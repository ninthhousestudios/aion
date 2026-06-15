import 'dart:ui';

import 'card_model.dart';
import 'snap_physics.dart';

class WorkspaceState {
  WorkspaceState({
    required List<CardModel> cards,
    required this.selectedId,
    required List<SnapGuide> guides,
    required this.snapEnabled,
    required this.nextZ,
    required this.cardCounter,
    required Map<String, Color> chartAccents,
    required this.accentCounter,
  }) : cards = List.unmodifiable(cards),
       guides = List.unmodifiable(guides),
       chartAccents = Map.unmodifiable(chartAccents);

  WorkspaceState.initial()
    : cards = const [],
      selectedId = null,
      guides = const [],
      snapEnabled = false,
      nextZ = 0,
      cardCounter = 0,
      chartAccents = const {},
      accentCounter = 0;

  final List<CardModel> cards;
  final String? selectedId;
  final List<SnapGuide> guides;
  final bool snapEnabled;
  final int nextZ;
  final int cardCounter;
  final Map<String, Color> chartAccents;
  final int accentCounter;

  Color? accentForCard(CardModel card) {
    final chartId = card.expressions.firstOrNull?.chartId;
    if (chartId == null) return null;
    return chartAccents[chartId];
  }

  List<CardModel> get sortedCards {
    return List<CardModel>.from(cards)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
  }

  CardModel? cardById(String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  static const Object _unset = Object();

  WorkspaceState copyWith({
    List<CardModel>? cards,
    Object? selectedId = _unset,
    List<SnapGuide>? guides,
    bool? snapEnabled,
    int? nextZ,
    int? cardCounter,
    Map<String, Color>? chartAccents,
    int? accentCounter,
  }) {
    return WorkspaceState(
      cards: cards ?? this.cards,
      selectedId: identical(selectedId, _unset)
          ? this.selectedId
          : selectedId as String?,
      guides: guides ?? this.guides,
      snapEnabled: snapEnabled ?? this.snapEnabled,
      nextZ: nextZ ?? this.nextZ,
      cardCounter: cardCounter ?? this.cardCounter,
      chartAccents: chartAccents ?? this.chartAccents,
      accentCounter: accentCounter ?? this.accentCounter,
    );
  }
}
