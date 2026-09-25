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

- [ ] Card status strip painted with slot color, resolved via the `ThemeResolver` path
- [ ] Pin indicator on pinned cards
- [ ] Card context menu: bind-to-slot submenu + pin/unpin actions
- [ ] Slot recolor/relabel reflects immediately on bound cards

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

- [ ] `ActionRegistry` model with enablement + execute; generation from renderer registry, slot ops, workspace ops, toggles
- [ ] Domain alias table (d1–d60, dashas) attached to renderer meta
- [ ] Fuzzy matcher with ranking; unit tests for alias and fuzzy hits
- [ ] Card and canvas context menus consume the registry; existing menu behavior preserved
- [ ] Registry directory respects the layering constraint; path recorded in the log

### aion/53 — Expression config dialog

*Depends on: aion/63. Builds on the `ConfigDimension` model (already landed).*

Progressive-disclosure config dialog with collapsible sections grouped by
intent, using the existing `ConfigDimension` model, with a cheap-vs-expensive
(SweConfig vs CalcConfig) indicator. The dialog edits either a **slot's**
expression config (opened from the slots panel, aion/68) or a **per-card
override** (opened from the card context menu). There is no global default
expression config any more; slot config replaces it.

Acceptance criteria:

- [ ] Dialog renders collapsible sections from `ConfigDimension` groups
- [ ] Collapsed sections show dimension name + current value
- [ ] Expanded sections show the full option list appropriate to the type
- [ ] SweConfig vs CalcConfig indicator visible on sections
- [ ] Dialog anchors near the source card when opened from the context menu
- [ ] Dialog can be embedded (not only shown as a modal)
- [ ] Changing a value calls back with the updated config
- [ ] Card context menu entry opens it as a per-card override editor

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

- [ ] Persistent slim rail with flyout framework (single open flyout, dismiss on click-away/Esc)
- [ ] View catalog flyout: category-grouped grid from ActionRegistry
- [ ] Clicking a catalog entry adds a card bound to the active slot
- [ ] New renderers appear in the catalog with no catalog changes (registry-driven)

### aion/25 — Command palette (Ctrl+K) over ActionRegistry

*Depends on: aion/65. Rail button requires aion/67.*

Overlay opened by Ctrl+K or a rail button. Fuzzy match over ActionRegistry
titles + domain aliases ("d9" → Navamsa, "vim" → Vimshottari). Empty query
shows clickable categories so mouse-first users can browse — the same actions
as the rail, one mental model. Reuse the aion/65 matcher; don't write a second
one.

Acceptance criteria:

- [ ] Ctrl+K and a rail button open the palette overlay
- [ ] Fuzzy matching over titles + aliases with sensible ranking
- [ ] Empty query shows clickable category browsing
- [ ] Enter/click executes the action (add view to active slot, workspace ops, toggles)

### aion/68 — Slots panel flyout: load chart, label/color, active slot, config entry

*Depends on: aion/53, aion/63, aion/67.*

Rail flyout for managing slots (PRD §Rail, §Chart slots). Lists slots with
color + label; rename and recolor inline; load a chart into a slot (file
picker for now, since the chart browser comes later); set the active slot;
entry point to the slot's expression config (the aion/53 dialog).

Acceptance criteria:

- [ ] Slots panel lists slots with color + editable label
- [ ] Load chart into a slot from the panel; bound cards update
- [ ] Active slot selection; add/remove slots (slot A cannot be removed)
- [ ] Opens the slot expression config dialog

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

- [ ] Settings card opens from the rail settings button and the palette (registered in ActionRegistry)
- [ ] Opens at ~80% window size, resizable and movable
- [ ] No slot color strip
- [ ] Tabbed interior: Theme, Display, General
- [ ] Theme and Display tabs wired to the existing theme/display system
- [ ] Settings card can remain open while the user works

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

- [ ] Workspace model captures renderer type, geometry, slot binding, per-card overrides — no chart data
- [ ] TOML round-trip tests; unknown keys tolerated
- [ ] Save current layout as named workspace; load restores it
- [ ] Dangling slot ids resolve to the default slot instead of erroring

### aion/71 — View/edit mode: layouts locked by default, explicit edit mode

*Depends on: aion/65.*

The daily-use plane is a locked layout (PRD §Workspaces and edit mode). View
mode (default): card drag/resize disabled; interactions are content-level
only. Edit mode: the existing drag/resize/snap physics enabled, corner grips
visible. Toggle registered in the ActionRegistry (reachable from rail,
palette, canvas menu).

Acceptance criteria:

- [ ] View mode: drag/resize/grips disabled; content interaction (hover/click/scroll) unaffected
- [ ] Edit mode: existing drag/resize/snap behavior intact
- [ ] Mode toggle via ActionRegistry with a clear visual affordance of which mode is active
- [ ] Canvas context menu reduced to add-view, edit-mode toggle, workspace operations (PRD story 28)

### aion/72 — Arrangement commands: tile selection as grid, align, distribute

*Depends on: aion/71.*

Edit-mode arrangement verbs (PRD §Workspaces and edit mode). Multi-select
cards, then tile the selection into an N-cell grid, align edges, or distribute
spacing. Requires a card multi-select model (marquee or shift-click).
Geometry is pure functions over rects, tested without widgets.

Acceptance criteria:

- [ ] Card multi-select (shift-click and/or marquee) in edit mode
- [ ] Tile selection into a grid (sensible rows×cols for N cards)
- [ ] Align edges + distribute spacing commands, registered in ActionRegistry
- [ ] Pure-logic tests for tiling/align/distribute geometry

### aion/73 — Workspace switcher in rail + animated transitions

*Depends on: aion/67, aion/70.*

Rail flyout listing workspaces. Switching swaps the layout with animated card
transitions. Slot assignments are app-session state and survive the switch,
so the loaded client flows into the new layout.

Acceptance criteria:

- [ ] Workspace switcher flyout in the rail (save-as, rename, delete)
- [ ] Switching preserves slot assignments; cards resolve against live slots
- [ ] Animated card transitions on switch

### aion/74 — Starter workspaces

*Depends on: aion/70, aion/73.*

Ship read-only starter workspace templates so first launch shows a working
instrument, not an empty canvas. Size the initial set to the available
renderers (e.g. Natal Reading, Varga Overview). "Save as" forks a template
into a user workspace.

Acceptance criteria:

- [ ] At least two starter workspaces built from currently available renderers
- [ ] Starters are read-only; save-as forks to a user workspace
- [ ] First launch opens into a starter workspace

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
