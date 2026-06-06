# ADR-003: Chart binding as a plain function

## Status

Accepted (2026-06-06)

## Context

The entire Chart→Expression→Card lifecycle (load file, compute expression, add card with renderer) was embedded in a `switch` arm of the context-menu handler in `canvas_workspace.dart`. Four string literals were hardcoded: `'drishti'` (plugin), `'calculate_chart'` (tool), `const {}` (config), `'south_indian'` (renderer type). The binding logic was untestable without driving a widget.

## Decision

Extract into `bindChartToCard()` — a plain Dart async function with named parameters and defaults:

```dart
Future<BindChartResult> bindChartToCard(
  ChartStore store, {
  String server = 'drishti',
  String tool = 'calculate_chart',
  Map<String, dynamic> config = const {},
  String rendererType = 'south_indian',
})
```

Returns a sealed result type (`ChartBound | BindFailed | BindCancelled`). The context-menu handler becomes a thin caller that positions the card.

A class, provider, or declarative config was considered but deferred — there is one call site today, and the function signature is the seam for future renderer-picker UI.

## Consequences

- The defaults (`'drishti'`, `'calculate_chart'`, `'south_indian'`) are visible and greppable as function parameter defaults.
- When a renderer picker UI is added, the caller passes an explicit `rendererType` — the default becomes a fallback, then eventually dead.
- The binding logic is testable without Flutter widget infrastructure.
