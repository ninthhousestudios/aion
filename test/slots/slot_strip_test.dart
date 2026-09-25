import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/chart_slot.dart';
import 'package:aion/slots/expression_resolution.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:aion/theme/aion_theme.dart';
import 'package:aion/theme/display_options.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:aion/theme/theme_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

const _resolver = ThemeResolver(
  preset: ThemePreset.dark,
  globalDisplayOptions: DisplayOptions.defaultOptions,
);

CardModel _card(CardBinding? binding) => CardModel(
  id: 'c',
  label: 'c',
  position: Offset.zero,
  size: const Size(100, 100),
  binding: binding,
);

SlotState _slots() => SlotState(
  slots: const [
    ChartSlot(
      id: 'A',
      label: 'Client',
      colorIndex: 0,
      chartId: 'ravi',
      chartName: 'Ravi',
      config: {'ayanamsa': 'lahiri'},
    ),
    ChartSlot(id: 'B', label: 'Partner', colorIndex: 1),
  ],
  activeSlotId: 'A',
);

void main() {
  final theme = AionTheme.fromPreset(ThemePreset.dark);

  group('status strip', () {
    test('slot-bound card shows its slot color', () {
      final strip = _resolver.stripFor(_card(const SlotBinding('B')), _slots());
      expect(strip?.color, theme.slotColor(1));
      expect(strip?.pinned, isFalse);
    });

    test('recoloring the slot changes the strip', () {
      final recolored = _slots().copyWith(
        slots: [
          for (final s in _slots().slots)
            s.id == 'B' ? s.copyWith(colorIndex: 4) : s,
        ],
      );
      final strip = _resolver.stripFor(
        _card(const SlotBinding('B')),
        recolored,
      );
      expect(strip?.color, theme.slotColor(4));
    });

    test('dangling slot id uses the default slot color', () {
      final strip = _resolver.stripFor(_card(const SlotBinding('Q')), _slots());
      expect(strip?.color, theme.slotColor(0));
    });

    test('pinned card shows pin indicator', () {
      final strip = _resolver.stripFor(
        _card(const PinnedBinding(chartId: 'x')),
        _slots(),
      );
      expect(strip?.pinned, isTrue);
    });

    test('unbound card has no strip', () {
      expect(_resolver.stripFor(_card(null), _slots()), isNull);
    });

    test('slot palette wraps', () {
      final n = theme.slotPalette.length;
      expect(theme.slotColor(n + 2), theme.slotColor(2));
    });
  });

  group('pinning', () {
    test('pin captures slot chart and effective config', () {
      final pinned = pinnedBindingFor(
        const SlotBinding('A'),
        _slots(),
        configOverride: {'ayanamsa': 'kp'},
      );
      expect(pinned?.chartId, 'ravi');
      expect(pinned?.chartName, 'Ravi');
      expect(pinned?.config, {'ayanamsa': 'kp'});
    });

    test('cannot pin empty slot or pinned card', () {
      expect(pinnedBindingFor(const SlotBinding('B'), _slots()), isNull);
      expect(
        pinnedBindingFor(const PinnedBinding(chartId: 'x'), _slots()),
        isNull,
      );
    });

    test('pinned card resolves to the same ref it showed before pinning', () {
      final before = resolveCardExpression(const SlotBinding('A'), _slots());
      final pinned = pinnedBindingFor(const SlotBinding('A'), _slots());
      expect(resolveCardExpression(pinned, _slots())?.ref, before?.ref);
    });

    test('pinCard sets binding and clears override', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(workspaceProvider.notifier)
        ..addCard(
          Offset.zero,
          const Size(10, 10),
          'x',
          binding: const SlotBinding('A'),
        )
        ..setCardConfigOverride('card_0', {'k': 'v'})
        ..pinCard('card_0', const PinnedBinding(chartId: 'ravi'));
      expect(n, isNotNull);
      final card = c.read(workspaceProvider).cardById('card_0');
      expect(card?.binding, const PinnedBinding(chartId: 'ravi'));
      expect(card?.configOverride, isNull);
    });

    test('slotMenuLabel', () {
      expect(slotMenuLabel(_slots().slots.first), 'Slot A · Client — Ravi');
      expect(slotMenuLabel(SlotState.defaultSlot), 'Slot A');
    });
  });
}
