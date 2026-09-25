import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/theme/card_display_overrides.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  void seedCards(ProviderContainer container) {
    final notifier = container.read(workspaceProvider.notifier);
    notifier.addCard(const Offset(40, 60), const Size(240, 160), 'Card A');
    notifier.addCard(const Offset(40, 260), const Size(240, 160), 'Card B');
  }

  test('workspace starts empty', () {
    final container = createContainer();

    final state = container.read(workspaceProvider);

    expect(state.cards, isEmpty);
    expect(state.cardCounter, 0);
    expect(state.nextZ, 0);
  });

  test('selecting a card records selection and brings it forward', () {
    final container = createContainer();
    seedCards(container);
    final notifier = container.read(workspaceProvider.notifier);

    notifier.selectCard('card_0');
    final state = container.read(workspaceProvider);

    expect(state.selectedId, 'card_0');
    expect(state.cardById('card_0')!.zOrder, 2);
    expect(state.nextZ, 3);
  });

  test('moves a card without mutating the original model instance', () {
    final container = createContainer();
    seedCards(container);
    // Layout edits require edit mode (aion/71).
    container.read(workspaceProvider.notifier).setEditMode(true);
    final notifier = container.read(workspaceProvider.notifier);
    final original = container.read(workspaceProvider).cardById('card_0')!;

    notifier.moveCard(
      'card_0',
      const Offset(12, 8),
      const Size(4000, 4000),
      applySnap: false,
    );
    final moved = container.read(workspaceProvider).cardById('card_0')!;

    expect(moved.position, original.position + const Offset(12, 8));
    expect(identical(original, moved), isFalse);
  });

  test('duplicate and delete update cards and selection', () {
    final container = createContainer();
    seedCards(container);
    final notifier = container.read(workspaceProvider.notifier);
    final initialCount = container.read(workspaceProvider).cards.length;
    final source = container.read(workspaceProvider).cardById('card_1')!;

    notifier.selectCard('card_1');
    notifier.duplicateCard('card_1');
    var state = container.read(workspaceProvider);

    expect(state.cards, hasLength(initialCount + 1));
    final duplicate = state.cardById('card_$initialCount')!;
    expect(duplicate.label, '${source.label} (copy)');
    expect(duplicate.size, source.size);

    notifier.deleteCard('card_1');
    state = container.read(workspaceProvider);

    expect(state.cards, hasLength(initialCount));
    expect(state.cardById('card_1'), isNull);
    expect(state.selectedId, isNull);
  });

  test('keyboard actions move, cycle, delete, and toggle snap', () {
    final container = createContainer();
    seedCards(container);
    // Layout edits require edit mode (aion/71).
    container.read(workspaceProvider.notifier).setEditMode(true);
    final notifier = container.read(workspaceProvider.notifier);
    final originalPos = container
        .read(workspaceProvider)
        .cardById('card_0')!
        .position;
    final initialSnap = container.read(workspaceProvider).snapEnabled;

    notifier.selectCard('card_0');
    notifier.handleKey(LogicalKeyboardKey.arrowRight);
    expect(
      container.read(workspaceProvider).cardById('card_0')!.position,
      originalPos + const Offset(10, 0),
    );

    notifier.handleKey(LogicalKeyboardKey.tab);
    expect(container.read(workspaceProvider).selectedId, 'card_1');

    notifier.handleKey(LogicalKeyboardKey.keyS);
    expect(container.read(workspaceProvider).snapEnabled, !initialSnap);

    notifier.handleKey(LogicalKeyboardKey.delete);
    expect(container.read(workspaceProvider).cardById('card_1'), isNull);
    expect(container.read(workspaceProvider).selectedId, isNull);
  });

  group('setCardRenderer', () {
    test('changes renderer and clears displayConfig', () {
      final container = createContainer();
      final notifier = container.read(workspaceProvider.notifier);
      const ref = SlotBinding('A');
      notifier.addCard(
        const Offset(0, 0),
        const Size(500, 500),
        'Test',
        binding: ref,
        rendererType: 'south_indian',
        preferredAspectRatio: 1.0,
      );

      notifier.setCardRenderer(
        'card_0',
        'data_table',
        preferredAspectRatio: null,
      );
      final card = container.read(workspaceProvider).cardById('card_0')!;

      expect(card.rendererType, 'data_table');
      expect(card.displayConfig, isEmpty);
      expect(card.preferredAspectRatio, isNull);
      expect(card.binding, ref);
    });
  });

  group('updateCardDisplayOverrides', () {
    test('applies overrides to card', () {
      final container = createContainer();
      seedCards(container);
      final notifier = container.read(workspaceProvider.notifier);

      notifier.updateCardDisplayOverrides(
        'card_0',
        const CardDisplayOverrides(useSignGlyphs: true),
      );
      final card = container.read(workspaceProvider).cardById('card_0')!;

      expect(card.displayOverrides.useSignGlyphs, true);
      expect(card.displayOverrides.usePlanetGlyphs, isNull);
    });

    test('does not affect other cards', () {
      final container = createContainer();
      seedCards(container);
      final notifier = container.read(workspaceProvider.notifier);

      notifier.updateCardDisplayOverrides(
        'card_0',
        const CardDisplayOverrides(showOuterPlanets: false),
      );
      final other = container.read(workspaceProvider).cardById('card_1')!;

      expect(other.displayOverrides.isEmpty, isTrue);
    });
  });

  group('resetCardSize', () {
    test('changes size and preserves position', () {
      final container = createContainer();
      seedCards(container);
      final notifier = container.read(workspaceProvider.notifier);
      final original = container.read(workspaceProvider).cardById('card_0')!;

      notifier.resetCardSize('card_0', const Size(500, 500));
      final card = container.read(workspaceProvider).cardById('card_0')!;

      expect(card.size, const Size(500, 500));
      expect(card.position, original.position);
    });
  });

  group('duplicateCard preserves display state', () {
    test('copies displayConfig and displayOverrides', () {
      final container = createContainer();
      final notifier = container.read(workspaceProvider.notifier);
      notifier.addCard(
        const Offset(0, 0),
        const Size(500, 400),
        'Source',
        rendererType: 'data_table',
      );

      notifier.updateCardDisplayOverrides(
        'card_0',
        const CardDisplayOverrides(useSignGlyphs: true),
      );

      notifier.duplicateCard('card_0');
      final copy = container.read(workspaceProvider).cardById('card_1')!;

      expect(copy.displayOverrides.useSignGlyphs, true);
      expect(copy.rendererType, 'data_table');
    });
  });

  test('snap toggle clears active guides', () {
    final container = createContainer();
    seedCards(container);
    // Layout edits require edit mode (aion/71).
    container.read(workspaceProvider.notifier).setEditMode(true);
    final notifier = container.read(workspaceProvider.notifier);

    if (!container.read(workspaceProvider).snapEnabled) {
      notifier.toggleSnap();
    }

    notifier.moveCard('card_0', const Offset(5, 0), const Size(4000, 4000));
    expect(container.read(workspaceProvider).guides, isNotEmpty);

    notifier.toggleSnap();
    final state = container.read(workspaceProvider);

    expect(state.snapEnabled, isFalse);
    expect(state.guides, isEmpty);
  });
}
