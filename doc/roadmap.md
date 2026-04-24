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

**depends on:** phase 1 (mcp host), drishti development

## phase 3 — atlas

timezone resolution is required before chart input works for end users.

- geonames integration (geo lookup, bundled sqlite)
- meridian codex integration (historic timezones)
- iana tz database as fallback
- location search ui (autocomplete, reverse geocode)
- atlas as mcp server

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
- llm as mcp client: calls drishti, chart-db, atlas, any plugin
- context management: how much chart data to include automatically
- provider settings ui (choose local vs cloud, model selection)

**research needed:**
- ollama integration from dart/flutter
- anthropic/openai api from dart
- prompt engineering for astrological context
- context window management strategies

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
