import 'dart:math';
import 'dart:typed_data';

import 'package:chart_model/chart_model.dart';

import 'vector_schema.dart';

/// Encodes an angle in degrees as a (sin, cos) pair.
(double, double) sinCos(double degrees) {
  final radians = degrees * pi / 180.0;
  return (sin(radians), cos(radians));
}

/// Extracts a fixed-length numeric vector from [expression] according to
/// [schemaSpec].
///
/// Pure function — no I/O, no side effects.
///
/// The dimension order is deterministic:
/// longitudes → house_cusps → swe_aux → house_placements → nakshatras → retrogrades
Float64List extractVector(
  ChartExpression expression,
  Map<String, dynamic> schemaSpec,
) {
  final bodies = (schemaSpec['bodies'] as List).cast<String>();
  final features = schemaSpec['features'] as Map<String, dynamic>;

  final planetMap = <String, Planet>{};
  for (final p in expression.planets) {
    planetMap[p.name.toLowerCase()] = p;
  }

  for (final body in bodies) {
    if (!planetMap.containsKey(body)) {
      throw ArgumentError(
        'Body "$body" required by schema but not found in expression planets',
      );
    }
  }

  final values = <double>[];

  // --- longitudes ---
  if (features['longitudes'] == true) {
    for (final body in bodies) {
      final (s, c) = sinCos(planetMap[body]!.longitude);
      values.add(s);
      values.add(c);
    }
  }

  // --- house_cusps ---
  if (features['house_cusps'] == true) {
    final sorted = List<House>.from(expression.houses)
      ..sort((a, b) => a.number.compareTo(b.number));
    for (final house in sorted) {
      final (s, c) = sinCos(house.cuspLongitude);
      values.add(s);
      values.add(c);
    }
  }

  // --- swe_aux ---
  final sweAux = features['swe_aux'];
  if (sweAux is List && sweAux.isNotEmpty) {
    final ascmc = expression.ascmc;
    if (ascmc == null) {
      throw StateError('swe_aux features requested but expression has no ascmc');
    }
    for (final key in sweAux) {
      final value = switch (key as String) {
        'armc' => ascmc.armc,
        'vertex' => ascmc.vertex,
        'equasc' => ascmc.equatorialAscendant,
        'co_asc_koch' => ascmc.coAscendantKoch,
        'co_asc_munkasey' => ascmc.coAscendantMunkasey,
        'polar_asc' => ascmc.polarAscendant,
        _ => throw ArgumentError('Unknown swe_aux key: "$key"'),
      };
      final (s, c) = sinCos(value);
      values.add(s);
      values.add(c);
    }
  }

  // --- house_placements ---
  if (features['house_placements'] == true) {
    for (final body in bodies) {
      final degrees = planetMap[body]!.house * 30.0;
      final (s, c) = sinCos(degrees);
      values.add(s);
      values.add(c);
    }
  }

  // --- nakshatras ---
  if (features['nakshatras'] == true) {
    for (final body in bodies) {
      final planet = planetMap[body]!;
      final index = nakshatraToIndex(planet.nakshatra);
      if (index == null) {
        throw ArgumentError(
          'Unknown nakshatra "${planet.nakshatra}" for body "$body"',
        );
      }
      final degrees = index * 360.0 / 27.0;
      final (s, c) = sinCos(degrees);
      values.add(s);
      values.add(c);
    }
  }

  // --- retrogrades ---
  if (features['retrogrades'] == true) {
    for (final body in bodies) {
      values.add(planetMap[body]!.retrograde ? 1.0 : 0.0);
    }
  }

  final result = Float64List.fromList(values);

  final expectedDims = computeDims(schemaSpec);
  if (result.length != expectedDims) {
    throw StateError(
      'Vector length ${result.length} does not match expected dims $expectedDims',
    );
  }

  return result;
}
