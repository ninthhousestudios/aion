import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/canvas_actions.dart';
import '../commands/action_registry.dart';
import '../slots/slot_state.dart';
import '../workspaces/workspace_actions.dart';
import '../workspaces/workspace_store.dart';

/// The app's single action registry. Rebuilt when the set of slots changes
/// (per-slot actions); everything else is read at execute time.
final actionRegistryProvider = Provider<ActionRegistry>((ref) {
  ref.watch(
    slotsProvider.select(
      (s) => [
        for (final slot in s.slots)
          '${slot.id}|${slot.label}|${slot.chartName}',
      ].join(','),
    ),
  );
  ref.watch(
    workspaceLibraryProvider.select(
      (lib) =>
          [for (final w in lib.valueOrNull?.all ?? const []) w.name].join('\n'),
    ),
  );
  return ActionRegistry([
    ...buildCanvasActions(ref),
    ...buildWorkspaceActions(ref),
  ]);
});
