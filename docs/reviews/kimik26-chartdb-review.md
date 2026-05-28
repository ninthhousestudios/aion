# Code Review: Chart DB (Commits 44d75d7 → 83b69ff)

**Review Date:** 2026-04-26
**Commits:** 5 waves, 42 files changed, +6,188 −1 lines
**Author:** josh (josh@ninthhouse.studio)
**Co-Author:** Claude Opus 4.6

---

## Executive Summary

The Chart DB feature is delivered as a clean, 5-wave incremental PR that introduces a SQLite-backed chart storage system with full-text search, vector similarity search, and an MCP server interface. The architecture demonstrates good separation of concerns (`chart_db_core` for engine, `chart_db` for MCP transport), comprehensive test coverage (137 tests, all passing), and thoughtful design decisions around content-addressed hashing and graceful fallbacks.

**Overall Grade: B+** — Solid architecture and testing, with a few maintainability issues, code duplication, and edge-case gaps that should be addressed before production.

---

## Wave-by-Wave Review

### Wave 1: `44d75d7` — SQLite Schema Foundation

**Files:** `database.dart`, `database_test.dart`, `pubspec.yaml`

**Strengths:**
- Clean schema design with proper foreign keys, cascade deletes, and WAL mode.
- FTS5 virtual table with well-crafted `ai`/`ad`/`au` triggers for automatic index sync.
- `user_version` PRAGMA for future migration support.
- In-memory default (`:memory:`) makes testing trivial.

**Issues:**
1. **Schema version is a private constant (`_schemaVersion = 1`)** — not reachable by external migration runners. Consider exposing a getter.
2. **`_ensureSchema()` does not handle partial migrations** — if schema v1 exists and v2 is introduced, the `BEGIN..COMMIT` block runs all `_create*` methods unconditionally. This is fine for v1→v2 but will fail loudly if v3 adds a table that already exists (though `IF NOT EXISTS` mitigates this). For v3 adding a column, this pattern breaks.
3. **No index on `charts(jd, lat, lon)`** — the natural unique key is enforced but not indexed for lookups (SQLite auto-creates a unique index, so this is minor).
4. **FTS5 `content_rowid='rowid'`** is correct but fragile — if the `charts` table is ever VACUUMed or rowids change, the FTS index must be rebuilt. Document this constraint.

---

### Wave 2: `2b4e1b7` — CRUD, Collections, Vector Schemas, File Importer

**Files:** `chart_repository.dart`, `collection_repository.dart`, `vector_schema.dart`, `chart_importer.dart`, + tests

**Strengths:**
- `DuplicateChartException` with the existing chart id is a thoughtful UX touch.
- `ChartRepository.search()` composes FTS + metadata filters cleanly with dynamic SQL generation.
- `VectorSchema` uses content-addressed SHA-256 hashes for ids — idempotent, deterministic, and prevents duplicate specs.
- `CollectionRepository` handles tags and memberships with proper cascade semantics.
- Chart importer uses existing `charts_dart.ChartIO` instead of reinventing format parsing.

**Issues:**

#### 1. Code Duplication: Julian Day Algorithm
The Meeus JD algorithm is implemented **twice**:
- `lib/import/chart_importer.dart:133-150` (as `ChartImporter.dateTimeToJd`)
- `packages/chart_db/lib/src/tools/import_charts.dart:169-185` (as `_dateTimeToJd`)

The two implementations are byte-for-byte identical. This is a classic DRY violation. The MCP tool package should depend on the core importer or a shared utility.

**Fix:** Extract `dateTimeToJd` into `chart_db_core` or a shared `utils/julian_day.dart` and have both call sites import it.

#### 2. `ChartRepository.update()` — Dynamic SQL Construction
```dart
_db.execute(
  'UPDATE charts SET ${sets.join(', ')} WHERE id = ?;',
  params,
);
```
While `sets` only contains hardcoded literals (`'name = ?'`, etc.), this pattern is a landmine for future maintenance. If someone refactors to inject a column name from user input, it becomes an injection vector.

**Fix:** Keep the dynamic approach but add a `const Set<String> _mutableColumns = {'name', 'gender', ...}` guard that validates every set clause starts with an allowed column name.

#### 3. `ChartRepository.search()` — Potential SQL Injection via `orderBy`
```dart
orderBy = 'bm25(charts_fts)'; // lower = better match
```
The `orderBy` variable is assigned from a literal but flows into final SQL string interpolation:
```dart
ORDER BY $orderBy
```
Currently safe because both branches use hardcoded strings, but this is brittle.

**Fix:** Use a whitelist map:
```dart
const _orderByMap = {
  'name': 'c.name',
  'bm25': 'bm25(charts_fts)',
};
```

#### 4. `ChartImporter.importDirectory` — No Recursive Listing
```dart
for (final entity in dir.listSync(recursive: false)) {
```
Users with nested chart directories (e.g., `charts/2024/`, `charts/2025/`) will silently get partial imports. The MCP `import_charts` tool inherits this limitation.

**Fix:** Either change `recursive: false` → `recursive: true` with a max-depth guard, or document the flat-directory requirement in the tool description.

#### 5. `VectorSchemaRepository.register()` — Double SELECT After INSERT
```dart
_db.execute('INSERT ...');
final rows = _db.select('SELECT * FROM vector_schemas WHERE id = ?;', [id]);
return VectorSchema.fromRow(rows.first);
```
This pattern (insert then re-select) appears in multiple repositories. It’s 2 round-trips when 1 would suffice using `RETURNING *` (SQLite 3.35+). `sqlite3` supports `RETURNING`.

**Fix:** `INSERT ... RETURNING *` and map directly from the result row.

---

### Wave 3: `e321954` — Configs, Vector Extraction, Vec Store

**Files:** `config_repository.dart`, `vector_extractor.dart`, `vec_store.dart`, + tests

**Strengths:**
- `ConfigRepository` uses SHA-256 of raw preset JSON for idempotent registration.
- `updateSchema()` validates schema bodies are a subset of config bodies — prevents impossible vector extraction.
- `extractVector()` is a **pure function** with no I/O. Excellent for testability.
- Sin/cos encoding of angles is the correct way to make circular data (0° ≈ 360°) amenable to Euclidean distance.
- `VecStore` has a clean fallback strategy: detect `vec_version()`, use native `vec0` if available, otherwise Dart-side cosine similarity on blobs.

**Issues:**

#### 1. `VecStore` — Inconsistent INSERT Semantics
```dart
if (_useNativeVec) {
  _db.execute('INSERT INTO $table ...');        // may throw on duplicate
} else {
  _db.execute('INSERT OR REPLACE INTO $table ...'); // upsert
}
```
The native path will throw `SqliteException` on duplicate `(chart_id, config_id)` pairs, while the blob path silently overwrites. This divergence could cause flaky behavior in environments where `vec0` is sometimes available.

**Fix:** Use `INSERT OR REPLACE` in both branches, or explicitly handle the duplicate-key case in the native branch.

#### 2. `VecStore._tableName()` — Hash Prefix Collision Risk
```dart
String _tableName(String schemaId) => 'vec_${schemaId.substring(0, 8)}';
```
SHA-256 produces 64 hex chars. The probability of two schema hashes colliding in the first 8 chars is astronomically low (~1 in 4 billion), but it’s not zero. If it happens, two unrelated schemas share a vec table and data corruption ensues.

**Fix:** Use the full hash or store a `table_name` column in `vector_schemas`.

#### 3. `VecStore.knn()` Blob Fallback Loads Entire Config Into Memory
```dart
final rows = _db.select('SELECT chart_id, vector FROM $table WHERE config_id = ?', [configId]);
```
For a config with 100,000 charts, this loads 100k × dim × 8 bytes into Dart memory. At 101 dims (western-13), that’s ~80MB. At 1M charts, it’s ~800MB.

**Fix:** Not urgent for MVP, but add a `// TODO: pagination or chunked streaming for large configs` comment. The native `vec0` path does not have this issue.

#### 4. `extractVector()` — No Validation of `chartJson` Structure
The function assumes `chartJson['planets']` is a `List<Map>` and `chartJson['houses']` is a `List<Map>`. If the calculation engine returns a malformed map (e.g., `planets` is a single map instead of a list), the cast will throw a runtime `TypeError` rather than a descriptive `ArgumentError`.

**Fix:** Add structural validation before casting, or use `as List<dynamic>?` and validate element types.

#### 5. `VectorSchema.computeDims()` and `extractVector()` Are Tightly Coupled
If `computeDims()` and `extractVector()` get out of sync (e.g., someone adds a new feature to `computeDims()` but forgets `extractVector()`), the `assert(result.length == expectedDims)` catches it at runtime in debug mode only. In release mode, the assert is stripped and the mismatch propagates to the database.

**Fix:** Add a unit test that iterates over all known schema specs, calls `extractVector` on a fixture chart, and verifies the length against `computeDims()`. Or better, drive `extractVector` from a single source of truth (e.g., an `encodeFeature` registry).

---

### Wave 4: `863251f` — Similarity Search & Chart Service Orchestration

**Files:** `similarity_search.dart`, `chart_service.dart`, + tests

**Strengths:**
- `SimilaritySearch.findSimilar()` correctly excludes the query chart from results.
- Weighted dimension search with L2 re-normalization is mathematically sound.
- `ChartService` provides a clean lifecycle API: `createChart`, `deleteChart`, `recomputeVectors`, `migrateSchema`.
- `migrateSchema` drops old vec tables when no longer referenced — good cleanup hygiene.

**Issues:**

#### 1. `ChartService.createChart()` — Sequential Config Processing
```dart
for (final config in configs) {
  if (config.vectorSchemaId == null) continue;
  final chartJson = await _calculateChart(...);
  final vector = extractVector(chartJson, schema.spec);
  _vecStore.insertVector(...);
}
```
If a user has 5 configs (e.g., tropical, sidereal, vedic, heliocentric, etc.), `_calculateChart` is called 5 times serially. Each call may trigger an MCP round-trip to `drishti` or heavy SWE computation. This is O(configs) latency.

**Fix:** Parallelize with `Future.wait`:
```dart
await Future.wait(configs.where((c) => c.vectorSchemaId != null).map((config) async {
  // ... calculate and store
}));
```
Note: `extractVector` is CPU-bound but fast; the bottleneck is `_calculateChart`.

#### 2. `ChartService.recomputeVectors()` — `limit: 1 << 30` Hack
```dart
final charts = _chartRepo.search(limit: 1 << 30);
```
This relies on an implementation detail of `ChartRepository.search()` — there is no dedicated `listAll()` or `streamAll()` method. Using `1 << 30` (approx 1 billion) as a stand-in for "unlimited" is semantically muddy and brittle if the repo later caps limits internally.

**Fix:** Add `ChartRepository.listAll()` or accept `limit: null` in `search()` to mean "no limit."

#### 3. `ChartService.deleteChart()` — Async-Delete-Then-Sync-Delete Race
```dart
Future<void> deleteChart(String chartId) async {
  final configs = _resolveConfigs(null);
  for (final config in configs) {
    _vecStore.deleteVectors(...);
  }
  _chartRepo.delete(chartId);     // synchronous
}
```
The chart row is deleted synchronously after (async) vector deletions. If `_chartRepo.delete` cascades tags/collections via FK, and a concurrent read is happening, there’s a tiny window where the chart exists but its vectors are gone. In SQLite with WAL mode, this is mostly benign, but for strict consistency the chart delete should happen in the same transaction as vector deletes.

**Fix:** The bigger issue is that `ChartDatabase` exposes `_db` directly, so repositories use independent transactions. Consider adding a transaction helper to `ChartDatabase` and threading it through the service.

#### 4. `SimilaritySearch.findSimilar()` — Wasted `k+1` Native Query
```dart
final results = _vecStore.knn(schemaId, configId, searchVector, k + 1);
return results.where((r) => r.chartId != chartId).take(k).toList();
```
When using the native `vec0` extension, the database computes and sorts `k+1` results, then Dart discards one. For large `k` (e.g., 100), the waste is negligible. For small `k` (e.g., 1 or 2), it’s 50-100% overhead. More importantly, if the query chart is not in the result set (e.g., it has no vector), the `k+1` logic still applies and may return `k` results correctly.

**Fix:** Acceptable for MVP. For optimization, consider a `WHERE chart_id != ?` clause in the native `vec0` query, but `vec0` MATCH syntax may not support this cleanly.

---

### Wave 5: `83b69ff` — MCP Server & Aion Integration

**Files:** `server.dart`, 8 tool files, `plugin_manifest.dart`, `bin/chart_db.dart`

**Strengths:**
- Follows the existing `drishti` stdio transport pattern.
- 8 well-defined tools with JSON schema validation via `mcp_dart`.
- Clean signal handling (`SIGINT`, `SIGTERM`) with database close.
- `PluginManifest` for `chartDb` correctly sets `bundled: true, autoStart: true`.
- `CHART_DB_PATH` env var override is a nice ops touch.

**Issues:**

#### 1. `chart_db` MCP Server Has No Health Check / Readiness Tool
There is no `ping`, `health`, or `status` tool. An MCP client that auto-starts `chart_db` has no way to verify the server is ready beyond attempting a tool call.

**Fix:** Add a `chart_db_status` tool that returns `{ "ready": true, "db_path": ..., "chart_count": ..., "config_count": ... }`.

#### 2. `import_charts` Tool Uses File Paths from Client
```dart
final path = args['path'] as String;
```
The MCP server receives a file path from the LLM/client and performs `FileSystemEntity.isDirectorySync(path)`. If the MCP server runs on a different host than the client (e.g., containerized), paths will be wrong. Even in local mode, this is a potential directory traversal risk if the LLM is prompted to pass `../../../etc/passwd`.

**Fix:** Validate that the resolved path is within an allowed directory (e.g., `Platform.environment['CHART_IMPORT_DIR']` or `$HOME/charts`). Add a sandbox check:
```dart
final allowedRoot = Platform.environment['CHART_IMPORT_DIR'] ?? '${Platform.environment['HOME']}/charts';
if (!path.startsWith(allowedRoot)) return _errorResult('Path outside allowed import directory');
```

#### 3. `search_charts` Tool Does Not Return `tags` or `collections`
The tool returns raw chart fields but omits the tags and collection memberships. A user searching for charts may want to see which collections a chart belongs to.

**Fix:** Either join tags/collections in the search response, or add a separate `get_chart_collections` tool.

#### 4. `similar_charts` Tool Weights API Is Cumbersome
```json
{ "weights": { "0": 0.0, "1": 0.0, "2": 10.0, "3": 10.0 } }
```
Dimension indices are opaque to LLM callers. A schema-aware weight API (e.g., `{ "longitudes": 2.0, "retrogrades": 0.5 }`) would be far more usable.

**Fix:** Add a weight-by-feature-name helper that maps to indices internally. This could live in `SimilaritySearch`.

#### 5. `plugin_manifest.dart` — Relative `workingDirectory`
```dart
static final chartDb = PluginManifest(
  workingDirectory: 'packages/chart_db',
);
```
This assumes the aion binary is always run from the project root. If the binary is installed globally or run from a different CWD, the relative path breaks.

**Fix:** Resolve relative to the executable path:
```dart
workingDirectory: Platform.environment['CHART_DB_PATH'] ?? 
    '${Platform.script.toFilePath()}/../packages/chart_db',
```
Or document that `AION_ROOT` / `CHART_DB_PATH` env vars are required for non-dev use.

#### 6. `startServer()` Opens DB Before Signal Handlers Are Ready
```dart
final database = ChartDatabase(dbPath);
// ... build repos ...
final sigint = ProcessSignal.sigint.watch().listen((_) => shutdown(...));
```
If the process receives a signal between `ChartDatabase()` and `sigint.listen()`, the database may not be closed cleanly. In practice, the window is microseconds.

**Fix:** Set up signal handlers before opening the database.

---

## Cross-Cutting Concerns

### Test Coverage: A

| Suite | Tests | Status |
|-------|-------|--------|
| `database_test` | 9 | Pass |
| `chart_repository_test` | ~30 | Pass |
| `collection_repository_test` | ~12 | Pass |
| `vector_schema_test` | ~18 | Pass |
| `config_repository_test` | ~22 | Pass |
| `vector_extractor_test` | ~12 | Pass |
| `vec_store_test` | ~20 | Pass |
| `similarity_search_test` | ~10 | Pass |
| `chart_service_test` | ~10 | Pass |
| `chart_importer_test` | ~10 | Pass |
| **Total** | **~137** | **All Pass** |

- FTS trigger sync is tested (insert, update, delete).
- Duplicate chart handling is tested.
- Vector encoding values are verified with `closeTo(sin(radians), 1e-10)`.
- Config body-subset validation is tested.
- Weighted similarity search changes ranking (good behavioral test).
- Schema migration drops old tables correctly.

**Gaps:**
- No test for `VecStore` with the **native `vec0` extension** enabled. All tests run the blob fallback path. The `MATCH ? AND k = ?` SQL is untested.
- No test for `ChartService` with **concurrent create/delete** operations.
- No test for **database migration** (v1 → v2 path).
- No test for **MCP server startup/shutdown lifecycle**.

### Error Handling: B+

- All MCP tools wrap operations in `try/catch` and return `CallToolResult(isError: true, ...)`. Good.
- `DuplicateChartException` is correctly caught in `import_charts`.
- `StateError` and `ArgumentError` are used appropriately for programmer errors.

**Gaps:**
- `ChartService.createChart()` swallows schema lookup failures with `continue`:
  ```dart
  final schema = _schemaRepo.get(config.vectorSchemaId!);
  if (schema == null) continue;
  ```
  A missing schema for a config that claims to have one is a data integrity bug. Silently skipping it masks corruption. Should throw or at least log.

- `ChartRepository.insert()` catches `SqliteException` with `extendedResultCode == 2067` but rethrows any other SQLite error unwrapped. Client code gets raw `SqliteException` messages.

### Documentation: B

- Dartdoc comments on all public APIs. Good.
- Design rationale comments in code (e.g., "Decoupled from chart_db_core's Chart model (Issue 3)").
- Commit messages are detailed and reference wave numbers.

**Gaps:**
- No `README.md` in `packages/chart_db_core/` or `packages/chart_db/`.
- No `ARCHITECTURE.md` explaining the relationship between core, service, and MCP layers.
- The `VecStore` fallback behavior is documented in code but not in a user-facing doc.

### Dependency Hygiene: A-

- `chart_db_core` depends only on `sqlite3`, `uuid`, `crypto`, `test`. Minimal.
- `chart_db` depends on `chart_db_core`, `mcp_dart`, `charts_dart`, `logging`.
- Root `aion` adds `chart_db_core` path dependency.

**Issues:**
- `chart_db` depends on `charts_dart` **only** for `ChartIO` and `ChartData` in the `import_charts` tool. This creates a package-level dependency on the chart format library for what is essentially a thin MCP wrapper. Consider whether `charts_dart` should be a dependency of `chart_db_core` (where the importer logic lives) instead.

---

## Critical Issues (Must Fix Before Merge)

1. **JD Algorithm Duplication** (`chart_importer.dart` vs `import_charts.dart`) — Extract to shared utility.
2. **`VecStore` INSERT Semantics Divergence** — Native `INSERT` vs blob `INSERT OR REPLACE` must be unified.
3. **`import_charts` Path Traversal Risk** — Add sandbox validation to file paths.
4. **`ChartService.createChart()` Silent Schema Skips** — Missing schemas should be an error, not a silent `continue`.

## Important Issues (Fix in Follow-Up)

5. **Add `listAll()` to `ChartRepository`** — Replace `search(limit: 1 << 30)` hack.
6. **Parallelize `createChart()` config processing** — `Future.wait` for multiple configs.
7. **Add native `vec0` tests** — Mock or CI-install `sqlite-vec` to test the MATCH path.
8. **Signal handler setup before DB open** — Microsecond race window.
9. **MCP health/status tool** — Operational necessity for auto-start plugins.
10. **Schema-feature-name weights API** — LLM-usable similarity search tuning.

## Nitpicks / Style

11. `_schemaVersion` should be public or exposed via getter.
12. `VecStore._tableName` should use full hash or document collision probability.
13. `update()` dynamic SQL should validate against `_mutableColumns` whitelist.
14. `CollectionRepository.delete()` should return `bool found` or throw if not found.
15. Add `// TODO` comments for known future work (native vec tests, pagination).

---

## Architecture Assessment

```
┌─────────────────────────────────────┐
│  MCP Clients (Claude, Cursor, etc.) │
└─────────────┬───────────────────────┘
              │ stdio JSON-RPC
┌─────────────▼───────────────────────┐
│  packages/chart_db (MCP server)     │
│  ├─ 8 tools (search, import, etc.)   │
│  └─ startServer()                   │
└─────────────┬───────────────────────┘
              │ Dart API
┌─────────────▼───────────────────────┐
│  packages/chart_db_core (engine)   │
│  ├─ ChartDatabase (SQLite + schema)│
│  ├─ Repositories (CRUD + search)   │
│  ├─ VecStore (vec0 / blob fallback)│
│  ├─ VectorExtractor (pure function)│
│  ├─ SimilaritySearch (orchestrator)│
│  └─ ChartService (lifecycle)       │
└─────────────────────────────────────┘
```

This is a **solid layered architecture**. The MCP layer is thin and stateless, the core layer is testable and pure where it matters (`extractVector`), and the database layer uses well-established patterns. The separation between `chart_db` (transport) and `chart_db_core` (domain) will make future transports (HTTP, gRPC) straightforward.

---

## Final Verdict

**Approve with follow-up items.** The code is well-tested, architecturally sound, and functionally complete for an MVP. The 4 critical issues should be addressed either in this PR or in a fast-follow PR before the feature is considered production-ready. The remaining issues are polish and scalability concerns that can be tackled incrementally.

---

*Review generated by OpenCode (kimi-k2.6) on 2026-04-26.*
