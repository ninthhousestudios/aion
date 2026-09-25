import 'package:chart_model/chart_model.dart';
import 'package:flutter/rendering.dart';

import '../theme/display_options.dart';
import 'highlight.dart';

class RendererMeta {
  final String id;
  final String displayName;
  final List<String> systems;
  final double? preferredAspectRatio;

  /// View-catalog category: one of 'Charts', 'Vargas', 'Tables', 'Time'.
  final String category;

  /// Search aliases for the palette — see `renderer_aliases.dart`.
  final List<String> aliases;

  const RendererMeta({
    required this.id,
    required this.displayName,
    required this.systems,
    this.preferredAspectRatio,
    this.category = 'Charts',
    this.aliases = const [],
  });
}

enum DisplayOptionType { toggle, choice }

class DisplayChoice {
  final String value;
  final String label;

  const DisplayChoice({required this.value, required this.label});
}

class DisplayOption {
  final String key;
  final String label;
  final String? group;
  final DisplayOptionType type;
  final Object defaultValue;
  final List<DisplayChoice>? choices;

  const DisplayOption({
    required this.key,
    required this.label,
    this.group,
    required this.type,
    required this.defaultValue,
    this.choices,
  });
}

sealed class ChartHitResult {
  final Rect bounds;
  const ChartHitResult({required this.bounds});
}

class PlanetHit extends ChartHitResult {
  final String planetId;
  final Planet planet;

  const PlanetHit({
    required this.planetId,
    required super.bounds,
    required this.planet,
  });
}

class HouseHit extends ChartHitResult {
  final int houseNumber;

  const HouseHit({required this.houseNumber, required super.bounds});
}

class GlyphPlacement {
  final String assetPath;
  final Rect bounds;
  final Color color;

  const GlyphPlacement({
    required this.assetPath,
    required this.bounds,
    required this.color,
  });
}

abstract class ChartPainter extends CustomPainter {
  ChartHitResult? hitTestChart(Offset localPosition);
  List<GlyphPlacement> get glyphPlacements => const [];

  /// The linkable entity under a hit, for linked highlighting. Default:
  /// planets → [PlanetEntity], houses → [HouseEntity]. Renderers whose hit
  /// areas mean something else (a sign cell) override this.
  HighlightEntity? entityForHit(ChartHitResult? hit) => switch (hit) {
    PlanetHit(:final planetId) => PlanetEntity(planetId),
    HouseHit(:final houseNumber) => HouseEntity(houseNumber),
    null => null,
  };
}

class RendererColors {
  final Color text;
  final Color dim;
  final Color accent;
  final Color line;

  const RendererColors({
    required this.text,
    required this.dim,
    required this.accent,
    required this.line,
  });
}

abstract class ChartRenderer {
  RendererMeta get meta;
  List<DisplayOption> get displayOptions;

  /// [highlights]: entities to emphasize (linked highlighting). Painters
  /// that don't support highlighting may ignore it.
  ChartPainter createPainter({
    required List<ChartExpression> expressions,
    required Map<String, dynamic> displayConfig,
    required RendererColors colors,
    required DisplayOptions displayOpts,
    Set<HighlightEntity> highlights = const {},
  });
}
