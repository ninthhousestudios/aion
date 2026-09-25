import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/canvas_actions.dart';
import '../slots/chart_slot.dart';
import '../slots/slot_state.dart';
import '../theme/aion_theme.dart';
import 'rail.dart';

/// Rail flyout for managing chart slots: color, label, active slot, the
/// loaded chart, and entry points to load a chart or edit slot config.
/// Operations that need the file picker or the config dialog go through
/// registry actions via [onAction].
class SlotsFlyout extends ConsumerWidget {
  const SlotsFlyout({super.key, required this.onAction});

  final void Function(String actionId) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final state = ref.watch(slotsProvider);
    return FlyoutPanel(
      title: 'Chart slots',
      width: 400,
      child: ListView(
        children: [
          for (final slot in state.slots)
            _SlotRow(
              key: ValueKey(slot.id),
              slot: slot,
              active: slot.id == state.activeSlotId,
              onAction: onAction,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.read(slotsProvider.notifier).addSlot(),
              icon: Icon(Icons.add, size: 16, color: t.chromeIconColor),
              label: Text(
                'Add slot',
                style: TextStyle(color: t.cardLabelColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends ConsumerStatefulWidget {
  const _SlotRow({
    super.key,
    required this.slot,
    required this.active,
    required this.onAction,
  });

  final ChartSlot slot;
  final bool active;
  final void Function(String actionId) onAction;

  @override
  ConsumerState<_SlotRow> createState() => _SlotRowState();
}

class _SlotRowState extends ConsumerState<_SlotRow> {
  late final _label = TextEditingController(text: widget.slot.label);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_SlotRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _label.text != widget.slot.label) {
      _label.text = widget.slot.label;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final slot = widget.slot;
    final slots = ref.read(slotsProvider.notifier);
    final dim = TextStyle(color: t.cardDimColor, fontSize: 11);

    IconButton iconButton(IconData icon, String tip, VoidCallback onTap) =>
        IconButton(
          icon: Icon(icon, size: 16, color: t.chromeIconColor),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: widget.active ? t.chromeButtonHover : null,
        border: Border.all(color: t.surfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          iconButton(
            widget.active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            'Make active',
            () => slots.setActive(slot.id),
          ),
          Tooltip(
            message: 'Change color',
            child: InkWell(
              onTap: () => slots.setColorIndex(slot.id, slot.colorIndex + 1),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: t.slotColor(slot.colorIndex),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _label,
                  focusNode: _focus,
                  style: TextStyle(color: t.cardLabelColor, fontSize: 13),
                  cursorColor: t.snapAccent,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    prefixText: '${slot.id}  ',
                    prefixStyle: dim,
                  ),
                  onChanged: (v) => slots.rename(slot.id, v),
                ),
                Text(slot.chartName ?? 'Empty', style: dim),
              ],
            ),
          ),
          iconButton(
            Icons.folder_open,
            'Load chart',
            () => widget.onAction(slotLoadActionId(slot.id)),
          ),
          iconButton(
            Icons.tune,
            'Expression config',
            () => widget.onAction(slotConfigActionId(slot.id)),
          ),
          if (slot.id != SlotState.kDefaultSlotId)
            iconButton(
              Icons.close,
              'Remove slot',
              () => widget.onAction(slotRemoveActionId(slot.id)),
            ),
        ],
      ),
    );
  }
}
