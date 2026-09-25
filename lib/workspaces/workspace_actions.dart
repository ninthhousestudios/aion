import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/app_action.dart';
import 'workspace_store.dart';

String workspaceLoadActionId(String name) => 'workspace.load.$name';

/// Workspace operations as registry actions: save, save-as, switch.
List<AppAction> buildWorkspaceActions(Ref ref) {
  final library = ref.read(workspaceLibraryProvider).valueOrNull;
  WorkspaceLibraryNotifier notifier() =>
      ref.read(workspaceLibraryProvider.notifier);
  String? active() =>
      ref.read(workspaceLibraryProvider).valueOrNull?.activeName;

  Future<void> saveAs(ActionContext ctx, {String initial = ''}) async {
    final name = await ctx.promptText?.call(
      'Save workspace as',
      initial: initial,
    );
    if (name == null) return;
    final error = await notifier().saveCurrentAs(name);
    switch (error) {
      case WorkspaceNameError.empty:
        ctx.onError?.call('Workspace name cannot be empty');
      case WorkspaceNameError.starter:
        ctx.onError?.call(
          '"${name.trim()}" is a starter workspace — choose another name',
        );
      case null:
        break;
    }
  }

  return [
    AppAction(
      id: 'workspace.save_as',
      title: 'Save Workspace As…',
      category: ActionCategory.workspace,
      icon: Icons.save_as_outlined,
      aliases: const ['fork', 'layout'],
      isEnabled: (ctx) => ctx.promptText != null,
      execute: (ctx) {
        final current = active();
        final lib = ref.read(workspaceLibraryProvider).valueOrNull;
        final initial = current == null
            ? ''
            : (lib?.isStarter(current) ?? false)
            ? '$current (copy)'
            : current;
        return saveAs(ctx, initial: initial);
      },
    ),
    AppAction(
      id: 'workspace.save',
      title: 'Save Workspace',
      category: ActionCategory.workspace,
      icon: Icons.save_outlined,
      isEnabled: (_) {
        final name = active();
        final lib = ref.read(workspaceLibraryProvider).valueOrNull;
        return name != null && lib != null && !lib.isStarter(name);
      },
      execute: (ctx) async {
        if (active() case final name?) await notifier().saveCurrentAs(name);
      },
    ),
    for (final ws in library?.all ?? const [])
      AppAction(
        id: workspaceLoadActionId(ws.name),
        title: 'Switch to ${ws.name}',
        category: ActionCategory.workspace,
        icon: Icons.view_quilt_outlined,
        isChecked: (_) => active() == ws.name,
        execute: (_) => notifier().load(ws.name),
      ),
  ];
}
