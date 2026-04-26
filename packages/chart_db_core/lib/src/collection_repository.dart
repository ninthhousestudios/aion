import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A named collection of charts.
class Collection {
  Collection({
    required this.id,
    required this.name,
    this.note,
    required this.createdAt,
  });

  factory Collection.fromRow(Row row) {
    return Collection(
      id: row['id'] as String,
      name: row['name'] as String,
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String name;
  final String? note;
  final DateTime createdAt;
}

/// A [Collection] paired with the number of charts it contains.
class CollectionWithCount {
  CollectionWithCount({required this.collection, required this.chartCount});

  final Collection collection;
  final int chartCount;
}

/// Manages collections, chart-collection membership, and chart tags.
///
/// All operations are synchronous (sqlite3 is synchronous). Pass the
/// underlying [Database] from [ChartDatabase.db].
class CollectionRepository {
  CollectionRepository(this._db);

  final Database _db;

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  /// Creates a new collection and returns its id.
  String create(String name, {String? note}) {
    final id = _uuid.v4();
    _db.execute(
      'INSERT INTO collections (id, name, note) VALUES (?, ?, ?);',
      [id, name, note],
    );
    return id;
  }

  /// Returns a single collection by [id], or `null` if not found.
  Collection? get(String id) {
    final rows = _db.select(
      'SELECT * FROM collections WHERE id = ?;',
      [id],
    );
    if (rows.isEmpty) return null;
    return Collection.fromRow(rows.first);
  }

  /// Lists all collections with their chart counts.
  List<CollectionWithCount> list() {
    final rows = _db.select('''
      SELECT c.*, COUNT(cc.chart_id) AS chart_count
      FROM collections c
      LEFT JOIN chart_collections cc ON cc.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.name;
    ''');
    return rows.map((row) {
      return CollectionWithCount(
        collection: Collection.fromRow(row),
        chartCount: row['chart_count'] as int,
      );
    }).toList();
  }

  /// Adds a chart to a collection.
  void addChart(String chartId, String collectionId) {
    _db.execute(
      'INSERT OR IGNORE INTO chart_collections (chart_id, collection_id) VALUES (?, ?);',
      [chartId, collectionId],
    );
  }

  /// Removes a chart from a collection.
  void removeChart(String chartId, String collectionId) {
    _db.execute(
      'DELETE FROM chart_collections WHERE chart_id = ? AND collection_id = ?;',
      [chartId, collectionId],
    );
  }

  /// Returns the ids of all charts in [collectionId].
  List<String> chartsIn(String collectionId) {
    final rows = _db.select(
      'SELECT chart_id FROM chart_collections WHERE collection_id = ? ORDER BY chart_id;',
      [collectionId],
    );
    return rows.map((r) => r['chart_id'] as String).toList();
  }

  /// Deletes a collection. Cascade FK removes chart_collections entries.
  void delete(String collectionId) {
    _db.execute('DELETE FROM collections WHERE id = ?;', [collectionId]);
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  /// Adds a tag to a chart. No-op if the tag already exists.
  void addTag(String chartId, String tag) {
    _db.execute(
      'INSERT OR IGNORE INTO chart_tags (chart_id, tag) VALUES (?, ?);',
      [chartId, tag],
    );
  }

  /// Removes a tag from a chart.
  void removeTag(String chartId, String tag) {
    _db.execute(
      'DELETE FROM chart_tags WHERE chart_id = ? AND tag = ?;',
      [chartId, tag],
    );
  }

  /// Returns all tags for a chart.
  Set<String> tagsFor(String chartId) {
    final rows = _db.select(
      'SELECT tag FROM chart_tags WHERE chart_id = ? ORDER BY tag;',
      [chartId],
    );
    return rows.map((r) => r['tag'] as String).toSet();
  }

  /// Returns the ids of all charts that have [tag].
  List<String> chartsWithTag(String tag) {
    final rows = _db.select(
      'SELECT chart_id FROM chart_tags WHERE tag = ? ORDER BY chart_id;',
      [tag],
    );
    return rows.map((r) => r['chart_id'] as String).toList();
  }
}
