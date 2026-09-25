import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/app_action.dart';
import 'workspace.dart';
import 'workspace_store.dart';

String workspaceLoadActionId(String name) => 'workspace.load.$name';
String workspaceRenameActionId(String name) => 'workspace.rename.$name';
String workspaceDeleteActionId(String name) => 'workspace.delete.$name';

String? workspaceNameErrorMessage(WorkspaceNameError? error, String name) =>
    switch (error) {
      WorkspaceNameError.empty => 'Workspace name cannot be empty',
      WorkspaceNameError.starter =>
        '"${name.trim()}" is a starter workspace — choose another name',
      WorkspaceNameError.exists => 'A workspace named "${name.trim()}" exists',
      null => null,
    };

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
    if (workspaceNameErrorMessage(error, name) case final message?) {
      ctx.onError?.call(message);
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
    for (final ws in library?.user ?? const <Workspace>[]) ...[
      AppAction(
        id: workspaceRenameActionId(ws.name),
        title: 'Rename Workspace ${ws.name}…',
        category: ActionCategory.workspace,
        isEnabled: (ctx) => ctx.promptText != null,
        execute: (ctx) async {
          final to = await ctx.promptText?.call(
            'Rename workspace',
            initial: ws.name,
          );
          if (to == null) return;
          final error = await notifier().rename(ws.name, to);
          if (workspaceNameErrorMessage(error, to) case final message?) {
            ctx.onError?.call(message);
          }
        },
      ),
      AppAction(
        id: workspaceDeleteActionId(ws.name),
        title: 'Delete Workspace ${ws.name}',
        category: ActionCategory.workspace,
        execute: (_) => notifier().delete(ws.name),
      ),
    ],
  ];
}
