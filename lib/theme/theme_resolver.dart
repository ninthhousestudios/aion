import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/card_model.dart';
import '../slots/card_binding.dart';
import '../slots/slot_state.dart';
import 'aion_theme.dart';
import 'card_display_overrides.dart';
import 'display_options.dart';
import 'display_options_store.dart';
import 'preset_store.dart';
import 'resolved_theme.dart';
import 'theme_preset.dart';

/// What a card's status strip shows: its link-group color, plus whether the
/// card is pinned (and so no longer follows a slot).
class CardStrip {
  const CardStrip({required this.color, required this.pinned});

  final Color color;
  final bool pinned;

  @override
  bool operator ==(Object other) =>
      other is CardStrip && other.color == color && other.pinned == pinned;

  @override
  int get hashCode => Object.hash(color, pinned);
}

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

  /// Status strip for [card]: slot-bound cards show their slot's color
  /// (a dangling slot id falls back to the default slot, matching expression
  /// resolution); pinned cards show a neutral strip with a pin; unbound cards
  /// (placeholders, settings) show no strip.
  CardStrip? stripFor(CardModel card, SlotState slots) {
    final theme = AionTheme.fromPreset(preset);
    return switch (card.binding) {
      SlotBinding(:final slotId) => CardStrip(
        color: theme.slotColor(slots.slotOrDefault(slotId).colorIndex),
        pinned: false,
      ),
      PinnedBinding() => CardStrip(color: theme.cardDimColor, pinned: true),
      null => null,
    };
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
