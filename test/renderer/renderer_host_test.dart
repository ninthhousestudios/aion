import 'package:chart_model/chart_model.dart';
import 'package:aion/renderer/renderer_host.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_expressions.dart';

void main() {
  group('expressionListsEqual', () {
    const a = testExpression;
    // A distinct instance with the same content: identity is what counts.
    final b = ChartExpression(
      planets: testExpression.planets,
      ascendant: testExpression.ascendant,
      houses: testExpression.houses,
    );

    test('fresh list around the same expression is equal', () {
      expect(expressionListsEqual([a], [a]), isTrue);
    });

    test('different expression instance is not equal', () {
      expect(expressionListsEqual([a], [b]), isFalse);
    });

    test('length mismatch is not equal', () {
      expect(expressionListsEqual([a], [a, a]), isFalse);
      expect(expressionListsEqual(const [], [a]), isFalse);
    });

    test('empty lists are equal', () {
      expect(expressionListsEqual(const [], const []), isTrue);
    });
  });
}
