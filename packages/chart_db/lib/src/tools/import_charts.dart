import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:charts_dart/charts_dart.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the import_charts tool.
final _inputSchema = JsonObject(
  properties: {
    'path': JsonString(
      description: 'Path to a chart file or directory of chart files',
    ),
    'extensions': JsonArray(
      description: 'File extensions to import (e.g. [".toml", ".json"]). '
          'If omitted, all supported extensions are used.',
      items: JsonString(),
    ),
  },
  required: ['path'],
  additionalProperties: false,
);

/// Registers the import_charts tool on the given [server].
void registerImportCharts(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'import_charts',
    description: 'Import chart files from disk into the database. '
        'Accepts a single file path or a directory path. '
        'Duplicate charts (same jd, lat, lon) are skipped.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(args, chartRepo),
  );
}

CallToolResult _handle(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  final path = args['path'] as String?;
  if (path == null || path.isEmpty) {
    return _errorResult('Missing required parameter: path');
  }

  final extensions = (args['extensions'] as List?)
      ?.map((e) => (e as String).toLowerCase())
      .toList();

  try {
    final imported = <_ImportResult>[];
    final errors = <String>[];

    if (FileSystemEntity.isDirectorySync(path)) {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        return _errorResult('Directory not found: $path');
      }

      final exts = extensions ??
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
      return _errorResult('Path not found: $path');
    }

    return CallToolResult.fromStructuredContent({
      'imported': imported.length,
      'skipped_duplicates':
          imported.where((r) => r.skippedDuplicate).length,
      'errors': errors.length,
      'results': imported
          .map((r) => {
                'chart_id': r.chartId,
                'name': r.name,
                'source': r.sourcePath,
                if (r.skippedDuplicate) 'skipped_duplicate': true,
              })
          .toList(),
      if (errors.isNotEmpty) 'error_details': errors,
    });
  } catch (e) {
    return _errorResult('Import failed: $e');
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
    final alt = (chartData.extra['altitude'] as num?)?.toDouble() ?? 0.0;

    final chart = Chart(
      id: '',
      jd: jd,
      lat: chartData.birthLocation.latitude,
      lon: chartData.birthLocation.longitude,
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
      sourcePath: filePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final id = chartRepo.insert(chart);
      imported.add(_ImportResult(
        chartId: id,
        name: chart.name,
        sourcePath: filePath,
      ));
    } on DuplicateChartException catch (e) {
      imported.add(_ImportResult(
        chartId: e.existingId,
        name: chart.name,
        sourcePath: filePath,
        skippedDuplicate: true,
      ));
    }
  } catch (e) {
    errors.add('$filePath: $e');
  }
}

class _ImportResult {
  _ImportResult({
    required this.chartId,
    required this.name,
    required this.sourcePath,
    this.skippedDuplicate = false,
  });

  final String chartId;
  final String name;
  final String sourcePath;
  final bool skippedDuplicate;
}

/// Lowercase file extension including the dot.
String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}

CallToolResult _errorResult(String message) {
  return CallToolResult(
    content: [TextContent(text: message)],
    isError: true,
  );
}
