import 'package:aion/canvas/canvas_actions.dart';
import 'package:aion/canvas/canvas_card.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/action_menu.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/renderer/chart_renderer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(workspaceProvider.notifier)
        .addCard(const Offset(10, 10), const Size(200, 100), 'A');
    return c;
  }

  test('view mode is the default and locks the layout', () {
    final c = container();
    final n = c.read(workspaceProvider.notifier);
    expect(c.read(workspaceProvider).editMode, isFalse);
    n.moveCard('card_0', const Offset(50, 50), const Size(999, 999));
    n.resizeCard('card_0', const Offset(50, 50), ResizeCorner.bottomRight);
    n.handleKey(LogicalKeyboardKey.arrowRight);
    n.selectCard('card_0');
    n.handleKey(LogicalKeyboardKey.delete);
    final card = c.read(workspaceProvider).cardById('card_0');
    expect(card?.position, const Offset(10, 10));
    expect(card?.size, const Size(200, 100));
  });

  test('edit mode restores drag/resize/nudge/delete', () {
    final c = container();
    final n = c.read(workspaceProvider.notifier)..setEditMode(true);
    n.moveCard(
      'card_0',
      const Offset(5, 0),
      const Size(999, 999),
      applySnap: false,
    );
    n.resizeCard('card_0', const Offset(10, 0), ResizeCorner.bottomRight);
    final card = c.read(workspaceProvider).cardById('card_0');
    expect(card?.position, const Offset(15, 10));
    expect(card?.size.width, 210);
    n
      ..selectCard('card_0')
      ..handleKey(LogicalKeyboardKey.delete);
    expect(c.read(workspaceProvider).cards, isEmpty);
  });

  test('E key and registry action toggle edit mode', () async {
    final c = container();
    c.read(workspaceProvider.notifier).handleKey(LogicalKeyboardKey.keyE);
    expect(c.read(workspaceProvider).editMode, isTrue);
    final registry = c.read(actionRegistryProvider);
    final toggle = registry.get('workspace.toggle_edit');
    expect(toggle?.isChecked?.call(const ActionContext()), isTrue);
    await registry.execute('workspace.toggle_edit', const ActionContext());
    expect(c.read(workspaceProvider).editMode, isFalse);
  });

  test('canvas menu: add-view, edit toggle, workspace ops only', () {
    final c = container();
    final registry = c.read(actionRegistryProvider);
    const ctx = ActionContext();
    final metas = [
      for (final id in ['south_indian', 'data_table'])
        RendererMeta(id: id, displayName: id, systems: const []),
    ];
    final ids = [
      for (final a in resolveMenu(canvasMenuIds(metas), registry, ctx)) a?.id,
    ].whereType<String>().toList();
    expect(ids, [
      'view.add.south_indian',
      'view.add.data_table',
      'workspace.toggle_edit',
    ]);
    // Save-as appears once a prompt surface is available.
    final withPrompt = ActionContext(
      promptText: (title, {initial = ''}) async => null,
    );
    expect(
      resolveMenu(canvasMenuIds(metas), registry, withPrompt).map((a) => a?.id),
      contains('workspace.save_as'),
    );
  });

  test('add-view menu entries read "Add …"', () {
    final c = container();
    expect(
      c.read(actionRegistryProvider).get('view.add.data_table')?.menuTitle,
      'Add Data Table',
    );
  });
}
