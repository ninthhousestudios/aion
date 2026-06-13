import 'dart:ui';

import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/data_table/data_table_renderer.dart';
import 'package:chart_model/chart_model.dart';
import 'package:test/test.dart';

import 'test_expressions.dart';

void main() {
  late DataTableRenderer renderer;

  setUp(() {
    renderer = DataTableRenderer();
  });

  group('DataTableRenderer meta', () {
    test('has correct id', () {
      expect(renderer.meta.id, 'data_table');
    });

    test('has correct display name', () {
      expect(renderer.meta.displayName, 'Data Table');
    });

    test('supports all systems (empty list)', () {
      expect(renderer.meta.systems, isEmpty);
    });

    test('has no fixed aspect ratio', () {
      expect(renderer.meta.preferredAspectRatio, isNull);
    });
  });

  group('displayOptions', () {
    test('has show_outer_planets toggle', () {
      final opt = renderer.displayOptions.firstWhere(
        (o) => o.key == 'show_outer_planets',
      );
      expect(opt.defaultValue, false);
      expect(opt.type, DisplayOptionType.toggle);
    });

    test('has show_house_cusps toggle', () {
      final opt = renderer.displayOptions.firstWhere(
        (o) => o.key == 'show_house_cusps',
      );
      expect(opt.defaultValue, false);
      expect(opt.type, DisplayOptionType.toggle);
    });
  });

  group('DataTablePainter', () {
    test('createPainter returns DataTablePainter', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      expect(painter, isA<DataTablePainter>());
    });

    test('paints at 300x200 without error', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(300, 200));
      recorder.endRecording();
    });

    test('paints at 800x600 without error', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();
    });

    test('paints with empty expressions without error', () {
      final painter = renderer.createPainter(
        expressions: const [],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints with house cusps enabled', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {'show_house_cusps': true},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();
    });

    test('hitTestChart returns PlanetHit for planet row', () {
      final painter =
          renderer.createPainter(
                expressions: const [testExpression],
                displayConfig: const {},
              )
              as DataTablePainter;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();

      // Y below header: header takes ~1 row + separator, first planet row starts after
      // With 3 planets + 1 header = 4 rows, fontSize ~(300/5.5) ≈ clamped to 16,
      // rowH ~25.6, header ends at ~padding + 25.6 + 2 ≈ 39.6
      // First planet row at y ~40, so middle of first row at ~52
      final hit = painter.hitTestChart(const Offset(100, 52));
      expect(hit, isA<PlanetHit>());
    });

    test('hitTestChart returns null above header', () {
      final painter =
          renderer.createPainter(
                expressions: const [testExpression],
                displayConfig: const {},
              )
              as DataTablePainter;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();

      final hit = painter.hitTestChart(const Offset(100, 5));
      expect(hit, isNull);
    });

    test('shouldRepaint returns true for different list instances', () {
      final p1 =
          renderer.createPainter(
                expressions: [testExpression],
                displayConfig: const {},
              )
              as DataTablePainter;
      final p2 =
          renderer.createPainter(
                expressions: [testExpression],
                displayConfig: const {},
              )
              as DataTablePainter;
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint returns false for identical data', () {
      const data = [testExpression];
      const config = <String, dynamic>{};
      final p1 =
          renderer.createPainter(expressions: data, displayConfig: config)
              as DataTablePainter;
      final p2 = DataTablePainter(expressions: data, displayConfig: config);
      expect(p1.shouldRepaint(p2), isFalse);
    });
  });
}
