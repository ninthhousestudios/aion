import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

final _inputSchema = JsonObject(
  properties: {
    'id': JsonString(
      description: 'The chart id (UUID)',
    ),
  },
  required: ['id'],
  additionalProperties: false,
);

void registerGetChart(McpServer server, ChartRepository chartRepo) {
  server.registerTool(
    'get_chart',
    description: 'Get a chart by its id. Returns full chart details '
        'including all metadata fields.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleGetChart(args, chartRepo),
  );
}

CallToolResult handleGetChart(
  Map<String, dynamic> args,
  ChartRepository chartRepo,
) {
  final id = args['id'];
  if (id is! String || id.isEmpty) {
    return errorResult('Missing required parameter: id');
  }

  try {
    final chart = chartRepo.get(id);
    if (chart == null) {
      return errorResult('Chart not found: $id');
    }

    return CallToolResult.fromStructuredContent(chartToMap(chart));
  } catch (e) {
    return errorResult('Failed to get chart: $e');
  }
}
