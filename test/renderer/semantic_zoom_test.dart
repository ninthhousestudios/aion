import 'dart:ui';

import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/data_table/data_table_renderer.dart';
import 'package:aion/renderer/renderer_host.dart';
import 'package:aion/renderer/south_indian/south_indian_renderer.dart';
import 'package:aion/theme/display_options.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_expressions.dart';

const _levels = [
  DetailLevel(id: 'a', label: 'A', minShortestSide: 0),
  DetailLevel(id: 'b', label: 'B', minShortestSide: 300),
  DetailLevel(id: 'c', label: 'C', minShortestSide: 500),
];

const _colors = RendererColors(
  text: Color(0xFFFFFFFF),
  dim: Color(0xFF888888),
  accent: Color(0xFF6366F1),
  line: Color(0xFF888888),
);

void main() {
  group('selectDetailLevel boundaries', () {
    test('thresholds are inclusive on the shortest side', () {
      expect(selectDetailLevel(_levels, const Size(299.9, 1000)), 0);
      expect(selectDetailLevel(_levels, const Size(300, 1000)), 1);
      expect(selectDetailLevel(_levels, const Size(1000, 499.9)), 1);
      expect(selectDetailLevel(_levels, const Size(500, 500)), 2);
      expect(selectDetailLevel(_levels, const Size(4000, 4000)), 2);
    });

    test('tiny, zero and no-levels cases', () {
      expect(selectDetailLevel(_levels, Size.zero), 0);
      expect(selectDetailLevel(const [], const Size(900, 900)), 0);
    });
  });

  group('rendered chart size', () {
    test('aspect ratio fits inside the box', () {
      expect(renderedChartSize(const Size(800, 400), 1), const Size(400, 400));
      expect(renderedChartSize(const Size(400, 800), 1), const Size(400, 400));
      expect(
        renderedChartSize(const Size(800, 400), null),
        const Size(800, 400),
      );
    });
  });

  group('renderer declarations', () {
    test('south indian: 3 ordered levels; data table: 2', () {
      final si = SouthIndianRenderer().meta.detailLevels;
      final dt = DataTableRenderer().meta.detailLevels;
      expect(si, hasLength(3));
      expect(dt, hasLength(2));
      for (final levels in [si, dt]) {
        expect(levels.first.minShortestSide, 0);
        final thresholds = [for (final l in levels) l.minShortestSide];
        expect(thresholds, [...thresholds]..sort());
      }
    });

    test('south indian labels grow with level', () {
      final mars = testExpression.planets[2]; // Libra 20.0, retrograde
      expect(planetCellLabel(mars, 'Ma', 0), 'Ma(R)');
      expect(planetCellLabel(mars, 'Ma', 1), 'Ma(R) 20°');
      expect(planetCellLabel(mars, 'Ma', 2), 'Ma(R) 20° Swat');
    });

    test('data table: core columns at level 0, all at level 1', () {
      final core = dataTableColumnFractions(0);
      final full = dataTableColumnFractions(1);
      expect(core.sublist(3), [0, 0]);
      expect(full.every((f) => f > 0), isTrue);
      double sum(List<double> l) => l.fold(0.0, (a, b) => a + b);
      expect(sum(core), closeTo(sum(full), 1e-9));
    });

    test('painters receive the level and repaint on change', () {
      for (final renderer in [SouthIndianRenderer(), DataTableRenderer()]) {
        ChartPainter paint(int? level) => renderer.createPainter(
          expressions: const [testExpression],
          displayConfig: const {},
          colors: _colors,
          displayOpts: DisplayOptions.defaultOptions,
          detailLevel: level,
        );
        expect(paint(1).shouldRepaint(paint(0)), isTrue);
        expect(paint(0).shouldRepaint(paint(0)), isFalse);
      }
    });
  });
}
