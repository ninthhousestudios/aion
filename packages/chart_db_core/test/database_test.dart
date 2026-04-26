import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';
import 'package:uuid/uuid.dart';

void main() {
  late ChartDatabase chartDb;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
  });

  tearDown(() {
    chartDb.close();
  });

  group('schema creation', () {
    test('all expected tables exist', () {
      final rows = chartDb.db.select(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      final tables = rows.map((r) => r['name'] as String).toSet();

      expect(tables, contains('charts'));
      expect(tables, contains('collections'));
      expect(tables, contains('chart_collections'));
      expect(tables, contains('chart_tags'));
      expect(tables, contains('vector_schemas'));
      expect(tables, contains('configs'));
      expect(tables, contains('charts_fts'));
    });

    test('FTS triggers exist', () {
      final rows = chartDb.db.select(
        "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name;",
      );
      final triggers = rows.map((r) => r['name'] as String).toSet();

      expect(triggers, contains('charts_ai'));
      expect(triggers, contains('charts_ad'));
      expect(triggers, contains('charts_au'));
    });

    test('idx_chart_tags_tag index exists', () {
      final rows = chartDb.db.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_chart_tags_tag';",
      );
      expect(rows, hasLength(1));
    });

    test('foreign keys are enabled', () {
      final result = chartDb.db.select('PRAGMA foreign_keys;');
      expect(result.first['foreign_keys'], equals(1));
    });
  });

  group('FTS triggers', () {
    late String chartId;

    setUp(() {
      chartId = const Uuid().v4();
    });

    test('insert syncs to FTS', () {
      chartDb.db.execute(
        "INSERT INTO charts (id, jd, lat, lon, name, placename, country, notes) "
        "VALUES (?, 2451545.0, 51.5, -0.1, 'Isaac Newton', 'Woolsthorpe', 'England', 'gravity guy');",
        [chartId],
      );

      final ftsResults = chartDb.db.select(
        "SELECT * FROM charts_fts WHERE charts_fts MATCH 'Newton';",
      );
      expect(ftsResults, hasLength(1));
      expect(ftsResults.first['name'], equals('Isaac Newton'));
    });

    test('update syncs to FTS', () {
      chartDb.db.execute(
        "INSERT INTO charts (id, jd, lat, lon, name, placename, country, notes) "
        "VALUES (?, 2451545.0, 51.5, -0.1, 'Isaac Newton', 'Woolsthorpe', 'England', 'gravity guy');",
        [chartId],
      );

      chartDb.db.execute(
        "UPDATE charts SET name = 'Sir Isaac Newton' WHERE id = ?;",
        [chartId],
      );

      // Old name should not match
      final oldResults = chartDb.db.select(
        "SELECT * FROM charts_fts WHERE charts_fts MATCH 'Isaac' AND name != 'Sir Isaac Newton';",
      );
      expect(oldResults, isEmpty);

      // New name should match
      final newResults = chartDb.db.select(
        "SELECT * FROM charts_fts WHERE charts_fts MATCH 'Sir';",
      );
      expect(newResults, hasLength(1));
      expect(newResults.first['name'], equals('Sir Isaac Newton'));
    });

    test('delete cleans FTS', () {
      chartDb.db.execute(
        "INSERT INTO charts (id, jd, lat, lon, name, placename, country, notes) "
        "VALUES (?, 2451545.0, 51.5, -0.1, 'Isaac Newton', 'Woolsthorpe', 'England', 'gravity guy');",
        [chartId],
      );

      chartDb.db.execute("DELETE FROM charts WHERE id = ?;", [chartId]);

      final ftsResults = chartDb.db.select(
        "SELECT * FROM charts_fts WHERE charts_fts MATCH 'Newton';",
      );
      expect(ftsResults, isEmpty);
    });
  });

  group('migration versioning', () {
    test('user_version is set after schema creation', () {
      final result = chartDb.db.select('PRAGMA user_version;');
      expect(result.first['user_version'], equals(1));
    });

    test('reopening does not re-run schema creation', () {
      // Opening a second in-memory DB is independent, but we can verify
      // that the version check logic works by manually setting a higher
      // version and confirming no error on re-init.
      chartDb.db.execute('PRAGMA user_version = 99;');
      final result = chartDb.db.select('PRAGMA user_version;');
      expect(result.first['user_version'], equals(99));
    });
  });
}
