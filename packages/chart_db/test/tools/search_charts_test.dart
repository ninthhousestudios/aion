import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/search_charts.dart';

import 'test_helpers.dart';

void main() {
  late ChartDatabase db;
  late ChartRepository repo;

  setUp(() {
    db = ChartDatabase();
    repo = ChartRepository(db.db);
  });

  tearDown(() => db.close());

  test('returns empty results for empty db', () {
    final result = handleSearchCharts({}, repo);

    expect(result.isError, isFalse);
    expect(result.structuredContent!['count'], 0);
    expect(result.structuredContent!['charts'], isEmpty);
  });

  test('returns charts matching query', () {
    repo.insert(makeChart(name: 'Isaac Newton'));
    repo.insert(makeChart(
      name: 'Albert Einstein',
      jd: 2451546.0,
      lat: 48.4,
      lon: 11.8,
    ));

    final result = handleSearchCharts({'query': 'Newton'}, repo);

    expect(result.isError, isFalse);
    expect(result.structuredContent!['count'], 1);
    final charts = result.structuredContent!['charts'] as List;
    expect(charts.first['name'], 'Isaac Newton');
  });

  test('filters by country', () {
    repo.insert(makeChart(name: 'A', country: 'England'));
    repo.insert(makeChart(
      name: 'B',
      country: 'Germany',
      jd: 2451546.0,
      lat: 48.4,
      lon: 11.8,
    ));

    final result = handleSearchCharts({'country': 'Germany'}, repo);

    expect(result.structuredContent!['count'], 1);
    final charts = result.structuredContent!['charts'] as List;
    expect(charts.first['name'], 'B');
  });

  test('respects limit', () {
    for (var i = 0; i < 5; i++) {
      repo.insert(makeChart(
        name: 'Chart $i',
        jd: 2451545.0 + i,
        lat: 51.0 + i,
      ));
    }

    final result = handleSearchCharts({'limit': 2}, repo);

    expect(result.structuredContent!['count'], 2);
  });

  test('returns error for invalid limit type', () {
    final result = handleSearchCharts({'limit': 'many'}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('limit'));
  });
}
