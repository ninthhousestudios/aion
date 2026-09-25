import 'app_action.dart';

/// Scores how well [query] matches [action]; null means no match.
///
/// Tiers, best first: exact alias, exact title, title prefix, alias prefix,
/// word prefix in title, title substring, alias substring, fuzzy
/// subsequence over the title (tighter matches score higher).
int? scoreAction(AppAction action, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  final title = action.title.toLowerCase();
  final aliases = [for (final a in action.aliases) a.toLowerCase()];

  if (aliases.contains(q)) return 1000;
  if (title == q) return 950;
  if (title.startsWith(q)) return 900;
  if (aliases.any((a) => a.startsWith(q))) return 800;
  final words = title.split(RegExp(r'[\s\-_/·]+'));
  if (words.any((w) => w.startsWith(q))) return 700;
  if (title.contains(q)) return 600;
  if (aliases.any((a) => a.contains(q))) return 500;
  final fuzzy = fuzzySubsequenceScore(title, q);
  return fuzzy;
}

/// Subsequence match of [query] in [text]: null when [query]'s characters
/// don't appear in order. Otherwise 100–400, higher for fewer gaps.
int? fuzzySubsequenceScore(String text, String query) {
  var ti = 0;
  var gaps = 0;
  var last = -1;
  for (final ch in query.split('')) {
    final found = text.indexOf(ch, ti);
    if (found < 0) return null;
    if (last >= 0 && found != last + 1) gaps++;
    last = found;
    ti = found + 1;
  }
  final score = 400 - gaps * 60 - (text.length - query.length);
  return score.clamp(100, 400);
}

/// [actions] matching [query], best first; ties broken by category order
/// then title. Empty query returns everything in category/title order.
List<AppAction> rankActions(Iterable<AppAction> actions, String query) {
  final scored = <(AppAction, int)>[
    for (final a in actions)
      if (scoreAction(a, query) case final s?) (a, s),
  ];
  scored.sort((x, y) {
    final byScore = y.$2.compareTo(x.$2);
    if (byScore != 0) return byScore;
    final byCat = ActionCategory.rank(
      x.$1.category,
    ).compareTo(ActionCategory.rank(y.$1.category));
    if (byCat != 0) return byCat;
    return x.$1.title.compareTo(y.$1.title);
  });
  return [for (final (a, _) in scored) a];
}
