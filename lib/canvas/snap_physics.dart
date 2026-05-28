import 'package:flutter/widgets.dart';

class SnapResult {
  const SnapResult(this.offset, this.guides);
  final Offset offset;
  final List<SnapGuide> guides;
}

class SnapGuide {
  const SnapGuide({required this.axis, required this.position});
  final Axis axis;
  final double position;
}

class SnapPhysics {
  static const double threshold = 12.0;

  static SnapResult snap(Rect moving, List<Rect> others, Size canvasSize) {
    double dx = 0;
    double dy = 0;
    final guides = <SnapGuide>[];

    final edges = _movingEdges(moving);
    final targets = <double>[];
    final targetYs = <double>[];

    for (final other in others) {
      targets.addAll([other.left, other.right, other.center.dx]);
      targetYs.addAll([other.top, other.bottom, other.center.dy]);
    }
    if (!canvasSize.isEmpty) {
      targets.addAll([0, canvasSize.width]);
      targetYs.addAll([0, canvasSize.height]);
    }

    for (final ex in [edges.left, edges.right, edges.centerX]) {
      for (final tx in targets) {
        final dist = (ex - tx).abs();
        if (dist < threshold && (dx == 0 || dist < dx.abs())) {
          dx = tx - ex;
          guides.removeWhere((g) => g.axis == Axis.vertical);
          guides.add(SnapGuide(axis: Axis.vertical, position: tx));
        }
      }
    }

    for (final ey in [edges.top, edges.bottom, edges.centerY]) {
      for (final ty in targetYs) {
        final dist = (ey - ty).abs();
        if (dist < threshold && (dy == 0 || dist < dy.abs())) {
          dy = ty - ey;
          guides.removeWhere((g) => g.axis == Axis.horizontal);
          guides.add(SnapGuide(axis: Axis.horizontal, position: ty));
        }
      }
    }

    return SnapResult(Offset(dx, dy), guides);
  }

  static _Edges _movingEdges(Rect r) => _Edges(
    left: r.left,
    right: r.right,
    top: r.top,
    bottom: r.bottom,
    centerX: r.center.dx,
    centerY: r.center.dy,
  );
}

class _Edges {
  const _Edges({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.centerX,
    required this.centerY,
  });
  final double left, right, top, bottom, centerX, centerY;
}
