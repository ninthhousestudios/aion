import 'package:sqlite3/sqlite3.dart';

/// Current schema version. Bump when migrating.
const int _schemaVersion = 2;

/// Wraps a raw sqlite3 [Database] with chart-db schema management.
///
/// Opens (or creates) a SQLite database at [path] and ensures the
/// chart-db schema is present. Defaults to `:memory:` for tests;
/// callers provide the real path (e.g. `~/.config/aion/charts.db`).
class ChartDatabase {
  ChartDatabase([String? path]) : _db = sqlite3.open(path ?? ':memory:') {
    _configurePragmas();
    _ensureSchema();
  }

  final Database _db;

  /// The underlying sqlite3 database, exposed for direct queries.
  Database get db => _db;

  /// Close the database connection.
  void close() => _db.dispose();

  // ---------------------------------------------------------------------------
  // Pragmas
  // ---------------------------------------------------------------------------

  void _configurePragmas() {
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute('PRAGMA foreign_keys = ON;');
  }

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  void _ensureSchema() {
    final currentVersion =
        _db.select('PRAGMA user_version;').first['user_version'] as int;

    if (currentVersion >= _schemaVersion) return;

    // Migrations that rebuild tables must disable FK checks to avoid
    // cascade-deleting child rows. PRAGMA foreign_keys can only be changed
    // outside a transaction.
    final isMigration = currentVersion > 0;
    if (isMigration) {
      _db.execute('PRAGMA foreign_keys = OFF;');
    }

    _db.execute('BEGIN;');
    try {
      if (currentVersion == 0) {
        _createTables();
        _createFts();
        _createFtsTriggers();
      } else {
        if (currentVersion < 2) _migrateV1ToV2();
      }
      _db.execute('PRAGMA user_version = $_schemaVersion;');
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    if (isMigration) {
      _db.execute('PRAGMA foreign_keys = ON;');
      final fkCheck = _db.select('PRAGMA foreign_key_check;');
      if (fkCheck.isNotEmpty) {
        throw StateError(
          'Foreign key violations after migration: ${fkCheck.length} rows',
        );
      }
    }
  }

  void _migrateV1ToV2() {
    // Strategy: create new table, copy data, drop old, rename new.
    // Child tables (chart_tags, chart_collections) reference "charts" by name.
    // With FK OFF, their definitions stay pointing at "charts" throughout.
    // After rename, "charts" exists again with the correct IDs.
    _db.execute('DROP TRIGGER IF EXISTS charts_ai;');
    _db.execute('DROP TRIGGER IF EXISTS charts_ad;');
    _db.execute('DROP TRIGGER IF EXISTS charts_au;');
    _db.execute('DROP TABLE IF EXISTS charts_fts;');

    _db.execute('''
      CREATE TABLE charts_new (
        id TEXT PRIMARY KEY,
        jd REAL NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        alt REAL NOT NULL DEFAULT 0,
        name TEXT NOT NULL DEFAULT '',
        gender TEXT,
        placename TEXT,
        country TEXT,
        utc_offset REAL,
        dst_offset REAL,
        notes TEXT,
        rodden TEXT,
        source_path TEXT,
        content_hash TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      );
    ''');

    _db.execute('''
      INSERT INTO charts_new (id, jd, lat, lon, alt, name, gender, placename,
        country, utc_offset, dst_offset, notes, rodden, source_path,
        created_at, updated_at)
      SELECT id, jd, lat, lon, alt, name, gender, placename,
        country, utc_offset, dst_offset, notes, rodden, source_path,
        created_at, updated_at
      FROM charts;
    ''');

    _db.execute('DROP TABLE charts;');
    _db.execute('ALTER TABLE charts_new RENAME TO charts;');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_charts_jd_lat_lon
      ON charts(jd, lat, lon);
    ''');
    _db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_charts_source_path
      ON charts(source_path) WHERE source_path IS NOT NULL;
    ''');

    _createFts();
    _createFtsTriggers();
    _db.execute("INSERT INTO charts_fts(charts_fts) VALUES('rebuild');");
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS charts (
        id TEXT PRIMARY KEY,
        jd REAL NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        alt REAL NOT NULL DEFAULT 0,
        name TEXT NOT NULL DEFAULT '',
        gender TEXT,
        placename TEXT,
        country TEXT,
        utc_offset REAL,
        dst_offset REAL,
        notes TEXT,
        rodden TEXT,
        source_path TEXT,
        content_hash TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      );
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_charts_jd_lat_lon
      ON charts(jd, lat, lon);
    ''');

    _db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_charts_source_path
      ON charts(source_path) WHERE source_path IS NOT NULL;
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS chart_collections (
        chart_id TEXT NOT NULL REFERENCES charts(id) ON DELETE CASCADE,
        collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
        PRIMARY KEY (chart_id, collection_id)
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS chart_tags (
        chart_id TEXT NOT NULL REFERENCES charts(id) ON DELETE CASCADE,
        tag TEXT NOT NULL,
        PRIMARY KEY (chart_id, tag)
      );
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chart_tags_tag ON chart_tags(tag);
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS vector_schemas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        spec TEXT NOT NULL,
        dims INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        preset TEXT NOT NULL,
        vector_schema_id TEXT REFERENCES vector_schemas(id),
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      );
    ''');
  }

  void _createFts() {
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS charts_fts USING fts5(
        name, placename, country, notes,
        content='charts',
        content_rowid='rowid'
      );
    ''');
  }

  void _createFtsTriggers() {
    _db.execute('''
      CREATE TRIGGER IF NOT EXISTS charts_ai AFTER INSERT ON charts BEGIN
        INSERT INTO charts_fts(rowid, name, placename, country, notes)
        VALUES (new.rowid, new.name, new.placename, new.country, new.notes);
      END;
    ''');

    _db.execute('''
      CREATE TRIGGER IF NOT EXISTS charts_ad AFTER DELETE ON charts BEGIN
        INSERT INTO charts_fts(charts_fts, rowid, name, placename, country, notes)
        VALUES ('delete', old.rowid, old.name, old.placename, old.country, old.notes);
      END;
    ''');

    _db.execute('''
      CREATE TRIGGER IF NOT EXISTS charts_au AFTER UPDATE ON charts BEGIN
        INSERT INTO charts_fts(charts_fts, rowid, name, placename, country, notes)
        VALUES ('delete', old.rowid, old.name, old.placename, old.country, old.notes);
        INSERT INTO charts_fts(rowid, name, placename, country, notes)
        VALUES (new.rowid, new.name, new.placename, new.country, new.notes);
      END;
    ''');
  }
}
