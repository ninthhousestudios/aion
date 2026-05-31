import 'dart:collection';
import 'dart:convert';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:rxdart/rxdart.dart';

import 'chart_state.dart';
import 'expression_ref.dart';
import 'expression_state.dart';
import 'plugin_host.dart';

class ChartStore {
  final PluginHost _host;
  final _charts = <String, BehaviorSubject<ChartState>>{};
  final _expressions = <ExpressionRef, BehaviorSubject<ExpressionState>>{};
  final _inFlight = <ExpressionRef, Future<void>>{};

  ChartStore(this._host);

  void loadChart(String chartId, ChartDoc doc) {
    if (_charts.containsKey(chartId)) return;
    _charts[chartId] = BehaviorSubject.seeded(
      ChartLoaded(id: chartId, doc: doc),
    );
  }

  void unloadChart(String chartId) {
    _charts.remove(chartId)?.close();
    final refs = _expressions.keys
        .where((ref) => ref.chartId == chartId)
        .toList();
    for (final ref in refs) {
      _expressions.remove(ref)?.close();
      _inFlight.remove(ref);
    }
  }

  Future<ExpressionRef> computeExpression(
    String chartId,
    String server,
    String tool,
    Map<String, dynamic> config,
  ) async {
    final chart = _charts[chartId]?.value;
    if (chart is! ChartLoaded) {
      throw StateError('Chart $chartId is not loaded');
    }

    final configHash = _hashConfig(config);
    final ref = ExpressionRef(chartId: chartId, configHash: configHash);
    final subject = _expressionOf(ref);

    if (subject.value is ExpressionReady) return ref;

    final existing = _inFlight[ref];
    if (existing != null) {
      await existing;
      return ref;
    }

    final args = <String, dynamic>{
      'jd': chart.doc.jd,
      'lat': chart.doc.lat,
      'lon': chart.doc.lon,
      if (chart.doc.alt != 0) 'altitude': chart.doc.alt,
      ...config,
    };
    final future = _compute(subject, server, tool, args);
    _inFlight[ref] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(ref);
    }
    return ref;
  }

  Stream<ChartState> watchChart(String chartId) =>
      _chartOf(chartId).stream;

  ChartState chartState(String chartId) =>
      _chartOf(chartId).value;

  Stream<ExpressionState> watchExpression(ExpressionRef ref) =>
      _expressionOf(ref).stream;

  ExpressionState expressionState(ExpressionRef ref) =>
      _expressionOf(ref).value;

  List<String> get loadedChartIds => _charts.keys.toList();

  List<ExpressionRef> expressionsForChart(String chartId) =>
      _expressions.keys
          .where((ref) => ref.chartId == chartId)
          .toList();

  void dispose() {
    for (final s in _charts.values) {
      s.close();
    }
    for (final s in _expressions.values) {
      s.close();
    }
    _charts.clear();
    _expressions.clear();
    _inFlight.clear();
  }

  Future<void> _compute(
    BehaviorSubject<ExpressionState> subject,
    String server,
    String tool,
    Map<String, dynamic> args,
  ) async {
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
      final textContent =
          result.content.whereType<TextContent>().firstOrNull;
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

  BehaviorSubject<ChartState> _chartOf(String chartId) =>
      _charts.putIfAbsent(
        chartId,
        () => BehaviorSubject.seeded(const ChartLoading()),
      );

  BehaviorSubject<ExpressionState> _expressionOf(ExpressionRef ref) =>
      _expressions.putIfAbsent(
        ref,
        () => BehaviorSubject.seeded(const ExpressionIdle()),
      );

  static String _hashConfig(Map<String, dynamic> config) =>
      json.encode(_sortedValue(config));

  static Object? _sortedValue(Object? value) {
    if (value is Map<String, dynamic>) {
      final sorted = SplayTreeMap<String, dynamic>();
      for (final key in value.keys) {
        sorted[key] = _sortedValue(value[key]);
      }
      return sorted;
    }
    if (value is List) return value.map(_sortedValue).toList();
    return value;
  }
}
