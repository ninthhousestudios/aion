import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart' as cdc;
import 'package:charts_dart/charts_dart.dart';

/// Standalone data class holding all fields needed for the charts table.
///
/// Decoupled from chart_db_core's Chart model (Issue 3) so the importer
/// can be developed independently. The chart service (Issue 11) bridges
/// between ImportedChart and the repository's Chart class.
class ImportedChart {
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

  const ImportedChart({
    required this.jd,
    required this.lat,
    required this.lon,
    this.alt = 0,
    required this.name,
    this.gender,
    this.placename,
    this.country,
    this.utcOffset,
    this.dstOffset,
    this.notes,
    this.rodden,
    this.sourcePath,
  });

  @override
  String toString() =>
      'ImportedChart($name, jd=$jd, lat=$lat, lon=$lon)';
}

/// Imports chart files from disk into [ImportedChart] instances.
///
/// Uses charts_dart's [ChartIO] for format dispatch, then maps the
/// resulting [ChartData] to ImportedChart with Julian Day computation.
class ChartImporter {
  /// Import a single chart file.
  ///
  /// Throws [UnsupportedError] if the file extension is not recognised.
  /// Throws [FileSystemException] if the file does not exist.
  ImportedChart importFile(String path) {
    final chartData = ChartIO.read(path);
    return _mapToImported(chartData, path);
  }

  /// Import all chart files in [dirPath] matching [extensions].
  ///
  /// If [extensions] is null, all extensions supported by ChartIO are used.
  /// Non-matching files are silently skipped.
  /// Files that fail to parse are skipped and their paths are collected in
  /// [errors] (if provided).
  List<ImportedChart> importDirectory(
    String dirPath, {
    List<String>? extensions,
    List<(String path, Object error)>? errors,
  }) {
    final exts = extensions ??
        ChartIO.supportedExtensions.map((e) => e.toLowerCase()).toList();
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      throw FileSystemException('Directory not found', dirPath);
    }

    final results = <ImportedChart>[];
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

  /// Map [ChartData] to [ImportedChart].
  ImportedChart _mapToImported(ChartData cd, String filePath) {
    final jd = cdc.dateTimeToJd(cd.utcDateTime);
    final alt = (cd.extra['altitude'] as num?)?.toDouble() ?? 0.0;

    return ImportedChart(
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
      sourcePath: filePath,
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
