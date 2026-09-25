import 'dart:async';

import 'package:flutter/widgets.dart';

/// Where and on what an action is invoked.
///
/// Surfaces (card menu, canvas menu, rail, palette) fill in what they know:
/// the card menu passes [cardId]; the canvas menu passes [position]; the
/// palette passes the selected card, if any.
class ActionContext {
  const ActionContext({
    this.cardId,
    this.position,
    this.viewportSize,
    this.onError,
    this.editConfig,
    this.promptText,
  });

  /// Target card for card-scoped actions.
  final String? cardId;

  /// Workspace-space point the action was invoked at (e.g. right-click).
  final Offset? position;

  /// Size of the visible canvas, for actions that size things to the window.
  final Size? viewportSize;

  /// Reports a user-facing failure (e.g. a chart failed to load).
  final void Function(String message)? onError;

  /// Opens the expression config editor. Supplied by UI surfaces; actions
  /// that edit config are no-ops without it.
  final void Function(ConfigEditRequest request)? editConfig;

  /// Asks the user for a line of text (e.g. a workspace name); completes
  /// with null on cancel. Supplied by UI surfaces.
  final Future<String?> Function(String title, {String initial})? promptText;
}

/// A request to edit an expression config interactively.
class ConfigEditRequest {
  const ConfigEditRequest({
    required this.title,
    required this.initial,
    required this.onChanged,
  });

  final String title;
  final Map<String, Object> initial;
  final void Function(Map<String, Object> config) onChanged;
}

bool _always(ActionContext _) => true;

/// One thing the app can do. Every surface draws from the same set of
/// actions, so there is one mental model regardless of input style.
class AppAction {
  const AppAction({
    required this.id,
    required this.title,
    required this.category,
    required this.execute,
    this.aliases = const [],
    this.icon,
    this.isEnabled = _always,
    this.isChecked,
    this.requiresCard = false,
    this.menuTitle,
  });

  final String id;
  final String title;

  /// Label in context menus when it should read differently from [title]
  /// (e.g. "Add Data Table" vs the catalog's "Data Table").
  final String? menuTitle;

  /// One of the `ActionCategory` constants.
  final String category;

  /// Extra search terms: domain shorthand ("d9", "vim"), abbreviations.
  final List<String> aliases;
  final IconData? icon;
  final bool Function(ActionContext) isEnabled;

  /// Non-null for toggles: returns the current on/off state.
  final bool Function(ActionContext)? isChecked;

  /// Card-scoped: only enabled when the context names a card.
  final bool requiresCard;

  final FutureOr<void> Function(ActionContext) execute;

  bool enabledIn(ActionContext ctx) =>
      (!requiresCard || ctx.cardId != null) && isEnabled(ctx);
}

/// Category names, in display order. View categories come first — they are
/// what the catalog shows.
abstract final class ActionCategory {
  static const charts = 'Charts';
  static const vargas = 'Vargas';
  static const tables = 'Tables';
  static const time = 'Time';
  static const slots = 'Slots';
  static const workspace = 'Workspace';
  static const card = 'Card';
  static const display = 'Display';
  static const settings = 'Settings';

  static const views = [charts, vargas, tables, time];
  static const order = [
    charts,
    vargas,
    tables,
    time,
    slots,
    workspace,
    card,
    display,
    settings,
  ];

  static int rank(String category) {
    final i = order.indexOf(category);
    return i < 0 ? order.length : i;
  }
}
