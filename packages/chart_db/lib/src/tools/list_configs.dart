import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the list_configs tool.
final _inputSchema = JsonObject(
  properties: {},
  required: [],
  additionalProperties: false,
);

/// Registers the list_configs tool on the given [server].
void registerListConfigs(McpServer server, ConfigRepository configRepo) {
  server.registerTool(
    'list_configs',
    description: 'List all registered configs with their associated '
        'vector schema info.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(configRepo),
  );
}

CallToolResult _handle(ConfigRepository configRepo) {
  try {
    final configs = configRepo.list();

    return CallToolResult.fromStructuredContent({
      'count': configs.length,
      'configs': configs
          .map((cws) => {
                'id': cws.config.id,
                'name': cws.config.name,
                'preset': cws.config.preset,
                if (cws.config.vectorSchemaId != null)
                  'vector_schema_id': cws.config.vectorSchemaId,
                if (cws.schemaName != null) 'schema_name': cws.schemaName,
                if (cws.schemaDims != null) 'schema_dims': cws.schemaDims,
                'created_at': cws.config.createdAt.toIso8601String(),
              })
          .toList(),
    });
  } catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to list configs: $e')],
      isError: true,
    );
  }
}
