import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../chart_renderer.dart';
import '../expression_data.dart';

class SouthIndianRenderer extends ChartRenderer {
  @override
  RendererMeta get meta => const RendererMeta(
    id: 'south_indian',
    displayName: 'South Indian Grid',
    systems: ['vedic'],
    preferredAspectRatio: 1.0,
  );

  @override
  List<DisplayOption> get displayOptions => const [
    DisplayOption(
      key: 'show_outer_planets',
      label: 'Outer planets',
      group: 'Planets',
      type: DisplayOptionType.toggle,
      defaultValue: false,
    ),
    DisplayOption(
      key: 'glyph_style',
      label: 'Glyph style',
      group: 'Display',
      type: DisplayOptionType.choice,
      defaultValue: 'abbreviation',
      choices: [
        DisplayChoice(value: 'abbreviation', label: 'Abbreviation (Su, Mo)'),
        DisplayChoice(value: 'symbol', label: 'Symbol'),
      ],
    ),
  ];

  @override
  ChartPainter createPainter({
    required List<Map<String, dynamic>> expressions,
    required Map<String, dynamic> displayConfig,
  }) =>
      SouthIndianPainter(
        expressions: expressions,
        displayConfig: displayConfig,
      );
}

class _PlacedGlyph {
  final String planetId;
  final ui.Rect bounds;
  final Map<String, dynamic> details;

  _PlacedGlyph({
    required this.planetId,
    required this.bounds,
    required this.details,
  });
}

class SouthIndianPainter extends ChartPainter {
  SouthIndianPainter({
    required this.expressions,
    required this.displayConfig,
  });

  final List<Map<String, dynamic>> expressions;
  final Map<String, dynamic> displayConfig;

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

  static const _signAbbreviations = [
    'Ar', 'Ta', 'Ge', 'Cn', 'Le', 'Vi',
    'Li', 'Sc', 'Sg', 'Cp', 'Aq', 'Pi',
  ];

  static const _planetAbbreviations = {
    'sun': 'Su',
    'moon': 'Mo',
    'mars': 'Ma',
    'mercury': 'Me',
    'jupiter': 'Ju',
    'venus': 'Ve',
    'saturn': 'Sa',
    'rahu': 'Ra',
    'ketu': 'Ke',
    'uranus': 'Ur',
    'neptune': 'Ne',
    'pluto': 'Pl',
  };

  final _placedGlyphs = <_PlacedGlyph>[];
  double _cellW = 0;
  double _cellH = 0;

  @override
  void paint(Canvas canvas, ui.Size size) {
    _placedGlyphs.clear();
    _cellW = size.width / 4;
    _cellH = size.height / 4;
    final lineWidth = (_cellH * 0.008).clamp(0.5, 3.0);

    final linePaint = Paint()
      ..color = const ui.Color(0xAAFFFFFF)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Outer border
    canvas.drawRect(ui.Offset.zero & size, linePaint);

    // Vertical lines — columns 1 and 3 run full height; column 2 skips center
    canvas.drawLine(ui.Offset(_cellW, 0), ui.Offset(_cellW, size.height), linePaint);
    canvas.drawLine(ui.Offset(3 * _cellW, 0), ui.Offset(3 * _cellW, size.height), linePaint);
    // Column 2: top row and bottom row only
    canvas.drawLine(ui.Offset(2 * _cellW, 0), ui.Offset(2 * _cellW, _cellH), linePaint);
    canvas.drawLine(ui.Offset(2 * _cellW, 3 * _cellH), ui.Offset(2 * _cellW, size.height), linePaint);

    // Horizontal lines — rows 1 and 3 run full width; row 2 skips center
    canvas.drawLine(ui.Offset(0, _cellH), ui.Offset(size.width, _cellH), linePaint);
    canvas.drawLine(ui.Offset(0, 3 * _cellH), ui.Offset(size.width, 3 * _cellH), linePaint);
    // Row 2: left column and right column only
    canvas.drawLine(ui.Offset(0, 2 * _cellH), ui.Offset(_cellW, 2 * _cellH), linePaint);
    canvas.drawLine(ui.Offset(3 * _cellW, 2 * _cellH), ui.Offset(size.width, 2 * _cellH), linePaint);

    // Sign labels in each cell
    final signFontSize = (_cellH * 0.12).clamp(8.0, 14.0);
    for (final entry in _signToCell.entries) {
      final signIndex = entry.key;
      final (col, row) = entry.value;
      final cellRect = ui.Rect.fromLTWH(
        col * _cellW,
        row * _cellH,
        _cellW,
        _cellH,
      );
      _drawSignLabel(canvas, cellRect, _signAbbreviations[signIndex], signFontSize);
    }

    // Ascendant and planet placement
    final expr = expressions.firstOrNull;
    if (expr == null) return;

    final ascendant = expr[ExpressionKeys.ascendant];
    final ascSignIndex = ascendant is Map ? ascendant[ExpressionKeys.signIndex] : null;

    // Mark ascendant cell
    if (ascSignIndex is int && _signToCell.containsKey(ascSignIndex)) {
      final (col, row) = _signToCell[ascSignIndex]!;
      final ascFontSize = (_cellH * 0.11).clamp(7.0, 12.0);
      _drawText(
        canvas,
        'Asc',
        ui.Offset(col * _cellW + _cellW * 0.05, row * _cellH + _cellH * 0.55),
        ascFontSize,
        const ui.Color(0xFF6366F1),
      );
    }

    // House cusp numbers
    final houses = expr[ExpressionKeys.houses];
    if (houses is List) {
      final cuspFontSize = (_cellH * 0.11).clamp(7.0, 12.0);
      for (final house in houses) {
        if (house is! Map<String, dynamic>) continue;
        final houseSignIndex = house[ExpressionKeys.signIndex];
        final houseNumber = house['number'];
        if (houseSignIndex is! int || !_signToCell.containsKey(houseSignIndex)) continue;
        if (houseNumber is! int) continue;
        final (hCol, hRow) = _signToCell[houseSignIndex]!;
        _drawText(
          canvas,
          '$houseNumber',
          ui.Offset(
            hCol * _cellW + _cellW * 0.75,
            hRow * _cellH + _cellH * 0.75,
          ),
          cuspFontSize,
          const ui.Color(0x66FFFFFF),
        );
      }
    }

    final planets = expr[ExpressionKeys.planets];
    if (planets is! List) return;

    // Group planets by sign for layout within cells
    final planetsBySign = <int, List<Map<String, dynamic>>>{};
    for (final planet in planets) {
      if (planet is! Map<String, dynamic>) continue;
      final signIndex = planet[ExpressionKeys.signIndex];
      if (signIndex is! int || !_signToCell.containsKey(signIndex)) continue;
      planetsBySign.putIfAbsent(signIndex, () => []).add(planet);
    }

    final planetFontSize = (_cellH * 0.14).clamp(9.0, 16.0);

    for (final entry in planetsBySign.entries) {
      final (col, row) = _signToCell[entry.key]!;
      final cellX = col * _cellW;
      final cellY = row * _cellH;
      final planetsInCell = entry.value;

      for (var i = 0; i < planetsInCell.length; i++) {
        final planet = planetsInCell[i];
        final planetId = planet[ExpressionKeys.id] as String? ?? '?';
        final abbr = _planetAbbreviations[planetId] ?? planetId.substring(0, 2).capitalize();
        final retro = planet[ExpressionKeys.retrograde] == true;
        final label = retro ? '$abbr(R)' : abbr;

        // Stack planets vertically within the cell
        final x = cellX + _cellW * 0.15;
        final y = cellY + _cellH * 0.25 + (i * planetFontSize * 1.3);

        if (y + planetFontSize > cellY + _cellH) break;

        final textBounds = _drawText(
          canvas,
          label,
          ui.Offset(x, y),
          planetFontSize,
          const ui.Color(0xFFFFFFFF),
        );

        _placedGlyphs.add(_PlacedGlyph(
          planetId: planetId,
          bounds: textBounds,
          details: planet,
        ));
      }
    }
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
      const ui.Color(0x88FFFFFF),
    );
  }

  ui.Rect _drawText(
    Canvas canvas,
    String text,
    ui.Offset position,
    double fontSize,
    ui.Color color,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontFamily: 'monospace',
      ),
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

  @override
  ChartHitResult? hitTestChart(ui.Offset localPosition) {
    for (final g in _placedGlyphs) {
      if (g.bounds.contains(localPosition)) {
        return PlanetHit(
          planetId: g.planetId,
          bounds: g.bounds,
          details: g.details,
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
          bounds: ui.Rect.fromLTWH(
            col * _cellW,
            row * _cellH,
            _cellW,
            _cellH,
          ),
        );
      }
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant SouthIndianPainter oldDelegate) =>
      !identical(expressions, oldDelegate.expressions) ||
      !identical(displayConfig, oldDelegate.displayConfig);
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
