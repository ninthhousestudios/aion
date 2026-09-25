import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/aion_theme.dart';
import '../workspaces/workspace.dart';
import '../workspaces/workspace_actions.dart';
import '../workspaces/workspace_store.dart';
import 'rail.dart';

/// Rail flyout listing workspaces: click to switch; save / save-as, rename
/// and delete for user workspaces. Starters are marked read-only. All
/// operations run as registry actions via [onAction].
class WorkspacesFlyout extends ConsumerWidget {
  const WorkspacesFlyout({super.key, required this.onAction});

  final void Function(String actionId) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final library = ref.watch(workspaceLibraryProvider).valueOrNull;
    final dim = TextStyle(color: t.cardDimColor, fontSize: 11);
    final active = library?.activeName;
    final canSave = active != null && !(library?.isStarter(active) ?? true);

    Widget row(Workspace ws, {required bool starter}) {
      final isActive = ws.name == active;
      return InkWell(
        onTap: () => onAction(workspaceLoadActionId(ws.name)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? t.chromeButtonHover : null,
            border: Border.all(
              color: isActive ? t.snapAccent : t.surfaceBorder,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                starter ? Icons.lock_outline : Icons.view_quilt_outlined,
                size: 16,
                color: t.chromeIconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ws.name,
                  style: TextStyle(color: t.cardLabelColor, fontSize: 13),
                ),
              ),
              Text('${ws.cards.length} cards', style: dim),
              if (!starter) ...[
                IconButton(
                  icon: Icon(Icons.edit, size: 14, color: t.chromeIconColor),
                  tooltip: 'Rename',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAction(workspaceRenameActionId(ws.name)),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: t.chromeIconColor,
                  ),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAction(workspaceDeleteActionId(ws.name)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return FlyoutPanel(
      title: 'Workspaces',
      child: ListView(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onAction('workspace.save_as'),
                icon: Icon(
                  Icons.save_as_outlined,
                  size: 16,
                  color: t.chromeIconColor,
                ),
                label: Text(
                  'Save as…',
                  style: TextStyle(color: t.cardLabelColor),
                ),
              ),
              if (canSave)
                TextButton.icon(
                  onPressed: () => onAction('workspace.save'),
                  icon: Icon(
                    Icons.save_outlined,
                    size: 16,
                    color: t.chromeIconColor,
                  ),
                  label: Text(
                    'Save',
                    style: TextStyle(color: t.cardLabelColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (library == null)
            Text('Loading…', style: dim)
          else ...[
            if (library.starters.isNotEmpty) ...[
              Text('STARTERS', style: dim),
              const SizedBox(height: 4),
              for (final ws in library.starters) row(ws, starter: true),
              const SizedBox(height: 8),
            ],
            Text('MY WORKSPACES', style: dim),
            const SizedBox(height: 4),
            if (library.user.isEmpty)
              Text(
                'None yet — "Save as…" keeps the current layout.',
                style: dim,
              ),
            for (final ws in library.user) row(ws, starter: false),
          ],
        ],
      ),
    );
  }
}
