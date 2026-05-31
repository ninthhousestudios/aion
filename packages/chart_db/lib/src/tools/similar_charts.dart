import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

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

void registerSimilarCharts(McpServer server, SimilaritySearch search) {
  server.registerTool(
    'similar_charts',
    description: 'Find charts similar to a given chart using vector '
        'similarity search. Returns ranked results with distance scores.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleSimilarCharts(args, search),
  );
}

CallToolResult handleSimilarCharts(
  Map<String, dynamic> args,
  SimilaritySearch search,
) {
  final chartId = args['chart_id'];
  if (chartId is! String || chartId.isEmpty) {
    return errorResult('Missing required parameter: chart_id');
  }

  final configId = args['config_id'];
  if (configId is! String || configId.isEmpty) {
    return errorResult('Missing required parameter: config_id');
  }

  final rawK = args['k'];
  if (rawK != null && rawK is! num) {
    return errorResult('Invalid parameter: k (expected number)');
  }
  final k = (rawK as num?)?.toInt() ?? 20;

  Map<int, double>? weights;
  if (args['weights'] != null) {
    if (args['weights'] is! Map) {
      return errorResult(
          'Invalid parameter: weights (expected object with string keys)');
    }
    final rawWeights = args['weights'] as Map<String, dynamic>;
    weights = {};
    for (final entry in rawWeights.entries) {
      final dim = int.tryParse(entry.key);
      if (dim == null) {
        return errorResult(
            'Invalid weights key: "${entry.key}" (expected integer string)');
      }
      if (entry.value is! num) {
        return errorResult(
            'Invalid weights value for key "${entry.key}" (expected number)');
      }
      weights[dim] = (entry.value as num).toDouble();
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
    return errorResult('Similarity search failed: $e');
  }
}
