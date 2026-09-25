import 'dart:io';
import 'dart:ui';

import 'package:aion/canvas/card_model.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:aion/theme/card_display_overrides.dart';
import 'package:aion/workspaces/workspace.dart';
import 'package:aion/workspaces/workspace_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _full = Workspace(
  name: 'Natal "Reading"',
  cards: [
    WorkspaceCard(
      label: 'Rasi',
      rect: Rect.fromLTWH(10, 20, 500, 500),
      rendererType: 'south_indian',
      binding: SlotBinding('B'),
      configOverride: {
        'signAyanamsa': 'raman',
        'stars': ['a', 'b'],
      },
      displayConfig: {'show_house_cusps': true},
      displayOverrides: CardDisplayOverrides(
        useSignGlyphs: true,
        signNames: ['Ar', 'Ta'],
      ),
      opacityOverride: 0.5,
      preferredAspectRatio: 1,
    ),
    WorkspaceCard(
      label: 'Reference',
      rect: Rect.fromLTWH(520, 20, 400, 300),
      rendererType: 'data_table',
      binding: PinnedBinding(
        chartId: '/charts/ref.toml',
        chartName: 'Ref',
        config: {'houseSystem': 'placidus'},
      ),
    ),
    WorkspaceCard(
      label: 'Settings',
      rect: Rect.fromLTWH(0, 0, 800, 600),
      kind: CardKind.settings,
    ),
  ],
);

void main() {
  group('TOML round-trip', () {
    test('all fields survive', () {
      final back = Workspace.fromToml(_full.toToml());
      expect(back.name, _full.name);
      expect(back.cards, hasLength(3));
      final a = back.cards[0];
      expect(a.label, 'Rasi');
      expect(a.rect, const Rect.fromLTWH(10, 20, 500, 500));
      expect(a.rendererType, 'south_indian');
      expect(a.binding, const SlotBinding('B'));
      expect(a.configOverride, {
        'signAyanamsa': 'raman',
        'stars': ['a', 'b'],
      });
      expect(a.displayConfig, {'show_house_cusps': true});
      expect(
        a.displayOverrides,
        const CardDisplayOverrides(
          useSignGlyphs: true,
          signNames: ['Ar', 'Ta'],
        ),
      );
      expect(a.opacityOverride, 0.5);
      expect(a.preferredAspectRatio, 1.0);
      expect(
        back.cards[1].binding,
        const PinnedBinding(
          chartId: '/charts/ref.toml',
          chartName: 'Ref',
          config: {'houseSystem': 'placidus'},
        ),
      );
      expect(back.cards[1].configOverride, isNull);
      expect(back.cards[2].kind, CardKind.settings);
      expect(back.cards[2].binding, isNull);
    });

    test('no chart data is written for slot-bound cards', () {
      final toml = _full.toToml();
      expect(toml, isNot(contains('jd')));
      expect(toml, contains("slot = 'B'"));
    });

    test('unknown keys tolerated, malformed cards skipped', () {
      final ws = Workspace.fromToml('''
name = "X"
future_setting = 3

[[cards]]
label = "ok"
x = 1
y = 2
width = 3
height = 4
kind = "hologram"
sparkle = true
[cards.binding]
type = "slot"
slot = "A"
extra = "?"

[[cards]]
label = "no geometry"
''');
      expect(ws.cards, hasLength(1));
      expect(ws.cards.single.kind, CardKind.chart);
      expect(ws.cards.single.rect, const Rect.fromLTWH(1, 2, 3, 4));
    });

    test('missing name is a format error', () {
      expect(() => Workspace.fromToml('x = 1'), throwsFormatException);
      expect(() => Workspace.fromToml('not toml ['), throwsFormatException);
    });
  });

  group('slot resolution on load', () {
    test('dangling slot ids resolve to the default slot', () {
      final card = _full.cards.first.toCard(
        id: 'c',
        zOrder: 0,
        slots: SlotState.initial(),
      );
      expect(card.binding, const SlotBinding(SlotState.kDefaultSlotId));
    });

    test('existing slot ids are kept', () {
      final slots = SlotState.initial().copyWith(
        slots: [
          SlotState.defaultSlot,
          SlotState.defaultSlot.copyWith(label: 'B').withId('B'),
        ],
      );
      final card = _full.cards.first.toCard(id: 'c', zOrder: 0, slots: slots);
      expect(card.binding, const SlotBinding('B'));
    });
  });

  group('save / load', () {
    late Directory dir;
    late ProviderContainer c;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('aion_ws_');
      c = ProviderContainer(
        overrides: [
          workspaceStoreProvider.overrideWithValue(
            WorkspaceStore(configDir: dir.path),
          ),
          starterWorkspacesProvider.overrideWithValue(const [
            Workspace(name: 'Starter', cards: [], readOnly: true),
          ]),
        ],
      );
    });

    tearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });

    test('save current layout, reload it after clearing', () async {
      await c.read(workspaceLibraryProvider.future);
      c
          .read(workspaceProvider.notifier)
          .addCard(
            const Offset(5, 6),
            const Size(300, 200),
            'T',
            binding: const SlotBinding('A'),
            rendererType: 'data_table',
          );
      final notifier = c.read(workspaceLibraryProvider.notifier);
      expect(await notifier.saveCurrentAs('Mine'), isNull);
      c.read(workspaceProvider.notifier).replaceCards(const []);
      expect(c.read(workspaceProvider).cards, isEmpty);

      notifier.load('Mine');
      final card = c.read(workspaceProvider).cards.single;
      expect(card.position, const Offset(5, 6));
      expect(card.rendererType, 'data_table');
      expect(card.binding, const SlotBinding('A'));
      expect(c.read(workspaceLibraryProvider).valueOrNull?.activeName, 'Mine');

      // Persisted to disk and readable by a fresh store.
      final onDisk = await WorkspaceStore(configDir: dir.path).loadAll();
      expect(onDisk.single.name, 'Mine');
    });

    test('starter names and empty names are refused', () async {
      await c.read(workspaceLibraryProvider.future);
      final notifier = c.read(workspaceLibraryProvider.notifier);
      expect(
        await notifier.saveCurrentAs('Starter'),
        WorkspaceNameError.starter,
      );
      expect(await notifier.saveCurrentAs('  '), WorkspaceNameError.empty);
    });

    test(
      'replaceCards reuses ids by position, then mints, and sets z-order',
      () {
        final n = c.read(workspaceProvider.notifier)
          ..addCard(Offset.zero, const Size(1, 1), 'old');
        n.replaceCards([
          for (final w in _full.cards)
            w.toCard(id: 'x', zOrder: 9, slots: SlotState.initial()),
        ]);
        final cards = c.read(workspaceProvider).cards;
        expect({for (final card in cards) card.id}, hasLength(3));
        expect([for (final card in cards) card.zOrder], [0, 1, 2]);
        expect(
          [for (final card in cards) card.id],
          ['card_0', 'card_1', 'card_2'],
        );
        expect(c.read(workspaceProvider).cardCounter, 3);
        expect(c.read(workspaceProvider).layoutEpoch, 1);
      },
    );
  });
}
