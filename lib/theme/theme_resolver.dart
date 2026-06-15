import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/card_model.dart';
import 'aion_theme.dart';
import 'card_display_overrides.dart';
import 'display_options.dart';
import 'display_options_store.dart';
import 'preset_store.dart';
import 'resolved_theme.dart';
import 'theme_preset.dart';

class ThemeResolver {
  const ThemeResolver({
    required this.preset,
    required this.globalDisplayOptions,
  });

  final ThemePreset preset;
  final DisplayOptions globalDisplayOptions;

  ResolvedTheme resolve(CardModel? card) {
    final theme = AionTheme.fromPreset(preset);

    if (card == null) {
      return ResolvedTheme(
        theme: theme,
        displayOptions: globalDisplayOptions,
        cardOpacity: preset.cardOpacity,
      );
    }

    final overrides = card.displayOverrides;
    final displayOptions = overrides.isEmpty
        ? globalDisplayOptions
        : _mergeDisplayOptions(overrides);

    return ResolvedTheme(
      theme: theme,
      displayOptions: displayOptions,
      cardOpacity: card.opacityOverride ?? preset.cardOpacity,
    );
  }

  DisplayOptions _mergeDisplayOptions(CardDisplayOverrides overrides) {
    return DisplayOptions(
      signNames: overrides.signNames ?? globalDisplayOptions.signNames,
      signPresetSource: overrides.signNames != null
          ? null
          : globalDisplayOptions.signPresetSource,
      planetNames: globalDisplayOptions.planetNames,
      planetPresetSource: globalDisplayOptions.planetPresetSource,
      useSignGlyphs:
          overrides.useSignGlyphs ?? globalDisplayOptions.useSignGlyphs,
      usePlanetGlyphs:
          overrides.usePlanetGlyphs ?? globalDisplayOptions.usePlanetGlyphs,
      showOuterPlanets:
          overrides.showOuterPlanets ?? globalDisplayOptions.showOuterPlanets,
    );
  }
}

final themeResolverProvider = Provider<ThemeResolver>((ref) {
  final presetStore = ref.watch(presetStoreProvider).valueOrNull;
  final displayStore = ref.watch(displayOptionsProvider).valueOrNull;
  return ThemeResolver(
    preset: presetStore?.activePreset ?? ThemePreset.dark,
    globalDisplayOptions:
        displayStore?.options ?? DisplayOptions.defaultOptions,
  );
});
