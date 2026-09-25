import 'package:aion/canvas/arrangement.dart';
import 'package:aion/canvas/workspace_notifier.dart';
import 'package:aion/commands/app_action.dart';
import 'package:aion/providers/action_registry_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gridShape', () {
    test('sensible rows x cols', () {
      expect(gridShape(0), (0, 0));
      expect(gridShape(1), (1, 1));
      expect(gridShape(2), (1, 2));
      expect(gridShape(3), (2, 2));
      expect(gridShape(4), (2, 2));
      expect(gridShape(5), (2, 3));
      expect(gridShape(6), (2, 3));
      expect(gridShape(7), (3, 3));
      expect(gridShape(12), (3, 4));
    });
  });

  group('tileGrid', () {
    test('four cards fill a 2x2 grid over their bounds', () {
      final rects = [
        const Rect.fromLTWH(0, 0, 50, 50),
        const Rect.fromLTWH(300, 0, 10, 10),
        const Rect.fromLTWH(0, 200, 10, 10),
        const Rect.fromLTWH(200, 200, 110, 10),
      ];
      final out = tileGrid(rects, gap: 10);
      // bounds 0,0 → 310,210: cells (310-10)/2=150 wide, (210-10)/2=100 high
      expect(out[0], const Rect.fromLTWH(0, 0, 150, 100));
      expect(out[1], const Rect.fromLTWH(160, 0, 150, 100));
      expect(out[2], const Rect.fromLTWH(0, 110, 150, 100));
      expect(out[3], const Rect.fromLTWH(160, 110, 150, 100));
    });

    test('reading order decides cell order, output keeps input order', () {
      final rects = [
        const Rect.fromLTWH(100, 100, 10, 10), // second in reading order
        const Rect.fromLTWH(0, 0, 10, 10), // first
      ];
      final out = tileGrid(rects, gap: 0);
      expect(out[1].left, 0);
      expect(out[0].left, greaterThan(out[1].left));
    });

    test('no overlaps', () {
      final rects = [
        for (var i = 0; i < 7; i++) Rect.fromLTWH(i * 37.0, i * 11.0, 80, 60),
      ];
      final out = tileGrid(rects);
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          expect(out[i].overlaps(out[j]), isFalse, reason: '$i vs $j');
        }
      }
    });

    test('single rect unchanged', () {
      const r = [Rect.fromLTWH(1, 2, 3, 4)];
      expect(tileGrid(r), r);
    });
  });

  group('align', () {
    final rects = [
      const Rect.fromLTWH(10, 10, 100, 50),
      const Rect.fromLTWH(50, 100, 20, 30),
    ];

    test('edges', () {
      expect(alignRects(rects, AlignEdge.left).map((r) => r.left), [10, 10]);
      expect(alignRects(rects, AlignEdge.right).map((r) => r.right), [
        110,
        110,
      ]);
      expect(alignRects(rects, AlignEdge.top).map((r) => r.top), [10, 10]);
      expect(alignRects(rects, AlignEdge.bottom).map((r) => r.bottom), [
        130,
        130,
      ]);
    });

    test('centers keep sizes', () {
      final out = alignRects(rects, AlignEdge.centerHorizontal);
      expect(out[0].center.dx, out[1].center.dx);
      expect(out[1].size, rects[1].size);
      final v = alignRects(rects, AlignEdge.centerVertical);
      expect(v[0].center.dy, v[1].center.dy);
    });
  });

  group('distribute', () {
    test('equal horizontal gaps, outer cards fixed', () {
      final rects = [
        const Rect.fromLTWH(0, 0, 10, 10),
        const Rect.fromLTWH(15, 0, 20, 10),
        const Rect.fromLTWH(100, 0, 10, 10),
      ];
      final out = distributeRects(rects, DistributeAxis.horizontal);
      expect(out[0].left, 0);
      expect(out[2].left, 100);
      // span 110, occupied 40 → gap 35
      expect(out[1].left, 45);
    });

    test('vertical and fewer than three unchanged', () {
      final rects = [
        const Rect.fromLTWH(0, 0, 10, 10),
        const Rect.fromLTWH(0, 90, 10, 10),
        const Rect.fromLTWH(0, 20, 10, 10),
      ];
      final out = distributeRects(rects, DistributeAxis.vertical);
      expect(out[2].top, 45);
      expect(
        distributeRects(rects.take(2).toList(), DistributeAxis.vertical),
        rects.take(2).toList(),
      );
    });
  });

  group('multi-select + commands', () {
    ProviderContainer setup() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(workspaceProvider.notifier)
        ..addCard(const Offset(0, 0), const Size(100, 100), 'a')
        ..addCard(const Offset(300, 40), const Size(100, 100), 'b')
        ..addCard(const Offset(40, 300), const Size(100, 100), 'c');
      return c;
    }

    test('shift-select requires edit mode', () {
      final c = setup();
      final n = c.read(workspaceProvider.notifier)..selectCard('card_0');
      n.toggleCardSelection('card_1');
      expect(c.read(workspaceProvider).selection, {'card_0'});
      n
        ..setEditMode(true)
        ..toggleCardSelection('card_1')
        ..toggleCardSelection('card_2');
      expect(c.read(workspaceProvider).selection, {
        'card_0',
        'card_1',
        'card_2',
      });
      n.toggleCardSelection('card_1');
      expect(c.read(workspaceProvider).selection, {'card_0', 'card_2'});
      n.selectCard('card_1');
      expect(c.read(workspaceProvider).selection, {'card_1'});
    });

    test('align action moves the selected cards only in edit mode', () async {
      final c = setup();
      final n = c.read(workspaceProvider.notifier)
        ..setEditMode(true)
        ..selectCard('card_0')
        ..toggleCardSelection('card_1');
      final registry = c.read(actionRegistryProvider);
      await registry.execute('arrange.align.top', const ActionContext());
      final s = c.read(workspaceProvider);
      expect(s.cardById('card_1')?.position.dy, 0);
      expect(s.cardById('card_2')?.position, const Offset(40, 300));
      expect(
        registry
            .get('arrange.distribute.horizontal')
            ?.enabledIn(const ActionContext()),
        isFalse,
      );
      n.setEditMode(false);
      expect(
        registry.get('arrange.tile')?.enabledIn(const ActionContext()),
        isFalse,
      );
    });
  });
}
