import 'package:flutter/services.dart';

import '../slots/card_binding.dart';
import '../slots/chart_slot.dart';
import '../theme/card_display_overrides.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas_card.dart';
import 'card_model.dart';
import 'snap_physics.dart';
import 'workspace_state.dart';

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF10B981),
  ];

  @override
  WorkspaceState build() {
    return WorkspaceState.initial();
  }

  void addCard(
    Offset position,
    Size size,
    String label, {
    CardBinding? binding,
    ExpressionConfig? configOverride,
    String? rendererType,
    double? preferredAspectRatio,
  }) {
    state = _addCardToState(
      state,
      position,
      size,
      label,
      binding: binding,
      configOverride: configOverride,
      rendererType: rendererType,
      preferredAspectRatio: preferredAspectRatio,
    );
  }

  void duplicateCard(String id) {
    final card = state.cardById(id);
    if (card == null) return;

    state = _addCardToState(
      state,
      card.position + const Offset(30, 30),
      card.size,
      '${card.label} (copy)',
      binding: card.binding,
      configOverride: card.configOverride,
      rendererType: card.rendererType,
      preferredAspectRatio: card.preferredAspectRatio,
      displayConfig: card.displayConfig,
      displayOverrides: card.displayOverrides,
    );
  }

  void deleteCard(String id) {
    final selectedId = state.selectedId == id ? null : state.selectedId;
    state = state.copyWith(
      cards: state.cards.where((card) => card.id != id).toList(),
      selectedId: selectedId,
      guides: const [],
    );
  }

  void selectCard(String? id) {
    if (id == null) {
      state = state.copyWith(selectedId: null);
      return;
    }

    final card = state.cardById(id);
    if (card == null) return;

    final zOrder = state.nextZ;
    state = state.copyWith(
      cards: _replaceCard(card.copyWith(zOrder: zOrder)),
      selectedId: id,
      nextZ: zOrder + 1,
    );
  }

  void moveCard(
    String id,
    Offset delta,
    Size canvasSize, {
    bool applySnap = true,
  }) {
    final card = state.cardById(id);
    if (card == null) return;

    var moved = card.copyWith(position: card.position + delta);
    var guides = const <SnapGuide>[];

    if (applySnap && state.snapEnabled) {
      final snap = SnapPhysics.snap(moved.rect, _otherRects(id), canvasSize);
      moved = moved.copyWith(position: moved.position + snap.offset);
      guides = snap.guides;
    }

    state = state.copyWith(cards: _replaceCard(moved), guides: guides);
  }

  void resizeCard(String id, Offset delta, ResizeCorner corner) {
    final card = state.cardById(id);
    if (card == null) return;

    var dx = delta.dx;
    var dy = delta.dy;

    final flipX =
        corner == ResizeCorner.topLeft || corner == ResizeCorner.bottomLeft;
    final flipY =
        corner == ResizeCorner.topLeft || corner == ResizeCorner.topRight;

    if (flipX) dx = -dx;
    if (flipY) dy = -dy;

    var newW = (card.size.width + dx)
        .clamp(card.minSize.width, double.infinity)
        .toDouble();
    var newH = (card.size.height + dy)
        .clamp(card.minSize.height, double.infinity)
        .toDouble();

    final ar = card.preferredAspectRatio;
    if (ar != null) {
      if (newW / ar > newH) {
        newH = newW / ar;
      } else {
        newW = newH * ar;
      }
    }

    final actualDx = newW - card.size.width;
    final actualDy = newH - card.size.height;

    var position = card.position;
    if (flipX) {
      position = Offset(position.dx - actualDx, position.dy);
    }
    if (flipY) {
      position = Offset(position.dx, position.dy - actualDy);
    }

    state = state.copyWith(
      cards: _replaceCard(
        card.copyWith(position: position, size: Size(newW, newH)),
      ),
    );
  }

  void clearGuides() {
    if (state.guides.isEmpty) return;
    state = state.copyWith(guides: const []);
  }

  void cycleChartAccent(String chartId) {
    final current = state.chartAccents[chartId];
    if (current == null) return;
    final idx = _palette.indexOf(current);
    final next = _palette[(idx + 1) % _palette.length];
    state = state.copyWith(
      chartAccents: {...state.chartAccents, chartId: next},
    );
  }

  void setCardOpacity(String id, double? opacity) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(
      cards: _replaceCard(card.copyWith(opacityOverride: opacity)),
    );
  }

  void setCardRenderer(
    String id,
    String rendererType, {
    double? preferredAspectRatio,
  }) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(
      cards: _replaceCard(
        card.copyWith(
          rendererType: rendererType,
          displayConfig: const {},
          preferredAspectRatio: preferredAspectRatio,
        ),
      ),
    );
  }

  void updateCardDisplayOverrides(String id, CardDisplayOverrides overrides) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(
      cards: _replaceCard(card.copyWith(displayOverrides: overrides)),
    );
  }

  void setCardBinding(String id, CardBinding? binding) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(
      cards: _replaceCard(card.copyWith(binding: binding)),
    );
  }

  void setCardConfigOverride(String id, ExpressionConfig? config) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(
      cards: _replaceCard(card.copyWith(configOverride: config)),
    );
  }

  void resetCardSize(String id, Size size) {
    final card = state.cardById(id);
    if (card == null) return;
    state = state.copyWith(cards: _replaceCard(card.copyWith(size: size)));
  }

  void toggleSnap() {
    state = state.copyWith(snapEnabled: !state.snapEnabled, guides: const []);
  }

  void handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyS) {
      toggleSnap();
      return;
    }

    final selectedId = state.selectedId;
    if (selectedId == null) return;

    const step = 10.0;

    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        moveCard(
          selectedId,
          const Offset(-step, 0),
          Size.zero,
          applySnap: false,
        );
      case LogicalKeyboardKey.arrowRight:
        moveCard(
          selectedId,
          const Offset(step, 0),
          Size.zero,
          applySnap: false,
        );
      case LogicalKeyboardKey.arrowUp:
        moveCard(
          selectedId,
          const Offset(0, -step),
          Size.zero,
          applySnap: false,
        );
      case LogicalKeyboardKey.arrowDown:
        moveCard(
          selectedId,
          const Offset(0, step),
          Size.zero,
          applySnap: false,
        );
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        deleteCard(selectedId);
      case LogicalKeyboardKey.tab:
        _selectNextCard();
    }
  }

  WorkspaceState _addCardToState(
    WorkspaceState current,
    Offset position,
    Size size,
    String label, {
    CardBinding? binding,
    ExpressionConfig? configOverride,
    String? rendererType,
    double? preferredAspectRatio,
    Map<String, dynamic> displayConfig = const {},
    CardDisplayOverrides displayOverrides = CardDisplayOverrides.empty,
  }) {
    final card = CardModel(
      id: 'card_${current.cardCounter}',
      label: label,
      position: position,
      size: size,
      binding: binding,
      configOverride: configOverride,
      rendererType: rendererType,
      preferredAspectRatio: preferredAspectRatio,
      displayConfig: displayConfig,
      displayOverrides: displayOverrides,
      zOrder: current.nextZ,
    );

    var chartAccents = current.chartAccents;
    var accentCounter = current.accentCounter;
    final chartId = WorkspaceState.accentKey(card);
    if (chartId != null && !chartAccents.containsKey(chartId)) {
      chartAccents = {
        ...chartAccents,
        chartId: _palette[accentCounter % _palette.length],
      };
      accentCounter++;
    }

    return current.copyWith(
      cards: [...current.cards, card],
      nextZ: current.nextZ + 1,
      cardCounter: current.cardCounter + 1,
      chartAccents: chartAccents,
      accentCounter: accentCounter,
    );
  }

  List<CardModel> _replaceCard(CardModel updated) {
    return [
      for (final card in state.cards)
        if (card.id == updated.id) updated else card,
    ];
  }

  List<Rect> _otherRects(String excludeId) {
    return state.cards
        .where((card) => card.id != excludeId)
        .map((card) => card.rect)
        .toList();
  }

  void _selectNextCard() {
    if (state.cards.isEmpty) return;

    final selectedId = state.selectedId;
    final idx = state.cards.indexWhere((card) => card.id == selectedId);
    final nextIndex = idx < 0 ? 0 : (idx + 1) % state.cards.length;
    selectCard(state.cards[nextIndex].id);
  }
}
