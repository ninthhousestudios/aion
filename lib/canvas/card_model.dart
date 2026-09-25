import 'dart:ui';

import '../slots/card_binding.dart';
import '../slots/chart_slot.dart';
import '../theme/card_display_overrides.dart';

class CardModel {
  const CardModel({
    required this.id,
    required this.label,
    required this.position,
    required this.size,
    this.binding,
    this.configOverride,
    this.minSize = const Size(120, 80),
    this.zOrder = 0,
    this.rendererType,
    this.displayConfig = const {},
    this.preferredAspectRatio,
    this.opacityOverride,
    this.displayOverrides = CardDisplayOverrides.empty,
  });

  final String id;
  final String label;
  final Offset position;
  final Size size;

  /// Where the card's chart comes from; null for cards not bound to a chart.
  final CardBinding? binding;

  /// Per-card expression config override; null means "use the slot's (or
  /// pinned) config". The opt-in exception, not the rule.
  final ExpressionConfig? configOverride;
  final Size minSize;
  final int zOrder;
  final String? rendererType;
  final Map<String, dynamic> displayConfig;
  final double? preferredAspectRatio;
  final double? opacityOverride;
  final CardDisplayOverrides displayOverrides;

  Rect get rect => position & size;

  static const Object _unset = Object();

  CardModel copyWith({
    String? id,
    String? label,
    Offset? position,
    Size? size,
    Object? binding = _unset,
    Object? configOverride = _unset,
    Size? minSize,
    int? zOrder,
    Object? rendererType = _unset,
    Map<String, dynamic>? displayConfig,
    Object? preferredAspectRatio = _unset,
    Object? opacityOverride = _unset,
    CardDisplayOverrides? displayOverrides,
  }) {
    return CardModel(
      id: id ?? this.id,
      label: label ?? this.label,
      position: position ?? this.position,
      size: size ?? this.size,
      binding: identical(binding, _unset)
          ? this.binding
          : binding as CardBinding?,
      configOverride: identical(configOverride, _unset)
          ? this.configOverride
          : configOverride as ExpressionConfig?,
      minSize: minSize ?? this.minSize,
      zOrder: zOrder ?? this.zOrder,
      rendererType: identical(rendererType, _unset)
          ? this.rendererType
          : rendererType as String?,
      displayConfig: displayConfig ?? this.displayConfig,
      preferredAspectRatio: identical(preferredAspectRatio, _unset)
          ? this.preferredAspectRatio
          : preferredAspectRatio as double?,
      opacityOverride: identical(opacityOverride, _unset)
          ? this.opacityOverride
          : opacityOverride as double?,
      displayOverrides: displayOverrides ?? this.displayOverrides,
    );
  }
}
