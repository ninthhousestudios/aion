import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the list_schemas tool.
final _inputSchema = JsonObject(
  properties: {},
  required: [],
  additionalProperties: false,
);

/// Registers the list_schemas tool on the given [server].
void registerListSchemas(
  McpServer server,
  VectorSchemaRepository schemaRepo,
) {
  server.registerTool(
    'list_schemas',
    description: 'List all registered vector schemas with their dimensions '
        'and spec details.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(schemaRepo),
  );
}

CallToolResult _handle(VectorSchemaRepository schemaRepo) {
  try {
    final schemas = schemaRepo.list();

    return CallToolResult.fromStructuredContent({
      'count': schemas.length,
      'schemas': schemas
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'dims': s.dims,
                'spec': s.spec,
                'created_at': s.createdAt.toIso8601String(),
              })
          .toList(),
    });
  } catch (e) {
    return CallToolResult(
      content: [TextContent(text: 'Failed to list schemas: $e')],
      isError: true,
    );
  }
}
