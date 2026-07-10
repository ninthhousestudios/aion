# Enforcement Ledger

Tracks every architectural constraint: what it guards, why, and how it got here.
Maintained by `vidhi-sutra-tend` at review checkpoints.

## Live constraints

### Package DAG

| Name | Kind | Severity | Provenance | Added |
|---|---|---|---|---|
| `chart-model-no-core` | forbidden_dep | blocking | docs/adr/001-typed-expression-boundary.md | seed |
| `chart-model-no-db` | forbidden_dep | blocking | docs/adr/001-typed-expression-boundary.md | seed |
| `chart-model-no-app` | forbidden_dep | blocking | docs/adr/001-typed-expression-boundary.md | seed |
| `core-no-mcp-wrapper` | forbidden_dep | blocking | (implicit) | seed |
| `core-no-app` | forbidden_dep | blocking | (implicit) | seed |
| `chart-db-no-app` | forbidden_dep | blocking | docs/chart-db-design.md | seed |
| `app-uses-core-not-tools` | forbidden_dep | blocking | docs/chart-db-design.md | seed |

### App layer boundaries

| Name | Kind | Severity | Provenance | Added |
|---|---|---|---|---|
| `mcp-no-canvas` | forbidden_dep | blocking | docs/mcp-spine-architecture.md | seed |
| `mcp-no-widgets` | forbidden_dep | blocking | docs/mcp-spine-architecture.md | seed |
| `mcp-no-renderer` | forbidden_dep | blocking | docs/mcp-spine-architecture.md | seed |
| `mcp-no-providers` | forbidden_dep | blocking | docs/mcp-spine-architecture.md | seed |
| `renderer-no-mcp` | forbidden_dep | blocking | docs/architecture-plan-overview.md | seed |
| `renderer-no-canvas` | forbidden_dep | blocking | docs/architecture-plan-overview.md | seed |

### Cycle prevention

| Name | Kind | Severity | Scope | Added |
|---|---|---|---|---|
| `tools-no-cycles` | no_cycles | blocking | packages/chart_db/lib/src/tools/ | seed |
| `providers-no-cycles` | no_cycles | blocking | lib/providers/ | seed |
| `theme-no-cycles` | no_cycles | blocking | lib/theme/ | checkpoint:aion/81 |
| `canvas-no-cycles` | no_cycles | blocking | lib/canvas/ | checkpoint:aion/81 |
| `renderer-no-cycles` | no_cycles | blocking | lib/renderer/ | checkpoint:aion/81 |

### Language rules (coding_discipline)

| Name | Kind | Severity | Scope | Added |
|---|---|---|---|---|
| `no-dynamic-type` | forbidden_pattern | advisory | lib/ | checkpoint:aion/81 (fired aion/82) |
| `no-bang-null-assertion` | forbidden_pattern | advisory | lib/ | checkpoint:aion/81 (fired aion/82) |

## Deferred constraints

| Intent | Kind | Trigger | Status | Notes |
|---|---|---|---|---|
| `slot-model-no-canvas` | forbidden_dep | aion/63 lands | pending | ChartSlot is session-state data, not presentation. Path TBD. |
| `slot-model-no-renderer` | forbidden_dep | aion/63 lands | pending | Renderers receive slot context through RendererHost. Path TBD. |
| `registry-no-canvas` | forbidden_dep | aion/65 lands | pending | ActionRegistry is a coordination layer, not a canvas component. Path TBD. |
| `registry-no-renderer` | forbidden_dep | aion/65 lands | pending | Registry references RendererMeta, not renderer implementations. Path TBD. |
| `no-dynamic-type` | forbidden_pattern | tree-sitter-dart grammar validated | **fired** | Grammar fixed (aion/82): `((type_identifier) @match (#eq? @match "dynamic"))`. Moved to live. |
| `no-bang-null-assertion` | forbidden_pattern | tree-sitter-dart grammar validated | **fired** | Grammar fixed (aion/82): node is `null_assertion_expression`, not `postfix_expression`. Moved to live. |

## Maintenance log

| Date | Checkpoint | Summary |
|---|---|---|
| 2026-07-10 | aion/81 | First tend pass. Backfilled ledger from rules.toml. Added 3 no_cycles (theme, canvas, renderer). 2 language catalog rules (no-dynamic-type, no-bang-null-assertion) deferred — tree-sitter-dart grammar queries need validation. 4 deferred constraints for workspace model (aion/~4 slots-registry phase). Zero violations, zero drift. Conventions: all 97 FCA entries are structural tautologies — no promotions. |
