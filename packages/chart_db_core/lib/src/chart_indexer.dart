import 'dart:convert';
import 'dart:io';

import 'chart_doc.dart';
import 'chart_repository.dart';
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
  ChartIndexer(this._repo);

  final ChartRepository _repo;

  /// Full or incremental reindex of [directoryPath].
  ///
  /// Scans all .toml files, compares content_hash against what's stored,
  /// and inserts/updates/deletes as needed. Returns an [IndexResult] summary.
  IndexResult reindex(String directoryPath) {
    final dir = Directory(directoryPath);
    final tomlFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.toml'))
        .toList();

    final indexed = _repo.listIndexed();
    final seenPaths = <String>{};
    var added = 0;
    var updated = 0;
    var skipped = 0;
    final errors = <(String, Object)>[];

    for (final file in tomlFiles) {
      final path = file.path;
      seenPaths.add(path);
      final bytes = file.readAsBytesSync();
      final hash = contentHash(bytes);

      final existing = indexed[path];
      if (existing != null && existing.contentHash == hash) {
        skipped++;
        continue;
      }

      ChartDoc doc;
      try {
        doc = TomlChartCodec.decode(utf8.decode(bytes));
      } catch (e) {
        errors.add((path, e));
        continue;
      }

      if (existing != null) {
        _repo.delete(existing.id);
        _repo.insert(_chartFromDoc(doc, path, hash));
        updated++;
      } else {
        _repo.insert(_chartFromDoc(doc, path, hash));
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

    return IndexResult(
      added: added,
      updated: updated,
      removed: removed,
      skipped: skipped,
      errors: errors,
    );
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
