import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/mcp/expression_ref.dart';
import 'package:test/test.dart';

const _ref1 = ExpressionRef(chartId: 'chart-1', configHash: 'lahiri');
const _ref2 = ExpressionRef(chartId: 'chart-2', configHash: 'kp');

CardModel _card({List<ExpressionRef> expressions = const []}) {
  return CardModel(
    id: 'c1',
    label: 'Test',
    color: const Color(0xFF000000),
    position: Offset.zero,
    size: const Size(200, 150),
    expressions: expressions,
  );
}

void main() {
  test('default expressions is empty list', () {
    final card = _card();
    expect(card.expressions, isEmpty);
  });

  test('single expression ref', () {
    final card = _card(expressions: [_ref1]);
    expect(card.expressions, hasLength(1));
    expect(card.expressions.first, equals(_ref1));
  });

  test('multiple expression refs for synastry', () {
    final card = _card(expressions: [_ref1, _ref2]);
    expect(card.expressions, hasLength(2));
    expect(card.expressions, containsAll([_ref1, _ref2]));
  });

  test('copyWith preserves expressions when not overridden', () {
    final card = _card(expressions: [_ref1]);
    final moved = card.copyWith(position: const Offset(10, 20));

    expect(moved.expressions, equals([_ref1]));
    expect(moved.position, const Offset(10, 20));
  });

  test('copyWith replaces expressions list', () {
    final card = _card(expressions: [_ref1]);
    final updated = card.copyWith(expressions: [_ref1, _ref2]);

    expect(updated.expressions, equals([_ref1, _ref2]));
    expect(card.expressions, equals([_ref1]));
  });

  test('copyWith to empty expressions', () {
    final card = _card(expressions: [_ref1, _ref2]);
    final cleared = card.copyWith(expressions: const []);

    expect(cleared.expressions, isEmpty);
  });

  test('copyWith does not mutate original', () {
    final card = _card(expressions: [_ref1]);
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
      color: const Color(0xFF000000),
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
      color: const Color(0xFF000000),
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
      color: const Color(0xFF000000),
      position: Offset.zero,
      size: const Size(200, 150),
      displayConfig: const {'show_outer_planets': true},
    );
    final moved = card.copyWith(position: const Offset(10, 20));
    expect(moved.displayConfig, {'show_outer_planets': true});
  });
}
