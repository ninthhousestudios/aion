@Tags(['integration'])
import 'dart:io';

import 'package:test/test.dart';

import 'package:aion/mcp/plugin_host.dart';
import 'package:aion/mcp/plugin_manifest.dart';

void main() {
  late PluginHost host;
  late PluginManifest manifest;

  setUpAll(() {
    final drishtiPath = Platform.environment['DRISHTI_PATH'] ?? '../arjuna';
    final dir = Directory(drishtiPath);
    if (!dir.existsSync()) {
      throw StateError(
        'Drishti workspace not found at $drishtiPath. '
        'Set DRISHTI_PATH environment variable.',
      );
    }
    manifest = PluginManifest(
      name: 'drishti',
      displayName: 'Drishti',
      description: 'Astrological calculation engine',
      transport: PluginTransport.stdio,
      command: 'dart',
      args: ['run', '--verbosity=error', 'drishti:drishti'],
      workingDirectory: drishtiPath,
      bundled: true,
      autoStart: true,
    );
  });

  setUp(() {
    host = PluginHost();
  });

  tearDown(() async {
    await host.dispose();
  });

  test('connect to Drishti and list tools', () async {
    await host.startPlugin(manifest);

    final state = host.pluginState('drishti');
    expect(state.status, equals(PluginStatus.connected));
    expect(state.tools.map((t) => t.name), contains('calculate_chart'));
  });

  test('call calculate_chart with known input', () async {
    await host.startPlugin(manifest);

    final result = await host.callTool('drishti', 'calculate_chart', {
      'date': '2000-01-01T12:00:00Z',
      'latitude': 28.6,
      'longitude': 77.2,
      'preset': 'ernst',
    });

    expect(result.isError, isFalse);

    final data = result.structuredContent;
    expect(data, isNotNull);
    expect(data, contains('planets'));
    expect(data, contains('summary'));
    expect(data, contains('houses'));
    expect(data!['planets'], isA<List>());
    expect((data['planets'] as List), isNotEmpty);
  });

  test('stop plugin and verify cleanup', () async {
    await host.startPlugin(manifest);
    expect(host.pluginState('drishti').status, PluginStatus.connected);

    await host.stopPlugin('drishti');
    expect(host.pluginState('drishti').status, PluginStatus.stopped);
  });
}
