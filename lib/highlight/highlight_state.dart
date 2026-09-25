import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../renderer/highlight.dart';
import '../slots/card_binding.dart';

/// Linked-highlighting scope for a card: cards with the same scope light
/// up together. v1: one scope per slot; pinned cards share a scope per
/// pinned chart. Unbound cards have no scope and never highlight.
///
/// Cross-slot brushing (synastry) is deferred: it would map an entity from
/// one scope into others, which this state shape (entity + scope) allows.
String? highlightScopeFor(CardBinding? binding) => switch (binding) {
  SlotBinding(:final slotId) => 'slot:$slotId',
  PinnedBinding(:final chartId) => 'chart:$chartId',
  null => null,
};

/// What is highlighted, where, and whether it is locked.
///
/// Transient (hover) highlights follow the pointer; a locked (clicked)
/// highlight stays until clicked again or cleared with Esc, and hovering
/// doesn't disturb it.
class HighlightState {
  const HighlightState({this.entity, this.scope, this.locked = false});

  static const none = HighlightState();

  final HighlightEntity? entity;
  final String? scope;
  final bool locked;

  bool get isEmpty => entity == null;

  /// Entities to emphasize on a card with [cardScope].
  Set<HighlightEntity> highlightsFor(String? cardScope) {
    final e = entity;
    if (e == null || cardScope == null || cardScope != scope) return const {};
    return {e};
  }

  @override
  bool operator ==(Object other) =>
      other is HighlightState &&
      other.entity == entity &&
      other.scope == scope &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(entity, scope, locked);

  @override
  String toString() => 'HighlightState($entity @ $scope, locked: $locked)';
}

/// Pure transitions, so they can be tested without providers.
abstract final class HighlightTransitions {
  /// Pointer moved onto [entity] (or off everything, when null).
  static HighlightState hover(
    HighlightState s,
    HighlightEntity? entity,
    String? scope,
  ) {
    if (s.locked) return s;
    if (entity == null || scope == null) return HighlightState.none;
    return HighlightState(entity: entity, scope: scope);
  }

  /// Click on [entity]: lock it; clicking the locked entity again (or
  /// empty space) unlocks.
  static HighlightState click(
    HighlightState s,
    HighlightEntity? entity,
    String? scope,
  ) {
    if (entity == null || scope == null) {
      return s.locked ? HighlightState.none : s;
    }
    if (s.locked && s.entity == entity && s.scope == scope) {
      return HighlightState(entity: entity, scope: scope);
    }
    return HighlightState(entity: entity, scope: scope, locked: true);
  }
}

class HighlightNotifier extends Notifier<HighlightState> {
  @override
  HighlightState build() => HighlightState.none;

  void hover(HighlightEntity? entity, String? scope) {
    final next = HighlightTransitions.hover(state, entity, scope);
    if (next != state) state = next;
  }

  void click(HighlightEntity? entity, String? scope) {
    final next = HighlightTransitions.click(state, entity, scope);
    if (next != state) state = next;
  }

  /// Esc: drop any highlight, locked or not.
  void clear() {
    if (!state.isEmpty) state = HighlightState.none;
  }
}

final highlightProvider = NotifierProvider<HighlightNotifier, HighlightState>(
  HighlightNotifier.new,
);
