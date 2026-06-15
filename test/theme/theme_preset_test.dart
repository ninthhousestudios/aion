import 'dart:ui';

import 'package:aion/theme/theme_preset.dart';
import 'package:test/test.dart';

void main() {
  group('TOML round-trip', () {
    test('dark preset survives round-trip', () {
      final toml = ThemePreset.dark.toToml();
      final parsed = ThemePreset.fromToml(toml);
      expect(parsed, equals(ThemePreset.dark));
    });

    test('light preset survives round-trip', () {
      final toml = ThemePreset.light.toToml();
      final parsed = ThemePreset.fromToml(toml);
      expect(parsed, equals(ThemePreset.light));
    });

    test('immersive preset survives round-trip', () {
      final toml = ThemePreset.immersive.toToml();
      final parsed = ThemePreset.fromToml(toml);
      expect(parsed, equals(ThemePreset.immersive));
    });

    test('preset with image path round-trips', () {
      const preset = ThemePreset(
        name: 'starfield',
        backgroundType: BackgroundType.image,
        backgroundColor: Color(0xFF000000),
        backgroundImagePath: '/home/user/images/stars.png',
        surfaceCard: Color(0xFF1A1A2E),
        surfacePanel: Color(0xFF12121F),
        surfaceBorderIdle: Color(0x33FFFFFF),
        surfaceBorderHovered: Color(0x66FFFFFF),
        surfaceBorderSelected: Color(0xCCFFFFFF),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xAAFFFFFF),
        textMuted: Color(0x66FFFFFF),
        accentSeed: Color(0xFF7C3AED),
        accentLink: Color(0xFFA78BFA),
        cardOpacity: 0.75,
        statusStripHeight: 6.0,
      );
      final toml = preset.toToml();
      final parsed = ThemePreset.fromToml(toml);
      expect(parsed, equals(preset));
    });
  });

  group('built-in preset validity', () {
    for (final preset in ThemePreset.builtIn) {
      test('${preset.name} has non-transparent text primary', () {
        expect(preset.textPrimary.a, greaterThan(0.0));
      });

      test('${preset.name} has valid card opacity', () {
        expect(preset.cardOpacity, greaterThanOrEqualTo(0.0));
        expect(preset.cardOpacity, lessThanOrEqualTo(1.0));
      });

      test('${preset.name} has positive status strip height', () {
        expect(preset.statusStripHeight, greaterThan(0.0));
      });

      test('${preset.name} round-trips through TOML', () {
        final parsed = ThemePreset.fromToml(preset.toToml());
        expect(parsed, equals(preset));
      });
    }
  });

  group('parse tolerance', () {
    test('missing optional sections use defaults', () {
      const minimal = 'name = "minimal"\n';
      final parsed = ThemePreset.fromToml(minimal);
      expect(parsed.name, 'minimal');
      expect(parsed.backgroundType, BackgroundType.solid);
      expect(parsed.cardOpacity, 1.0);
    });

    test('unknown keys are ignored', () {
      final toml =
          '${ThemePreset.dark.toToml()}\n[unknown_section]\nfoo = "bar"\n';
      final parsed = ThemePreset.fromToml(toml);
      expect(parsed, equals(ThemePreset.dark));
    });

    test('missing name defaults to unnamed', () {
      const noName = '[background]\ntype = "solid"\ncolor = "FF000000"\n';
      final parsed = ThemePreset.fromToml(noName);
      expect(parsed.name, 'unnamed');
    });
  });

  group('slugify', () {
    test('lowercases and replaces spaces', () {
      expect(ThemePreset.slugify('My Cool Theme'), 'my-cool-theme');
    });

    test('strips leading and trailing hyphens', () {
      expect(ThemePreset.slugify('--hello--'), 'hello');
    });

    test('collapses multiple special chars', () {
      expect(ThemePreset.slugify('a   b___c'), 'a-b-c');
    });
  });

  group('equality', () {
    test('identical presets are equal', () {
      expect(ThemePreset.dark, equals(ThemePreset.dark));
    });

    test('different names are not equal', () {
      final copy = ThemePreset.fromToml(
        ThemePreset.dark.toToml().replaceFirst(
          'name = "dark"',
          'name = "other"',
        ),
      );
      expect(copy, isNot(equals(ThemePreset.dark)));
    });
  });
}
