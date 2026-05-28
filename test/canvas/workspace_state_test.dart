import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/canvas/workspace_state.dart';
import 'package:aion/mcp/expression_ref.dart';
import 'package:test/test.dart';

const _ref1 = ExpressionRef(chartId: 'chart-1', configHash: 'lahiri');
const _ref2 = ExpressionRef(chartId: 'chart-2', configHash: 'kp');

CardModel _card(String id, {int zOrder = 0, List<ExpressionRef> expressions = const []}) {
  return CardModel(
    id: id,
    label: 'Card $id',
    color: const Color(0xFF000000),
    position: Offset.zero,
    size: const Size(200, 150),
    expressions: expressions,
    zOrder: zOrder,
  );
}

void main() {
  test('initial state has empty cards', () {
    final state = WorkspaceState.initial();
    expect(state.cards, isEmpty);
    expect(state.selectedId, isNull);
    expect(state.snapEnabled, isTrue);
    expect(state.nextZ, 0);
    expect(state.cardCounter, 0);
  });

  test('cardById returns matching card', () {
    final card = _card('a');
    final state = WorkspaceState(
      cards: [card, _card('b')],
      selectedId: null,
      guides: const [],
      snapEnabled: true,
      nextZ: 2,
      cardCounter: 2,
    );

    expect(state.cardById('a'), equals(card));
  });

  test('cardById returns null for missing id', () {
    final state = WorkspaceState(
      cards: [_card('a')],
      selectedId: null,
      guides: const [],
      snapEnabled: true,
      nextZ: 1,
      cardCounter: 1,
    );

    expect(state.cardById('z'), isNull);
  });

  test('cards list is unmodifiable', () {
    final state = WorkspaceState(
      cards: [_card('a')],
      selectedId: null,
      guides: const [],
      snapEnabled: true,
      nextZ: 1,
      cardCounter: 1,
    );

    expect(() => state.cards.add(_card('b')), throwsUnsupportedError);
  });

  test('sortedCards returns by ascending zOrder', () {
    final state = WorkspaceState(
      cards: [_card('a', zOrder: 3), _card('b', zOrder: 1), _card('c', zOrder: 2)],
      selectedId: null,
      guides: const [],
      snapEnabled: true,
      nextZ: 4,
      cardCounter: 3,
    );

    final sorted = state.sortedCards;
    expect(sorted.map((c) => c.id).toList(), equals(['b', 'c', 'a']));
  });

  test('copyWith preserves fields when not overridden', () {
    final state = WorkspaceState(
      cards: [_card('a', expressions: [_ref1])],
      selectedId: 'a',
      guides: const [],
      snapEnabled: false,
      nextZ: 5,
      cardCounter: 3,
    );

    final copy = state.copyWith(snapEnabled: true);
    expect(copy.cards, hasLength(1));
    expect(copy.cards.first.expressions, equals([_ref1]));
    expect(copy.selectedId, 'a');
    expect(copy.snapEnabled, isTrue);
    expect(copy.nextZ, 5);
    expect(copy.cardCounter, 3);
  });

  test('cards with expression bindings round-trip through copyWith', () {
    final card = _card('synastry', expressions: [_ref1, _ref2]);
    final state = WorkspaceState(
      cards: [card],
      selectedId: null,
      guides: const [],
      snapEnabled: true,
      nextZ: 1,
      cardCounter: 1,
    );

    final updated = state.copyWith(
      cards: [
        ...state.cards,
        _card('single', expressions: [_ref1]),
      ],
    );

    expect(updated.cards, hasLength(2));
    expect(updated.cardById('synastry')!.expressions, equals([_ref1, _ref2]));
    expect(updated.cardById('single')!.expressions, equals([_ref1]));
  });
}
