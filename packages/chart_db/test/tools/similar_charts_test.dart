import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/similar_charts.dart';
import 'test_helpers.dart';

void main() {
  late ChartDatabase db;
  late ConfigRepository configRepo;
  late VectorSchemaRepository schemaRepo;
  late VecStore vecStore;
  late SimilaritySearch search;

  setUp(() {
    db = ChartDatabase();
    configRepo = ConfigRepository(db.db);
    schemaRepo = VectorSchemaRepository(db.db);
    vecStore = VecStore(db.db);
    search = SimilaritySearch(
      configRepository: configRepo,
      vectorSchemaRepository: schemaRepo,
      vecStore: vecStore,
    );
    schemaRepo.ensureDefaults();
  });

  tearDown(() => db.close());

  test('returns error for missing chart_id', () {
    final result = handleSimilarCharts({'config_id': 'abc'}, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('chart_id'));
  });

  test('returns error for empty chart_id', () {
    final result = handleSimilarCharts({
      'chart_id': '',
      'config_id': 'abc',
    }, search);

    expect(result.isError, isTrue);
  });

  test('returns error for missing config_id', () {
    final result = handleSimilarCharts({'chart_id': 'abc'}, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('config_id'));
  });

  test('returns error for non-string chart_id', () {
    final result = handleSimilarCharts({
      'chart_id': 123,
      'config_id': 'abc',
    }, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('chart_id'));
  });

  test('returns error for non-number k', () {
    final result = handleSimilarCharts({
      'chart_id': 'abc',
      'config_id': 'def',
      'k': 'many',
    }, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('k'));
  });

  test('returns error for non-map weights', () {
    final result = handleSimilarCharts({
      'chart_id': 'abc',
      'config_id': 'def',
      'weights': [1, 2, 3],
    }, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('weights'));
  });

  test('returns error for non-integer weight key', () {
    final result = handleSimilarCharts({
      'chart_id': 'abc',
      'config_id': 'def',
      'weights': {'sun': 1.5},
    }, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('sun'));
  });

  test('returns error for non-number weight value', () {
    final result = handleSimilarCharts({
      'chart_id': 'abc',
      'config_id': 'def',
      'weights': {'0': 'high'},
    }, search);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('0'));
  });
}
