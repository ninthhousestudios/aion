import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

String configHash(String presetJson) {
  final Object? parsed;
  try {
    parsed = jsonDecode(presetJson);
  } catch (e) {
    throw ArgumentError('Unparseable preset JSON: $e');
  }
  final canonical = jsonEncode(_sortedValue(parsed));
  return sha256.convert(utf8.encode(canonical)).toString();
}

Object? _sortedValue(Object? value) {
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
