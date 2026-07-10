## Problem Statement

Aion's visual presentation is hardcoded and inflexible. There is a single dark theme with no way to switch modes, no background images, no transparency, no card visual differentiation, and no way to control display options (sign names vs glyphs, planet names, outer planet visibility). Cards are colored with a raw `.withAlpha(200)` on an arbitrary material color rather than using semantic tokens. The canvas is a flat solid color. Users cannot customize the look and feel of their workspace, and there is no foundation for visual identity across different astrological systems or personal preferences.

## Solution

A three-layer theme and display system that separates visual presets, display options, and per-card overrides into independent, composable concerns. Visual presets (dark, light, immersive, user-created) control palette, background, and card chrome. Display options control how astrological data is rendered (sign/planet names, glyphs, outer planets). Per-card overrides allow individual cards to diverge from global defaults for opacity and display options. All settings are persisted as human-readable TOML files that can be shared.

## User Stories

1. As a user, I want to switch between dark, light, and immersive visual presets, so that my workspace matches my environment and mood.
2. As a user, I want to set a background image that stays fixed while I pan and zoom the canvas, so that I can create an immersive workspace atmosphere.
3. As a user, I want to use a solid color background, so that I can have a clean, distraction-free workspace.
4. As a user, I want the background to fall back to a solid color if my chosen image fails to load, so that the app remains usable.
5. As a user, I want to create my own visual presets by cloning and editing existing ones, so that I can personalize my workspace.
6. As a user, I want to share preset files with other users, so that we can exchange visual styles.
7. As a user, I want each loaded Chart to have a distinct accent color shown as a status strip on its cards, so that I can visually group cards by Chart at a glance.
8. As a user, I want Chart accent colors to be auto-assigned from a palette when a Chart is loaded, so that I get visual differentiation without manual setup.
9. As a user, I want to manually choose a Chart's accent color, so that I can assign meaningful colors to specific Charts.
10. As a user, I want to control the opacity of card backgrounds globally via the preset, so that cards can be translucent over a background image.
11. As a user, I want to override opacity per card, so that I can make a data table fully opaque for readability while keeping chart wheels translucent.
12. As a user, I want card content (text, chart lines, glyphs) to always remain fully opaque regardless of card surface transparency, so that content stays readable.
13. As a user, I want to choose whether signs are displayed as names or glyphs, so that I can match my reading preference.
14. As a user, I want to choose whether planets are displayed as names or glyphs, so that I can match my reading preference.
15. As a user, I want to toggle outer planet visibility (Uranus, Neptune, Pluto), so that I can focus on traditional planets when working in systems that don't use them.
16. As a user, I want to select from built-in sign name presets (tropical-western, aditya, zodiac-sanskrit), so that I get sensible defaults for my tradition.
17. As a user, I want to edit any of the 12 sign name strings directly in the GUI, so that I can use any naming convention I prefer (including Greek, custom, etc.).
18. As a user, I want to edit planet name strings directly in the GUI, so that I can use any naming convention I prefer.
19. As a user, I want display options to survive visual preset switches, so that changing from dark to immersive mode doesn't reset my sign name preferences.
20. As a user, I want to override display options per card, so that one card can show glyphs while the global default is names.
21. As a user, I want cards that don't have overrides to automatically inherit the global display defaults, so that I only configure exceptions.
22. As a user, I want card borders to visually indicate hover and selection state, so that I can see which card I'm interacting with.
23. As a user, I want the app to ship with at least three built-in presets (dark, light, immersive), so that I have good starting points.
24. As a user, I want preset files stored as TOML in my config directory, so that I can back them up and edit them manually if I choose.
25. As a user, I want display options stored as a separate TOML file from visual presets, so that they are independent concerns.

## Implementation Decisions

### Architecture: Three independent concerns

- **Visual presets** — individual `.toml` files in the user's config directory. One active at a time. Built-in presets (dark, light, immersive) ship with the app.
- **Display options** — single `display.toml` in the config directory. Sign names (12 editable strings seeded from built-in presets), planet names, glyph toggles, outer planet visibility.
- **Card overrides** — nullable fields stored in the card's workspace/layout state. Opacity and display option overrides only. Palette, borders, and text colors are not per-card overridable.

### Modules

1. **ThemePreset** — immutable data model + TOML serialization for a visual preset. Tokens: background (type, color, image path), surface (card, panel, border states), text (primary, secondary, muted), accent (seed, link), card defaults (opacity, status strip height). Built-in presets as static constants.

2. **PresetStore** — Riverpod provider managing preset files. Lists available presets (built-in + user), loads by name, saves user presets, tracks active preset selection.

3. **DisplayOptions** — data model + TOML serialization for display settings. Sign names (12 strings + source preset name), planet names, glyph toggles, outer planet visibility. Built-in sign/planet name presets as seed data. Riverpod provider with persistence.

4. **ThemeResolver** — composition layer. Takes active preset + global display options + card overrides → resolved tokens. Interface: `resolve(Card?) → ResolvedTheme`. Null card returns global resolution.

5. **BackgroundLayer** — viewport-fixed widget rendering solid color or image. Sits behind the canvas widget in the widget tree, not inside the canvas (image does not scroll/pan with the canvas).

6. **AionTheme (modify)** — evolves from hardcoded static tokens to being driven by the active ThemePreset. Remains a `ThemeExtension` so existing call sites keep working.

7. **Card model + chrome (modify)** — add nullable override fields (opacity, display options). Card widget gets status strip painted with the Chart's accent color and surface opacity support.

### Visual preset token schema

Preset tokens cover: background type and value, surface colors (card, panel, border states), text colors (primary, secondary, muted), accent colors (seed, link), card chrome defaults (opacity, status strip height).

### Sign/planet name mapping

Arrow thinks in numbers 1-12 for signs. Aion translates sign number to display string via the 12-entry name list in DisplayOptions. No domain modeling — purely a number-to-label lookup. Same pattern for planets. Built-in presets (tropical-western, aditya, zodiac-sanskrit) seed the name lists; the user edits inline in the GUI. Editing any name makes the preset indicator show "modified" or "custom".

### Chart accent colors

Not part of the theme system — they are workspace state. When a Chart is loaded, it gets an auto-assigned accent color from a palette or the user picks one. The accent color is shown as a status strip at the top of every card bound to that Chart.

### Card override composition

All override fields are nullable. Resolution: check card override → fall back to global display option / preset default. Most cards override nothing; the data model stays minimal.

### Background rendering

The background image is fixed to the viewport (not to the canvas). The canvas pans and zooms over it. Architecturally, the background is a window-level layer beneath the canvas widget.

## Testing Decisions

Tests cover pure logic — data models and composition. No widget/visual tests.

- **ThemePreset TOML round-trip** — serialize a preset to TOML and parse it back; verify all tokens survive.
- **DisplayOptions TOML round-trip** — same for display settings, including sign/planet name lists.
- **ThemeResolver override composition** — verify null card overrides fall through to global defaults; non-null overrides win; mixed scenarios (some fields overridden, some not).
- **Built-in preset validity** — all built-in presets parse successfully and contain valid token values.
- **Sign/planet name lookup** — verify number-to-name mapping for all built-in presets, edge cases (index bounds).

Existing test patterns in the codebase (chart-db, expression parsing) provide prior art for the round-trip and data model testing style.

## Out of Scope

- **Settings UI / interaction model** — how the user accesses and changes these settings is deferred to the interaction model PRD. This design defines what the settings are and how they're stored/composed, not the GUI for them.
- **Font selection** — app-level decision, set once in MaterialApp. Not a per-preset axis.
- **Gradient backgrounds** — can be added later as a third background type variant without breaking the preset format.
- **Plugin-provided theme tokens** — plugins don't contribute to the theme. They produce data; aion decides how to display it.
- **Sign name domain modeling** — aion stores 12 user-editable strings. No semantic relationship to systems, circles, or astrological meaning.

## Further Notes

- aion/14 (Multiple Charts + accent colors) is absorbed into this design — the status strip replaces the current whole-card coloring approach.
- The interaction model PRD (separate, upcoming) will design the settings UI that exposes all of these options. That PRD should reference this one for the data model it needs to present.
- The preset format is intentionally extensible — new token groups can be added to TOML without breaking existing presets (unknown keys are ignored, defaults fill gaps).
