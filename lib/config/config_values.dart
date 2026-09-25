import 'arrow_dimensions.dart';
import 'config_dimension.dart';

/// Pure helpers for reading and editing an expression config map through
/// the [ConfigDimension] model. Configs only store non-default values, so
/// an untouched config is `{}` and hashes the same as "drishti defaults".

/// Current value of [d] in [config], or its default. Multi-select values
/// are stored as JSON lists and returned as sets.
Object configValue(Map<String, Object> config, ConfigDimension d) {
  final raw = config[d.key];
  if (raw == null) return d.defaultValue;
  if (d.type == ConfigDimensionType.multiSelect && raw is List) {
    return {for (final v in raw) '$v'};
  }
  return raw;
}

bool _sameValue(Object a, Object b) {
  if (a is Set<String> && b is Set<String>) {
    return a.length == b.length && a.containsAll(b);
  }
  return a == b;
}

/// [config] with [d] set to [value]. Setting a dimension back to its
/// default removes the key. Sets are stored as sorted lists (JSON-safe).
Map<String, Object> setConfigValue(
  Map<String, Object> config,
  ConfigDimension d,
  Object value,
) {
  final next = Map<String, Object>.of(config)..remove(d.key);
  if (_sameValue(value, d.defaultValue)) return next;
  next[d.key] = value is Set<String> ? (value.toList()..sort()) : value;
  return next;
}

/// Short human-readable value for a collapsed section summary.
String formatConfigValue(ConfigDimension d, Object value) {
  String label(String v) =>
      d.choices?.where((c) => c.value == v).firstOrNull?.label ?? v;
  return switch (value) {
    bool b => b ? 'On' : 'Off',
    Set<String> s when s.isEmpty => 'None',
    Set<String> s when s.length <= 3 => (s.map(label).toList()..sort()).join(
      ', ',
    ),
    Set<String> s => '${s.length} selected',
    String v => label(v),
    _ => '$value',
  };
}

/// Which pipeline stage a section's settings affect. Expensive dimensions
/// change the ephemeris computation (SweConfig); cheap ones only change
/// derived calculation (CalcConfig).
enum ConfigStage { swe, calc, mixed }

ConfigStage sectionStage(List<ConfigDimension> dims) {
  final costs = {for (final d in dims) d.cost};
  if (costs.length > 1) return ConfigStage.mixed;
  return costs.contains(ConfigCost.cheap) ? ConfigStage.calc : ConfigStage.swe;
}

String stageLabel(ConfigStage stage) => switch (stage) {
  ConfigStage.swe => 'SweConfig',
  ConfigStage.calc => 'CalcConfig',
  ConfigStage.mixed => 'Swe + Calc',
};

/// Non-empty groups in display order, with their dimensions.
List<(ConfigGroup, List<ConfigDimension>)> configSections() {
  final groups = [...kGroups]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [
    for (final g in groups)
      if (dimensionsForGroup(g) case final dims when dims.isNotEmpty) (g, dims),
  ];
}
