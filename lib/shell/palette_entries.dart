import '../commands/action_matcher.dart';
import '../commands/action_registry.dart';
import '../commands/app_action.dart';

/// A row in the command palette: a browsable category or an action.
sealed class PaletteEntry {
  const PaletteEntry();
}

class PaletteCategoryEntry extends PaletteEntry {
  const PaletteCategoryEntry(this.category, this.count);

  final String category;
  final int count;
}

class PaletteActionEntry extends PaletteEntry {
  const PaletteActionEntry(this.action);

  final AppAction action;
}

/// What the palette lists.
///
/// - Query typed: ranked matches over titles + aliases (within [category]
///   if one is chosen).
/// - Empty query, category chosen: that category's actions.
/// - Empty query, nothing chosen: clickable categories, for mouse browsing.
List<PaletteEntry> paletteEntries(
  ActionRegistry registry,
  ActionContext ctx, {
  String query = '',
  String? category,
}) {
  final enabled = registry.all.where(
    (a) => a.enabledIn(ctx) && (category == null || a.category == category),
  );
  if (query.trim().isNotEmpty || category != null) {
    return [for (final a in rankActions(enabled, query)) PaletteActionEntry(a)];
  }
  final counts = <String, int>{};
  for (final a in enabled) {
    counts[a.category] = (counts[a.category] ?? 0) + 1;
  }
  final categories = counts.keys.toList()
    ..sort((a, b) => ActionCategory.rank(a).compareTo(ActionCategory.rank(b)));
  return [for (final c in categories) PaletteCategoryEntry(c, counts[c] ?? 0)];
}

/// Keyboard selection movement, wrapping at both ends.
int moveSelection(int current, int delta, int length) {
  if (length <= 0) return 0;
  return (current + delta) % length;
}
