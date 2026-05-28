import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:rxdart/rxdart.dart';

import 'expression_ref.dart';
import 'expression_state.dart';
import 'plugin_host.dart';

class WorkspaceStore {
  final PluginHost _host;
  final _expressions = <ExpressionRef, BehaviorSubject<ExpressionState>>{};

  WorkspaceStore(this._host);

  BehaviorSubject<ExpressionState> _expressionOf(ExpressionRef ref) {
    return _expressions.putIfAbsent(
      ref,
      () => BehaviorSubject.seeded(const ExpressionIdle()),
    );
  }

  Stream<ExpressionState> watch(ExpressionRef ref) => _expressionOf(ref).stream;

  ExpressionState current(ExpressionRef ref) => _expressionOf(ref).value;

  Future<void> recalculate(
    ExpressionRef ref,
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
    final subject = _expressionOf(ref);
    subject.add(ExpressionLoading(args));
    try {
      final result = await _host.callTool(server, tool, args);
      if (result.isError) {
        final message = result.content
                .whereType<TextContent>()
                .firstOrNull
                ?.text ??
            'Unknown tool error';
        subject.add(ExpressionError(message, args));
        return;
      }
      final textContent = result.content.whereType<TextContent>().firstOrNull;
      if (textContent == null) {
        subject.add(ExpressionError('No TextContent in tool result', args));
        return;
      }
      final Map<String, dynamic> data;
      try {
        data = json.decode(textContent.text) as Map<String, dynamic>;
      } catch (_) {
        subject.add(ExpressionError(
          'Tool result is not valid JSON: ${textContent.text}',
          args,
        ));
        return;
      }
      subject.add(ExpressionReady(data, args));
    } catch (error) {
      subject.add(ExpressionError(error, args));
    }
  }

  List<ExpressionRef> get activeExpressions => _expressions.entries
      .where((e) => e.value.value is! ExpressionIdle)
      .map((e) => e.key)
      .toList();

  void dispose() {
    for (final subject in _expressions.values) {
      subject.close();
    }
  }
}
