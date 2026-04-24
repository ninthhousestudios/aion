import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(pluginHostProvider).startAll(BundledManifests.all);
      } catch (e, st) {
        debugPrint('Failed to start plugins: $e\n$st');
      }
    });
  }

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
    final (color, label) = switch (state.status) {
      PluginStatus.connected => (Colors.green, 'Connected'),
      PluginStatus.starting => (Colors.amber, 'Starting'),
      PluginStatus.error => (Colors.red, 'Error'),
      PluginStatus.stopped => (Colors.grey, 'Stopped'),
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
