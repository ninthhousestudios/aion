import 'dart:io';

import 'package:test/test.dart';

import 'package:aion/mcp/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('testParseValidJson', () {
      final json = {
        'name': 'my-plugin',
        'displayName': 'My Plugin',
        'description': 'Does things',
        'transport': 'stdio',
        'command': 'dart',
        'args': ['run', 'my-plugin:server'],
        'env': {'FOO': 'bar'},
        'workingDirectory': '/some/path',
        'bundled': false,
        'autoStart': true,
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.name, equals('my-plugin'));
      expect(manifest.displayName, equals('My Plugin'));
      expect(manifest.description, equals('Does things'));
      expect(manifest.transport, equals(PluginTransport.stdio));
      expect(manifest.command, equals('dart'));
      expect(manifest.args, equals(['run', 'my-plugin:server']));
      expect(manifest.env, equals({'FOO': 'bar'}));
      expect(manifest.workingDirectory, equals('/some/path'));
      expect(manifest.bundled, isFalse);
      expect(manifest.autoStart, isTrue);

      final roundtripped = PluginManifest.fromJson(manifest.toJson());

      expect(roundtripped.name, equals(manifest.name));
      expect(roundtripped.displayName, equals(manifest.displayName));
      expect(roundtripped.description, equals(manifest.description));
      expect(roundtripped.transport, equals(manifest.transport));
      expect(roundtripped.command, equals(manifest.command));
      expect(roundtripped.args, equals(manifest.args));
      expect(roundtripped.env, equals(manifest.env));
      expect(roundtripped.workingDirectory, equals(manifest.workingDirectory));
      expect(roundtripped.bundled, equals(manifest.bundled));
      expect(roundtripped.autoStart, equals(manifest.autoStart));
    });

    test('testParseHttpTransport', () {
      final json = {
        'name': 'remote-plugin',
        'displayName': 'Remote Plugin',
        'description': 'HTTP-based plugin',
        'transport': 'http',
        'url': 'http://localhost:8080',
        'bundled': false,
        'autoStart': false,
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.transport, equals(PluginTransport.http));
      expect(manifest.url, equals('http://localhost:8080'));
      expect(manifest.command, isNull);
      expect(manifest.args, isNull);
    });

    test('testVariableSubstitution', () {
      final originalPlugins = Platform.environment['AION_PLUGINS'];

      final json = {
        'name': 'subst-plugin',
        'displayName': 'Substitution Plugin',
        'description': 'Tests variable substitution',
        'transport': 'stdio',
        'command': r'${AION_PLUGINS}/bin/server',
        'args': [r'--data', r'${AION_PLUGINS}/data'],
        'workingDirectory': r'${AION_PLUGINS}/work',
        'bundled': false,
        'autoStart': false,
      };

      final manifest = PluginManifest.fromJson(json);

      final expectedBase = originalPlugins ??
          '${Platform.environment['HOME']}/.config/aion/plugins';

      expect(manifest.command, equals('$expectedBase/bin/server'));
      expect(manifest.args, equals(['--data', '$expectedBase/data']));
      expect(manifest.workingDirectory, equals('$expectedBase/work'));
    });

    test('testBundledManifestConstants', () {
      final drishti = BundledManifests.drishti;

      expect(drishti.command, equals('dart'));
      expect(drishti.args, equals(['run', '--verbosity=error', 'drishti:drishti']));
      expect(drishti.workingDirectory, isNotNull);
      expect(drishti.bundled, isTrue);
      expect(drishti.autoStart, isTrue);
      expect(drishti.transport, equals(PluginTransport.stdio));
    });
  });
}
