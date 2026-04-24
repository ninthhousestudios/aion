import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import 'package:aion/mcp/plugin_host.dart';
import 'package:aion/mcp/slot_state.dart';
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

  test('testSlotLifecycle', () async {
    final states = <SlotState>[];
    final sub = store.watch('natal').listen(states.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"sun": "aries"}')],
    );

    await store.recalculate('natal', 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<SlotIdle>());
    expect(states.any((s) => s is SlotLoading), isTrue);
    expect(states.last, isA<SlotReady>());
    final ready = states.last as SlotReady;
    expect(ready.data, equals({'sun': 'aries'}));
    expect(ready.options, equals({'date': '2000-01-01'}));
  });

  test('testSlotError', () async {
    final states = <SlotState>[];
    final sub = store.watch('natal').listen(states.add);

    host.nextError = Exception('server unreachable');

    await store.recalculate('natal', 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<SlotIdle>());
    expect(states.last, isA<SlotError>());
    final error = states.last as SlotError;
    expect(error.options, equals({'date': '2000-01-01'}));
  });

  test('testSlotErrorOnInvalidJson', () async {
    final states = <SlotState>[];
    final sub = store.watch('natal').listen(states.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: 'not valid json {{')],
    );

    await store.recalculate('natal', 'drishti', 'calculate_chart', {'date': '2000-01-01'});
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();

    expect(states, hasLength(greaterThanOrEqualTo(3)));
    expect(states.first, isA<SlotIdle>());
    expect(states.last, isA<SlotError>());
  });

  test('testIndependentSlots', () async {
    final natalStates = <SlotState>[];
    final transitStates = <SlotState>[];

    final sub1 = store.watch('natal').listen(natalStates.add);
    final sub2 = store.watch('transit').listen(transitStates.add);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"slot": "natal"}')],
    );
    await store.recalculate('natal', 'drishti', 'calculate_chart', {'id': 'natal'});

    host.nextError = Exception('transit error');
    await store.recalculate('transit', 'drishti', 'calculate_chart', {'id': 'transit'});

    await sub1.cancel();
    await sub2.cancel();

    expect(natalStates.last, isA<SlotReady>());
    expect(transitStates.last, isA<SlotError>());
  });

  test('testCurrentState', () async {
    expect(store.current('natal'), isA<SlotIdle>());

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"result": true}')],
    );
    await store.recalculate('natal', 'drishti', 'calculate_chart', {});

    expect(store.current('natal'), isA<SlotReady>());
  });

  test('testActiveSlots', () async {
    expect(store.activeSlots, isEmpty);

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"ok": true}')],
    );
    await store.recalculate('natal', 'drishti', 'calculate_chart', {});

    expect(store.activeSlots, contains('natal'));
    expect(store.activeSlots, hasLength(1));

    host.nextResult = CallToolResult(
      content: [TextContent(text: '{"ok": true}')],
    );
    await store.recalculate('transit', 'drishti', 'calculate_chart', {});

    expect(store.activeSlots, containsAll(['natal', 'transit']));
    expect(store.activeSlots, hasLength(2));
  });
}
