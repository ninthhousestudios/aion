import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Simple data class mirroring the `charts` table.
class Chart {
  Chart({
    required this.id,
    required this.jd,
    required this.lat,
    required this.lon,
    this.alt = 0,
    this.name = '',
    this.gender,
    this.placename,
    this.country,
    this.utcOffset,
    this.dstOffset,
    this.notes,
    this.rodden,
    this.sourcePath,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chart.fromRow(Row row) {
    return Chart(
      id: row['id'] as String,
      jd: (row['jd'] as num).toDouble(),
      lat: (row['lat'] as num).toDouble(),
      lon: (row['lon'] as num).toDouble(),
      alt: (row['alt'] as num).toDouble(),
      name: row['name'] as String,
      gender: row['gender'] as String?,
      placename: row['placename'] as String?,
      country: row['country'] as String?,
      utcOffset: row['utc_offset'] == null
          ? null
          : (row['utc_offset'] as num).toDouble(),
      dstOffset: row['dst_offset'] == null
          ? null
          : (row['dst_offset'] as num).toDouble(),
      notes: row['notes'] as String?,
      rodden: row['rodden'] as String?,
      sourcePath: row['source_path'] as String?,
      contentHash: row['content_hash'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String id;
  final double jd;
  final double lat;
  final double lon;
  final double alt;
  final String name;
  final String? gender;
  final String? placename;
  final String? country;
  final double? utcOffset;
  final double? dstOffset;
  final String? notes;
  final String? rodden;
  final String? sourcePath;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns a map suitable for INSERT parameter binding (column order).
  Map<String, Object?> toMap() => {
    'id': id,
    'jd': jd,
    'lat': lat,
    'lon': lon,
    'alt': alt,
    'name': name,
    'gender': gender,
    'placename': placename,
    'country': country,
    'utc_offset': utcOffset,
    'dst_offset': dstOffset,
    'notes': notes,
    'rodden': rodden,
    'source_path': sourcePath,
    'content_hash': contentHash,
  };
}

/// CRUD and full-text search for the `charts` table.
///
/// All operations are synchronous (sqlite3 is synchronous). Pass the
/// underlying [Database] from [ChartDatabase.db].
class ChartRepository {
  ChartRepository(this._db);

  final Database _db;

  /// Inserts a chart. Generates a UUID v4 if [chart.id] is empty.
  ///
  /// FTS is synced automatically via trigger.
  String insert(Chart chart) {
    final id = chart.id.isEmpty ? _uuid.v4() : chart.id;
    _db.execute(
      '''INSERT INTO charts
         (id, jd, lat, lon, alt, name, gender, placename, country,
          utc_offset, dst_offset, notes, rodden, source_path, content_hash)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);''',
      [
        id,
        chart.jd,
        chart.lat,
        chart.lon,
        chart.alt,
        chart.name,
        chart.gender,
        chart.placename,
        chart.country,
        chart.utcOffset,
        chart.dstOffset,
        chart.notes,
        chart.rodden,
        chart.sourcePath,
        chart.contentHash,
      ],
    );
    return id;
  }

  /// Returns a chart by [id], or `null` if not found.
  Chart? get(String id) {
    final rows = _db.select('SELECT * FROM charts WHERE id = ?;', [id]);
    if (rows.isEmpty) return null;
    return Chart.fromRow(rows.first);
  }

  /// Partial update of mutable fields. Sets `updated_at` automatically.
  /// FTS is synced via trigger.
  void update(
    String id, {
    String? name,
    String? gender,
    String? notes,
    String? rodden,
    String? placename,
    String? country,
  }) {
    final sets = <String>[];
    final params = <Object?>[];

    if (name != null) {
      sets.add('name = ?');
      params.add(name);
    }
    if (gender != null) {
      sets.add('gender = ?');
      params.add(gender);
    }
    if (notes != null) {
      sets.add('notes = ?');
      params.add(notes);
    }
    if (rodden != null) {
      sets.add('rodden = ?');
      params.add(rodden);
    }
    if (placename != null) {
      sets.add('placename = ?');
      params.add(placename);
    }
    if (country != null) {
      sets.add('country = ?');
      params.add(country);
    }

    if (sets.isEmpty) return;

    sets.add("updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')");
    params.add(id);

    _db.execute('UPDATE charts SET ${sets.join(', ')} WHERE id = ?;', params);
  }

  /// Deletes a chart by [id]. Tags and collection memberships cascade via FK.
  /// FTS is cleaned via trigger.
  void delete(String id) {
    _db.execute('DELETE FROM charts WHERE id = ?;', [id]);
  }

  /// Searches charts combining FTS5 match and metadata filters.
  ///
  /// When [query] is provided, joins with `charts_fts` using MATCH and ranks
  /// by BM25. Otherwise filters the `charts` table directly.
  ///
  /// All non-null filters are combined with AND.
  List<Chart> search({
    String? query,
    String? country,
    double? jdMin,
    double? jdMax,
    String? tag,
    String? collectionId,
    int limit = 50,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    var from = 'charts c';
    var orderBy = 'c.name';

    // FTS match
    if (query != null && query.isNotEmpty) {
      from =
          'charts_fts '
          'JOIN charts c ON c.rowid = charts_fts.rowid';
      where.add('charts_fts MATCH ?');
      params.add(query);
      orderBy = 'bm25(charts_fts)'; // lower = better match
    }

    // Country filter
    if (country != null) {
      where.add('c.country = ?');
      params.add(country);
    }

    // JD range
    if (jdMin != null) {
      where.add('c.jd >= ?');
      params.add(jdMin);
    }
    if (jdMax != null) {
      where.add('c.jd <= ?');
      params.add(jdMax);
    }

    // Tag filter
    if (tag != null) {
      from += ' JOIN chart_tags ct ON ct.chart_id = c.id';
      where.add('ct.tag = ?');
      params.add(tag);
    }

    // Collection filter
    if (collectionId != null) {
      from += ' JOIN chart_collections cc ON cc.chart_id = c.id';
      where.add('cc.collection_id = ?');
      params.add(collectionId);
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    params.add(limit);

    final sql =
        '''
      SELECT DISTINCT c.*
      FROM $from
      $whereClause
      ORDER BY $orderBy
      LIMIT ?;
    ''';

    final rows = _db.select(sql, params);
    return rows.map(Chart.fromRow).toList();
  }

  /// Returns charts whose (jd, lat, lon) match within tolerance.
  ///
  /// Default tolerances: ~1 second for JD, ~10m for coordinates.
  /// If [excludeId] is provided, that chart is excluded from results
  /// (useful when checking before an update).
  List<Chart> findDuplicates(
    double jd,
    double lat,
    double lon, {
    double jdTolerance = 1.2e-5,
    double geoTolerance = 0.0001,
    String? excludeId,
  }) {
    final where = [
      'jd >= ? AND jd <= ?',
      'lat >= ? AND lat <= ?',
      'lon >= ? AND lon <= ?',
    ];
    final params = <Object?>[
      jd - jdTolerance,
      jd + jdTolerance,
      lat - geoTolerance,
      lat + geoTolerance,
      lon - geoTolerance,
      lon + geoTolerance,
    ];

    if (excludeId != null) {
      where.add('id != ?');
      params.add(excludeId);
    }

    final sql = 'SELECT * FROM charts WHERE ${where.join(' AND ')};';
    final rows = _db.select(sql, params);
    return rows.map(Chart.fromRow).toList();
  }

  /// Returns all charts with a non-null source_path, keyed by source_path.
  Map<String, Chart> listIndexed() {
    final rows = _db.select(
      'SELECT * FROM charts WHERE source_path IS NOT NULL',
    );
    final result = <String, Chart>{};
    for (final row in rows) {
      final chart = Chart.fromRow(row);
      result[chart.sourcePath!] = chart;
    }
    return result;
  }
}
