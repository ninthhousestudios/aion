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
    this.editMode = false,
  }) : cards = List.unmodifiable(cards),
       guides = List.unmodifiable(guides);

  WorkspaceState.initial()
    : cards = const [],
      selectedId = null,
      guides = const [],
      snapEnabled = false,
      nextZ = 0,
      cardCounter = 0,
      editMode = false;

  final List<CardModel> cards;
  final String? selectedId;
  final List<SnapGuide> guides;
  final bool snapEnabled;
  final int nextZ;
  final int cardCounter;

  /// Layouts are locked in view mode (the default): no drag, resize or
  /// keyboard nudging. Edit mode is the explicit layout editor.
  final bool editMode;

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
    bool? editMode,
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
      editMode: editMode ?? this.editMode,
    );
  }
}
