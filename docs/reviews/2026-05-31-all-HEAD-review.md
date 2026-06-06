# Code Review: aion @ all-of-HEAD (`e883a4e`)

**Date:** 2026-05-31
**Scope:** all of HEAD on `main` (32 commits, first review). App shell `lib/`, `packages/chart_db` MCP server, `packages/chart_db_core` engine.
**Verdict:** **hold for fixes**

The bar is one Critical contract violation (`charts` hard-uniqueness contradicts the stated natural-key invariant) plus a red regression net on the most actively-churned subsystem. Neither is large to fix, but both should land before a release tag. The rest is ship-with-follow-ups material.

## Verification

- **Build:** implicit pass (full app + path packages compiled clean under `flutter test`).
- **Tests:** **FAIL — 90 pass / 6 fail** (app). All 6 in `test/canvas/*`, stale after `10958e1`. `chart_db_core` 172/172 pass. `packages/chart_db` MCP server: **0 tests**.
- **Lint:** 2 `info` (leading-underscore locals in two `chart_db_core` test files). No warnings/errors.
- **Format:** drift in 24 of 42 app files — cosmetic (author writes >80-col lines), not a version mismatch.

I trust the pack's verification; I did not re-run anything.

## Design

The three-layer model (Canvas geometry → Card bindings → Workspace/Chart store) is sound and the "core has zero astrological knowledge" contract genuinely holds in `lib/`: nothing in the canvas or store layer knows what a planet is; domain data flows through opaque `Map<String,dynamic>` Expression payloads pulled from plugins via `PluginHost`. The Expression/Config/Card/Renderer separation in CONTEXT.md is respected at the type level — `ExpressionRef` is a pure `(chartId, configHash)` pair, Cards reference Expressions declaratively, and the renderer registry keys off a string `rendererType`. That's the part of the design that earns its keep.

Where the design does **not** hold up is at the **storage contract**. CONTEXT.md is explicit on two invariants: (1) "TOML files are the source of truth for Charts; sqlite index and vectors are derived, rebuildable artifacts," and (2) the natural key `(jd,lat,lon)` is "used for deduplication hints, **not hard uniqueness** — two Charts may share a natural key with different metadata." The implementation contradicts both. `charts` has a hard `UNIQUE(jd,lat,lon)` constraint (`database.dart:76`) and the only write path (`import_charts._importFile`) inserts straight into sqlite via `ChartRepository.insert` — it never writes a canonical TOML, never routes through `TomlChartCodec` or `ChartService`. So sqlite is currently the *primary* store, not a derived one, and the natural key is *hard*-unique. The TOML-as-truth half is plausibly in-progress scaffolding (the codec exists, the write path doesn't yet) and I've scored it low-confidence. The hard-uniqueness half is a shipped, enforced constraint that directly violates a stated invariant and silently collapses legitimately-distinct Charts — that's the Critical.

The second design smell is **two parallel implementations of the same seam, only one wired**. `ChartStore` (wired, used by the canvas) and `WorkspaceStore` (unwired, only its own test references it) are near-identical PluginHost wrappers with copy-pasted `_compute`/JSON-decode logic. Likewise `lib/import/ChartImporter` (tested, unwired) duplicates the ChartData→Chart mapping that `import_charts._importFile` reimplements by hand. Both pairs are kept alive only by their dedicated test files, so they can — and the importer already did — drift from the wired version with green tests the whole way. This is new state space (two code paths) without a constraint surface (nothing forces them to agree). The fix is to delete the unwired twin in each pair, not to maintain both.

No ADRs exist, so CONTEXT.md is the only normative source; I'm treating its storage section as binding rather than as a settled-and-reopenable ADR.

## Findings

```yaml
- id: charts-hard-unique-violates-natural-key-contract
  severity: critical
  category: contract
  title: charts UNIQUE(jd,lat,lon) contradicts the "not hard uniqueness" invariant and silently drops Charts
  location: packages/chart_db_core/lib/src/database.dart:76 (+ chart_repository.dart:115-153, import_charts.dart:127-141)
  evidence: |
    Schema: `UNIQUE(jd, lat, lon)`. ChartRepository.insert catches SQLITE_CONSTRAINT_UNIQUE (2067)
    and throws DuplicateChartException; import_charts treats that as "skipped_duplicate".
    CONTEXT.md (Storage): "Natural key (jd, lat, lon) ... Used for deduplication hints, not hard
    uniqueness — two Charts may share a natural key with different metadata (name, tags, notes).
    Collisions at JD precision are rare but must be handled."
  why: |
    The domain contract says two distinct Charts (e.g. twins, or a birth and an unrelated event
    computed to the same JD/location) may legitimately share the natural key. The schema makes that
    impossible: the second import is silently swallowed as a duplicate and its metadata is lost. This
    is data loss against an explicitly-documented allowed case, and it is enforced at the lowest layer
    so no caller can opt out.
  recommendation: |
    Drop the UNIQUE constraint; keep (jd,lat,lon) as a non-unique index for dedup *hints*. Move the
    dedup decision up to the import layer: on natural-key collision, surface the existing chart and let
    the caller choose (skip / import-as-distinct / merge). If a uniqueness guard is wanted short-term,
    it must include enough metadata to distinguish twins (e.g. name) — but per CONTEXT the right answer
    is a hint, not a constraint. Either way the schema change must precede any release that imports data.
  confidence: high

- id: red-canvas-regression-net
  severity: high
  category: correctness
  title: 6 stale canvas tests leave the most-churned subsystem with no working regression net
  location: test/canvas/workspace_notifier_test.dart, test/canvas/workspace_state_test.dart
  evidence: |
    All 6 failures assert the pre-10958e1 defaults (first card 'Chart Wheel', snap-on, empty initial
    cards). Production now seeds 'Planet Table' first, snap defaults off (workspace_state.dart:20), and
    WorkspaceNotifier.build seeds 4 cards. canvas_workspace.dart (churn 7) is the highest-churn app file.
  why: |
    A red suite is an off suite. While these specific failures are stale-assertion noise, the suite being
    red means a *real* regression in WorkspaceNotifier (move/snap/duplicate/delete/z-order) would not be
    caught — CI either ignores the suite or is already failing, so new breakage is invisible. For a
    release gate this is the headline process blocker.
  recommendation: |
    Update the 6 assertions to the new defaults in the same commit as any further default-layout change.
    Then add one guard test that pins the *seeded card count and snap-default* so the next layout edit
    fails loudly instead of silently. Do not snapshot the full default layout (too brittle); pin the
    invariants that matter.
  confidence: high

- id: duplicate-store-and-importer-only-one-wired
  severity: high
  category: design
  title: WorkspaceStore and lib/import/ChartImporter are unwired twins of the live code paths
  location: lib/mcp/workspace_store.dart, lib/providers/workspace_providers.dart, lib/import/chart_importer.dart
  evidence: |
    WorkspaceStore + workspaceStoreProvider + expressionProvider have zero consumers outside their own
    files and workspace_store_test.dart; the canvas uses ChartStore/chartStoreProvider, whose _compute()
    is a near-verbatim copy of WorkspaceStore.recalculate(). lib/import/ChartImporter._mapToImported is
    duplicated by import_charts._importFile (which reimplements the mapping rather than reusing it).
  why: |
    Two implementations of one seam with nothing forcing them to agree. The importer pair has *already*
    drifted (the wired MCP handler hand-rolls the ChartData→Chart map instead of calling ChartImporter),
    and both unwired twins stay green via their own tests, so the rot is invisible. This is exactly the
    "new state space without a constraint surface" failure mode. It also misleads the next maintainer
    about which path is canonical.
  recommendation: |
    Pick the wired path in each pair and delete the twin: remove WorkspaceStore + its providers + test
    (ChartStore supersedes it); collapse import_charts._importFile to call ChartImporter, or delete
    ChartImporter if the MCP server is the only importer. If WorkspaceStore is intended as a future
    multi-Expression store, say so in a comment and gate it behind a real consumer — don't leave it
    floating. (mv to /tmp per repo deletion policy.)
  confidence: high

- id: config-id-not-canonicalized-breaks-idempotency
  severity: medium
  category: correctness
  title: create_config hashes the raw preset string, so logically-equal configs get distinct ids
  location: packages/chart_db_core/lib/src/config_repository.dart:62-65, 110-135
  evidence: |
    `_presetHash` = sha256(utf8(presetJson)) of the *raw* string; the comment says "not canonicalized".
    CONTEXT.md (Config): "Two Configs are equal when their content hashes match." Idempotency relies on
    byte-identical input.
  why: |
    The same logical config serialized with different key order or whitespace produces a different id →
    a duplicate config row → duplicate vectors under similarity search → "idempotent" registration that
    isn't. Clients (the app, any third-party plugin) have no contract telling them to byte-normalize first.
  recommendation: |
    Canonicalize before hashing: parse the JSON, sort keys recursively, re-encode, then sha256. This is
    exactly what the app already does in ChartStore._sortedValue — lift that into a shared helper so
    both sides agree (see config-hash-two-schemes). Reject unparseable preset_json with a clear error
    rather than hashing garbage.
  confidence: high

- id: config-hash-two-schemes
  severity: medium
  category: contract
  title: ExpressionRef.configHash and Config.id are different hashing schemes for "the config hash"
  location: lib/mcp/chart_store.dart:162-175 vs packages/chart_db_core/lib/src/config_repository.dart:62
  evidence: |
    App side: ExpressionRef.configHash = json.encode(canonical-sorted config map) — the literal sorted
    JSON string, not a digest. DB side: Config.id = sha256(raw preset string). CONTEXT.md refers to a
    single notion of "content hash."
  why: |
    Two values both colloquially "the config hash" that can never be equal (one is canonical sorted JSON,
    the other a non-canonical sha256). Today they live in separate namespaces so nothing breaks, but the
    moment anything tries to correlate an ExpressionRef with a persisted Config (e.g. caching computed
    Expressions keyed by Config.id) the mismatch becomes a silent cache miss or a wrong-key bug. The name
    "configHash" is also a misnomer — it's the canonicalized config, not a digest.
  recommendation: |
    Define one canonical-hash function (canonicalize → sha256) in a shared location and use it on both
    sides; make ExpressionRef.configHash actually be that digest. Until unified, rename the app field to
    `configKey` so it doesn't read as the same thing as Config.id.
  confidence: medium

- id: canvas-edge-snap-unreachable
  severity: medium
  category: correctness
  title: Canvas-edge snapping is dead — live drags always pass Size.zero
  location: lib/canvas/canvas_workspace.dart:192 (+ snap_physics.dart:31-34, workspace_notifier.dart:117)
  evidence: |
    _handleCardPointerMove calls moveCard(id, delta, Size.zero) with default applySnap:true.
    SnapPhysics.snap only adds canvas edges (0,width,height) as targets `if (!canvasSize.isEmpty)`, so
    with Size.zero only card-to-card snapping ever runs in production.
  why: |
    A designed feature (snap to canvas bounds) is unreachable through the only path that triggers it.
    Lower impact now that snap defaults off, but it's a latent correctness gap and the snap_physics
    branch is untestable through the real call site. Note also the math is questionable: snap is computed
    in workspace coords while canvasSize would be viewport-sized, and the canvas is an infinite pannable
    surface — "snap to origin" may not even be a coherent feature here.
  recommendation: |
    Either thread the real viewport Size from the LayoutBuilder/RenderBox into moveCard, or — if
    edge-snapping isn't wanted on an infinite canvas — delete the canvasSize parameter and the dead
    branch in SnapPhysics.snap rather than leaving a feature half-wired. Decide which; don't ship both.
  confidence: high

- id: chartdb-mcp-server-untested
  severity: medium
  category: correctness
  title: 8 MCP tool handlers (the entire plugin wire surface) have zero tests
  location: packages/chart_db/lib/src/tools/*.dart
  evidence: |
    No test/ dir in packages/chart_db; `test` declared as dev_dependency but unused. The handlers own all
    input validation, the args→repo arg mapping, and the wire JSON keys (snake_case) that the app and
    third-party plugins depend on.
  why: |
    This is the contract boundary between core and plugins — the one place CONTEXT.md's glossary becomes
    wire keys. It's also where untyped Map<String,dynamic> args get cast (e.g. similar_charts casts
    args['weights'] to Map<String,dynamic> with no type guard — a JSON array there throws and is caught
    only by the outer try as a generic "Similarity search failed"). Untested + untyped + the layer most
    likely to be hit by a misbehaving client is a bad combination for a release.
  recommendation: |
    Add a test/ with an in-memory ChartDatabase covering: each tool's happy path, missing/empty required
    args, and at least one malformed-type arg per tool (string where number expected, array where object
    expected). chart_db_core is already well-tested, so these tests are cheap — they exercise the thin
    handler + the schema/handler agreement, which is the actual untested risk.
  confidence: high

- id: plugin-host-restart-leak
  severity: low
  category: correctness
  title: startPlugin on an already-running plugin overwrites the client without closing the old one
  location: lib/mcp/plugin_host.dart:68-86, 79
  evidence: |
    startPlugin sets state to starting, builds a new client, and on success does
    `_clients[manifest.name] = client` — if a client for that name already exists (manual restart, or a
    second startAll), the previous client is replaced and never closed; its onclose still points at the
    same name and may fire _onUnexpectedClose after the new one connects.
  why: |
    Leaked subprocess + a stale onclose that can flip a freshly-connected plugin into error state. Only
    reachable via restart/double-start, which is why it's Low, but startAll is called from initState and
    a hot-reload or future "restart plugin" button would hit it.
  recommendation: |
    At the top of startPlugin, if `_clients[name]` exists, await stopPlugin(name) first (or guard against
    re-entrancy while status==starting). Capture the client in onclose by identity so a superseded client's
    close can't mutate the new state.
  confidence: medium

- id: collections-sqlite-vs-sidecar-json
  severity: low
  category: contract
  title: Collections stored in sqlite, not the documented sidecar _collections.json
  location: packages/chart_db_core/lib/src/database.dart:80-95, collection_repository.dart
  evidence: |
    CONTEXT.md (Collection): "Stored in a sidecar _collections.json." Implementation uses a `collections`
    table + `chart_collections` join in sqlite.
  why: |
    Minor now (no external consumer of the sidecar yet), but it contradicts the documented storage shape,
    and CONTEXT's whole premise is that sqlite is rebuildable/derived — collections-in-sqlite means
    collection membership is *not* rebuildable from TOML, so a "delete the db and re-import" recovery
    (implied by "sqlite is derived") silently loses collections.
  recommendation: |
    Either update CONTEXT.md to make sqlite the home for collections (and drop the "derived/rebuildable"
    framing for them), or move collection membership to the sidecar as documented. Pick one and align doc
    and code — the current split means the recovery story is wrong either way.
  confidence: medium
```

## Synthesis

**Root cause vs symptom.** There are two root causes and the rest are symptoms or independent.

1. **The storage contract was never enforced as documented.** `charts-hard-unique-violates-natural-key-contract` (Critical), `collections-sqlite-vs-sidecar-json` (Low), and the TOML-as-truth gap noted in Design all stem from the same thing: the schema/import layer was built as a sqlite-primary store while CONTEXT.md describes a TOML-primary, sqlite-derived, hint-based-dedup store. Fixing the hard-uniqueness constraint is the urgent slice; the rest is a doc-vs-code reconciliation that should happen at the same time so CONTEXT stops being aspirational.

2. **Duplicated seams with no agreement constraint.** `duplicate-store-and-importer-only-one-wired` (High), `config-id-not-canonicalized` (Medium), and `config-hash-two-schemes` (Medium) are all "same concept, two implementations, nothing forces them to match." The config-hash pair is the sharpest example: the app *already has* the canonical-hash logic the DB needs, but they were written independently. Unifying the hash function fixes both config findings at once.

The remaining findings — `red-canvas-regression-net`, `canvas-edge-snap-unreachable`, `chartdb-mcp-server-untested`, `plugin-host-restart-leak` — are independent and don't share a root.

**Fix order.**

1. **`charts-hard-unique`** first — it's the only Critical, it's a one-line schema change plus moving the dedup decision up to import, and it gates any release that touches real data. Do the CONTEXT reconciliation (collections, TOML-as-truth) in the same PR while the storage model is in your head.
2. **`red-canvas-regression-net`** second — cheap, and you want a green net *before* you start deleting the duplicate store/importer in step 3, so the deletions are covered.
3. **`duplicate-store-and-importer`** third — delete the unwired twins. This shrinks the surface for everything after.
4. **Config hashing** (`config-id-not-canonicalized` + `config-hash-two-schemes`) fourth — unify into one canonical-hash helper. Do them together; they're the same fix.
5. **`chartdb-mcp-server-untested`** fifth — add the handler tests. Cheap given chart_db_core's coverage, and they'll catch the `similar_charts` weights cast and any schema/handler drift.
6. **`canvas-edge-snap`** and **`plugin-host-restart-leak`** last — decide snap's fate (wire it or delete the branch); add the restart guard when a restart UI lands.

## Slop list

**Feature-introduced / divergence slop (this is the actionable set):**

1. `lib/mcp/workspace_store.dart` (whole file, 77 LOC) — unwired duplicate of `ChartStore`. Only consumer is `workspace_store_test.dart`. Remove with its providers.
2. `lib/providers/workspace_providers.dart` — `workspaceStoreProvider` + `expressionProvider`, zero external consumers. Remove with the store.
3. `lib/import/chart_importer.dart` (whole file, 132 LOC: `ChartImporter` + `ImportedChart`) — tested by `test/import/chart_importer_test.dart` but unwired; the live `import_charts._importFile` reimplements its mapping. Collapse to one path.
4. `lib/canvas/canvas_workspace.dart:130-132` — `_viewportDeltaToWorkspace` is an identity function (returns its arg). Either it's a stub for future zoom scaling (comment it) or dead indirection (inline it).
5. `lib/canvas/canvas_workspace.dart:192` — `Size.zero` passed as canvasSize on every live drag (see `canvas-edge-snap-unreachable`).
6. `packages/chart_db/pubspec` — `test` declared as dev_dependency but no `test/` dir exists (see `chartdb-mcp-server-untested`).
7. Format drift in 24 of 42 app files — cosmetic; run `dart format` in a standalone commit so it doesn't pollute review diffs.

**Pre-existing / noted-in-passing:**

8. `packages/chart_db_core/lib/src/vector_extractor.dart` (max_cog 28) — dense but linear feature-block structure; not a refactor emergency, but the `assert`-only length check (line 128) means a dimension mismatch passes silently in release builds. Consider a real throw, since a wrong-length vector corrupts similarity search.
9. `lib/mcp/expression_state.dart` — the field is named `options` in the state classes but `args` everywhere it's constructed; minor naming inconsistency.

**Sutra false-positive note for the pack-build filter:** The pack's dead-code section correctly filtered the 11 MCP `_handle`/`_errorResult` and the 26 unreachable-by-design files. However, it concluded "no production `lib/` file showed a genuine dead-code problem" — that's a **miss**: `WorkspaceStore`, its two providers, and `lib/import/ChartImporter` are production `lib/` code that is unreachable from `main()`/the widget tree and kept alive *only* by their own test files. sutra_dead can't see this because (a) the providers are referenced within their own declaration file and (b) a `*_test.dart` import counts as a use in the graph. Recommend the pack-build filter treat "imported only by a `*_test.dart` and never from the runtime entrypoint" as a *candidate* dead-code signal rather than auto-clearing anything a test touches.
