import 'package:chart_model/chart_model.dart';
import 'package:test/test.dart';

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
  'houses': [
    {'number': 1, 'sign_index': 4, 'cusp_longitude': 130.0},
    {'number': 2, 'sign_index': 5, 'cusp_longitude': 160.0},
  ],
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
      expect(expr.houses, hasLength(2));
      expect(expr.houses[0].number, 1);
      expect(expr.houses[0].signIndex, 4);
      expect(expr.houses[0].cuspLongitude, 130.0);
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
