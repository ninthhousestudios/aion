import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the get_chart tool.
final _inputSchema = JsonObject(
  properties: {
    'id': JsonString(
      description: 'The chart id (UUID)',
    ),
  },
  required: ['id'],
  additionalProperties: false,
);

/// Registers the get_chart tool on the given [server].
void registerGetChart(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'get_chart',
    description: 'Get a chart by its id. Returns full chart details '
        'including all metadata fields.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(args, chartRepo),
  );
}

CallToolResult _handle(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  final id = args['id'] as String?;
  if (id == null || id.isEmpty) {
    return _errorResult('Missing required parameter: id');
  }

  try {
    final chart = chartRepo.get(id);
    if (chart == null) {
      return _errorResult('Chart not found: $id');
    }

    return CallToolResult.fromStructuredContent({
      'id': chart.id,
      'name': chart.name,
      'jd': chart.jd,
      'lat': chart.lat,
      'lon': chart.lon,
      'alt': chart.alt,
      'gender': chart.gender,
      'placename': chart.placename,
      'country': chart.country,
      'utc_offset': chart.utcOffset,
      'dst_offset': chart.dstOffset,
      'notes': chart.notes,
      'rodden': chart.rodden,
      'source_path': chart.sourcePath,
      'created_at': chart.createdAt.toIso8601String(),
      'updated_at': chart.updatedAt.toIso8601String(),
    });
  } catch (e) {
    return _errorResult('Failed to get chart: $e');
  }
}

CallToolResult _errorResult(String message) {
  return CallToolResult(
    content: [TextContent(text: message)],
    isError: true,
  );
}
