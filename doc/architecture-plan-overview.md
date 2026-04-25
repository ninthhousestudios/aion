# aion architecture overview

2026-04-21 — initial design decisions from feature planning session.

## identity

aion is the flagship desktop application for professional astrologers,
built on the arjuna calculation ecosystem. flutter desktop (linux, macos, windows).

previously named gandiva-arjuna. the python prototype (gandiva/pyqt6) continues
as an experimentation platform; aion is the production rewrite.

## core principle: mcp as the spine

aion's extensibility architecture is built on mcp (model context protocol).
the core application is a thin ui shell + mcp host. all domain functionality
lives in mcp servers — some bundled, some third-party.

### what is core aion

- flutter ui: infinite canvas, card system, layout engine, snap physics
- mcp host: discover, launch, and manage mcp server lifecycles
- layout preset engine: save/load/share workspace layouts as json
- chat panel: ui surface for ai interaction (routes to llm provider)
- plugin registry: tracks installed mcp servers, their capabilities, ui contributions

core aion has zero astrological knowledge. it is a workspace shell.

### what is a plugin

everything else. each plugin is an mcp server (separate process, any language).

**bundled plugins (ship with aion):**

| plugin | role | language |
|---|---|---|
| drishti | arjuna/arrow calculations via mcp | rust |
| chart-db | chart storage, indexing, search, embeddings | tbd |
| atlas | geographic lookup (geonames) + historic timezone resolution (meridian codex + iana) | tbd |
| core renderers | south indian, north indian, western wheel, data table, dasha timeline | dart (in-process?) |

**third-party plugin examples:**

- additional renderers (uranian dial, human design bodygraph, cards of truth, kp)
- interpretive frameworks (teacher-specific yoga evaluation, tradition-specific dignities)
- import/export handlers (jhora .jhd, parashara's light, solar fire)
- external integrations (calendar, client crm, email)
- specialized data sources (fixed stars, asteroids, financial feeds)
- alternative or supplementary calculation engines

### renderer plugins — special case

renderers may need to be dart/flutter code running in-process for performance
(canvas painting at 60fps over ipc is impractical). two options:

1. renderers are compiled dart packages loaded at build time (not runtime-swappable)
2. renderers receive data via mcp but paint in-process via a registered dart widget

option 2 is preferable — the mcp server provides data and layout hints,
a thin dart adapter does the actual canvas painting. this keeps the protocol
consistent while keeping rendering performant.

### mcp sdk and transport

**package: `mcp_dart`** (community, v2.1.0, pub.dev/packages/mcp_dart).
chosen over the official `dart_mcp` (google labs) for streamable http support.
both were validated in `../mcp-spike/`.

transport strategy:

| server | transport | reason |
|---|---|---|
| drishti (local arrow) | stdio | child process, single client |
| chart-db | stdio | local, single client |
| atlas | stdio | local, single client |
| local plugins | stdio | default for all local servers |
| quiver (remote) | streamable http | different machine, network transport |
| future remote services | streamable http | as needed |

stdio is the default. aion spawns local mcp servers as child processes —
lifecycle tied to the app. streamable http is reserved for remote servers
(quiver, shared services). the plugin manifest declares supported transports;
aion connects appropriately.

aion is the single mcp host. the ai does not independently connect to servers —
it makes tool calls routed through aion. no multi-client scenario for local plugins.

## chart database

### storage layers

```
toml files (source of truth)
  human-readable, one per chart
  portable, shareable, existing format
        |
sqlite index (derived, rebuildable)
  metadata, tags, collections
  full-text search on names/notes
  smart filter definitions
        |
vector store via sqlite-vec (derived, rebuildable)
  structured chart vectors
  text embeddings
  similarity search
```

backup = copy the toml folder. import = drop toml files in and re-index.
the sqlite index and vectors are derived artifacts — rebuildable from toml alone.

### structured chart vectors

when a chart is calculated, extract a fixed-length numerical vector:

```
[sun_longitude, moon_longitude, ..., asc_longitude,
 sun_house, moon_house, ...,
 aspect_sun_moon, aspect_sun_mars, ...,
 dignity_sun, dignity_moon, ...,
 nakshatra_moon, ...]
```

normalized to [0,1]. enables:

- **similar chart lookup** — cosine similarity, instant across entire database
- **weighted similarity** — "similar but stronger saturn" by adjusting dimension weights
- **clustering** — discover natural groupings in a chart collection
- **smart filters** — astrological queries as vector operations, not sequential calculate-and-check

at the scale of a professional astrologer's database (hundreds to low thousands),
exact knn is sub-millisecond. ann (hnsw, ivf) only needed at 100k+ scale.

### text embeddings

generate natural language chart descriptions, embed with a small local model
(sentence transformer). enables semantic natural language queries:

- "clients going through a difficult saturn period"
- "charts with strong creative potential"
- "similar relationship dynamics to this chart"

complements structured vectors — structured handles precise astrological queries,
text embeddings handle fuzzy natural language queries.

### organization

- **collections** — named groups (folders): "my clients", "celebrity charts", "rectification cases"
- **tags** — freeform, multiple per chart
- **smart filters** — saved queries that leverage calculation + vector search
- **import** — jhora (.jhd) is highest priority. parashara's light second.
- **export** — json/toml (data), pdf (reports/charts)

## atlas

two distinct problems:

1. **geographic lookup** (name -> lat/lon): geonames, open source, 12m+ locations.
   bundled as sqlite export.

2. **historic timezone resolution** (location + date -> utc offset): meridian codex
   (open source, targets historical accuracy) + iana tz database as fallback.

arjuna/arrow works internally in julian days and does zero timezone handling.
timezone resolution is aion's responsibility — convert user input (local datetime +
location) to julian day before passing to arrow via drishti.

## ai integration

### architecture

```
aion chat panel
    | (user message + context)
    v
llm provider (user's choice)
    |-- local: ollama, llama.cpp
    |-- cloud: anthropic api, etc.
    | mcp tool calls
    v
+-------------------------------+
| drishti (calculations)        |
| chart-db (search, embeddings) |
| atlas (location/timezone)     |
| any installed plugin          |
+-------------------------------+
    | results
    v
llm synthesizes response
    |
    v
aion chat panel
```

### provider model

user chooses local or cloud in settings. aion does not auto-switch.
the interface is identical — llm is an mcp client calling the same servers.

- **local**: private, offline-capable, no subscription. weaker reasoning.
- **cloud**: better quality, requires internet, sends chart data to provider.

### capability tiers

1. **ephemeris assistant** — factual queries. local model handles well.
2. **chart narrator** — summarize chart features. local models borderline.
3. **interpretive consultant** — nuanced astrological reasoning. cloud models significantly better.

### ai + embeddings synergy

the llm can combine structured vector queries with text embedding queries
and calculation results in a single interaction:

```
user: "which clients should i reach out to about the upcoming saturn-mars conjunction?"

llm -> drishti: get conjunction date/degrees
llm -> chart-db (vector): find charts with natal saturn/mars near transit degrees
llm -> chart-db (text): refine by "relationship or career stress indicators"
llm -> synthesize: "these 4 clients are most affected, here's why..."
```

## canvas & workspace (from gui-spike)

### three layers

```
canvas layer — pure geometry, no astrology knowledge
    |
card bindings — declarative references to workspace data
    |
workspace store — live chart data, talks to plugins via mcp
```

### cards

each card: position, size, z-order, constraints (min size, aspect ratio),
slot binding, renderer type, renderer config.

cards have no knowledge of calculation. they say "show slot X using renderer Y
with config Z."

### layout presets

json documents. reference slots, not specific charts. shareable/exportable.
switching presets animates cards from old positions to new.

### interaction model

gesture-first, keyboard-augmented. command palette (ctrl+k or /).
card palette for drag-to-canvas. context menus for card operations.

## v1 feature scope

### must-have

- canvas workspace with card system
- chart database with search, tagging, collections
- multiple chart styles (south indian, north indian, western wheel minimum)
- data tables (planets, nakshatras, dashas, dignities)
- atlas with historic timezone support
- report generation / pdf export
- import from jhora format
- transit animation / time stepping
- multi-chart workspace (multiple slots, side by side)
- mcp plugin architecture (host + bundled plugins)

### v1 stretch

- ai chat panel (local + cloud)
- chart journaling / event tracking
- smart filters with vector search
- structured chart embeddings
- text embeddings for natural language search

### v2+

- community plugin repository
- astrocartography / relocation maps
- scheduling integration (cal.com or similar)
- custom glyph sets
- financial astrology module
- plugin ui contribution conventions (menus, settings panels)

## ecosystem

| project | role |
|---|---|
| arjuna/arrow | calculation engine (rust) |
| arjuna/quiver | remote server backend |
| drishti | mcp wrapper for arrow (planned) |
| vayu | frontend boundary layer between aion and arrow/quiver |
| aion | desktop application (this project) |
| gandiva | python prototype, experimentation platform |
| aion-gui-spike | flutter canvas interaction prototype |

## open questions

- renderer plugin architecture: compiled dart packages vs mcp data + dart adapter?
- chart vector schema: which astrological features to include, what dimensionality?
- text embedding model: which sentence transformer to bundle for local use?
- toml chart format: what extensions needed for metadata, tags, collections?
- mcp server lifecycle: how does aion discover, install, and update plugins?
- ai context: how much chart context to include in llm prompts automatically?
