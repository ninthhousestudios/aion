# aion roadmap

2026-04-21 — high-level phases and research areas.

## phase 0 — gui spike (now)

validate the canvas interaction model in isolation.

- canvas with draggable, resizable cards
- snap physics, spring animations
- slot binding and workspace store (mock data)
- layout presets (save/load/animate transitions)

this is happening in `gui-spike/`. code may not carry over directly
but the patterns and lessons will.

## phase 1 — mcp spine

the foundation everything else builds on.

- mcp host in dart/flutter: discover, launch, manage mcp server processes
- define plugin manifest format (how a plugin declares its capabilities)
- bundled plugin lifecycle (ship with aion, auto-start)
- wire up at least one real mcp server (drishti or a test stub)

**research needed:**
- ~~mcp sdk/libraries for dart~~ — RESOLVED: `mcp_dart` v2.1.0. validated in `../mcp-spike/`.
  stdio for local, streamable http for remote (quiver). `dart_mcp` (official) also works
  but lacks http transport.
- mcp server packaging — how do bundled plugins ship? embedded binaries?
- plugin discovery — file system convention? registry file?

## phase 2 — drishti + real data

aion becomes a real astrology app.

- drishti: mcp wrapper for arrow (rust, planned)
- wire canvas cards to drishti via mcp
- real chart calculation flowing into renderers
- core renderers: south indian, north indian, western wheel, data table
- **slot pipelines** — extend WorkspaceStore to support multi-step tool call
  composition. a slot can be defined by a pipeline of chained calls where each
  step's output feeds the next, executed in dart without inference overhead.
  this establishes the composition pattern that the AI layer (phase 6) can later
  generate programmatically. see david soria parra's "programmatic tool calling"
  concept from the MCP future talk (april 2025).
- **structured output contracts** — plugins declare output schemas on their tools
  (MCP's structured content type). WorkspaceStore validates results against schema
  and pipelines use type info to wire step outputs to inputs automatically.
  **drishti change:** tool registrations need `outputSchema` added.
- **skills field in PluginManifest** — add an optional `skills` field to the
  manifest format. plugins can advertise domain knowledge documents alongside
  tools (e.g. "natal chart reading procedure", "vimshottari dasha interpretation").
  nothing consumes this yet — the AI panel (phase 6) will load these into context
  instead of a monolithic system prompt. designing the field now means drishti can
  start shipping skills incrementally.
  **drishti change:** ship skill documents alongside tools when ready.

**depends on:** phase 1 (mcp host), drishti development

## phase 3 — mundus

timezone resolution is required before chart input works for end users.

- geonames integration (geo lookup, bundled sqlite)
- iana tz database as fallback
- location search ui (autocomplete, reverse geocode)
- mundus as mcp server

**research needed:**
- geonames: best format for bundled sqlite export? update cadence?
- dart/flutter libraries for timezone handling

## phase 4 — chart database

persistent storage and organization.

- toml chart files (extend existing format as needed)
- sqlite index for metadata, tags, collections, full-text search
- chart crud ui (create, edit, delete, browse)
- collections and tagging
- import from jhora (.jhd format)
- database as mcp server

**research needed:**
- jhora .jhd format — reverse engineer or find documentation
- toml schema: what metadata fields needed beyond birth data?
- sqlite from dart/flutter — ffi bindings, packages

## phase 5 — embeddings + smart search

vector search layered on top of the database.

- structured chart vectors: define schema (which features, dimensionality)
- compute vectors on chart insert/update
- sqlite-vec integration for knn search
- smart filters ui (saved vector queries with adjustable weights)
- text embeddings: choose and bundle a sentence transformer
- natural language search over chart descriptions

**research needed:**
- chart vector schema design — this is a domain question, not a tech question.
  which astrological features capture meaningful similarity? what dimensionality?
  needs experimentation.
- sqlite-vec: dart/flutter ffi bindings? or access via mcp server?
- sentence transformer selection: model size vs quality tradeoff for bundling.
  must run locally on modest hardware.

## phase 6 — ai integration

the chat panel and llm wiring.

- chat panel ui in aion
- llm provider abstraction (local ollama, cloud anthropic/openai)
- llm as mcp client: calls drishti, chart-db, mundus, any plugin
- context management: how much chart data to include automatically
- provider settings ui (choose local vs cloud, model selection)
- **progressive discovery** — do not dump all plugin tools into the LLM context.
  provide a `search_tools` meta-tool; load plugin tools on demand when the model
  needs them. PluginHost already holds tool lists per plugin — build a search
  index over them. this is the single biggest context-reduction technique
  (demonstrated in claude code by anthropic).
- **skills consumption** — load plugin-shipped skills (from the manifest field
  added in phase 2) into the LLM context as domain knowledge. skills travel with
  the plugin, so drishti can update its jyotish knowledge independently of aion
  releases. the model gets "here's how to read a natal chart" from the server
  rather than a hardcoded system prompt.

**research needed:**
- ollama integration from dart/flutter
- anthropic/openai api from dart
- prompt engineering for astrological context — partially addressed by skills-over-MCP;
  plugin-shipped skills reduce the prompt engineering burden on aion itself
- context window management strategies — progressive discovery is the primary
  technique; also consider programmatic tool calling (model writes scripts in
  the slot pipeline REPL rather than orchestrating one call at a time)

## phase 7 — reports + export

professional output.

- pdf report generation
- chart image export (png, svg)
- report templates (configurable, saveable)
- print support

## phase 8 — polish + release

- journaling / event tracking
- transit animation / time stepping with snap-to-event
- keyboard shortcuts, accessibility
- onboarding / first-run experience
- documentation
- packaging and distribution (linux, macos, windows installers)

## future (post-v1)

- community plugin repository / marketplace
- astrocartography / relocation maps
- scheduling integration
- financial astrology module
- plugin ui contribution conventions
- **mcp applications for chart rendering** — MCP's experimental "applications"
  feature lets servers ship their own rendered UI (HTML/canvas). this could solve
  chart renderer portability: drishti ships a south indian grid renderer that
  works in any MCP host, not just aion. for now we stay with native flutter
  renderers (performance, tight canvas interaction). but supporting both is
  attractive long-term: flutter-native cards for the main canvas, with a webview
  fallback for plugin-provided rich views. worth revisiting once MCP applications
  stabilize in the spec.

---

## research priorities

roughly ordered by when the knowledge is needed and how long
the research might take.

1. ~~**mcp in dart/flutter**~~ — RESOLVED. `mcp_dart` v2.1.0 selected. spike at `../mcp-spike/`.
   stdio + streamable http both validated.
2. **meridian codex** — phase 3. deep dive into coverage, api, integration path.
3. **jhora .jhd format** — phase 4. need to understand the format for import.
4. **chart vector schema** — phase 5. domain research + experimentation.
   what makes two charts "similar"? this is as much an astrological question
   as a technical one. gandiva prototype could be useful for experimenting.
5. **local llm from flutter** — phase 6. ollama bindings, model selection,
   resource requirements for end users.
6. **sentence transformers for bundling** — phase 5/6. which models are
   small enough to ship, good enough to be useful?
