import 'dart:convert';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/create_config.dart';

import 'test_helpers.dart';

void main() {
  late ChartDatabase db;
  late ConfigRepository repo;

  setUp(() {
    db = ChartDatabase();
    repo = ConfigRepository(db.db);
  });

  tearDown(() => db.close());

  String preset(List<String> bodies) =>
      jsonEncode({'sweConfig': {'bodies': bodies}});

  test('creates a config and returns its fields', () {
    final result = handleCreateConfig({
      'name': 'tropical',
      'preset_json': preset(['Sun', 'Moon']),
    }, repo);

    expect(result.isError, isFalse);
    final data = result.structuredContent!;
    expect(data['name'], 'tropical');
    expect(data['id'], isA<String>());
    expect(data['preset'], preset(['Sun', 'Moon']));
    expect(data.containsKey('created_at'), isTrue);
  });

  test('idempotent: same preset returns same id', () {
    final p = preset(['Sun']);
    final r1 = handleCreateConfig({'name': 'a', 'preset_json': p}, repo);
    final r2 = handleCreateConfig({'name': 'b', 'preset_json': p}, repo);

    expect(r1.structuredContent!['id'], r2.structuredContent!['id']);
  });

  test('returns error for missing name', () {
    final result = handleCreateConfig({'preset_json': '{}'}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('name'));
  });

  test('returns error for empty name', () {
    final result = handleCreateConfig({
      'name': '',
      'preset_json': '{}',
    }, repo);

    expect(result.isError, isTrue);
  });

  test('returns error for missing preset_json', () {
    final result = handleCreateConfig({'name': 'test'}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('preset_json'));
  });

  test('returns error for non-string name', () {
    final result = handleCreateConfig({
      'name': 42,
      'preset_json': '{}',
    }, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('name'));
  });

  test('returns error for non-string schema_id', () {
    final result = handleCreateConfig({
      'name': 'test',
      'preset_json': '{}',
      'schema_id': 123,
    }, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('schema_id'));
  });
}
