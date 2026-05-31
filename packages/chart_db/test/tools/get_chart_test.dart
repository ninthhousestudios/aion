import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/get_chart.dart';

import 'test_helpers.dart';

void main() {
  late ChartDatabase db;
  late ChartRepository repo;

  setUp(() {
    db = ChartDatabase();
    repo = ChartRepository(db.db);
  });

  tearDown(() => db.close());

  test('returns chart by id', () {
    final id = repo.insert(makeChart(name: 'Newton'));

    final result = handleGetChart({'id': id}, repo);

    expect(result.isError, isFalse);
    expect(result.structuredContent!['id'], id);
    expect(result.structuredContent!['name'], 'Newton');
    expect(result.structuredContent!['jd'], 2451545.0);
  });

  test('omits null optional fields', () {
    final id = repo.insert(makeChart(notes: null, rodden: null));

    final result = handleGetChart({'id': id}, repo);

    expect(result.structuredContent!.containsKey('notes'), isFalse);
    expect(result.structuredContent!.containsKey('rodden'), isFalse);
  });

  test('includes non-null optional fields', () {
    final id = repo.insert(makeChart(notes: 'test note', rodden: 'A'));

    final result = handleGetChart({'id': id}, repo);

    expect(result.structuredContent!['notes'], 'test note');
    expect(result.structuredContent!['rodden'], 'A');
  });

  test('returns error for missing id', () {
    final result = handleGetChart({}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('id'));
  });

  test('returns error for empty id', () {
    final result = handleGetChart({'id': ''}, repo);

    expect(result.isError, isTrue);
  });

  test('returns error for non-string id', () {
    final result = handleGetChart({'id': 123}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('id'));
  });

  test('returns error for nonexistent chart', () {
    final result = handleGetChart({'id': 'no-such-id'}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('not found'));
  });
}
