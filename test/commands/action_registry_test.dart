import 'package:aion/canvas/canvas_actions.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/action_matcher.dart';
import 'package:aion/commands/action_menu.dart';
import 'package:aion/commands/action_registry.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/commands/view_actions.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/renderer_aliases.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppAction _a(
  String id,
  String title, {
  String category = ActionCategory.charts,
  List<String> aliases = const [],
  bool requiresCard = false,
  bool enabled = true,
  void Function()? run,
}) => AppAction(
  id: id,
  title: title,
  category: category,
  aliases: aliases,
  requiresCard: requiresCard,
  isEnabled: (_) => enabled,
  execute: (_) => run?.call(),
);

final _metas = [
  RendererMeta(
    id: 'south_indian',
    displayName: 'South Indian Grid',
    systems: const ['vedic'],
    aliases: vargaAliases('d1'),
  ),
  RendererMeta(
    id: 'navamsa',
    displayName: 'Navamsa',
    systems: const ['vedic'],
    category: ActionCategory.vargas,
    aliases: vargaAliases('d9'),
  ),
  RendererMeta(
    id: 'vimshottari',
    displayName: 'Vimshottari Dasha',
    systems: const ['vedic'],
    category: ActionCategory.time,
    aliases: dashaAliases('vimshottari'),
  ),
  const RendererMeta(
    id: 'data_table',
    displayName: 'Data Table',
    systems: [],
    category: ActionCategory.tables,
    aliases: ['table'],
  ),
];

void main() {
  group('matcher', () {
    final actions = viewActionsFromRenderers(_metas, onAdd: (_, _) {});
    List<String> ids(String q) => [
      for (final a in rankActions(actions, q)) a.id,
    ];

    test('domain aliases hit', () {
      expect(ids('d9').first, 'view.add.navamsa');
      expect(ids('vim').first, 'view.add.vimshottari');
      expect(ids('d1').first, 'view.add.south_indian');
      expect(ids('rasi').first, 'view.add.south_indian');
    });

    test('exact alias beats title substring', () {
      final a = _a('x', 'Table of Contents');
      final b = _a('y', 'Something', aliases: ['table']);
      expect(rankActions([a, b], 'table').first.id, 'y');
    });

    test('title prefix beats word prefix beats substring', () {
      final prefix = _a('p', 'Grid view');
      final word = _a('w', 'South Grid');
      final sub = _a('s', 'Subgridded');
      expect(
        [
          for (final a in rankActions([sub, word, prefix], 'grid')) a.id,
        ],
        ['p', 'w', 's'],
      );
    });

    test('fuzzy subsequence matches and prefers tight matches', () {
      expect(ids('sig'), contains('view.add.south_indian'));
      expect(fuzzySubsequenceScore('data table', 'dtt'), isNotNull);
      expect(fuzzySubsequenceScore('data table', 'xyz'), isNull);
      final tight = fuzzySubsequenceScore('navamsa', 'nvm');
      final loose = fuzzySubsequenceScore('n a v a m s a chart', 'nvm');
      expect(tight, greaterThan(loose ?? 0));
    });

    test('no match excluded; case insensitive', () {
      expect(ids('zzzz'), isEmpty);
      expect(ids('NAVAMSA').first, 'view.add.navamsa');
    });

    test('empty query lists all by category order', () {
      expect(ids(''), [
        'view.add.south_indian',
        'view.add.navamsa',
        'view.add.data_table',
        'view.add.vimshottari',
      ]);
    });
  });

  group('registry', () {
    test('view actions generated per renderer with category and aliases', () {
      final added = <String>[];
      final registry = ActionRegistry(
        viewActionsFromRenderers(_metas, onAdd: (m, _) => added.add(m.id)),
      );
      expect(
        registry.inCategory(ActionCategory.vargas).single.title,
        'Navamsa',
      );
      expect(registry.categories, [
        ActionCategory.charts,
        ActionCategory.vargas,
        ActionCategory.tables,
        ActionCategory.time,
      ]);
      registry.execute(addViewActionId('navamsa'), const ActionContext());
      expect(added, ['navamsa']);
    });

    test(
      'card-scoped actions need a card; disabled actions do not run',
      () async {
        var ran = 0;
        final registry = ActionRegistry([
          _a('card', 'Card op', requiresCard: true, run: () => ran++),
          _a('off', 'Off', enabled: false, run: () => ran++),
        ]);
        expect(await registry.execute('card', const ActionContext()), isFalse);
        expect(await registry.execute('off', const ActionContext()), isFalse);
        expect(
          await registry.execute('card', const ActionContext(cardId: 'c')),
          isTrue,
        );
        expect(ran, 1);
        expect(registry.search('', const ActionContext()), isEmpty);
      },
    );

    test('resolveMenu drops disabled items and collapses dividers', () {
      final registry = ActionRegistry([
        _a('a', 'A'),
        _a('b', 'B', enabled: false),
        _a('c', 'C'),
      ]);
      final menu = resolveMenu(
        [null, 'a', null, 'b', null, null, 'missing', 'c', null],
        registry,
        const ActionContext(),
      );
      expect([for (final m in menu) m?.id], ['a', null, 'c']);
    });
  });

  group('canvas actions', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('add view binds the new card to the active slot', () async {
      final c = container();
      final slotId = c.read(slotsProvider.notifier).addSlot();
      c.read(slotsProvider.notifier).setActive(slotId);
      await c
          .read(actionRegistryProvider)
          .execute(addViewActionId('data_table'), const ActionContext());
      final card = c.read(workspaceProvider).cards.single;
      expect(card.binding, SlotBinding(slotId));
      expect(card.rendererType, 'data_table');
    });

    test('card menu consumes the registry: every id exists', () {
      final c = container();
      final registry = c.read(actionRegistryProvider);
      final metas = _metas.where(
        (m) => m.id == 'south_indian' || m.id == 'data_table',
      );
      final layout = [
        ...cardMenuIds(metas, c.read(slotsProvider).slots),
        ...canvasMenuIds(metas),
      ];
      for (final id in layout.whereType<String>()) {
        expect(registry.get(id), isNotNull, reason: id);
      }
    });

    test('unbound card hides chart-only card actions', () {
      final c = container();
      c
          .read(workspaceProvider.notifier)
          .addCard(Offset.zero, const Size(10, 10), 'placeholder');
      final registry = c.read(actionRegistryProvider);
      const ctx = ActionContext(cardId: 'card_0');
      expect(
        registry.get('card.open_as.south_indian')?.enabledIn(ctx),
        isFalse,
      );
      expect(registry.get('card.duplicate')?.enabledIn(ctx), isTrue);
    });

    test('per-slot actions follow the slot list', () {
      final c = container();
      expect(c.read(actionRegistryProvider).get('slot.bind.B'), isNull);
      c.read(slotsProvider.notifier).addSlot();
      expect(c.read(actionRegistryProvider).get('slot.bind.B'), isNotNull);
    });
  });
}
