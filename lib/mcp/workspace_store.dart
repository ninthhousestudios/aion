import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:rxdart/rxdart.dart';

import 'plugin_host.dart';
import 'slot_state.dart';

class WorkspaceStore {
  final PluginHost _host;
  final _slots = <String, BehaviorSubject<SlotState>>{};

  WorkspaceStore(this._host);

  BehaviorSubject<SlotState> _slotOf(String name) {
    return _slots.putIfAbsent(name, () => BehaviorSubject.seeded(const SlotIdle()));
  }

  Stream<SlotState> watch(String name) => _slotOf(name).stream;

  SlotState current(String name) => _slotOf(name).value;

  Future<void> recalculate(
    String slot,
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
    final subject = _slotOf(slot);
    subject.add(SlotLoading(args));
    try {
      final result = await _host.callTool(server, tool, args);
      if (result.isError) {
        final message = result.content
                .whereType<TextContent>()
                .firstOrNull
                ?.text ??
            'Unknown tool error';
        subject.add(SlotError(message, args));
        return;
      }
      final textContent = result.content.whereType<TextContent>().firstOrNull;
      if (textContent == null) {
        subject.add(SlotError('No TextContent in tool result', args));
        return;
      }
      final Map<String, dynamic> data;
      try {
        data = json.decode(textContent.text) as Map<String, dynamic>;
      } catch (_) {
        subject.add(SlotError('Tool result is not valid JSON: ${textContent.text}', args));
        return;
      }
      subject.add(SlotReady(data, args));
    } catch (error) {
      subject.add(SlotError(error, args));
    }
  }

  List<String> get activeSlots => _slots.entries
      .where((e) => e.value.value is! SlotIdle)
      .map((e) => e.key)
      .toList();

  void dispose() {
    for (final subject in _slots.values) {
      subject.close();
    }
  }
}
