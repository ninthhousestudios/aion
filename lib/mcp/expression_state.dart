sealed class ExpressionState {
  const ExpressionState();
}

class ExpressionIdle extends ExpressionState {
  const ExpressionIdle();
}

class ExpressionLoading extends ExpressionState {
  final Map<String, dynamic> options;
  const ExpressionLoading(this.options);
}

class ExpressionReady extends ExpressionState {
  final Map<String, dynamic> data;
  final Map<String, dynamic> options;
  const ExpressionReady(this.data, this.options);
}

class ExpressionError extends ExpressionState {
  final Object error;
  final Map<String, dynamic> options;
  const ExpressionError(this.error, this.options);
}
