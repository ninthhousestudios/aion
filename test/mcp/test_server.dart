import 'package:mcp_dart/mcp_dart.dart';

void main() async {
  final server = McpServer(
    const Implementation(name: 'test-server', version: '0.1.0'),
  );

  server.registerTool(
    'echo',
    description: 'Echoes input',
    inputSchema: JsonObject(
      properties: {
        'message': JsonString(),
      },
    ),
    callback: (args, extra) async {
      final msg = args['message'] ?? 'no message';
      return CallToolResult(content: [TextContent(text: msg.toString())]);
    },
  );

  final transport = StdioServerTransport();
  await server.connect(transport);
}
