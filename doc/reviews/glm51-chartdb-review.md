# Code Review: chart-db Package Suite (Waves 1–5)

**Reviewer:** GLM-5.1  
**Date:** 2026-04-26  
**Commits reviewed:**

| Wave | Hash | Description | Files | LoC |
|------|------|-------------|-------|-----|
| 1 | `44d75d7` | chart-db-core package with SQLite schema | 5 | 731 |
| 2 | `2b4e1b7` | Chart CRUD, collections, vector schemas, file importer | 12 | 2008 |
| 3 | `e321954` | Config management, vector extraction, sqlite-vec store | 6 | 1319 |
| 4 | `863251f` | Similarity search and chart service orchestration | 4 | 838 |
| 5 | `83b69ff` | MCP server and aion plugin registration | 15 | 1292 |

**Total:** ~6,188 lines added across 5 commits.

---

## Summary

These five commits introduce a complete chart storage and vector similarity search subsystem for aion, structured as two Dart packages:

- **`chart_db_core`** — pure Dart library: SQLite schema, CRUD repositories, vector schema registry, vector extraction, vec store, similarity search, and a chart service orchestrator.
- **`chart_db`** — MCP server exposing 8 tools over stdio transport, plus aion plugin registration.

The code is well-organized, thoroughly tested (148 tests across 9 test files), and follows the existing project conventions (drishti-style MCP plugin pattern, charts_dart ChartIO for import). The review below focuses on correctness, robustness, security, and maintainability issues.

---

## Critical Issues

### C1. FTS5 content-sync integrity is fragile — no `rebuild` path

**Files:** `database.dart:105-127`, `database_test.dart`  
**Severity:** Critical

The FTS5 table uses `content='charts'` (content-sync mode) with triggers for INSERT/UPDATE/DELETE. This is correct, but there is no `INSERT INTO charts_fts(charts_fts) VALUES('rebuild')` path exposed anywhere. If a trigger ever fails silently (e.g., due to a write conflict or if someone modifies the charts table with `PRAGMA recursive_triggers = OFF`), the FTS index becomes silently stale with no way to recover.

**Recommendation:** Add a `rebuildFts()` method to `ChartDatabase` that runs `INSERT INTO charts_fts(charts_fts) VALUES('rebuild')`. Call it from a CLI command or after schema migration.

### C2. `UNIQUE(jd, lat, lon)` natural key is astronomically insufficient

**File:** `database.dart:68`  
**Severity:** Critical

The unique constraint `UNIQUE(jd, lat, lon)` prevents duplicate *birth events at the same time and place*, but real-world astrology databases routinely contain multiple charts for the same (jd, lat, lon) — twins, relocated charts at the same moment, or charts with identical coordinates but different names/genders. The `DuplicateChartException` makes this a hard error rather than a warning.

**Recommendation:** Either (a) relax to a softer "skip or warn" policy (the MCP `import_charts` tool already does this for imports, but the core repository does not), or (b) add `name` to the unique constraint to allow same-location births with different identities, or (c) make the constraint configurable. At minimum, document the design decision and its implications.

### C3. `_dateTimeToJd` is duplicated between `ChartImporter` and `import_charts.dart`

**Files:** `chart_importer.dart:133-150`, `import_charts.dart:173-187`  
**Severity:** Critical (DRY violation / divergence risk)

The Meeus Julian Day algorithm is copy-pasted verbatim into two locations. If a bug fix or precision improvement is made in one, the other will silently remain wrong. The `import_charts.dart` MCP tool duplicates the function rather than importing from `chart_importer.dart` or `chart_db_core`.

**Recommendation:** Extract `dateTimeToJd` into `chart_db_core` as a public utility function. Have both `ChartImporter` and the MCP tool import it from there. The `ChartImporter` is already in the aion main package which depends on `charts_dart`; the JD function has no such dependency.

---

## High-Severity Issues

### H1. `VecStore.knn()` blob fallback loads ALL vectors into memory

**File:** `vec_store.dart:147-162`  
**Severity:** High

When the `vec0` native extension is unavailable (which is the default/test path), the KNN fallback loads every vector for the given `configId` into Dart memory and computes cosine similarity in a loop. For a database with 100k charts at 127 dims each, this is ~12.7M floats = ~100 MB loaded per query. This will cause OOM on constrained systems and is extremely slow.

**Recommendation:** Add a `limit` parameter to the fallback SQL query (e.g., `SELECT chart_id, vector FROM $table WHERE config_id = ? LIMIT 500`) and document that the fallback is only suitable for small-to-medium databases. Consider storing pre-computed norms alongside vectors to speed up the cosine computation.

### H2. `ChartService.recomputeVectors()` uses `limit: 1 << 30` to fetch all charts

**File:** `chart_service.dart:106`  
**Severity:** High

`_chartRepo.search(limit: 1 << 30)` is a hack to load all charts. This bypasses any pagination safety and will load the entire charts table into memory. The `search` method joins with FTS tables and applies `DISTINCT`, making this query expensive.

**Recommendation:** Add a dedicated `ChartRepository.all()` or `ChartRepository.listAll()` method that does a simple `SELECT * FROM charts` without FTS joins, DISTINCT, or ORDER BY. Use cursor-based pagination for large datasets.

### H3. No transaction wrapping in repository write operations

**Files:** `chart_repository.dart`, `collection_repository.dart`, `config_repository.dart`, `vector_schema.dart`  
**Severity:** High

Individual repository methods (insert, update, delete) execute bare SQL statements without transaction wrapping. While the `ChartService` orchestrator calls multiple repositories in sequence (e.g., `createChart` → insert chart → compute vectors → store vectors), a failure midway leaves the database in an inconsistent state (chart exists but vectors don't, or vectors exist but chart doesn't).

**Recommendation:** Either (a) add transaction support to the repositories (accept an optional `Database` with an active transaction), or (b) add explicit `begin`/`commit`/`rollback` calls in `ChartService` methods, or (c) document that the service methods are not atomic and add a `repair()` method.

### H4. `VectorSchema` spec is stored as stringified JSON but compared as a parsed Map

**File:** `vector_schema.dart:203-208`  
**Severity:** High

The `register()` method checks for existence by querying `vector_schemas WHERE id = ?` using the hash. This is correct. However, the `spec` column stores `canonicalJson(spec)` (deterministic), while `VectorSchema.spec` returns `jsonDecode(row['spec'])` — a parsed `Map<String, dynamic>`. Downstream code (e.g., `extractVector`) compares the spec as a Map, but two semantically identical specs with different key ordering would produce different hashes and thus different rows. The `canonicalJson` function mitigates this, but only if *every* caller passes through `register()`. If someone inserts a row directly with non-canonical JSON, the system breaks.

**Recommendation:** This is partially mitigated by the hash-based idempotency. Document that direct SQL inserts into `vector_schemas` must use canonical JSON. Consider adding a CHECK constraint or trigger that validates the `spec` column matches `specHash(jsonDecode(spec))`.

### H5. `import_charts` MCP tool does not use `ChartImporter` from aion

**File:** `import_charts.dart`  
**Severity:** High

The MCP tool re-implements the entire import logic (ChartIO.read, JD computation, field mapping) instead of reusing the `ChartImporter` class from `lib/import/chart_importer.dart`. This is a layer violation: the MCP server package (`chart_db`) should depend on the core logic, not reimplement it. This leads to:
- Duplicated JD computation (C3)
- Duplicated field mapping logic
- Future drift when `ChartImporter` is updated but the MCP tool is not

**Recommendation:** Either have the MCP tool import and use `ChartImporter` (requires making `chart_db` depend on the aion main package, which may create circular deps), or extract the shared import logic into `chart_db_core` as an `ImportedChart` → `Chart` mapper.

---

## Medium-Severity Issues

### M1. `chart_tags` lacks a `tag` normalization strategy

**File:** `database.dart:85-89`, `collection_repository.dart:131-145`  
**Severity:** Medium

Tags are stored as-is with no normalization. "Natal", "natal", "NATAL" would be three different tags. The `chart_tags` PK is `(chart_id, tag)` with a B-tree index on `tag`, but case-insensitive tag lookups require `LOWER(tag)` which bypasses the index.

**Recommendation:** Either (a) store tags in a normalized form (e.g., lowercase), or (b) add a COLLATE NOCASE index, or (c) document the current behavior and add a `normalizeTag()` helper.

### M2. `configs.id` is the SHA-256 of the *raw* preset string, not canonical JSON

**File:** `config_repository.dart:37-41`  
**Severity:** Medium

Unlike `VectorSchema.id` which uses `canonicalJson()` (sorted keys, deterministic), `Config.id` hashes the raw `presetJson` string. This means two semantically identical presets with different key ordering produce different config ids and different rows. The doc comment says "making registration idempotent" but it's only idempotent for byte-identical strings, not semantically identical JSON.

**Recommendation:** Apply `canonicalJson` to `presetJson` before hashing, consistent with the vector schema approach. Or document the intentional difference and explain why raw hashing is preferred (e.g., to preserve exact preset bytes for round-trip fidelity).

### M3. `Chart.fromRow()` uses `as num` with `.toDouble()` instead of native type checking

**File:** `chart_repository.dart:44-60`  
**Severity:** Medium

SQLite returns integers for values like `0` but doubles for `0.0`. The `(row['jd'] as num).toDouble()` pattern handles this, but it also silently accepts strings or booleans that happen to be castable to `num`. If the schema ever drifts (e.g., a migration changes a column type), this will produce confusing runtime errors instead of clear type errors.

**Recommendation:** Use explicit type checks: `if (row['jd'] is int) { ... } else if (row['jd'] is double) { ... }` or at minimum add assertions. The same pattern appears in `Collection.fromRow`, `VectorSchema.fromRow`, and `Config.fromRow`.

### M4. `SimilaritySearch._applyWeights()` re-normalizes but distorts the metric space

**File:** `similarity_search.dart:89-103`  
**Severity:** Medium

Weighting individual dimensions and re-normalizing to unit length changes the relative importance of dimensions in a way that is not equivalent to a weighted distance metric. For example, zeroing out dimensions 0 and 1 then re-normalizing makes dimensions 2+ dominate, but the cosine similarity with *unweighted* stored vectors no longer measures the same thing as cosine similarity in the weighted subspace. The KNN results are compared against unweighted stored vectors, creating a semantic mismatch.

**Recommendation:** Either (a) store weighted vectors separately for search, or (b) compute weighted cosine similarity directly in the fallback path without re-normalizing the query, or (c) document that this is an approximation and explain the trade-off.

### M5. `ChartDatabase.close()` calls `_db.dispose()` but repositories hold references

**File:** `database.dart:21`  
**Severity:** Medium

After `ChartDatabase.close()`, any `ChartRepository` or other repository instance that holds a reference to `_db` will throw when used. There is no guard against use-after-close. The test `tearDown` calls `close()`, which is safe because the test is ending, but in the MCP server, if `shutdown()` is called while a tool handler is still executing, the handler will crash with an unhelpful sqlite3 error.

**Recommendation:** Add a `_closed` flag to `ChartDatabase` and check it before operations, or use a reference-counting pattern, or ensure the MCP server drains all in-flight requests before calling `close()`.

### M6. No indexing on `charts.jd` despite range queries

**File:** `database.dart`  
**Severity:** Medium

The `search` method supports `jdMin`/`jdMax` range filters (`c.jd >= ?`, `c.jd <= ?`), but there is no index on `charts.jd`. For large databases, this results in full table scans for JD-only queries.

**Recommendation:** Add `CREATE INDEX IF NOT EXISTS idx_charts_jd ON charts(jd);` in `_createTables()`.

### M7. `import_charts` MCP tool does not recursively scan directories

**File:** `import_charts.dart:80-85`  
**Severity:** Medium

The tool uses `dir.listSync(recursive: false)`, matching the `ChartImporter.importDirectory` behavior. However, chart collections on disk are often organized in nested subdirectories (e.g., `natal/famous/`, `mundane/historical/`). Users will expect recursive import.

**Recommendation:** Add a `recursive` parameter (default `false` for safety, `true` for convenience). This should be done in both `ChartImporter` and the MCP tool.

### M8. `_extension()` is duplicated between `ChartImporter` and `import_charts`

**File:** `chart_importer.dart:119-122`, `import_charts.dart:160-164`  
**Severity:** Medium

Same function, same logic, two locations. Related to C3.

### M9. `_mapToImported` field mapping logic is duplicated in `import_charts.dart`

**Files:** `chart_importer.dart:93-116`, `import_charts.dart:98-131`  
**Severity:** Medium

The mapping from `ChartData` to chart fields (city → placename, country, gender, etc.) is repeated. This is part of H5 but worth calling out separately — the conditional `isNotEmpty` → null logic for `placename` and `country` is duplicated exactly.

---

## Low-Severity Issues

### L1. `ensureSchema()` catch block rethrows but schema may be partially created

**File:** `database.dart:35-48`  
**Severity:** Low

If `_createTables()` succeeds but `_createFts()` fails, the ROLLBACK will undo everything (since the whole thing is in a transaction). This is correct. But if `_createFtsTriggers()` fails, the FTS table exists without triggers, and the ROLLBACK undoes it. However, the `user_version` PRAGMA is set inside the transaction, so after ROLLBACK, `user_version` is still 0 and the next attempt will retry. This is fine but worth documenting.

### L2. `_schemaVersion` is private and not exposed for external validation

**File:** `database.dart:4`  
**Severity:** Low

There is no way to query the current schema version from outside the class. If a migration is needed, the caller must use `PRAGMA user_version` directly. Consider exposing a `schemaVersion` getter.

### L3. `computeDims()` silently accepts `swe_aux` as a non-list truthy value

**File:** `vector_schema.dart:202-204`  
**Severity:** Low

`if (sweAux is List && sweAux.isNotEmpty)` is correct, but `sweAux == true` would not be caught here — it would just be skipped. The `validateSpec` function does validate `swe_aux` must be a list if present, but `computeDims` is a public function that could be called independently.

### L4. Test fixture chart JSON uses `name.hashCode` for deterministic data

**File:** `chart_service_test.dart:40`  
**Severity:** Low

`'longitude': (jd * 13.37 + name.hashCode) % 360` — `String.hashCode` is not guaranteed stable across Dart VM versions or isolates. The tests pass now but may become flaky on SDK upgrades. Use a fixed mapping instead.

### L5. `VecStore._tableName()` truncates schema ID to 8 chars

**File:** `vec_store.dart:38`  
**Severity:** Low

`'vec_${schemaId.substring(0, 8)}'` — SHA-256 hashes are 64 hex chars. Truncating to 8 chars (32 bits) creates collision risk: ~65k schemas would produce a 50% collision chance. For a local astrology DB this is extremely unlikely, but the truncation is unnecessary (SQLite table names can be much longer). Document the trade-off or use more chars.

### L6. MCP tool `_errorResult` functions are duplicated across every tool file

**Files:** `create_config.dart`, `get_chart.dart`, `import_charts.dart`, `list_collections.dart`, `list_configs.dart`, `list_schemas.dart`, `search_charts.dart`, `similar_charts.dart`  
**Severity:** Low

Every tool file defines its own `_errorResult` helper. Extract to a shared `tool_utils.dart`.

### L7. `BundledManifests.chartDb` uses `dart run` instead of a compiled snapshot

**File:** `plugin_manifest.dart:152`  
**Severity:** Low

`args: ['run', '--verbosity=error', 'chart_db:chart_db']` — `dart run` does JIT compilation on every startup. For an auto-start plugin, this adds ~1-2s cold-start latency. Consider `dart compile exe` and pointing at the binary, or using `dart run` only in dev with a compiled snapshot in production.

### L8. No `pubspec.yaml` `publish_to: none` on `chart_db_core`

**File:** `chart_db_core/pubspec.yaml`  
**Severity:** Low

`chart_db` has `publish_to: none` but `chart_db_core` does not. If someone accidentally runs `dart pub publish` from the core package, it could be published to pub.dev with internal dependencies.

---

## Design Observations (Non-blocking)

### D1. Synchronous API throughout

All repository methods are synchronous (wrapping synchronous sqlite3 calls). This is fine for a local CLI/desktop app but will block the Dart event loop during long queries (especially the KNN fallback). If aion ever moves to a Flutter UI, these will need to move to isolates.

### D2. Content-addressed IDs for configs and schemas

Using SHA-256 hashes as primary keys is clever for idempotency but makes debugging harder (you can't look at a config ID and know which config it is). The `name` field helps, but logs and error messages show only the hash. Consider including a short human-readable prefix.

### D3. The `CalculateChart` callback is async but repositories are sync

`ChartService.createChart` is `async` because it calls `CalculateChart`, but the repository writes are synchronous. This means a chart row is committed to the database before vectors are computed. If the vector computation fails, the chart exists without vectors. This is related to H3.

### D4. `extractVector` is a pure function — good design

The vector extraction is a pure function with no I/O, making it easy to test and reason about. The dimension ordering is documented and deterministic. Good.

### D5. The blob fallback cosine similarity is correctly implemented

The `_cosineSimilarity` method handles zero-norm inputs (returns 0.0) and produces correct rankings. The test coverage for this path is solid.

---

## Test Coverage Assessment

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `database_test.dart` | 9 | Schema creation, FTS triggers, migration versioning |
| `chart_repository_test.dart` | 18 | CRUD, search, FTS, duplicate handling |
| `collection_repository_test.dart` | 12 | Collections, tags, FK cascades |
| `vector_schema_test.dart` | 12 | Registration, validation, dims, hash determinism |
| `config_repository_test.dart` | 14 | Registration, idempotency, body validation |
| `vec_store_test.dart` | 10 | Table creation, insert/KNN, delete, fallback |
| `vector_extractor_test.dart` | 10 | sin/cos encoding, dimension layout |
| `chart_service_test.dart` | 10 | Lifecycle, recompute, migration |
| `similarity_search_test.dart` | 8 | Weighted search, self-exclusion, edge cases |
| `chart_importer_test.dart` | 8 | JD conversion, file/directory import |

**Total: ~111 tests.** Coverage is good for the happy paths and most error paths. Notable gaps:
- No test for concurrent access (two ChartDatabase instances on the same file)
- No test for WAL mode behavior or checkpoint
- No test for `VecStore` with native `vec0` extension (understandable — extension may not be available in CI)
- No test for MCP server integration (would require mock transport)
- No test for schema migration (`user_version` bump from 1 → 2)
- `chart_service_test.dart` uses a mock `CalculateChart` — no test with real ephemeris computation

---

## Action Items (Prioritized)

| Priority | ID | Summary | Effort |
|----------|----|---------|--------|
| P0 | C3 | Deduplicate `dateTimeToJd` | Small |
| P0 | C2 | Document/relax unique key policy | Small |
| P1 | H5 | MCP import tool should reuse core logic | Medium |
| P1 | H3 | Add transaction wrapping for multi-step writes | Medium |
| P1 | H1 | Cap KNN fallback memory usage | Small |
| P1 | H2 | Add dedicated `listAll()` instead of `limit: 1<<30` | Small |
| P2 | M2 | Canonicalize preset JSON before hashing | Small |
| P2 | M6 | Add index on `charts.jd` | Trivial |
| P2 | M5 | Guard against use-after-close | Small |
| P2 | M4 | Document weighted search approximation | Small |
| P2 | M9 | Deduplicate field mapping logic | Small |
| P3 | L8 | Add `publish_to: none` to core pubspec | Trivial |
| P3 | L6 | Extract shared `_errorResult` helper | Small |
| P3 | L7 | Consider compiled snapshot for auto-start | Medium |

---

## Overall Assessment

The chart-db package suite is a well-structured, test-driven implementation of a domain-specific vector database. The layered architecture (core library → MCP server → aion plugin) is clean, and the code follows Dart conventions consistently. The main risks are around data integrity (no transaction wrapping for multi-step operations), scalability (KNN fallback loads all vectors), and code duplication across the aion main package and the MCP server. The P0 items (JD dedup, unique key documentation) should be addressed before any production use; the P1 items should follow soon after.
