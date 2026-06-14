import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart' as cdc;
import 'package:chart_db_core/chart_db_core.dart' show ChartDoc;
import 'package:charts_dart/charts_dart.dart';

/// Imports chart files from disk into [ChartDoc] instances.
///
/// Uses charts_dart's [ChartIO] for format dispatch (handles legacy TOML,
/// JSON, and other formats), then maps the resulting [ChartData] to a
/// [ChartDoc] with Julian Day computation.
class ChartImporter {
  /// Import a single chart file.
  ///
  /// Returns the decoded [ChartDoc] and the source file path.
  /// Throws [UnsupportedError] if the file extension is not recognised.
  /// Throws [FileSystemException] if the file does not exist.
  (ChartDoc, String) importFile(String path) {
    final chartData = ChartIO.read(path);
    return (_mapToChartDoc(chartData), path);
  }

  /// Import all chart files in [dirPath] matching [extensions].
  ///
  /// If [extensions] is null, all extensions supported by ChartIO are used.
  /// Non-matching files are silently skipped.
  /// Files that fail to parse are skipped and their paths are collected in
  /// [errors] (if provided).
  List<(ChartDoc, String)> importDirectory(
    String dirPath, {
    List<String>? extensions,
    List<(String path, Object error)>? errors,
  }) {
    final exts =
        extensions ??
        ChartIO.supportedExtensions.map((e) => e.toLowerCase()).toList();
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      throw FileSystemException('Directory not found', dirPath);
    }

    final results = <(ChartDoc, String)>[];
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is! File) continue;
      final ext = _extension(entity.path);
      if (!exts.contains(ext)) continue;
      try {
        results.add(importFile(entity.path));
      } catch (e) {
        errors?.add((entity.path, e));
      }
    }
    return results;
  }

  ChartDoc _mapToChartDoc(ChartData cd) {
    final jd = cdc.dateTimeToJd(cd.utcDateTime);
    final alt = (cd.extra['altitude'] as num?)?.toDouble() ?? 0.0;

    return ChartDoc(
      jd: jd,
      lat: cd.birthLocation.latitude,
      lon: cd.birthLocation.longitude,
      alt: alt,
      name: cd.name,
      gender: cd.gender?.name,
      placename: cd.birthLocation.city.isNotEmpty
          ? cd.birthLocation.city
          : null,
      country: cd.birthLocation.country.isNotEmpty
          ? cd.birthLocation.country
          : null,
      utcOffset: cd.utcOffsetHours,
      dstOffset: cd.dstOffsetHours,
      notes: cd.notes,
      rodden: cd.roddenRating,
    );
  }

  /// Lowercase file extension including the dot.
  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot).toLowerCase();
  }

  /// Convert a UTC [DateTime] to Julian Day Number.
  ///
  /// Visible for testing. Delegates to chart_db_core's canonical
  /// [cdc.dateTimeToJd] — the single home for JD math in aion.
  static double dateTimeToJd(DateTime dt) => cdc.dateTimeToJd(dt);
}
