import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

/// A minimal preset JSON that includes all 13 western bodies.
const _presetJson = '{"sweConfig":{"bodies":'
    '["sun","moon","mercury","venus","mars","jupiter","saturn",'
    '"uranus","neptune","pluto","chiron","rahu","ketu"]}}';

void main() {
  late ChartDatabase chartDb;
  late VectorSchemaRepository schemaRepo;
  late ConfigRepository configRepo;
  late VecStore vecStore;
  late SimilaritySearch search;
  late VectorSchema schema;
  late Config config;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    schemaRepo = VectorSchemaRepository(chartDb.db);
    configRepo = ConfigRepository(chartDb.db);
    vecStore = VecStore(chartDb.db);

    // Register a simple 4-dim schema (2 bodies x 2 sin/cos).
    schema = schemaRepo.register('test-4', {
      'bodies': ['sun', 'moon'],
      'features': {'longitudes': true},
    });
    // dims = 2 bodies x 2 (sin/cos) = 4

    vecStore.ensureTable(schema);

    // Register a config that references this schema.
    config = configRepo.register(
      'test-config',
      _presetJson,
      vectorSchemaId: schema.id,
    );

    search = SimilaritySearch(
      configRepository: configRepo,
      vectorSchemaRepository: schemaRepo,
      vecStore: vecStore,
    );
  });

  tearDown(() {
    chartDb.close();
  });

  test('findSimilar returns identical vector as top result', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'chart-a', config.id, v);
    vecStore.insertVector(schema.id, 'chart-b', config.id, v);

    final results = search.findSimilar('chart-a', config.id);

    expect(results, hasLength(1));
    expect(results[0].chartId, equals('chart-b'));
    expect(results[0].distance, closeTo(0.0, 1e-10));
  });

  test('weighted search changes ranking', () {
    // v1 emphasizes dim 0, v2 emphasizes dim 2.
    final vQuery = Float64List.fromList([0.8, 0.2, 0.5, 0.5]);
    final vA = Float64List.fromList([0.9, 0.1, 0.0, 0.0]); // strong on dim 0
    final vB = Float64List.fromList([0.0, 0.0, 0.9, 0.1]); // strong on dim 2

    vecStore.insertVector(schema.id, 'query', config.id, vQuery);
    vecStore.insertVector(schema.id, 'chart-a', config.id, vA);
    vecStore.insertVector(schema.id, 'chart-b', config.id, vB);

    // Without weights: query is closer to chart-a (shares dim 0 energy).
    final unweighted = search.findSimilar('query', config.id);
    expect(unweighted[0].chartId, equals('chart-a'));

    // With weights that zero out dims 0-1 and emphasize dims 2-3:
    final weighted = search.findSimilar(
      'query',
      config.id,
      weights: {0: 0.0, 1: 0.0, 2: 10.0, 3: 10.0},
    );
    expect(weighted[0].chartId, equals('chart-b'));
  });

  test('uniform weights produce same ranking as no weights', () {
    final vQuery = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    final vA = Float64List.fromList([0.9, 0.1, 0.0, 0.0]);
    final vB = Float64List.fromList([0.0, 1.0, 0.0, 0.0]);

    vecStore.insertVector(schema.id, 'query', config.id, vQuery);
    vecStore.insertVector(schema.id, 'chart-a', config.id, vA);
    vecStore.insertVector(schema.id, 'chart-b', config.id, vB);

    final noWeights = search.findSimilar('query', config.id);
    final uniformWeights = search.findSimilar(
      'query',
      config.id,
      weights: {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0},
    );

    expect(noWeights.length, equals(uniformWeights.length));
    for (var i = 0; i < noWeights.length; i++) {
      expect(uniformWeights[i].chartId, equals(noWeights[i].chartId));
      expect(
        uniformWeights[i].distance,
        closeTo(noWeights[i].distance, 1e-10),
      );
    }
  });

  test('query chart is excluded from its own results', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'chart-a', config.id, v);
    vecStore.insertVector(schema.id, 'chart-b', config.id, v);
    vecStore.insertVector(schema.id, 'chart-c', config.id, v);

    final results = search.findSimilar('chart-a', config.id);

    final ids = results.map((r) => r.chartId).toList();
    expect(ids, isNot(contains('chart-a')));
    expect(ids, contains('chart-b'));
    expect(ids, contains('chart-c'));
  });

  test('k limit is respected', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'query', config.id, v);
    for (var i = 0; i < 5; i++) {
      vecStore.insertVector(schema.id, 'chart-$i', config.id, v);
    }

    final results = search.findSimilar('query', config.id, k: 2);
    expect(results, hasLength(2));
  });

  test('chart with no vector returns empty list', () {
    // Don't insert any vector for 'missing-chart'.
    final results = search.findSimilar('missing-chart', config.id);
    expect(results, isEmpty);
  });

  test('invalid config id throws StateError', () {
    expect(
      () => search.findSimilar('chart-a', 'nonexistent-config'),
      throwsA(isA<StateError>()),
    );
  });

  test('config with no vector schema throws StateError', () {
    // Register a config without a vector schema.
    final noSchemaConfig = configRepo.register(
      'no-schema',
      '{"sweConfig":{"bodies":["sun"]}}',
    );

    expect(
      () => search.findSimilar('chart-a', noSchemaConfig.id),
      throwsA(isA<StateError>()),
    );
  });
}
