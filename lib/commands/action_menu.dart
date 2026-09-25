import 'package:flutter/material.dart';

import 'action_registry.dart';
import 'app_action.dart';

/// Resolves a menu layout (action ids, `null` = divider) against the
/// registry: drops missing/disabled actions, then leading, trailing and
/// doubled dividers. Result: actions, with `null` for dividers.
List<AppAction?> resolveMenu(
  List<String?> layout,
  ActionRegistry registry,
  ActionContext ctx,
) {
  final out = <AppAction?>[];
  for (final id in layout) {
    if (id == null) {
      if (out.isNotEmpty && out.last != null) out.add(null);
      continue;
    }
    final action = registry.get(id);
    if (action != null && action.enabledIn(ctx)) out.add(action);
  }
  if (out.isNotEmpty && out.last == null) out.removeLast();
  return out;
}

/// Popup menu entries for a resolved menu. Values are action ids.
List<PopupMenuEntry<String>> popupEntries(
  List<AppAction?> items,
  ActionContext ctx,
) => [
  for (final action in items)
    if (action == null)
      const PopupMenuDivider()
    else if (action.isChecked case final checked?)
      CheckedPopupMenuItem(
        value: action.id,
        checked: checked(ctx),
        child: Text(action.title),
      )
    else
      PopupMenuItem(value: action.id, child: Text(action.title)),
];
