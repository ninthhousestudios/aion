import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// A config binds a name to a serialized ArrowOptions preset and an optional
/// vector schema. The id is the SHA-256 hash of the exact preset JSON string,
/// making registration idempotent.
class Config {
  Config({
    required this.id,
    required this.name,
    required this.preset,
    this.vectorSchemaId,
    required this.createdAt,
  });

  factory Config.fromRow(Row row) {
    return Config(
      id: row['id'] as String,
      name: row['name'] as String,
      preset: row['preset'] as String,
      vectorSchemaId: row['vector_schema_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// SHA-256 hash of the preset JSON string.
  final String id;

  /// Human-readable name (e.g. "tropical-western").
  final String name;

  /// Serialized ArrowOptions JSON, stored verbatim.
  final String preset;

  /// Optional FK to vector_schemas.id.
  final String? vectorSchemaId;

  /// When the config was first registered.
  final DateTime createdAt;
}

/// A [Config] paired with optional schema metadata from a JOIN.
class ConfigWithSchema {
  ConfigWithSchema({required this.config, this.schemaName, this.schemaDims});

  final Config config;

  /// The name of the associated vector schema, if any.
  final String? schemaName;

  /// The dimension count of the associated vector schema, if any.
  final int? schemaDims;
}

// ---------------------------------------------------------------------------
// Hashing
// ---------------------------------------------------------------------------

/// SHA-256 hash of the raw preset JSON string (not canonicalized).
String _presetHash(String presetJson) {
  final bytes = utf8.encode(presetJson);
  return sha256.convert(bytes).toString();
}

// ---------------------------------------------------------------------------
// Body extraction
// ---------------------------------------------------------------------------

/// Extracts the bodies list from a preset JSON string.
///
/// Expects the structure: `{ "sweConfig": { "bodies": ["sun", ...] } }`.
/// Returns an empty set if the path is missing or malformed.
Set<String> extractBodies(String presetJson) {
  try {
    final map = jsonDecode(presetJson) as Map<String, dynamic>;
    final sweConfig = map['sweConfig'] as Map<String, dynamic>?;
    if (sweConfig == null) return {};
    final bodies = sweConfig['bodies'];
    if (bodies is! List) return {};
    return bodies.whereType<String>().toSet();
  } catch (_) {
    return {};
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Manages config registrations in the database.
///
/// Takes a raw sqlite3 [Database] (from [ChartDatabase.db]).
class ConfigRepository {
  ConfigRepository(this._db);

  final Database _db;

  /// Registers a config with [name] and [presetJson].
  ///
  /// The id is the SHA-256 hash of the exact [presetJson] string, making
  /// registration idempotent: if the same preset already exists the existing
  /// row is returned.
  ///
  /// If [vectorSchemaId] is provided, validates that it exists in the
  /// vector_schemas table before inserting.
  ///
  /// Throws [ArgumentError] if [vectorSchemaId] is given but does not exist.
  Config register(String name, String presetJson, {String? vectorSchemaId}) {
    final id = _presetHash(presetJson);

    // Return existing if hash matches.
    final existing = _db.select(
      'SELECT * FROM configs WHERE id = ?;',
      [id],
    );
    if (existing.isNotEmpty) {
      return Config.fromRow(existing.first);
    }

    // Validate schema FK if provided.
    if (vectorSchemaId != null) {
      _validateSchemaExists(vectorSchemaId);
    }

    _db.execute(
      'INSERT INTO configs (id, name, preset, vector_schema_id) '
      'VALUES (?, ?, ?, ?);',
      [id, name, presetJson, vectorSchemaId],
    );

    final rows = _db.select('SELECT * FROM configs WHERE id = ?;', [id]);
    return Config.fromRow(rows.first);
  }

  /// Returns a config by its content-hash [id], or `null` if not found.
  Config? get(String id) {
    final rows = _db.select('SELECT * FROM configs WHERE id = ?;', [id]);
    if (rows.isEmpty) return null;
    return Config.fromRow(rows.first);
  }

  /// Lists all configs, optionally joined with schema info.
  List<ConfigWithSchema> list() {
    final rows = _db.select('''
      SELECT c.*, vs.name AS schema_name, vs.dims AS schema_dims
      FROM configs c
      LEFT JOIN vector_schemas vs ON vs.id = c.vector_schema_id
      ORDER BY c.name;
    ''');
    return rows.map((row) {
      return ConfigWithSchema(
        config: Config.fromRow(row),
        schemaName: row['schema_name'] as String?,
        schemaDims: row['schema_dims'] as int?,
      );
    }).toList();
  }

  /// Updates the vector_schema_id FK on a config.
  ///
  /// Validates that [newSchemaId] exists in vector_schemas and that the
  /// schema's bodies are a subset of the config's preset bodies.
  ///
  /// Returns the old schema id (may be `null`). The caller is responsible
  /// for migrating vectors when the schema changes.
  ///
  /// Throws [StateError] if the config does not exist.
  /// Throws [ArgumentError] if [newSchemaId] does not exist or if the
  /// schema's bodies are not a subset of the config's preset bodies.
  String? updateSchema(String configId, String newSchemaId) {
    // Fetch the config.
    final configRows = _db.select(
      'SELECT * FROM configs WHERE id = ?;',
      [configId],
    );
    if (configRows.isEmpty) {
      throw StateError('Config "$configId" not found');
    }
    final config = Config.fromRow(configRows.first);

    // Validate new schema exists and get its spec.
    _validateSchemaExists(newSchemaId);
    final schemaRows = _db.select(
      'SELECT * FROM vector_schemas WHERE id = ?;',
      [newSchemaId],
    );
    final schemaSpec =
        jsonDecode(schemaRows.first['spec'] as String) as Map<String, dynamic>;

    // Body validation: schema bodies must be subset of config bodies.
    final configBodies = extractBodies(config.preset);
    final schemaBodies =
        (schemaSpec['bodies'] as List).cast<String>().toSet();

    if (!schemaBodies.every((b) => configBodies.contains(b))) {
      final missing = schemaBodies.difference(configBodies);
      throw ArgumentError(
        'Schema bodies $missing are not present in config preset bodies '
        '$configBodies',
      );
    }

    final oldSchemaId = config.vectorSchemaId;

    _db.execute(
      'UPDATE configs SET vector_schema_id = ? WHERE id = ?;',
      [newSchemaId, configId],
    );

    return oldSchemaId;
  }

  /// Deletes a config by [id].
  ///
  /// The caller is responsible for cleaning up any associated vectors first.
  void delete(String id) {
    _db.execute('DELETE FROM configs WHERE id = ?;', [id]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _validateSchemaExists(String schemaId) {
    final rows = _db.select(
      'SELECT id FROM vector_schemas WHERE id = ?;',
      [schemaId],
    );
    if (rows.isEmpty) {
      throw ArgumentError('Vector schema "$schemaId" does not exist');
    }
  }
}
