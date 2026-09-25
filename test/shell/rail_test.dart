import 'package:aion/commands/action_registry.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/commands/view_actions.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/shell/catalog_flyout.dart';
import 'package:aion/shell/rail_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rail flyouts', () {
    test('one flyout at a time; tapping the open one closes it', () {
      expect(toggleRailSection(null, RailSection.catalog), RailSection.catalog);
      expect(
        toggleRailSection(RailSection.catalog, RailSection.slots),
        RailSection.slots,
      );
      expect(toggleRailSection(RailSection.slots, RailSection.slots), isNull);
    });

    test('notifier toggles and closes', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(railProvider.notifier).toggle(RailSection.catalog);
      expect(c.read(railProvider), RailSection.catalog);
      c.read(railProvider.notifier).close();
      expect(c.read(railProvider), isNull);
    });
  });

  group('catalog', () {
    test('groups view actions by category in catalog order', () {
      final registry = ActionRegistry([
        ...viewActionsFromRenderers(const [
          RendererMeta(id: 't', displayName: 'Table', systems: [], category: 'Tables'),
          RendererMeta(id: 'b', displayName: 'B chart', systems: []),
          RendererMeta(id: 'a', displayName: 'A chart', systems: []),
        ], onAdd: (_, _) {}),
        AppAction(
          id: 'not.a.view',
          title: 'Delete',
          category: ActionCategory.card,
          execute: (_) {},
        ),
      ]);
      final groups = catalogGroups(registry);
      expect([for (final (c, _) in groups) c], ['Charts', 'Tables']);
      expect([for (final a in groups.first.$2) a.title], ['A chart', 'B chart']);
    });

    test('new renderers appear with no catalog changes', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final groups = catalogGroups(c.read(actionRegistryProvider));
      final ids = [for (final (_, group) in groups) ...group.map((a) => a.id)];
      expect(ids, containsAll(['view.add.south_indian', 'view.add.data_table']));
    });
  });
}
