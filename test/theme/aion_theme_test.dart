import 'dart:ui';

import 'package:aion/theme/aion_theme.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:test/test.dart';

void main() {
  group('fromPreset dark regression', () {
    final theme = AionTheme.fromPreset(ThemePreset.dark);

    test('canvasBackground', () {
      expect(theme.canvasBackground, const Color(0xFF0F0F1A));
    });

    test('surfaceOverlay', () {
      expect(theme.surfaceOverlay, const Color(0xFF1E1E2E));
    });

    test('surfaceBorder', () {
      expect(theme.surfaceBorder, const Color(0x1FFFFFFF));
    });

    test('cardBorderSelected', () {
      expect(theme.cardBorderSelected, const Color(0xFFFFFFFF));
    });

    test('cardBorderHovered', () {
      expect(theme.cardBorderHovered, const Color(0x8AFFFFFF));
    });

    test('cardBorderIdle', () {
      expect(theme.cardBorderIdle, const Color(0x3DFFFFFF));
    });

    test('cardShadow', () {
      expect(theme.cardShadow, const Color(0x1EFFFFFF));
    });

    test('cardLabelColor', () {
      expect(theme.cardLabelColor, const Color(0xFFFFFFFF));
    });

    test('cardDimColor', () {
      expect(theme.cardDimColor, const Color(0x78FFFFFF));
    });

    test('snapAccent', () {
      expect(theme.snapAccent, const Color(0xFF6366F1));
    });

    test('snapGuideColor', () {
      expect(theme.snapGuideColor, const Color(0x556366F1));
    });

    test('snapInactiveColor', () {
      expect(theme.snapInactiveColor, const Color(0x61FFFFFF));
    });

    test('chromeButtonHover', () {
      expect(theme.chromeButtonHover, const Color(0x1FFFFFFF));
    });

    test('chromeCloseHover', () {
      expect(theme.chromeCloseHover, const Color(0xFFF44336));
    });

    test('chromeIconColor', () {
      expect(theme.chromeIconColor, const Color(0x8AFFFFFF));
    });

    test('statusConnected', () {
      expect(theme.statusConnected, const Color(0xFF4CAF50));
    });

    test('statusStarting', () {
      expect(theme.statusStarting, const Color(0xFFFFC107));
    });

    test('statusError', () {
      expect(theme.statusError, const Color(0xFFF44336));
    });

    test('statusStopped', () {
      expect(theme.statusStopped, const Color(0xFF9E9E9E));
    });
  });

  group('fromPreset validity', () {
    for (final preset in ThemePreset.builtIn) {
      test('${preset.name} produces non-transparent canvas', () {
        final theme = AionTheme.fromPreset(preset);
        expect(theme.canvasBackground.a, greaterThan(0.0));
      });

      test('${preset.name} produces non-transparent text', () {
        final theme = AionTheme.fromPreset(preset);
        expect(theme.cardLabelColor.a, greaterThan(0.0));
      });
    }
  });

  group('different presets produce different themes', () {
    test('dark and light differ', () {
      final dark = AionTheme.fromPreset(ThemePreset.dark);
      final light = AionTheme.fromPreset(ThemePreset.light);
      expect(dark.canvasBackground, isNot(equals(light.canvasBackground)));
    });
  });
}
