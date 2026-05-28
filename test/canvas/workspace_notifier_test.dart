import 'package:aion/canvas/workspace_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('seeds default workspace cards', () {
    final container = createContainer();

    final state = container.read(workspaceProvider);

    expect(state.cards, hasLength(4));
    expect(state.cards.first.label, 'Chart Wheel');
    expect(state.cardCounter, 4);
    expect(state.nextZ, 4);
  });

  test('selecting a card records selection and brings it forward', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.selectCard('card_0');
    final state = container.read(workspaceProvider);

    expect(state.selectedId, 'card_0');
    expect(state.cardById('card_0')!.zOrder, 4);
    expect(state.nextZ, 5);
  });

  test('moves a card without mutating the original model instance', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);
    final original = container.read(workspaceProvider).cardById('card_0')!;

    notifier.moveCard(
      'card_0',
      const Offset(12, 8),
      const Size(4000, 4000),
      applySnap: false,
    );
    final moved = container.read(workspaceProvider).cardById('card_0')!;

    expect(original.position, const Offset(60, 60));
    expect(moved.position, const Offset(72, 68));
    expect(identical(original, moved), isFalse);
  });

  test('duplicate and delete update cards and selection', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.selectCard('card_1');
    notifier.duplicateCard('card_1');
    var state = container.read(workspaceProvider);

    expect(state.cards, hasLength(5));
    expect(state.cardById('card_4')!.label, 'Planet Table (copy)');
    expect(state.cardById('card_4')!.size, const Size(280, 200));

    notifier.deleteCard('card_1');
    state = container.read(workspaceProvider);

    expect(state.cards, hasLength(4));
    expect(state.cardById('card_1'), isNull);
    expect(state.selectedId, isNull);
  });

  test('keyboard actions move, cycle, delete, and toggle snap', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.selectCard('card_0');
    notifier.handleKey(LogicalKeyboardKey.arrowRight);
    expect(
      container.read(workspaceProvider).cardById('card_0')!.position,
      const Offset(70, 60),
    );

    notifier.handleKey(LogicalKeyboardKey.tab);
    expect(container.read(workspaceProvider).selectedId, 'card_1');

    notifier.handleKey(LogicalKeyboardKey.keyS);
    expect(container.read(workspaceProvider).snapEnabled, isFalse);

    notifier.handleKey(LogicalKeyboardKey.delete);
    expect(container.read(workspaceProvider).cardById('card_1'), isNull);
    expect(container.read(workspaceProvider).selectedId, isNull);
  });

  test('snap toggle clears active guides', () {
    final container = createContainer();
    final notifier = container.read(workspaceProvider.notifier);

    notifier.moveCard('card_0', const Offset(30, 0), const Size(4000, 4000));
    expect(container.read(workspaceProvider).guides, isNotEmpty);

    notifier.toggleSnap();
    final state = container.read(workspaceProvider);

    expect(state.snapEnabled, isFalse);
    expect(state.guides, isEmpty);
  });
}
