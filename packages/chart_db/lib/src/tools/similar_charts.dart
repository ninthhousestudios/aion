import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the similar_charts tool.
final _inputSchema = JsonObject(
  properties: {
    'chart_id': JsonString(
      description: 'The id of the chart to find similar charts for',
    ),
    'config_id': JsonString(
      description: 'The config id that determines which vector schema to use',
    ),
    'k': JsonNumber(
      description: 'Number of similar charts to return (default: 20)',
      defaultValue: 20,
    ),
    'weights': JsonObject(
      description: 'Optional dimension weights as a map of dimension index '
          '(string) to weight (number). Unspecified dimensions default to 1.0.',
      additionalProperties: true,
    ),
  },
  required: ['chart_id', 'config_id'],
  additionalProperties: false,
);

/// Registers the similar_charts tool on the given [server].
void registerSimilarCharts(McpServer server, SimilaritySearch search) {
  server.registerTool(
    'similar_charts',
    description: 'Find charts similar to a given chart using vector '
        'similarity search. Returns ranked results with distance scores.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(args, search),
  );
}

CallToolResult _handle(
  Map<String, dynamic> args,
  SimilaritySearch search,
) {
  final chartId = args['chart_id'] as String?;
  if (chartId == null || chartId.isEmpty) {
    return _errorResult('Missing required parameter: chart_id');
  }

  final configId = args['config_id'] as String?;
  if (configId == null || configId.isEmpty) {
    return _errorResult('Missing required parameter: config_id');
  }

  final k = (args['k'] as num?)?.toInt() ?? 20;

  // Parse weights: JSON object with string keys (dimension indices) to doubles.
  Map<int, double>? weights;
  if (args['weights'] != null) {
    final rawWeights = args['weights'] as Map<String, dynamic>;
    weights = {};
    for (final entry in rawWeights.entries) {
      final dim = int.tryParse(entry.key);
      final weight = (entry.value as num?)?.toDouble();
      if (dim != null && weight != null) {
        weights[dim] = weight;
      }
    }
  }

  try {
    final results = search.findSimilar(
      chartId,
      configId,
      k: k,
      weights: weights,
    );

    return CallToolResult.fromStructuredContent({
      'query_chart_id': chartId,
      'config_id': configId,
      'count': results.length,
      'results': results
          .map((r) => {
                'chart_id': r.chartId,
                'distance': r.distance,
              })
          .toList(),
    });
  } catch (e) {
    return _errorResult('Similarity search failed: $e');
  }
}

CallToolResult _errorResult(String message) {
  return CallToolResult(
    content: [TextContent(text: message)],
    isError: true,
  );
}
