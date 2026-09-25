import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/chart_slot.dart';
import 'package:aion/slots/expression_resolution.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

SlotState _slots() => SlotState(
  slots: const [
    ChartSlot(
      id: 'A',
      label: 'Client',
      colorIndex: 0,
      chartId: 'ravi',
      config: {'ayanamsa': 'lahiri'},
    ),
    ChartSlot(
      id: 'B',
      label: 'Partner',
      colorIndex: 1,
      chartId: 'sita',
      config: {'ayanamsa': 'raman'},
    ),
    ChartSlot(id: 'C', label: 'Empty', colorIndex: 2),
  ],
  activeSlotId: 'A',
);

void main() {
  group('resolveCardExpression', () {
    test('slot binding uses slot chart and slot config', () {
      final r = resolveCardExpression(const SlotBinding('B'), _slots());
      expect(r?.chartId, 'sita');
      expect(r?.config, {'ayanamsa': 'raman'});
    });

    test('card override wins over slot config', () {
      final r = resolveCardExpression(
        const SlotBinding('A'),
        _slots(),
        configOverride: {'ayanamsa': 'kp'},
      );
      final plain = resolveCardExpression(const SlotBinding('A'), _slots());
      expect(r?.chartId, 'ravi');
      expect(r?.config, {'ayanamsa': 'kp'});
      expect(r?.ref, isNot(equals(plain?.ref)));
    });

    test('same chart + same config resolve to the same ref', () {
      final viaSlot = resolveCardExpression(const SlotBinding('A'), _slots());
      const pinned = PinnedBinding(
        chartId: 'ravi',
        config: {'ayanamsa': 'lahiri'},
      );
      final viaPin = resolveCardExpression(pinned, _slots());
      expect(viaSlot?.ref, equals(viaPin?.ref));
    });

    test('config key order does not change the ref', () {
      final a = resolveCardExpression(
        const PinnedBinding(chartId: 'x', config: {'a': 1, 'b': 2}),
        _slots(),
      );
      final b = resolveCardExpression(
        const PinnedBinding(chartId: 'x', config: {'b': 2, 'a': 1}),
        _slots(),
      );
      expect(a?.ref, equals(b?.ref));
    });

    test('pinned binding ignores slots', () {
      const pinned = PinnedBinding(chartId: 'ref', config: {'k': 'v'});
      final before = resolveCardExpression(pinned, _slots());
      final changed = _slots().copyWith(
        slots: [
          for (final s in _slots().slots)
            s.copyWith(chartId: 'other', config: {'k': 'changed'}),
        ],
      );
      final after = resolveCardExpression(pinned, changed);
      expect(after?.ref, equals(before?.ref));
      expect(after?.chartId, 'ref');
    });

    test('pinned override wins over pinned config', () {
      final r = resolveCardExpression(
        const PinnedBinding(chartId: 'ref', config: {'k': 'v'}),
        _slots(),
        configOverride: {'k': 'o'},
      );
      expect(r?.config, {'k': 'o'});
    });

    test('empty slot and unbound card resolve to null', () {
      expect(resolveCardExpression(const SlotBinding('C'), _slots()), isNull);
      expect(resolveCardExpression(null, _slots()), isNull);
    });

    test('dangling slot id resolves against the default slot', () {
      final r = resolveCardExpression(const SlotBinding('Z'), _slots());
      expect(r?.chartId, 'ravi');
    });

    test('set values are canonicalized to sorted lists', () {
      final r = resolveCardExpression(
        const PinnedBinding(
          chartId: 'x',
          config: {
            'bodies': {'moon', 'sun'},
          },
        ),
        _slots(),
      );
      expect(r?.config['bodies'], ['moon', 'sun']);
    });
  });

  group('propagation scoping', () {
    final bindings = <String, CardBinding?>{
      'a1': const SlotBinding('A'),
      'a2': const SlotBinding('A'),
      'b1': const SlotBinding('B'),
      'p1': const PinnedBinding(chartId: 'ravi'),
      'u1': null,
    };

    test('boundToSlot selects exactly the cards of that slot', () {
      expect(boundToSlot(bindings.keys, (k) => bindings[k], 'A'), ['a1', 'a2']);
      expect(boundToSlot(bindings.keys, (k) => bindings[k], 'B'), ['b1']);
      expect(boundToSlot(bindings.keys, (k) => bindings[k], 'C'), isEmpty);
    });

    test('slot chart change changes exactly the bound cards refs', () {
      final before = _slots();
      final after = before.copyWith(
        slots: [
          for (final s in before.slots)
            s.id == 'A' ? s.copyWith(chartId: 'new-client') : s,
        ],
      );
      final changed = [
        for (final e in bindings.entries)
          if (resolveCardExpression(e.value, before)?.ref !=
              resolveCardExpression(e.value, after)?.ref)
            e.key,
      ];
      expect(changed, ['a1', 'a2']);
    });

    test('slot config change changes exactly the bound cards refs', () {
      final before = _slots();
      final after = before.copyWith(
        slots: [
          for (final s in before.slots)
            s.id == 'B' ? s.copyWith(config: {'ayanamsa': 'kp'}) : s,
        ],
      );
      final changed = [
        for (final e in bindings.entries)
          if (resolveCardExpression(e.value, before)?.ref !=
              resolveCardExpression(e.value, after)?.ref)
            e.key,
      ];
      expect(changed, ['b1']);
    });
  });

  group('SlotsNotifier', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('default slot A exists and is active', () {
      final state = container().read(slotsProvider);
      expect(state.slots.map((s) => s.id), ['A']);
      expect(state.activeSlotId, 'A');
    });

    test('slot A cannot be removed', () {
      final c = container();
      c.read(slotsProvider.notifier).removeSlot('A');
      expect(c.read(slotsProvider).slotById('A'), isNotNull);
    });

    test('add, activate, remove active falls back to A', () {
      final c = container();
      final n = c.read(slotsProvider.notifier);
      final id = n.addSlot();
      expect(id, 'B');
      n.setActive('B');
      expect(c.read(slotsProvider).activeSlotId, 'B');
      n.removeSlot('B');
      expect(c.read(slotsProvider).activeSlotId, 'A');
      expect(c.read(slotsProvider).slotById('B'), isNull);
    });

    test('setChart with no slot targets the active slot', () {
      final c = container();
      final n = c.read(slotsProvider.notifier);
      n.addSlot();
      n.setActive('B');
      n.setChart(null, 'chart-1', chartName: 'Ravi');
      expect(c.read(slotsProvider).slotById('B')?.chartId, 'chart-1');
      expect(c.read(slotsProvider).slotById('A')?.chartId, isNull);
    });

    test('rename, recolor, config, clear', () {
      final c = container();
      final n = c.read(slotsProvider.notifier)
        ..rename('A', 'Client')
        ..setColorIndex('A', 3)
        ..setConfig('A', {'ayanamsa': 'kp'})
        ..setChart('A', 'x')
        ..clearChart('A');
      expect(n, isNotNull);
      final a = c.read(slotsProvider).slotById('A');
      expect(a?.label, 'Client');
      expect(a?.colorIndex, 3);
      expect(a?.config, {'ayanamsa': 'kp'});
      expect(a?.isEmpty, isTrue);
    });
  });
}
