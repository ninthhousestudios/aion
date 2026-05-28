import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import 'package:aion/mcp/expression_ref.dart';
import 'package:aion/mcp/expression_state.dart';
import 'package:aion/mcp/plugin_host.dart';
import 'package:aion/mcp/workspace_store.dart';

class MockPluginHost extends PluginHost {
  CallToolResult? nextResult;
  Object? nextError;

  @override
  Future<CallToolResult> callTool(
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
    if (nextError != null) throw nextError!;
    return nextResult!;
  }
}

const _natal = ExpressionRef(chartId: 'chart-1', configHash: 'lahiri');
const _transit = ExpressionRef(chartId: 'chart-2', configHash: 'lahiri');

void main() {
  late MockPluginHost host;
  late WorkspaceStore store;

  setUp(() {
    host = MockPluginHost();
    store = WorkspaceStore(host);
  });

  tearDown(() {
    store.dispose();
  });

  test('expression lifecycle: idle → loading → ready', () async {
    final states = <ExpressionState>[];
    final sub = store.watch(_natal).listen(states.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"sun": "aries"}')],
    );

    await store.recalculate(_natal, 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<ExpressionIdle>());
    expect(states.any((s) => s is ExpressionLoading), isTrue);
    expect(states.last, isA<ExpressionReady>());
    final ready = states.last as ExpressionReady;
    expect(ready.data, equals({'sun': 'aries'}));
    expect(ready.options, equals({'date': '2000-01-01'}));
  });

  test('expression error on exception', () async {
    final states = <ExpressionState>[];
    final sub = store.watch(_natal).listen(states.add);

    host.nextError = Exception('server unreachable');

    await store.recalculate(_natal, 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<ExpressionIdle>());
    expect(states.last, isA<ExpressionError>());
    final error = states.last as ExpressionError;
    expect(error.options, equals({'date': '2000-01-01'}));
  });

  test('expression error on invalid JSON', () async {
    final states = <ExpressionState>[];
    final sub = store.watch(_natal).listen(states.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: 'not valid json {{')],
    );

    await store.recalculate(_natal, 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<ExpressionIdle>());
    expect(states.last, isA<ExpressionError>());
  });

  test('independent expressions do not interfere', () async {
    final natalStates = <ExpressionState>[];
    final transitStates = <ExpressionState>[];

    final sub1 = store.watch(_natal).listen(natalStates.add);
    final sub2 = store.watch(_transit).listen(transitStates.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"slot": "natal"}')],
    );
    await store.recalculate(_natal, 'drishti', 'calculate_chart', {'id': 'natal'});

    host.nextError = Exception('transit error');
    await store.recalculate(_transit, 'drishti', 'calculate_chart', {'id': 'transit'});

    await sub1.cancel();
    await sub2.cancel();

    expect(natalStates.last, isA<ExpressionReady>());
    expect(transitStates.last, isA<ExpressionError>());
  });

  test('current returns latest state', () async {
    expect(store.current(_natal), isA<ExpressionIdle>());

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"result": true}')],
    );
    await store.recalculate(_natal, 'drishti', 'calculate_chart', {});

    expect(store.current(_natal), isA<ExpressionReady>());
  });

  test('activeExpressions tracks non-idle refs', () async {
    expect(store.activeExpressions, isEmpty);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"ok": true}')],
    );
    await store.recalculate(_natal, 'drishti', 'calculate_chart', {});

    expect(store.activeExpressions, contains(_natal));
    expect(store.activeExpressions, hasLength(1));

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"ok": true}')],
    );
    await store.recalculate(_transit, 'drishti', 'calculate_chart', {});

    expect(store.activeExpressions, containsAll([_natal, _transit]));
    expect(store.activeExpressions, hasLength(2));
  });
}
