# aion code map

## lib/ directory index

| dir | purpose |
|---|---|
| `actions/` | One-shot async ops: file pick + chart bind. Return sealed result types. |
| `canvas/` | Workspace geometry: card layout, drag/resize, snap physics, edit mode, multi-select, arrangement geometry, Riverpod notifier; concrete canvas/card/slot registry actions (`canvas_actions.dart`). |
| `commands/` | Action registry: `AppAction`, `ActionRegistry`, fuzzy matcher, menu resolution, renderer-generated view actions. Imports only `renderer/chart_renderer.dart` (metadata) — never `canvas/` or renderer implementations. |
| `config/` | `ConfigDimension` model, Arrow dimension inventory, config value helpers, `ConfigEditor` + `showConfigDialog`. |
| `highlight/` | Linked highlighting: `HighlightState`, transitions, `highlightProvider`, scope per slot. |
| `import/` | Parse `.toml` chart files into `ImportedChart` structs. |
| `mcp/` | Plugin lifecycle (stdio MCP transport), chart store, expression caching, observable state streams. |
| `providers/` | Riverpod wiring: `PluginHost`, `ChartStore`, `RendererRegistry`, `ActionRegistry`. |
| `renderer/` | Abstract renderer contract (+ highlight entities, detail levels, alias table) + registry + host widget. |
| `renderer/south_indian/` | South Indian grid renderer (4x4 CustomPainter). |
| `renderer/data_table/` | Tabular planet data renderer (CustomPainter text table). |
| `shell/` | App chrome over the registry: rail + flyouts (catalog, slots, workspaces), command palette, settings panel, text prompt. |
| `slots/` | Chart slots (app-session state): `ChartSlot`, `CardBinding`, `SlotState`, expression resolution. Imports `mcp/` only — never `canvas/` or `renderer/`. |
| `theme/` | `AionTheme` extension with all color tokens (incl. slot palette, highlight color), `ThemeResolver` (display options, card status strip). |
| `widgets/` | Leaf UI: `TitleBar`, `PluginStatus`. |
| `workspaces/` | Saved layouts: `Workspace` model + TOML codec, `WorkspaceStore`, `workspaceLibraryProvider`, starters, workspace registry actions. |

## Key types

**actions/**
- `loadChartFromFile()` -> `LoadChartResult` (ChartLoadedOk | ChartLoadCancelled | ChartLoadFailed)
- `bindChartToCard()` -> `BindChartResult` (ChartBound | BindFailed)

**canvas/**
- `CardModel` — position, size, `binding` (`CardBinding?`), `configOverride`, `kind` (chart | settings), rendererType, preferredAspectRatio, displayConfig, display overrides
- `WorkspaceState` — ordered card list, selectedId + `multiSelectedIds` (`selection`), snap guides, `editMode`, `layoutEpoch`
- `WorkspaceNotifier` — Riverpod notifier; all card mutations (move/resize gated on edit mode), `replaceCards`, `arrangeSelection`, `openSettingsCard`
- `CanvasWorkspace` — root widget; pointer dispatch, rail/flyouts, palette (Ctrl+K), context menus (registry consumers), layout animation
- `CanvasCard` — per-card widget; slot strip + pin, corner grips (edit mode), binding resolution, renderer host, settings panel
- `SnapPhysics` — edge-snapping geometry (threshold 12px)
- `arrangement.dart` — `gridShape`, `tileGrid`, `alignRects`, `distributeRects` (pure)
- `canvas_actions.dart` — `buildCanvasActions(ref)`, `cardMenuIds`, `canvasMenuIds`, `defaultCardSize`, `cascadePosition`

**slots/**
- `ChartSlot` — id, label, colorIndex (into `AionTheme.slotPalette`), chartId?, chartName?, config
- `CardBinding` — sealed: `SlotBinding(slotId)` | `PinnedBinding(chartId, chartName?, config)`
- `SlotState` / `SlotsNotifier` — slots + active slot; default slot `A` always exists
- `resolveCardExpression(binding, slots, configOverride)` → `ResolvedExpression` (chartId, canonical config, `ExpressionRef`); `ensureExpression` kicks the unchanged `ChartStore` compute path; `boundToSlot`, `pinnedBindingFor`, `canonicalConfig`

**commands/**
- `AppAction` — id, title, menuTitle?, category, aliases, icon, isEnabled, isChecked?, requiresCard, execute
- `ActionContext` — cardId?, position?, viewportSize?, onError, editConfig, promptText (UI callbacks)
- `ActionRegistry` — register/get/inCategory/categories/search/execute
- `rankActions` / `scoreAction` — alias > title > prefix > word > substring > fuzzy
- `viewActionsFromRenderers`, `resolveMenu`, `popupEntries`

**highlight/**
- `HighlightState` — entity, scope, locked; `highlightsFor(scope)`
- `HighlightTransitions` — hover / click (lock, unlock) pure transitions; `highlightScopeFor(binding)`

**workspaces/**
- `Workspace` / `WorkspaceCard` — layout template (no chart data); `toToml` / `fromToml`; `toCard` resolves dangling slot ids to `A`
- `WorkspaceStore` — `<app support>/workspaces/*.toml`, `active.txt`
- `WorkspaceLibrary` / `WorkspaceLibraryNotifier` — starters + user workspaces, save-as/load/rename/delete, `openInitial`
- `kStarterWorkspaces` — Natal Reading, Chart Focus

**shell/**
- `Rail`, `FlyoutPanel`, `railProvider` (`RailSection`), `CatalogFlyout`, `SlotsFlyout`, `WorkspacesFlyout`
- `showCommandPalette`, `paletteEntries` (categories | ranked actions)
- `SettingsPanel` (Theme / Display / General tabs), `showTextPrompt`

**config/**
- `ConfigDimension`, `kDimensions`, `kGroups` (Arrow inventory)
- `configValue` / `setConfigValue` / `formatConfigValue` / `sectionStage` (pure)
- `ConfigEditor` (embeddable), `showConfigDialog` (anchored)

**mcp/**
- `PluginHost` — manages stdio MCP sessions per plugin
- `ChartStore` — loads charts, dispatches `computeExpression`, caches as streams
- `ExpressionRef` — identity key (chartId + configHash)
- `ExpressionState` -> ExpressionIdle | ExpressionLoading | ExpressionReady | ExpressionError

**renderer/**
- `ChartRenderer` (abstract) — meta + displayOptions + createPainter
- `ChartPainter` (abstract, extends CustomPainter) — paint + hitTestChart
- `RendererMeta` — id, displayName, systems, preferredAspectRatio, category, aliases, detailLevels
- `DetailLevel` + `selectDetailLevel(levels, size)` — semantic zoom
- `HighlightEntity` -> PlanetEntity | HouseEntity | SignEntity (`highlight.dart`); `ChartPainter.entityForHit`
- `renderer_aliases.dart` — varga (d1–d60) and dasha alias tables
- `ChartHitResult` -> PlanetHit | HouseHit
- `RendererRegistry` — register/get/forSystem/all
- `RendererHost` — StatefulWidget; resolves config defaults, manages painter lifecycle (single change check), picks detail level from size, passes highlights in / entity hover+tap out, popup overlay

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
| `slotsProvider` | `NotifierProvider<SlotsNotifier, SlotState>` | `slots/slot_state.dart` |
| `actionRegistryProvider` | `Provider<ActionRegistry>` (rebuilt when slots / workspace names change) | `providers/action_registry_provider.dart` |
| `highlightProvider` | `NotifierProvider<HighlightNotifier, HighlightState>` | `highlight/highlight_state.dart` |
| `railProvider` | `NotifierProvider<RailNotifier, RailSection?>` | `shell/rail_state.dart` |
| `workspaceStoreProvider` | `Provider<WorkspaceStore>` | `workspaces/workspace_store.dart` |
| `starterWorkspacesProvider` | `Provider<List<Workspace>>` | `workspaces/workspace_store.dart` |
| `workspaceLibraryProvider` | `AsyncNotifierProvider<WorkspaceLibraryNotifier, WorkspaceLibrary>` | `workspaces/workspace_store.dart` |

## Data flow: chart into a slot → every bound card renders

```
slot.load.<id> / slot.load_chart / view.open_chart.*   canvas/canvas_actions.dart
  loadChartFromFile() -> store.loadChart(chartId, doc)   actions/load_chart_action.dart
  bindChartToCard(store, result, config: slot config)    actions/bind_chart_action.dart
    (validates the chart computes; reports BindFailed via ActionContext.onError)
  slotsNotifier.setChart(slotId, chartId, chartName)     slots/slot_state.dart

CanvasCard.build (every card watches slotsProvider)     canvas/canvas_card.dart
  resolveCardExpression(card.binding, slots, override)  slots/expression_resolution.dart
    slot chart + (card override ?? slot config) -> canonical config -> ExpressionRef
  ensureExpression(store, resolved)  (microtask; only if idle)
    store.computeExpression(chartId, 'drishti', 'calculate_chart', config)
  store.watchExpression(ref) -> ExpressionReady(data)
  RendererHost(renderer, [data], highlights, ...)
    LayoutBuilder -> selectDetailLevel(meta.detailLevels, size)
    renderer.createPainter(expressions, config, colors, displayOpts,
                           highlights, detailLevel) -> ChartPainter
```

Workspace switch: `WorkspaceLibraryNotifier.load(name)` → `Workspace.cards[i].toCard(slots)` → `WorkspaceNotifier.replaceCards` (ids reused, `layoutEpoch`++ → animated). Slots are untouched, so the loaded chart flows into the new layout.

## Test structure

```
test/canvas/     workspace_notifier_test.dart, edit_mode_test.dart, arrangement_test.dart
test/import/     chart_importer_test.dart
test/mcp/        plugin_host_test.dart
test/integration/ drishti_test.dart
test/renderer/   chart_renderer_test.dart, south_indian_renderer_test.dart,
                 data_table_renderer_test.dart, renderer_host_test.dart,
                 semantic_zoom_test.dart, test_expressions.dart
test/slots/      slot_resolution_test.dart, slot_strip_test.dart
test/commands/   action_registry_test.dart
test/config/     config_values_test.dart (+ config_dimension_test.dart)
test/shell/      rail_test.dart, palette_entries_test.dart, slots_panel_test.dart,
                 settings_card_test.dart
test/workspaces/ workspace_test.dart, workspace_switch_test.dart,
                 starter_workspaces_test.dart
test/highlight/  highlight_state_test.dart, highlight_rendering_test.dart
```
