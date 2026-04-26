import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the search_charts tool.
final _inputSchema = JsonObject(
  properties: {
    'query': JsonString(
      description: 'Full-text search query (searches name, placename, '
          'country, notes)',
    ),
    'country': JsonString(
      description: 'Filter by country (exact match)',
    ),
    'jd_min': JsonNumber(
      description: 'Minimum Julian Day number',
    ),
    'jd_max': JsonNumber(
      description: 'Maximum Julian Day number',
    ),
    'tag': JsonString(
      description: 'Filter by tag (exact match)',
    ),
    'collection_id': JsonString(
      description: 'Filter by collection id',
    ),
    'limit': JsonNumber(
      description: 'Maximum number of results (default: 50)',
      defaultValue: 50,
    ),
  },
  required: [],
  additionalProperties: false,
);

/// Registers the search_charts tool on the given [server].
void registerSearchCharts(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'search_charts',
    description: 'Search for charts using full-text search and metadata '
        'filters. Combines FTS5 match with country, JD range, tag, '
        'and collection filters.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(args, chartRepo),
  );
}

CallToolResult _handle(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  try {
    final charts = chartRepo.search(
      query: args['query'] as String?,
      country: args['country'] as String?,
      jdMin: _parseNum(args['jd_min']),
      jdMax: _parseNum(args['jd_max']),
      tag: args['tag'] as String?,
      collectionId: args['collection_id'] as String?,
      limit: (args['limit'] as num?)?.toInt() ?? 50,
    );

    final results = charts.map(_chartToMap).toList();
    return CallToolResult.fromStructuredContent({
      'count': results.length,
      'charts': results,
    });
  } catch (e) {
    return _errorResult('Search failed: $e');
  }
}

Map<String, dynamic> _chartToMap(Chart chart) => {
      'id': chart.id,
      'name': chart.name,
      'jd': chart.jd,
      'lat': chart.lat,
      'lon': chart.lon,
      'alt': chart.alt,
      if (chart.gender != null) 'gender': chart.gender,
      if (chart.placename != null) 'placename': chart.placename,
      if (chart.country != null) 'country': chart.country,
      if (chart.utcOffset != null) 'utc_offset': chart.utcOffset,
      if (chart.dstOffset != null) 'dst_offset': chart.dstOffset,
      if (chart.notes != null) 'notes': chart.notes,
      if (chart.rodden != null) 'rodden': chart.rodden,
      if (chart.sourcePath != null) 'source_path': chart.sourcePath,
      'created_at': chart.createdAt.toIso8601String(),
      'updated_at': chart.updatedAt.toIso8601String(),
    };

double? _parseNum(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

CallToolResult _errorResult(String message) {
  return CallToolResult(
    content: [TextContent(text: message)],
    isError: true,
  );
}
