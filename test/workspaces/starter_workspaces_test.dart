import 'dart:io';

import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/providers/renderer_registry_provider.dart';
import 'package:aion/workspaces/starter_workspaces.dart';
import 'package:aion/workspaces/workspace.dart';
import 'package:aion/workspaces/workspace_store.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('aion_ws_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        workspaceStoreProvider.overrideWithValue(
          WorkspaceStore(configDir: dir.path),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('at least two read-only starters using only available renderers', () {
    final c = container();
    final registry = c.read(rendererRegistryProvider);
    expect(kStarterWorkspaces.length, greaterThanOrEqualTo(2));
    for (final ws in kStarterWorkspaces) {
      expect(ws.readOnly, isTrue);
      expect(ws.cards, isNotEmpty);
      for (final card in ws.cards) {
        expect(registry.get(card.rendererType ?? ''), isNotNull);
      }
    }
  });

  test('starters survive a TOML round trip (they are ordinary layouts)', () {
    for (final ws in kStarterWorkspaces) {
      expect(Workspace.fromToml(ws.toToml()).cards.length, ws.cards.length);
    }
  });

  test('first launch opens the first starter', () async {
    final c = container();
    await c.read(workspaceLibraryProvider.notifier).openInitial();
    expect(
      c.read(workspaceLibraryProvider).valueOrNull?.activeName,
      kStarterWorkspaces.first.name,
    );
    expect(
      c.read(workspaceProvider).cards.length,
      kStarterWorkspaces.first.cards.length,
    );
  });

  test('later launches reopen the remembered workspace', () async {
    await WorkspaceStore(configDir: dir.path).saveActiveName('Chart Focus');
    final c = container();
    await c.read(workspaceLibraryProvider.notifier).openInitial();
    expect(
      c.read(workspaceLibraryProvider).valueOrNull?.activeName,
      'Chart Focus',
    );
  });

  test('openInitial leaves a non-empty canvas alone', () async {
    final c = container();
    c
        .read(workspaceProvider.notifier)
        .addCard(Offset.zero, const Size(10, 10), 'mine');
    await c.read(workspaceLibraryProvider.notifier).openInitial();
    expect(c.read(workspaceProvider).cards.single.label, 'mine');
  });

  test('save-as forks a starter; the starter itself is unchanged', () async {
    final c = container();
    final n = c.read(workspaceLibraryProvider.notifier);
    await n.openInitial();
    c.read(workspaceProvider.notifier).deleteCard('card_0');
    expect(
      await n.saveCurrentAs(kStarterWorkspaces.first.name),
      WorkspaceNameError.starter,
    );
    expect(await n.saveCurrentAs('My Reading'), isNull);
    final lib = c.read(workspaceLibraryProvider).valueOrNull;
    expect(lib?.byName('My Reading')?.cards.length, 1);
    expect(
      lib?.byName(kStarterWorkspaces.first.name)?.cards.length,
      kStarterWorkspaces.first.cards.length,
    );
  });

  test('initialWorkspaceName falls back when remembered is gone', () {
    const lib = WorkspaceLibrary(starters: kStarterWorkspaces);
    expect(initialWorkspaceName(lib, 'Deleted'), 'Natal Reading');
    expect(initialWorkspaceName(const WorkspaceLibrary(), null), isNull);
  });
}
