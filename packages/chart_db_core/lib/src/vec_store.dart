import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'vector_schema.dart';

/// Result of a KNN vector search.
class VecResult {
  VecResult({required this.chartId, required this.distance});

  /// The chart that matched.
  final String chartId;

  /// Distance from the query vector (0.0 = identical, 1.0 = orthogonal).
  final double distance;
}

/// Vector storage and KNN search backed by SQLite.
///
/// Uses the sqlite-vec (vec0) extension when available for hardware-
/// accelerated similarity search. Falls back to blob storage with Dart-side
/// cosine similarity when the extension is not loaded.
class VecStore {
  VecStore(this._db) {
    _detectVecExtension();
  }

  final Database _db;

  /// Whether the native vec0 extension is available.
  bool get useNativeVec => _useNativeVec;
  bool _useNativeVec = false;

  void _detectVecExtension() {
    try {
      _db.select('SELECT vec_version()');
      _useNativeVec = true;
    } catch (_) {
      _useNativeVec = false;
    }
  }

  /// Returns the table name for a given schema id.
  String _tableName(String schemaId) => 'vec_${schemaId.substring(0, 8)}';

  /// Creates the vector table for [schema] if it does not already exist.
  void ensureTable(VectorSchema schema) {
    final table = _tableName(schema.id);
    if (_useNativeVec) {
      _db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS $table '
        'USING vec0(chart_id text, config_id text, '
        'vector float[${schema.dims}])',
      );
    } else {
      _db.execute(
        'CREATE TABLE IF NOT EXISTS $table ('
        'chart_id TEXT NOT NULL, '
        'config_id TEXT NOT NULL, '
        'vector BLOB NOT NULL, '
        'PRIMARY KEY (chart_id, config_id))',
      );
    }
  }

  /// Inserts (or replaces) a vector for a chart+config pair.
  void insertVector(
    String schemaId,
    String chartId,
    String configId,
    Float64List vector,
  ) {
    final table = _tableName(schemaId);
    if (_useNativeVec) {
      _db.execute(
        'INSERT INTO $table (chart_id, config_id, vector) '
        'VALUES (?, ?, ?)',
        [chartId, configId, vector.buffer.asUint8List()],
      );
    } else {
      _db.execute(
        'INSERT OR REPLACE INTO $table (chart_id, config_id, vector) '
        'VALUES (?, ?, ?)',
        [chartId, configId, vector.buffer.asUint8List()],
      );
    }
  }

  /// Retrieves the stored vector for a specific chart+config pair.
  ///
  /// Returns `null` if no vector is found.
  Float64List? getVector(String schemaId, String chartId, String configId) {
    final table = _tableName(schemaId);
    final rows = _db.select(
      'SELECT vector FROM $table WHERE chart_id = ? AND config_id = ?',
      [chartId, configId],
    );
    if (rows.isEmpty) return null;
    final blob = rows.first['vector'] as Uint8List;
    return Float64List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float64List.bytesPerElement,
    );
  }

  /// Deletes vectors matching the given filters.
  ///
  /// At least one of [configId] or [chartId] must be provided.
  void deleteVectors({
    required String schemaId,
    String? configId,
    String? chartId,
  }) {
    assert(
      configId != null || chartId != null,
      'At least one of configId or chartId must be provided',
    );

    final table = _tableName(schemaId);
    final clauses = <String>[];
    final params = <Object>[];

    if (chartId != null) {
      clauses.add('chart_id = ?');
      params.add(chartId);
    }
    if (configId != null) {
      clauses.add('config_id = ?');
      params.add(configId);
    }

    _db.execute(
      'DELETE FROM $table WHERE ${clauses.join(' AND ')}',
      params,
    );
  }

  /// Returns the [k] nearest neighbors for [query] within the given config.
  List<VecResult> knn(
    String schemaId,
    String configId,
    Float64List query,
    int k,
  ) {
    final table = _tableName(schemaId);

    if (_useNativeVec) {
      final rows = _db.select(
        'SELECT chart_id, distance FROM $table '
        'WHERE config_id = ? AND vector MATCH ? AND k = ? '
        'ORDER BY distance',
        [configId, query.buffer.asUint8List(), k],
      );
      return rows
          .map(
            (row) => VecResult(
              chartId: row['chart_id'] as String,
              distance: (row['distance'] as num).toDouble(),
            ),
          )
          .toList();
    }

    // Blob fallback: load all vectors for config, compute cosine similarity.
    final rows = _db.select(
      'SELECT chart_id, vector FROM $table WHERE config_id = ?',
      [configId],
    );

    final scored = <VecResult>[];
    for (final row in rows) {
      final blob = row['vector'] as Uint8List;
      final stored = Float64List.view(blob.buffer, blob.offsetInBytes,
          blob.lengthInBytes ~/ Float64List.bytesPerElement);
      final similarity = _cosineSimilarity(query, stored);
      scored.add(VecResult(
        chartId: row['chart_id'] as String,
        distance: 1.0 - similarity,
      ));
    }

    scored.sort((a, b) => a.distance.compareTo(b.distance));
    return scored.take(k).toList();
  }

  /// Drops the vector table for [schemaId] if it exists.
  void dropTable(String schemaId) {
    final table = _tableName(schemaId);
    _db.execute('DROP TABLE IF EXISTS $table');
  }

  /// Cosine similarity between two vectors. Returns 0.0 for zero-norm inputs.
  double _cosineSimilarity(Float64List a, Float64List b) {
    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0.0;
    return dotProduct / denom;
  }
}
