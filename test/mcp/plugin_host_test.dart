import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import 'package:aion/mcp/plugin_host.dart';
import 'package:aion/mcp/plugin_manifest.dart';

final _testManifest = PluginManifest(
  name: 'test-server',
  displayName: 'Test Server',
  description: 'Test MCP server',
  transport: PluginTransport.stdio,
  command: 'dart',
  args: ['run', 'test/mcp/test_server.dart'],
  workingDirectory: '.',
);

void main() {
  group('PluginHost', () {
    late PluginHost host;

    setUp(() {
      host = PluginHost();
    });

    tearDown(() async {
      await host.dispose();
    });

    test('testStartAndConnect', () async {
      await host.startPlugin(_testManifest);

      final state = host.pluginState('test-server');
      expect(state.status, equals(PluginStatus.connected));
      expect(state.tools.map((t) => t.name), contains('echo'));
    });

    test('testCallTool', () async {
      await host.startPlugin(_testManifest);

      final result = await host.callTool(
        'test-server',
        'echo',
        {'message': 'hello world'},
      );

      final texts = result.content
          .whereType<TextContent>()
          .map((c) => c.text)
          .toList();
      expect(texts, anyElement(contains('hello world')));
    });

    test('testStopPlugin', () async {
      await host.startPlugin(_testManifest);
      await host.stopPlugin('test-server');

      final state = host.pluginState('test-server');
      expect(state.status, equals(PluginStatus.stopped));
    });

    test('testStartNonexistentCommand', () async {
      final badManifest = PluginManifest(
        name: 'bad-server',
        displayName: 'Bad Server',
        description: 'Server with nonexistent command',
        transport: PluginTransport.stdio,
        command: 'nonexistent_command_xyz_12345',
        args: [],
        workingDirectory: '.',
      );

      await host.startPlugin(badManifest);

      final state = host.pluginState('bad-server');
      expect(state.status, equals(PluginStatus.error));
      expect(state.error, isNotNull);
    });

    test('testPluginStateStream', () async {
      final states = <PluginStatus>[];
      final subscription = host
          .watchPlugin('test-server')
          .map((s) => s.status)
          .listen(states.add);

      await host.startPlugin(_testManifest);
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();

      expect(states, containsAllInOrder([
        PluginStatus.stopped,
        PluginStatus.starting,
        PluginStatus.connected,
      ]));
    });
  });
}
