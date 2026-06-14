import 'dart:io';

import 'package:toml/toml.dart';

import 'chart_doc.dart';
import 'collection_repository.dart';
import 'toml_chart.dart';

class ChartLibrary {
  final String root;
  final CollectionRepository? _collectionRepo;

  ChartLibrary(this.root, {CollectionRepository? collectionRepo})
    : _collectionRepo = collectionRepo {
    Directory(root).createSync(recursive: true);
  }

  static String defaultRoot() {
    final override = Platform.environment['AION_CHARTS'];
    if (override != null && override.isNotEmpty) return override;
    final xdg = Platform.environment['XDG_DATA_HOME'];
    final base = xdg ?? '${Platform.environment['HOME']}/.local/share';
    return '$base/aion/charts';
  }

  List<String> listChartPaths() {
    return Directory(root)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.toml'))
        .map((f) => f.path)
        .toList();
  }

  ChartDoc loadChart(String path) {
    final source = File(path).readAsStringSync();
    final doc = TomlChartCodec.decode(source);
    if (_jdMissing(source)) {
      TomlChartCodec.encodeFile(path, doc);
    }
    return doc;
  }

  Map<String, ChartDoc> loadAll({List<(String, Object)>? errors}) {
    final result = <String, ChartDoc>{};
    for (final path in listChartPaths()) {
      try {
        result[path] = loadChart(path);
      } catch (e) {
        errors?.add((path, e));
      }
    }
    return result;
  }

  String saveChart(ChartDoc doc, {String? path}) {
    final target = path ?? _generatePath(doc);
    TomlChartCodec.encodeFile(target, doc);
    return target;
  }

  /// Updates the tags on a chart file and optionally syncs to sqlite.
  ///
  /// Reads the existing TOML, replaces the tags, writes back atomically.
  /// If [collectionRepo] was provided at construction and [chartId] is given,
  /// the sqlite `chart_tags` table is diff-updated to match.
  void setTags(String path, List<String> tags, {String? chartId}) {
    final doc = loadChart(path);
    final updated = doc.copyWith(tags: tags);
    saveChart(updated, path: path);

    final repo = _collectionRepo;
    if (repo != null && chartId != null) {
      final current = repo.tagsFor(chartId);
      final desired = tags.toSet();
      for (final tag in desired.difference(current)) {
        repo.addTag(chartId, tag);
      }
      for (final tag in current.difference(desired)) {
        repo.removeTag(chartId, tag);
      }
    }
  }

  static bool _jdMissing(String source) {
    try {
      final map = TomlDocument.parse(source).toMap();
      final moment = map['moment'] as Map<String, dynamic>?;
      return moment == null || moment['jd'] == null;
    } catch (_) {
      return false;
    }
  }

  String _generatePath(ChartDoc doc) {
    final base = sanitizeName(doc.name.isEmpty ? 'chart' : doc.name);
    var candidate = '$root/$base.toml';
    var counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '$root/$base-$counter.toml';
      counter++;
    }
    return candidate;
  }

  static String sanitizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
