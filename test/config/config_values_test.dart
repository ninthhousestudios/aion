import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/config/arrow_dimensions.dart';
import 'package:aion/config/config_dimension.dart';
import 'package:aion/config/config_values.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('config values', () {
    test('missing key reads as default', () {
      expect(configValue(const {}, signAyanamsa), 'tropical');
      expect(configValue(const {}, bodies), bodies.defaultValue);
    });

    test('set stores non-default, default removes key', () {
      final c = setConfigValue(const {}, signAyanamsa, 'lahiri');
      expect(c, {'signAyanamsa': 'lahiri'});
      expect(setConfigValue(c, signAyanamsa, 'tropical'), isEmpty);
    });

    test('multi-select stored as sorted list, read back as set', () {
      final c = setConfigValue(const {}, stars, {'b', 'a'});
      expect(c['stars'], ['a', 'b']);
      expect(configValue(c, stars), {'a', 'b'});
      expect(setConfigValue(c, stars, <String>{}), isEmpty);
    });

    test('format values', () {
      expect(formatConfigValue(signAyanamsa, 'lahiri'), 'Lahiri');
      expect(formatConfigValue(trueNode, true), 'On');
      expect(formatConfigValue(stars, <String>{}), 'None');
      expect(formatConfigValue(bodies, {'a', 'b', 'c', 'd'}), '4 selected');
    });

    test('section stage from dimension costs', () {
      expect(sectionStage([signAyanamsa]), ConfigStage.swe);
      expect(sectionStage([circle]), ConfigStage.calc);
      expect(sectionStage([signAyanamsa, circle]), ConfigStage.mixed);
    });

    test('sections ordered by group sortOrder, all dimensions covered', () {
      final sections = configSections();
      final orders = [for (final (g, _) in sections) g.sortOrder];
      expect(orders, [...orders]..sort());
      final covered = [for (final (_, d) in sections) ...d];
      expect(covered.length, kDimensions.length);
    });

    test('every dimension has a group from kGroups', () {
      for (final d in kDimensions) {
        expect(kGroups, contains(d.group), reason: d.key);
        expect(validateValue(d, d.defaultValue), isNull, reason: d.key);
      }
    });
  });

  group('config actions', () {
    test('card config edits a per-card override seeded from slot config', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(slotsProvider.notifier).setConfig('A', {'signAyanamsa': 'lahiri'});
      c
          .read(workspaceProvider.notifier)
          .addCard(
            Offset.zero,
            const Size(10, 10),
            'x',
            binding: const SlotBinding('A'),
          );
      ConfigEditRequest? request;
      final ctx = ActionContext(
        cardId: 'card_0',
        editConfig: (r) => request = r,
      );
      final registry = c.read(actionRegistryProvider);
      registry.execute('card.config', ctx);
      expect(request?.initial, {'signAyanamsa': 'lahiri'});
      request?.onChanged({'signAyanamsa': 'raman'});
      expect(c.read(workspaceProvider).cardById('card_0')?.configOverride, {
        'signAyanamsa': 'raman',
      });
      // Slot config untouched: the override is the exception.
      expect(c.read(slotsProvider).slotById('A')?.config, {
        'signAyanamsa': 'lahiri',
      });
      registry.execute('card.clear_config', ctx);
      expect(
        c.read(workspaceProvider).cardById('card_0')?.configOverride,
        isNull,
      );
    });

    test('slot config action edits the slot', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      ConfigEditRequest? request;
      c
          .read(actionRegistryProvider)
          .execute(
            'slot.config.A',
            ActionContext(editConfig: (r) => request = r),
          );
      request?.onChanged({'houseSystem': 'placidus'});
      expect(c.read(slotsProvider).slotById('A')?.config, {
        'houseSystem': 'placidus',
      });
    });

    test('config actions disabled without an editor surface', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final a = c.read(actionRegistryProvider).get('slot.config.A');
      expect(a?.enabledIn(const ActionContext()), isFalse);
      expect(ConfigDimensionType.values, isNotEmpty);
    });
  });
}
