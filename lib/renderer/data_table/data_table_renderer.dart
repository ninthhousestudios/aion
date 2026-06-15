import 'dart:ui' as ui;

import 'package:chart_model/chart_model.dart';
import 'package:flutter/rendering.dart';

import '../../theme/display_options.dart';
import '../chart_renderer.dart';

class DataTableRenderer extends ChartRenderer {
  @override
  RendererMeta get meta => const RendererMeta(
    id: 'data_table',
    displayName: 'Data Table',
    systems: [],
  );

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
  }) => DataTablePainter(
    expressions: expressions,
    displayConfig: displayConfig,
    colors: colors,
    displayOpts: displayOpts,
  );
}

class DataTablePainter extends ChartPainter {
  DataTablePainter({
    required this.expressions,
    required this.displayConfig,
    required this.colors,
    required this.displayOpts,
  });

  final List<ChartExpression> expressions;
  final Map<String, dynamic> displayConfig;
  final RendererColors colors;
  final DisplayOptions displayOpts;

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
  static const _colFractions = [0.18, 0.22, 0.08, 0.28, 0.16];

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

    final colX = <double>[];
    var cx = pad;
    for (final f in _colFractions) {
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
      _drawCell(
        canvas,
        _headers[i],
        colX[i],
        y,
        size.width * _colFractions[i],
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
            size.width * _colFractions[0] - glyphSize - 2,
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
          size.width * _colFractions[0],
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
          size.width * _colFractions[1],
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
          size.width * _colFractions[1],
          fontSize,
          textColor,
        );
      }

      _drawCell(
        canvas,
        '${planet.house}',
        colX[2],
        y,
        size.width * _colFractions[2],
        fontSize,
        dimColor,
      );

      _drawCell(
        canvas,
        '${planet.nakshatra} ${planet.nakshatraPada}',
        colX[3],
        y,
        size.width * _colFractions[3],
        fontSize,
        textColor,
      );

      _drawCell(
        canvas,
        planet.dignity ?? '—',
        colX[4],
        y,
        size.width * _colFractions[4],
        fontSize,
        dimColor,
      );

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
      displayOpts != oldDelegate.displayOpts;
}
