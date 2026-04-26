import 'dart:math';
import 'dart:typed_data';

import 'vector_schema.dart';

/// Mapping from schema swe_aux key names to chartJson ascmc key names.
const Map<String, String> _sweAuxKeyMap = {
  'armc': 'armc',
  'vertex': 'vertex',
  'equasc': 'equatorial_ascendant',
  'co_asc_koch': 'co_ascendant_koch',
  'co_asc_munkasey': 'co_ascendant_munkasey',
  'polar_asc': 'polar_ascendant',
};

/// Encodes an angle in degrees as a (sin, cos) pair.
(double, double) sinCos(double degrees) {
  final radians = degrees * pi / 180.0;
  return (sin(radians), cos(radians));
}

/// Extracts a fixed-length numeric vector from [chartJson] according to
/// [schemaSpec].
///
/// Pure function — no I/O, no side effects.
///
/// The dimension order is deterministic:
/// longitudes → house_cusps → swe_aux → house_placements → nakshatras → retrogrades
Float64List extractVector(
  Map<String, dynamic> chartJson,
  Map<String, dynamic> schemaSpec,
) {
  final bodies = (schemaSpec['bodies'] as List).cast<String>();
  final features = schemaSpec['features'] as Map<String, dynamic>;
  final planets = (chartJson['planets'] as List).cast<Map<String, dynamic>>();

  // Build a lookup map: body name → planet entry.
  final planetMap = <String, Map<String, dynamic>>{};
  for (final p in planets) {
    planetMap[p['name'] as String] = p;
  }

  // Verify all schema bodies exist in chartJson.
  for (final body in bodies) {
    if (!planetMap.containsKey(body)) {
      throw ArgumentError(
        'Body "$body" required by schema but not found in chart JSON planets',
      );
    }
  }

  final values = <double>[];

  // --- longitudes ---
  if (features['longitudes'] == true) {
    for (final body in bodies) {
      final longitude = (planetMap[body]!['longitude'] as num).toDouble();
      final (s, c) = sinCos(longitude);
      values.add(s);
      values.add(c);
    }
  }

  // --- house_cusps ---
  if (features['house_cusps'] == true) {
    final houses = (chartJson['houses'] as List).cast<Map<String, dynamic>>();
    // Sort by house number to guarantee order 1-12.
    final sorted = List<Map<String, dynamic>>.from(houses)
      ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    for (final house in sorted) {
      final longitude = (house['longitude'] as num).toDouble();
      final (s, c) = sinCos(longitude);
      values.add(s);
      values.add(c);
    }
  }

  // --- swe_aux ---
  final sweAux = features['swe_aux'];
  if (sweAux is List && sweAux.isNotEmpty) {
    final ascmc = chartJson['ascmc'] as Map<String, dynamic>;
    for (final key in sweAux) {
      final chartKey = _sweAuxKeyMap[key as String];
      if (chartKey == null) {
        throw ArgumentError('Unknown swe_aux key: "$key"');
      }
      final value = (ascmc[chartKey] as num).toDouble();
      final (s, c) = sinCos(value);
      values.add(s);
      values.add(c);
    }
  }

  // --- house_placements ---
  if (features['house_placements'] == true) {
    for (final body in bodies) {
      final houseNumber = (planetMap[body]!['house_number'] as num).toDouble();
      final degrees = houseNumber * 30.0;
      final (s, c) = sinCos(degrees);
      values.add(s);
      values.add(c);
    }
  }

  // --- nakshatras ---
  if (features['nakshatras'] == true) {
    for (final body in bodies) {
      final nakshatra = (planetMap[body]!['nakshatra'] as num).toDouble();
      final degrees = nakshatra * 360.0 / 27.0;
      final (s, c) = sinCos(degrees);
      values.add(s);
      values.add(c);
    }
  }

  // --- retrogrades ---
  if (features['retrogrades'] == true) {
    for (final body in bodies) {
      final isRetrograde = planetMap[body]!['is_retrograde'] as bool;
      values.add(isRetrograde ? 1.0 : 0.0);
    }
  }

  final result = Float64List.fromList(values);

  // Verify length matches expected dims.
  final expectedDims = computeDims(schemaSpec);
  assert(
    result.length == expectedDims,
    'Vector length ${result.length} does not match expected dims $expectedDims',
  );

  return result;
}
