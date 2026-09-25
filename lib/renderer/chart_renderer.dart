import 'package:chart_model/chart_model.dart';
import 'package:flutter/rendering.dart';

import '../theme/display_options.dart';
import 'highlight.dart';

/// One semantic-zoom level: used when the card's rendered area has a
/// shortest side of at least [minShortestSide] logical pixels.
class DetailLevel {
  const DetailLevel({
    required this.id,
    required this.label,
    required this.minShortestSide,
  });

  final String id;
  final String label;
  final double minShortestSide;
}

/// Index of the most detailed level in [levels] (ordered least → most
/// detailed, thresholds ascending) whose threshold [size] meets. 0 when
/// nothing matches or no levels are declared.
int selectDetailLevel(List<DetailLevel> levels, Size size) {
  final shortest = size.shortestSide;
  var chosen = 0;
  for (var i = 0; i < levels.length; i++) {
    if (shortest >= levels[i].minShortestSide) chosen = i;
  }
  return chosen;
}

class RendererMeta {
  final String id;
  final String displayName;
  final List<String> systems;
  final double? preferredAspectRatio;

  /// View-catalog category: one of 'Charts', 'Vargas', 'Tables', 'Time'.
  final String category;

  /// Search aliases for the palette — see `renderer_aliases.dart`.
  final List<String> aliases;

  /// Semantic zoom: ordered detail levels (least → most detailed). Empty
  /// means a single level. The host picks one from the card's size.
  final List<DetailLevel> detailLevels;

  const RendererMeta({
    required this.id,
    required this.displayName,
    required this.systems,
    this.preferredAspectRatio,
    this.category = 'Charts',
    this.aliases = const [],
    this.detailLevels = const [],
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

  /// Linked-highlighting emphasis; falls back to [accent].
  final Color? highlight;

  Color get highlightOrAccent => highlight ?? accent;

  const RendererColors({
    required this.text,
    required this.dim,
    required this.accent,
    required this.line,
    this.highlight,
  });
}

abstract class ChartRenderer {
  RendererMeta get meta;
  List<DisplayOption> get displayOptions;

  /// [highlights]: entities to emphasize (linked highlighting). Painters
  /// that don't support highlighting may ignore it.
  ///
  /// [detailLevel]: index into [RendererMeta.detailLevels] chosen by the
  /// host from the card size; null means the renderer's own default.
  ChartPainter createPainter({
    required List<ChartExpression> expressions,
    required Map<String, dynamic> displayConfig,
    required RendererColors colors,
    required DisplayOptions displayOpts,
    Set<HighlightEntity> highlights = const {},
    int? detailLevel,
  });
}
