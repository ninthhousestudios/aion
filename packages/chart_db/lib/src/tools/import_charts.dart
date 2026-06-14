import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:charts_dart/charts_dart.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

final _inputSchema = JsonObject(
  properties: {
    'path': JsonString(
      description: 'Path to a chart file or directory of chart files',
    ),
    'extensions': JsonArray(
      description:
          'File extensions to import (e.g. [".toml", ".json"]). '
          'If omitted, all supported extensions are used.',
      items: JsonString(),
    ),
  },
  required: ['path'],
  additionalProperties: false,
);

void registerImportCharts(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'import_charts',
    description:
        'Import chart files from disk into the database. '
        'Accepts a single file path or a directory path. '
        'Warns about potential duplicates (same jd, lat, lon) but still imports.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleImportCharts(args, chartRepo),
  );
}

CallToolResult handleImportCharts(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  final path = args['path'];
  if (path is! String || path.isEmpty) {
    return errorResult('Missing required parameter: path');
  }

  final rawExtensions = args['extensions'];
  if (rawExtensions != null && rawExtensions is! List) {
    return errorResult('Invalid parameter: extensions (expected array)');
  }
  final extensions = (rawExtensions as List?)
      ?.map((e) => (e as String).toLowerCase())
      .toList();

  try {
    final imported = <_ImportResult>[];
    final errors = <String>[];

    if (FileSystemEntity.isDirectorySync(path)) {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        return errorResult('Directory not found: $path');
      }

      final exts =
          extensions ??
          ChartIO.supportedExtensions.map((e) => e.toLowerCase()).toList();

      for (final entity in dir.listSync(recursive: false)) {
        if (entity is! File) continue;
        final ext = _extension(entity.path);
        if (!exts.contains(ext)) continue;
        _importFile(entity.path, chartRepo, imported, errors);
      }
    } else if (FileSystemEntity.isFileSync(path)) {
      _importFile(path, chartRepo, imported, errors);
    } else {
      return errorResult('Path not found: $path');
    }

    final duplicateWarnings = imported
        .where((r) => r.duplicateOf.isNotEmpty)
        .map(
          (r) => {
            'chart_id': r.chartId,
            'name': r.name,
            'duplicate_of': r.duplicateOf
                .map(
                  (d) => {
                    'id': d.id,
                    'name': d.name,
                    'jd': d.jd,
                    'lat': d.lat,
                    'lon': d.lon,
                    if (d.placename != null) 'placename': d.placename,
                    if (d.country != null) 'country': d.country,
                    if (d.sourcePath != null) 'source_path': d.sourcePath,
                  },
                )
                .toList(),
          },
        )
        .toList();

    return CallToolResult.fromStructuredContent({
      'imported': imported.length,
      'duplicates': duplicateWarnings.length,
      'errors': errors.length,
      'results': imported
          .map(
            (r) => {
              'chart_id': r.chartId,
              'name': r.name,
              'source': r.sourcePath,
            },
          )
          .toList(),
      if (duplicateWarnings.isNotEmpty) 'duplicate_warnings': duplicateWarnings,
      if (errors.isNotEmpty) 'error_details': errors,
    });
  } catch (e) {
    return errorResult('Import failed: $e');
  }
}

void _importFile(
  String filePath,
  ChartRepository chartRepo,
  List<_ImportResult> imported,
  List<String> errors,
) {
  try {
    final chartData = ChartIO.read(filePath);
    final jd = dateTimeToJd(chartData.utcDateTime);
    final lat = chartData.birthLocation.latitude;
    final lon = chartData.birthLocation.longitude;
    final alt = (chartData.extra['altitude'] as num?)?.toDouble() ?? 0.0;

    final duplicates = chartRepo.findDuplicates(jd, lat, lon);

    final chart = Chart(
      id: '',
      jd: jd,
      lat: lat,
      lon: lon,
      alt: alt,
      name: chartData.name,
      gender: chartData.gender?.name,
      placename: chartData.birthLocation.city.isNotEmpty
          ? chartData.birthLocation.city
          : null,
      country: chartData.birthLocation.country.isNotEmpty
          ? chartData.birthLocation.country
          : null,
      utcOffset: chartData.utcOffsetHours,
      dstOffset: chartData.dstOffsetHours,
      notes: chartData.notes,
      rodden: chartData.roddenRating,
      sourcePath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final id = chartRepo.insert(chart);
    imported.add(
      _ImportResult(
        chartId: id,
        name: chart.name,
        sourcePath: filePath,
        duplicateOf: duplicates,
      ),
    );
  } catch (e) {
    errors.add('$filePath: $e');
  }
}

class _ImportResult {
  _ImportResult({
    required this.chartId,
    required this.name,
    required this.sourcePath,
    this.duplicateOf = const [],
  });

  final String chartId;
  final String name;
  final String sourcePath;
  final List<Chart> duplicateOf;
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}
