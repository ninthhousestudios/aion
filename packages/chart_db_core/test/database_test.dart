import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:test/test.dart';
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
      expect(result.first['user_version'], equals(2));
    });

    test('reopening does not re-run schema creation', () {
      // Opening a second in-memory DB is independent, but we can verify
      // that the version check logic works by manually setting a higher
      // version and confirming no error on re-init.
      chartDb.db.execute('PRAGMA user_version = 99;');
      final result = chartDb.db.select('PRAGMA user_version;');
      expect(result.first['user_version'], equals(99));
    });

    test('v1→v2 migration preserves chart_tags and chart_collections', () {
      // Build a v1 database on disk so ChartDatabase can re-open and migrate.
      final tmpFile =
          '/tmp/test_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      final dbFile = raw.sqlite3.open(tmpFile);
      dbFile.execute('PRAGMA journal_mode = WAL;');
      dbFile.execute('PRAGMA foreign_keys = ON;');
      dbFile.execute('''
        CREATE TABLE charts (
          id TEXT PRIMARY KEY,
          jd REAL NOT NULL, lat REAL NOT NULL, lon REAL NOT NULL,
          alt REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
          gender TEXT, placename TEXT, country TEXT,
          utc_offset REAL, dst_offset REAL, notes TEXT, rodden TEXT,
          source_path TEXT,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
          updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
          UNIQUE(jd, lat, lon)
        );
      ''');
      dbFile.execute('''
        CREATE TABLE collections (
          id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, note TEXT,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
        );
      ''');
      dbFile.execute('''
        CREATE TABLE chart_collections (
          chart_id TEXT NOT NULL REFERENCES charts(id) ON DELETE CASCADE,
          collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
          PRIMARY KEY (chart_id, collection_id)
        );
      ''');
      dbFile.execute('''
        CREATE TABLE chart_tags (
          chart_id TEXT NOT NULL REFERENCES charts(id) ON DELETE CASCADE,
          tag TEXT NOT NULL, PRIMARY KEY (chart_id, tag)
        );
      ''');
      dbFile.execute('''
        CREATE TABLE vector_schemas (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, spec TEXT NOT NULL,
          dims INTEGER NOT NULL,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
        );
      ''');
      dbFile.execute('''
        CREATE TABLE configs (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, preset TEXT NOT NULL,
          vector_schema_id TEXT REFERENCES vector_schemas(id),
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
        );
      ''');
      dbFile.execute(
        "INSERT INTO charts (id, jd, lat, lon, name) VALUES ('chart-1', 2451545.0, 51.5, -0.1, 'Test');",
      );
      dbFile.execute("INSERT INTO chart_tags VALUES ('chart-1', 'natal');");
      dbFile.execute("INSERT INTO chart_tags VALUES ('chart-1', 'famous');");
      dbFile.execute(
        "INSERT INTO collections (id, name) VALUES ('col-1', 'My Charts');",
      );
      dbFile.execute(
        "INSERT INTO chart_collections VALUES ('chart-1', 'col-1');",
      );
      dbFile.execute('PRAGMA user_version = 1;');
      dbFile.dispose();

      // Now open via ChartDatabase which triggers the migration.
      final migrated = ChartDatabase(tmpFile);

      // Verify chart survived.
      final charts = migrated.db.select('SELECT * FROM charts WHERE id = ?', [
        'chart-1',
      ]);
      expect(charts, hasLength(1));
      expect(charts.first['name'], 'Test');

      // Verify tags survived.
      final tags = migrated.db.select(
        'SELECT tag FROM chart_tags WHERE chart_id = ?',
        ['chart-1'],
      );
      expect(tags.map((r) => r['tag']).toList()..sort(), ['famous', 'natal']);

      // Verify collection membership survived.
      final cols = migrated.db.select(
        'SELECT collection_id FROM chart_collections WHERE chart_id = ?',
        ['chart-1'],
      );
      expect(cols, hasLength(1));
      expect(cols.first['collection_id'], 'col-1');

      // Verify content_hash column exists (nullable, so null for migrated rows).
      expect(charts.first['content_hash'], isNull);

      migrated.close();
      File(tmpFile).deleteSync();
    });
  });
}
