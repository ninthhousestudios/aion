import 'package:aion/canvas/canvas_actions.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test(
    'every slot has load and config actions; only non-default removable',
    () {
      final c = container();
      c.read(slotsProvider.notifier).addSlot();
      final registry = c.read(actionRegistryProvider);
      for (final id in ['A', 'B']) {
        expect(registry.get(slotLoadActionId(id)), isNotNull);
        expect(registry.get(slotConfigActionId(id)), isNotNull);
      }
      expect(registry.get(slotRemoveActionId('A')), isNull);
      expect(registry.get(slotRemoveActionId('B')), isNotNull);
    },
  );

  test('remove action removes the slot and re-activates A', () async {
    final c = container();
    c.read(slotsProvider.notifier)
      ..addSlot()
      ..setActive('B');
    await c
        .read(actionRegistryProvider)
        .execute(slotRemoveActionId('B'), const ActionContext());
    expect(c.read(slotsProvider).slotById('B'), isNull);
    expect(c.read(slotsProvider).activeSlotId, 'A');
  });

  test('activate action is checked for the active slot only', () {
    final c = container();
    c.read(slotsProvider.notifier).addSlot();
    final registry = c.read(actionRegistryProvider);
    const ctx = ActionContext();
    expect(registry.get('slot.activate.A')?.isChecked?.call(ctx), isTrue);
    expect(registry.get('slot.activate.B')?.isChecked?.call(ctx), isFalse);
  });
}
