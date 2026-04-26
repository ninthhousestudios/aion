import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

/// Input schema for the create_config tool.
final _inputSchema = JsonObject(
  properties: {
    'name': JsonString(
      description: 'Human-readable name for the config (e.g. "tropical-western")',
    ),
    'preset_json': JsonString(
      description: 'Serialized ArrowOptions JSON string. The config id is '
          'the SHA-256 hash of this string, making registration idempotent.',
    ),
    'schema_id': JsonString(
      description: 'Optional vector schema id to associate with this config',
    ),
  },
  required: ['name', 'preset_json'],
  additionalProperties: false,
);

/// Registers the create_config tool on the given [server].
void registerCreateConfig(McpServer server, ConfigRepository configRepo) {
  server.registerTool(
    'create_config',
    description: 'Register a calculation config with a name and preset JSON. '
        'Idempotent: if the same preset already exists, returns the existing '
        'config. Optionally associates a vector schema.',
    inputSchema: _inputSchema,
    callback: (args, extra) => _handle(args, configRepo),
  );
}

CallToolResult _handle(
  Map<String, dynamic> args,
  ConfigRepository configRepo,
) {
  final name = args['name'] as String?;
  if (name == null || name.isEmpty) {
    return _errorResult('Missing required parameter: name');
  }

  final presetJson = args['preset_json'] as String?;
  if (presetJson == null || presetJson.isEmpty) {
    return _errorResult('Missing required parameter: preset_json');
  }

  final schemaId = args['schema_id'] as String?;

  try {
    final config = configRepo.register(
      name,
      presetJson,
      vectorSchemaId: schemaId,
    );

    return CallToolResult.fromStructuredContent({
      'id': config.id,
      'name': config.name,
      'preset': config.preset,
      if (config.vectorSchemaId != null)
        'vector_schema_id': config.vectorSchemaId,
      'created_at': config.createdAt.toIso8601String(),
    });
  } catch (e) {
    return _errorResult('Failed to create config: $e');
  }
}

CallToolResult _errorResult(String message) {
  return CallToolResult(
    content: [TextContent(text: message)],
    isError: true,
  );
}
