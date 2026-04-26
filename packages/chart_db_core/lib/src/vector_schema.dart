import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Valid body names matching the Body enum in arjuna.
const Set<String> validBodyNames = {
  'sun',
  'moon',
  'mercury',
  'venus',
  'mars',
  'jupiter',
  'saturn',
  'uranus',
  'neptune',
  'pluto',
  'chiron',
  'rahu',
  'ketu',
};

/// Valid swe_aux field names.
const Set<String> validSweAux = {
  'armc',
  'vertex',
  'equasc',
  'co_asc_koch',
  'co_asc_munkasey',
  'polar_asc',
};

/// Known feature keys in a vector schema spec.
const Set<String> _knownFeatureKeys = {
  'longitudes',
  'house_cusps',
  'swe_aux',
  'house_placements',
  'nakshatras',
  'retrogrades',
};

/// The default western-13 spec.
const Map<String, dynamic> westernSpec = {
  'bodies': [
    'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
    'uranus', 'neptune', 'pluto', 'chiron', 'rahu', 'ketu',
  ],
  'features': {
    'longitudes': true,
    'house_cusps': true,
    'swe_aux': [
      'armc', 'vertex', 'equasc', 'co_asc_koch', 'co_asc_munkasey',
      'polar_asc',
    ],
    'house_placements': true,
    'nakshatras': false,
    'retrogrades': true,
  },
};

/// The default vedic-13 spec.
const Map<String, dynamic> vedicSpec = {
  'bodies': [
    'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
    'uranus', 'neptune', 'pluto', 'chiron', 'rahu', 'ketu',
  ],
  'features': {
    'longitudes': true,
    'house_cusps': true,
    'swe_aux': [
      'armc', 'vertex', 'equasc', 'co_asc_koch', 'co_asc_munkasey',
      'polar_asc',
    ],
    'house_placements': true,
    'nakshatras': true,
    'retrogrades': true,
  },
};

/// A vector schema defines how chart data is encoded into a fixed-length
/// numeric vector for similarity search.
class VectorSchema {
  VectorSchema({
    required this.id,
    required this.name,
    required this.spec,
    required this.dims,
    required this.createdAt,
  });

  factory VectorSchema.fromRow(Row row) {
    return VectorSchema(
      id: row['id'] as String,
      name: row['name'] as String,
      spec: jsonDecode(row['spec'] as String) as Map<String, dynamic>,
      dims: row['dims'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Content-hash id (sha256 of canonical spec JSON).
  final String id;

  /// Human-readable name (e.g. "western-13").
  final String name;

  /// The parsed JSON spec defining bodies and features.
  final Map<String, dynamic> spec;

  /// Total number of dimensions in the encoded vector.
  final int dims;

  /// When the schema was first registered.
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Canonical JSON helpers
// ---------------------------------------------------------------------------

/// Recursively sorts map keys for deterministic JSON output.
dynamic _sortKeys(dynamic value) {
  if (value is Map<String, dynamic>) {
    final sorted = Map<String, dynamic>.fromEntries(
      value.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted.map((k, v) => MapEntry(k, _sortKeys(v)));
  }
  if (value is List) {
    return value.map(_sortKeys).toList();
  }
  return value;
}

/// Returns the canonical JSON string for a spec (sorted keys, no extra
/// whitespace). Two specs that are semantically identical always produce
/// the same string.
String canonicalJson(Map<String, dynamic> spec) {
  return jsonEncode(_sortKeys(spec));
}

/// SHA-256 hash of the canonical JSON, returned as a hex string.
String specHash(Map<String, dynamic> spec) {
  final bytes = utf8.encode(canonicalJson(spec));
  return sha256.convert(bytes).toString();
}

// ---------------------------------------------------------------------------
// Dimension computation
// ---------------------------------------------------------------------------

/// Deterministically computes the total vector dimensions from a spec.
///
/// Layout:
/// - longitudes: bodies × 2 (sin/cos)
/// - house_cusps: 12 × 2 (sin/cos)
/// - swe_aux: count × 2 (sin/cos)
/// - house_placements: bodies × 2 (sin/cos)
/// - nakshatras: bodies × 2 (sin/cos) — only if enabled
/// - retrogrades: bodies × 1 (boolean 0.0/1.0) — only if enabled
int computeDims(Map<String, dynamic> spec) {
  final bodies = (spec['bodies'] as List).length;
  final features = spec['features'] as Map<String, dynamic>;

  var dims = 0;

  if (features['longitudes'] == true) {
    dims += bodies * 2;
  }

  if (features['house_cusps'] == true) {
    dims += 12 * 2; // always 12 cusps
  }

  final sweAux = features['swe_aux'];
  if (sweAux is List && sweAux.isNotEmpty) {
    dims += sweAux.length * 2;
  }

  if (features['house_placements'] == true) {
    dims += bodies * 2;
  }

  if (features['nakshatras'] == true) {
    dims += bodies * 2;
  }

  if (features['retrogrades'] == true) {
    dims += bodies * 1;
  }

  return dims;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Validates a vector schema spec.
///
/// Returns `null` if valid, or a description of the first problem found.
String? validateSpec(Map<String, dynamic> spec) {
  // -- bodies --
  final bodies = spec['bodies'];
  if (bodies == null) return 'spec missing "bodies"';
  if (bodies is! List || bodies.isEmpty) {
    return '"bodies" must be a non-empty list';
  }
  for (final b in bodies) {
    if (b is! String) return 'body name must be a string, got: $b';
    if (!validBodyNames.contains(b)) return 'unrecognized body: "$b"';
  }

  // -- features --
  final features = spec['features'];
  if (features == null) return 'spec missing "features"';
  if (features is! Map<String, dynamic>) {
    return '"features" must be a map';
  }

  for (final key in features.keys) {
    if (!_knownFeatureKeys.contains(key)) {
      return 'unknown feature key: "$key"';
    }
  }

  // -- swe_aux validation --
  final sweAux = features['swe_aux'];
  if (sweAux != null) {
    if (sweAux is! List) return '"swe_aux" must be a list';
    for (final v in sweAux) {
      if (v is! String) return 'swe_aux entry must be a string, got: $v';
      if (!validSweAux.contains(v)) return 'unrecognized swe_aux: "$v"';
    }
  }

  return null; // valid
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Manages vector schema registrations in the database.
///
/// Takes a raw sqlite3 [Database] (from [ChartDatabase.db]).
class VectorSchemaRepository {
  VectorSchemaRepository(this._db);

  final Database _db;

  /// Registers a vector schema spec under [name].
  ///
  /// The id is the SHA-256 hash of the canonical JSON, making registration
  /// idempotent: if the same spec already exists the existing row is returned.
  ///
  /// Throws [ArgumentError] if the spec fails validation.
  VectorSchema register(String name, Map<String, dynamic> spec) {
    final error = validateSpec(spec);
    if (error != null) {
      throw ArgumentError('Invalid vector schema spec: $error');
    }

    final id = specHash(spec);
    final dims = computeDims(spec);
    final canonical = canonicalJson(spec);

    // Check if this hash already exists.
    final existing = _db.select(
      'SELECT * FROM vector_schemas WHERE id = ?;',
      [id],
    );
    if (existing.isNotEmpty) {
      return VectorSchema.fromRow(existing.first);
    }

    _db.execute(
      'INSERT INTO vector_schemas (id, name, spec, dims) VALUES (?, ?, ?, ?);',
      [id, name, canonical, dims],
    );

    final rows = _db.select(
      'SELECT * FROM vector_schemas WHERE id = ?;',
      [id],
    );
    return VectorSchema.fromRow(rows.first);
  }

  /// Returns a schema by its content-hash [id], or `null` if not found.
  VectorSchema? get(String id) {
    final rows = _db.select(
      'SELECT * FROM vector_schemas WHERE id = ?;',
      [id],
    );
    if (rows.isEmpty) return null;
    return VectorSchema.fromRow(rows.first);
  }

  /// Lists all registered schemas.
  List<VectorSchema> list() {
    final rows = _db.select(
      'SELECT * FROM vector_schemas ORDER BY name;',
    );
    return rows.map(VectorSchema.fromRow).toList();
  }

  /// Deletes a schema by [id].
  ///
  /// Throws [StateError] if any config references this schema.
  void delete(String id) {
    final refs = _db.select(
      'SELECT COUNT(*) AS cnt FROM configs WHERE vector_schema_id = ?;',
      [id],
    );
    final count = refs.first['cnt'] as int;
    if (count > 0) {
      throw StateError(
        'Cannot delete vector schema "$id": $count config(s) reference it',
      );
    }
    _db.execute('DELETE FROM vector_schemas WHERE id = ?;', [id]);
  }

  /// Creates the western-13 and vedic-13 default schemas if they don't
  /// already exist.
  void ensureDefaults() {
    register('western-13', westernSpec);
    register('vedic-13', vedicSpec);
  }
}
