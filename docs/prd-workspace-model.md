# PRD: Workspace Instrument Model

## Problem Statement

The interaction-model PRD routed all primary interaction through context menus. Implementation revealed the mismatch: context menus are invisible until invoked, frame the work as "perform an action on an object," and bury the view catalog — the most important browsing surface in the app — in the least browsable location. The ctrl+right-click modifier to reach global actions was a symptom: when a modifier key is needed to reach the global surface, the global surface is in the wrong place.

The deeper mismatch is with how professional astrologers work. A reading is not a sequence of actions on objects — it is a composed surface of many simultaneous views (rasi, vargas, dashas, tables, strengths) of one chart context, scanned and cross-referenced for an hour. The current model has no way to change the chart everywhere at once (the consultation flow: load a client, everything updates), no saved layouts, no persistent surface showing what exists, and per-card independent expressions that make a chart change an N-card chore. Freeform card placement, aion's original identity, adds a fiddliness tax to every session while most users would arrange a layout once and never move things again.

Audience: professional astrologers — mouse-first, mostly Windows, valuing density, stability, and speed over decoration.

## Solution

Reframe aion from freeform canvas to professional instrument. Named **workspaces** (locked layouts) that charts flow through via **chart slots** (color + label link groups, Bloomberg-terminal style). Two access surfaces driven by one **action registry**: a persistent edge **rail** for mouse users and a **command palette** for keyboard speed. Freeform arrangement becomes an explicit **edit mode** — the layout editor, not the daily interaction plane. Three coordination features make the cards one instrument instead of independent windows: **linked highlighting** (hover a planet, it lights up everywhere), a **global time cursor** (scrub time, time-dependent views follow), and **semantic zoom** (card size selects detail level). Context menus are demoted to scoped shortcuts.

## User Stories

### Chart slots

1. As a user, I want to load a chart into a slot and see every card bound to that slot update at once, so that starting a consultation is one action, not one per card.
2. As a user, I want slots to have a color and an editable label ("Client", "Partner"), so that I can see and name what each card group is showing.
3. As a user, I want each card's status strip to show its slot color, so that I can visually group cards by slot at a glance.
4. As a user, I want to rebind a card to a different slot, so that I can restructure what a layout shows without recreating cards.
5. As a user, I want to pin a card to a fixed chart and config, so that it stops following its slot (e.g. keep a reference chart visible while clients change).
6. As a user, I want to compare two people side by side by loading them into slots A and B, so that synastry-style work is a first-class flow.
7. As a user, I want cards to inherit calculation config from their slot, so that changing the slot's ayanamsa recomputes all its cards together.
8. As a user, I want to override calculation config on a single card, so that I can compare two ayanamsas side by side as the exception, not the rule.

### Rail and command palette

9. As a user, I want a slim persistent rail with the view catalog, slots, workspaces, time, and settings, so that everything the app can do is discoverable by mouse without menus.
10. As a user, I want the view catalog to open as a browsable grid grouped by category (charts, vargas, tables, time), so that adding a view is point-and-click.
11. As a user, I want a command palette (Ctrl+K) with fuzzy matching and domain aliases ("d9" → Navamsa, "vim" → Vimshottari), so that keyboard users summon views in three keystrokes.
12. As a user, I want the palette to be browsable by mouse (clickable categories when the query is empty), so that it serves both interaction styles.
13. As a user, I want the rail and palette to expose the same actions, so that there is one mental model regardless of input style.

### Workspaces and edit mode

14. As a user, I want to save my current layout as a named workspace, so that "Natal Reading" or "Varga Overview" is one switch away.
15. As a user, I want slot assignments to survive workspace switches, so that my loaded client flows into the new layout instead of being reset.
16. As a user, I want layouts locked in normal use, so that I never accidentally drag a card mid-consultation.
17. As a user, I want an explicit edit mode with freeform drag, resize, and snapping, so that full layout control is there when I want it.
18. As a user, I want arrangement commands in edit mode (tile selection as grid, align, distribute), so that arranging twelve cards takes seconds, not minutes.
19. As a user, I want aion to ship with starter workspaces, so that first launch shows a working instrument, not an empty canvas.

### Linked highlighting

20. As a user, I want hovering a planet in any card to highlight it in every card of the same slot (glyph in the chart, row in the table), so that cross-referencing is visual, not mental.
21. As a user, I want to click an entity to lock the highlight and Esc to clear it, so that I can keep Saturn lit while I scan.

### Time cursor

22. As a user, I want a global time cursor with a scrubber, so that time-dependent views (transits, dashas) follow one shared "when."
23. As a user, I want to type a date/time or jump to now, so that navigating time is precise as well as exploratory.
24. As a user, I want the time scrubber summonable from the rail and hidden otherwise, so that natal-only sessions pay no chrome for it.

### Semantic zoom

25. As a user, I want a small chart card to show a glanceable summary and a large one to show full detail (degrees, nakshatras, dignities), so that resizing is how I promote a view from thumbnail to focus.
26. As a user, I want renderers to declare their detail levels, so that new renderers get this behavior by contract, not special-casing.

### Context menus (demoted, retained)

27. As a user, I want the card context menu to keep scoped shortcuts — switch renderer, config, display overrides, pin/unpin, slot binding, duplicate, delete — so that per-card operations stay one right-click away.
28. As a user, I want the canvas context menu reduced to add-view, edit-mode toggle, and workspace operations, so that it is a shortcut, not a load-bearing surface.

## Implementation Decisions

### Identity

Aion is a professional instrument: dense, stable, linked. Freeform placement is preserved in full — as the layout editor, entered deliberately. The daily-use plane is a locked workspace that charts and time flow through.

### Chart slots

- New model `ChartSlot`: id, label, color, optional chartId, expression config. Slots are app-session state, not workspace state — switching workspaces keeps clients loaded.
- `CardModel` binding becomes a sealed type: `SlotBinding(slotId)` or `PinnedBinding(chartId, config)`. Resolution: slot's chart + (card config override ?? slot config) → `ExpressionRef` → existing `ChartStore` compute/cache path, which is unchanged.
- The slot color takes over the card status strip. This amends the theme PRD (aion/36): per-Chart accent colors become slot colors — the strip now encodes the link group, not just chart identity. Pinned cards show a pin indicator in the strip.
- A default slot A always exists; opening a chart with no slot targeted loads into the active slot.

### Action registry, rail, palette

- `ActionRegistry`: actions with id, title, category, aliases, icon, enablement, execute. Sources: renderer registry (add view per renderer), slot ops, workspace ops, quick toggles, settings. The existing `ContextMenuService` (aion/50) becomes a consumer of the registry rather than a parallel definition of actions.
- Rail: slim persistent edge strip. Sections open as flyouts (catalog grid, slots panel, workspace switcher, time, settings) — no permanent side panels, canvas space is preserved.
- Palette: overlay opened by Ctrl+K or a rail button. Fuzzy match over titles + aliases; empty query shows clickable categories. Domain alias table (d1–d60, dasha names, common abbreviations) lives alongside `RendererMeta`.

### Workspaces and edit mode

- `Workspace`: name + card list (renderer type, geometry, slot binding, per-card overrides). No chart data — a workspace is a template that slots flow through. Persisted as TOML in the config directory, consistent with theme presets.
- View mode (default): card drag/resize disabled; interactions are content-level (hover, click, scroll). Edit mode: existing drag/resize/snap physics plus arrangement commands — tile selection into a grid, align edges, distribute. Toggle lives in rail, palette, and canvas menu.
- Workspace switches animate card transitions (roadmap phase 0 already called for animated layout presets).
- Starter workspaces ship read-only; "save as" forks them.

### Linked highlighting

- `HighlightState` provider: highlighted entity (planet, house, sign), slot scope, transient (hover) vs locked (click). Renderer contract gains a highlight input: `RendererHost` passes the highlight set to painters, which render emphasis. Hit-testing already exists (`ChartHitResult`); this adds the outbound channel.
- Scope v1: cards of the same slot; entities: planets, houses, signs. Cross-slot brushing (synastry: "show me his Saturn on her chart") is deferred but the state model should not preclude it.

### Time cursor

- Global `TimeCursor` state, defaulting to now. Time-dependent expressions (transits, dashas relative to a date) declare their dependence; scrubbing debounces and recomputes through the existing `ChartStore` path.
- Requires expressions parameterized by datetime — a drishti/arrow API implication to be confirmed before this phase.
- v1 UI: bottom-docked scrubber summoned from the rail — scrub bar, date field, now button, step buttons. Play/animation and snap-to-event stay in roadmap phase 9.

### Semantic zoom

- `RendererMeta` gains ordered detail levels with size thresholds. `RendererHost` selects the level from the card's rendered size and passes it to the painter. v1: south indian (occupancy → +degrees → +nakshatra/dignity) and data table (core columns → full columns).

### Expression config default flip

The interaction-model PRD made per-card independent config the default; this inverts it. Config lives on the slot; per-card override is the opt-in exception. The `ConfigDimension` model and progressive-disclosure dialog (aion/49) carry forward unchanged — the dialog now edits slot config (opened from the slots panel) or a card override (opened from the card menu).

### Phasing

Each phase is independently shippable:

1. **Slots + action registry** — model layer, no new chrome; cards rebind to slots, registry subsumes ContextMenuService.
2. **Rail + palette** — the two access surfaces over the registry.
3. **Workspaces** — persistence, view/edit mode, tiling commands, starter templates.
4. **Linked highlighting** — highlight channel through the renderer contract.
5. **Time cursor** — after the drishti datetime-parameterization question is resolved.
6. **Semantic zoom** — detail levels in renderer meta.

### Relationship to prior work

- Supersedes `prd-interaction-model.md`'s canvas-menu and global-access design. Carried forward from it: card context menu structure (aion/50), settings card, expression config dialog, `ConfigDimension` (aion/49).
- aion/25 (command palette) is promoted from out-of-scope to a core surface.
- Amends the theme PRD (aion/36): chart accent colors → slot colors on the status strip.
- Recovers the original roadmap intent: phase 0 listed "slot binding and workspace store" and "layout presets"; phase 2 lists slot pipelines. This PRD is that design, made concrete.

## Testing Decisions

Pure logic only — no widget/visual tests.

- **Slot resolution** — binding + override composition → correct `ExpressionRef`; pinned cards ignore slot changes; slot chart/config change marks exactly its bound cards for recompute.
- **ActionRegistry** — generation from renderer registry, alias/fuzzy matching and ranking, enablement rules.
- **Workspace serialization** — TOML round-trip; dangling slot ids resolve to the default slot rather than erroring.
- **HighlightState** — same-slot scoping, transient vs locked transitions.
- **Detail level selection** — size threshold boundaries.
- **Tiling geometry** — N selected cards → grid rects for the arrangement commands.

## Out of Scope

- **Chart entry and chart browser (aion/16, aion/20)** — required for a professional product, designed separately. The rail reserves a section for the chart browser; slots are where a browsed chart lands.
- **Reports, printing, export** — roadmap phase 8.
- **Time animation / snap-to-event** — roadmap phase 9; the cursor's state model should accommodate it.
- **Cross-slot highlighting (synastry brushing)** — deferred; state model must not preclude it.
- **New renderers** (dasha timeline, transit views) — this PRD defines coordination, not the views themselves; new renderers slot into catalog, palette, zoom, and highlighting by contract.
- **Plugin-advertised palette actions** — the registry is structured to accept them later.
- **Multi-window / multi-monitor** — post-v1.

## Further Notes

- The six moves compose into one instrument: a workspace is a saved layout, slots are the data flowing through it, rail/palette summon views into it, highlighting and the time cursor link them live, semantic zoom lets density and detail coexist.
- The design's litmus test, per audience: does it make a working astrologer's reading *faster*? Decoration (backgrounds, presets) remains supported via the theme system but is no longer the pillar; composition is.
- Kala's proven pattern (many simultaneous views, ambient chart context, shallow catalog) is the functional baseline; slots generalize its single ambient chart, workspaces generalize its Screens, and the rail/palette replace its popup dialog.
