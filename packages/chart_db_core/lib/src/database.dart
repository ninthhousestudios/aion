import 'package:sqlite3/sqlite3.dart';

/// Current schema version. Bump when migrating.
const int _schemaVersion = 1;

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

    _db.execute('BEGIN;');
    try {
      _createTables();
      _createFts();
      _createFtsTriggers();
      _db.execute('PRAGMA user_version = $_schemaVersion;');
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
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
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        UNIQUE(jd, lat, lon)
      );
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
