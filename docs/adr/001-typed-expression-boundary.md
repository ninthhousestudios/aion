# ADR-001: Typed expression boundary

## Status

Accepted (2026-06-06)

## Context

MCP plugin output (drishti's `calculate_chart`) enters aion as raw `Map<String, dynamic>`. Multiple consumers — renderers, the vector extractor, the chart store — each independently reach into this map with hardcoded string keys. `ExpressionKeys` documented the expected shape but enforced nothing. The vector extractor in chart_db_core had divergent key names (`house_number` vs `house`, `is_retrograde` vs `retrograde`) that passed tests only because its fixture was self-consistently wrong.

## Decision

Introduce a `packages/chart_model` package containing typed data classes (`ChartExpression`, `Planet`, `Ascendant`, `House`, `AscMc`) with `fromJson` factories. Parse once at the `ChartStore` boundary when MCP tool results arrive. All downstream consumers — renderers and the vector extractor — receive typed objects, not raw maps.

### Key choices

- **Domain-specific types** (not generic map wrappers). Renderers are built-in, not MCP plugins, so astrological data types (planet, house, nakshatra) belong in the shared model.
- **Separate package** (`packages/chart_model`) rather than placing types in the app or in `chart_db_core`. Both the app and chart_db_core depend on this package, keeping the dependency direction clean.
- **Parse at the boundary** (ChartStore._compute). Single parse point, early failure on schema drift.

## Consequences

- `ExpressionKeys` is removed — the typed fields replace string constants.
- The vector extractor's divergent keys are fixed as a side effect (the typed model enforces the canonical shape).
- Adding a new field to drishti output requires updating `ChartExpression.fromJson` and the relevant data class — one place, compile-checked.
- Nakshatra names (strings from drishti) are mapped to indices via `nakshatraToIndex` for vector encoding.
