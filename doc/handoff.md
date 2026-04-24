# Handoff

## Status

Phase 1 MCP spine is implemented and passing all tests. 15 unit tests + 3 integration tests green. App launches on Linux, connects to Drishti, and shows plugin status UI.

## What was done

- Replaced `flutter create` scaffold with Aion app shell (dark theme, ProviderScope)
- Built pure-Dart MCP infrastructure in `lib/mcp/`: PluginManifest, PluginHost, SlotState, WorkspaceStore
- Riverpod bridge providers in `lib/providers/`
- Plugin status UI in `lib/widgets/plugin_status.dart` — shows connection state and tool list
- Full test coverage: manifest parsing, plugin lifecycle, workspace store state machine, Drishti integration
- Pre-mortem ran and findings addressed before implementation (`.agents/council/2026-04-24-pre-mortem-mcp-spine-phase1.md`)

## Key discoveries during implementation

- **`dart run --verbosity=error`** is required for MCP servers with native assets (like Drishti). Without it, "Running build hooks..." contaminates stdout and breaks the JSON-RPC stream. This flag is baked into the bundled manifest.
- **Drishti invocation:** `dart run drishti:drishti` from the arjuna workspace root, NOT `dart run bin/drishti.dart` from the drishti subdirectory. The workspace resolution requires the root.
- **BehaviorSubject delivers events asynchronously** — tests need `await Future.delayed(Duration.zero)` after async operations to flush microtask queue before asserting on collected stream values.
- **mcp_dart API:** uses `registerTool()` not `addTool()`, and `StdioServerParameters` uses `environment` not `env` for the env map parameter.

## Next step

Port canvas from `gui-spike` into `lib/canvas/`, wire cards to WorkspaceStore slots (Phase 2).

## Open items

- mcp_dart fork pinned to commit `0cfec14`. PR #90 upstream to `leehack/mcp_dart` — check merge status periodically, switch to pub.dev version when merged
- No timeout on `McpClient.connect()` / `callTool()` — acceptable for Phase 1, add for hardening
- No process exit detection — if Drishti crashes, PluginHost doesn't notice until next callTool fails
- `PluginConfig` JSON file I/O is implemented but unused in Phase 1 (only bundled manifests are used)
