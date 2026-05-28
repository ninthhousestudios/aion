# mcp spine architecture

Current implemented state of `lib/` as of 2026-04-24.

This document covers what exists in code today, not the planned future
described in `architecture-plan-overview.md`.

## directory layout

```
lib/
  main.dart                          # app entry point
  mcp/
    plugin_host.dart                 # MCP client lifecycle manager
    plugin_manifest.dart             # plugin config, persistence, bundled manifests
    slot_state.dart                  # sealed state type for workspace data slots
    workspace_store.dart             # named data slots backed by MCP tool calls
  providers/
    plugin_host_provider.dart        # Riverpod provider for PluginHost
    workspace_providers.dart         # Riverpod providers for WorkspaceStore + slots
  widgets/
    plugin_status.dart               # plugin dashboard UI (current home screen)
```

## dependency graph

```
main.dart
  └─ widgets/plugin_status.dart
       ├─ providers/plugin_host_provider.dart
       │    └─ mcp/plugin_host.dart
       │         └─ mcp/plugin_manifest.dart
       └─ mcp/plugin_manifest.dart (BundledManifests)

providers/workspace_providers.dart
  ├─ providers/plugin_host_provider.dart
  ├─ mcp/workspace_store.dart
  │    ├─ mcp/plugin_host.dart
  │    └─ mcp/slot_state.dart
  └─ mcp/slot_state.dart
```

External dependencies: `mcp_dart` (MCP protocol), `rxdart` (BehaviorSubject
streams), `flutter_riverpod` (state management).

## layer architecture

Three layers, bottom to top:

```
┌──────────────────────────────────────────────────┐
│  widgets/            Flutter UI                  │
│  (PluginStatusPage)  Reads Riverpod providers    │
├──────────────────────────────────────────────────┤
│  providers/          Riverpod glue               │
│  (pluginHostProvider, workspaceStoreProvider,     │
│   pluginStateProvider, slotProvider)             │
├──────────────────────────────────────────────────┤
│  mcp/                Pure Dart, no Flutter deps  │
│  (PluginHost, WorkspaceStore, PluginManifest,    │
│   SlotState)                                     │
└──────────────────────────────────────────────────┘
        │
        │ stdio / streamable HTTP
        ▼
  ┌─────────────┐
  │ MCP servers  │  (Drishti, user plugins, future bundled plugins)
  └─────────────┘
```

The `mcp/` layer has zero Flutter imports. It can be tested with plain
`dart test` against real or mock MCP servers.

## mcp/ module detail

### PluginHost (`plugin_host.dart`)

Central manager for MCP client connections. One instance per app lifetime.

**State model.** Each plugin name maps to a `BehaviorSubject<PluginState>`.
`PluginState` is a data class carrying:

- `status`: `stopped | starting | connected | error`
- `error`: present only in `error` state
- `tools`: the `List<Tool>` returned by `listTools()`, present only in
  `connected` state

**Lifecycle operations:**

| Method | What it does |
|---|---|
| `startPlugin(manifest)` | Build transport, create `McpClient`, connect (30s timeout), list tools, store client reference, emit `connected` |
| `stopPlugin(name)` | Close client, remove from maps, emit `stopped`, close the BehaviorSubject |
| `startAll(manifests)` | `Future.wait` over all manifests where `autoStart == true`. Failures set error state per-plugin but don't abort sibling starts |
| `dispose()` | Stop all plugins, close all subjects, mark instance as disposed |

**Transport construction.** `_buildTransport` switches on `PluginTransport`:

- `stdio` → `StdioClientTransport` wrapping `StdioServerParameters`
  (command, args, working directory, env, stderr forwarded to host stdout)
- `http` → `StreamableHttpClientTransport` wrapping a URI

**Crash detection.** After successful connect, the host registers an
`onclose` callback on the `McpClient`. If the plugin process exits while
the host is still alive, the plugin transitions to
`error('Plugin process exited unexpectedly')`.

**Tool invocation.** `callTool(server, tool, args)` looks up the client
by server name and delegates to `McpClient.callTool`. Throws
`PluginNotConnected` if the server isn't in the connected client map.

**Observability.** `watchPlugin(name)` returns the BehaviorSubject's stream.
`pluginState(name)` returns the current snapshot. `connectedPlugins` returns
names of all plugins currently in `connected` status.

### PluginManifest (`plugin_manifest.dart`)

Three concerns in one file: the manifest data class, the config
persistence layer, and the bundled manifest constants.

**PluginManifest fields:**

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Unique identifier |
| `displayName` | `String` | Human-readable label |
| `description` | `String` | Short description |
| `transport` | `PluginTransport` | `stdio` or `http` |
| `command` | `String?` | Executable path (stdio only) |
| `args` | `List<String>?` | Command arguments (stdio only) |
| `env` | `Map<String, String>?` | Environment variables (stdio only) |
| `workingDirectory` | `String?` | CWD for child process (stdio only) |
| `url` | `String?` | Server URL (http only) |
| `bundled` | `bool` | Ships with aion (default false) |
| `autoStart` | `bool` | Start on app launch (default false) |

Full JSON round-trip via `fromJson`/`toJson`. `fromJson` applies
variable substitution to `command`, `args`, and `workingDirectory`.

**Variable substitution.** `${AION_PLUGINS}` in manifest fields is replaced
with `$AION_PLUGINS` env var, falling back to `~/.config/aion/plugins`.
This lets user plugin manifests reference a shared plugins directory
without hardcoding paths.

**PluginConfig** (static helper class):

- `configPath()` → `$XDG_CONFIG_HOME/aion` or `~/.config/aion`
- `loadUserPlugins()` → reads `plugins.json` from config dir, returns
  `List<PluginManifest>`. Silently returns `[]` on missing file or parse error.
- `saveUserPlugins(plugins)` → writes `plugins.json`, creating parent
  directories as needed.

**BundledManifests.** Static constants for plugins that ship with aion.
Currently one entry:

```
drishti:
  transport: stdio
  command: dart
  args: [run, --verbosity=error, drishti:drishti]
  workingDirectory: $DRISHTI_PATH or ../arjuna
  env: {DRISHTI_EPHE_PATH if set}
  bundled: true
  autoStart: true
```

### SlotState (`slot_state.dart`)

Sealed class with four variants:

| Variant | Fields | Meaning |
|---|---|---|
| `SlotIdle` | (none) | No calculation requested yet |
| `SlotLoading` | `options` | Tool call in flight |
| `SlotReady` | `data`, `options` | Successful result, decoded JSON map |
| `SlotError` | `error`, `options` | Failed — transport error, tool error, or bad JSON |

`options` is carried through all non-idle states so the UI can display
what parameters produced the current result or error.

### WorkspaceStore (`workspace_store.dart`)

Manages named "slots" — each slot is an independently observable
computation result backed by an MCP tool call.

**Slot lifecycle.** Each slot name maps to a `BehaviorSubject<SlotState>`.
Lazy creation: first access to any name creates a subject seeded with
`SlotIdle`.

**`recalculate(slot, server, tool, args)`** — the core operation:

1. Emit `SlotLoading(args)`
2. Call `PluginHost.callTool(server, tool, args)`
3. On success: extract `TextContent` from result, `json.decode` it,
   emit `SlotReady(data, args)`
4. On tool-level error (`result.isError`): extract error message from
   `TextContent`, emit `SlotError`
5. On missing `TextContent`: emit `SlotError`
6. On invalid JSON: emit `SlotError` with the raw text in the message
7. On transport/connection exception: emit `SlotError`

**Design constraint.** WorkspaceStore expects tool results to be a single
`TextContent` containing a JSON object. This is the contract between
aion and its MCP servers. Drishti currently uses
`CallToolResult.fromStructuredContent` which satisfies this.

**Observability.** `watch(name)` returns the stream, `current(name)`
returns the snapshot, `activeSlots` returns names of all non-idle slots.

## providers/ module detail

### pluginHostProvider (`plugin_host_provider.dart`)

```dart
final pluginHostProvider = Provider<PluginHost>((ref) { ... });
```

Singleton `PluginHost` scoped to the `ProviderScope` lifetime. Disposes
on scope teardown.

```dart
final pluginStateProvider = StreamProvider.family<PluginState, String>((ref, name) { ... });
```

Family provider keyed by plugin name. Widgets use
`ref.watch(pluginStateProvider('drishti'))` to reactively rebuild on
plugin state changes.

### workspaceProviders (`workspace_providers.dart`)

```dart
final workspaceStoreProvider = Provider<WorkspaceStore>((ref) { ... });
```

Singleton `WorkspaceStore` wired to the `PluginHost`. Disposes on scope
teardown.

```dart
final slotProvider = StreamProvider.family<SlotState, String>((ref, name) { ... });
```

Family provider keyed by slot name. Widgets use
`ref.watch(slotProvider('natal'))` to reactively rebuild when a slot's
computation completes or errors.

## widgets/ module detail

### PluginStatusPage (`plugin_status.dart`)

`ConsumerStatefulWidget`. Currently the app's sole screen (`home:` in
MaterialApp).

**On init:** kicks off `PluginHost.startAll(BundledManifests.all)` via
`Future.microtask` to avoid triggering during build.

**UI structure:** `Scaffold` with app bar + `ListView` of plugin tiles.
Each tile shows:

- Status indicator (colored dot: green/amber/red/grey)
- Display name and subtitle (tool count when connected, error message
  when errored)
- Expandable tool list (name + description for each registered tool)

The page watches `pluginStateProvider(manifest.name)` per plugin, so it
rebuilds reactively as plugins connect, error, or disconnect.

## data flow

### startup sequence

```
main()
  → ProviderScope(child: AionApp)
    → MaterialApp(home: PluginStatusPage)
      → initState()
        → PluginHost.startAll(BundledManifests.all)
          → for each manifest where autoStart:
              startPlugin(manifest)
                → _buildTransport(manifest)     # StdioClientTransport
                → McpClient.connect(transport)   # 30s timeout
                → client.listTools()             # discover available tools
                → emit PluginState.connected(tools)
                → register onclose crash handler
```

### chart calculation (via WorkspaceStore)

```
caller
  → WorkspaceStore.recalculate('natal', 'drishti', 'calculate_chart', {
      'date': '2000-01-01T12:00:00Z',
      'latitude': 28.6,
      'longitude': 77.2,
      'preset': 'ernst',
    })
  → emit SlotLoading(args)
  → PluginHost.callTool('drishti', 'calculate_chart', args)
    → McpClient.callTool(CallToolRequest(...))
      → [stdio transport → Drishti process]
        → Vayu.calculateChart(dateTime, location, options)
          → SweFacade.calcAll(jd, location, options)   # Swiss Ephemeris FFI
          → Chart(snapshot, calcConfig)                 # domain model
        → formatChart(chart)                            # → structured JSON
        → CallToolResult.fromStructuredContent(map)
      → [stdio transport ← result]
    → CallToolResult
  → json.decode(textContent.text)
  → emit SlotReady(data, args)
```

### the Drishti pipeline (other side of the wire)

Drishti is the bundled MCP server in `arjuna/drishti/`. It wraps the
Arrow calculation engine:

```
McpServer (stdio transport)
  └─ Tool: calculate_chart
       ├─ parse & validate: date, latitude, longitude, altitude, preset
       ├─ resolve preset → ArrowOptions (ernst / lahiri / western)
       ├─ Vayu.calculateChart(utcDateTime, location, options)
       │    └─ SweFacade → EphSnapshot → Chart
       └─ formatChart(chart) → structured JSON
            ├─ summary: { jd, ayanamsa, ascendant, mc }
            ├─ planets: [{ name, longitude, sign, nakshatra, pada,
            │              is_retrograde, speed_class, dignity?, is_combust? }]
            └─ houses: [{ number, sign, sign_name, longitude }]
```

`Vayu` (`arjuna/quiver/embedded/`) is the in-process facade over the
Arrow pipeline. It manages the native Swiss Ephemeris handle lifecycle.

## reactive wiring summary

```
BehaviorSubject<PluginState>    (per plugin, in PluginHost)
  → Stream<PluginState>
    → pluginStateProvider(name)   (Riverpod StreamProvider.family)
      → Widget rebuild

BehaviorSubject<SlotState>      (per slot, in WorkspaceStore)
  → Stream<SlotState>
    → slotProvider(name)          (Riverpod StreamProvider.family)
      → Widget rebuild
```

Both PluginHost and WorkspaceStore use `BehaviorSubject` (rxdart) so
new subscribers immediately receive the current value. Riverpod bridges
these into the widget tree via `StreamProvider.family`.

## error handling

| Layer | Strategy |
|---|---|
| Transport connect | 30s timeout; failure → `PluginState.error` |
| Process crash | `McpClient.onclose` → `PluginState.error` |
| `startAll` failures | Per-plugin catch; logged via `Zone.handleUncaughtError`, other plugins continue |
| Tool call on disconnected server | `PluginNotConnected` exception |
| Tool returns `isError: true` | `SlotError` with extracted text message |
| Tool returns no `TextContent` | `SlotError('No TextContent in tool result')` |
| Tool returns non-JSON text | `SlotError('Tool result is not valid JSON: ...')` |
| Transport exception during tool call | `SlotError` with raw exception |

## resource cleanup

`PluginHost.dispose()`:
1. Sets `_disposed = true` (prevents crash handler from firing during teardown)
2. Stops all connected plugins (`close()` on each `McpClient`)
3. Closes all `BehaviorSubject`s
4. Clears both maps

`WorkspaceStore.dispose()`:
1. Closes all slot `BehaviorSubject`s

Both are wired to Riverpod's `ref.onDispose`, so they clean up when the
`ProviderScope` tears down.

## test coverage

| File | What's tested |
|---|---|
| `test/mcp/plugin_host_test.dart` | Start/connect, tool call, stop, bad command → error, state stream transitions |
| `test/mcp/workspace_store_test.dart` | Slot lifecycle (idle→loading→ready), error states, invalid JSON, independent slots, `activeSlots` |
| `test/mcp/plugin_manifest_test.dart` | JSON round-trip, HTTP transport parsing, `${AION_PLUGINS}` substitution, bundled manifest constants |
| `test/mcp/test_server.dart` | Minimal MCP server with one `echo` tool, used as test fixture |
| `test/integration/drishti_test.dart` | Real Drishti connection, tool listing, `calculate_chart` with known input, stop/cleanup (tagged `integration`, requires arjuna workspace) |

## what exists vs. what's planned

**Implemented now:**
- PluginHost with full lifecycle (start, stop, crash detection, dispose)
- Two transports (stdio, streamable HTTP)
- Plugin manifests with JSON persistence and variable substitution
- One bundled plugin (Drishti) with auto-start
- WorkspaceStore with named slots and reactive state
- Riverpod provider layer bridging MCP streams to widgets
- Plugin status dashboard UI
- Full unit + integration test suite

**Not yet implemented (described in architecture-plan-overview.md):**
- Canvas workspace and card system
- Card-to-slot bindings and layout presets
- Chart database (chart-db plugin)
- Geographic/timezone resolution (mundus plugin)
- AI chat panel and LLM integration
- Renderer plugin architecture
- Plugin discovery, installation, and update
- User plugin management UI (beyond status dashboard)
