import 'package:chart_model/chart_model.dart';

sealed class ExpressionState {
  const ExpressionState();
}

class ExpressionIdle extends ExpressionState {
  const ExpressionIdle();
}

class ExpressionLoading extends ExpressionState {
  final Map<String, dynamic> args;
  const ExpressionLoading(this.args);
}

class ExpressionReady extends ExpressionState {
  final ChartExpression data;
  final Map<String, dynamic> args;
  const ExpressionReady(this.data, this.args);
}

class ExpressionError extends ExpressionState {
  final Object error;
  final Map<String, dynamic> args;
  const ExpressionError(this.error, this.args);
}
