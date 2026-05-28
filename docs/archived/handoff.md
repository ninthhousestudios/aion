# handoff

2026-04-24

## current state

- **mcp spine** — implemented and hardened. plugin host, workspace store,
  providers, plugin status UI. 15 unit + 3 integration tests green.
  see `doc/mcp-spine-architecture.md`.
- **drishti** — built. bundled MCP server wrapping arrow via vayu.
  auto-starts with aion, exposes `calculate_chart` tool.
- **mundus** — built. registered as bundled plugin. design and plan at
  `~/nhs/soft/astrology/mundus/`.
- **gui-spike** — started in `gui-spike/`. canvas with draggable/resizable
  cards, snap physics. patterns being validated before integration.
- **chart-db** — designed, not implemented. see `doc/chart-db-design.md`.

## next up

**chart-db implementation plan.** the design doc covers the storage
architecture (toml source of truth, sqlite index, config-aware vector
schema, profile model, in-process core + MCP wrapper). next session
should turn that into a concrete implementation plan — package
structure, dependency wiring, migration strategy, which pieces to
build first.

## key design decisions for chart-db

- chart-db-core is an in-process dart package (not MCP for UI access).
  MCP wrapper for AI/plugin access only. same pattern as vayu/drishti.
- chart natural key is (jd, lat, lon). vectors are per (chart, config)
  pair where config = hash(ArrowOptions).
- tags go in toml files, collections in a sidecar `_collections.json`.
- vector extraction logic lives in chart-db-core, not drishti.
- sqlite-vec for KNN, with dart-side cosine similarity as fallback.
- text embeddings are chitta's concern, not chart-db's.
- config deletion purges vectors immediately (derived, recomputable).
- rectification variants are distinct charts, grouped via collections.

## open items

- mcp_dart fork pinned to commit `0cfec14`. PR #90 upstream — check
  merge status periodically, switch to pub.dev when merged.
- `PluginConfig` JSON file I/O is implemented but unused (only bundled
  manifests used). will matter when user-installed plugins are supported.
- OAS name settled: "open astrology society" (updated in `../oas/`).
