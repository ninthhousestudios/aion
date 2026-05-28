class ExpressionRef {
  final String chartId;
  final String configHash;

  const ExpressionRef({required this.chartId, required this.configHash});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpressionRef &&
          chartId == other.chartId &&
          configHash == other.configHash;

  @override
  int get hashCode => Object.hash(chartId, configHash);

  @override
  String toString() => 'ExpressionRef($chartId, $configHash)';
}
