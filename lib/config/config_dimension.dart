enum ConfigDimensionType { enumPick, boolean, multiSelect }

enum ConfigCost { cheap, expensive }

class ConfigChoice {
  final String value;
  final String label;

  const ConfigChoice({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigChoice && value == other.value && label == other.label;

  @override
  int get hashCode => Object.hash(value, label);

  @override
  String toString() => 'ConfigChoice($value)';
}

class ConfigGroup {
  final String key;
  final String label;
  final int sortOrder;

  const ConfigGroup({
    required this.key,
    required this.label,
    required this.sortOrder,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConfigGroup && key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'ConfigGroup($key)';
}

class ConfigDimension {
  final String key;
  final String name;
  final ConfigGroup group;
  final ConfigDimensionType type;
  final Object defaultValue;
  final List<ConfigChoice>? choices;
  final ConfigCost cost;

  const ConfigDimension({
    required this.key,
    required this.name,
    required this.group,
    required this.type,
    required this.defaultValue,
    this.choices,
    required this.cost,
  });

  @override
  String toString() => 'ConfigDimension($key)';
}

String? validateValue(ConfigDimension dimension, Object value) {
  switch (dimension.type) {
    case ConfigDimensionType.boolean:
      if (value is! bool) {
        return '${dimension.key}: expected bool, got ${value.runtimeType}';
      }
      return null;

    case ConfigDimensionType.enumPick:
      if (value is! String) {
        return '${dimension.key}: expected String, got ${value.runtimeType}';
      }
      final choices = dimension.choices;
      if (choices == null || choices.isEmpty) {
        return '${dimension.key}: enum dimension has no choices';
      }
      if (!choices.any((c) => c.value == value)) {
        return '${dimension.key}: "$value" is not a valid choice';
      }
      return null;

    case ConfigDimensionType.multiSelect:
      if (value is! Set<String>) {
        return '${dimension.key}: expected Set<String>, '
            'got ${value.runtimeType}';
      }
      final choices = dimension.choices;
      if (choices == null || choices.isEmpty) {
        return '${dimension.key}: multiSelect dimension has no choices';
      }
      final valid = choices.map((c) => c.value).toSet();
      final invalid = value.difference(valid);
      if (invalid.isNotEmpty) {
        return '${dimension.key}: invalid values: $invalid';
      }
      return null;
  }
}
