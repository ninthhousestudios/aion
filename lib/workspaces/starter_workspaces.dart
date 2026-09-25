import 'dart:ui';

import '../slots/card_binding.dart';
import '../slots/slot_state.dart';
import 'workspace.dart';

/// Read-only starter workspaces, sized to the renderers that exist today
/// (south indian grid, data table). All cards follow the default slot, so
/// loading one chart fills the whole layout. "Save as" forks them.
const kStarterWorkspaces = [
  Workspace(
    name: 'Natal Reading',
    readOnly: true,
    cards: [
      WorkspaceCard(
        label: 'Rasi',
        rect: Rect.fromLTWH(16, 48, 520, 520),
        rendererType: 'south_indian',
        binding: SlotBinding(SlotState.kDefaultSlotId),
        preferredAspectRatio: 1,
      ),
      WorkspaceCard(
        label: 'Positions',
        rect: Rect.fromLTWH(552, 48, 560, 520),
        rendererType: 'data_table',
        binding: SlotBinding(SlotState.kDefaultSlotId),
      ),
    ],
  ),
  Workspace(
    name: 'Chart Focus',
    readOnly: true,
    cards: [
      WorkspaceCard(
        label: 'Rasi',
        rect: Rect.fromLTWH(16, 48, 680, 680),
        rendererType: 'south_indian',
        binding: SlotBinding(SlotState.kDefaultSlotId),
        preferredAspectRatio: 1,
      ),
      WorkspaceCard(
        label: 'Positions',
        rect: Rect.fromLTWH(712, 48, 420, 340),
        rendererType: 'data_table',
        binding: SlotBinding(SlotState.kDefaultSlotId),
      ),
      WorkspaceCard(
        label: 'House cusps',
        rect: Rect.fromLTWH(712, 404, 420, 324),
        rendererType: 'data_table',
        binding: SlotBinding(SlotState.kDefaultSlotId),
        displayConfig: {'show_house_cusps': true},
      ),
    ],
  ),
];
