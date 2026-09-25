# Workspace instrument model: cloud run review

Unattended implementation of `docs/prd-workspace-model.md`, following the task
list in `docs/workspace-model-tasks.md` (aion/61, then phases 1–5). The
decisions log at the bottom of the tasks doc covers every task in more detail.
This doc summarizes the run and has the manual test script.

**Nothing here was run as an app.** The container has no display, and chart
computation needs the drishti plugin. Every UI behavior below is unverified
until someone works through the manual test script. Everything that could be
checked by pure-logic tests was.

## Summary

- **Slots:** `ChartSlot`, `SlotBinding`/`PinnedBinding` and expression
  resolution are in `lib/slots/`. Cards resolve their binding against live
  slots on every build and compute through the unchanged `ChartStore`. Loading
  a chart into a slot updates every card bound to that slot.
- **One action registry:** `lib/commands/` drives the card and canvas context
  menus, the rail's view catalog and the Ctrl+K command palette. It includes a
  fuzzy matcher and domain aliases (d1–d60, dasha abbreviations).
- **Rail:** a slim left rail. It has flyouts for the catalog, slots and
  workspaces, plus buttons for the palette, edit mode and settings. Time is a
  disabled placeholder.
- **Workspaces:** saved as TOML under `<app support>/workspaces/`, with
  save/save-as/rename/delete and animated switching. Two read-only starters
  ship, and first launch opens "Natal Reading".
- **View/edit mode:** layouts are locked by default. Edit mode brings back
  drag, resize and snap, and adds shift-click multi-select with
  tile/align/distribute.
- **Linked highlighting:** hovering an entity highlights it in every card on
  the same slot, clicking locks it, and Esc clears it. Both renderers draw the
  emphasis.
- **Semantic zoom:** renderers declare detail levels. The host picks one from
  the card size: south indian has 3 levels, the data table has 2.
- **Expression config dialog:** edits a slot's config or a per-card override.
- **Settings card:** tabs for Theme, Display and General.

## Per-task status

| Task | Status | Commit(s) | What was built |
|---|---|---|---|
| aion/61 RendererHost rebuild | done | `2df7502` | Single change check in `build()` (expression list compared by content); `CanvasCard` caches the `[data]` list. |
| aion/63 ChartSlot model + binding + resolution | done | `5c683e8` | `lib/slots/`: slot model/provider, sealed `CardBinding`, canonical-config resolution to `ExpressionRef`, `ensureExpression`. |
| aion/64 Slot UI | done | `be34ed9` | Status strip in slot color (`ThemeResolver.stripFor`, `AionTheme.slotPalette`), pin icon, card-menu bind-to-slot / pin / unpin / cycle slot color. |
| aion/65 ActionRegistry + aliases | done | `2790fcf` | `lib/commands/` registry + matcher + menu resolution; `RendererMeta.category/aliases`; alias table; both context menus consume the registry. |
| aion/53 Expression config dialog | done | `94e6082` | `ConfigEditor` (collapsible `ConfigDimension` sections, SweConfig/CalcConfig badge) + anchored `showConfigDialog`; per-card override and slot config actions. |
| aion/67 Rail + flyouts + catalog | done | `44488f8` | `lib/shell/` rail, flyout framework (one at a time, click-away/Esc), registry-driven catalog grid. |
| aion/25 Command palette | done | `6596603` | Ctrl+K / rail overlay; shared matcher; empty query browses categories; keyboard + mouse. |
| aion/68 Slots panel | done | `c93123c`, `1ec636e` | Slots flyout: active slot, color, inline label, load chart, config, add/remove. Follow-up: stops typing from triggering canvas shortcuts. |
| aion/57 Settings card | done | `aa7c2c1` | `CardKind.settings` card at 80% of the canvas; Theme/Display/General tabs; opened from rail and palette. |
| aion/70 Workspace model + TOML | done | `6d8d9d7` | `lib/workspaces/`: model, TOML codec (tolerant), store, library provider, save/save-as/switch actions, text prompt. |
| aion/71 View/edit mode | done | `6093bef` | `editMode` enforced in the notifier; grips/cursor only in edit mode; rail/palette/menu/E-key toggle; canvas menu reduced. |
| aion/72 Arrangement commands | done | `999f3ed` | Shift-click multi-select; pure tile/align/distribute geometry; `arrange.*` actions. |
| aion/73 Workspace switcher + animation | done | `82fa6e8` | Workspaces flyout with rename/delete; id reuse + `layoutEpoch` driving `AnimatedPositioned`/`AnimatedContainer`. |
| aion/74 Starter workspaces | done | `b370d85` | "Natal Reading" and "Chart Focus"; read-only, save-as forks; first launch opens a starter, later launches the last one. |
| aion/76 HighlightState + channel | done | `e4eaedd` | Highlight entities in the renderer contract; `HighlightState` + transitions; `RendererHost` highlights in, hover/tap out. |
| aion/77 Highlight rendering + interactions | done | `0c797aa` | Planet box + sign-cell tint (south indian), row tint (data table); hover/click/Esc; `AionTheme.highlightColor`. |
| aion/80 Semantic zoom | done | `4838fb8` | `DetailLevel` in `RendererMeta`; host picks from rendered size; south indian 3 levels, data table 2. |
| aion/78, aion/79 Time cursor | skipped (out of scope) | — | Not touched, as instructed. The rail has a disabled time placeholder. |

No task was blocked.

## Deviations from the PRD (and why)

1. **One binding per card.** The PRD's sealed `SlotBinding | PinnedBinding`
   replaced `CardModel.expressions: List<ExpressionRef>`. The old
   "multi-expression synastry card" shape is gone until a synastry renderer
   exists. Synastry now means two cards on slots A and B (story 6).
2. **Slot color is a palette index.** `ChartSlot` stores `colorIndex` into
   `AionTheme.slotPalette`, not a raw `Color`. This keeps the slot model
   presentation-free and themeable. Recoloring cycles through the palette;
   there's no free color picker.
3. **Per-chart accent colors are removed entirely.** The PRD amends them into
   slot colors. `chartAccents`/`cycleChartAccent` and their test file were
   deleted.
4. **Flat bind-to-slot menu section.** It's one checked item per slot instead
   of a nested submenu, because `showMenu` has no submenus. Unpin rebinds to
   the *active* slot, because `PinnedBinding` doesn't record where it came
   from.
5. **Canvas menu contents.** It now holds add-view, Edit Layout, arrangement
   (edit mode only), Save/Save As and Switch to… (story 28). "Add Card" and
   "Open <renderer>…" moved to the palette only.
6. **Starter set.** "Varga Overview" isn't possible yet because there are no
   varga renderers. The starters are "Natal Reading" and "Chart Focus", built
   from the two existing renderers.
7. **Multi-select is shift-click only.** There's no marquee. Dragging moves one
   card, not the whole selection.
8. **Settings card placement.** It's centered at 80% of the visible canvas and
   assumes the canvas isn't panned.
9. **The renderer contract grew by two optional `createPainter` parameters**
   (`highlights`, `detailLevel`) and `ChartPainter.entityForHit`. The fake
   renderer in `test/renderer/chart_renderer_test.dart` was updated to keep
   compiling.
10. **Remembering the last workspace** goes slightly beyond aion/74:
    returning users reopen their last workspace instead of a starter.

## Manual test script

Run `flutter run -d linux` with drishti available. You need two or more
`.toml` chart files (for example "Ravi" and "Sita") and a fresh config, so
delete `<app support>/workspaces/` first to see first-launch behavior.

**Slots: PRD story 1 first**

1. Launch. The canvas should open straight into the **Natal Reading** starter:
   a south indian grid on the left, a data table on the right, both empty. The
   bottom-left badge reads **"VIEW · layout locked"**. The rail runs down the
   left edge.
2. In the rail, click the **link icon (Chart slots)**. A flyout lists slot
   **A**. Click its **folder icon**, pick "Ravi". **Both cards fill with Ravi's
   chart at once** (story 1). Each card's thin top status strip shows slot A's
   color.
3. Load "Sita" into slot A the same way. Both cards switch to Sita together.
4. In the slots flyout, click A's **color swatch**. Both cards' strips change
   color immediately. Edit the label to "Client". While you type, the canvas
   must *not* toggle edit mode, snap or theme. Press Esc or click the canvas
   to close the flyout.
5. Click **Add slot**, which adds slot B. Load "Ravi" into B. Click B's radio
   to make it active; the rail's slot button dot takes B's color.
6. Right-click the data table and choose **Bind to Slot B**. Only that card
   switches to Ravi, and its strip takes B's color (stories 4, 6).
7. Right-click the grid and choose **Pin**. A pin icon appears under the
   strip. Load another chart into the grid's slot: the pinned card doesn't
   change (story 5). Right-click and choose **Unpin**, and it follows the
   active slot again.

**Config**

8. In the slots flyout, click A's **tune icon**. A config panel opens with
   collapsed sections: each shows its values plus a SweConfig/CalcConfig
   badge. Expand "Ayanamsa & Zodiac" and change the sign ayanamsa. All
   slot-A cards recompute (story 7).
9. Right-click one slot-A card and choose **Expression Config…**. The panel
   opens next to the card. Change a value, and only that card recomputes
   (story 8). **Clear Config Override** puts it back in line with the slot.
   *Check that drishti accepts the config keys (`signAyanamsa`, etc.).*

**Catalog and palette**

10. In the rail, open **View catalog** (grid icon). You should see tiles
    grouped as CHARTS and TABLES. Click "Data Table": a new card bound to the
    active slot appears and shows that slot's chart.
11. Press **Ctrl+K**. With an empty query you see categories; click
    "Workspace" to browse it. Backspace returns to categories. Type `d1` and
    press Enter: a south indian grid is added. Type `table` and use the
    arrows and Enter. Try `snap`, `edit` and `settings`.
12. Select a card, press Ctrl+K and type `dup`. Duplicate should be offered
    for the selected card.

**Workspaces and edit mode**

13. Try dragging a card. It must not move in view mode, and there are no
    corner grips.
14. Press **E**, or click the rail's lock button. The badge turns to
    "EDIT LAYOUT" with an accent border. Grips appear, and drag, resize and
    snap (S) work.
15. Shift-click three cards: all three show the selected border. Right-click
    one and choose **Tile Selection as Grid**, then **Align Top Edges** and
    **Distribute Horizontally**. Check the results look sensible.
16. In the rail, open **Workspaces** and click **Save as…**. Enter "Mine". It
    appears under MY WORKSPACES, highlighted. Try saving as "Natal Reading":
    this should be refused with a message.
17. Click **Chart Focus**. Cards should *animate* into the new layout, and the
    loaded chart carries over (story 15). Click **Mine** to switch back
    (animated).
18. Rename and delete "Mine" from the flyout. Starters have no rename or
    delete.
19. Right-click empty canvas. You should see only Add <view>, Edit Layout,
    Save/Save As and Switch to <workspace> (plus arrange items in edit mode
    with a selection).
20. Quit and relaunch. The last active workspace reopens.

**Linked highlighting**

21. Put a grid and a table on the same slot. Hover Saturn in the grid: its
    glyph gets a box, and the table's Saturn row is tinted (story 20). Hover a
    grid cell: the sign is tinted, and table rows for planets in that sign
    are tinted. A card on another slot shows nothing.
22. Click Saturn. The highlight stays while you move away (story 21). Click
    Saturn again, or click empty chart space, to release it. Lock it again
    and press **Esc** to clear.

**Semantic zoom**

23. In edit mode, resize a grid from small to large. Below about 360px it
    shows planet names only; from about 360px it adds degrees; from about
    560px it adds nakshatra and dignity (story 25). Resize a table below
    about 300px: it drops to Planet/Longitude/Hse.

**Settings and regressions**

24. Click the rail's **gear** or run "Settings" from the palette. A settings
    card opens at about 80% of the window with Theme, Display and General
    tabs and no status strip. Switch the theme preset and toggle the glyphs.
    The card stays open while you work; a second open just re-selects it.
25. Toggle Sign Glyphs repeatedly from a card's context menu across several
    right-clicks. The toggle must stay stable (aion/61). Switching renderer
    from the card menu should have no noticeable lag.

## Known gaps, stubs, TODOs

- **Time cursor** (aion/78, aion/79) isn't implemented. The rail button is a
  disabled placeholder.
- **Drishti config keys are unverified.** The config dialog sends
  `ConfigDimension` keys as `calculate_chart` arguments.
- **Semantic-zoom thresholds and highlight colors are untuned** guesses.
- **Workspace transitions:** only as many cards animate as the outgoing
  layout had. Extra cards pop in and surplus cards vanish.
- **No marquee selection and no group drag.**
- **Removed slots:** cards bound to a removed slot resolve and color as slot A
  but keep the dangling id until rebound. That's deliberate, per the
  dangling-id rule.
- **Error surfacing:** chart-load errors go to a SnackBar via
  `ActionContext.onError`. Compute errors show inside the card, as before.
- **Glyph overlay offset (pre-existing):** SVG glyph overlays in `RendererHost`
  are positioned relative to the host, not the centered aspect-ratio chart.
  This was not changed.
- The layering rules still need binding to the real paths: `lib/slots/**`
  must not import `lib/canvas/` or `lib/renderer/`, and `lib/commands/**`
  must not import `lib/canvas/` or renderer implementations. Both hold today.

## Analyze / test: baseline vs final

| | Baseline (`1090f59`) | Final |
|---|---|---|
| `flutter analyze` | 10 issues, all pre-existing (6 warnings: `preset_store.dart:82` `!`, the `chart_db_core` path dependency, 4 missing asset dirs; 4 infos: `_makeChart` ×3 and `_makePreset` local names) | **same 10 issues, none new** |
| `flutter test --exclude-tags integration` | 278 passed | **400 passed**, 0 failed |

Existing tests changed because the behavior they test changed (all logged):

- `card_model_test`, `workspace_state_test`, `workspace_notifier_test`: moved
  from `expressions` to `binding`.
- `workspace_notifier_test`: 3 layout tests now turn on edit mode first.
- `workspace_accent_test`: deleted, because per-chart accents were replaced
  by slot colors.
- `chart_renderer_test`: the fake renderer gained the new optional contract
  parameters.
