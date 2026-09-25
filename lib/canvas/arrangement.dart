import 'dart:math' as math;
import 'dart:ui';

/// Pure geometry for edit-mode arrangement commands. Every function
/// returns rects in the same order as its input.

/// Rows × cols for tiling [n] cards: as square as possible, filled by rows
/// (cols = ⌈√n⌉, rows = ⌈n / cols⌉): 3 → 2×2 with one empty cell, 5 → 2×3.
(int rows, int cols) gridShape(int n) {
  if (n <= 0) return (0, 0);
  final cols = math.sqrt(n).ceil();
  final rows = (n / cols).ceil();
  return (rows, cols);
}

Rect _bounds(List<Rect> rects) =>
    rects.skip(1).fold(rects.first, (acc, r) => acc.expandToInclude(r));

/// Indices of [rects] in reading order: top-to-bottom, then left-to-right.
List<int> _readingOrder(List<Rect> rects) =>
    List<int>.generate(rects.length, (i) => i)..sort((a, b) {
      final dy = rects[a].top.compareTo(rects[b].top);
      return dy != 0 ? dy : rects[a].left.compareTo(rects[b].left);
    });

/// Tiles [rects] into a grid filling their combined bounding box, with
/// [gap] between cells. Cards keep their reading order across the cells.
List<Rect> tileGrid(List<Rect> rects, {double gap = 12}) {
  if (rects.length < 2) return rects;
  final (rows, cols) = gridShape(rects.length);
  final b = _bounds(rects);
  final cellW = math.max(1.0, (b.width - gap * (cols - 1)) / cols);
  final cellH = math.max(1.0, (b.height - gap * (rows - 1)) / rows);
  final out = List<Rect>.of(rects);
  final order = _readingOrder(rects);
  for (var cell = 0; cell < order.length; cell++) {
    final row = cell ~/ cols;
    final col = cell % cols;
    out[order[cell]] = Rect.fromLTWH(
      b.left + col * (cellW + gap),
      b.top + row * (cellH + gap),
      cellW,
      cellH,
    );
  }
  return out;
}

enum AlignEdge { left, right, top, bottom, centerHorizontal, centerVertical }

/// Aligns [rects] to an edge (or center line) of their bounding box.
/// Sizes are unchanged.
List<Rect> alignRects(List<Rect> rects, AlignEdge edge) {
  if (rects.length < 2) return rects;
  final b = _bounds(rects);
  return [
    for (final r in rects)
      switch (edge) {
        AlignEdge.left => r.translate(b.left - r.left, 0),
        AlignEdge.right => r.translate(b.right - r.right, 0),
        AlignEdge.top => r.translate(0, b.top - r.top),
        AlignEdge.bottom => r.translate(0, b.bottom - r.bottom),
        AlignEdge.centerHorizontal => r.translate(b.center.dx - r.center.dx, 0),
        AlignEdge.centerVertical => r.translate(0, b.center.dy - r.center.dy),
      },
  ];
}

enum DistributeAxis { horizontal, vertical }

/// Equalizes the gaps between [rects] along [axis]. The outermost two stay
/// put; the others move. Needs at least three rects to change anything.
List<Rect> distributeRects(List<Rect> rects, DistributeAxis axis) {
  if (rects.length < 3) return rects;
  final horizontal = axis == DistributeAxis.horizontal;
  double start(Rect r) => horizontal ? r.left : r.top;
  double extent(Rect r) => horizontal ? r.width : r.height;

  final order = List<int>.generate(rects.length, (i) => i)
    ..sort((a, b) => start(rects[a]).compareTo(start(rects[b])));
  final first = rects[order.first];
  final last = rects[order.last];
  final span = start(last) + extent(last) - start(first);
  final occupied = order.fold(0.0, (sum, i) => sum + extent(rects[i]));
  final gap = (span - occupied) / (rects.length - 1);

  final out = List<Rect>.of(rects);
  var cursor = start(first);
  for (final i in order) {
    final r = rects[i];
    out[i] = horizontal
        ? r.translate(cursor - r.left, 0)
        : r.translate(0, cursor - r.top);
    cursor += extent(r) + gap;
  }
  return out;
}
