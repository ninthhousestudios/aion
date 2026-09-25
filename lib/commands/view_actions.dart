import 'dart:async';

import 'package:flutter/material.dart';

import '../renderer/chart_renderer.dart';
import 'app_action.dart';

/// Action id for "add a [rendererId] view to the active slot".
String addViewActionId(String rendererId) => 'view.add.$rendererId';

/// One "add view" action per renderer — the catalog and palette entries.
/// New renderers appear automatically; nothing here names a renderer.
List<AppAction> viewActionsFromRenderers(
  Iterable<RendererMeta> metas, {
  required FutureOr<void> Function(RendererMeta meta, ActionContext ctx) onAdd,
}) => [
  for (final meta in metas)
    AppAction(
      id: addViewActionId(meta.id),
      title: meta.displayName,
      menuTitle: 'Add ${meta.displayName}',
      category: meta.category,
      aliases: meta.aliases,
      icon: _iconFor(meta.category),
      execute: (ctx) => onAdd(meta, ctx),
    ),
];

IconData _iconFor(String category) => switch (category) {
  ActionCategory.tables => Icons.table_chart_outlined,
  ActionCategory.time => Icons.schedule,
  ActionCategory.vargas => Icons.grid_on,
  _ => Icons.grid_view,
};
