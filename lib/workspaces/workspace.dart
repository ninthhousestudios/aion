import 'dart:ui';

import 'package:toml/toml.dart';

import '../canvas/card_model.dart';
import '../slots/card_binding.dart';
import '../slots/chart_slot.dart';
import '../slots/slot_state.dart';
import '../theme/card_display_overrides.dart';

/// One card in a saved layout: geometry, renderer, binding and per-card
/// overrides. Holds no chart data — a slot binding names only a slot id.
class WorkspaceCard {
  const WorkspaceCard({
    required this.label,
    required this.rect,
    this.kind = CardKind.chart,
    this.rendererType,
    this.binding,
    this.configOverride,
    this.displayConfig = const {},
    this.displayOverrides = CardDisplayOverrides.empty,
    this.opacityOverride,
    this.preferredAspectRatio,
  });

  factory WorkspaceCard.fromCard(CardModel card) => WorkspaceCard(
    label: card.label,
    rect: card.rect,
    kind: card.kind,
    rendererType: card.rendererType,
    binding: card.binding,
    configOverride: card.configOverride,
    displayConfig: {
      for (final e in card.displayConfig.entries)
        if (e.value case final Object v) e.key: v,
    },
    displayOverrides: card.displayOverrides,
    opacityOverride: card.opacityOverride,
    preferredAspectRatio: card.preferredAspectRatio,
  );

  final String label;
  final Rect rect;
  final CardKind kind;
  final String? rendererType;
  final CardBinding? binding;
  final ExpressionConfig? configOverride;
  final Map<String, Object> displayConfig;
  final CardDisplayOverrides displayOverrides;
  final double? opacityOverride;
  final double? preferredAspectRatio;

  /// A live card. A slot binding naming a slot that doesn't exist in
  /// [slots] is rebound to the default slot rather than erroring.
  CardModel toCard({
    required String id,
    required int zOrder,
    required SlotState slots,
  }) {
    final b = binding;
    return CardModel(
      id: id,
      label: label,
      position: rect.topLeft,
      size: rect.size,
      zOrder: zOrder,
      kind: kind,
      rendererType: rendererType,
      binding: b is SlotBinding
          ? SlotBinding(slots.resolveSlotId(b.slotId))
          : b,
      configOverride: configOverride,
      displayConfig: displayConfig,
      displayOverrides: displayOverrides,
      opacityOverride: opacityOverride,
      preferredAspectRatio: preferredAspectRatio,
    );
  }
}

/// A named layout template that charts flow through via slots.
class Workspace {
  const Workspace({
    required this.name,
    required this.cards,
    this.readOnly = false,
  });

  factory Workspace.fromCards(String name, Iterable<CardModel> cards) =>
      Workspace(
        name: name,
        cards: [
          for (final c
              in cards.toList()..sort((a, b) => a.zOrder.compareTo(b.zOrder)))
            WorkspaceCard.fromCard(c),
        ],
      );

  final String name;

  /// Back-to-front (z-order ascending).
  final List<WorkspaceCard> cards;

  /// Starter workspaces are read-only; saving forks them under a new name.
  final bool readOnly;

  Workspace copyWith({String? name, bool? readOnly}) => Workspace(
    name: name ?? this.name,
    cards: cards,
    readOnly: readOnly ?? this.readOnly,
  );

  static const formatVersion = 1;

  String toToml() => TomlDocument.fromMap({
    'name': name,
    'version': formatVersion,
    'cards': [for (final c in cards) _cardToMap(c)],
  }).toString();

  /// Parses a workspace file. Unknown keys are ignored; malformed cards are
  /// skipped. Throws [FormatException] only when there's no usable name.
  factory Workspace.fromToml(String source) {
    final Map<String, dynamic> doc;
    try {
      doc = TomlDocument.parse(source).toMap();
    } on Object catch (e) {
      throw FormatException('Invalid workspace TOML: $e');
    }
    final name = doc['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Workspace has no name');
    }
    final raw = doc['cards'];
    return Workspace(
      name: name,
      cards: [
        if (raw is List)
          for (final c in raw)
            if (c is Map<String, dynamic>) ?_cardFromMap(c),
      ],
    );
  }
}

Map<String, Object> _cardToMap(WorkspaceCard c) {
  final binding = c.binding;
  final overrides = c.displayOverrides;
  return {
    'kind': c.kind.name,
    'label': c.label,
    'x': c.rect.left,
    'y': c.rect.top,
    'width': c.rect.width,
    'height': c.rect.height,
    'renderer': ?c.rendererType,
    'aspect_ratio': ?c.preferredAspectRatio,
    'opacity': ?c.opacityOverride,
    if (binding != null)
      'binding': switch (binding) {
        SlotBinding(:final slotId) => {'type': 'slot', 'slot': slotId},
        PinnedBinding(:final chartId, :final chartName, :final config) => {
          'type': 'pinned',
          'chart_id': chartId,
          'chart_name': ?chartName,
          if (config.isNotEmpty) 'config': canonicalConfig(config),
        },
      },
    if (c.configOverride case final o?) 'config_override': canonicalConfig(o),
    if (c.displayConfig.isNotEmpty) 'display_config': c.displayConfig,
    if (!overrides.isEmpty)
      'display_overrides': {
        'use_sign_glyphs': ?overrides.useSignGlyphs,
        'use_planet_glyphs': ?overrides.usePlanetGlyphs,
        'show_outer_planets': ?overrides.showOuterPlanets,
        'sign_names': ?overrides.signNames,
      },
  };
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Recursively converts parsed TOML into JSON-safe config values.
Map<String, Object> _objectMap(Object? raw) {
  Object? conv(Object? v) => switch (v) {
    Map<String, dynamic> m => _objectMap(m),
    List<dynamic> l => [for (final e in l) ?conv(e)],
    String() || bool() || num() => v,
    _ => null,
  };
  if (raw is! Map<String, dynamic>) return const {};
  return {
    for (final e in raw.entries)
      if (conv(e.value) case final Object v) e.key: v,
  };
}

WorkspaceCard? _cardFromMap(Map<String, dynamic> m) {
  final x = _num(m['x']);
  final y = _num(m['y']);
  final w = _num(m['width']);
  final h = _num(m['height']);
  if (x == null || y == null || w == null || h == null) return null;

  final kind =
      CardKind.values.where((k) => k.name == m['kind']).firstOrNull ??
      CardKind.chart;

  CardBinding? binding;
  final b = m['binding'];
  if (b is Map<String, dynamic>) {
    switch (b['type']) {
      case 'slot':
        final slot = b['slot'];
        binding = SlotBinding(slot is String ? slot : SlotState.kDefaultSlotId);
      case 'pinned':
        final chartId = b['chart_id'];
        final chartName = b['chart_name'];
        if (chartId is String) {
          binding = PinnedBinding(
            chartId: chartId,
            chartName: chartName is String ? chartName : null,
            config: _objectMap(b['config']),
          );
        }
    }
  }

  final o = m['display_overrides'];
  final overrides = o is Map<String, dynamic>
      ? CardDisplayOverrides(
          useSignGlyphs: o['use_sign_glyphs'] is bool
              ? o['use_sign_glyphs'] as bool
              : null,
          usePlanetGlyphs: o['use_planet_glyphs'] is bool
              ? o['use_planet_glyphs'] as bool
              : null,
          showOuterPlanets: o['show_outer_planets'] is bool
              ? o['show_outer_planets'] as bool
              : null,
          signNames: o['sign_names'] is List
              ? [for (final s in o['sign_names'] as List) '$s']
              : null,
        )
      : CardDisplayOverrides.empty;

  final label = m['label'];
  final renderer = m['renderer'];
  return WorkspaceCard(
    label: label is String ? label : '',
    rect: Rect.fromLTWH(x, y, w, h),
    kind: kind,
    rendererType: renderer is String ? renderer : null,
    binding: binding,
    configOverride: m.containsKey('config_override')
        ? _objectMap(m['config_override'])
        : null,
    displayConfig: _objectMap(m['display_config']),
    displayOverrides: overrides,
    opacityOverride: _num(m['opacity']),
    preferredAspectRatio: _num(m['aspect_ratio']),
  );
}
