import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

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

void registerSearchCharts(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'search_charts',
    description: 'Search for charts using full-text search and metadata '
        'filters. Combines FTS5 match with country, JD range, tag, '
        'and collection filters.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleSearchCharts(args, chartRepo),
  );
}

CallToolResult handleSearchCharts(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  try {
    final limit = args['limit'];
    if (limit != null && limit is! num) {
      return errorResult('Invalid parameter: limit (expected number)');
    }

    final charts = chartRepo.search(
      query: args['query'] as String?,
      country: args['country'] as String?,
      jdMin: _parseNum(args['jd_min']),
      jdMax: _parseNum(args['jd_max']),
      tag: args['tag'] as String?,
      collectionId: args['collection_id'] as String?,
      limit: (limit as num?)?.toInt() ?? 50,
    );

    final results = charts.map(chartToMap).toList();
    return CallToolResult.fromStructuredContent({
      'count': results.length,
      'charts': results,
    });
  } catch (e) {
    return errorResult('Search failed: $e');
  }
}

double? _parseNum(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
