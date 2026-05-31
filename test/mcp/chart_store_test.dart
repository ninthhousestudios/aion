import 'dart:convert';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import 'package:aion/mcp/chart_state.dart';
import 'package:aion/mcp/chart_store.dart';
import 'package:aion/mcp/expression_state.dart';
import 'package:aion/mcp/plugin_host.dart';

class MockPluginHost extends PluginHost {
  CallToolResult? nextResult;
  Object? nextError;
  int callCount = 0;

  @override
  Future<CallToolResult> callTool(
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
    callCount++;
    if (nextError != null) throw nextError!;
    return nextResult!;
  }
}

const _testDoc = ChartDoc(
  jd: 2451545.0,
  lat: 28.6,
  lon: 77.2,
  name: 'Test Chart',
);

const _config = {'preset': 'lahiri'};
const _configAlt = {'preset': 'ernst'};

CallToolResult _jsonResult(Map<String, dynamic> data) =>
    CallToolResult(content: [TextContent(text: json.encode(data))]);

void main() {
  late MockPluginHost host;
  late ChartStore store;

  setUp(() {
    host = MockPluginHost();
    store = ChartStore(host);
  });

  tearDown(() {
    store.dispose();
  });

  test('loadChart sets ChartLoaded state', () {
    store.loadChart('chart-1', _testDoc);

    final state = store.chartState('chart-1');
    expect(state, isA<ChartLoaded>());
    final loaded = state as ChartLoaded;
    expect(loaded.id, 'chart-1');
    expect(loaded.doc, _testDoc);
    expect(store.loadedChartIds, ['chart-1']);
  });

  test('computeExpression lifecycle: idle → loading → ready', () async {
    store.loadChart('chart-1', _testDoc);

    host.nextResult = _jsonResult({'sun': 'aries'});

    final states = <ExpressionState>[];
    final ref = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );
    final sub = store.watchExpression(ref).listen(states.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final current = store.expressionState(ref);
    expect(current, isA<ExpressionReady>());
    final ready = current as ExpressionReady;
    expect(ready.data, {'sun': 'aries'});
    expect(host.callCount, 1);
  });

  test('same (chartId, config) returns cached expression', () async {
    store.loadChart('chart-1', _testDoc);

    host.nextResult = _jsonResult({'sun': 'aries'});

    final ref1 = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );
    final ref2 = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );

    expect(ref1, equals(ref2));
    expect(host.callCount, 1);
  });

  test('different config produces separate expression', () async {
    store.loadChart('chart-1', _testDoc);

    host.nextResult = _jsonResult({'sun': 'aries'});
    final ref1 = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );

    host.nextResult = _jsonResult({'sun': 'pisces'});
    final ref2 = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _configAlt,
    );

    expect(ref1, isNot(equals(ref2)));
    expect(host.callCount, 2);
    expect(
      (store.expressionState(ref1) as ExpressionReady).data,
      {'sun': 'aries'},
    );
    expect(
      (store.expressionState(ref2) as ExpressionReady).data,
      {'sun': 'pisces'},
    );
  });

  test('unloadChart removes chart and all its expressions', () async {
    store.loadChart('chart-1', _testDoc);
    host.nextResult = _jsonResult({'sun': 'aries'});
    final ref = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );

    expect(store.expressionsForChart('chart-1'), [ref]);

    store.unloadChart('chart-1');

    expect(store.loadedChartIds, isEmpty);
    expect(store.expressionsForChart('chart-1'), isEmpty);
    expect(store.chartState('chart-1'), isA<ChartLoading>());
  });

  test('error propagation from plugin', () async {
    store.loadChart('chart-1', _testDoc);
    host.nextError = Exception('server unreachable');

    final ref = await store.computeExpression(
      'chart-1', 'drishti', 'calculate_chart', _config,
    );

    expect(store.expressionState(ref), isA<ExpressionError>());
  });

  test('concurrent chart loads and computations', () async {
    store.loadChart('chart-1', _testDoc);
    store.loadChart('chart-2', const ChartDoc(
      jd: 2448058.833,
      lat: 40.7,
      lon: -74.0,
      name: 'Chart 2',
    ));

    host.nextResult = _jsonResult({'result': 'ok'});

    final results = await Future.wait([
      store.computeExpression('chart-1', 'drishti', 'calculate_chart', _config),
      store.computeExpression('chart-2', 'drishti', 'calculate_chart', _config),
    ]);

    expect(results[0].chartId, 'chart-1');
    expect(results[1].chartId, 'chart-2');
    expect(store.expressionState(results[0]), isA<ExpressionReady>());
    expect(store.expressionState(results[1]), isA<ExpressionReady>());
    expect(host.callCount, 2);
  });

  test('computeExpression on unloaded chart throws', () {
    expect(
      () => store.computeExpression(
        'no-such-chart', 'drishti', 'calculate_chart', _config,
      ),
      throwsStateError,
    );
  });

  test('loadChart is idempotent', () {
    store.loadChart('chart-1', _testDoc);
    store.loadChart('chart-1', const ChartDoc(
      jd: 0.0, lat: 0.0, lon: 0.0, name: 'Different',
    ));

    final loaded = store.chartState('chart-1') as ChartLoaded;
    expect(loaded.doc, _testDoc);
  });
}
