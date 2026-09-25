import 'dart:ui' as ui;

import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/data_table/data_table_renderer.dart';
import 'package:aion/renderer/highlight.dart';
import 'package:aion/renderer/south_indian/south_indian_renderer.dart';
import 'package:aion/theme/aion_theme.dart';
import 'package:aion/theme/display_options.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:flutter_test/flutter_test.dart';

import '../renderer/test_expressions.dart';

const _colors = RendererColors(
  text: ui.Color(0xFFFFFFFF),
  dim: ui.Color(0xFF888888),
  accent: ui.Color(0xFF6366F1),
  line: ui.Color(0xFF888888),
  highlight: ui.Color(0xFFFFD700),
);

void _paint(ChartPainter painter) {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const ui.Size(400, 400));
  recorder.endRecording().dispose();
}

void main() {
  final sun = testExpression.planets.first; // Leo (4), house 1

  test('data table rows: planet, its sign, or its house', () {
    expect(isRowHighlighted(sun, {const PlanetEntity('sun')}), isTrue);
    expect(isRowHighlighted(sun, {const PlanetEntity('moon')}), isFalse);
    expect(isRowHighlighted(sun, {const SignEntity(4)}), isTrue);
    expect(isRowHighlighted(sun, {const HouseEntity(1)}), isTrue);
    expect(isRowHighlighted(sun, {const HouseEntity(2)}), isFalse);
    expect(isRowHighlighted(sun, const {}), isFalse);
  });

  test('south indian tints signs directly and houses via their sign', () {
    expect(highlightedSigns(testExpression, {const SignEntity(3)}), {3});
    // House 2 cusp is in sign 5 in the test expression.
    expect(highlightedSigns(testExpression, {const HouseEntity(2)}), {5});
    expect(
      highlightedSigns(testExpression, {const PlanetEntity('sun')}),
      isEmpty,
    );
  });

  test('painters paint highlighted state without error', () {
    for (final renderer in [SouthIndianRenderer(), DataTableRenderer()]) {
      _paint(
        renderer.createPainter(
          expressions: const [testExpression],
          displayConfig: const {},
          colors: _colors,
          displayOpts: DisplayOptions.defaultOptions,
          highlights: {const PlanetEntity('sun'), const SignEntity(1)},
        ),
      );
    }
  });

  test('highlight color comes from the theme; colors fall back to accent', () {
    final t = AionTheme.fromPreset(ThemePreset.dark);
    expect(t.highlightColor, ThemePreset.dark.accentLink);
    const noHighlight = RendererColors(
      text: ui.Color(0xFFFFFFFF),
      dim: ui.Color(0xFF888888),
      accent: ui.Color(0xFF6366F1),
      line: ui.Color(0xFF888888),
    );
    expect(noHighlight.highlightOrAccent, noHighlight.accent);
    expect(_colors.highlightOrAccent, const ui.Color(0xFFFFD700));
  });
}
