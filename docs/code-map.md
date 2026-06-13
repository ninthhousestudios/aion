# aion code map

## lib/ directory index

| dir | purpose |
|---|---|
| `actions/` | One-shot async ops: file pick + chart bind. Return sealed result types. |
| `canvas/` | Workspace geometry: card layout, drag/resize, snap physics, Riverpod notifier. |
| `import/` | Parse `.toml` chart files into `ImportedChart` structs. |
| `mcp/` | Plugin lifecycle (stdio MCP transport), chart store, expression caching, observable state streams. |
| `providers/` | Riverpod wiring: `PluginHost`, `ChartStore`, `RendererRegistry`. |
| `renderer/` | Abstract renderer contract + registry + host widget. |
| `renderer/south_indian/` | South Indian grid renderer (4x4 CustomPainter). |
| `renderer/data_table/` | Tabular planet data renderer (CustomPainter text table). |
| `theme/` | `AionTheme` extension with all color tokens. |
| `widgets/` | Leaf UI: `TitleBar`, `PluginStatus`. |

## Key types

**actions/**
- `loadChartFromFile()` -> `LoadChartResult` (ChartLoadedOk | ChartLoadCancelled | ChartLoadFailed)
- `bindChartToCard()` -> `BindChartResult` (ChartBound | BindFailed)

**canvas/**
- `CardModel` — position, size, expressions, rendererType, preferredAspectRatio, displayConfig
- `WorkspaceState` — ordered card list, selectedId, snap guides
- `WorkspaceNotifier` — Riverpod notifier; all card mutations
- `CanvasWorkspace` — root widget; pointer dispatch, context menu, chart-open flow
- `CanvasCard` — per-card widget; corner grips, renderer host
- `SnapPhysics` — edge-snapping geometry (threshold 12px)

**mcp/**
- `PluginHost` — manages stdio MCP sessions per plugin
- `ChartStore` — loads charts, dispatches `computeExpression`, caches as streams
- `ExpressionRef` — identity key (chartId + configHash)
- `ExpressionState` -> ExpressionIdle | ExpressionLoading | ExpressionReady | ExpressionError

**renderer/**
- `ChartRenderer` (abstract) — meta + displayOptions + createPainter
- `ChartPainter` (abstract, extends CustomPainter) — paint + hitTestChart
- `RendererMeta` — id, displayName, systems, preferredAspectRatio
- `ChartHitResult` -> PlanetHit | HouseHit
- `RendererRegistry` — register/get/forSystem/all
- `RendererHost` — StatefulWidget; resolves config defaults, manages painter lifecycle, popup overlay

**packages/chart_model/**
- `ChartExpression` — planets, ascendant, houses, ascmc
- `Planet` — id, name, longitude, sign, signIndex, degreeInSign, retrograde, nakshatra, nakshatraPada, house, dignity?
- `House` — number, signIndex, cuspLongitude
- `Ascendant` — signIndex, longitude

**packages/chart_db_core/**
- `ChartRepository`, `ChartService` — SQLite persistence + search

## Riverpod providers

| provider | type | file |
|---|---|---|
| `pluginHostProvider` | `Provider<PluginHost>` | `providers/plugin_host_provider.dart` |
| `pluginStateProvider` | `StreamProvider.family<PluginState, String>` | `providers/plugin_host_provider.dart` |
| `chartStoreProvider` | `Provider<ChartStore>` | `providers/chart_store_provider.dart` |
| `rendererRegistryProvider` | `Provider<RendererRegistry>` | `providers/renderer_registry_provider.dart` |
| `workspaceProvider` | `NotifierProvider<WorkspaceNotifier, WorkspaceState>` | `canvas/workspace_notifier.dart` |

## Data flow: file to render

```
loadChartFromFile()                  actions/load_chart_action.dart
  file_selector -> toml path
  TomlChartCodec.decodeFile() -> ChartDoc
  store.loadChart(chartId, doc)

bindChartToCard(store, loadResult)   actions/bind_chart_action.dart
  store.computeExpression(chartId, 'drishti', 'calculate_chart', config)
    PluginHost.callTool() -> json
    json.decode -> ChartExpression.fromJson()     chart_store.dart:128-130
  -> ChartBound(chartName, expressionRef, rendererType)

CanvasWorkspace._openChartAs()       canvas/canvas_workspace.dart
  workspace.addCard(pos, size, name,
    expressions: [ref], rendererType, preferredAspectRatio)

CanvasCard._buildRenderer()          canvas/canvas_card.dart:77
  registry.get(rendererType) -> ChartRenderer
  store.watchExpression(ref) -> ExpressionReady(data)
  RendererHost(renderer, [data], displayConfig)
    renderer.createPainter(expressions, config) -> ChartPainter
    CustomPaint(painter)
```

## Test structure

```
test/canvas/     workspace_notifier_test.dart
test/import/     chart_importer_test.dart
test/mcp/        plugin_host_test.dart
test/integration/ drishti_test.dart
test/renderer/   chart_renderer_test.dart, south_indian_renderer_test.dart,
                 data_table_renderer_test.dart, test_expressions.dart
```
