import 'package:chart_model/chart_model.dart';
import 'package:test/test.dart';

Map<String, dynamic> _makeHouse(int number, int signIndex) => {
  'number': number,
  'sign_index': signIndex,
  'cusp_longitude': (number - 1) * 30.0,
};

final _houses12 = List.generate(12, (i) => _makeHouse(i + 1, i));

final _fixtureJson = <String, dynamic>{
  'planets': [
    {
      'id': 'sun',
      'name': 'Sun',
      'longitude': 135.5,
      'sign': 'Leo',
      'sign_index': 4,
      'degree_in_sign': 15.5,
      'retrograde': false,
      'nakshatra': 'Magha',
      'nakshatra_pada': 2,
      'house': 1,
    },
    {
      'id': 'moon',
      'name': 'Moon',
      'longitude': 45.2,
      'sign': 'Taurus',
      'sign_index': 1,
      'degree_in_sign': 15.2,
      'retrograde': false,
      'nakshatra': 'Rohini',
      'nakshatra_pada': 3,
      'house': 10,
    },
  ],
  'ascendant': {'sign_index': 4, 'longitude': 130.0},
  'houses': _houses12,
};

Map<String, dynamic> _makePlanet(
  String id, {
  int signIndex = 0,
  int nakshatraPada = 1,
}) => {
  'id': id,
  'name': id,
  'longitude': 0.0,
  'sign': 'Aries',
  'sign_index': signIndex,
  'degree_in_sign': 0.0,
  'retrograde': false,
  'nakshatra': 'Ashwini',
  'nakshatra_pada': nakshatraPada,
  'house': 1,
};

void main() {
  group('ChartExpression.fromJson', () {
    test('parses planets', () {
      final expr = ChartExpression.fromJson(_fixtureJson);
      expect(expr.planets, hasLength(2));
      expect(expr.planets[0].id, 'sun');
      expect(expr.planets[0].name, 'Sun');
      expect(expr.planets[0].longitude, 135.5);
      expect(expr.planets[0].sign, 'Leo');
      expect(expr.planets[0].signIndex, 4);
      expect(expr.planets[0].degreeInSign, 15.5);
      expect(expr.planets[0].retrograde, false);
      expect(expr.planets[0].nakshatra, 'Magha');
      expect(expr.planets[0].nakshatraPada, 2);
      expect(expr.planets[0].house, 1);
    });

    test('parses ascendant', () {
      final expr = ChartExpression.fromJson(_fixtureJson);
      expect(expr.ascendant.signIndex, 4);
      expect(expr.ascendant.longitude, 130.0);
    });

    test('parses houses', () {
      final expr = ChartExpression.fromJson(_fixtureJson);
      expect(expr.houses, hasLength(12));
      expect(expr.houses[0].number, 1);
      expect(expr.houses[0].signIndex, 0);
      expect(expr.houses[0].cuspLongitude, 0.0);
    });

    test('ascmc is null when absent', () {
      final expr = ChartExpression.fromJson(_fixtureJson);
      expect(expr.ascmc, isNull);
    });

    test('parses ascmc when present', () {
      final json = {
        ..._fixtureJson,
        'ascmc': {
          'armc': 285.7,
          'vertex': 123.45,
          'equatorial_ascendant': 345.6,
          'co_ascendant_koch': 12.3,
          'co_ascendant_munkasey': 45.6,
          'polar_ascendant': 78.9,
        },
      };
      final expr = ChartExpression.fromJson(json);
      expect(expr.ascmc, isNotNull);
      expect(expr.ascmc!.armc, 285.7);
      expect(expr.ascmc!.vertex, 123.45);
    });

    test('throws FormatException on missing planets', () {
      expect(
        () => ChartExpression.fromJson({'ascendant': {}, 'houses': []}),
        throwsFormatException,
      );
    });

    test('throws FormatException on missing ascendant', () {
      expect(
        () => ChartExpression.fromJson({'planets': [], 'houses': []}),
        throwsFormatException,
      );
    });

    test('throws FormatException on missing houses', () {
      expect(
        () => ChartExpression.fromJson({
          'planets': [],
          'ascendant': {'sign_index': 0, 'longitude': 0.0},
        }),
        throwsFormatException,
      );
    });

    group('domain validation', () {
      test('throws on fewer than 12 houses', () {
        final json = {
          ..._fixtureJson,
          'houses': [_makeHouse(1, 0)],
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on more than 12 houses', () {
        final json = {
          ..._fixtureJson,
          'houses': [..._houses12, _makeHouse(13, 0)],
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on house number outside 1-12', () {
        final houses = List.generate(12, (i) => _makeHouse(i, i));
        final json = {..._fixtureJson, 'houses': houses};
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on duplicate house numbers', () {
        final houses = [
          for (var i = 1; i <= 11; i++) _makeHouse(i, i - 1),
          _makeHouse(1, 11),
        ];
        final json = {..._fixtureJson, 'houses': houses};
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on planet signIndex outside 0-11', () {
        final json = {
          ..._fixtureJson,
          'planets': [_makePlanet('sun', signIndex: 99)],
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on planet nakshatraPada outside 1-4', () {
        final json = {
          ..._fixtureJson,
          'planets': [_makePlanet('sun', nakshatraPada: 0)],
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on ascendant signIndex outside 0-11', () {
        final json = {
          ..._fixtureJson,
          'ascendant': {'sign_index': 12, 'longitude': 0.0},
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on house signIndex outside 0-11', () {
        final houses = [
          for (var i = 1; i <= 11; i++) _makeHouse(i, i - 1),
          _makeHouse(12, 99),
        ];
        final json = {..._fixtureJson, 'houses': houses};
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });

      test('throws on duplicate planet IDs', () {
        final json = {
          ..._fixtureJson,
          'planets': [_makePlanet('sun'), _makePlanet('sun')],
        };
        expect(() => ChartExpression.fromJson(json), throwsFormatException);
      });
    });
  });

  group('nakshatraToIndex', () {
    test('returns correct index for known nakshatra', () {
      expect(nakshatraToIndex('Ashwini'), 0);
      expect(nakshatraToIndex('Magha'), 9);
      expect(nakshatraToIndex('Revati'), 26);
    });

    test('is case-insensitive', () {
      expect(nakshatraToIndex('magha'), 9);
      expect(nakshatraToIndex('MAGHA'), 9);
    });

    test('returns null for unknown name', () {
      expect(nakshatraToIndex('NotANakshatra'), isNull);
    });
  });
}
