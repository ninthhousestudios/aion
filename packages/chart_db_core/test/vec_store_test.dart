import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

void main() {
  late ChartDatabase chartDb;
  late VectorSchemaRepository schemaRepo;
  late VecStore vecStore;
  late VectorSchema schema;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    schemaRepo = VectorSchemaRepository(chartDb.db);
    vecStore = VecStore(chartDb.db);

    // Register a simple 4-dim schema for testing.
    schema = schemaRepo.register('test-4', {
      'bodies': ['sun', 'moon'],
      'features': {'longitudes': true},
    });
    // dims = 2 bodies × 2 (sin/cos) = 4

    vecStore.ensureTable(schema);
  });

  tearDown(() {
    chartDb.close();
  });

  test('blob fallback is used (no vec0 extension)', () {
    expect(vecStore.useNativeVec, isFalse);
  });

  test('table created with correct name', () {
    final prefix = schema.id.substring(0, 8);
    final rows = chartDb.db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      ['vec_$prefix'],
    );
    expect(rows, hasLength(1));
  });

  test('insert and KNN query returns nearest', () {
    final v1 = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    final v2 = Float64List.fromList([0.0, 1.0, 0.0, 0.0]);
    final v3 = Float64List.fromList([0.9, 0.1, 0.0, 0.0]);

    vecStore.insertVector(schema.id, 'chart-a', 'cfg-1', v1);
    vecStore.insertVector(schema.id, 'chart-b', 'cfg-1', v2);
    vecStore.insertVector(schema.id, 'chart-c', 'cfg-1', v3);

    // Query with v1 — chart-a should be closest (identical), chart-c next.
    final results = vecStore.knn(
      schema.id,
      'cfg-1',
      Float64List.fromList([1.0, 0.0, 0.0, 0.0]),
      3,
    );

    expect(results, hasLength(3));
    expect(results[0].chartId, equals('chart-a'));
    expect(results[0].distance, closeTo(0.0, 1e-10));
    expect(results[1].chartId, equals('chart-c'));
  });

  test('delete by chart removes only that chart', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'chart-a', 'cfg-1', v);
    vecStore.insertVector(schema.id, 'chart-b', 'cfg-1', v);

    vecStore.deleteVectors(schemaId: schema.id, chartId: 'chart-a');

    final results = vecStore.knn(
      schema.id,
      'cfg-1',
      v,
      10,
    );
    expect(results, hasLength(1));
    expect(results[0].chartId, equals('chart-b'));
  });

  test('delete by config removes only that config', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'chart-a', 'cfg-1', v);
    vecStore.insertVector(schema.id, 'chart-a', 'cfg-2', v);

    vecStore.deleteVectors(schemaId: schema.id, configId: 'cfg-1');

    // cfg-2 should still exist.
    final rows = chartDb.db.select(
      'SELECT * FROM vec_${schema.id.substring(0, 8)} WHERE config_id = ?',
      ['cfg-2'],
    );
    expect(rows, hasLength(1));

    // cfg-1 should be gone.
    final gone = chartDb.db.select(
      'SELECT * FROM vec_${schema.id.substring(0, 8)} WHERE config_id = ?',
      ['cfg-1'],
    );
    expect(gone, isEmpty);
  });

  test('delete by chart AND config', () {
    final v = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    vecStore.insertVector(schema.id, 'chart-a', 'cfg-1', v);
    vecStore.insertVector(schema.id, 'chart-a', 'cfg-2', v);
    vecStore.insertVector(schema.id, 'chart-b', 'cfg-1', v);

    vecStore.deleteVectors(
      schemaId: schema.id,
      chartId: 'chart-a',
      configId: 'cfg-1',
    );

    final table = 'vec_${schema.id.substring(0, 8)}';
    final remaining = chartDb.db.select('SELECT * FROM $table');
    expect(remaining, hasLength(2));

    final ids = remaining.map((r) =>
        '${r['chart_id']}:${r['config_id']}').toSet();
    expect(ids, containsAll(['chart-a:cfg-2', 'chart-b:cfg-1']));
  });

  test('blob fallback cosine similarity returns correct rankings', () {
    // v1 and v2 are identical → distance 0
    // v3 is orthogonal to v1 → distance 1
    // v4 is partially similar → distance between 0 and 1
    final v1 = Float64List.fromList([1.0, 0.0, 0.0, 0.0]);
    final v2 = Float64List.fromList([1.0, 0.0, 0.0, 0.0]); // identical
    final v3 = Float64List.fromList([0.0, 1.0, 0.0, 0.0]); // orthogonal
    final v4 = Float64List.fromList([0.7, 0.7, 0.0, 0.0]); // partial

    vecStore.insertVector(schema.id, 'identical', 'cfg-1', v2);
    vecStore.insertVector(schema.id, 'orthogonal', 'cfg-1', v3);
    vecStore.insertVector(schema.id, 'partial', 'cfg-1', v4);

    final results = vecStore.knn(schema.id, 'cfg-1', v1, 3);

    expect(results, hasLength(3));
    // Identical vector first (distance ≈ 0).
    expect(results[0].chartId, equals('identical'));
    expect(results[0].distance, closeTo(0.0, 1e-10));

    // Partial similarity second.
    expect(results[1].chartId, equals('partial'));
    expect(results[1].distance, greaterThan(0.0));
    expect(results[1].distance, lessThan(1.0));

    // Orthogonal last (distance ≈ 1).
    expect(results[2].chartId, equals('orthogonal'));
    expect(results[2].distance, closeTo(1.0, 1e-10));
  });

  test('drop table removes the table', () {
    vecStore.dropTable(schema.id);

    final prefix = schema.id.substring(0, 8);
    final rows = chartDb.db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      ['vec_$prefix'],
    );
    expect(rows, isEmpty);
  });

  test('KNN respects k limit', () {
    for (var i = 0; i < 5; i++) {
      final v = Float64List.fromList([
        (i + 1).toDouble(),
        0.0,
        0.0,
        0.0,
      ]);
      vecStore.insertVector(schema.id, 'chart-$i', 'cfg-1', v);
    }

    final results = vecStore.knn(
      schema.id,
      'cfg-1',
      Float64List.fromList([1.0, 0.0, 0.0, 0.0]),
      2,
    );
    expect(results, hasLength(2));
  });
}
