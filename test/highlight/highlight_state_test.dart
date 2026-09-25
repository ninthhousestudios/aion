import 'package:aion/highlight/highlight_state.dart';
import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/data_table/data_table_renderer.dart';
import 'package:aion/renderer/highlight.dart';
import 'package:aion/renderer/south_indian/south_indian_renderer.dart';
import 'package:aion/slots/card_binding.dart';
import 'package:aion/theme/display_options.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../renderer/test_expressions.dart';

const _sun = PlanetEntity('sun');
const _moon = PlanetEntity('moon');
const _colors = RendererColors(
  text: Color(0xFFFFFFFF),
  dim: Color(0xFF888888),
  accent: Color(0xFF6366F1),
  line: Color(0xFF888888),
);

void main() {
  group('scoping', () {
    test('scope per slot; pinned per chart; unbound none', () {
      expect(highlightScopeFor(const SlotBinding('A')), 'slot:A');
      expect(highlightScopeFor(const PinnedBinding(chartId: 'x')), 'chart:x');
      expect(highlightScopeFor(null), isNull);
    });

    test('only same-scope cards receive the highlight', () {
      const s = HighlightState(entity: _sun, scope: 'slot:A');
      expect(s.highlightsFor('slot:A'), {_sun});
      expect(s.highlightsFor('slot:B'), isEmpty);
      expect(s.highlightsFor('chart:x'), isEmpty);
      expect(s.highlightsFor(null), isEmpty);
    });
  });

  group('transitions', () {
    test('hover sets and clears a transient highlight', () {
      var s = HighlightTransitions.hover(HighlightState.none, _sun, 'slot:A');
      expect(s, const HighlightState(entity: _sun, scope: 'slot:A'));
      s = HighlightTransitions.hover(s, null, 'slot:A');
      expect(s.isEmpty, isTrue);
    });

    test('hover → click locks; hover no longer changes it', () {
      var s = HighlightTransitions.hover(HighlightState.none, _sun, 'slot:A');
      s = HighlightTransitions.click(s, _sun, 'slot:A');
      expect(s.locked, isTrue);
      s = HighlightTransitions.hover(s, _moon, 'slot:A');
      expect(s.entity, _sun);
      s = HighlightTransitions.hover(s, null, null);
      expect(s.entity, _sun);
    });

    test('clicking the locked entity unlocks to transient', () {
      var s = HighlightTransitions.click(HighlightState.none, _sun, 'slot:A');
      s = HighlightTransitions.click(s, _sun, 'slot:A');
      expect(s.locked, isFalse);
      expect(s.entity, _sun);
    });

    test('clicking another entity moves the lock; empty space unlocks', () {
      var s = HighlightTransitions.click(HighlightState.none, _sun, 'slot:A');
      s = HighlightTransitions.click(s, _moon, 'slot:B');
      expect(
        s,
        const HighlightState(entity: _moon, scope: 'slot:B', locked: true),
      );
      s = HighlightTransitions.click(s, null, 'slot:B');
      expect(s.isEmpty, isTrue);
    });

    test('notifier: hover → locked → Esc clear', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(highlightProvider.notifier)
        ..hover(_sun, 'slot:A')
        ..click(_sun, 'slot:A');
      expect(c.read(highlightProvider).locked, isTrue);
      c.read(highlightProvider.notifier).clear();
      expect(c.read(highlightProvider), HighlightState.none);
    });
  });

  group('renderer channel', () {
    test('painters receive highlights and repaint when they change', () {
      for (final renderer in [SouthIndianRenderer(), DataTableRenderer()]) {
        ChartPainter paint(Set<HighlightEntity> h) => renderer.createPainter(
          expressions: const [testExpression],
          displayConfig: const {},
          colors: _colors,
          displayOpts: DisplayOptions.defaultOptions,
          highlights: h,
        );
        final plain = paint(const {});
        final lit = paint({_sun});
        expect(lit.shouldRepaint(plain), isTrue, reason: renderer.meta.id);
        expect(paint({_sun}).shouldRepaint(lit), isFalse);
      }
    });

    test('hit → entity mapping', () {
      final si = SouthIndianRenderer().createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
        colors: _colors,
        displayOpts: DisplayOptions.defaultOptions,
      );
      const house = HouseHit(houseNumber: 12, bounds: Rect.zero);
      // South indian cells are signs.
      expect(si.entityForHit(house), const SignEntity(11));
      final dt = DataTableRenderer().createPainter(
        expressions: const [testExpression],
        displayConfig: const {},
        colors: _colors,
        displayOpts: DisplayOptions.defaultOptions,
      );
      expect(dt.entityForHit(house), const HouseEntity(12));
      final sun = testExpression.planets.first;
      expect(
        dt.entityForHit(
          PlanetHit(planetId: 'sun', bounds: Rect.zero, planet: sun),
        ),
        _sun,
      );
      expect(dt.entityForHit(null), isNull);
    });
  });
}
