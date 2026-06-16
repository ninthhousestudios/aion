import 'package:flutter_test/flutter_test.dart';

import 'package:aion/config/arrow_dimensions.dart';
import 'package:aion/config/config_dimension.dart';

void main() {
  group('dimension inventory', () {
    test('has exactly 16 dimensions', () {
      expect(kDimensions.length, 16);
    });

    test('all dimension keys are unique', () {
      final keys = kDimensions.map((d) => d.key).toSet();
      expect(keys.length, kDimensions.length);
    });

    test('has exactly 5 groups', () {
      expect(kGroups.length, 5);
    });

    test('every dimension belongs to a known group', () {
      for (final d in kDimensions) {
        expect(
          kGroups,
          contains(d.group),
          reason: '${d.key} has unknown group',
        );
      }
    });
  });

  group('group membership', () {
    test('Ayanamsa & Zodiac has expected dimensions', () {
      final keys = dimensionsForGroup(ayanamsaZodiacGroup).map((d) => d.key);
      expect(keys, [
        'signAyanamsa',
        'nakAyanamsa',
        'circle',
        'zodiacSystem',
        'nakEquatorial',
      ]);
    });

    test('Houses has expected dimensions', () {
      final keys = dimensionsForGroup(housesGroup).map((d) => d.key);
      expect(keys, ['houseSystem']);
    });

    test('Bodies has expected dimensions', () {
      final keys = dimensionsForGroup(bodiesGroup).map((d) => d.key);
      expect(keys, ['bodies', 'trueNode', 'stars']);
    });

    test('Vedic Options has expected dimensions', () {
      final keys = dimensionsForGroup(vedicGroup).map((d) => d.key);
      expect(keys, ['dashaYearLength', 'charaKarakaCount', 'rashiAspectMode']);
    });

    test('Advanced has expected dimensions', () {
      final keys = dimensionsForGroup(advancedGroup).map((d) => d.key);
      expect(keys, [
        'topocentric',
        'ephemerisSource',
        'extraFrames',
        'traditions',
      ]);
    });
  });

  group('type correctness', () {
    test('enum dimensions have non-empty choices', () {
      for (final d in kDimensions.where(
        (d) => d.type == ConfigDimensionType.enumPick,
      )) {
        expect(d.choices, isNotNull, reason: '${d.key} choices null');
        expect(d.choices, isNotEmpty, reason: '${d.key} choices empty');
      }
    });

    test('boolean dimensions have no choices', () {
      for (final d in kDimensions.where(
        (d) => d.type == ConfigDimensionType.boolean,
      )) {
        expect(d.choices, isNull, reason: '${d.key} should have no choices');
      }
    });

    test('multiSelect dimensions have non-empty choices', () {
      for (final d in kDimensions.where(
        (d) => d.type == ConfigDimensionType.multiSelect,
      )) {
        expect(d.choices, isNotNull, reason: '${d.key} choices null');
        expect(d.choices, isNotEmpty, reason: '${d.key} choices empty');
      }
    });
  });

  group('choice counts', () {
    test('signAyanamsa has 53 choices', () {
      expect(signAyanamsa.choices!.length, 53);
    });

    test('nakAyanamsa shares ayanamsa choices', () {
      expect(nakAyanamsa.choices!.length, signAyanamsa.choices!.length);
    });

    test('houseSystem has 15 choices', () {
      expect(houseSystem.choices!.length, 15);
    });

    test('bodies has 13 choices', () {
      expect(bodies.choices!.length, 13);
    });

    test('stars has 75 choices', () {
      expect(stars.choices!.length, 75);
    });

    test('dashaYearLength has 6 choices', () {
      expect(dashaYearLength.choices!.length, 6);
    });

    test('charaKarakaCount has 2 choices', () {
      expect(charaKarakaCount.choices!.length, 2);
    });

    test('rashiAspectMode has 3 choices', () {
      expect(rashiAspectMode.choices!.length, 3);
    });

    test('ephemerisSource has 3 choices', () {
      expect(ephemerisSource.choices!.length, 3);
    });

    test('extraFrames has 3 choices', () {
      expect(extraFrames.choices!.length, 3);
    });
  });

  group('cost flags', () {
    test('SweConfig fields are expensive', () {
      const sweKeys = {
        'signAyanamsa',
        'nakAyanamsa',
        'houseSystem',
        'bodies',
        'trueNode',
        'topocentric',
        'ephemerisSource',
        'extraFrames',
        'stars',
      };
      for (final d in kDimensions.where((d) => sweKeys.contains(d.key))) {
        expect(
          d.cost,
          ConfigCost.expensive,
          reason: '${d.key} should be expensive',
        );
      }
    });

    test('CalcConfig and VedicConfig fields are cheap', () {
      const cheapKeys = {
        'circle',
        'zodiacSystem',
        'nakEquatorial',
        'traditions',
        'dashaYearLength',
        'charaKarakaCount',
        'rashiAspectMode',
      };
      for (final d in kDimensions.where((d) => cheapKeys.contains(d.key))) {
        expect(d.cost, ConfigCost.cheap, reason: '${d.key} should be cheap');
      }
    });
  });

  group('default values', () {
    test('all defaults pass validation', () {
      for (final d in kDimensions) {
        final error = validateValue(d, d.defaultValue);
        expect(error, isNull, reason: '${d.key} default failed: $error');
      }
    });
  });

  group('validateValue', () {
    test('enum: accepts valid choice', () {
      expect(validateValue(houseSystem, 'placidus'), isNull);
    });

    test('enum: rejects unknown string', () {
      expect(validateValue(houseSystem, 'notASystem'), isNotNull);
    });

    test('enum: rejects non-string', () {
      expect(validateValue(houseSystem, 42), isNotNull);
    });

    test('boolean: accepts bool', () {
      expect(validateValue(trueNode, true), isNull);
      expect(validateValue(trueNode, false), isNull);
    });

    test('boolean: rejects non-bool', () {
      expect(validateValue(trueNode, 'true'), isNotNull);
    });

    test('multiSelect: accepts valid subset', () {
      expect(validateValue(bodies, <String>{'sun', 'moon'}), isNull);
    });

    test('multiSelect: accepts empty set', () {
      expect(validateValue(bodies, <String>{}), isNull);
    });

    test('multiSelect: rejects invalid values', () {
      expect(validateValue(bodies, <String>{'sun', 'invalid'}), isNotNull);
    });

    test('multiSelect: rejects non-set', () {
      expect(validateValue(bodies, 'sun'), isNotNull);
    });
  });

  group('ConfigChoice equality', () {
    test('equal choices are equal', () {
      const a = ConfigChoice(value: 'x', label: 'X');
      const b = ConfigChoice(value: 'x', label: 'X');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different choices are not equal', () {
      const a = ConfigChoice(value: 'x', label: 'X');
      const b = ConfigChoice(value: 'y', label: 'Y');
      expect(a, isNot(equals(b)));
    });
  });

  group('ConfigGroup equality', () {
    test('groups with same key are equal', () {
      const a = ConfigGroup(key: 'k', label: 'A', sortOrder: 0);
      const b = ConfigGroup(key: 'k', label: 'B', sortOrder: 1);
      expect(a, equals(b));
    });

    test('groups with different keys are not equal', () {
      const a = ConfigGroup(key: 'k1', label: 'A', sortOrder: 0);
      const b = ConfigGroup(key: 'k2', label: 'A', sortOrder: 0);
      expect(a, isNot(equals(b)));
    });
  });
}
