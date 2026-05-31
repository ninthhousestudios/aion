import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aion_theme.dart';
import 'chart_renderer.dart';

class RendererHost extends StatefulWidget {
  const RendererHost({
    super.key,
    required this.renderer,
    required this.expressionData,
    this.displayConfig = const {},
  });

  final ChartRenderer renderer;
  final List<Map<String, dynamic>> expressionData;
  final Map<String, dynamic> displayConfig;

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

  void _rebuildPainter() {
    _painter = widget.renderer.createPainter(
      expressions: widget.expressionData,
      displayConfig: _resolveConfig(),
    );
  }

  @override
  void initState() {
    super.initState();
    _rebuildPainter();
  }

  @override
  void didUpdateWidget(RendererHost old) {
    super.didUpdateWidget(old);
    if (widget.expressionData != old.expressionData ||
        widget.displayConfig != old.displayConfig ||
        widget.renderer != old.renderer) {
      _rebuildPainter();
    }
  }

  void _onHover(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(event.position);
    final hit = _painter.hitTestChart(local);
    if (hit != _hitResult) setState(() => _hitResult = hit);
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.renderer.meta.preferredAspectRatio;

    Widget chart = MouseRegion(
      onHover: _onHover,
      onExit: (_) => setState(() => _hitResult = null),
      child: CustomPaint(
        painter: _painter,
        child: const SizedBox.expand(),
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
        if (_hitResult case PlanetHit hit) _PlanetPopup(hit: hit),
      ],
    );
  }
}

class _PlanetPopup extends StatelessWidget {
  const _PlanetPopup({required this.hit});
  final PlanetHit hit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final name = hit.details['name'] ?? hit.planetId;
    final degree = hit.details['degree_in_sign'];
    final sign = hit.details['sign'] ?? '';
    final retro = hit.details['retrograde'] == true ? ' (R)' : '';
    final degreeStr = degree is num ? '${degree.toStringAsFixed(1)}°' : '';

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
