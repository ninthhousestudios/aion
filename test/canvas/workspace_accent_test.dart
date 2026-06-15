import 'dart:ui';

import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/mcp/expression_ref.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _refA = ExpressionRef(chartId: 'chart-a', configHash: 'h1');
const _refB = ExpressionRef(chartId: 'chart-b', configHash: 'h2');

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('chart-bound card gets an auto-assigned accent', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Chart A',
      expressions: [_refA],
    );
    final state = container.read(workspaceProvider);

    expect(state.chartAccents, contains('chart-a'));
    expect(state.accentForCard(state.cards.first), isNotNull);
  });

  test('chartless card has no accent', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(Offset.zero, const Size(200, 150), 'Plain');
    final state = container.read(workspaceProvider);

    expect(state.accentForCard(state.cards.first), isNull);
    expect(state.chartAccents, isEmpty);
  });

  test('second card for same chart reuses accent', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Card 1',
      expressions: [_refA],
    );
    notifier.addCard(
      const Offset(300, 0),
      const Size(200, 150),
      'Card 2',
      expressions: [_refA],
    );
    final state = container.read(workspaceProvider);

    expect(
      state.accentForCard(state.cards[0]),
      equals(state.accentForCard(state.cards[1])),
    );
    expect(state.accentCounter, 1);
  });

  test('different charts get different accents', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Chart A',
      expressions: [_refA],
    );
    notifier.addCard(
      const Offset(300, 0),
      const Size(200, 150),
      'Chart B',
      expressions: [_refB],
    );
    final state = container.read(workspaceProvider);

    final accentA = state.chartAccents['chart-a'];
    final accentB = state.chartAccents['chart-b'];
    expect(accentA, isNot(equals(accentB)));
    expect(state.accentCounter, 2);
  });

  test('cycleChartAccent advances to next palette color', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Chart A',
      expressions: [_refA],
    );
    final before = container.read(workspaceProvider).chartAccents['chart-a']!;

    notifier.cycleChartAccent('chart-a');
    final after = container.read(workspaceProvider).chartAccents['chart-a']!;

    expect(after, isNot(equals(before)));
  });

  test('cycleChartAccent wraps around palette', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Chart A',
      expressions: [_refA],
    );
    final first = container.read(workspaceProvider).chartAccents['chart-a']!;

    // Cycle through all 8 palette entries to wrap back to start.
    for (var i = 0; i < 8; i++) {
      notifier.cycleChartAccent('chart-a');
    }
    final wrapped = container.read(workspaceProvider).chartAccents['chart-a']!;

    expect(wrapped, equals(first));
  });

  test('cycleChartAccent is no-op for unknown chart', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Chart A',
      expressions: [_refA],
    );
    final before = container.read(workspaceProvider);

    notifier.cycleChartAccent('nonexistent');
    final after = container.read(workspaceProvider);

    expect(after.chartAccents, equals(before.chartAccents));
  });

  test('accentForCard looks up by first expression chartId', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.addCard(
      Offset.zero,
      const Size(200, 150),
      'Multi',
      expressions: [_refA, _refB],
    );
    final state = container.read(workspaceProvider);

    expect(
      state.accentForCard(state.cards.first),
      equals(state.chartAccents['chart-a']),
    );
  });
}
