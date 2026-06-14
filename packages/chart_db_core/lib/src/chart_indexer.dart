import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'chart_doc.dart';
import 'chart_repository.dart';
import 'collection_repository.dart';
import 'collection_sidecar.dart';
import 'content_hash.dart';
import 'toml_chart.dart';

/// Result of a [ChartIndexer.reindex] operation.
class IndexResult {
  IndexResult({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int added;
  final int updated;
  final int removed;
  final int skipped;
  final List<(String path, Object error)> errors;

  int get total => added + updated + removed + skipped;
}

/// Builds and incrementally maintains the chart index from a directory of
/// .toml files.
///
/// The index is derived — rebuildable from the TOML directory at any time.
/// Uses [contentHash] (SHA-256 of raw bytes) to detect changes and skip
/// unchanged files.
class ChartIndexer {
  ChartIndexer(this._db, this._repo, {CollectionRepository? collectionRepo})
    : _collectionRepo = collectionRepo;

  final Database _db;
  final ChartRepository _repo;
  final CollectionRepository? _collectionRepo;

  /// Full or incremental reindex of [directoryPath].
  ///
  /// Scans all .toml files, compares content_hash against what's stored,
  /// and inserts/updates/deletes as needed. Returns an [IndexResult] summary.
  ///
  /// The entire operation runs inside an IMMEDIATE transaction to prevent
  /// concurrent reindex from creating duplicate source_path rows.
  IndexResult reindex(String directoryPath) {
    final dir = Directory(directoryPath);
    final tomlFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.toml'))
        .toList();

    // Read file bytes and compute hashes outside the transaction (I/O heavy).
    final fileData = <(File, String, String)>[]; // (file, path, hash)
    for (final file in tomlFiles) {
      final bytes = file.readAsBytesSync();
      fileData.add((file, file.path, contentHash(bytes)));
    }

    _db.execute('BEGIN IMMEDIATE;');
    try {
      final result = _reindexInTransaction(fileData);
      _db.execute('COMMIT;');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  IndexResult _reindexInTransaction(List<(File, String, String)> fileData) {
    final indexed = _repo.listIndexed();
    final seenPaths = <String>{};
    var added = 0;
    var updated = 0;
    var skipped = 0;
    final errors = <(String, Object)>[];

    for (final (file, path, hash) in fileData) {
      seenPaths.add(path);

      final existing = indexed[path];
      if (existing != null && existing.contentHash == hash) {
        _ensureTags(existing.id, file);
        skipped++;
        continue;
      }

      ChartDoc doc;
      try {
        final bytes = file.readAsBytesSync();
        doc = TomlChartCodec.decode(utf8.decode(bytes));
      } catch (e) {
        errors.add((path, e));
        continue;
      }

      if (existing != null) {
        _repo.delete(existing.id);
        final chartId = _repo.insert(_chartFromDoc(doc, path, hash));
        _syncTags(chartId, doc.tags);
        updated++;
      } else {
        final chartId = _repo.insert(_chartFromDoc(doc, path, hash));
        _syncTags(chartId, doc.tags);
        added++;
      }
    }

    var removed = 0;
    for (final entry in indexed.entries) {
      if (!seenPaths.contains(entry.key)) {
        _repo.delete(entry.value.id);
        removed++;
      }
    }

    if (_collectionRepo != null && fileData.isNotEmpty) {
      final dirPath = File(fileData.first.$2).parent.path;
      _syncCollections(dirPath);
    }

    return IndexResult(
      added: added,
      updated: updated,
      removed: removed,
      skipped: skipped,
      errors: errors,
    );
  }

  void _syncCollections(String dirPath) {
    final repo = _collectionRepo!;
    final sidecar = CollectionSidecar.load(dirPath);

    // Build source_path → chart_id lookup from current index.
    final indexed = _repo.listIndexed();
    final pathToId = <String, String>{
      for (final e in indexed.entries) e.key: e.value.id,
    };

    // Sync each sidecar collection into sqlite.
    final existingIds = repo.list().map((c) => c.collection.id).toSet();

    for (final col in sidecar) {
      if (!existingIds.contains(col.id)) {
        _db.execute(
          'INSERT INTO collections (id, name, note) VALUES (?, ?, ?);',
          [col.id, col.name, col.note],
        );
      } else {
        _db.execute('UPDATE collections SET name = ?, note = ? WHERE id = ?;', [
          col.name,
          col.note,
          col.id,
        ]);
      }

      // Resolve source paths to chart ids and sync membership.
      // Sidecar may store absolute or relative paths; try both.
      final currentMembers = repo.chartsIn(col.id).toSet();
      final desired = <String>{};
      for (final sourcePath in col.charts) {
        var chartId = pathToId[sourcePath];
        if (chartId == null && !sourcePath.startsWith('/')) {
          chartId = pathToId['$dirPath/$sourcePath'];
        }
        if (chartId != null) desired.add(chartId);
      }

      for (final chartId in desired.difference(currentMembers)) {
        repo.addChart(chartId, col.id);
      }
      for (final chartId in currentMembers.difference(desired)) {
        repo.removeChart(chartId, col.id);
      }
    }

    // Remove sqlite collections that are no longer in the sidecar.
    final sidecarIds = sidecar.map((c) => c.id).toSet();
    for (final id in existingIds.difference(sidecarIds)) {
      repo.delete(id);
    }
  }

  /// For skipped (unchanged) charts, ensure tags are present in sqlite.
  /// Avoids decoding TOML unless tag rows are missing.
  void _ensureTags(String chartId, File file) {
    final repo = _collectionRepo;
    if (repo == null) return;
    final existing = repo.tagsFor(chartId);
    if (existing.isNotEmpty) return;
    // No tags in sqlite — decode TOML to check if it has tags.
    try {
      final doc = TomlChartCodec.decode(utf8.decode(file.readAsBytesSync()));
      _syncTags(chartId, doc.tags);
    } catch (_) {
      // Best-effort: if TOML can't be decoded, skip.
    }
  }

  void _syncTags(String chartId, List<String> tags) {
    final repo = _collectionRepo;
    if (repo == null) return;
    for (final tag in tags) {
      repo.addTag(chartId, tag);
    }
  }

  Chart _chartFromDoc(ChartDoc doc, String path, String hash) {
    return Chart(
      id: '',
      jd: doc.jd,
      lat: doc.lat,
      lon: doc.lon,
      alt: doc.alt,
      name: doc.name,
      gender: doc.gender,
      placename: doc.placename,
      country: doc.country,
      utcOffset: doc.utcOffset,
      dstOffset: doc.dstOffset,
      notes: doc.notes,
      rodden: doc.rodden,
      sourcePath: path,
      contentHash: hash,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
