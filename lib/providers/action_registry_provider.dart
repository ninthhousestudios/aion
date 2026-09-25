import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/canvas_actions.dart';
import '../commands/action_registry.dart';
import '../slots/slot_state.dart';

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
  return ActionRegistry(buildCanvasActions(ref));
});
