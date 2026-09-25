import 'dart:io';
import 'dart:ui';

import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/slots/expression_resolution.dart';
import 'package:aion/slots/slot_state.dart';
import 'package:aion/workspaces/workspace.dart';
import 'package:aion/workspaces/workspace_actions.dart';
import 'package:aion/workspaces/workspace_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _starter = Workspace(
  name: 'Starter',
  readOnly: true,
  cards: [
    WorkspaceCard(
      label: 'Grid',
      rect: Rect.fromLTWH(0, 0, 400, 400),
      rendererType: 'south_indian',
      binding: SlotBinding('A'),
    ),
  ],
);

void main() {
  late Directory dir;
  late ProviderContainer c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('aion_ws_');
    c = ProviderContainer(
      overrides: [
        workspaceStoreProvider.overrideWithValue(
          WorkspaceStore(configDir: dir.path),
        ),
        starterWorkspacesProvider.overrideWithValue(const [_starter]),
      ],
    );
    await c.read(workspaceLibraryProvider.future);
  });

  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  test('reuseCardIds reuses then mints', () {
    final (ids, counter) = reuseCardIds(['card_3', 'card_7'], 3, 8);
    expect(ids, ['card_3', 'card_7', 'card_8']);
    expect(counter, 9);
    final (fewer, same) = reuseCardIds(['card_3', 'card_7'], 1, 8);
    expect(fewer, ['card_3']);
    expect(same, 8);
  });

  test('switching keeps slots; cards resolve against the live slot', () {
    c.read(slotsProvider.notifier).setChart('A', 'client', chartName: 'Ravi');
    c.read(workspaceLibraryProvider.notifier).load('Starter');
    final card = c.read(workspaceProvider).cards.single;
    expect(c.read(slotsProvider).slotById('A')?.chartId, 'client');
    expect(
      resolveCardExpression(card.binding, c.read(slotsProvider))?.chartId,
      'client',
    );
  });

  test('switch actions exist per workspace and mark the active one', () async {
    final registry = c.read(actionRegistryProvider);
    await registry.execute(
      workspaceLoadActionId('Starter'),
      const ActionContext(),
    );
    expect(
      registry
          .get(workspaceLoadActionId('Starter'))
          ?.isChecked
          ?.call(const ActionContext()),
      isTrue,
    );
    expect(registry.get(workspaceRenameActionId('Starter')), isNull);
    expect(registry.get(workspaceDeleteActionId('Starter')), isNull);
  });

  test('rename and delete user workspaces; starters protected', () async {
    final n = c.read(workspaceLibraryProvider.notifier);
    await n.saveCurrentAs('Mine');
    expect(await n.rename('Mine', 'Starter'), WorkspaceNameError.starter);
    expect(await n.rename('Starter', 'X'), WorkspaceNameError.starter);
    await n.saveCurrentAs('Other');
    expect(await n.rename('Mine', 'Other'), WorkspaceNameError.exists);
    expect(await n.rename('Mine', 'Renamed'), isNull);
    var lib = c.read(workspaceLibraryProvider).valueOrNull;
    expect(
      [for (final w in lib?.user ?? const <Workspace>[]) w.name],
      ['Other', 'Renamed'],
    );
    await n.delete('Renamed');
    await n.delete('Starter');
    lib = c.read(workspaceLibraryProvider).valueOrNull;
    expect(
      [for (final w in lib?.all ?? const <Workspace>[]) w.name],
      ['Starter', 'Other'],
    );
    final onDisk = await WorkspaceStore(configDir: dir.path).loadAll();
    expect([for (final w in onDisk) w.name], ['Other']);
  });

  test('rename via action uses the prompt', () async {
    await c.read(workspaceLibraryProvider.notifier).saveCurrentAs('Mine');
    await c
        .read(actionRegistryProvider)
        .execute(
          workspaceRenameActionId('Mine'),
          ActionContext(promptText: (title, {initial = ''}) async => 'Yours'),
        );
    expect(c.read(workspaceLibraryProvider).valueOrNull?.activeName, 'Yours');
  });

  test('switch bumps layout epoch and reuses ids for animation', () {
    c
        .read(workspaceProvider.notifier)
        .addCard(Offset.zero, const Size(10, 10), 'old');
    c.read(workspaceLibraryProvider.notifier).load('Starter');
    final s = c.read(workspaceProvider);
    expect(s.cards.single.id, 'card_0');
    expect(s.layoutEpoch, 1);
  });
}
