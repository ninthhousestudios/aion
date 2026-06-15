import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/theme/aion_theme.dart';
import 'package:aion/theme/card_display_overrides.dart';
import 'package:aion/theme/display_options.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:aion/theme/theme_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThemeResolver resolver;

  setUp(() {
    resolver = const ThemeResolver(
      preset: ThemePreset.dark,
      globalDisplayOptions: DisplayOptions.defaultOptions,
    );
  });

  group('resolve(null)', () {
    test('returns global defaults', () {
      final resolved = resolver.resolve(null);

      expect(resolved.displayOptions, DisplayOptions.defaultOptions);
      expect(resolved.cardOpacity, ThemePreset.dark.cardOpacity);
      expect(
        resolved.theme.canvasBackground,
        AionTheme.fromPreset(ThemePreset.dark).canvasBackground,
      );
    });
  });

  group('resolve(card) with no overrides', () {
    test('returns global defaults', () {
      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
      );

      final resolved = resolver.resolve(card);

      expect(resolved.displayOptions, DisplayOptions.defaultOptions);
      expect(resolved.cardOpacity, ThemePreset.dark.cardOpacity);
    });
  });

  group('resolve(card) with partial overrides', () {
    test('useSignGlyphs override applies, rest inherits global', () {
      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
        displayOverrides: const CardDisplayOverrides(useSignGlyphs: true),
      );

      final resolved = resolver.resolve(card);

      expect(resolved.displayOptions.useSignGlyphs, isTrue);
      expect(
        resolved.displayOptions.usePlanetGlyphs,
        DisplayOptions.defaultOptions.usePlanetGlyphs,
      );
      expect(
        resolved.displayOptions.showOuterPlanets,
        DisplayOptions.defaultOptions.showOuterPlanets,
      );
      expect(
        resolved.displayOptions.signNames,
        DisplayOptions.defaultOptions.signNames,
      );
    });

    test('showOuterPlanets override applies', () {
      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
        displayOverrides: const CardDisplayOverrides(showOuterPlanets: false),
      );

      final resolved = resolver.resolve(card);

      expect(resolved.displayOptions.showOuterPlanets, isFalse);
      expect(
        resolved.displayOptions.useSignGlyphs,
        DisplayOptions.defaultOptions.useSignGlyphs,
      );
    });

    test(
      'signNames override replaces global list and clears preset source',
      () {
        final customNames = [
          'A1',
          'A2',
          'A3',
          'A4',
          'A5',
          'A6',
          'A7',
          'A8',
          'A9',
          'A10',
          'A11',
          'A12',
        ];
        final card = CardModel(
          id: 'card_0',
          label: 'Test',
          position: Offset.zero,
          size: const Size(200, 200),
          displayOverrides: CardDisplayOverrides(signNames: customNames),
        );

        final resolved = resolver.resolve(card);

        expect(resolved.displayOptions.signNames, customNames);
        expect(resolved.displayOptions.signPresetSource, isNull);
      },
    );

    test('opacityOverride flows through', () {
      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
        opacityOverride: 0.5,
      );

      final resolved = resolver.resolve(card);

      expect(resolved.cardOpacity, 0.5);
    });
  });

  group('resolve(card) with full overrides', () {
    test('all fields come from card overrides', () {
      final customNames = [
        'S1',
        'S2',
        'S3',
        'S4',
        'S5',
        'S6',
        'S7',
        'S8',
        'S9',
        'S10',
        'S11',
        'S12',
      ];
      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
        opacityOverride: 0.7,
        displayOverrides: CardDisplayOverrides(
          useSignGlyphs: true,
          usePlanetGlyphs: true,
          showOuterPlanets: false,
          signNames: customNames,
        ),
      );

      final resolved = resolver.resolve(card);

      expect(resolved.displayOptions.useSignGlyphs, isTrue);
      expect(resolved.displayOptions.usePlanetGlyphs, isTrue);
      expect(resolved.displayOptions.showOuterPlanets, isFalse);
      expect(resolved.displayOptions.signNames, customNames);
      expect(resolved.displayOptions.signPresetSource, isNull);
      expect(
        resolved.displayOptions.planetNames,
        DisplayOptions.defaultOptions.planetNames,
      );
      expect(resolved.cardOpacity, 0.7);
    });
  });

  group('different presets', () {
    test('immersive preset cardOpacity used when no card override', () {
      final immersiveResolver = const ThemeResolver(
        preset: ThemePreset.immersive,
        globalDisplayOptions: DisplayOptions.defaultOptions,
      );

      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
      );

      final resolved = immersiveResolver.resolve(card);

      expect(resolved.cardOpacity, ThemePreset.immersive.cardOpacity);
    });

    test('card opacityOverride wins over immersive preset', () {
      final immersiveResolver = const ThemeResolver(
        preset: ThemePreset.immersive,
        globalDisplayOptions: DisplayOptions.defaultOptions,
      );

      final card = CardModel(
        id: 'card_0',
        label: 'Test',
        position: Offset.zero,
        size: const Size(200, 200),
        opacityOverride: 1.0,
      );

      final resolved = immersiveResolver.resolve(card);

      expect(resolved.cardOpacity, 1.0);
    });
  });
}
