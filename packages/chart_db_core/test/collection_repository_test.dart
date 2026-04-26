import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Inserts a minimal chart row and returns its id.
String _insertChart(ChartDatabase chartDb, {double jd = 2451545.0, double lat = 51.5, double lon = -0.1}) {
  final id = _uuid.v4();
  chartDb.db.execute(
    "INSERT INTO charts (id, jd, lat, lon, name) VALUES (?, ?, ?, ?, '');",
    [id, jd, lat, lon],
  );
  return id;
}

void main() {
  late ChartDatabase chartDb;
  late CollectionRepository repo;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    repo = CollectionRepository(chartDb.db);
  });

  tearDown(() {
    chartDb.close();
  });

  group('collections', () {
    test('create and list', () {
      final id = repo.create('Natal Charts', note: 'personal nativities');
      expect(id, isNotEmpty);

      final all = repo.list();
      expect(all, hasLength(1));
      expect(all.first.collection.name, equals('Natal Charts'));
      expect(all.first.collection.note, equals('personal nativities'));
      expect(all.first.chartCount, equals(0));
    });

    test('get returns collection', () {
      final id = repo.create('Mundane');
      final col = repo.get(id);
      expect(col, isNotNull);
      expect(col!.name, equals('Mundane'));
    });

    test('get returns null for missing id', () {
      expect(repo.get('nonexistent'), isNull);
    });

    test('add and remove chart', () {
      final colId = repo.create('Test');
      final chartId = _insertChart(chartDb);

      repo.addChart(chartId, colId);
      expect(repo.chartsIn(colId), equals([chartId]));

      repo.removeChart(chartId, colId);
      expect(repo.chartsIn(colId), isEmpty);
    });

    test('chart count reflects membership', () {
      final colId = repo.create('Big Collection');
      final c1 = _insertChart(chartDb, jd: 1.0, lat: 0.0, lon: 0.0);
      final c2 = _insertChart(chartDb, jd: 2.0, lat: 0.0, lon: 0.0);
      final c3 = _insertChart(chartDb, jd: 3.0, lat: 0.0, lon: 0.0);

      repo.addChart(c1, colId);
      repo.addChart(c2, colId);
      repo.addChart(c3, colId);

      final all = repo.list();
      expect(all.first.chartCount, equals(3));
    });

    test('delete collection cascades to chart_collections', () {
      final colId = repo.create('Ephemeral');
      final chartId = _insertChart(chartDb);
      repo.addChart(chartId, colId);

      repo.delete(colId);

      // Collection gone
      expect(repo.get(colId), isNull);

      // Junction row gone
      final rows = chartDb.db.select(
        'SELECT * FROM chart_collections WHERE collection_id = ?;',
        [colId],
      );
      expect(rows, isEmpty);
    });

    test('delete chart cascades to chart_collections', () {
      final colId = repo.create('Persistent');
      final chartId = _insertChart(chartDb);
      repo.addChart(chartId, colId);

      chartDb.db.execute('DELETE FROM charts WHERE id = ?;', [chartId]);

      expect(repo.chartsIn(colId), isEmpty);
      // Collection itself still exists
      expect(repo.get(colId), isNotNull);
    });

    test('addChart is idempotent', () {
      final colId = repo.create('Dupes');
      final chartId = _insertChart(chartDb);

      repo.addChart(chartId, colId);
      repo.addChart(chartId, colId); // no error

      expect(repo.chartsIn(colId), hasLength(1));
    });
  });

  group('tags', () {
    late String chartId;

    setUp(() {
      chartId = _insertChart(chartDb);
    });

    test('add and query tags', () {
      repo.addTag(chartId, 'natal');
      repo.addTag(chartId, 'famous');

      final tags = repo.tagsFor(chartId);
      expect(tags, equals({'famous', 'natal'}));
    });

    test('remove tag', () {
      repo.addTag(chartId, 'natal');
      repo.addTag(chartId, 'famous');
      repo.removeTag(chartId, 'natal');

      expect(repo.tagsFor(chartId), equals({'famous'}));
    });

    test('addTag is idempotent', () {
      repo.addTag(chartId, 'natal');
      repo.addTag(chartId, 'natal'); // no error

      expect(repo.tagsFor(chartId), equals({'natal'}));
    });

    test('chartsWithTag returns all matching charts', () {
      final c1 = chartId;
      final c2 = _insertChart(chartDb, jd: 10.0, lat: 1.0, lon: 1.0);
      final c3 = _insertChart(chartDb, jd: 20.0, lat: 2.0, lon: 2.0);

      repo.addTag(c1, 'mundane');
      repo.addTag(c2, 'mundane');
      repo.addTag(c3, 'natal');

      final mundane = repo.chartsWithTag('mundane');
      expect(mundane, hasLength(2));
      expect(mundane, containsAll([c1, c2]));

      final natal = repo.chartsWithTag('natal');
      expect(natal, equals([c3]));
    });

    test('delete chart cascades to chart_tags', () {
      repo.addTag(chartId, 'doomed');

      chartDb.db.execute('DELETE FROM charts WHERE id = ?;', [chartId]);

      expect(repo.tagsFor(chartId), isEmpty);
      expect(repo.chartsWithTag('doomed'), isEmpty);
    });
  });
}
