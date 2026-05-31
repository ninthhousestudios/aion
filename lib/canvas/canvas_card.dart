import 'package:flutter/material.dart';
import '../mcp/chart_store.dart';
import '../mcp/expression_state.dart';
import '../renderer/renderer_host.dart';
import '../renderer/renderer_registry.dart';
import '../renderer/south_indian/south_indian_renderer.dart';
import '../theme/aion_theme.dart';
import 'card_model.dart';

final rendererRegistry = RendererRegistry()
  ..register(SouthIndianRenderer());

enum ResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

class CanvasCard extends StatefulWidget {
  const CanvasCard({
    super.key,
    required this.model,
    required this.chartStore,
    required this.selected,
    required this.onSelect,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onContextMenu,
  });

  final CardModel model;
  final ChartStore chartStore;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(Offset delta, ResizeCorner corner) onResizeUpdate;
  final VoidCallback onResizeEnd;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends State<CanvasCard> {
  bool _hovered = false;

  static const double _gripSize = 14;

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
        onPanUpdate: (d) => widget.onResizeUpdate(d.delta, corner),
        onPanEnd: (_) => widget.onResizeEnd(),
        child: MouseRegion(
          cursor: _cursorForCorner(corner),
          child: SizedBox(width: _gripSize, height: _gripSize),
        ),
      ),
    );
  }

  Widget _buildRenderer(CardModel m, AionTheme t) {
    final renderer = rendererRegistry.get(m.rendererType!);
    if (renderer == null) {
      return Center(
        child: Text(
          'Unknown renderer: ${m.rendererType}',
          style: TextStyle(color: t.cardDimColor),
        ),
      );
    }
    if (m.expressions.isEmpty) {
      return RendererHost(
        renderer: renderer,
        expressionData: const [],
        displayConfig: m.displayConfig,
      );
    }
    final ref = m.expressions.first;
    return StreamBuilder<ExpressionState>(
      stream: widget.chartStore.watchExpression(ref),
      initialData: widget.chartStore.expressionState(ref),
      builder: (context, snapshot) {
        final exprState = snapshot.data;
        return switch (exprState) {
          ExpressionLoading() => Center(
              child: CircularProgressIndicator(color: t.cardDimColor),
            ),
          ExpressionError(:final error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '$error',
                  style: TextStyle(color: t.cardDimColor, fontSize: 12),
                ),
              ),
            ),
          ExpressionReady(:final data) => RendererHost(
              renderer: renderer,
              expressionData: [data],
              displayConfig: m.displayConfig,
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final m = widget.model;
    final borderColor = widget.selected
        ? t.cardBorderSelected
        : _hovered
        ? t.cardBorderHovered
        : t.cardBorderIdle;

    return GestureDetector(
      onTap: widget.onSelect,
      onSecondaryTapUp: (d) => widget.onContextMenu(d.globalPosition),
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
                  color: t.cardShadow,
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            children: [
              if (m.rendererType != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildRenderer(m, t),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.label,
                        style: TextStyle(
                          color: t.cardLabelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.size.width.round()} x ${m.size.height.round()}',
                        style: TextStyle(
                          color: t.cardDimColor,
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
