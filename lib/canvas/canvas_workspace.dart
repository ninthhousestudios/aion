import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../actions/bind_chart_action.dart';
import '../actions/load_chart_action.dart';
import '../providers/chart_store_provider.dart';
import '../providers/renderer_registry_provider.dart';
import '../theme/aion_theme.dart';
import '../theme/preset_store.dart';
import '../widgets/title_bar.dart';
import 'background_layer.dart';
import 'card_model.dart';
import 'canvas_card.dart';
import 'snap_physics.dart';
import 'workspace_notifier.dart';

class CanvasWorkspace extends ConsumerStatefulWidget {
  const CanvasWorkspace({super.key});

  @override
  ConsumerState<CanvasWorkspace> createState() => _CanvasWorkspaceState();
}

class _CanvasWorkspaceState extends ConsumerState<CanvasWorkspace> {
  final _canvasKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  Offset _viewportOffset = Offset.zero;
  int? _workspacePanPointer;
  int? _cardDragPointer;
  String? _cardDragId;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _showContextMenu(Offset globalPos, CardModel? card) async {
    final t = Theme.of(context).extension<AionTheme>()!;
    final hasAccent =
        card != null && ref.read(workspaceProvider).accentForCard(card) != null;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      color: t.surfaceOverlay,
      items: [
        if (card != null) ...[
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
          if (hasAccent)
            const PopupMenuItem(
              value: 'cycle_color',
              child: Text('Cycle Color'),
            ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(value: 'add', child: Text('Add Card')),
        const PopupMenuItem(value: 'open_chart', child: Text('Open Chart…')),
        const PopupMenuItem(
          value: 'open_data_table',
          child: Text('Open Data Table…'),
        ),
      ],
    );
    if (result == null) return;

    final workspace = ref.read(workspaceProvider.notifier);
    switch (result) {
      case 'duplicate':
        workspace.duplicateCard(card!.id);
      case 'delete':
        workspace.deleteCard(card!.id);
      case 'cycle_color':
        final chartId = card!.expressions.first.chartId;
        workspace.cycleChartAccent(chartId);
      case 'add':
        final viewportLocal = _globalToViewport(globalPos);
        final local = _viewportToWorkspace(viewportLocal);
        final counter = ref.read(workspaceProvider).cardCounter;
        workspace.addCard(local, const Size(240, 160), 'Card $counter');
      case 'open_chart':
        await _openChartAs(globalPos, 'south_indian');
      case 'open_data_table':
        await _openChartAs(globalPos, 'data_table');
    }
  }

  Future<void> _openChartAs(Offset globalPos, String rendererType) async {
    final loadResult = await loadChartFromFile(ref.read(chartStoreProvider));
    if (!mounted) return;
    if (loadResult is ChartLoadCancelled) return;
    final result = await bindChartToCard(
      ref.read(chartStoreProvider),
      loadResult,
      rendererType: rendererType,
    );
    if (!mounted) return;
    switch (result) {
      case ChartBound(:final chartName, :final expressionRef):
        final renderer = ref.read(rendererRegistryProvider).get(rendererType);
        final ar = renderer?.meta.preferredAspectRatio;
        final size = ar != null ? const Size(500, 500) : const Size(500, 400);
        final viewportLocal = _globalToViewport(globalPos);
        final local = _viewportToWorkspace(viewportLocal);
        ref
            .read(workspaceProvider.notifier)
            .addCard(
              local,
              size,
              chartName,
              expressions: [expressionRef],
              rendererType: rendererType,
              preferredAspectRatio: ar,
            );
      case BindFailed(:final message):
        _showError(context, message);
    }
  }

  void _showError(BuildContext context, String message) {
    final t = Theme.of(context).extension<AionTheme>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: t.cardLabelColor)),
        backgroundColor: t.surfaceOverlay,
      ),
    );
  }

  Offset _globalToViewport(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  Offset _viewportToWorkspace(Offset viewportPoint) {
    return viewportPoint - _viewportOffset;
  }

  Offset _viewportDeltaToWorkspace(Offset viewportDelta) {
    return viewportDelta;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      _cyclePreset();
      return;
    }
    ref.read(workspaceProvider.notifier).handleKey(event.logicalKey);
  }

  void _cyclePreset() {
    final notifier = ref.read(presetStoreProvider.notifier);
    final store = ref.read(presetStoreProvider).valueOrNull;
    if (store == null) return;
    final names = store.presets.map((p) => p.name).toList();
    final current = names.indexOf(store.activePresetName);
    final next = (current + 1) % names.length;
    notifier.setActive(names[next]);
  }

  void _handleWorkspacePointerDown(PointerDownEvent event) {
    final viewportPoint = _globalToViewport(event.position);
    final workspacePoint = _viewportToWorkspace(viewportPoint);
    final hitCard = ref
        .read(workspaceProvider)
        .cards
        .any((card) => card.rect.contains(workspacePoint));
    _workspacePanPointer = hitCard ? null : event.pointer;
  }

  void _handleWorkspacePointerMove(PointerMoveEvent event) {
    if (_workspacePanPointer != event.pointer) return;

    setState(() => _viewportOffset += event.delta);
  }

  void _handleWorkspacePointerEnd(PointerEvent event) {
    if (_workspacePanPointer == event.pointer) {
      _workspacePanPointer = null;
    }
  }

  bool _isResizeGripHit(Offset localPosition, Size cardSize) {
    const gripSize = 14.0;
    final grips = [
      Rect.fromLTWH(0, 0, gripSize, gripSize),
      Rect.fromLTWH(cardSize.width - gripSize, 0, gripSize, gripSize),
      Rect.fromLTWH(0, cardSize.height - gripSize, gripSize, gripSize),
      Rect.fromLTWH(
        cardSize.width - gripSize,
        cardSize.height - gripSize,
        gripSize,
        gripSize,
      ),
    ];
    return grips.any((grip) => grip.contains(localPosition));
  }

  void _handleCardPointerDown(PointerDownEvent event, CardModel card) {
    if (_isResizeGripHit(event.localPosition, card.size)) return;

    _workspacePanPointer = null;
    _cardDragPointer = event.pointer;
    _cardDragId = card.id;
    ref.read(workspaceProvider.notifier).selectCard(card.id);
  }

  void _handleCardPointerMove(PointerMoveEvent event) {
    final cardId = _cardDragId;
    if (_cardDragPointer != event.pointer || cardId == null) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final canvasSize = box?.size ?? Size.zero;
    ref
        .read(workspaceProvider.notifier)
        .moveCard(cardId, _viewportDeltaToWorkspace(event.delta), canvasSize);
  }

  void _handleCardPointerEnd(PointerEvent event) {
    if (_cardDragPointer != event.pointer) return;

    _cardDragPointer = null;
    _cardDragId = null;
    ref.read(workspaceProvider.notifier).clearGuides();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final workspaceState = ref.watch(workspaceProvider);
    final workspace = ref.read(workspaceProvider.notifier);
    final sorted = workspaceState.sortedCards;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onSecondaryTapUp: (d) => _showContextMenu(d.globalPosition, null),
        onTap: () => workspace.selectCard(null),
        child: Stack(
          children: [
            const Positioned.fill(child: BackgroundLayer()),
            Container(
              key: _canvasKey,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handleWorkspacePointerDown,
                onPointerMove: _handleWorkspacePointerMove,
                onPointerUp: _handleWorkspacePointerEnd,
                onPointerCancel: _handleWorkspacePointerEnd,
                child: CustomPaint(
                  painter: _GuidePainter(
                    workspaceState.guides,
                    viewportOffset: _viewportOffset,
                    color: t.snapGuideColor,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final card in sorted)
                        Positioned(
                          left: card.position.dx + _viewportOffset.dx,
                          top: card.position.dy + _viewportOffset.dy,
                          child: RepaintBoundary(
                            key: ValueKey(card.id),
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) =>
                                  _handleCardPointerDown(event, card),
                              onPointerMove: _handleCardPointerMove,
                              onPointerUp: _handleCardPointerEnd,
                              onPointerCancel: _handleCardPointerEnd,
                              child: CanvasCard(
                                model: card,
                                chartStore: ref.read(chartStoreProvider),
                                selected: card.id == workspaceState.selectedId,
                                accentColor: workspaceState.accentForCard(card),
                                onSelect: () => workspace.selectCard(card.id),
                                onResizeUpdate: (delta, corner) =>
                                    workspace.resizeCard(
                                      card.id,
                                      _viewportDeltaToWorkspace(delta),
                                      corner,
                                    ),
                                onResizeEnd: workspace.clearGuides,
                                onContextMenu: (pos) =>
                                    _showContextMenu(pos, card),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: TitleBar()),
            Positioned(
              left: 12,
              bottom: 12,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: t.surfaceOverlay,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.surfaceBorder),
                    ),
                    child: Text(
                      'Snap: ${workspaceState.snapEnabled ? "ON" : "OFF"}  [S]',
                      style: TextStyle(
                        color: workspaceState.snapEnabled
                            ? t.snapAccent
                            : t.snapInactiveColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(
    this.guides, {
    required this.viewportOffset,
    required this.color,
  });
  final List<SnapGuide> guides;
  final Offset viewportOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (final guide in guides) {
      if (guide.axis == Axis.vertical) {
        canvas.drawLine(
          Offset(guide.position + viewportOffset.dx, 0),
          Offset(guide.position + viewportOffset.dx, size.height),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(0, guide.position + viewportOffset.dy),
          Offset(size.width, guide.position + viewportOffset.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) {
    return guides != oldDelegate.guides ||
        viewportOffset != oldDelegate.viewportOffset;
  }
}
