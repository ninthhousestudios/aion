import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

final _inputSchema = JsonObject(
  properties: {},
  required: [],
  additionalProperties: false,
);

void registerListCollections(
  McpServer server,
  CollectionRepository collectionRepo,
) {
  server.registerTool(
    'list_collections',
    description: 'List all chart collections with their chart counts.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleListCollections(collectionRepo),
  );
}

CallToolResult handleListCollections(CollectionRepository collectionRepo) {
  try {
    final collections = collectionRepo.list();

    return CallToolResult.fromStructuredContent({
      'count': collections.length,
      'collections': collections
          .map((cwc) => {
                'id': cwc.collection.id,
                'name': cwc.collection.name,
                if (cwc.collection.note != null) 'note': cwc.collection.note,
                'chart_count': cwc.chartCount,
                'created_at': cwc.collection.createdAt.toIso8601String(),
              })
          .toList(),
    });
  } catch (e) {
    return errorResult('Failed to list collections: $e');
  }
}
