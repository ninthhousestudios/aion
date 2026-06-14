import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A collection as stored in `_collections.json`.
class SidecarCollection {
  SidecarCollection({
    required this.id,
    required this.name,
    this.note,
    List<String>? charts,
  }) : charts = charts ?? [];

  final String id;
  String name;
  final String? note;
  final List<String> charts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (note != null) 'note': note,
    'charts': charts,
  };

  static SidecarCollection fromJson(Map<String, dynamic> json) {
    return SidecarCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      note: json['note'] as String?,
      charts: (json['charts'] as List<dynamic>?)?.cast<String>().toList() ?? [],
    );
  }
}

/// Reads and writes `_collections.json` in a chart directory.
///
/// This file is the source of truth for collection definitions — the sqlite
/// tables are a derived index rebuilt during reindex.  Chart membership uses
/// source-relative TOML paths (e.g. `"gandhi.toml"`) so references survive
/// a database rebuild.
class CollectionSidecar {
  static const fileName = '_collections.json';

  /// Loads collections from `_collections.json` in [dirPath].
  /// Returns an empty list if the file does not exist.
  static List<SidecarCollection> load(String dirPath) {
    final file = File('$dirPath/$fileName');
    if (!file.existsSync()) return [];
    final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(SidecarCollection.fromJson)
        .toList();
  }

  /// Atomically writes collections to `_collections.json` in [dirPath].
  static void save(String dirPath, List<SidecarCollection> collections) {
    final path = '$dirPath/$fileName';
    final tmp = File('$path.tmp');
    final encoder = const JsonEncoder.withIndent('  ');
    tmp.writeAsStringSync(
      encoder.convert(collections.map((c) => c.toJson()).toList()),
      flush: true,
    );
    tmp.renameSync(path);
  }

  /// Creates a collection, saves, and returns its id.
  static String create(String dirPath, String name, {String? note}) {
    final collections = load(dirPath);
    final id = _uuid.v4();
    collections.add(SidecarCollection(id: id, name: name, note: note));
    save(dirPath, collections);
    return id;
  }

  /// Renames a collection and saves.
  static void rename(String dirPath, String collectionId, String newName) {
    final collections = load(dirPath);
    final col = collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () =>
          throw StateError('Collection "$collectionId" not found in sidecar'),
    );
    col.name = newName;
    save(dirPath, collections);
  }

  /// Deletes a collection and saves.
  static void delete(String dirPath, String collectionId) {
    final collections = load(dirPath);
    collections.removeWhere((c) => c.id == collectionId);
    save(dirPath, collections);
  }

  /// Adds a chart (by source path) to a collection and saves.
  static void addChart(String dirPath, String collectionId, String sourcePath) {
    final collections = load(dirPath);
    final col = collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () =>
          throw StateError('Collection "$collectionId" not found in sidecar'),
    );
    if (!col.charts.contains(sourcePath)) {
      col.charts.add(sourcePath);
      save(dirPath, collections);
    }
  }

  /// Removes a chart (by source path) from a collection and saves.
  static void removeChart(
    String dirPath,
    String collectionId,
    String sourcePath,
  ) {
    final collections = load(dirPath);
    final col = collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () =>
          throw StateError('Collection "$collectionId" not found in sidecar'),
    );
    if (col.charts.remove(sourcePath)) {
      save(dirPath, collections);
    }
  }
}
