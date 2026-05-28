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
chart (jd, lat, lon)              — the birth event
  × config (ArrowOptions hash)    — the calculation pipeline
  × vector_schema (feature spec)  — what to extract and vectorize
  = vector                        — the searchable feature vector
```

a chart can have vectors for multiple configs. a vedic astrologer
working with ernst and lahiri has two vector sets. someone exploring
aditya adds a third.

each config references a vector_schema that defines which features
are extracted into the vector (bodies, cusps, nakshatras, etc.). the
schema is a separate entity because it's about what the astrologer
wants to search on, not how the chart is calculated. two configs can
share a schema; one config can switch schemas without changing its
calculation identity.

vectors are only comparable within the same config — cross-config
comparison is meaningless because the same planet has different
longitudes under different ayanamsas.

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
  source_path text,               -- relative path to source file (.toml, .chtk, .jhd)
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

### vector schemas table

```sql
create table vector_schemas (
  id    text primary key,       -- content hash of the spec
  name  text not null,          -- e.g. "western-13", "vedic-13", "uranian-21"
  spec  text not null,          -- json: bodies, features (see vector schema section)
  dims  integer not null        -- total dimensionality (derived from spec)
);
```

the `id` is a content hash (sha-256 of the canonical JSON spec).
default schemas (western-13, vedic-13, uranian-21) are built into
chart-db-core and auto-created on first run. custom schemas are
user-created and persisted in a `_schemas.json` sidecar alongside
the charts directory.

### configs table

```sql
create table configs (
  id               text primary key,  -- hash of ArrowOptions only
  name             text not null,
  preset           text not null,     -- json-encoded ArrowOptions
  vector_schema_id text not null references vector_schemas(id),
  note             text
);
```

the `id` is a content hash (sha-256 of the canonical JSON
serialization of ArrowOptions). the vector_schema_id is a separate
reference — changing the schema does not change the config's
identity. this means:

- two configs with identical options always resolve to the same id,
  even if created independently
- changing any option, no matter how obscure, produces a different id
- the same config can switch schemas without losing its identity

### chart vectors (sqlite-vec)

chart-db creates one sqlite-vec virtual table per vector schema.
this is necessary because `vec0` requires a fixed dimensionality
at table creation, and different schemas produce different-sized
vectors.

a sqlite virtual table looks like a regular SQL table but is backed
by an extension module — in this case sqlite-vec, which handles
vector storage and KNN queries. you query it with normal SQL but
the underlying implementation is specialized for vector operations.

```sql
-- created dynamically when a vector schema is first used
-- one table per distinct schema
create virtual table vec_<schema_id_prefix> using vec0(
  chart_id  text,
  config_id text,
  vector    float[N]              -- N = vector_schemas.dims
);
```

each row is a (chart, config) pair. searching for similar charts
picks the table for the config's schema, then filters by config_id.

the vector is extracted from a fully calculated chart (the structured
JSON that drishti returns). chart-db-core contains the extraction
logic: a pure function that takes drishti's output plus a schema
spec and produces a fixed-length float array.

### vector schema

the vector schema is a separate, user-configurable entity that defines
which features are extracted from a calculated chart and how they map
to vector dimensions. it is independent of the config (which controls
the astronomical calculation). an astrologer can tailor the schema to
search for what matters to their practice.

all angular values use sin/cos encoding to respect circular topology.
a longitude of θ degrees becomes (sin(2π·θ/360), cos(2π·θ/360)).

the schema spec is a json object listing bodies and feature blocks:

```json
{
  "bodies": ["su","mo","me","ve","ma","ju","sa","ra","ke","ur","ne","pl","ch"],
  "features": {
    "longitudes": true,
    "house_cusps": 12,
    "swe_aux": ["armc","vertex","equasc","co_asc_koch","co_asc_munkasey","polar_asc"],
    "house_placements": true,
    "nakshatras": false,
    "retrogrades": true
  }
}
```

dimensionality is computed deterministically from the spec. dimension
ordering follows feature block order: longitudes, cusps, swe_aux,
house_placements, nakshatras, retrogrades.

#### default schemas

**western-13** (default for western configs):

| feature | dims | encoding |
|---|---|---|
| planet longitudes (13: su,mo,me,ve,ma,ju,sa,ra,ke,ur,ne,pl,ch) | 26 | sin/cos of ecliptic longitude |
| house cusps (12) | 24 | sin/cos of ecliptic longitude |
| SWE auxiliary (armc, vertex, equasc, co-asc koch, co-asc munkasey, polar asc) | 12 | sin/cos |
| house placements (13 bodies) | 26 | sin/cos of (house × 30°) |
| retrograde flags (13 bodies) | 13 | 0.0 or 1.0 |
| **total** | **101** | |

**vedic-13** (default for vedic configs):

| feature | dims | encoding |
|---|---|---|
| planet longitudes (13) | 26 | sin/cos of ecliptic longitude |
| house cusps (12) | 24 | sin/cos of ecliptic longitude |
| SWE auxiliary (6 values) | 12 | sin/cos |
| house placements (13 bodies) | 26 | sin/cos of (house × 30°) |
| nakshatras (13 bodies) | 26 | sin/cos of (nakshatra × 360/27°) |
| retrograde flags (13 bodies) | 13 | 0.0 or 1.0 |
| **total** | **127** | |

**uranian-21** (for uranian astrology):

| feature | dims | encoding |
|---|---|---|
| planet longitudes (21: 13 default + cupido, hades, zeus, kronos, apollon, admetos, vulkanus, poseidon) | 42 | sin/cos of ecliptic longitude |
| house cusps (12) | 24 | sin/cos of ecliptic longitude |
| SWE auxiliary (6 values) | 12 | sin/cos |
| house placements (21 bodies) | 42 | sin/cos of (house × 30°) |
| retrograde flags (21 bodies) | 21 | 0.0 or 1.0 |
| **total** | **141** | |

the longitudes stored are whatever the config produces — tropical,
sidereal (lahiri), or aditya. the vector faithfully represents the
chart as calculated under that config. this is why cross-config
comparison doesn't work: the same planet at the same moment has
different longitudes under different ayanamsas.

**weighted search.** the full vector is always stored. queries apply
a weight vector to emphasize dimensions relevant to the search.
examples:

- "similar saturn placement" → weight saturn's longitude and house
  placement dims
- "similar cusp pattern" → weight the 24 house cusp dims
- "similar overall pattern" → uniform weights (default)

weights are applied at query time, not stored. the same vector
supports all these queries.

### storage estimates

at professional scale (2000 charts, 3 active configs):

- vec tables: 6000 rows × ~500 bytes = ~3 MB (vectors range from
  101 to 141 dims depending on schema)
- charts table + indexes: ~1 MB
- FTS index: ~0.5 MB
- total: well under 10 MB

adding more configs scales linearly. each distinct schema adds one
vec0 table, but the per-row cost is similar. 10 configs across 3
schemas for 2000 charts is still ~10 MB. storage is not a constraint.

## computation flow

### chart creation / import

```
new chart (toml or manual entry)
  → insert into charts table
  → for each config in active profile:
      → call drishti: calculate_chart(jd, lat, lon, config)
      → look up config's vector_schema
      → extract vector from result per schema spec
      → insert into schema's vec table (chart_id, config_id, vector)
  → update FTS index
```

### adding a new config

```
user (or agent) adds config to profile
  → insert into configs table (with vector_schema_id)
  → create schema's vec table if it doesn't exist
  → batch job: for each chart in charts table:
      → call drishti: calculate_chart(jd, lat, lon, config)
      → extract vector per schema spec
      → insert into schema's vec table
```

this is a batch operation. 2000 charts through vayu takes seconds
(in-process, no IPC). the MCP path would be slower but still
manageable — triggered explicitly by user or agent.

### changing a config's vector schema

```
user changes config C's schema from S1 to S2
  → delete all vectors for config C from S1's vec table
  → create S2's vec table if it doesn't exist
  → batch job: for each chart in charts table:
      → load or recalculate chart under config C
      → extract vector per S2 spec
      → insert into S2's vec table
```

if S1 has no remaining vectors after the migration, its vec table
can be dropped.

### similarity search

```
query: find charts similar to chart X under config C
  → look up config C's vector_schema → determines which vec table
  → load vector for (X, C) from that vec table
  → apply weight vector (optional, defaults to uniform)
  → sqlite-vec KNN query filtered by config_id = C
  → return ranked chart list with distances
```

exact KNN at 2000 charts × ~100 dims is sub-millisecond.
approximate nearest neighbor (HNSW, IVF) only needed at 100k+ scale.

## rebuild semantics

the sqlite database is a derived artifact. it can be rebuilt from:

- **charts table** → toml files (the source of truth)
- **tags** → stored in toml files, rebuilt on re-import
- **vector_schemas** → defaults from code, custom schemas from
  `_schemas.json` sidecar
- **chart_vectors** → recalculate from (jd, lat, lon) × configs ×
  schemas
- **FTS index** → regenerate from charts table
- **collections** → `_collections.json` sidecar in charts directory

backup strategy: copy the charts directory (toml/chtk/jhd files,
includes tags in toml files) + `_collections.json` + `_schemas.json`
(custom vector schemas). everything else is rebuildable.

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

- **vector schema as separate entity.** the vector schema defines
  what features to extract, independent of the config's calculation
  parameters. this separation exists because search is about what
  the astrologer cares about, not how the chart was computed. two
  configs can share a schema; one config can switch schemas. default
  schemas (western-13, vedic-13, uranian-21) cover standard use
  cases. custom schemas support specialized practices.

- **vector extraction implementation.** lives in chart-db-core. pure
  function: structured chart JSON + schema spec in, `Float64List`
  out. the schema spec parameterizes extraction — bodies, feature
  blocks, and dim ordering are all derived from it. the MCP wrapper
  doesn't need this function (it calls chart-db-core). drishti
  doesn't own it — the vector schema is chart-db's concern, not the
  calculation engine's.

- **one vec0 table per schema.** sqlite-vec's `vec0` requires fixed
  dimensionality at table creation. since schemas can have different
  dims (101 for western-13, 127 for vedic-13, 141 for uranian-21),
  each schema gets its own virtual table. tables are created lazily
  when a config first references a schema. this is cleaner than
  padding all vectors to a max dimension.

- **sqlite-vec from dart.** the `sqlite3` dart package supports
  `sqlite3_load_extension()`, and sqlite-vec ships as a loadable
  extension. try extension loading first. fallback: store vectors as
  blobs, compute cosine similarity in dart. at 2000 charts × ~100
  floats, that's ~1ms — not blocked either way.

- **config lifecycle.** purge vectors immediately on config deletion.
  they're derived data, recomputable in seconds. no orphan cleanup
  complexity. if a schema's vec table has no remaining vectors, drop
  the table.

- **rectification variants.** distinct charts (they have different
  JDs by definition). no special parent/variant linkage — collections
  handle grouping ("Josh rectification"). if rectification workflows
  need more structure later (diff views, parent tracking), add a
  `parent_chart_id` column then.
