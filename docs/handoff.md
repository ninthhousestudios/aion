# Handoff

## Status

chart-db implementation complete (12 issues, 5 waves, 168 tests). Two code
reviews received and triaged. Next step: implement review fixes.

## What to pick up

Run the chart-db review fix pass. Prioritized list below — do batch 1
first, then batch 2.

### Batch 1: Quick fixes (do first)

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 1 | Extract `dateTimeToJd` into chart_db_core utility, remove duplicates from `chart_importer.dart` and `import_charts.dart` | `packages/chart_db_core/lib/src/julian_day.dart` (new), `lib/import/chart_importer.dart`, `packages/chart_db/lib/src/tools/import_charts.dart` | Small |
| 2 | Add `ChartRepository.listAll()` — simple `SELECT * FROM charts`, replace `search(limit: 1<<30)` hack in `chart_service.dart` | `chart_repository.dart`, `chart_service.dart` | Small |
| 3 | Unify VecStore INSERT — native path uses `INSERT`, blob uses `INSERT OR REPLACE`. Both should use `INSERT OR REPLACE`. | `vec_store.dart` | Trivial |
| 4 | Add `CREATE INDEX IF NOT EXISTS idx_charts_jd ON charts(jd)` | `database.dart` (in `_createTables`), bump `_schemaVersion` to 2 | Trivial |
| 5 | Add `rebuildFts()` method to ChartDatabase | `database.dart` | Trivial |
| 6 | Fix silent schema skip — `ChartService.createChart()` does `continue` when schema is null for a config that claims one. Should throw. | `chart_service.dart` | Trivial |
| 7 | Add `publish_to: none` to `chart_db_core/pubspec.yaml` | `pubspec.yaml` | Trivial |
| 8 | Extract shared `_errorResult` into `packages/chart_db/lib/src/tools/tool_utils.dart`, import from all 8 tool files | Tool files in `packages/chart_db/lib/src/tools/` | Small |

### Batch 2: Medium effort fixes

| # | Fix | Files | Effort |
|---|-----|-------|--------|
| 9 | Add recursive parameter to `importDirectory` (default true) | `chart_importer.dart`, `import_charts.dart`, tests | Small |
| 10 | Transaction wrapping for ChartService — two-phase pattern: compute vectors async first, then write chart + vectors in single transaction. Add `transaction()` helper to ChartDatabase. Thread DB handle through repos. | `database.dart`, `chart_service.dart`, all repositories | Medium |
| 11 | Consolidate import logic — MCP `import_charts` tool should use ChartImporter instead of reimplementing field mapping. May require moving ChartImporter to chart_db_core or having chart_db depend on aion's lib. | `import_charts.dart`, possibly `chart_importer.dart` | Medium |
| 12 | Import path sandbox — validate file paths in `import_charts` MCP tool against allowed directory | `import_charts.dart` | Small |
| 13 | Canonicalize config preset JSON before hashing (currently inconsistent with schema hashing) | `config_repository.dart` | Small |
| 14 | Tag normalization — lowercase on insert | `collection_repository.dart` | Trivial |
| 15 | MCP health/status tool | `packages/chart_db/lib/src/tools/status.dart` (new), `server.dart` | Small |

### Reviews for reference

- `doc/reviews/glm51-chartdb-review.md` — GLM-5.1 review
- `doc/reviews/kimik26-chartdb-review.md` — Kimi-K2.6 review

## Key context

- **Raw sqlite3 confirmed** (not Drift) — decision in Chitta
- **arjuna** is a sibling repo at `../arjuna`, not inside aion
- **charts_dart** is a sibling at `../charts_dart`
- Transaction wrapping: use two-phase pattern (compute outside tx, write inside tx). See Chitta observation for details.
- UNIQUE(jd, lat, lon) is correct — do NOT relax it (confirmed with Josh)
- Recursive import is a real need — Josh had to flatten nested chart dirs manually

## Blockers

None.
