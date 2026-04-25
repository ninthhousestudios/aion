# chart-db design

2026-04-24 — storage architecture for chart database.

## identity

chart-db is the persistent storage layer for aion. it stores birth data,
organizes charts into collections, and provides similarity search via
structured chart vectors.

chart-db does not store text embeddings — those belong to chitta.
chart-db does not perform calculations — it calls drishti (via the
plugin host) to compute charts, then extracts and stores the results.

## access architecture

chart-db-core is an in-process dart package. the aion UI imports it
directly for low-latency browsing, filtering, search, and CRUD. no
IPC overhead for the operations that happen most frequently (scrolling
a chart list, type-ahead search, drag-and-drop between collections).

a thin MCP wrapper exposes the same operations as tool calls for the
AI agent and external plugins. one implementation, two access paths —
same pattern as vayu (in-process) / drishti (MCP wrapper).

```
aion UI ──→ chart-db-core (dart package, in-process)
                ↑
AI agent ──→ chart-db MCP server (thin wrapper, stdio)
```

## data model

### the natural key

a chart is uniquely identified by the astronomical moment:

- **jd** — julian day (UTC)
- **lat** — geographic latitude
- **lon** — geographic longitude

everything else — planet positions, signs, houses, dignities — is
derived from this triple through a calculation pipeline with specific
options. one birth event, many possible computed representations.

altitude is stored as metadata but is not part of the natural key.
its effect on calculations is negligible for the purpose of chart
identity.

### charts vs configs vs vectors

```
chart (jd, lat, lon)          — the birth event
  × config (hash of ArrowOptions) — the calculation pipeline
  = vector                        — the computed feature vector
```

the same chart can have vectors for multiple configs. a vedic
astrologer working in ernst and lahiri has two vector sets. someone
exploring aditya adds a third. each vector set is independently
searchable — you only compare vectors computed the same way.

### profiles

a profile defines which configs are active for a user's workflow.
when a chart is imported or created, chart-db automatically computes
vectors for all configs in the active profile.

- default: one profile with one config (the user's preferred preset)
- power users: multiple configs, managed directly
- AI agent: can add configs and trigger batch recomputation on behalf
  of the user

profiles are a UI/workflow concept in aion, not a chart-db-core
concern. chart-db-core just knows about charts, configs, and vectors.

## sqlite schema

### charts table

```sql
create table charts (
  id          text primary key,   -- uuid
  jd          real not null,
  lat         real not null,
  lon         real not null,
  alt         real,
  name        text not null,
  gender      text,               -- 'male', 'female', null
  placename   text,
  country     text,
  utc_offset  real not null,
  dst_offset  real default 0,
  notes       text,
  rodden      text,               -- rodden rating (AA, A, B, C, DD, X, XX)
  toml_path   text,               -- relative path to source toml file
  created_at  text not null,      -- iso 8601
  updated_at  text not null,

  unique(jd, lat, lon)            -- natural key constraint
);
```

### collections and tags

```sql
create table collections (
  id    text primary key,
  name  text not null unique,
  note  text
);

create table chart_collections (
  chart_id      text not null references charts(id) on delete cascade,
  collection_id text not null references collections(id) on delete cascade,
  primary key (chart_id, collection_id)
);

create table chart_tags (
  chart_id text not null references charts(id) on delete cascade,
  tag      text not null,
  primary key (chart_id, tag)
);

create index idx_chart_tags_tag on chart_tags(tag);
```

### full-text search

```sql
create virtual table charts_fts using fts5(
  name,
  placename,
  country,
  notes,
  content='charts',
  content_rowid='rowid'
);
```

triggers on insert/update/delete to keep the FTS index in sync with
the charts table.

### configs table

```sql
create table configs (
  id      text primary key,       -- hash of the full ArrowOptions
  name    text not null,           -- human-readable label
  preset  text not null,           -- json-encoded ArrowOptions
  note    text
);
```

the `id` is a content hash (sha-256 of the canonical JSON
serialization of ArrowOptions). this means:

- two configs with identical options always resolve to the same id,
  even if created independently
- changing any option, no matter how obscure, produces a different id
- there is no ambiguity about whether two configs are "the same"

### chart vectors (sqlite-vec)

```sql
create virtual table chart_vectors using vec0(
  chart_id  text,
  config_id text,
  vector    float[N]              -- N = dimensionality, see below
);
```

each row is a (chart, config) pair. searching for similar charts
always filters by config_id first — cross-config comparison is
meaningless.

the vector is extracted from a fully calculated chart (the structured
JSON that drishti returns). chart-db-core contains the extraction
logic: it takes drishti's output and produces a fixed-length float
array.

### vector schema

all angular values use sin/cos encoding to respect circular topology.
a longitude of θ degrees becomes (sin(2π·θ/360), cos(2π·θ/360)).

| feature | dims | encoding |
|---|---|---|
| planet longitudes (9 bodies: su, mo, me, ve, ma, ju, sa, ra, ke) | 18 | sin/cos of ecliptic longitude |
| ascendant | 2 | sin/cos |
| MC (midheaven) | 2 | sin/cos |
| house placements (9 bodies) | 18 | sin/cos of (house × 30°) |
| planet-pair angular separations (9 choose 2 = 36 pairs) | 72 | sin/cos of separation angle |
| moon nakshatra | 2 | sin/cos of (nakshatra × 360/27°) |
| retrograde flags (9 bodies) | 9 | 0.0 or 1.0 |
| **total** | **123** | |

the longitudes stored are whatever the config produces — tropical,
sidereal (lahiri), or aditya. the vector faithfully represents the
chart as calculated under that config. this is why cross-config
comparison doesn't work: the same planet at the same moment has
different longitudes under different ayanamsas.

**weighted search.** the full 123-dim vector is always stored.
queries apply a weight vector to emphasize dimensions relevant to the
search. examples:

- "similar saturn placement" → weight saturn's 2 longitude dims,
  zero everything else
- "similar aspect geometry" → weight the 72 aspect-pair dims
- "similar overall pattern" → uniform weights (default)

weights are applied at query time, not stored. the same vector
supports all these queries.

### storage estimates

at professional scale (2000 charts, 3 active configs):

- chart_vectors: 6000 rows × ~500 bytes = ~3 MB
- charts table + indexes: ~1 MB
- FTS index: ~0.5 MB
- total: well under 10 MB

adding more configs scales linearly. 10 configs for 2000 charts is
still ~10 MB. storage is not a constraint.

## computation flow

### chart creation / import

```
new chart (toml or manual entry)
  → insert into charts table
  → for each config in active profile:
      → call drishti: calculate_chart(jd, lat, lon, config)
      → extract vector from result
      → insert into chart_vectors (chart_id, config_id, vector)
  → update FTS index
```

### adding a new config

```
user (or agent) adds config to profile
  → insert into configs table
  → batch job: for each chart in charts table:
      → call drishti: calculate_chart(jd, lat, lon, config)
      → extract vector from result
      → insert into chart_vectors
```

this is a batch operation. 2000 charts through vayu takes seconds
(in-process, no IPC). the MCP path would be slower but still
manageable — triggered explicitly by user or agent.

### similarity search

```
query: find charts similar to chart X under config C
  → load vector for (X, C) from chart_vectors
  → apply weight vector (optional, defaults to uniform)
  → sqlite-vec KNN query filtered by config_id = C
  → return ranked chart list with distances
```

exact KNN at 2000 charts × 123 dims is sub-millisecond.
approximate nearest neighbor (HNSW, IVF) only needed at 100k+ scale.

## rebuild semantics

the sqlite database is a derived artifact. it can be rebuilt from:

- **charts table** → toml files (the source of truth)
- **tags** → stored in toml files, rebuilt on re-import
- **chart_vectors** → recalculate from (jd, lat, lon) × configs
- **FTS index** → regenerate from charts table
- **collections** → `_collections.json` sidecar in charts directory

backup strategy: copy the toml directory (includes tags in each file)
+ `_collections.json`. everything else is rebuildable.

## MCP tool surface (sketch)

the MCP wrapper exposes chart-db-core operations as tools. initial
tool set:

| tool | description |
|---|---|
| `search_charts` | text search (FTS) + metadata filters (date range, tags, collection, country) |
| `similar_charts` | vector similarity search: given a chart id + config + optional weights |
| `get_chart` | retrieve full chart data by id |
| `list_collections` | list all collections with chart counts |
| `list_configs` | list available configs with chart counts |

the UI calls chart-db-core directly and doesn't use these tools.
these exist for the AI agent, which accesses chart-db through the
MCP host like any other plugin.

## resolved design decisions

- **collections persistence.** tags are per-chart metadata — they go
  in the toml file as a top-level `tags = ["client", "rectification"]`
  array. they survive a database rebuild because they travel with the
  chart. collections are organizational structure (a chart doesn't know
  it's in a collection) — those go in a sidecar manifest
  (`_collections.json`) in the charts directory. both get copied with a
  directory backup. nothing lives only in sqlite.

- **vector extraction implementation.** lives in chart-db-core. pure
  function: structured chart JSON in, `Float64List` out. the MCP
  wrapper doesn't need it (it calls chart-db-core). drishti doesn't
  own it — the vector schema is chart-db's concern, not the
  calculation engine's. keeps the dependency arrow clean.

- **sqlite-vec from dart.** the `sqlite3` dart package supports
  `sqlite3_load_extension()`, and sqlite-vec ships as a loadable
  extension. try extension loading first. fallback: store vectors as
  blobs, compute cosine similarity in dart. at 2000 charts × 123
  floats, that's ~1ms — not blocked either way.

- **config lifecycle.** purge vectors immediately on config deletion.
  they're derived data, recomputable in seconds. no orphan cleanup
  complexity.

- **rectification variants.** distinct charts (they have different
  JDs by definition). no special parent/variant linkage — collections
  handle grouping ("Josh rectification"). if rectification workflows
  need more structure later (diff views, parent tracking), add a
  `parent_chart_id` column then.
