import 'package:aion/commands/action_registry.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/commands/view_actions.dart';
import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/renderer_aliases.dart';
import 'package:aion/shell/palette_entries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = ActionRegistry([
    ...viewActionsFromRenderers([
      RendererMeta(
        id: 'navamsa',
        displayName: 'Navamsa',
        systems: const [],
        category: ActionCategory.vargas,
        aliases: vargaAliases('d9'),
      ),
      const RendererMeta(
        id: 'si',
        displayName: 'South Indian Grid',
        systems: [],
      ),
    ], onAdd: (_, _) {}),
    AppAction(
      id: 'card.delete',
      title: 'Delete',
      category: ActionCategory.card,
      requiresCard: true,
      execute: (_) {},
    ),
    AppAction(
      id: 'workspace.toggle_snap',
      title: 'Snap to Edges',
      category: ActionCategory.workspace,
      execute: (_) {},
    ),
  ]);

  List<String> labels(List<PaletteEntry> entries) => [
    for (final e in entries)
      switch (e) {
        PaletteCategoryEntry(:final category) => 'cat:$category',
        PaletteActionEntry(:final action) => action.id,
      },
  ];

  test('empty query shows browsable categories of enabled actions', () {
    expect(labels(paletteEntries(registry, const ActionContext())), [
      'cat:Charts',
      'cat:Vargas',
      'cat:Workspace',
    ]);
    // Card actions show up once a card is selected.
    expect(
      labels(paletteEntries(registry, const ActionContext(cardId: 'c'))),
      contains('cat:Card'),
    );
  });

  test('category with empty query lists its actions', () {
    expect(
      labels(
        paletteEntries(registry, const ActionContext(), category: 'Vargas'),
      ),
      ['view.add.navamsa'],
    );
  });

  test('query uses the shared matcher including aliases', () {
    expect(
      labels(
        paletteEntries(registry, const ActionContext(), query: 'd9'),
      ).first,
      'view.add.navamsa',
    );
    expect(
      labels(paletteEntries(registry, const ActionContext(), query: 'snap')),
      ['workspace.toggle_snap'],
    );
  });

  test('query within a category is filtered to it', () {
    expect(
      labels(
        paletteEntries(
          registry,
          const ActionContext(),
          query: 'grid',
          category: 'Vargas',
        ),
      ),
      isEmpty,
    );
  });

  test('selection wraps', () {
    expect(moveSelection(0, -1, 3), 2);
    expect(moveSelection(2, 1, 3), 0);
    expect(moveSelection(0, 1, 0), 0);
  });
}
