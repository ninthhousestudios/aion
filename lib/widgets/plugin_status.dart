import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/aion_theme.dart';

import '../mcp/plugin_host.dart';
import '../mcp/plugin_manifest.dart';
import '../providers/plugin_host_provider.dart';


class PluginStatusPage extends ConsumerStatefulWidget {
  const PluginStatusPage({super.key});

  @override
  ConsumerState<PluginStatusPage> createState() => _PluginStatusPageState();
}

class _PluginStatusPageState extends ConsumerState<PluginStatusPage> {
  final _expanded = <String>{};


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aion — Plugins')),
      body: ListView(
        children: BundledManifests.all.map(_buildPluginTile).toList(),
      ),
    );
  }

  Widget _buildPluginTile(PluginManifest manifest) {
    final state = ref.watch(pluginStateProvider(manifest.name));
    final isExpanded = _expanded.contains(manifest.name);

    return state.when(
      data: (pluginState) => _tile(manifest, pluginState, isExpanded),
      loading: () => _tile(manifest, const PluginState.starting(), isExpanded),
      error: (e, _) => _tile(manifest, PluginState.error(e), isExpanded),
    );
  }

  Widget _tile(PluginManifest manifest, PluginState state, bool isExpanded) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final (color, label) = switch (state.status) {
      PluginStatus.connected => (t.statusConnected, 'Connected'),
      PluginStatus.starting => (t.statusStarting, 'Starting'),
      PluginStatus.error => (t.statusError, 'Error'),
      PluginStatus.stopped => (t.statusStopped, 'Stopped'),
    };

    final toolCount = state.tools.length;
    final subtitle = switch (state.status) {
      PluginStatus.connected => '$toolCount tool${toolCount == 1 ? '' : 's'}',
      PluginStatus.error => state.error.toString(),
      _ => label,
    };

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.circle, color: color, size: 12),
          title: Text(manifest.displayName),
          subtitle: Text(subtitle),
          trailing: state.tools.isNotEmpty
              ? Icon(isExpanded ? Icons.expand_less : Icons.expand_more)
              : null,
          onTap: state.tools.isNotEmpty
              ? () => setState(() {
                    isExpanded
                        ? _expanded.remove(manifest.name)
                        : _expanded.add(manifest.name);
                  })
              : null,
        ),
        if (isExpanded)
          ...state.tools.map(
            (tool) => ListTile(
              contentPadding: const EdgeInsets.only(left: 56),
              dense: true,
              title: Text(tool.name),
              subtitle:
                  tool.description != null ? Text(tool.description!) : null,
            ),
          ),
      ],
    );
  }
}
