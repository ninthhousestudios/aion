import 'dart:async';
import 'dart:convert';

import 'package:chart_db_core/chart_db_core.dart';

import '../mcp/chart_state.dart';
import '../mcp/chart_store.dart';
import '../mcp/expression_ref.dart';
import '../mcp/expression_state.dart';
import 'card_binding.dart';
import 'chart_slot.dart';
import 'slot_state.dart';

/// Plugin tool that computes an Expression from a chart + config.
const kExpressionServer = 'drishti';
const kExpressionTool = 'calculate_chart';

/// The fully-resolved inputs for one card's Expression.
class ResolvedExpression {
  const ResolvedExpression({
    required this.chartId,
    required this.config,
    required this.ref,
  });

  final String chartId;

  /// Canonical (key-sorted, JSON-safe) config. Passing exactly this map to
  /// `ChartStore.computeExpression` yields [ref].
  final Map<String, Object> config;
  final ExpressionRef ref;

  @override
  bool operator ==(Object other) =>
      other is ResolvedExpression && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;
}

ResolvedExpression _resolve(String chartId, Map<String, Object> config) {
  final canon = canonicalConfig(config);
  return ResolvedExpression(
    chartId: chartId,
    config: canon,
    ref: ExpressionRef(
      chartId: chartId,
      configHash: configHash(jsonEncode(canon)),
    ),
  );
}

/// Resolves a card's binding against the live slots.
///
/// Slot-bound: slot's chart + (card override ?? slot config). Pinned: the
/// pinned chart + (card override ?? pinned config). Returns null when the
/// card is unbound or its slot is empty. A slot id that no longer exists
/// resolves against the default slot.
ResolvedExpression? resolveCardExpression(
  CardBinding? binding,
  SlotState slots, {
  ExpressionConfig? configOverride,
}) {
  switch (binding) {
    case null:
      return null;
    case SlotBinding(:final slotId):
      final slot = slots.slotOrDefault(slotId);
      final chartId = slot.chartId;
      if (chartId == null) return null;
      return _resolve(chartId, configOverride ?? slot.config);
    case PinnedBinding(:final chartId, :final config):
      return _resolve(chartId, configOverride ?? config);
  }
}

/// The items bound to [slotId] — exactly the ones a change to that slot's
/// chart or config must recompute. Pinned and unbound items never match.
List<T> boundToSlot<T>(
  Iterable<T> items,
  CardBinding? Function(T) bindingOf,
  String slotId,
) => [
  for (final item in items)
    if (bindingOf(item) case SlotBinding(slotId: final id) when id == slotId)
      item,
];

/// Kicks off computation of [resolved] unless it is already cached or in
/// flight. Goes through the unchanged `ChartStore` compute/cache path.
///
/// Safe to call from `build`: the compute is deferred to a microtask so no
/// stream listener is notified mid-build.
void ensureExpression(ChartStore store, ResolvedExpression resolved) {
  if (!store.loadedChartIds.contains(resolved.chartId)) return;
  if (store.chartState(resolved.chartId) is! ChartLoaded) return;
  if (store.expressionState(resolved.ref) is! ExpressionIdle) return;
  scheduleMicrotask(() {
    if (store.expressionState(resolved.ref) is! ExpressionIdle) return;
    store
        .computeExpression(
          resolved.chartId,
          kExpressionServer,
          kExpressionTool,
          resolved.config,
        )
        // Failures are published on the expression stream as ExpressionError.
        .ignore();
  });
}
