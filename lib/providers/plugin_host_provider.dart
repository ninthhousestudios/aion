import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/plugin_host.dart';

final pluginHostProvider = Provider<PluginHost>((ref) {
  final host = PluginHost();
  ref.onDispose(() => host.dispose());
  return host;
});

final pluginStateProvider = StreamProvider.family<PluginState, String>(
  (ref, name) => ref.watch(pluginHostProvider).watchPlugin(name),
);
