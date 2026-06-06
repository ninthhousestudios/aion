import '../mcp/chart_store.dart';
import '../mcp/expression_ref.dart';
import '../mcp/expression_state.dart';
import 'load_chart_action.dart';

sealed class BindChartResult {
  const BindChartResult();
}

class ChartBound extends BindChartResult {
  final String chartName;
  final ExpressionRef expressionRef;
  final String rendererType;
  const ChartBound(this.chartName, this.expressionRef, this.rendererType);
}

class BindFailed extends BindChartResult {
  final String message;
  const BindFailed(this.message);
}

Future<BindChartResult> bindChartToCard(
  ChartStore store,
  LoadChartResult loadResult, {
  String server = 'drishti',
  String tool = 'calculate_chart',
  Map<String, dynamic> config = const {},
  String rendererType = 'south_indian',
}) async {
  switch (loadResult) {
    case ChartLoadedOk(:final chartId, :final doc):
      ExpressionRef exprRef;
      try {
        exprRef = await store.computeExpression(chartId, server, tool, config);
      } catch (e) {
        return BindFailed('$e');
      }
      final exprState = store.expressionState(exprRef);
      if (exprState is ExpressionError) {
        return BindFailed('${exprState.error}');
      }
      return ChartBound(
        doc.name.isEmpty ? 'Chart' : doc.name,
        exprRef,
        rendererType,
      );
    case ChartLoadFailed(:final message):
      return BindFailed(message);
    case ChartLoadCancelled():
      return const BindFailed('Load cancelled');
  }
}
