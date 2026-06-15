import 'package:aion/theme/display_options.dart';
import 'package:test/test.dart';

void main() {
  group('TOML round-trip', () {
    test('default options survive round-trip', () {
      final toml = DisplayOptions.defaultOptions.toToml();
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed, equals(DisplayOptions.defaultOptions));
    });

    test('custom options survive round-trip', () {
      const options = DisplayOptions(
        signNames: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        signPresetSource: null,
        planetNames: {'sun': 'Sol', 'moon': 'Luna', 'chiron': 'Chiron'},
        planetPresetSource: null,
        useSignGlyphs: true,
        usePlanetGlyphs: true,
        showOuterPlanets: false,
      );
      final parsed = DisplayOptions.fromToml(options.toToml());
      expect(parsed, equals(options));
    });

    test('options with preset sources round-trip', () {
      final options = DisplayOptions(
        signNames: DisplayOptions.signNamePresets['zodiac-sanskrit']!,
        signPresetSource: 'zodiac-sanskrit',
        planetNames: DisplayOptions.planetNamePresets['zodiac-sanskrit']!,
        planetPresetSource: 'zodiac-sanskrit',
      );
      final parsed = DisplayOptions.fromToml(options.toToml());
      expect(parsed, equals(options));
    });
  });

  group('sign name lookup', () {
    test('0-based index returns correct name', () {
      const opts = DisplayOptions(
        signNames: [
          'Aries',
          'Taurus',
          'Gemini',
          'Cancer',
          'Leo',
          'Virgo',
          'Libra',
          'Scorpio',
          'Sagittarius',
          'Capricorn',
          'Aquarius',
          'Pisces',
        ],
        planetNames: {},
      );
      expect(opts.signName(0), 'Aries');
      expect(opts.signName(4), 'Leo');
      expect(opts.signName(11), 'Pisces');
    });

    test('out-of-bounds index returns ?', () {
      expect(DisplayOptions.defaultOptions.signName(-1), '?');
      expect(DisplayOptions.defaultOptions.signName(12), '?');
      expect(DisplayOptions.defaultOptions.signName(100), '?');
    });

    for (final entry in DisplayOptions.signNamePresets.entries) {
      test('${entry.key} preset has exactly 12 sign names', () {
        expect(entry.value, hasLength(12));
      });

      test('${entry.key} preset has no empty names', () {
        for (final name in entry.value) {
          expect(name, isNotEmpty);
        }
      });
    }
  });

  group('planet name lookup', () {
    test('known id returns display name', () {
      expect(DisplayOptions.defaultOptions.planetName('sun'), 'Sun');
      expect(DisplayOptions.defaultOptions.planetName('chiron'), 'Chiron');
    });

    test('unknown id falls back to id string', () {
      expect(DisplayOptions.defaultOptions.planetName('ceres'), 'ceres');
    });

    for (final entry in DisplayOptions.planetNamePresets.entries) {
      test('${entry.key} preset covers all default planet ids', () {
        const expectedIds = [
          'sun',
          'moon',
          'mercury',
          'venus',
          'mars',
          'jupiter',
          'saturn',
          'rahu',
          'ketu',
          'uranus',
          'neptune',
          'pluto',
          'chiron',
        ];
        for (final id in expectedIds) {
          expect(
            entry.value.containsKey(id),
            isTrue,
            reason: '${entry.key} missing planet id: $id',
          );
        }
      });

      test('${entry.key} preset has no empty planet names', () {
        for (final name in entry.value.values) {
          expect(name, isNotEmpty);
        }
      });
    }
  });

  group('parse tolerance', () {
    test('empty toml returns defaults', () {
      final parsed = DisplayOptions.fromToml('');
      expect(parsed.signNames, hasLength(12));
      expect(parsed.planetNames, isNotEmpty);
      expect(parsed.showOuterPlanets, isTrue);
    });

    test('sign preset name seeds sign names when names list absent', () {
      const toml = 'sign_preset = "aditya"\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(
        parsed.signNames,
        equals(DisplayOptions.signNamePresets['aditya']),
      );
    });

    test('planet preset name seeds planet names when section absent', () {
      const toml = 'planet_preset = "zodiac-sanskrit"\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(
        parsed.planetNames,
        equals(DisplayOptions.planetNamePresets['zodiac-sanskrit']),
      );
    });

    test('explicit names override preset seeding', () {
      final toml = DisplayOptions.defaultOptions.toToml();
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed.signNames, equals(DisplayOptions.defaultOptions.signNames));
    });

    test('unknown keys are ignored', () {
      final toml =
          '${DisplayOptions.defaultOptions.toToml()}\n[extra]\nfoo = "bar"\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed, equals(DisplayOptions.defaultOptions));
    });
  });

  group('equality', () {
    test('identical options are equal', () {
      expect(
        DisplayOptions.defaultOptions,
        equals(DisplayOptions.defaultOptions),
      );
    });

    test('different sign names are not equal', () {
      final other = DisplayOptions(
        signNames: DisplayOptions.signNamePresets['aditya']!,
        signPresetSource: 'aditya',
        planetNames: DisplayOptions.defaultOptions.planetNames,
      );
      expect(other, isNot(equals(DisplayOptions.defaultOptions)));
    });
  });

  group('sign name validation', () {
    test('truncated sign names fall back to defaults', () {
      const toml = '[sign_names]\nnames = ["Aries", "Taurus"]\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed.signNames, hasLength(12));
      expect(parsed.signNames.first, 'Aries');
    });

    test('overlong sign names fall back to defaults', () {
      final names = List.generate(15, (i) => '"Sign$i"').join(', ');
      final toml = '[sign_names]\nnames = [$names]\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed.signNames, hasLength(12));
    });

    test('sign names with empty string fall back to defaults', () {
      final names = List.generate(
        12,
        (i) => i == 5 ? '""' : '"Sign$i"',
      ).join(', ');
      final toml = '[sign_names]\nnames = [$names]\n';
      final parsed = DisplayOptions.fromToml(toml);
      expect(parsed.signNames, hasLength(12));
      expect(parsed.signNames[5], isNotEmpty);
    });
  });

  group('signDisplay', () {
    test('returns name regardless of glyph toggle', () {
      expect(DisplayOptions.defaultOptions.signDisplay(0), 'Aries');
      expect(DisplayOptions.defaultOptions.signDisplay(11), 'Pisces');
      final glyphOpts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        useSignGlyphs: true,
      );
      expect(glyphOpts.signDisplay(0), 'Aries');
    });
  });

  group('planetDisplay', () {
    test('returns name regardless of glyph toggle', () {
      expect(DisplayOptions.defaultOptions.planetDisplay('sun'), 'Sun');
      final glyphOpts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        usePlanetGlyphs: true,
      );
      expect(glyphOpts.planetDisplay('sun'), 'Sun');
    });
  });

  group('signGlyphPath', () {
    test('returns null when useSignGlyphs is false', () {
      expect(DisplayOptions.defaultOptions.signGlyphPath(0), isNull);
    });

    test('returns asset path when useSignGlyphs is true', () {
      final opts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        useSignGlyphs: true,
      );
      expect(opts.signGlyphPath(0), 'assets/glyphs/zodiac/aries.svg');
      expect(opts.signGlyphPath(11), 'assets/glyphs/zodiac/pisces.svg');
    });

    test('returns null for out-of-bounds even with glyphs on', () {
      final opts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        useSignGlyphs: true,
      );
      expect(opts.signGlyphPath(-1), isNull);
      expect(opts.signGlyphPath(12), isNull);
    });
  });

  group('planetGlyphPath', () {
    test('returns null when usePlanetGlyphs is false', () {
      expect(DisplayOptions.defaultOptions.planetGlyphPath('sun'), isNull);
    });

    test('returns asset path when usePlanetGlyphs is true', () {
      final opts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        usePlanetGlyphs: true,
      );
      expect(opts.planetGlyphPath('sun'), 'assets/glyphs/planets/sun.svg');
      expect(
        opts.planetGlyphPath('saturn'),
        'assets/glyphs/planets/saturn.svg',
      );
    });

    test('returns null for unknown id with glyphs on', () {
      final opts = DisplayOptions(
        signNames: DisplayOptions.defaultOptions.signNames,
        planetNames: DisplayOptions.defaultOptions.planetNames,
        usePlanetGlyphs: true,
      );
      expect(opts.planetGlyphPath('ceres'), isNull);
    });
  });

  group('isOuterPlanet', () {
    test('identifies outer planets', () {
      expect(DisplayOptions.defaultOptions.isOuterPlanet('uranus'), isTrue);
      expect(DisplayOptions.defaultOptions.isOuterPlanet('neptune'), isTrue);
      expect(DisplayOptions.defaultOptions.isOuterPlanet('pluto'), isTrue);
      expect(DisplayOptions.defaultOptions.isOuterPlanet('chiron'), isTrue);
    });

    test('does not flag inner planets', () {
      expect(DisplayOptions.defaultOptions.isOuterPlanet('sun'), isFalse);
      expect(DisplayOptions.defaultOptions.isOuterPlanet('mars'), isFalse);
      expect(DisplayOptions.defaultOptions.isOuterPlanet('saturn'), isFalse);
    });
  });

  group('quoted planet keys', () {
    test('planet id with dot round-trips', () {
      const options = DisplayOptions(
        signNames: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        planetNames: {'asteroid.ceres': 'Ceres', 'sun': 'Sun'},
      );
      final parsed = DisplayOptions.fromToml(options.toToml());
      expect(parsed.planetName('asteroid.ceres'), 'Ceres');
    });

    test('planet id with space round-trips', () {
      const options = DisplayOptions(
        signNames: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        planetNames: {'black moon': 'Lilith', 'sun': 'Sun'},
      );
      final parsed = DisplayOptions.fromToml(options.toToml());
      expect(parsed.planetName('black moon'), 'Lilith');
    });
  });
}
