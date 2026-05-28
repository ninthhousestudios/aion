import 'dart:ui';

import '../mcp/expression_ref.dart';

class CardModel {
  const CardModel({
    required this.id,
    required this.label,
    required this.color,
    required this.position,
    required this.size,
    this.expressions = const [],
    this.minSize = const Size(120, 80),
    this.zOrder = 0,
  });

  final String id;
  final String label;
  final Color color;
  final Offset position;
  final Size size;
  final List<ExpressionRef> expressions;
  final Size minSize;
  final int zOrder;

  Rect get rect => position & size;

  CardModel copyWith({
    String? id,
    String? label,
    Color? color,
    Offset? position,
    Size? size,
    List<ExpressionRef>? expressions,
    Size? minSize,
    int? zOrder,
  }) {
    return CardModel(
      id: id ?? this.id,
      label: label ?? this.label,
      color: color ?? this.color,
      position: position ?? this.position,
      size: size ?? this.size,
      expressions: expressions ?? this.expressions,
      minSize: minSize ?? this.minSize,
      zOrder: zOrder ?? this.zOrder,
    );
  }
}
