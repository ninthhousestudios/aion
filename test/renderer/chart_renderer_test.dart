import 'dart:ui';

import 'package:aion/renderer/chart_renderer.dart';
import 'package:aion/renderer/renderer_registry.dart';
import 'package:aion/renderer/south_indian/south_indian_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('RendererMeta', () {
    test('exposes all fields', () {
      const meta = RendererMeta(
        id: 'test',
        displayName: 'Test Renderer',
        systems: ['vedic'],
        preferredAspectRatio: 1.0,
      );
      expect(meta.id, 'test');
      expect(meta.displayName, 'Test Renderer');
      expect(meta.systems, ['vedic']);
      expect(meta.preferredAspectRatio, 1.0);
    });

    test('preferredAspectRatio defaults to null', () {
      const meta = RendererMeta(
        id: 'x',
        displayName: 'X',
        systems: [],
      );
      expect(meta.preferredAspectRatio, isNull);
    });
  });

  group('DisplayOption', () {
    test('toggle option has correct defaults', () {
      const opt = DisplayOption(
        key: 'show_x',
        label: 'Show X',
        type: DisplayOptionType.toggle,
        defaultValue: false,
      );
      expect(opt.defaultValue, false);
      expect(opt.choices, isNull);
      expect(opt.group, isNull);
    });

    test('choice option has choices', () {
      const opt = DisplayOption(
        key: 'style',
        label: 'Style',
        type: DisplayOptionType.choice,
        defaultValue: 'a',
        choices: [
          DisplayChoice(value: 'a', label: 'A'),
          DisplayChoice(value: 'b', label: 'B'),
        ],
      );
      expect(opt.choices, hasLength(2));
      expect(opt.choices!.first.value, 'a');
    });
  });

  group('ChartHitResult', () {
    test('PlanetHit carries details', () {
      const hit = PlanetHit(
        planetId: 'sun',
        bounds: Rect.fromLTWH(10, 20, 30, 15),
        details: {'name': 'Sun'},
      );
      expect(hit.planetId, 'sun');
      expect(hit.bounds, const Rect.fromLTWH(10, 20, 30, 15));
      expect(hit.details['name'], 'Sun');
    });

    test('HouseHit carries house number', () {
      const hit = HouseHit(
        houseNumber: 5,
        bounds: Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(hit.houseNumber, 5);
    });

    test('sealed class pattern matching', () {
      const ChartHitResult result = PlanetHit(
        planetId: 'moon',
        bounds: Rect.fromLTWH(0, 0, 10, 10),
        details: {},
      );
      final matched = switch (result) {
        PlanetHit(planetId: final id) => 'planet:$id',
        HouseHit(houseNumber: final n) => 'house:$n',
      };
      expect(matched, 'planet:moon');
    });
  });

  group('RendererRegistry', () {
    late RendererRegistry registry;

    setUp(() {
      registry = RendererRegistry();
    });

    test('starts empty', () {
      expect(registry.all, isEmpty);
    });

    test('register and get by id', () {
      final renderer = SouthIndianRenderer();
      registry.register(renderer);
      expect(registry.get('south_indian'), same(renderer));
    });

    test('get returns null for unknown id', () {
      expect(registry.get('nope'), isNull);
    });

    test('forSystem filters by system', () {
      registry.register(SouthIndianRenderer());
      expect(registry.forSystem('vedic'), hasLength(1));
      expect(registry.forSystem('western'), isEmpty);
    });

    test('renderer with empty systems matches any system', () {
      registry.register(_UniversalRenderer());
      expect(registry.forSystem('vedic'), hasLength(1));
      expect(registry.forSystem('western'), hasLength(1));
    });
  });
}

class _UniversalRenderer extends ChartRenderer {
  @override
  RendererMeta get meta => const RendererMeta(
    id: 'universal',
    displayName: 'Universal',
    systems: [],
  );

  @override
  List<DisplayOption> get displayOptions => const [];

  @override
  ChartPainter createPainter({
    required List<Map<String, dynamic>> expressions,
    required Map<String, dynamic> displayConfig,
  }) =>
      throw UnimplementedError();
}
