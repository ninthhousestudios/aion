# Workspace model: implementation tasks

Task specs for implementing `docs/prd-workspace-model.md`, exported from the
local issue tracker (yojana) so they can be worked without it. Task ids
(`aion/N`) are the tracker's ids — use them in commit messages so work can be
reconciled back.

The PRD is the source of truth for intent. This doc is the source of truth for
scope, order, and acceptance criteria. Where the two disagree, note it in the
log at the bottom and follow the PRD.

## Working rules

**Order.** Work the tasks in the order listed. It is a topological order of
the dependency graph — each task's `Depends on` is satisfied by the tasks
above it.

**Definition of done, per task:**

1. `flutter analyze` reports no errors or warnings introduced by the task.
2. `flutter test --exclude-tags integration` passes. (Integration tests need a
   local drishti checkout and cannot run here.)
3. New pure-logic tests for the task's model/logic, per the PRD's Testing
   Decisions: **pure logic only, no widget or golden tests.**
4. Acceptance-criteria checkboxes below ticked (`[x]`) in this doc, in the
   same commit.
5. One commit per task: `aion/N: <task title>`. Commit before moving on. A
   task too big for one commit may take several, all prefixed `aion/N:`.

**When stuck or ambiguous:** don't stop. Pick the most conservative option
consistent with the PRD, record the question and your choice in the log at the
bottom, and continue. If a task is genuinely blocked, mark it `BLOCKED` in its
heading with the reason, and skip it — plus anything depending on it.

**Codebase conventions** (normally enforced by local tooling that is not
available here, so you are the enforcement):

- All UI colors from `AionTheme` (`lib/theme/aion_theme.dart`). Never hardcode
  colors. Add tokens to `AionTheme` when needed.
- No `dynamic` or implicit `Object` to escape typing — use generics or explicit
  interfaces.
- Don't use `!` to silence null errors — use `??`, `?.`, or an explicit null
  check. (The existing `Theme.of(context).extension<AionTheme>()!` idiom is the
  one sanctioned exception.)
- No `// ignore:` / `// ignore_for_file:`. Fix the diagnostic.
- `const` constructors wherever possible; cascades and collection-if/for over
  imperative list/map building.
- Reuse over duplication: if logic exists elsewhere, reuse it (widen
  visibility or extract a helper) rather than copying it.
- Read `docs/code-map.md` before starting and keep it accurate: update it when
  you add directories, key types, or providers.

**Layering constraints** (pending enforcement rules, see
`docs/enforcement-ledger.md`):

- The slot model (aion/63) must not import from `lib/canvas/` or
  `lib/renderer/`. It is session-state data, not presentation.
- The ActionRegistry (aion/65) must not import from `lib/canvas/` or renderer
  *implementations*. It may reference renderer metadata (`RendererMeta`,
  registry lookup). If `RendererMeta` lives somewhere that makes this
  impossible without importing implementations, move the metadata type
  rather than break the rule, and log it.
- Record the directories you choose for the slot model and registry in the
  log so the rules can be bound to real paths later.

**Out of scope for this run:** time cursor (aion/78, aion/79 — needs a design
decision in the drishti repo), chart entry and chart browser (aion/16,
aion/20), and everything in the PRD's Out of Scope section.

---

## Phase 0 — prerequisite fix

### aion/61 — RendererHost rebuild: fix staleness and reduce unnecessary painter recreation

*Bug. Depends on: nothing. Files: `lib/renderer/renderer_host.dart`, `lib/canvas/canvas_card.dart`.*

Done first because highlighting (aion/76) and semantic zoom (aion/80) both
extend `RendererHost`.

Two related issues in `RendererHost`:

1. **Stale painter state.** `RendererHost.build()` only rebuilds the painter
   when colors change. It relies entirely on `didUpdateWidget` for
   `displayOpts` changes. If `didUpdateWidget` and `build()` ordering causes
   the painter to miss a `displayOpts` update, the card renders with stale
   display options (sign glyphs toggled via context menu intermittently revert
   on right-click).
2. **Excessive painter recreation.** `widget.expressionData != old.expressionData`
   in `didUpdateWidget` uses list identity, but `[data]` in
   `CanvasCard._buildRenderer` allocates a new list every time
   `StreamBuilder.builder` runs (hover, selection, any parent rebuild). The
   painter is recreated on every rebuild even when expression data hasn't
   changed, causing visible lag on renderer switch.

Fix approach:

- Track `_lastDisplayOpts` (and possibly `_lastExpressionData`) in
  `_RendererHostState` and check them in `build()` as a safety net.
- Compare `expressionData` by content (length + identical elements) rather
  than list identity in `didUpdateWidget`.
- Consider caching the `[data]` list in `CanvasCard._buildRenderer` to avoid
  allocating a new list on every `StreamBuilder` emission with the same data.

Acceptance criteria:

- [x] Toggling display overrides (sign glyphs, planet glyphs) via the card context menu is stable across repeated right-clicks
- [x] Painter is not recreated when `expressionData` content is unchanged
- [x] Switching renderers via context menu has no perceptible lag beyond initial paint

---

## Phase 1 — slots + action registry

### aion/63 — ChartSlot model + card slot binding + expression resolution

*Depends on: nothing. Foundation for almost everything below.*

Core model layer for chart slots (PRD §Chart slots). `ChartSlot`: id, label,
color, optional chartId, expression config. It is app-session state, not
workspace state. `CardModel` binding becomes a sealed type:
`SlotBinding(slotId)` | `PinnedBinding(chartId, config)`. Resolution: slot's
chart + (card config override ?? slot config) → `ExpressionRef` → the existing
ChartStore compute/cache path (unchanged). A default slot A always exists;
loading a chart with no slot targeted lands in the active slot.

This inverts the old per-card-independent config default: config lives on the
slot, and a per-card override is the opt-in exception.

Acceptance criteria:

- [x] `ChartSlot` model + slot state provider; default slot A guaranteed to exist
- [x] `CardModel` binding is sealed `SlotBinding | PinnedBinding`; existing expression field migrated
- [x] Resolution composes card override ?? slot config correctly into `ExpressionRef`
- [x] Slot chart/config change recomputes exactly its bound cards; pinned cards unaffected
- [x] Pure-logic tests: resolution composition, propagation scoping, pin behavior
- [x] Slot model directory respects the layering constraint; path recorded in the log

### aion/64 — Slot UI: status strip color, pin indicator, card menu slot actions

*Depends on: aion/63.*

Surface slots on cards (PRD §Chart slots). The card status strip shows the
slot color. This amends the theme PRD: the strip now encodes the link group,
not chart identity. Pinned cards show a pin indicator in the strip. The card
context menu gains a bind-to-slot submenu and pin/unpin. The settings card
(not chart-bound) keeps no strip.

Acceptance criteria:

- [x] Card status strip painted with slot color, resolved via the `ThemeResolver` path
- [x] Pin indicator on pinned cards
- [x] Card context menu: bind-to-slot submenu + pin/unpin actions
- [x] Slot recolor/relabel reflects immediately on bound cards

### aion/65 — ActionRegistry + alias table; ContextMenuService becomes a consumer

*Depends on: aion/63.*

One action registry behind all surfaces (PRD §Action registry).
`ActionRegistry`: actions with id, title, category, aliases, icon, enablement,
execute. Sources: renderer registry (add view per renderer), slot ops,
workspace ops, quick toggles, settings. A domain alias table (d1–d60, dasha
names, common abbreviations) lives alongside `RendererMeta`. Fuzzy matching
over titles + aliases, with ranking. The existing context menus are
refactored to consume the registry rather than define actions in parallel.
**No user-visible menu changes.**

*Note:* the PRD and tracker call the current menu code "`ContextMenuService`",
but no such class exists. The card and canvas menus are built inline in
`lib/canvas/canvas_workspace.dart` (`showMenu`, restructured in aion/50) with
supporting logic in `lib/canvas/workspace_notifier.dart`. Those are what
becomes a registry consumer.

Acceptance criteria:

- [x] `ActionRegistry` model with enablement + execute; generation from renderer registry, slot ops, workspace ops, toggles
- [x] Domain alias table (d1–d60, dashas) attached to renderer meta
- [x] Fuzzy matcher with ranking; unit tests for alias and fuzzy hits
- [x] Card and canvas context menus consume the registry; existing menu behavior preserved
- [x] Registry directory respects the layering constraint; path recorded in the log

### aion/53 — Expression config dialog

*Depends on: aion/63. Builds on the `ConfigDimension` model (already landed).*

Progressive-disclosure config dialog with collapsible sections grouped by
intent, using the existing `ConfigDimension` model, with a cheap-vs-expensive
(SweConfig vs CalcConfig) indicator. The dialog edits either a **slot's**
expression config (opened from the slots panel, aion/68) or a **per-card
override** (opened from the card context menu). There is no global default
expression config any more; slot config replaces it.

Acceptance criteria:

- [x] Dialog renders collapsible sections from `ConfigDimension` groups
- [x] Collapsed sections show dimension name + current value
- [x] Expanded sections show the full option list appropriate to the type
- [x] SweConfig vs CalcConfig indicator visible on sections
- [x] Dialog anchors near the source card when opened from the context menu
- [x] Dialog can be embedded (not only shown as a modal)
- [x] Changing a value calls back with the updated config
- [x] Card context menu entry opens it as a per-card override editor

---

## Phase 2 — rail + command palette

### aion/67 — Rail: persistent edge strip + flyout framework + view catalog

*Depends on: aion/65.*

The mouse-first primary surface (PRD §Rail). Slim persistent left rail;
sections open as flyouts (one at a time, click-away dismiss). No permanent
side panels. First flyout: the view catalog, a browsable grid grouped by
category (charts, vargas, tables, time) generated from the ActionRegistry.
Clicking a view adds a card bound to the active slot. The rail also hosts
buttons for slots, workspaces, and settings, wired up as those features land
below. Leave a disabled placeholder for time (out of scope for this run).
All colors via `AionTheme`.

Acceptance criteria:

- [x] Persistent slim rail with flyout framework (single open flyout, dismiss on click-away/Esc)
- [x] View catalog flyout: category-grouped grid from ActionRegistry
- [x] Clicking a catalog entry adds a card bound to the active slot
- [x] New renderers appear in the catalog with no catalog changes (registry-driven)

### aion/25 — Command palette (Ctrl+K) over ActionRegistry

*Depends on: aion/65. Rail button requires aion/67.*

Overlay opened by Ctrl+K or a rail button. Fuzzy match over ActionRegistry
titles + domain aliases ("d9" → Navamsa, "vim" → Vimshottari). Empty query
shows clickable categories so mouse-first users can browse — the same actions
as the rail, one mental model. Reuse the aion/65 matcher; don't write a second
one.

Acceptance criteria:

- [x] Ctrl+K and a rail button open the palette overlay
- [x] Fuzzy matching over titles + aliases with sensible ranking
- [x] Empty query shows clickable category browsing
- [x] Enter/click executes the action (add view to active slot, workspace ops, toggles)

### aion/68 — Slots panel flyout: load chart, label/color, active slot, config entry

*Depends on: aion/53, aion/63, aion/67.*

Rail flyout for managing slots (PRD §Rail, §Chart slots). Lists slots with
color + label; rename and recolor inline; load a chart into a slot (file
picker for now, since the chart browser comes later); set the active slot;
entry point to the slot's expression config (the aion/53 dialog).

Acceptance criteria:

- [x] Slots panel lists slots with color + editable label
- [x] Load chart into a slot from the panel; bound cards update
- [x] Active slot selection; add/remove slots (slot A cannot be removed)
- [x] Opens the slot expression config dialog

### aion/57 — Settings card

*Depends on: aion/67 (rail button). Uses the existing theme/display system.*

The settings card is a regular canvas card that isn't bound to a chart. Opens
at ~80% window size, resizable/movable, with no slot color strip. Tabs: Theme,
Display, General. There's no Expression Defaults tab because slot config
replaces the global default.

*Reconciled with the PRD:* the tracker's original criteria referenced an
Expression Defaults tab, an "apply to all" button, and a canvas-force
modifier. All three belong to the superseded interaction-model PRD and are
dropped. It opens from the rail settings button and the palette, not the
canvas context menu.

Acceptance criteria:

- [x] Settings card opens from the rail settings button and the palette (registered in ActionRegistry)
- [x] Opens at ~80% window size, resizable and movable
- [x] No slot color strip
- [x] Tabbed interior: Theme, Display, General
- [x] Theme and Display tabs wired to the existing theme/display system
- [x] Settings card can remain open while the user works

---

## Phase 3 — workspaces + edit mode

### aion/70 — Workspace model + TOML persistence + save/load

*Depends on: aion/63.*

Workspaces are layout templates (PRD §Workspaces). `Workspace`: name + card
list (renderer type, geometry, slot binding, per-card overrides). **No chart
data** — charts flow through via slots. TOML persistence in the config
directory, consistent with theme presets (see the existing `PresetStore`).
On load, dangling slot ids resolve to the default slot.

Acceptance criteria:

- [x] Workspace model captures renderer type, geometry, slot binding, per-card overrides — no chart data
- [x] TOML round-trip tests; unknown keys tolerated
- [x] Save current layout as named workspace; load restores it
- [x] Dangling slot ids resolve to the default slot instead of erroring

### aion/71 — View/edit mode: layouts locked by default, explicit edit mode

*Depends on: aion/65.*

The daily-use plane is a locked layout (PRD §Workspaces and edit mode). View
mode (default): card drag/resize disabled; interactions are content-level
only. Edit mode: the existing drag/resize/snap physics enabled, corner grips
visible. Toggle registered in the ActionRegistry (reachable from rail,
palette, canvas menu).

Acceptance criteria:

- [x] View mode: drag/resize/grips disabled; content interaction (hover/click/scroll) unaffected
- [x] Edit mode: existing drag/resize/snap behavior intact
- [x] Mode toggle via ActionRegistry with a clear visual affordance of which mode is active
- [x] Canvas context menu reduced to add-view, edit-mode toggle, workspace operations (PRD story 28)

### aion/72 — Arrangement commands: tile selection as grid, align, distribute

*Depends on: aion/71.*

Edit-mode arrangement verbs (PRD §Workspaces and edit mode). Multi-select
cards, then tile the selection into an N-cell grid, align edges, or distribute
spacing. Requires a card multi-select model (marquee or shift-click).
Geometry is pure functions over rects, tested without widgets.

Acceptance criteria:

- [x] Card multi-select (shift-click and/or marquee) in edit mode
- [x] Tile selection into a grid (sensible rows×cols for N cards)
- [x] Align edges + distribute spacing commands, registered in ActionRegistry
- [x] Pure-logic tests for tiling/align/distribute geometry

### aion/73 — Workspace switcher in rail + animated transitions

*Depends on: aion/67, aion/70.*

Rail flyout listing workspaces. Switching swaps the layout with animated card
transitions. Slot assignments are app-session state and survive the switch,
so the loaded client flows into the new layout.

Acceptance criteria:

- [x] Workspace switcher flyout in the rail (save-as, rename, delete)
- [x] Switching preserves slot assignments; cards resolve against live slots
- [x] Animated card transitions on switch

### aion/74 — Starter workspaces

*Depends on: aion/70, aion/73.*

Ship read-only starter workspace templates so first launch shows a working
instrument, not an empty canvas. Size the initial set to the available
renderers (e.g. Natal Reading, Varga Overview). "Save as" forks a template
into a user workspace.

Acceptance criteria:

- [x] At least two starter workspaces built from currently available renderers
- [x] Starters are read-only; save-as forks to a user workspace
- [x] First launch opens into a starter workspace

---

## Phase 4 — linked highlighting

### aion/76 — HighlightState provider + renderer highlight channel

*Depends on: aion/63, aion/61.*

State model for linked highlighting (PRD §Linked highlighting).
`HighlightState`: highlighted entity (planet, house, sign), slot scope,
transient (hover) vs locked (click). `RendererHost` passes the highlight set
into painters via a renderer-contract extension. Scope v1: cards of the same
slot. Cross-slot (synastry) is deferred, but the state model must not
preclude it. Hit-testing (`ChartHitResult`) already exists; this adds the
outbound channel.

Acceptance criteria:

- [ ] `HighlightState` provider: entity, slot scope, transient vs locked
- [ ] Renderer contract extension: painters receive the highlight set via `RendererHost`
- [ ] Tests: same-slot scoping, hover → locked → clear transitions

### aion/77 — Highlight rendering + hover/click/Esc interactions in renderers

*Depends on: aion/76.*

Wire linked highlighting through the two existing renderers. Hovering an
entity sets a transient highlight in all same-slot cards (glyph emphasis in
the south indian grid, row emphasis in the data table). Click locks the
highlight; Esc clears it. Emphasis styling comes from `AionTheme` tokens.

Acceptance criteria:

- [ ] South indian renderer paints entity emphasis from the highlight set
- [ ] Data table renderer emphasizes matching rows
- [ ] Hover → transient, click → locked, Esc → clear, across same-slot cards

---

## Phase 5 — semantic zoom

### aion/80 — Semantic zoom: detail levels in RendererMeta + host selection

*Depends on: aion/61.*

Card size selects detail level (PRD §Semantic zoom). `RendererMeta` gains
ordered detail levels with size thresholds; `RendererHost` selects the level
from the card's rendered size and passes it to the painter. v1: south indian
(occupancy → +degrees → +nakshatra/dignity), data table (core columns → full
columns). New renderers get the behavior by contract.

Acceptance criteria:

- [ ] `RendererMeta` declares ordered detail levels with size thresholds
- [ ] `RendererHost` selects level from rendered size; painter receives it
- [ ] South indian: 3 levels; data table: 2 levels
- [ ] Threshold boundary tests

---

## Log: decisions, questions, deviations

Append entries as you go: `aion/N — <what> — <why>`. Include every ambiguity
you resolved yourself, every PRD deviation, chosen directory paths for the
layering constraints, and anything that needs a human to verify visually.

- aion/61 — RendererHost now keeps a single change check in `build()` (colors, expression list by content via `expressionListsEqual`, displayConfig, renderer, displayOpts) and dropped `didUpdateWidget`; CanvasCard caches the `[data]` list — one check path means no ordering gap between didUpdateWidget and build. **Needs visual check:** glyph-toggle stability across right-clicks, no renderer-switch lag.
- aion/63 — Slot model lives in `lib/slots/` (`chart_slot.dart`, `card_binding.dart`, `slot_state.dart`, `expression_resolution.dart`); imports only `lib/mcp/`, riverpod and chart_db_core — no `lib/canvas/` or `lib/renderer/`. Bind the layering rule to `lib/slots/**`.
- aion/63 — `ChartSlot.color` is stored as `colorIndex` into a theme palette (AionTheme slot palette, added in aion/64) rather than a raw `Color`, so slot colors follow the theme and the model stays presentation-free.
- aion/63 — `CardModel.expressions: List<ExpressionRef>` replaced by `binding: CardBinding?` + `configOverride`. A card now has exactly one binding (PRD's sealed type); the old multi-expression 'synastry card' shape is dropped until a synastry renderer exists. Tests in `test/canvas/card_model_test.dart`, `workspace_state_test.dart`, `workspace_notifier_test.dart`, `workspace_accent_test.dart` were migrated from `expressions` to `binding` (behavior they test changed shape, not intent).
- aion/63 — Configs are canonicalized (keys sorted, sets→sorted lists) before hashing so equal configs share one `ExpressionRef`; `ChartStore` is unchanged. Cards resolve their binding in `CanvasCard` on every build (watching `slotsProvider`) and `ensureExpression` triggers compute via a microtask only when the resolved ref is idle — so a slot change recomputes exactly its bound cards and pinned cards are untouched. Opening a chart from the canvas menu loads it into the active slot and adds a slot-bound card.
- aion/63 — Default slot config is `{}` (drishti's defaults), matching the previous `bindChartToCard` default.
- aion/64 — Per-chart accents (`WorkspaceState.chartAccents`, `cycleChartAccent`, hardcoded palette in WorkspaceNotifier) removed; the palette moved to `AionTheme.slotPalette` and the strip is resolved by `ThemeResolver.stripFor(card, slots)`. `test/canvas/workspace_accent_test.dart` deleted (the per-chart accent behavior it tested no longer exists; replaced by `test/slots/slot_strip_test.dart`). 'Cycle Color' in the card menu now recolors the card's slot.
- aion/64 — Card menu uses a flat 'slot binding' section (one checked item per slot) rather than a nested submenu: `showMenu` has no submenu support and the flat list keeps one-right-click access. Unpin rebinds to the *active* slot (PRD's PinnedBinding carries no origin slot). Pinned cards show a neutral (`cardDimColor`) strip plus a pin icon. **Needs visual check:** strip color, pin icon placement, immediate recolor on bound cards.
- aion/65 — Registry lives in `lib/commands/` (`app_action.dart`, `action_registry.dart`, `action_matcher.dart`, `view_actions.dart`, `action_menu.dart`); it imports only `lib/renderer/chart_renderer.dart` (for `RendererMeta`) — no `lib/canvas/`, no renderer implementations. Bind the layering rule to `lib/commands/**`. No metadata move was needed. The concrete canvas/card/slot actions are built in `lib/canvas/canvas_actions.dart` (they need the workspace notifier) and assembled by `actionRegistryProvider` in `lib/providers/`.
- aion/65 — `RendererMeta` gained `category` (default 'Charts') and `aliases`; the domain alias table (d1–d60 vargas, dasha abbreviations) is `lib/renderer/renderer_aliases.dart`. Category names are plain strings shared with `ActionCategory` so `lib/renderer` does not import `lib/commands`.
- aion/65 — Workspace ops in the registry at this point: Add Card, Snap to Edges; save/switch/edit-mode/arrange actions are added by aion/70–73. Menu layouts are id lists (`cardMenuIds`, `canvasMenuIds`); disabled actions are hidden rather than greyed, matching the old conditional menu sections. The menus are otherwise unchanged apart from the slot section added in aion/64. The old inline `_openSiblingCard`/`_openChartAs` moved into registry actions. **Needs visual check:** card/canvas menus look and behave as before.
- aion/53 — Editor is `ConfigEditor` (embeddable) + `showConfigDialog` in `lib/config/config_editor.dart`; pure helpers in `lib/config/config_values.dart`. Configs store only non-default values (untouched = `{}`), multi-selects as sorted JSON lists. Cost mapping: `ConfigCost.expensive` → 'SweConfig' badge, `cheap` → 'CalcConfig', mixed sections → 'Swe + Calc' (the tracker didn't define the mapping; expensive dimensions are the ephemeris-level ones). Changes apply live on every edit (no OK/Cancel).
- aion/53 — Surfaces open the dialog through `ActionContext.editConfig` (a callback the UI supplies), so registry actions stay free of `BuildContext`. Card menu gained 'Expression Config…' and 'Clear Config Override'; slot config is `slot.config.<id>`. **Unverified assumption:** dimension keys (`signAyanamsa`, `houseSystem`, …) are passed to drishti's `calculate_chart` as-is — needs checking against the drishti tool schema. **Needs visual check:** dialog anchoring near the card, section collapse/expand, dropdown/switch/chip controls.
- aion/67 — Rail + flyouts live in `lib/shell/` (`rail.dart`, `rail_state.dart`, `catalog_flyout.dart`). The rail is a 44px strip under the title bar inside `CanvasWorkspace`'s stack; the canvas viewport now starts offset by the rail width so cards don't begin under it. Flyouts: one at a time (`railProvider`), dismissed by click-away (transparent barrier), Esc, or re-clicking the rail button. The rail's active-slot button carries a dot in the active slot's color. Time button is a disabled placeholder (out of scope). Catalog tiles run the registry's add-view action, which adds a card bound to the active slot. **Needs visual check:** rail look, flyout placement, click-away/Esc dismissal, catalog tile grid.
- aion/25 — Palette is `lib/shell/command_palette.dart` (overlay via `showGeneralDialog`) with pure listing logic in `lib/shell/palette_entries.dart`, reusing `rankActions` from aion/65 — no second matcher. Empty query lists categories (with counts); clicking one scopes the list; Backspace on an empty query leaves the category. Actions run with the *selected* card as target, so card actions appear only when a card is selected. Opened by Ctrl+K (canvas keyboard handler) and the rail's search button. **Needs visual check:** Ctrl+K focus handling, arrow/Enter navigation, hover highlight, category chip.
- aion/68 — Slots flyout is `lib/shell/slots_flyout.dart`. Per-row: active radio, color swatch (click cycles through the theme slot palette — no free color picker, conservative choice given colors are palette indexes), inline label edit (renames live), chart name, load (file picker), config (aion/53 dialog), remove (not for A). Load/config/remove go through registry actions (`slot.load.<id>`, `slot.config.<id>`, `slot.remove.<id>`) so they're also reachable from the palette. Removing a slot leaves its cards' `SlotBinding` dangling; they resolve (and color) as slot A. **Needs visual check:** row layout, label editing, and that loading a chart into a slot updates every bound card (PRD story 1).
- aion/57 — Settings card = `CardModel(kind: CardKind.settings)` (new `CardKind` enum, default `chart`), unbound so it gets no strip; interior is `lib/shell/settings_panel.dart` (Theme: preset list via `presetStoreProvider`; Display: global glyph/outer-planet toggles via `displayOptionsProvider`, using a new `DisplayOptions.copyWith`; General: snap toggle — edit mode added in aion/71). Opened by `settings.open` (rail settings button, palette); a second open re-selects the existing card instead of adding another. Size = 80% of the visible canvas (min 480×360), placed in workspace coordinates assuming the viewport hasn't been panned. Duplicate and per-card display toggles are disabled on it. **Needs visual check:** tab switching, theme switching live, card stays usable while working.
- aion/70 — Workspace model and persistence live in `lib/workspaces/` (`workspace.dart` model + TOML codec, `workspace_store.dart` file store + `workspaceLibraryProvider`, `workspace_actions.dart` registry actions). Files go to `<app support>/workspaces/<slug>.toml` like theme presets. Serialization uses `TomlDocument.fromMap` (not a hand-written writer like presets) — simpler and escapes correctly. Pinned cards store their chart *id* (a file path reference) and config — a reference, not chart data; slot-bound cards store only the slot id.
- aion/70 — Save/load UI at this point: 'Save Workspace As…', 'Save Workspace', 'Switch to <name>' registry actions (palette), with a new `ActionContext.promptText` callback + `lib/shell/text_prompt.dart` for the name. Loading replaces all cards (`WorkspaceNotifier.replaceCards`, fresh ids); slots are untouched. Unknown TOML keys are ignored; cards without geometry are skipped; an unknown `kind` falls back to chart.
- aion/71 — `WorkspaceState.editMode` (default false) is enforced in the notifier: `moveCard`, `resizeCard`, arrow nudges and keyboard Delete are no-ops in view mode, so the lock is logic-level, not just UI. Three existing tests in `test/canvas/workspace_notifier_test.dart` (move, keyboard, snap guides) now switch edit mode on first — the behavior they test is now edit-mode-only. Card-menu Delete still works in view mode (PRD story 27 keeps it as a scoped shortcut). In view mode clicking a card only selects it (selection targets palette card actions).
- aion/71 — Toggle surfaces: `workspace.toggle_edit` (palette, canvas menu), a lock/unlock rail button, the E key, and a switch in Settings → General. Affordance: corner grips and the move cursor appear only in edit mode; the bottom-left badge reads 'VIEW · layout locked' or 'EDIT LAYOUT' (accent border). Canvas menu is now add-view (one 'Add <renderer>' per renderer), Edit Layout, Save/Save As, Switch to <workspace>. 'Add Card' (blank placeholder) and 'Open <renderer>…' left the canvas menu but remain palette actions. Added `AppAction.menuTitle` for the 'Add …' wording. **Needs visual check:** grips hidden in view mode, drag blocked, badge, rail lock button.
- aion/72 — Multi-select is shift-click only (`WorkspaceState.multiSelectedIds` + `selection` getter; edit mode only). Marquee selection was not built — the criterion allows either, and shift-click is the smaller surface. Dragging moves only the grabbed card, not the whole selection. Pure geometry in `lib/canvas/arrangement.dart`: `gridShape` (cols=⌈√n⌉, rows=⌈n/cols⌉), `tileGrid` (fills the selection's bounding box in reading order, 12px gaps), `alignRects` (6 edges/centers of the bounding box), `distributeRects` (outermost fixed, equal gaps; needs 3+). Reading order is strict top-then-left (no row tolerance). Commands are `arrange.*` registry actions, visible in the card and canvas menus and palette only in edit mode with 2+ (distribute: 3+) cards selected. **Needs visual check:** shift-click highlighting, tile/align/distribute results on screen.
- aion/73 — Switcher is `lib/shell/workspaces_flyout.dart` (starters with a lock icon, then user workspaces; click switches; Save as… / Save; rename/delete per user workspace via prompt-backed registry actions `workspace.rename.<name>` / `workspace.delete.<name>`). Rename refuses starter names and existing names (new `WorkspaceNameError.exists`); deleting the active workspace leaves the canvas as is and clears the active name.
- aion/73 — Animation: `replaceCards` reuses the outgoing cards' ids by z-order position (`reuseCardIds`) and bumps `WorkspaceState.layoutEpoch`; for 300ms after an epoch change the canvas uses `AnimatedPositioned` + `AnimatedContainer` (easeInOutCubic), otherwise duration zero so drag/resize stay instant. Cards beyond the outgoing count appear without animation; surplus old cards vanish. Reusing ids means a card slot can change renderer mid-animation. **Needs visual check:** the transition itself — this is the least-verifiable piece of the run.
- aion/74 — Starters (`lib/workspaces/starter_workspaces.dart`): 'Natal Reading' (grid + positions table) and 'Chart Focus' (large grid + positions table + house-cusp table). The PRD's 'Varga Overview' example isn't possible yet (no varga renderers); starters use only the south indian and data table renderers, and every card follows slot A so one chart load fills the layout. Starters are code-defined, never written to disk; saving under a starter name is refused, save-as forks.
- aion/74 — Startup: `AionApp` calls `workspaceLibraryProvider.notifier.openInitial()`, which (on an empty canvas) opens the last active workspace, remembered in `<app support>/workspaces/active.txt`, else the first starter. Remembering the last workspace goes slightly beyond the criterion; it's the conservative reading of 'opens into a working instrument' for returning users. **Needs visual check:** first launch shows the Natal Reading layout.
