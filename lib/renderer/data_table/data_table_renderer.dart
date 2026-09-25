import 'dart:ui' as ui;

import 'package:chart_model/chart_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../theme/display_options.dart';
import '../chart_renderer.dart';
import '../highlight.dart';

class DataTableRenderer extends ChartRenderer {
  @override
  RendererMeta get meta => const RendererMeta(
    id: 'data_table',
    displayName: 'Data Table',
    systems: [],
    category: 'Tables',
    aliases: ['table', 'planets', 'positions', 'longitudes', 'dt'],
    detailLevels: detailLevels,
  );

  /// Core columns (planet, longitude, house) → all columns.
  static const detailLevels = [
    DetailLevel(id: 'core', label: 'Core columns', minShortestSide: 0),
    DetailLevel(id: 'full', label: 'All columns', minShortestSide: 300),
  ];

  /// Without a host-selected level, show every column (classic view).
  static const defaultDetailLevel = 1;

  @override
  List<DisplayOption> get displayOptions => const [
    DisplayOption(
      key: 'show_house_cusps',
      label: 'House cusps',
      group: 'Display',
      type: DisplayOptionType.toggle,
      defaultValue: false,
    ),
  ];

  @override
  ChartPainter createPainter({
    required List<ChartExpression> expressions,
    required Map<String, dynamic> displayConfig,
    required RendererColors colors,
    required DisplayOptions displayOpts,
    Set<HighlightEntity> highlights = const {},
    int? detailLevel,
  }) => DataTablePainter(
    expressions: expressions,
    displayConfig: displayConfig,
    colors: colors,
    displayOpts: displayOpts,
    highlights: highlights,
    detailLevel: detailLevel ?? defaultDetailLevel,
  );
}

/// Column width fractions (Planet, Longitude, Hse, Nakshatra, Dignity) at
/// [detailLevel]: level 0 shows the core three columns, widened to fill;
/// hidden columns get 0.
List<double> dataTableColumnFractions(int detailLevel) {
  const full = [0.18, 0.22, 0.08, 0.28, 0.16];
  if (detailLevel >= 1) return full;
  const core = 3;
  final visible = full.take(core).fold(0.0, (a, b) => a + b);
  final total = full.fold(0.0, (a, b) => a + b);
  return [
    for (var i = 0; i < full.length; i++)
      i < core ? full[i] * total / visible : 0.0,
  ];
}

/// Whether [planet]'s row is emphasized: the planet itself, or the sign or
/// house it occupies.
bool isRowHighlighted(Planet planet, Set<HighlightEntity> highlights) =>
    highlights.any(
      (h) => switch (h) {
        PlanetEntity(:final planetId) => planetId == planet.id,
        SignEntity(:final signIndex) => signIndex == planet.signIndex,
        HouseEntity(:final houseNumber) => houseNumber == planet.house,
      },
    );

class DataTablePainter extends ChartPainter {
  DataTablePainter({
    required this.expressions,
    required this.displayConfig,
    required this.colors,
    required this.displayOpts,
    this.highlights = const {},
    this.detailLevel = DataTableRenderer.defaultDetailLevel,
  });

  final List<ChartExpression> expressions;
  final Map<String, dynamic> displayConfig;
  final RendererColors colors;
  final DisplayOptions displayOpts;
  final Set<HighlightEntity> highlights;

  /// Semantic-zoom level (index into the renderer's detail levels).
  final int detailLevel;

  final _glyphPlacements = <GlyphPlacement>[];

  @override
  List<GlyphPlacement> get glyphPlacements => _glyphPlacements;

  static const _headers = [
    'Planet',
    'Longitude',
    'Hse',
    'Nakshatra',
    'Dignity',
  ];

  final _rowHits = <(ui.Rect, Planet)>[];

  @override
  void paint(Canvas canvas, ui.Size size) {
    _rowHits.clear();
    _glyphPlacements.clear();
    final expr = expressions.firstOrNull;
    if (expr == null) return;

    final showCusps = displayConfig['show_house_cusps'] == true;
    final planets = displayOpts.showOuterPlanets
        ? expr.planets
        : expr.planets.where((p) => !displayOpts.isOuterPlanet(p.id)).toList();

    final cuspCount = showCusps ? expr.houses.length : 0;
    final totalRows = 1 + planets.length + (showCusps ? 1 + cuspCount : 0);
    final fontSize = (size.height / (totalRows + 1.5)).clamp(9.0, 16.0);
    final glyphSize = fontSize * 1.1;
    final rowH = fontSize * 1.6;
    final pad = size.width * 0.03;

    final fractions = dataTableColumnFractions(detailLevel);
    final colX = <double>[];
    var cx = pad;
    for (final f in fractions) {
      colX.add(cx);
      cx += size.width * f;
    }

    final linePaint = Paint()
      ..color = colors.line
      ..strokeWidth = 1.0;
    final headerColor = colors.accent;
    final textColor = colors.text;
    final dimColor = colors.dim;

    var y = pad;

    // Header row
    for (var i = 0; i < _headers.length; i++) {
      if (fractions[i] == 0) continue;
      _drawCell(
        canvas,
        _headers[i],
        colX[i],
        y,
        size.width * fractions[i],
        fontSize,
        headerColor,
      );
    }
    y += rowH;
    canvas.drawLine(
      ui.Offset(pad, y),
      ui.Offset(size.width - pad, y),
      linePaint,
    );
    y += 2;

    // Planet rows
    for (final planet in planets) {
      if (y + rowH > size.height) break;

      final rowRect = ui.Rect.fromLTWH(0, y, size.width, rowH);
      _rowHits.add((rowRect, planet));
      if (isRowHighlighted(planet, highlights)) {
        canvas.drawRect(
          rowRect,
          Paint()..color = colors.highlightOrAccent.withValues(alpha: 0.22),
        );
      }

      final planetGlyph = displayOpts.planetGlyphPath(planet.id);
      if (planetGlyph != null) {
        _glyphPlacements.add(
          GlyphPlacement(
            assetPath: planetGlyph,
            bounds: ui.Rect.fromLTWH(colX[0], y, glyphSize, glyphSize),
            color: textColor,
          ),
        );
        if (planet.retrograde) {
          _drawCell(
            canvas,
            '(R)',
            colX[0] + glyphSize + 2,
            y,
            size.width * fractions[0] - glyphSize - 2,
            fontSize,
            dimColor,
          );
        }
      } else {
        final pName = displayOpts.planetDisplay(planet.id);
        final name = planet.retrograde ? '$pName (R)' : pName;
        _drawCell(
          canvas,
          name,
          colX[0],
          y,
          size.width * fractions[0],
          fontSize,
          textColor,
        );
      }

      final signGlyph = displayOpts.signGlyphPath(planet.signIndex);
      final degreeText = '${planet.degreeInSign.toStringAsFixed(1)}°';
      if (signGlyph != null) {
        _drawCell(
          canvas,
          '$degreeText ',
          colX[1],
          y,
          size.width * fractions[1],
          fontSize,
          textColor,
        );
        _glyphPlacements.add(
          GlyphPlacement(
            assetPath: signGlyph,
            bounds: ui.Rect.fromLTWH(
              colX[1] + (degreeText.length + 1) * fontSize * 0.6,
              y,
              glyphSize,
              glyphSize,
            ),
            color: textColor,
          ),
        );
      } else {
        final sign = displayOpts.signDisplay(planet.signIndex);
        _drawCell(
          canvas,
          '$degreeText $sign',
          colX[1],
          y,
          size.width * fractions[1],
          fontSize,
          textColor,
        );
      }

      _drawCell(
        canvas,
        '${planet.house}',
        colX[2],
        y,
        size.width * fractions[2],
        fontSize,
        dimColor,
      );

      if (fractions[3] > 0) {
        _drawCell(
          canvas,
          '${planet.nakshatra} ${planet.nakshatraPada}',
          colX[3],
          y,
          size.width * fractions[3],
          fontSize,
          textColor,
        );

        _drawCell(
          canvas,
          planet.dignity ?? '—',
          colX[4],
          y,
          size.width * fractions[4],
          fontSize,
          dimColor,
        );
      }

      y += rowH;
    }

    // House cusps section
    if (showCusps && expr.houses.isNotEmpty) {
      y += rowH * 0.3;
      canvas.drawLine(
        ui.Offset(pad, y),
        ui.Offset(size.width - pad, y),
        linePaint,
      );
      y += 2;

      _drawCell(
        canvas,
        'House',
        colX[0],
        y,
        size.width * 0.15,
        fontSize,
        headerColor,
      );
      _drawCell(
        canvas,
        'Cusp',
        colX[1],
        y,
        size.width * 0.22,
        fontSize,
        headerColor,
      );
      _drawCell(
        canvas,
        'Sign',
        colX[2],
        y,
        size.width * 0.15,
        fontSize,
        headerColor,
      );
      y += rowH;
      canvas.drawLine(
        ui.Offset(pad, y),
        ui.Offset(size.width - pad, y),
        linePaint,
      );
      y += 2;

      for (final house in expr.houses) {
        if (y + rowH > size.height) break;
        _drawCell(
          canvas,
          '${house.number}',
          colX[0],
          y,
          size.width * 0.15,
          fontSize,
          textColor,
        );
        _drawCell(
          canvas,
          '${house.cuspLongitude.toStringAsFixed(1)}°',
          colX[1],
          y,
          size.width * 0.22,
          fontSize,
          textColor,
        );
        final houseSignGlyph = displayOpts.signGlyphPath(house.signIndex);
        if (houseSignGlyph != null) {
          _glyphPlacements.add(
            GlyphPlacement(
              assetPath: houseSignGlyph,
              bounds: ui.Rect.fromLTWH(colX[2], y, glyphSize, glyphSize),
              color: dimColor,
            ),
          );
        } else {
          final sign = displayOpts.signDisplay(house.signIndex);
          _drawCell(
            canvas,
            sign,
            colX[2],
            y,
            size.width * 0.15,
            fontSize,
            dimColor,
          );
        }
        y += rowH;
      }
    }
  }

  void _drawCell(
    Canvas canvas,
    String text,
    double x,
    double y,
    double maxWidth,
    double fontSize,
    ui.Color color,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: fontSize,
              fontFamily: 'monospace',
              maxLines: 1,
              ellipsis: '…',
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));

    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }

  @override
  ChartHitResult? hitTestChart(ui.Offset localPosition) {
    for (final (bounds, planet) in _rowHits) {
      if (bounds.contains(localPosition)) {
        return PlanetHit(planetId: planet.id, bounds: bounds, planet: planet);
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant DataTablePainter oldDelegate) =>
      !identical(expressions, oldDelegate.expressions) ||
      !identical(displayConfig, oldDelegate.displayConfig) ||
      !identical(colors, oldDelegate.colors) ||
      displayOpts != oldDelegate.displayOpts ||
      !setEquals(highlights, oldDelegate.highlights) ||
      detailLevel != oldDelegate.detailLevel;
}
