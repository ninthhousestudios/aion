import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/action_menu.dart';
import '../config/config_editor.dart';
import '../commands/app_action.dart';
import '../providers/action_registry_provider.dart';
import '../providers/chart_store_provider.dart';
import '../providers/renderer_registry_provider.dart';
import '../slots/slot_state.dart';
import '../theme/aion_theme.dart';
import '../theme/preset_store.dart';
import '../shell/catalog_flyout.dart';
import '../shell/command_palette.dart';
import '../shell/rail.dart';
import '../shell/rail_state.dart';
import '../shell/slots_flyout.dart';
import '../shell/text_prompt.dart';
import '../widgets/title_bar.dart';
import 'background_layer.dart';
import 'card_model.dart';
import 'canvas_actions.dart';
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
  // Start right of the rail so no card begins underneath it.
  Offset _viewportOffset = const Offset(Rail.width, 0);
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
    final registry = ref.read(actionRegistryProvider);
    final renderers = [
      for (final r in ref.read(rendererRegistryProvider).all) r.meta,
    ];
    final actionCtx = ActionContext(
      cardId: card?.id,
      position: _viewportToWorkspace(_globalToViewport(globalPos)),
      viewportSize: _canvasSize(),
      onError: (message) {
        if (mounted) _showError(context, message);
      },
      editConfig: (request) => _editConfig(request, anchor: globalPos),
      promptText: _promptText,
    );
    final layout = card != null
        ? cardMenuIds(renderers, ref.read(slotsProvider).slots)
        : canvasMenuIds(renderers);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      color: t.surfaceOverlay,
      items: popupEntries(resolveMenu(layout, registry, actionCtx), actionCtx),
    );
    if (result == null || !mounted) return;
    await ref.read(actionRegistryProvider).execute(result, actionCtx);
  }

  /// Context for actions invoked from global surfaces (rail, palette,
  /// keyboard): targets the selected card, if any.
  ActionContext _globalActionContext() => ActionContext(
    cardId: ref.read(workspaceProvider).selectedId,
    viewportSize: _canvasSize(),
    onError: (message) {
      if (mounted) _showError(context, message);
    },
    editConfig: _editConfig,
    promptText: _promptText,
  );

  Future<String?> _promptText(String title, {String initial = ''}) async {
    if (!mounted) return null;
    return showTextPrompt(context, title, initial: initial);
  }

  void _openPalette() {
    ref.read(railProvider.notifier).close();
    showCommandPalette(
      context,
      registry: ref.read(actionRegistryProvider),
      ctx: _globalActionContext(),
    );
  }

  Future<void> _runAction(String id) =>
      ref.read(actionRegistryProvider).execute(id, _globalActionContext());

  Widget _flyoutFor(RailSection section) {
    final registry = ref.watch(actionRegistryProvider);
    final rail = ref.read(railProvider.notifier);
    return switch (section) {
      RailSection.catalog => CatalogFlyout(
        registry: registry,
        onSelect: (action) {
          rail.close();
          _runAction(action.id);
        },
      ),
      RailSection.slots => SlotsFlyout(onAction: _runAction),
      _ => const SizedBox.shrink(),
    };
  }

  void _editConfig(ConfigEditRequest request, {Offset? anchor}) {
    if (!mounted) return;
    showConfigDialog(
      context,
      title: request.title,
      initial: request.initial,
      onChanged: request.onChanged,
      anchor: anchor,
    );
  }

  Size _canvasSize() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? Size.zero;
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
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        ref.read(railProvider) != null) {
      ref.read(railProvider.notifier).close();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        HardwareKeyboard.instance.isControlPressed) {
      _openPalette();
      return;
    }
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
    final openSection = ref.watch(railProvider);

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
            if (openSection != null) ...[
              // Click-away dismiss for the open flyout.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ref.read(railProvider.notifier).close,
                  onSecondaryTap: ref.read(railProvider.notifier).close,
                ),
              ),
              Positioned(
                left: Rail.width,
                top: TitleBar.height,
                bottom: 0,
                child: _flyoutFor(openSection),
              ),
            ],
            Positioned(
              left: 0,
              top: TitleBar.height,
              bottom: 0,
              child: Rail(
                onPalette: _openPalette,
                onSettings: () => _runAction('settings.open'),
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: TitleBar()),
            Positioned(
              left: Rail.width + 12,
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
