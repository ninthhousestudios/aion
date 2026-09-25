import 'app_action.dart';
import 'action_matcher.dart';

/// The single registry of actions behind every surface: card and canvas
/// context menus, the rail, and the command palette.
class ActionRegistry {
  ActionRegistry([Iterable<AppAction> actions = const []]) {
    registerAll(actions);
  }

  final _actions = <String, AppAction>{};

  void register(AppAction action) => _actions[action.id] = action;

  void registerAll(Iterable<AppAction> actions) {
    for (final a in actions) {
      register(a);
    }
  }

  AppAction? get(String id) => _actions[id];

  List<AppAction> get all => _actions.values.toList();

  List<AppAction> inCategory(String category) =>
      _actions.values.where((a) => a.category == category).toList();

  /// Categories that have at least one action, in display order.
  List<String> get categories {
    final present = {for (final a in _actions.values) a.category};
    return present.toList()..sort(
      (a, b) => ActionCategory.rank(a).compareTo(ActionCategory.rank(b)),
    );
  }

  /// Enabled actions matching [query], best first. Empty query lists all
  /// enabled actions by category, then title.
  List<AppAction> search(String query, ActionContext ctx) =>
      rankActions(_actions.values.where((a) => a.enabledIn(ctx)), query);

  /// Runs [id] if it exists and is enabled in [ctx]. Returns whether it ran.
  Future<bool> execute(String id, ActionContext ctx) async {
    final action = _actions[id];
    if (action == null || !action.enabledIn(ctx)) return false;
    await action.execute(ctx);
    return true;
  }
}
