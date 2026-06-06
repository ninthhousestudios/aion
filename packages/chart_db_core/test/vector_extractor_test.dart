import 'dart:math';

import 'package:chart_model/chart_model.dart';
import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

Planet _planet(
  String id, {
  required double longitude,
  required bool retrograde,
  required int house,
  required String nakshatra,
  int signIndex = 0,
}) =>
    Planet(
      id: id,
      name: id,
      longitude: longitude,
      sign: '',
      signIndex: signIndex,
      degreeInSign: 0,
      retrograde: retrograde,
      nakshatra: nakshatra,
      nakshatraPada: 1,
      house: house,
    );

final fixtureExpression = ChartExpression(
  planets: [
    _planet('sun', longitude: 35.25, retrograde: false, house: 4, nakshatra: 'Krittika'),
    _planet('moon', longitude: 128.50, retrograde: false, house: 8, nakshatra: 'Magha'),
    _planet('mercury', longitude: 22.10, retrograde: true, house: 3, nakshatra: 'Bharani'),
    _planet('venus', longitude: 310.75, retrograde: false, house: 11, nakshatra: 'Dhanishta'),
    _planet('mars', longitude: 195.40, retrograde: false, house: 7, nakshatra: 'Chitra'),
    _planet('jupiter', longitude: 72.80, retrograde: true, house: 5, nakshatra: 'Ardra'),
    _planet('saturn', longitude: 340.15, retrograde: false, house: 12, nakshatra: 'Purva Bhadrapada'),
    _planet('uranus', longitude: 55.60, retrograde: false, house: 4, nakshatra: 'Mrigashira'),
    _planet('neptune', longitude: 358.90, retrograde: true, house: 1, nakshatra: 'Ashwini'),
    _planet('pluto', longitude: 302.30, retrograde: false, house: 11, nakshatra: 'Dhanishta'),
    _planet('chiron', longitude: 23.45, retrograde: false, house: 3, nakshatra: 'Bharani'),
    _planet('rahu', longitude: 15.80, retrograde: true, house: 2, nakshatra: 'Bharani'),
    _planet('ketu', longitude: 195.80, retrograde: true, house: 8, nakshatra: 'Chitra'),
  ],
  ascendant: const Ascendant(signIndex: 0, longitude: 15.3),
  houses: const [
    House(number: 1, signIndex: 0, cuspLongitude: 15.30),
    House(number: 2, signIndex: 1, cuspLongitude: 42.10),
    House(number: 3, signIndex: 2, cuspLongitude: 68.90),
    House(number: 4, signIndex: 3, cuspLongitude: 95.70),
    House(number: 5, signIndex: 4, cuspLongitude: 122.50),
    House(number: 6, signIndex: 5, cuspLongitude: 149.30),
    House(number: 7, signIndex: 6, cuspLongitude: 195.30),
    House(number: 8, signIndex: 7, cuspLongitude: 222.10),
    House(number: 9, signIndex: 8, cuspLongitude: 248.90),
    House(number: 10, signIndex: 9, cuspLongitude: 275.70),
    House(number: 11, signIndex: 10, cuspLongitude: 302.50),
    House(number: 12, signIndex: 11, cuspLongitude: 329.30),
  ],
  ascmc: const AscMc(
    armc: 285.70,
    vertex: 123.45,
    equatorialAscendant: 345.60,
    coAscendantKoch: 12.30,
    coAscendantMunkasey: 45.60,
    polarAscendant: 78.90,
  ),
);

void main() {
  group('sinCos encoding', () {
    test('0 degrees -> (0, 1)', () {
      final (s, c) = sinCos(0.0);
      expect(s, closeTo(0.0, 1e-10));
      expect(c, closeTo(1.0, 1e-10));
    });

    test('90 degrees -> (1, 0)', () {
      final (s, c) = sinCos(90.0);
      expect(s, closeTo(1.0, 1e-10));
      expect(c, closeTo(0.0, 1e-10));
    });

    test('180 degrees -> (0, -1)', () {
      final (s, c) = sinCos(180.0);
      expect(s, closeTo(0.0, 1e-10));
      expect(c, closeTo(-1.0, 1e-10));
    });

    test('270 degrees -> (-1, 0)', () {
      final (s, c) = sinCos(270.0);
      expect(s, closeTo(-1.0, 1e-10));
      expect(c, closeTo(0.0, 1e-10));
    });
  });

  group('extractVector', () {
    test('western-13 produces 101-dim Float64List', () {
      final vec = extractVector(fixtureExpression, westernSpec);
      expect(vec.length, equals(101));
    });

    test('vedic-13 produces 127-dim Float64List', () {
      final vec = extractVector(fixtureExpression, vedicSpec);
      expect(vec.length, equals(127));
    });

    test('throws on missing body in expression', () {
      final expr = ChartExpression(
        planets: fixtureExpression.planets
            .where((p) => p.name != 'ketu')
            .toList(),
        ascendant: fixtureExpression.ascendant,
        houses: fixtureExpression.houses,
        ascmc: fixtureExpression.ascmc,
      );

      expect(
        () => extractVector(expr, westernSpec),
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
      final vec = extractVector(fixtureExpression, westernSpec);
      final radians = 35.25 * pi / 180.0;
      expect(vec[0], closeTo(sin(radians), 1e-10));
      expect(vec[1], closeTo(cos(radians), 1e-10));
    });

    test('retrograde planets encode as 1.0, non-retrograde as 0.0', () {
      final vec = extractVector(fixtureExpression, westernSpec);
      const retroStart = 88;
      final bodies = (westernSpec['bodies'] as List).cast<String>();
      final planetMap = {
        for (final p in fixtureExpression.planets) p.name.toLowerCase(): p,
      };

      for (var i = 0; i < bodies.length; i++) {
        final isRetro = planetMap[bodies[i]]!.retrograde;
        expect(
          vec[retroStart + i],
          equals(isRetro ? 1.0 : 0.0),
          reason: '${bodies[i]} retrograde encoding',
        );
      }
    });

    test('house cusp encoding for house 1', () {
      final vec = extractVector(fixtureExpression, westernSpec);
      final radians = 15.30 * pi / 180.0;
      expect(vec[26], closeTo(sin(radians), 1e-10));
      expect(vec[27], closeTo(cos(radians), 1e-10));
    });

    test('swe_aux encoding for armc', () {
      final vec = extractVector(fixtureExpression, westernSpec);
      final radians = 285.70 * pi / 180.0;
      expect(vec[50], closeTo(sin(radians), 1e-10));
      expect(vec[51], closeTo(cos(radians), 1e-10));
    });

    test('house placement encoding for sun', () {
      final vec = extractVector(fixtureExpression, westernSpec);
      // Sun house = 4, degrees = 4 * 30 = 120
      final radians = 120.0 * pi / 180.0;
      expect(vec[62], closeTo(sin(radians), 1e-10));
      expect(vec[63], closeTo(cos(radians), 1e-10));
    });

    test('nakshatra encoding for sun in vedic spec', () {
      final vec = extractVector(fixtureExpression, vedicSpec);
      // Sun nakshatra = 'Krittika' = index 2
      final degrees = 2.0 * 360.0 / 27.0;
      final radians = degrees * pi / 180.0;
      expect(vec[88], closeTo(sin(radians), 1e-10));
      expect(vec[89], closeTo(cos(radians), 1e-10));
    });

    test('minimal spec with only longitudes', () {
      final spec = {
        'bodies': ['sun', 'moon'],
        'features': {'longitudes': true},
      };
      final vec = extractVector(fixtureExpression, spec);
      expect(vec.length, equals(4));
    });
  });
}
