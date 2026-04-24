import 'dart:async';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:rxdart/rxdart.dart';

import 'plugin_manifest.dart';

enum PluginStatus { stopped, starting, connected, error }

class PluginState {
  final PluginStatus status;
  final Object? error;
  final List<Tool> tools;

  const PluginState({
    required this.status,
    this.error,
    this.tools = const [],
  });

  const PluginState.stopped()
      : status = PluginStatus.stopped,
        error = null,
        tools = const [];

  const PluginState.starting()
      : status = PluginStatus.starting,
        error = null,
        tools = const [];

  PluginState.connected(List<Tool> tools)
      : status = PluginStatus.connected,
        error = null,
        tools = List.unmodifiable(tools);

  PluginState.error(this.error)
      : status = PluginStatus.error,
        tools = const [];
}

class PluginNotConnected implements Exception {
  final String serverName;
  const PluginNotConnected(this.serverName);

  @override
  String toString() => 'PluginNotConnected: $serverName';
}

class PluginHost {
  static const _connectTimeout = Duration(seconds: 30);

  final _clients = <String, McpClient>{};
  final _states = <String, BehaviorSubject<PluginState>>{};
  bool _disposed = false;

  BehaviorSubject<PluginState> _stateOf(String name) {
    return _states.putIfAbsent(
      name,
      () => BehaviorSubject<PluginState>.seeded(const PluginState.stopped()),
    );
  }

  Stream<PluginState> watchPlugin(String name) => _stateOf(name).stream;

  PluginState pluginState(String name) => _stateOf(name).value;

  Future<void> startPlugin(PluginManifest manifest) async {
    _stateOf(manifest.name).add(const PluginState.starting());
    McpClient? client;
    try {
      final transport = _buildTransport(manifest);
      client = McpClient(
        const Implementation(name: 'aion', version: '0.1.0'),
      );
      await client.connect(transport).timeout(_connectTimeout);
      final result = await client.listTools();
      _clients[manifest.name] = client;
      client.onclose = () => _onUnexpectedClose(manifest.name);
      _stateOf(manifest.name).add(PluginState.connected(result.tools));
    } catch (e) {
      await client?.close();
      _clients.remove(manifest.name);
      _stateOf(manifest.name).add(PluginState.error(e));
    }
  }

  void _onUnexpectedClose(String name) {
    if (_disposed || !_clients.containsKey(name)) return;
    _clients.remove(name);
    _stateOf(name).add(
      PluginState.error('Plugin process exited unexpectedly'),
    );
  }

  Transport _buildTransport(PluginManifest manifest) {
    switch (manifest.transport) {
      case PluginTransport.stdio:
        final params = StdioServerParameters(
          command: manifest.command!,
          args: manifest.args ?? [],
          workingDirectory: manifest.workingDirectory,
          environment: manifest.env,
          stderrMode: ProcessStartMode.normal,
        );
        return StdioClientTransport(params);
      case PluginTransport.http:
        return StreamableHttpClientTransport(Uri.parse(manifest.url!));
    }
  }

  Future<CallToolResult> callTool(
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
    final client = _clients[server];
    if (client == null) {
      throw PluginNotConnected(server);
    }
    return client.callTool(CallToolRequest(name: tool, arguments: args));
  }

  Future<void> stopPlugin(String name) async {
    final client = _clients.remove(name);
    await client?.close();
    final subject = _states.remove(name);
    subject?.add(const PluginState.stopped());
    subject?.close();
  }

  Future<void> startAll(List<PluginManifest> manifests) async {
    await Future.wait(
      manifests
          .where((m) => m.autoStart)
          .map((m) async {
            try {
              await startPlugin(m);
            } catch (e) {
              // startPlugin already sets error state on the stream;
              // log here so failures aren't completely invisible.
              Zone.current.handleUncaughtError(e, StackTrace.current);
            }
          }),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final names = List<String>.from(_clients.keys);
    await Future.wait(names.map(stopPlugin));
    for (final subject in _states.values) {
      subject.close();
    }
    _states.clear();
    _clients.clear();
  }

  List<String> get connectedPlugins => _states.entries
      .where((e) => e.value.value.status == PluginStatus.connected)
      .map((e) => e.key)
      .toList();
}
