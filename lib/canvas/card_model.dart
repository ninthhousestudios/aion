import 'dart:ui';

class CardModel {
  const CardModel({
    required this.id,
    required this.label,
    required this.color,
    required this.position,
    required this.size,
    this.slotId,
    this.minSize = const Size(120, 80),
    this.zOrder = 0,
  });

  final String id;
  final String label;
  final Color color;
  final Offset position;
  final Size size;
  final String? slotId;
  final Size minSize;
  final int zOrder;

  Rect get rect => position & size;

  static const Object _unset = Object();

  CardModel copyWith({
    String? id,
    String? label,
    Color? color,
    Offset? position,
    Size? size,
    Object? slotId = _unset,
    Size? minSize,
    int? zOrder,
  }) {
    return CardModel(
      id: id ?? this.id,
      label: label ?? this.label,
      color: color ?? this.color,
      position: position ?? this.position,
      size: size ?? this.size,
      slotId: identical(slotId, _unset) ? this.slotId : slotId as String?,
      minSize: minSize ?? this.minSize,
      zOrder: zOrder ?? this.zOrder,
    );
  }
}
