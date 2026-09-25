import 'chart_slot.dart';

/// How a card gets its chart.
///
/// A [SlotBinding] follows a slot: whatever chart is loaded into the slot,
/// computed with the slot's config (unless the card overrides it). A
/// [PinnedBinding] is fixed to one chart and config and ignores slots.
sealed class CardBinding {
  const CardBinding();
}

class SlotBinding extends CardBinding {
  const SlotBinding(this.slotId);

  final String slotId;

  @override
  bool operator ==(Object other) =>
      other is SlotBinding && other.slotId == slotId;

  @override
  int get hashCode => slotId.hashCode;

  @override
  String toString() => 'SlotBinding($slotId)';
}

class PinnedBinding extends CardBinding {
  const PinnedBinding({
    required this.chartId,
    this.chartName,
    this.config = const {},
  });

  final String chartId;
  final String? chartName;
  final ExpressionConfig config;

  @override
  bool operator ==(Object other) =>
      other is PinnedBinding &&
      other.chartId == chartId &&
      other.chartName == chartName &&
      canonicalConfigJson(other.config) == canonicalConfigJson(config);

  @override
  int get hashCode => Object.hash(chartId, canonicalConfigJson(config));

  @override
  String toString() => 'PinnedBinding($chartId)';
}
