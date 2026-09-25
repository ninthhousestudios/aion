import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:test/test.dart';

const _slotA = SlotBinding('A');
const _pinned = PinnedBinding(chartId: 'chart-2', config: {'ayanamsa': 'kp'});

CardModel _card({CardBinding? binding}) {
  return CardModel(
    id: 'c1',
    label: 'Test',

    position: Offset.zero,
    size: const Size(200, 150),
    binding: binding,
  );
}

void main() {
  test('default binding is null (unbound card)', () {
    final card = _card();
    expect(card.binding, isNull);
    expect(card.configOverride, isNull);
  });

  test('slot binding', () {
    final card = _card(binding: _slotA);
    expect(card.binding, equals(const SlotBinding('A')));
  });

  test('pinned binding', () {
    final card = _card(binding: _pinned);
    expect(card.binding, isA<PinnedBinding>());
    expect(
      card.binding,
      equals(
        const PinnedBinding(chartId: 'chart-2', config: {'ayanamsa': 'kp'}),
      ),
    );
  });

  test('copyWith preserves binding when not overridden', () {
    final card = _card(binding: _slotA);
    final moved = card.copyWith(position: const Offset(10, 20));

    expect(moved.binding, equals(_slotA));
    expect(moved.position, const Offset(10, 20));
  });

  test('copyWith replaces binding', () {
    final card = _card(binding: _slotA);
    final updated = card.copyWith(binding: _pinned);

    expect(updated.binding, equals(_pinned));
    expect(card.binding, equals(_slotA));
  });

  test('copyWith can clear binding and override', () {
    final card = _card(
      binding: _slotA,
    ).copyWith(configOverride: {'ayanamsa': 'raman'});
    final cleared = card.copyWith(binding: null, configOverride: null);

    expect(cleared.binding, isNull);
    expect(cleared.configOverride, isNull);
  });

  test('copyWith does not mutate original', () {
    final card = _card(binding: _slotA);
    final copy = card.copyWith(label: 'Changed');

    expect(card.label, 'Test');
    expect(copy.label, 'Changed');
    expect(identical(card, copy), isFalse);
  });

  test('default rendererType is null', () {
    final card = _card();
    expect(card.rendererType, isNull);
  });

  test('default displayConfig is empty map', () {
    final card = _card();
    expect(card.displayConfig, isEmpty);
  });

  test('copyWith preserves rendererType when not overridden', () {
    final card = CardModel(
      id: 'c1',
      label: 'Test',

      position: Offset.zero,
      size: const Size(200, 150),
      rendererType: 'south_indian',
    );
    final moved = card.copyWith(position: const Offset(10, 20));
    expect(moved.rendererType, 'south_indian');
  });

  test('copyWith can set rendererType to a value', () {
    final card = _card();
    final updated = card.copyWith(rendererType: 'south_indian');
    expect(updated.rendererType, 'south_indian');
  });

  test('copyWith can set rendererType back to null', () {
    final card = CardModel(
      id: 'c1',
      label: 'Test',

      position: Offset.zero,
      size: const Size(200, 150),
      rendererType: 'south_indian',
    );
    final cleared = card.copyWith(rendererType: null);
    expect(cleared.rendererType, isNull);
  });

  test('copyWith preserves displayConfig when not overridden', () {
    final card = CardModel(
      id: 'c1',
      label: 'Test',

      position: Offset.zero,
      size: const Size(200, 150),
      displayConfig: const {'show_outer_planets': true},
    );
    final moved = card.copyWith(position: const Offset(10, 20));
    expect(moved.displayConfig, {'show_outer_planets': true});
  });
}
