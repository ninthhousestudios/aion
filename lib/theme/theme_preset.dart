import 'dart:ui';

import 'package:toml/toml.dart';

enum BackgroundType { solid, image }

class ThemePreset {
  const ThemePreset({
    required this.name,
    this.backgroundType = BackgroundType.solid,
    required this.backgroundColor,
    this.backgroundImagePath,
    required this.surfaceCard,
    required this.surfacePanel,
    required this.surfaceBorderIdle,
    required this.surfaceBorderHovered,
    required this.surfaceBorderSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentSeed,
    required this.accentLink,
    this.cardOpacity = 1.0,
    this.statusStripHeight = 4.0,
  });

  final String name;

  final BackgroundType backgroundType;
  final Color backgroundColor;
  final String? backgroundImagePath;

  final Color surfaceCard;
  final Color surfacePanel;
  final Color surfaceBorderIdle;
  final Color surfaceBorderHovered;
  final Color surfaceBorderSelected;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accentSeed;
  final Color accentLink;

  final double cardOpacity;
  final double statusStripHeight;

  static const dark = ThemePreset(
    name: 'dark',
    backgroundColor: Color(0xFF0F0F1A),
    surfaceCard: Color(0xFF1E1E2E),
    surfacePanel: Color(0xFF1E1E2E),
    surfaceBorderIdle: Color(0x3DFFFFFF),
    surfaceBorderHovered: Color(0x8AFFFFFF),
    surfaceBorderSelected: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x78FFFFFF),
    accentSeed: Color(0xFF6366F1),
    accentLink: Color(0xFF818CF8),
  );

  static const light = ThemePreset(
    name: 'light',
    backgroundColor: Color(0xFFF5F5F5),
    surfaceCard: Color(0xFFFFFFFF),
    surfacePanel: Color(0xFFF0F0F0),
    surfaceBorderIdle: Color(0x1F000000),
    surfaceBorderHovered: Color(0x3D000000),
    surfaceBorderSelected: Color(0xFF1A1A2E),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0x99000000),
    textMuted: Color(0x61000000),
    accentSeed: Color(0xFF4F46E5),
    accentLink: Color(0xFF4338CA),
  );

  static const immersive = ThemePreset(
    name: 'immersive',
    backgroundType: BackgroundType.image,
    backgroundColor: Color(0xFF0A0A14),
    backgroundImagePath: 'assets/backgrounds/hero-dawn-temple_seed4830.png',
    surfaceCard: Color(0xFF1A1A2E),
    surfacePanel: Color(0xFF12121F),
    surfaceBorderIdle: Color(0x33FFFFFF),
    surfaceBorderHovered: Color(0x66FFFFFF),
    surfaceBorderSelected: Color(0xCCFFFFFF),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xAAF0F0F0),
    textMuted: Color(0x66F0F0F0),
    accentSeed: Color(0xFF7C3AED),
    accentLink: Color(0xFFA78BFA),
    cardOpacity: 0.85,
  );

  static const builtIn = [dark, light, immersive];

  factory ThemePreset.fromToml(String source) {
    final doc = TomlDocument.parse(source).toMap();

    final name = doc['name'] as String? ?? 'unnamed';

    final bg = doc['background'] as Map<String, dynamic>? ?? {};
    final backgroundType = (bg['type'] as String? ?? 'solid') == 'image'
        ? BackgroundType.image
        : BackgroundType.solid;
    final backgroundColor = _parseColor(bg['color']) ?? const Color(0xFF0F0F1A);
    final backgroundImagePath = bg['image_path'] as String?;

    final surface = doc['surface'] as Map<String, dynamic>? ?? {};
    final text = doc['text'] as Map<String, dynamic>? ?? {};
    final accent = doc['accent'] as Map<String, dynamic>? ?? {};
    final cardDefaults = doc['card_defaults'] as Map<String, dynamic>? ?? {};

    return ThemePreset(
      name: name,
      backgroundType: backgroundType,
      backgroundColor: backgroundColor,
      backgroundImagePath: backgroundImagePath,
      surfaceCard: _parseColor(surface['card']) ?? const Color(0xFF1E1E2E),
      surfacePanel: _parseColor(surface['panel']) ?? const Color(0xFF1E1E2E),
      surfaceBorderIdle:
          _parseColor(surface['border_idle']) ?? const Color(0x3DFFFFFF),
      surfaceBorderHovered:
          _parseColor(surface['border_hovered']) ?? const Color(0x8AFFFFFF),
      surfaceBorderSelected:
          _parseColor(surface['border_selected']) ?? const Color(0xFFFFFFFF),
      textPrimary: _parseColor(text['primary']) ?? const Color(0xFFFFFFFF),
      textSecondary: _parseColor(text['secondary']) ?? const Color(0xB3FFFFFF),
      textMuted: _parseColor(text['muted']) ?? const Color(0x78FFFFFF),
      accentSeed: _parseColor(accent['seed']) ?? const Color(0xFF6366F1),
      accentLink: _parseColor(accent['link']) ?? const Color(0xFF818CF8),
      cardOpacity: (cardDefaults['opacity'] as num?)?.toDouble() ?? 1.0,
      statusStripHeight:
          (cardDefaults['status_strip_height'] as num?)?.toDouble() ?? 4.0,
    );
  }

  String toToml() {
    final buf = StringBuffer();
    buf.writeln('name = "${_escapeToml(name)}"');
    buf.writeln();
    buf.writeln('[background]');
    buf.writeln('type = "${backgroundType.name}"');
    buf.writeln('color = "${_formatColor(backgroundColor)}"');
    if (backgroundImagePath != null) {
      buf.writeln('image_path = "${_escapeToml(backgroundImagePath!)}"');
    }
    buf.writeln();
    buf.writeln('[surface]');
    buf.writeln('card = "${_formatColor(surfaceCard)}"');
    buf.writeln('panel = "${_formatColor(surfacePanel)}"');
    buf.writeln('border_idle = "${_formatColor(surfaceBorderIdle)}"');
    buf.writeln('border_hovered = "${_formatColor(surfaceBorderHovered)}"');
    buf.writeln('border_selected = "${_formatColor(surfaceBorderSelected)}"');
    buf.writeln();
    buf.writeln('[text]');
    buf.writeln('primary = "${_formatColor(textPrimary)}"');
    buf.writeln('secondary = "${_formatColor(textSecondary)}"');
    buf.writeln('muted = "${_formatColor(textMuted)}"');
    buf.writeln();
    buf.writeln('[accent]');
    buf.writeln('seed = "${_formatColor(accentSeed)}"');
    buf.writeln('link = "${_formatColor(accentLink)}"');
    buf.writeln();
    buf.writeln('[card_defaults]');
    buf.writeln('opacity = $cardOpacity');
    buf.writeln('status_strip_height = $statusStripHeight');
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemePreset &&
          name == other.name &&
          backgroundType == other.backgroundType &&
          backgroundColor == other.backgroundColor &&
          backgroundImagePath == other.backgroundImagePath &&
          surfaceCard == other.surfaceCard &&
          surfacePanel == other.surfacePanel &&
          surfaceBorderIdle == other.surfaceBorderIdle &&
          surfaceBorderHovered == other.surfaceBorderHovered &&
          surfaceBorderSelected == other.surfaceBorderSelected &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          textMuted == other.textMuted &&
          accentSeed == other.accentSeed &&
          accentLink == other.accentLink &&
          cardOpacity == other.cardOpacity &&
          statusStripHeight == other.statusStripHeight;

  @override
  int get hashCode => Object.hash(
    name,
    backgroundType,
    backgroundColor,
    backgroundImagePath,
    surfaceCard,
    surfacePanel,
    surfaceBorderIdle,
    surfaceBorderHovered,
    surfaceBorderSelected,
    textPrimary,
    textSecondary,
    textMuted,
    accentSeed,
    accentLink,
    cardOpacity,
    statusStripHeight,
  );

  static Color? _parseColor(Object? value) {
    if (value is! String) return null;
    final hex = value.replaceFirst('#', '');
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static String _formatColor(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  static String _escapeToml(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
  }

  static String slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
