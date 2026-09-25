import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_slot.dart';

/// All chart slots plus which one is active. Slot [kDefaultSlotId] always
/// exists and cannot be removed.
class SlotState {
  SlotState({required List<ChartSlot> slots, required this.activeSlotId})
    : slots = List.unmodifiable(slots) {
    assert(slots.any((s) => s.id == kDefaultSlotId));
  }

  SlotState.initial()
    : slots = const [defaultSlot],
      activeSlotId = kDefaultSlotId;

  static const kDefaultSlotId = 'A';
  static const defaultSlot = ChartSlot(
    id: kDefaultSlotId,
    label: 'A',
    colorIndex: 0,
  );

  final List<ChartSlot> slots;
  final String activeSlotId;

  ChartSlot? slotById(String id) {
    for (final slot in slots) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  /// The slot with [id], or the default slot if it doesn't exist.
  ChartSlot slotOrDefault(String id) =>
      slotById(id) ?? slotById(kDefaultSlotId) ?? defaultSlot;

  ChartSlot get activeSlot => slotOrDefault(activeSlotId);

  /// [id] when it names an existing slot, else the default slot id.
  String resolveSlotId(String id) => slotById(id) == null ? kDefaultSlotId : id;

  /// Next unused single-letter id: A, B, C, … then S27, S28, ….
  String get nextSlotId {
    final used = {for (final s in slots) s.id};
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
      final id = String.fromCharCode(c);
      if (!used.contains(id)) return id;
    }
    for (var i = 27; ; i++) {
      if (!used.contains('S$i')) return 'S$i';
    }
  }

  SlotState copyWith({List<ChartSlot>? slots, String? activeSlotId}) =>
      SlotState(
        slots: slots ?? this.slots,
        activeSlotId: activeSlotId ?? this.activeSlotId,
      );
}

class SlotsNotifier extends Notifier<SlotState> {
  @override
  SlotState build() => SlotState.initial();

  void _update(String id, ChartSlot Function(ChartSlot) change) {
    state = state.copyWith(
      slots: [
        for (final s in state.slots)
          if (s.id == id) change(s) else s,
      ],
    );
  }

  /// Adds a slot and returns its id.
  String addSlot({String? label}) {
    final id = state.nextSlotId;
    state = state.copyWith(
      slots: [
        ...state.slots,
        ChartSlot(id: id, label: label ?? id, colorIndex: state.slots.length),
      ],
    );
    return id;
  }

  /// Removes a slot. The default slot cannot be removed; removing the active
  /// slot makes the default slot active.
  void removeSlot(String id) {
    if (id == SlotState.kDefaultSlotId) return;
    state = state.copyWith(
      slots: state.slots.where((s) => s.id != id).toList(),
      activeSlotId: state.activeSlotId == id
          ? SlotState.kDefaultSlotId
          : state.activeSlotId,
    );
  }

  void setActive(String id) {
    if (state.slotById(id) == null) return;
    state = state.copyWith(activeSlotId: id);
  }

  void rename(String id, String label) =>
      _update(id, (s) => s.copyWith(label: label));

  void setColorIndex(String id, int colorIndex) =>
      _update(id, (s) => s.copyWith(colorIndex: colorIndex));

  /// Loads a chart into a slot (the active slot when [id] is null).
  void setChart(String? id, String chartId, {String? chartName}) => _update(
    id ?? state.activeSlotId,
    (s) => s.copyWith(chartId: chartId, chartName: chartName),
  );

  void clearChart(String id) =>
      _update(id, (s) => s.copyWith(chartId: null, chartName: null));

  void setConfig(String id, ExpressionConfig config) =>
      _update(id, (s) => s.copyWith(config: config));
}

final slotsProvider = NotifierProvider<SlotsNotifier, SlotState>(
  SlotsNotifier.new,
);
