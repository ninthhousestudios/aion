> **Superseded** by `prd-workspace-model.md` (2026-07-03). The canvas context menu, ctrl+right-click modifier, and per-card-independent expression config are replaced by the slot/rail/palette/workspace model. Still current from this document: card context menu structure, settings card, expression config dialog, ConfigDimension.

## Problem Statement

Aion has a minimal, flat context menu that offers the same options regardless of whether the user right-clicks a card or the canvas. There is no way to change an Expression's calculation options (ayanamsa, house system, etc.) at runtime, no way to switch a card's renderer after creation, no settings UI, and no way to open related views (dashas, data table) scoped to an existing card's chart. Users cannot access arrow's full calculation options, and there is no foundation for the progressive disclosure of features as more renderers and systems are added.

## Solution

A three-surface interaction model: card context menu (scoped to the card's chart/expression), canvas context menu (global actions), and a settings card (full configuration as a regular canvas card). Expression config is edited through a progressive-disclosure dialog with collapsible sections, built against a config dimension abstraction (enum, boolean, multi-select) that is initially hardcoded from arrow's options but structured for future plugin-advertised schemas. Each card can independently change its expression config. A configurable modifier key (default ctrl+right-click) forces the canvas context menu even when the cursor is over a card.

## User Stories

1. As a user, I want to right-click a card and see actions scoped to that card's chart and expression, so that I can quickly open related views without re-picking the chart.
2. As a user, I want to open a data table for the same chart/expression that's already showing in a card, so that I can see the tabular data alongside the visual renderer.
3. As a user, I want to open a dasha timeline for the same chart/expression, so that I can explore dashas without rebinding a chart.
4. As a user, I want new sibling cards to inherit the source card's expression config, so that I don't have to reconfigure each one.
5. As a user, I want to switch a card's renderer in-place (e.g. south Indian to north Indian), so that I can compare visualizations without opening a new card.
6. As a user, I want to change a card's expression config (ayanamsa, house system, etc.) independently of other cards, so that I can compare two ayanamsas side by side.
7. As a user, I want an expression config dialog that shows my current settings at a glance (collapsed sections) and lets me expand only the section I want to change, so that I'm not overwhelmed by options.
8. As a user, I want config options grouped by intent (Ayanamsa & Zodiac, Houses, Bodies, Vedic Options, Advanced) rather than by technical category, so that I can find what I'm looking for intuitively.
9. As a user, I want a visual indicator for which config changes trigger full recalculation vs instant re-derive, so that I know what to expect when changing a setting.
10. As a user, I want to right-click the empty canvas and see global actions: open a chart with a chosen renderer, quick setting toggles, workspace operations, so that the canvas menu serves as the app's global action surface.
11. As a user, I want the canvas context menu's "Open Chart" section to list available renderers, so that I choose the renderer and then pick the chart in one flow.
12. As a user, I want quick-access toggles in the canvas context menu for theme preset switching, glyph toggle, and outer planet visibility, so that I don't have to open full settings for common changes.
13. As a user, I want a configurable modifier key (default ctrl+right-click) to force the canvas context menu even when my cursor is over a card, so that I can access global actions when the canvas is full.
14. As a user, I want a settings card that opens as a regular card on the canvas (default ~80% window size, resizable, movable), so that settings are accessible alongside my workspace.
15. As a user, I want the settings card to have tabs for Theme, Display, Expression Defaults, and General, so that configuration is organized by concern.
16. As a user, I want to set a global default expression config in the settings card, so that new cards use my preferred ayanamsa, house system, etc.
17. As a user, I want an "apply to all open cards" action on the global default expression config, so that I can fix all cards at once when I change my preferred settings.
18. As a user, I want per-card display overrides (opacity, sign names/glyphs, outer planets) accessible from the card context menu, so that I can customize individual cards without changing the global setting.
19. As a user, I want to duplicate a card from its context menu, so that I can create a copy to then diverge its expression config.
20. As a user, I want to delete a card from its context menu, so that I can clean up my workspace.
21. As a user, I want to resize a card to preset sizes from its context menu, so that I can quickly arrange my workspace.
22. As a user, I want new cards opened from the canvas to use the global default expression config, so that I only configure exceptions.
23. As a user, I want the expression config to support enum (pick one), boolean (toggle), and multi-select (pick many) dimension types, so that all of arrow's current calculation options can be exposed.
24. As a user, I want the settings card to not have a chart accent color strip, since it's not bound to a chart, so that it's visually distinct as an app-level surface.
25. As a user, I want to keep the settings card open while I work if I'm doing a lot of switching, since it's just another card on the canvas.

## Implementation Decisions

### Three interaction surfaces

- **Card context menu** — scoped to the card's Chart/Expression. Sections: Open for this Chart (renderer list, siblings inherit expression), This Card (switch renderer, expression config dialog), Display (per-card overrides: opacity, sign names/glyphs, outer planets), Card (duplicate, resize, delete).
- **Canvas context menu** — global actions. Sections: Open Chart (renderer list → chart picker, uses global default config), Quick Settings (preset switch, glyph toggle, outer planets), Workspace (settings card, save/load layout). Also opened by configurable modifier (default ctrl+right-click) even over a card.
- **Settings card** — a regular canvas card, not bound to a Chart. Opens at ~80% window size, resizable/movable. Tabbed: Theme (preset selector, background, opacity slider, preset management), Display (sign/planet name editing, glyph toggles, outer planets), Expression Defaults (global default config + "apply to all"), General (keybindings, future app-level settings).

### Expression config dialog

Progressive-disclosure dialog with collapsible sections. Each section shows the current value when collapsed, full option list when expanded. Anchored to the card when opened from card context menu. Embedded in the settings card for global defaults.

Sections grouped by user intent:
- **Ayanamsa & Zodiac** — sign ayanamsa, nak ayanamsa, circle, zodiac system
- **Houses** — house system
- **Bodies** — planet set (multi-select), outer planets, true/mean node, fixed stars
- **Vedic Options** — dasha year length, chara karaka count (7/8), rashi aspect mode
- **Advanced** — topocentric, ephemeris source, reference frames

Subtle indicator on sections containing SweConfig fields (expensive recalculation) vs CalcConfig-only sections (instant re-derive).

### Config dimension abstraction

Three dimension types: enum (pick one from list), boolean (toggle), multi-select (pick many from list). Each dimension has: name, group, type, current value, available values, and a metadata flag for cheap vs expensive. Initially hardcoded from arrow's options, structured so the data source can be swapped to plugin-advertised schema later without changing the UI.

### Independent expression config per card

Each card has its own Expression reference. Changing a card's config triggers computeExpression for that card only. Sibling cards are unaffected. New cards (from canvas menu) inherit the global default config. New sibling cards (from card context menu) inherit the source card's config. The global default expression config lives in settings and has an "apply to all open cards" action.

### Context menu is data-driven

Menu items in the "Open for this Chart" and "Open Chart" sections are driven by the renderer registry. As new renderers are registered, they appear automatically. This is the foundation for future system-aware filtering — when system plugins exist, the renderer list can be filtered/grouped by system.

### Relationship to existing tasks

- aion/13 (Card Expression switching) — absorbed into this design as the expression config dialog + independent per-card expression
- aion/12 (Card Renderer switching) — absorbed as "Switch Renderer" in card context menu
- aion/24 (Context menu with System awareness) — the flat renderer-driven menu is the foundation; full system-aware layering is deferred to when multiple systems exist

### Relationship to theme PRD (aion/36)

The interaction model provides the UI surface for the theme and display system's settings. The settings card's Theme and Display tabs expose what aion/36 defined. Per-card display overrides in the card context menu expose the card override model from aion/36. The two PRDs are complementary — aion/36 defines what the settings are, this PRD defines how the user accesses them.

## Testing Decisions

Tests cover pure logic only — no widget/visual tests.

- **ConfigDimension model** — dimension type correctness, value validation, grouping logic
- **ContextMenuService** — correct menu items generated for card context (with chart/expression) vs canvas context (no chart), renderer registry integration, quick-toggle state reflection, canvas-force modifier logic
- **Expression config inheritance** — new sibling cards get source card's config, new canvas cards get global default config

Existing test patterns in the codebase provide prior art for the data model testing style.

## Out of Scope

- **Command palette (aion/25)** — parallel access path to the same actions, does not change the design of context menus or settings
- **System-aware menu layering (aion/24 full design)** — deferred until multiple system plugins exist. The current flat renderer-driven menu is the foundation it will build on.
- **Chart browser panel (aion/20)** — replaces the file picker as chart selection UI, but the interaction model works with either
- **Chart creation flow (aion/16)** — "new chart" will appear in canvas context menu when it exists
- **Plugin-advertised config schema** — the abstraction supports this future, but arrow's options are hardcoded initially
- **Freeform star names** — the one config type not covered by enum/boolean/multi-select, deferred
- **Full keybinding system** — only the canvas-force modifier is in scope; a comprehensive keybinding UI is a separate concern

## Further Notes

- The interaction model is designed to grow. New renderers, new system plugins, new config options all slot into existing structures without redesigning the menus.
- The expression config dialog's section structure mirrors arrow's option groups but is user-intent-driven, not code-structure-driven. If arrow adds a new tradition (e.g. UranianConfig), it becomes a new collapsible section.
- The settings card being a regular canvas card means it inherits all card behaviors (resize, move, opacity) for free from the theme system.
- aion/12 and aion/13 are superseded by this design — their acceptance criteria are covered by the card context menu and expression config dialog respectively.
