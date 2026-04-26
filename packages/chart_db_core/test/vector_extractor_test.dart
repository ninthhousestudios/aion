import 'dart:math';

import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

/// Fixture chart JSON with realistic data for all 13 bodies.
final Map<String, dynamic> fixtureChart = {
  'summary': {
    'jd': 2460400.5,
    'ayanamsa': 24.17,
    'ascendant': 15.3,
    'mc': 285.7,
  },
  'planets': [
    {
      'name': 'sun',
      'longitude': 35.25,
      'is_retrograde': false,
      'house_number': 4,
      'nakshatra': 2,
    },
    {
      'name': 'moon',
      'longitude': 128.50,
      'is_retrograde': false,
      'house_number': 8,
      'nakshatra': 9,
    },
    {
      'name': 'mercury',
      'longitude': 22.10,
      'is_retrograde': true,
      'house_number': 3,
      'nakshatra': 1,
    },
    {
      'name': 'venus',
      'longitude': 310.75,
      'is_retrograde': false,
      'house_number': 11,
      'nakshatra': 23,
    },
    {
      'name': 'mars',
      'longitude': 195.40,
      'is_retrograde': false,
      'house_number': 7,
      'nakshatra': 14,
    },
    {
      'name': 'jupiter',
      'longitude': 72.80,
      'is_retrograde': true,
      'house_number': 5,
      'nakshatra': 5,
    },
    {
      'name': 'saturn',
      'longitude': 340.15,
      'is_retrograde': false,
      'house_number': 12,
      'nakshatra': 25,
    },
    {
      'name': 'uranus',
      'longitude': 55.60,
      'is_retrograde': false,
      'house_number': 4,
      'nakshatra': 4,
    },
    {
      'name': 'neptune',
      'longitude': 358.90,
      'is_retrograde': true,
      'house_number': 1,
      'nakshatra': 0,
    },
    {
      'name': 'pluto',
      'longitude': 302.30,
      'is_retrograde': false,
      'house_number': 11,
      'nakshatra': 22,
    },
    {
      'name': 'chiron',
      'longitude': 23.45,
      'is_retrograde': false,
      'house_number': 3,
      'nakshatra': 1,
    },
    {
      'name': 'rahu',
      'longitude': 15.80,
      'is_retrograde': true,
      'house_number': 2,
      'nakshatra': 1,
    },
    {
      'name': 'ketu',
      'longitude': 195.80,
      'is_retrograde': true,
      'house_number': 8,
      'nakshatra': 14,
    },
  ],
  'houses': [
    {'number': 1, 'longitude': 15.30},
    {'number': 2, 'longitude': 42.10},
    {'number': 3, 'longitude': 68.90},
    {'number': 4, 'longitude': 95.70},
    {'number': 5, 'longitude': 122.50},
    {'number': 6, 'longitude': 149.30},
    {'number': 7, 'longitude': 195.30},
    {'number': 8, 'longitude': 222.10},
    {'number': 9, 'longitude': 248.90},
    {'number': 10, 'longitude': 275.70},
    {'number': 11, 'longitude': 302.50},
    {'number': 12, 'longitude': 329.30},
  ],
  'ascmc': {
    'armc': 285.70,
    'vertex': 123.45,
    'equatorial_ascendant': 345.60,
    'co_ascendant_koch': 12.30,
    'co_ascendant_munkasey': 45.60,
    'polar_ascendant': 78.90,
  },
};

void main() {
  group('sinCos encoding', () {
    test('0° → (0, 1)', () {
      final (s, c) = sinCos(0.0);
      expect(s, closeTo(0.0, 1e-10));
      expect(c, closeTo(1.0, 1e-10));
    });

    test('90° → (1, 0)', () {
      final (s, c) = sinCos(90.0);
      expect(s, closeTo(1.0, 1e-10));
      expect(c, closeTo(0.0, 1e-10));
    });

    test('180° → (0, -1)', () {
      final (s, c) = sinCos(180.0);
      expect(s, closeTo(0.0, 1e-10));
      expect(c, closeTo(-1.0, 1e-10));
    });

    test('270° → (-1, 0)', () {
      final (s, c) = sinCos(270.0);
      expect(s, closeTo(-1.0, 1e-10));
      expect(c, closeTo(0.0, 1e-10));
    });
  });

  group('extractVector', () {
    test('western-13 produces 101-dim Float64List', () {
      final vec = extractVector(fixtureChart, westernSpec);
      expect(vec.length, equals(101));
    });

    test('vedic-13 produces 127-dim Float64List', () {
      final vec = extractVector(fixtureChart, vedicSpec);
      expect(vec.length, equals(127));
    });

    test('throws on missing body in chart JSON', () {
      final chartMissingBody = Map<String, dynamic>.from(fixtureChart);
      // Remove the last planet (ketu).
      final planets = (chartMissingBody['planets'] as List)
          .where((p) => (p as Map)['name'] != 'ketu')
          .toList();
      chartMissingBody['planets'] = planets;

      expect(
        () => extractVector(chartMissingBody, westernSpec),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('ketu'),
          ),
        ),
      );
    });

    test('longitude encoding matches expected sin/cos for sun', () {
      final vec = extractVector(fixtureChart, westernSpec);
      // Sun is the first body, longitudes are the first feature block.
      // Sun longitude = 35.25°
      final radians = 35.25 * pi / 180.0;
      expect(vec[0], closeTo(sin(radians), 1e-10));
      expect(vec[1], closeTo(cos(radians), 1e-10));
    });

    test('retrograde planets encode as 1.0, non-retrograde as 0.0', () {
      final vec = extractVector(fixtureChart, westernSpec);
      // Western-13 layout: longitudes (13×2=26) + cusps (12×2=24)
      //   + swe_aux (6×2=12) + house_placements (13×2=26) = 88
      // Retrogrades start at index 88, one per body in order.
      const retroStart = 88;
      final bodies = (westernSpec['bodies'] as List).cast<String>();
      final planets = (fixtureChart['planets'] as List)
          .cast<Map<String, dynamic>>();
      final planetMap = {for (final p in planets) p['name'] as String: p};

      for (var i = 0; i < bodies.length; i++) {
        final isRetro = planetMap[bodies[i]]!['is_retrograde'] as bool;
        expect(
          vec[retroStart + i],
          equals(isRetro ? 1.0 : 0.0),
          reason: '${bodies[i]} retrograde encoding',
        );
      }
    });

    test('house cusp encoding for house 1', () {
      final vec = extractVector(fixtureChart, westernSpec);
      // House cusps start after longitudes: 13×2 = 26.
      // House 1 longitude = 15.30°
      final radians = 15.30 * pi / 180.0;
      expect(vec[26], closeTo(sin(radians), 1e-10));
      expect(vec[27], closeTo(cos(radians), 1e-10));
    });

    test('swe_aux encoding for armc', () {
      final vec = extractVector(fixtureChart, westernSpec);
      // swe_aux starts after longitudes (26) + cusps (24) = 50.
      // First swe_aux key is 'armc' = 285.70°
      final radians = 285.70 * pi / 180.0;
      expect(vec[50], closeTo(sin(radians), 1e-10));
      expect(vec[51], closeTo(cos(radians), 1e-10));
    });

    test('house placement encoding for sun', () {
      final vec = extractVector(fixtureChart, westernSpec);
      // house_placements start after longitudes (26) + cusps (24) + swe_aux (12) = 62.
      // Sun house_number = 4, degrees = 4 × 30 = 120°
      final radians = 120.0 * pi / 180.0;
      expect(vec[62], closeTo(sin(radians), 1e-10));
      expect(vec[63], closeTo(cos(radians), 1e-10));
    });

    test('nakshatra encoding for sun in vedic spec', () {
      final vec = extractVector(fixtureChart, vedicSpec);
      // In vedic, nakshatras start after longitudes (26) + cusps (24)
      //   + swe_aux (12) + house_placements (26) = 88.
      // Sun nakshatra = 2, degrees = 2 × 360/27
      final degrees = 2.0 * 360.0 / 27.0;
      final radians = degrees * pi / 180.0;
      expect(vec[88], closeTo(sin(radians), 1e-10));
      expect(vec[89], closeTo(cos(radians), 1e-10));
    });

    test('minimal spec with only longitudes', () {
      final spec = {
        'bodies': ['sun', 'moon'],
        'features': {
          'longitudes': true,
        },
      };
      final vec = extractVector(fixtureChart, spec);
      expect(vec.length, equals(4));
    });
  });
}
