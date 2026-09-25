import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:aion/theme/display_options.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:aion/theme/theme_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings rect is ~80% of the viewport, centered', () {
    final r = settingsCardRect(const Size(1000, 800));
    expect(r, const Rect.fromLTWH(100, 80, 800, 640));
  });

  test('settings rect respects a minimum size but fits the viewport', () {
    expect(settingsCardRect(const Size(500, 400)).size, const Size(480, 360));
    expect(settingsCardRect(const Size(300, 200)).size, const Size(300, 200));
  });

  test('settings action opens one settings card, then re-selects it', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final registry = c.read(actionRegistryProvider);
    const ctx = ActionContext(viewportSize: Size(1000, 800));
    await registry.execute('settings.open', ctx);
    await registry.execute('settings.open', ctx);
    final cards = c.read(workspaceProvider).cards;
    expect(cards, hasLength(1));
    expect(cards.single.kind, CardKind.settings);
    expect(cards.single.binding, isNull);
    expect(c.read(workspaceProvider).selectedId, cards.single.id);
  });

  test('settings card has no slot strip and no display toggles', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final registry = c.read(actionRegistryProvider);
    await registry.execute(
      'settings.open',
      const ActionContext(viewportSize: Size(1000, 800)),
    );
    final card = c.read(workspaceProvider).cards.single;
    const resolver = ThemeResolver(
      preset: ThemePreset.dark,
      globalDisplayOptions: DisplayOptions.defaultOptions,
    );
    expect(resolver.stripFor(card, c.read(slotsProvider)), isNull);
    final ctx = ActionContext(cardId: card.id);
    expect(
      registry.get('display.toggle.useSignGlyphs')?.enabledIn(ctx),
      isFalse,
    );
    expect(registry.get('card.duplicate')?.enabledIn(ctx), isFalse);
  });

  test('DisplayOptions.copyWith changes only toggles', () {
    final next = DisplayOptions.defaultOptions.copyWith(useSignGlyphs: true);
    expect(next.useSignGlyphs, isTrue);
    expect(next.signNames, DisplayOptions.defaultOptions.signNames);
    expect(
      next.showOuterPlanets,
      DisplayOptions.defaultOptions.showOuterPlanets,
    );
  });
}
