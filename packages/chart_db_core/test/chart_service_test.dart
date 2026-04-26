import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

/// Mock chart calculation that returns a deterministic chart JSON map.
///
/// The output matches the drishti formatter structure and includes all fields
/// needed by both western and vedic vector schemas.
Future<Map<String, dynamic>> mockCalculateChart(
  double jd,
  double lat,
  double lon,
  String presetJson,
) async {
  return {
    'summary': {
      'jd': jd,
      'ayanamsa': 24.1,
      'ascendant': 30.0,
      'mc': 120.0,
    },
    'planets': [
      for (final name in [
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
        'uranus', 'neptune', 'pluto', 'chiron', 'rahu', 'ketu',
      ])
        {
          'name': name,
          'longitude': (jd * 13.37 + name.hashCode) % 360,
          'is_retrograde': name == 'saturn',
          'house_number': (name.hashCode % 12) + 1,
          'nakshatra': name.hashCode % 27,
        },
    ],
    'houses': [
      for (var i = 1; i <= 12; i++)
        {'number': i, 'longitude': (i * 30.0 + jd) % 360},
    ],
    'ascmc': {
      'armc': 123.4,
      'vertex': 234.5,
      'equatorial_ascendant': 345.6,
      'co_ascendant_koch': 12.3,
      'co_ascendant_munkasey': 45.6,
      'polar_ascendant': 78.9,
    },
  };
}

/// Tracks how many times the calculate callback was invoked.
int _callCount = 0;

Future<Map<String, dynamic>> _countingCalculateChart(
  double jd,
  double lat,
  double lon,
  String presetJson,
) async {
  _callCount++;
  return mockCalculateChart(jd, lat, lon, presetJson);
}

void main() {
  late ChartDatabase chartDb;
  late ChartRepository chartRepo;
  late ConfigRepository configRepo;
  late VectorSchemaRepository schemaRepo;
  late VecStore vecStore;
  late ChartService service;

  // Default schema and config created in setUp.
  late VectorSchema westernSchema;
  late Config westernConfig;

  /// Preset JSON for a 13-body western config.
  const westernPreset = '{"sweConfig":{"bodies":["sun","moon","mercury",'
      '"venus","mars","jupiter","saturn","uranus","neptune","pluto",'
      '"chiron","rahu","ketu"]}}';

  Chart _makeChart({
    String id = '',
    double jd = 2451545.0,
    double lat = 40.7128,
    double lon = -74.006,
    String name = 'Test Chart',
  }) {
    final now = DateTime.now();
    return Chart(
      id: id,
      jd: jd,
      lat: lat,
      lon: lon,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    chartRepo = ChartRepository(chartDb.db);
    configRepo = ConfigRepository(chartDb.db);
    schemaRepo = VectorSchemaRepository(chartDb.db);
    vecStore = VecStore(chartDb.db);

    // Register default western schema.
    schemaRepo.ensureDefaults();
    westernSchema = schemaRepo.list().firstWhere((s) => s.name == 'western-13');

    // Register a config that uses the western schema.
    westernConfig = configRepo.register(
      'western',
      westernPreset,
      vectorSchemaId: westernSchema.id,
    );

    // Create the vec table for the schema.
    vecStore.ensureTable(westernSchema);

    _callCount = 0;

    service = ChartService(
      chartRepository: chartRepo,
      configRepository: configRepo,
      vectorSchemaRepository: schemaRepo,
      vecStore: vecStore,
      calculateChart: _countingCalculateChart,
    );
  });

  tearDown(() {
    chartDb.close();
  });

  test('createChart inserts chart and stores vector', () async {
    final chart = _makeChart(id: 'chart-1');
    final id = await service.createChart(chart);

    expect(id, equals('chart-1'));

    // Chart should be retrievable.
    final stored = chartRepo.get('chart-1');
    expect(stored, isNotNull);
    expect(stored!.name, equals('Test Chart'));

    // Vector should be stored.
    final vec = vecStore.getVector(westernSchema.id, 'chart-1', westernConfig.id);
    expect(vec, isNotNull);
    expect(vec!.length, equals(westernSchema.dims));

    // calculateChart should have been called once.
    expect(_callCount, equals(1));
  });

  test('createChart with specific configIds only processes those configs',
      () async {
    // Register a second config without a vector schema.
    final noVecConfig = configRepo.register(
      'no-vec',
      '{"sweConfig":{"bodies":["sun"]}}',
    );

    final chart = _makeChart(id: 'chart-2', jd: 2451546.0, lat: 51.5, lon: -0.1);
    await service.createChart(chart, configIds: [noVecConfig.id]);

    // No vector should exist (config has no schema).
    final vec = vecStore.getVector(westernSchema.id, 'chart-2', noVecConfig.id);
    expect(vec, isNull);

    // calculateChart should not have been called (config has no schema).
    expect(_callCount, equals(0));
  });

  test('createChart with multiple configs creates vectors for each', () async {
    // Register a second schema and config.
    final vedicSchema = schemaRepo.list().firstWhere((s) => s.name == 'vedic-13');
    final vedicPreset = '{"sweConfig":{"bodies":["sun","moon","mercury",'
        '"venus","mars","jupiter","saturn","uranus","neptune","pluto",'
        '"chiron","rahu","ketu"],"ayanamsa":"lahiri"}}';
    final vedicConfig = configRepo.register(
      'vedic',
      vedicPreset,
      vectorSchemaId: vedicSchema.id,
    );
    vecStore.ensureTable(vedicSchema);

    final chart = _makeChart(id: 'multi-1', jd: 2451547.0, lat: 28.6, lon: 77.2);
    await service.createChart(chart);

    // Vectors should exist for both configs.
    final westernVec =
        vecStore.getVector(westernSchema.id, 'multi-1', westernConfig.id);
    expect(westernVec, isNotNull);
    expect(westernVec!.length, equals(westernSchema.dims));

    final vedicVec =
        vecStore.getVector(vedicSchema.id, 'multi-1', vedicConfig.id);
    expect(vedicVec, isNotNull);
    expect(vedicVec!.length, equals(vedicSchema.dims));

    // calculateChart called once per config.
    expect(_callCount, equals(2));
  });

  test('deleteChart removes chart and all vectors', () async {
    final chart = _makeChart(id: 'del-1', jd: 2451548.0, lat: 35.0, lon: 139.0);
    await service.createChart(chart);

    // Verify chart and vector exist.
    expect(chartRepo.get('del-1'), isNotNull);
    expect(
      vecStore.getVector(westernSchema.id, 'del-1', westernConfig.id),
      isNotNull,
    );

    await service.deleteChart('del-1');

    // Chart should be gone.
    expect(chartRepo.get('del-1'), isNull);

    // Vector should be gone.
    expect(
      vecStore.getVector(westernSchema.id, 'del-1', westernConfig.id),
      isNull,
    );
  });

  test('recomputeVectors replaces vectors with new computation', () async {
    // Create two charts.
    final c1 = _makeChart(id: 'rc-1', jd: 2451549.0, lat: 1.0, lon: 1.0);
    final c2 = _makeChart(id: 'rc-2', jd: 2451550.0, lat: 2.0, lon: 2.0);
    await service.createChart(c1);
    await service.createChart(c2);

    // Record original vectors.
    final origVec1 =
        vecStore.getVector(westernSchema.id, 'rc-1', westernConfig.id)!;
    final origVec2 =
        vecStore.getVector(westernSchema.id, 'rc-2', westernConfig.id)!;

    // Reset call count and recompute.
    _callCount = 0;
    await service.recomputeVectors(westernConfig.id);

    // calculateChart should have been called for each chart.
    expect(_callCount, equals(2));

    // Vectors should still exist (same mock returns same values, but the
    // point is the flow worked without errors).
    final newVec1 =
        vecStore.getVector(westernSchema.id, 'rc-1', westernConfig.id);
    expect(newVec1, isNotNull);
    expect(newVec1!.length, equals(origVec1.length));

    final newVec2 =
        vecStore.getVector(westernSchema.id, 'rc-2', westernConfig.id);
    expect(newVec2, isNotNull);
    expect(newVec2!.length, equals(origVec2.length));
  });

  test('migrateSchema moves vectors to new schema table', () async {
    // Create a chart with the western config.
    final chart = _makeChart(id: 'mig-1', jd: 2451551.0, lat: 10.0, lon: 20.0);
    await service.createChart(chart);

    // Verify vector exists under western schema.
    expect(
      vecStore.getVector(westernSchema.id, 'mig-1', westernConfig.id),
      isNotNull,
    );

    // Register a simpler schema to migrate to.
    final simpleSchema = schemaRepo.register('simple-2', {
      'bodies': ['sun', 'moon'],
      'features': {'longitudes': true},
    });

    // Reset call count and migrate.
    _callCount = 0;
    await service.migrateSchema(westernConfig.id, simpleSchema.id);

    // Old table should have been dropped (no config references it anymore).
    final oldTableName = 'vec_${westernSchema.id.substring(0, 8)}';
    final oldTables = chartDb.db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [oldTableName],
    );
    expect(oldTables, isEmpty);

    // New vector should exist under the new schema.
    final newVec =
        vecStore.getVector(simpleSchema.id, 'mig-1', westernConfig.id);
    expect(newVec, isNotNull);
    expect(newVec!.length, equals(simpleSchema.dims)); // 2 bodies * 2 = 4

    // calculateChart called once (one chart to recompute).
    expect(_callCount, equals(1));

    // Config should now reference the new schema.
    final updatedConfig = configRepo.get(westernConfig.id);
    expect(updatedConfig!.vectorSchemaId, equals(simpleSchema.id));
  });

  test('migrateSchema drops old table when no config references it', () async {
    final chart = _makeChart(id: 'mig-2', jd: 2451552.0, lat: 15.0, lon: 25.0);
    await service.createChart(chart);

    final oldSchemaId = westernSchema.id;
    final oldTableName = 'vec_${oldSchemaId.substring(0, 8)}';

    // Verify old table exists.
    var tables = chartDb.db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [oldTableName],
    );
    expect(tables, hasLength(1));

    // Migrate to a new schema.
    final newSchema = schemaRepo.register('tiny', {
      'bodies': ['sun'],
      'features': {'longitudes': true},
    });

    await service.migrateSchema(westernConfig.id, newSchema.id);

    // Old table should be dropped (no config references western schema now).
    tables = chartDb.db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [oldTableName],
    );
    expect(tables, isEmpty);
  });

  test('deleteChart is safe when no vectors exist', () async {
    // Insert chart directly (bypassing service, so no vectors).
    final chart = _makeChart(id: 'no-vec-1', jd: 2451553.0, lat: 5.0, lon: 5.0);
    chartRepo.insert(chart);

    // Should not throw.
    await service.deleteChart('no-vec-1');
    expect(chartRepo.get('no-vec-1'), isNull);
  });

  test('createChart generates id when chart.id is empty', () async {
    final chart = _makeChart(id: '', jd: 2451554.0, lat: 30.0, lon: 30.0);
    final id = await service.createChart(chart);

    expect(id, isNotEmpty);
    expect(chartRepo.get(id), isNotNull);
  });

  test('recomputeVectors throws on missing config', () async {
    expect(
      () => service.recomputeVectors('nonexistent'),
      throwsA(isA<StateError>()),
    );
  });

  test('recomputeVectors throws on config without schema', () async {
    final noSchemaConfig = configRepo.register(
      'bare',
      '{"sweConfig":{"bodies":["sun"]}}',
    );
    expect(
      () => service.recomputeVectors(noSchemaConfig.id),
      throwsA(isA<StateError>()),
    );
  });
}
