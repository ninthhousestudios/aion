import 'dart:io';
import 'dart:convert';

enum PluginTransport { stdio, http }

class PluginManifest {
  final String name;
  final String displayName;
  final String description;
  final PluginTransport transport;
  final String? command;
  final List<String>? args;
  final Map<String, String>? env;
  final String? workingDirectory;
  final String? url;
  final bool bundled;
  final bool autoStart;

  const PluginManifest({
    required this.name,
    required this.displayName,
    required this.description,
    required this.transport,
    this.command,
    this.args,
    this.env,
    this.workingDirectory,
    this.url,
    this.bundled = false,
    this.autoStart = false,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final transportStr = json['transport'] as String;
    final transport = transportStr == 'http' ? PluginTransport.http : PluginTransport.stdio;

    List<String>? args;
    if (json['args'] != null) {
      args = (json['args'] as List).map((e) => PluginConfig._substituteVars(e as String)).toList();
    }

    Map<String, String>? env;
    if (json['env'] != null) {
      env = Map<String, String>.from(json['env'] as Map);
    }

    final rawCommand = json['command'] as String?;
    final rawWorkingDirectory = json['workingDirectory'] as String?;

    return PluginManifest(
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      transport: transport,
      command: rawCommand != null ? PluginConfig._substituteVars(rawCommand) : null,
      args: args,
      env: env,
      workingDirectory: rawWorkingDirectory != null ? PluginConfig._substituteVars(rawWorkingDirectory) : null,
      url: json['url'] as String?,
      bundled: json['bundled'] as bool? ?? false,
      autoStart: json['autoStart'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'description': description,
      'transport': transport == PluginTransport.http ? 'http' : 'stdio',
      if (command != null) 'command': command,
      if (args != null) 'args': args,
      if (env != null) 'env': env,
      if (workingDirectory != null) 'workingDirectory': workingDirectory,
      if (url != null) 'url': url,
      'bundled': bundled,
      'autoStart': autoStart,
    };
  }
}

class PluginConfig {
  static String configPath() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    final base = xdg ?? '${Platform.environment['HOME']}/.config';
    return '$base/aion';
  }

  static String _pluginsPath() => '${configPath()}/plugins.json';

  static String _substituteVars(String value) {
    final pluginsDir =
        Platform.environment['AION_PLUGINS'] ?? '${configPath()}/plugins';
    return value.replaceAll(r'${AION_PLUGINS}', pluginsDir);
  }

  static Future<List<PluginManifest>> loadUserPlugins() async {
    final file = File(_pluginsPath());
    if (!await file.exists()) {
      return [];
    }
    final contents = await file.readAsString();
    final jsonList = jsonDecode(contents) as List;
    return jsonList
        .map((e) => PluginManifest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveUserPlugins(List<PluginManifest> plugins) async {
    final file = File(_pluginsPath());
    await file.parent.create(recursive: true);
    final jsonList = plugins.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}

class BundledManifests {
  static final drishti = PluginManifest(
    name: 'drishti',
    displayName: 'Drishti',
    description: 'Astrological calculation engine',
    transport: PluginTransport.stdio,
    command: 'dart',
    args: ['run', '--verbosity=error', 'drishti:drishti'],
    workingDirectory:
        Platform.environment['DRISHTI_PATH'] ?? '../arjuna',
    env: {
      if (Platform.environment.containsKey('DRISHTI_EPHE_PATH'))
        'DRISHTI_EPHE_PATH': Platform.environment['DRISHTI_EPHE_PATH']!,
    },
    bundled: true,
    autoStart: true,
  );
}
