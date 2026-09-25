import 'package:chart_model/chart_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/aion_theme.dart';
import '../theme/display_options.dart';
import 'chart_renderer.dart';
import 'highlight.dart';

/// Content equality for expression lists: same length and identical elements.
///
/// Callers routinely allocate a fresh list around the same expression
/// (`[data]`), so list identity is not a useful change signal.
bool expressionListsEqual(List<ChartExpression> a, List<ChartExpression> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// The size a chart actually paints at inside [box]: the whole box, or
/// the largest [aspect]-ratio rect that fits (as `AspectRatio` lays out).
Size renderedChartSize(Size box, double? aspect) {
  if (aspect == null || aspect <= 0 || !box.isFinite) return box;
  final byWidth = Size(box.width, box.width / aspect);
  if (byWidth.height <= box.height) return byWidth;
  return Size(box.height * aspect, box.height);
}

class RendererHost extends StatefulWidget {
  const RendererHost({
    super.key,
    required this.renderer,
    required this.expressionData,
    this.displayConfig = const {},
    required this.displayOpts,
    this.highlights = const {},
    this.onEntityHover,
    this.onEntityTap,
  });

  final ChartRenderer renderer;
  final List<ChartExpression> expressionData;
  final Map<String, dynamic> displayConfig;
  final DisplayOptions displayOpts;

  /// Linked-highlighting input: entities the painter should emphasize.
  final Set<HighlightEntity> highlights;

  /// Linked-highlighting output: the entity under the pointer changed
  /// (null when leaving all entities).
  final ValueChanged<HighlightEntity?>? onEntityHover;

  /// An entity (or empty space, null) was clicked.
  final ValueChanged<HighlightEntity?>? onEntityTap;

  @override
  State<RendererHost> createState() => _RendererHostState();
}

class _RendererHostState extends State<RendererHost> {
  ChartHitResult? _hitResult;
  late ChartPainter _painter;

  Map<String, dynamic> _resolveConfig() {
    final resolved = <String, dynamic>{};
    for (final opt in widget.renderer.displayOptions) {
      resolved[opt.key] = widget.displayConfig[opt.key] ?? opt.defaultValue;
    }
    return resolved;
  }

  RendererColors? _lastColors;
  List<ChartExpression>? _lastExpressionData;
  Map<String, dynamic>? _lastDisplayConfig;
  ChartRenderer? _lastRenderer;
  DisplayOptions? _lastDisplayOpts;
  Set<HighlightEntity> _lastHighlights = const {};
  int? _lastDetailLevel;
  HighlightEntity? _hoveredEntity;

  void _rebuildPainter(RendererColors colors) {
    _lastColors = colors;
    _lastExpressionData = widget.expressionData;
    _lastDisplayConfig = widget.displayConfig;
    _lastRenderer = widget.renderer;
    _lastDisplayOpts = widget.displayOpts;
    _lastHighlights = widget.highlights;
    _painter = widget.renderer.createPainter(
      expressions: widget.expressionData,
      displayConfig: _resolveConfig(),
      colors: colors,
      displayOpts: widget.displayOpts,
      highlights: widget.highlights,
      detailLevel: _lastDetailLevel,
    );
  }

  RendererColors _colorsFromTheme(AionTheme t) => RendererColors(
    text: t.cardLabelColor,
    dim: t.cardDimColor,
    accent: t.snapAccent,
    line: t.cardDimColor,
    highlight: t.highlightColor,
  );

  bool _inputsChanged(RendererColors colors) {
    final last = _lastColors;
    final lastData = _lastExpressionData;
    if (last == null || lastData == null) return true;
    return colors.text != last.text ||
        colors.dim != last.dim ||
        colors.accent != last.accent ||
        colors.line != last.line ||
        colors.highlight != last.highlight ||
        !expressionListsEqual(widget.expressionData, lastData) ||
        widget.displayConfig != _lastDisplayConfig ||
        widget.renderer != _lastRenderer ||
        widget.displayOpts != _lastDisplayOpts ||
        !setEquals(widget.highlights, _lastHighlights);
  }

  void _onHover(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(event.position);
    final hit = _painter.hitTestChart(local);
    if (hit != _hitResult) setState(() => _hitResult = hit);
    _setHoveredEntity(_painter.entityForHit(hit));
  }

  void _setHoveredEntity(HighlightEntity? entity) {
    if (entity == _hoveredEntity) return;
    _hoveredEntity = entity;
    widget.onEntityHover?.call(entity);
  }

  void _onTapUp(TapUpDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final hit = _painter.hitTestChart(
      box.globalToLocal(details.globalPosition),
    );
    widget.onEntityTap?.call(_painter.entityForHit(hit));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.biggest),
  );

  Widget _build(BuildContext context, Size box) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final colors = _colorsFromTheme(t);
    final meta = widget.renderer.meta;
    final aspect = meta.preferredAspectRatio;
    // Semantic zoom: the rendered chart size picks the detail level.
    final level = meta.detailLevels.isEmpty
        ? null
        : selectDetailLevel(meta.detailLevels, renderedChartSize(box, aspect));
    // Single change check, run on every build: covers theme changes and
    // widget updates alike, so no update can be missed between
    // didUpdateWidget and build.
    if (_inputsChanged(colors) || level != _lastDetailLevel) {
      _lastDetailLevel = level;
      _rebuildPainter(colors);
    }

    Widget chart = MouseRegion(
      onHover: _onHover,
      onExit: (_) {
        setState(() => _hitResult = null);
        _setHoveredEntity(null);
      },
      child: GestureDetector(
        onTapUp: widget.onEntityTap == null ? null : _onTapUp,
        child: CustomPaint(painter: _painter, child: const SizedBox.expand()),
      ),
    );

    if (aspect != null) {
      chart = Center(
        child: AspectRatio(aspectRatio: aspect, child: chart),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: chart),
        for (final glyph in _painter.glyphPlacements)
          Positioned(
            left: glyph.bounds.left,
            top: glyph.bounds.top,
            width: glyph.bounds.width,
            height: glyph.bounds.height,
            child: SvgPicture.asset(
              glyph.assetPath,
              colorFilter: ColorFilter.mode(glyph.color, BlendMode.srcIn),
            ),
          ),
        if (_hitResult case PlanetHit hit)
          _PlanetPopup(hit: hit, displayOpts: widget.displayOpts),
      ],
    );
  }
}

class _PlanetPopup extends StatelessWidget {
  const _PlanetPopup({required this.hit, required this.displayOpts});
  final PlanetHit hit;
  final DisplayOptions displayOpts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final p = hit.planet;
    final retro = p.retrograde ? ' (R)' : '';
    final degreeStr = '${p.degreeInSign.toStringAsFixed(1)}°';
    final name = displayOpts.planetDisplay(p.id);
    final sign = displayOpts.signDisplay(p.signIndex);

    return Positioned(
      left: hit.bounds.right + 8,
      top: hit.bounds.top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.surfaceOverlay,
          border: Border.all(color: t.surfaceBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$name $degreeStr $sign$retro'.trim(),
          style: TextStyle(color: t.cardLabelColor, fontSize: 12),
        ),
      ),
    );
  }
}
