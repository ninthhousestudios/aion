import 'dart:io';

import 'package:toml/toml.dart';

import 'chart_doc.dart';
import 'toml_chart.dart';

class ChartLibrary {
  final String root;

  ChartLibrary(this.root) {
    Directory(root).createSync(recursive: true);
  }

  static String defaultRoot() {
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
