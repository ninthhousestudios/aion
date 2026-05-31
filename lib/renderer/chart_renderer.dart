import 'package:flutter/rendering.dart';

class RendererMeta {
  final String id;
  final String displayName;
  final List<String> systems;
  final double? preferredAspectRatio;

  const RendererMeta({
    required this.id,
    required this.displayName,
    required this.systems,
    this.preferredAspectRatio,
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
  final Map<String, dynamic> details;

  const PlanetHit({
    required this.planetId,
    required super.bounds,
    required this.details,
  });
}

class HouseHit extends ChartHitResult {
  final int houseNumber;

  const HouseHit({required this.houseNumber, required super.bounds});
}

abstract class ChartPainter extends CustomPainter {
  ChartHitResult? hitTestChart(Offset localPosition);
}

abstract class ChartRenderer {
  RendererMeta get meta;
  List<DisplayOption> get displayOptions;

  ChartPainter createPainter({
    required List<Map<String, dynamic>> expressions,
    required Map<String, dynamic> displayConfig,
  });
}
