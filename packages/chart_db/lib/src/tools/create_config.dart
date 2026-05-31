import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'tool_helpers.dart';

final _inputSchema = JsonObject(
  properties: {
    'name': JsonString(
      description:
          'Human-readable name for the config (e.g. "tropical-western")',
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

void registerCreateConfig(McpServer server, ConfigRepository configRepo) {
  server.registerTool(
    'create_config',
    description: 'Register a calculation config with a name and preset JSON. '
        'Idempotent: if the same preset already exists, returns the existing '
        'config. Optionally associates a vector schema.',
    inputSchema: _inputSchema,
    callback: (args, extra) => handleCreateConfig(args, configRepo),
  );
}

CallToolResult handleCreateConfig(
  Map<String, dynamic> args,
  ConfigRepository configRepo,
) {
  final name = args['name'];
  if (name is! String || name.isEmpty) {
    return errorResult('Missing required parameter: name');
  }

  final presetJson = args['preset_json'];
  if (presetJson is! String || presetJson.isEmpty) {
    return errorResult('Missing required parameter: preset_json');
  }

  final schemaId = args['schema_id'];
  if (schemaId != null && schemaId is! String) {
    return errorResult('Invalid parameter: schema_id (expected string)');
  }

  try {
    final config = configRepo.register(
      name,
      presetJson,
      vectorSchemaId: schemaId as String?,
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
    return errorResult('Failed to create config: $e');
  }
}
