import 'dart:ui';

import '../mcp/expression_ref.dart';

class CardModel {
  const CardModel({
    required this.id,
    required this.label,
    required this.position,
    required this.size,
    this.expressions = const [],
    this.minSize = const Size(120, 80),
    this.zOrder = 0,
    this.rendererType,
    this.displayConfig = const {},
    this.preferredAspectRatio,
    this.opacityOverride,
  });

  final String id;
  final String label;
  final Offset position;
  final Size size;
  final List<ExpressionRef> expressions;
  final Size minSize;
  final int zOrder;
  final String? rendererType;
  final Map<String, dynamic> displayConfig;
  final double? preferredAspectRatio;
  final double? opacityOverride;

  Rect get rect => position & size;

  static const Object _unset = Object();

  CardModel copyWith({
    String? id,
    String? label,
    Offset? position,
    Size? size,
    List<ExpressionRef>? expressions,
    Size? minSize,
    int? zOrder,
    Object? rendererType = _unset,
    Map<String, dynamic>? displayConfig,
    Object? preferredAspectRatio = _unset,
    Object? opacityOverride = _unset,
  }) {
    return CardModel(
      id: id ?? this.id,
      label: label ?? this.label,
      position: position ?? this.position,
      size: size ?? this.size,
      expressions: expressions ?? this.expressions,
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
    );
  }
}
