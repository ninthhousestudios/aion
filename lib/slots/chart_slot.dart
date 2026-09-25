import 'dart:convert';

/// Expression config: the tool arguments that, together with a chart,
/// determine an Expression. Values must be JSON-encodable.
typedef ExpressionConfig = Map<String, Object>;

/// Normalizes [config] so equal configs encode identically: keys sorted
/// recursively, sets turned into sorted lists.
Map<String, Object> canonicalConfig(Map<String, Object> config) {
  Object canon(Object value) => switch (value) {
    Map<String, Object> m => canonicalConfig(m),
    Set<String> s => (s.toList()..sort()),
    List<Object> l => [for (final e in l) canon(e)],
    _ => value,
  };
  final keys = config.keys.toList()..sort();
  return {for (final k in keys) k: canon(config[k] ?? '')};
}

String canonicalConfigJson(Map<String, Object> config) =>
    jsonEncode(canonicalConfig(config));

/// A chart slot: a named, colored link group that cards bind to.
///
/// Slots are app-session state, not workspace state — switching workspaces
/// keeps the charts loaded in them. The color is an index into the theme's
/// slot palette (`AionTheme.slotPalette`), so slot colors follow the theme.
class ChartSlot {
  const ChartSlot({
    required this.id,
    required this.label,
    required this.colorIndex,
    this.chartId,
    this.chartName,
    this.config = const {},
  });

  final String id;
  final String label;
  final int colorIndex;

  /// Store id of the chart loaded into this slot; null when empty.
  final String? chartId;

  /// Display name of the loaded chart, for labels. Null when empty.
  final String? chartName;

  final ExpressionConfig config;

  bool get isEmpty => chartId == null;

  static const Object _unset = Object();

  ChartSlot copyWith({
    String? label,
    int? colorIndex,
    Object? chartId = _unset,
    Object? chartName = _unset,
    ExpressionConfig? config,
  }) {
    return ChartSlot(
      id: id,
      label: label ?? this.label,
      colorIndex: colorIndex ?? this.colorIndex,
      chartId: identical(chartId, _unset) ? this.chartId : chartId as String?,
      chartName: identical(chartName, _unset)
          ? this.chartName
          : chartName as String?,
      config: config ?? this.config,
    );
  }
}

/// Menu/list label for a slot: "Slot A · Client — Ravi".
String slotMenuLabel(ChartSlot slot) {
  final name = slot.label == slot.id
      ? 'Slot ${slot.id}'
      : 'Slot ${slot.id} · ${slot.label}';
  final chart = slot.chartName;
  return chart == null ? name : '$name — $chart';
}
