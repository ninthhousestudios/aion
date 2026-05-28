import 'package:flutter/material.dart';
import 'card_model.dart';

enum ResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

class CanvasCard extends StatefulWidget {
  const CanvasCard({
    super.key,
    required this.model,
    required this.selected,
    required this.onSelect,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onContextMenu,
  });

  final CardModel model;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(Offset delta, ResizeCorner corner) onResizeUpdate;
  final VoidCallback onResizeEnd;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends State<CanvasCard> {
  bool _hovered = false;
  ResizeCorner? _activeCorner;

  static const double _gripSize = 14;

  bool get _resizing => _activeCorner != null;

  MouseCursor _cursorForCorner(ResizeCorner corner) => switch (corner) {
    ResizeCorner.topLeft => SystemMouseCursors.resizeUpLeft,
    ResizeCorner.topRight => SystemMouseCursors.resizeUpRight,
    ResizeCorner.bottomLeft => SystemMouseCursors.resizeDownLeft,
    ResizeCorner.bottomRight => SystemMouseCursors.resizeDownRight,
  };

  Widget _cornerGrip(ResizeCorner corner) {
    final (
      double? top,
      double? bottom,
      double? left,
      double? right,
    ) = switch (corner) {
      ResizeCorner.topLeft => (0.0, null, 0.0, null),
      ResizeCorner.topRight => (0.0, null, null, 0.0),
      ResizeCorner.bottomLeft => (null, 0.0, 0.0, null),
      ResizeCorner.bottomRight => (null, 0.0, null, 0.0),
    };

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onPanStart: (_) => _activeCorner = corner,
        onPanUpdate: (d) => widget.onResizeUpdate(d.delta, corner),
        onPanEnd: (_) {
          _activeCorner = null;
          widget.onResizeEnd();
        },
        child: MouseRegion(
          cursor: _cursorForCorner(corner),
          child: SizedBox(width: _gripSize, height: _gripSize),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final borderColor = widget.selected
        ? Colors.white
        : _hovered
        ? Colors.white54
        : Colors.white24;

    return GestureDetector(
      onTap: widget.onSelect,
      onSecondaryTapUp: (d) => widget.onContextMenu(d.globalPosition),
      onPanUpdate: (d) {
        if (!_resizing) widget.onDragUpdate(d.delta);
      },
      onPanEnd: (_) {
        if (!_resizing) widget.onDragEnd();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.move,
        child: Container(
          width: m.size.width,
          height: m.size.height,
          decoration: BoxDecoration(
            color: m.color.withAlpha(200),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: [
              if (widget.selected)
                BoxShadow(
                  color: Colors.white.withAlpha(30),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.size.width.round()} x ${m.size.height.round()}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              for (final corner in ResizeCorner.values) _cornerGrip(corner),
            ],
          ),
        ),
      ),
    );
  }
}
