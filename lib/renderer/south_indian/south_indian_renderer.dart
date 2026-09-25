import 'dart:ui' as ui;

import 'package:chart_model/chart_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../theme/display_options.dart';
import '../chart_renderer.dart';
import '../highlight.dart';
import '../renderer_aliases.dart';

class SouthIndianRenderer extends ChartRenderer {
  @override
  RendererMeta get meta => RendererMeta(
    id: 'south_indian',
    displayName: 'South Indian Grid',
    systems: const ['vedic'],
    preferredAspectRatio: 1.0,
    aliases: [...vargaAliases('d1'), 'si', 'south', 'grid'],
    detailLevels: detailLevels,
  );

  /// Occupancy → + degrees → + nakshatra / dignity.
  static const detailLevels = [
    DetailLevel(id: 'occupancy', label: 'Occupancy', minShortestSide: 0),
    DetailLevel(id: 'degrees', label: 'Degrees', minShortestSide: 360),
    DetailLevel(id: 'full', label: 'Full', minShortestSide: 560),
  ];

  /// Without a host-selected level, keep the classic occupancy view.
  static const defaultDetailLevel = 0;

  @override
  List<DisplayOption> get displayOptions => const [];

  @override
  ChartPainter createPainter({
    required List<ChartExpression> expressions,
    required Map<String, dynamic> displayConfig,
    required RendererColors colors,
    required DisplayOptions displayOpts,
    Set<HighlightEntity> highlights = const {},
    int? detailLevel,
  }) => SouthIndianPainter(
    expressions: expressions,
    displayConfig: displayConfig,
    colors: colors,
    displayOpts: displayOpts,
    highlights: highlights,
    detailLevel: detailLevel ?? defaultDetailLevel,
  );
}

/// A planet's text in a grid cell at [detailLevel]: name (+R), then
/// degrees, then nakshatra and dignity.
String planetCellLabel(Planet planet, String name, int detailLevel) {
  final parts = [planet.retrograde ? '$name(R)' : name];
  if (detailLevel >= 1) parts.add('${planet.degreeInSign.floor()}°');
  if (detailLevel >= 2) {
    parts.add(
      planet.nakshatra.length > 4
          ? planet.nakshatra.substring(0, 4)
          : planet.nakshatra,
    );
    if (planet.dignity case final d? when d.isNotEmpty) {
      parts.add(d.length > 3 ? d.substring(0, 3) : d);
    }
  }
  return parts.join(' ');
}

/// Sign indices to tint for [highlights]: signs directly, houses via the
/// sign their cusp falls in.
Set<int> highlightedSigns(
  ChartExpression expr,
  Set<HighlightEntity> highlights,
) => {
  for (final h in highlights)
    ...switch (h) {
      SignEntity(:final signIndex) => [signIndex],
      HouseEntity(:final houseNumber) => [
        for (final house in expr.houses)
          if (house.number == houseNumber) house.signIndex,
      ],
      PlanetEntity() => const <int>[],
    },
};

class _PlacedGlyph {
  final String planetId;
  final ui.Rect bounds;
  final Planet planet;

  _PlacedGlyph({
    required this.planetId,
    required this.bounds,
    required this.planet,
  });
}

class SouthIndianPainter extends ChartPainter {
  SouthIndianPainter({
    required this.expressions,
    required this.displayConfig,
    required this.colors,
    required this.displayOpts,
    this.highlights = const {},
    this.detailLevel = SouthIndianRenderer.defaultDetailLevel,
  });

  final List<ChartExpression> expressions;
  final Map<String, dynamic> displayConfig;
  final RendererColors colors;
  final DisplayOptions displayOpts;
  final Set<HighlightEntity> highlights;

  /// Semantic-zoom level (index into the renderer's detail levels).
  final int detailLevel;

  // Sign index (0=Aries) → grid column, row in a 4×4 grid.
  // The 12 outer cells map to zodiac signs; center 2×2 is unused.
  static const _signToCell = {
    0: (1, 0),
    1: (2, 0),
    2: (3, 0),
    3: (3, 1),
    4: (3, 2),
    5: (3, 3),
    6: (2, 3),
    7: (1, 3),
    8: (0, 3),
    9: (0, 2),
    10: (0, 1),
    11: (0, 0),
  };

  final _placedGlyphs = <_PlacedGlyph>[];
  final _glyphPlacements = <GlyphPlacement>[];
  double _cellW = 0;
  double _cellH = 0;

  @override
  List<GlyphPlacement> get glyphPlacements => _glyphPlacements;

  @override
  void paint(Canvas canvas, ui.Size size) {
    _placedGlyphs.clear();
    _glyphPlacements.clear();
    _cellW = size.width / 4;
    _cellH = size.height / 4;
    final lineWidth = (_cellH * 0.008).clamp(0.5, 3.0);

    final linePaint = Paint()
      ..color = colors.line
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Outer border
    canvas.drawRect(ui.Offset.zero & size, linePaint);

    // Vertical lines — columns 1 and 3 run full height; column 2 skips center
    canvas.drawLine(
      ui.Offset(_cellW, 0),
      ui.Offset(_cellW, size.height),
      linePaint,
    );
    canvas.drawLine(
      ui.Offset(3 * _cellW, 0),
      ui.Offset(3 * _cellW, size.height),
      linePaint,
    );
    // Column 2: top row and bottom row only
    canvas.drawLine(
      ui.Offset(2 * _cellW, 0),
      ui.Offset(2 * _cellW, _cellH),
      linePaint,
    );
    canvas.drawLine(
      ui.Offset(2 * _cellW, 3 * _cellH),
      ui.Offset(2 * _cellW, size.height),
      linePaint,
    );

    // Horizontal lines — rows 1 and 3 run full width; row 2 skips center
    canvas.drawLine(
      ui.Offset(0, _cellH),
      ui.Offset(size.width, _cellH),
      linePaint,
    );
    canvas.drawLine(
      ui.Offset(0, 3 * _cellH),
      ui.Offset(size.width, 3 * _cellH),
      linePaint,
    );
    // Row 2: left column and right column only
    canvas.drawLine(
      ui.Offset(0, 2 * _cellH),
      ui.Offset(_cellW, 2 * _cellH),
      linePaint,
    );
    canvas.drawLine(
      ui.Offset(3 * _cellW, 2 * _cellH),
      ui.Offset(size.width, 2 * _cellH),
      linePaint,
    );

    // Sign labels in each cell
    final signFontSize = (_cellH * 0.12).clamp(8.0, 14.0);
    final signGlyphSize = signFontSize * 1.2;
    for (final entry in _signToCell.entries) {
      final signIndex = entry.key;
      final (col, row) = entry.value;
      final cellRect = ui.Rect.fromLTWH(
        col * _cellW,
        row * _cellH,
        _cellW,
        _cellH,
      );
      final glyphPath = displayOpts.signGlyphPath(signIndex);
      if (glyphPath != null) {
        _glyphPlacements.add(
          GlyphPlacement(
            assetPath: glyphPath,
            bounds: ui.Rect.fromLTWH(
              cellRect.left + cellRect.width * 0.05,
              cellRect.top + cellRect.height * 0.05,
              signGlyphSize,
              signGlyphSize,
            ),
            color: colors.dim,
          ),
        );
      } else {
        final signLabel = displayOpts.signName(signIndex).substring(0, 2);
        _drawSignLabel(canvas, cellRect, signLabel, signFontSize);
      }
    }

    final expr = expressions.firstOrNull;
    if (expr == null) return;

    // Linked highlighting: tint highlighted sign cells (a highlighted house
    // tints the sign it falls in).
    final highlightPaint = Paint()
      ..color = colors.highlightOrAccent.withValues(alpha: 0.18);
    for (final sign in highlightedSigns(expr, highlights)) {
      if (_signToCell[sign] case (final col, final row)) {
        canvas.drawRect(
          ui.Rect.fromLTWH(col * _cellW, row * _cellH, _cellW, _cellH),
          highlightPaint,
        );
      }
    }

    // Mark ascendant cell
    final ascSignIndex = expr.ascendant.signIndex;
    if (_signToCell.containsKey(ascSignIndex)) {
      final (col, row) = _signToCell[ascSignIndex]!;
      final ascFontSize = (_cellH * 0.11).clamp(7.0, 12.0);
      _drawText(
        canvas,
        'Asc',
        ui.Offset(col * _cellW + _cellW * 0.05, row * _cellH + _cellH * 0.55),
        ascFontSize,
        colors.accent,
      );
    }

    // House cusp numbers
    final cuspFontSize = (_cellH * 0.11).clamp(7.0, 12.0);
    for (final house in expr.houses) {
      if (!_signToCell.containsKey(house.signIndex)) continue;
      final (hCol, hRow) = _signToCell[house.signIndex]!;
      _drawText(
        canvas,
        '${house.number}',
        ui.Offset(hCol * _cellW + _cellW * 0.75, hRow * _cellH + _cellH * 0.75),
        cuspFontSize,
        colors.dim,
      );
    }

    // Group planets by sign for layout within cells
    final planetsBySign = <int, List<Planet>>{};
    for (final planet in expr.planets) {
      if (!_signToCell.containsKey(planet.signIndex)) continue;
      if (!displayOpts.showOuterPlanets &&
          displayOpts.isOuterPlanet(planet.id)) {
        continue;
      }
      planetsBySign.putIfAbsent(planet.signIndex, () => []).add(planet);
    }

    final planetFontSize = (_cellH * 0.14).clamp(9.0, 16.0);

    for (final entry in planetsBySign.entries) {
      final (col, row) = _signToCell[entry.key]!;
      final cellX = col * _cellW;
      final cellY = row * _cellH;
      final planetsInCell = entry.value;

      final planetGlyphSize = planetFontSize * 1.2;
      final step = displayOpts.usePlanetGlyphs
          ? planetGlyphSize * 1.1
          : planetFontSize * 1.3;

      for (var i = 0; i < planetsInCell.length; i++) {
        final planet = planetsInCell[i];

        final x = cellX + _cellW * 0.15;
        final y = cellY + _cellH * 0.25 + (i * step);

        if (y + planetFontSize > cellY + _cellH) break;

        final glyphPath = displayOpts.planetGlyphPath(planet.id);
        final ui.Rect placedBounds;
        if (glyphPath != null) {
          placedBounds = ui.Rect.fromLTWH(
            x,
            y,
            planetGlyphSize,
            planetGlyphSize,
          );
          _glyphPlacements.add(
            GlyphPlacement(
              assetPath: glyphPath,
              bounds: placedBounds,
              color: colors.text,
            ),
          );
        } else {
          final label = planetCellLabel(
            planet,
            displayOpts.planetDisplay(planet.id),
            detailLevel,
          );
          placedBounds = _drawText(
            canvas,
            label,
            ui.Offset(x, y),
            planetFontSize,
            colors.text,
          );
        }

        if (highlights.contains(PlanetEntity(planet.id))) {
          _drawPlanetEmphasis(canvas, placedBounds);
        }

        _placedGlyphs.add(
          _PlacedGlyph(
            planetId: planet.id,
            bounds: placedBounds,
            planet: planet,
          ),
        );
      }
    }
  }

  void _drawPlanetEmphasis(Canvas canvas, ui.Rect bounds) {
    final box = ui.RRect.fromRectAndRadius(
      bounds.inflate(2),
      const ui.Radius.circular(3),
    );
    canvas
      ..drawRRect(
        box,
        Paint()..color = colors.highlightOrAccent.withValues(alpha: 0.25),
      )
      ..drawRRect(
        box,
        Paint()
          ..color = colors.highlightOrAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  void _drawSignLabel(
    Canvas canvas,
    ui.Rect cellRect,
    String label,
    double fontSize,
  ) {
    _drawText(
      canvas,
      label,
      ui.Offset(
        cellRect.left + cellRect.width * 0.05,
        cellRect.top + cellRect.height * 0.05,
      ),
      fontSize,
      colors.dim,
    );
  }

  ui.Rect _drawText(
    Canvas canvas,
    String text,
    ui.Offset position,
    double fontSize,
    ui.Color color,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: fontSize, fontFamily: 'monospace'),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: _cellW * 0.9));

    canvas.drawParagraph(paragraph, position);

    return ui.Rect.fromLTWH(
      position.dx,
      position.dy,
      paragraph.longestLine,
      paragraph.height,
    );
  }

  /// Grid cells are signs: the cell hit's `houseNumber` is the 1-based
  /// sign number, so it links as a [SignEntity].
  @override
  HighlightEntity? entityForHit(ChartHitResult? hit) => switch (hit) {
    HouseHit(:final houseNumber) => SignEntity(houseNumber - 1),
    _ => super.entityForHit(hit),
  };

  @override
  ChartHitResult? hitTestChart(ui.Offset localPosition) {
    for (final g in _placedGlyphs) {
      if (g.bounds.contains(localPosition)) {
        return PlanetHit(
          planetId: g.planetId,
          bounds: g.bounds,
          planet: g.planet,
        );
      }
    }

    // Fall back to house hit based on grid cell
    if (_cellW <= 0 || _cellH <= 0) return null;
    final col = (localPosition.dx / _cellW).floor();
    final row = (localPosition.dy / _cellH).floor();

    // Check if in center 2×2 area
    if (col >= 1 && col <= 2 && row >= 1 && row <= 2) return null;

    // Find the sign index for this cell
    for (final entry in _signToCell.entries) {
      final (c, r) = entry.value;
      if (c == col && r == row) {
        return HouseHit(
          houseNumber: entry.key + 1,
          bounds: ui.Rect.fromLTWH(col * _cellW, row * _cellH, _cellW, _cellH),
        );
      }
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant SouthIndianPainter oldDelegate) =>
      !identical(expressions, oldDelegate.expressions) ||
      !identical(displayConfig, oldDelegate.displayConfig) ||
      !identical(colors, oldDelegate.colors) ||
      displayOpts != oldDelegate.displayOpts ||
      !setEquals(highlights, oldDelegate.highlights) ||
      detailLevel != oldDelegate.detailLevel;
}
