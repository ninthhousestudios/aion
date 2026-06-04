import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  test('same config, different key order → same hash', () {
    final a = configHash('{"b": 1, "a": 2}');
    final b = configHash('{"a": 2, "b": 1}');
    expect(a, equals(b));
  });

  test('nested maps are canonicalized', () {
    final a = configHash('{"outer": {"z": 1, "a": 2}}');
    final b = configHash('{"outer": {"a": 2, "z": 1}}');
    expect(a, equals(b));
  });

  test('arrays preserve order', () {
    final a = configHash('{"items": [1, 2, 3]}');
    final b = configHash('{"items": [3, 2, 1]}');
    expect(a, isNot(equals(b)));
  });

  test('output is a 64-char hex string', () {
    final h = configHash('{"key": "value"}');
    expect(h, hasLength(64));
    expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('unparseable JSON throws ArgumentError', () {
    expect(() => configHash('not json {{'), throwsArgumentError);
  });
}
