import 'package:aion/mcp/expression_ref.dart';
import 'package:test/test.dart';

void main() {
  test('equal refs with same chartId and configHash', () {
    const a = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');
    const b = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('different chartId produces inequality', () {
    const a = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');
    const b = ExpressionRef(chartId: 'chart-2', configHash: 'abc123');

    expect(a, isNot(equals(b)));
  });

  test('different configHash produces inequality', () {
    const a = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');
    const b = ExpressionRef(chartId: 'chart-1', configHash: 'def456');

    expect(a, isNot(equals(b)));
  });

  test('works as map key', () {
    const ref = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');
    final map = <ExpressionRef, String>{ref: 'value'};

    const lookup = ExpressionRef(chartId: 'chart-1', configHash: 'abc123');
    expect(map[lookup], equals('value'));
  });

  test('toString includes both fields', () {
    const ref = ExpressionRef(chartId: 'c1', configHash: 'h1');
    expect(ref.toString(), contains('c1'));
    expect(ref.toString(), contains('h1'));
  });
}
