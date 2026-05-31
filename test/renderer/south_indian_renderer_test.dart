import 'dart:ui';

import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/south_indian/south_indian_renderer.dart';
import 'package:test/test.dart';

import 'test_expressions.dart';

void main() {
  late SouthIndianRenderer renderer;

  setUp(() {
    renderer = SouthIndianRenderer();
  });

  group('SouthIndianRenderer meta', () {
    test('has correct id', () {
      expect(renderer.meta.id, 'south_indian');
    });

    test('has correct display name', () {
      expect(renderer.meta.displayName, 'South Indian Grid');
    });

    test('supports vedic system', () {
      expect(renderer.meta.systems, ['vedic']);
    });

    test('has 1:1 aspect ratio', () {
      expect(renderer.meta.preferredAspectRatio, 1.0);
    });
  });

  group('displayOptions', () {
    test('has show_outer_planets toggle', () {
      final opt =
          renderer.displayOptions.firstWhere((o) => o.key == 'show_outer_planets');
      expect(opt.defaultValue, false);
    });

    test('has glyph_style choice', () {
      final opt =
          renderer.displayOptions.firstWhere((o) => o.key == 'glyph_style');
      expect(opt.defaultValue, 'abbreviation');
      expect(opt.choices, isNotNull);
    });
  });

  group('SouthIndianPainter', () {
    test('createPainter returns SouthIndianPainter', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      expect(painter, isA<SouthIndianPainter>());
    });

    test('paints at 200x200 without error', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      recorder.endRecording();
    });

    test('paints at 800x800 without error', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 800));
      recorder.endRecording();
    });

    test('paints grid skeleton with empty expressions', () {
      final painter = renderer.createPainter(
        expressions: const [],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('paints with malformed data — missing planets key', () {
      final painter = renderer.createPainter(
        expressions: const [{'ascendant': {}}],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('paints with malformed data — bad sign_index', () {
      final painter = renderer.createPainter(
        expressions: const [
          {
            'planets': [
              {'id': 'x', 'sign_index': 99},
              {'id': 'y', 'sign_index': 'not_a_number'},
              {'id': 'z'},
            ],
            'ascendant': {'sign_index': 4},
          }
        ],
        displayConfig: const {},
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('hitTestChart returns null for center area', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      ) as SouthIndianPainter;
      // Paint first to set up geometry
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();

      // Center of the 4×4 grid (cells 1,1 to 2,2)
      final centerHit = painter.hitTestChart(const Offset(200, 200));
      expect(centerHit, isNull);
    });

    test('hitTestChart returns HouseHit for outer cell', () {
      final painter = renderer.createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
      ) as SouthIndianPainter;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();

      // Top-left cell: sign_index 11 (Pisces) → house number 12
      final hit = painter.hitTestChart(const Offset(10, 10));
      expect(hit, isA<HouseHit>());
      expect((hit as HouseHit).houseNumber, 12);
    });

    test('shouldRepaint returns true for different list instances', () {
      final p1 = renderer.createPainter(
        expressions: [testExpression],
        displayConfig: const {},
      ) as SouthIndianPainter;
      final p2 = renderer.createPainter(
        expressions: [testExpression],
        displayConfig: const {},
      ) as SouthIndianPainter;
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint returns false for identical data', () {
      const data = [testExpression];
      const config = <String, dynamic>{};
      final p1 = renderer.createPainter(
        expressions: data,
        displayConfig: config,
      ) as SouthIndianPainter;
      final p2 = SouthIndianPainter(
        expressions: data,
        displayConfig: config,
      );
      expect(p1.shouldRepaint(p2), isFalse);
    });
  });
}
