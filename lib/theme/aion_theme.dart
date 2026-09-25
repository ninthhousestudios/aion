import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme_preset.dart';

class AionTheme extends ThemeExtension<AionTheme> {
  const AionTheme({
    required this.canvasBackground,
    required this.surfaceOverlay,
    required this.surfaceBorder,
    required this.cardBorderSelected,
    required this.cardBorderHovered,
    required this.cardBorderIdle,
    required this.cardShadow,
    required this.cardLabelColor,
    required this.cardDimColor,
    required this.cardOpacity,
    required this.statusStripHeight,
    required this.snapAccent,
    required this.snapGuideColor,
    required this.snapInactiveColor,
    required this.chromeButtonHover,
    required this.chromeCloseHover,
    required this.chromeIconColor,
    required this.statusConnected,
    required this.statusStarting,
    required this.statusError,
    required this.statusStopped,
    this.slotPalette = defaultSlotPalette,
  });

  final Color canvasBackground;
  final Color surfaceOverlay;
  final Color surfaceBorder;

  final Color cardBorderSelected;
  final Color cardBorderHovered;
  final Color cardBorderIdle;
  final Color cardShadow;
  final Color cardLabelColor;
  final Color cardDimColor;

  final double cardOpacity;
  final double statusStripHeight;

  final Color snapAccent;
  final Color snapGuideColor;
  final Color snapInactiveColor;

  final Color chromeButtonHover;
  final Color chromeCloseHover;
  final Color chromeIconColor;

  final Color statusConnected;
  final Color statusStarting;
  final Color statusError;
  final Color statusStopped;

  /// Chart slot colors, indexed by `ChartSlot.colorIndex` (wrapping). The
  /// card status strip shows the color of the card's slot.
  final List<Color> slotPalette;

  static const defaultSlotPalette = [
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
  ];

  /// Palette color for a slot's [colorIndex] (wraps; never throws).
  Color slotColor(int colorIndex) {
    final palette = slotPalette.isEmpty ? defaultSlotPalette : slotPalette;
    return palette[colorIndex % palette.length];
  }

  factory AionTheme.fromPreset(ThemePreset preset) {
    return AionTheme(
      canvasBackground: preset.backgroundColor,
      surfaceOverlay: preset.surfaceCard,
      surfaceBorder: _withAlpha(preset.textPrimary, 0x1F),
      cardBorderSelected: preset.surfaceBorderSelected,
      cardBorderHovered: preset.surfaceBorderHovered,
      cardBorderIdle: preset.surfaceBorderIdle,
      cardShadow: _withAlpha(preset.textPrimary, 0x1E),
      cardLabelColor: preset.textPrimary,
      cardDimColor: preset.textMuted,
      cardOpacity: preset.cardOpacity,
      statusStripHeight: preset.statusStripHeight,
      snapAccent: preset.accentSeed,
      snapGuideColor: _withAlpha(preset.accentSeed, 0x55),
      snapInactiveColor: _withAlpha(preset.textPrimary, 0x61),
      chromeButtonHover: _withAlpha(preset.textPrimary, 0x1F),
      chromeCloseHover: const Color(0xFFF44336),
      chromeIconColor: _withAlpha(preset.textPrimary, 0x8A),
      statusConnected: const Color(0xFF4CAF50),
      statusStarting: const Color(0xFFFFC107),
      statusError: const Color(0xFFF44336),
      statusStopped: const Color(0xFF9E9E9E),
    );
  }

  static Color _withAlpha(Color base, int a) {
    return Color((a << 24) | (base.toARGB32() & 0x00FFFFFF));
  }

  static final dark = AionTheme.fromPreset(ThemePreset.dark);

  @override
  AionTheme copyWith({
    Color? canvasBackground,
    Color? surfaceOverlay,
    Color? surfaceBorder,
    Color? cardBorderSelected,
    Color? cardBorderHovered,
    Color? cardBorderIdle,
    Color? cardShadow,
    Color? cardLabelColor,
    Color? cardDimColor,
    double? cardOpacity,
    double? statusStripHeight,
    Color? snapAccent,
    Color? snapGuideColor,
    Color? snapInactiveColor,
    Color? chromeButtonHover,
    Color? chromeCloseHover,
    Color? chromeIconColor,
    Color? statusConnected,
    Color? statusStarting,
    Color? statusError,
    Color? statusStopped,
    List<Color>? slotPalette,
  }) {
    return AionTheme(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      cardBorderSelected: cardBorderSelected ?? this.cardBorderSelected,
      cardBorderHovered: cardBorderHovered ?? this.cardBorderHovered,
      cardBorderIdle: cardBorderIdle ?? this.cardBorderIdle,
      cardShadow: cardShadow ?? this.cardShadow,
      cardLabelColor: cardLabelColor ?? this.cardLabelColor,
      cardDimColor: cardDimColor ?? this.cardDimColor,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      statusStripHeight: statusStripHeight ?? this.statusStripHeight,
      snapAccent: snapAccent ?? this.snapAccent,
      snapGuideColor: snapGuideColor ?? this.snapGuideColor,
      snapInactiveColor: snapInactiveColor ?? this.snapInactiveColor,
      chromeButtonHover: chromeButtonHover ?? this.chromeButtonHover,
      chromeCloseHover: chromeCloseHover ?? this.chromeCloseHover,
      chromeIconColor: chromeIconColor ?? this.chromeIconColor,
      statusConnected: statusConnected ?? this.statusConnected,
      statusStarting: statusStarting ?? this.statusStarting,
      statusError: statusError ?? this.statusError,
      statusStopped: statusStopped ?? this.statusStopped,
      slotPalette: slotPalette ?? this.slotPalette,
    );
  }

  @override
  AionTheme lerp(AionTheme? other, double t) {
    if (other == null) return this;
    return AionTheme(
      canvasBackground: Color.lerp(
        canvasBackground,
        other.canvasBackground,
        t,
      )!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      cardBorderSelected: Color.lerp(
        cardBorderSelected,
        other.cardBorderSelected,
        t,
      )!,
      cardBorderHovered: Color.lerp(
        cardBorderHovered,
        other.cardBorderHovered,
        t,
      )!,
      cardBorderIdle: Color.lerp(cardBorderIdle, other.cardBorderIdle, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      cardLabelColor: Color.lerp(cardLabelColor, other.cardLabelColor, t)!,
      cardDimColor: Color.lerp(cardDimColor, other.cardDimColor, t)!,
      cardOpacity: lerpDouble(cardOpacity, other.cardOpacity, t)!,
      statusStripHeight: lerpDouble(
        statusStripHeight,
        other.statusStripHeight,
        t,
      )!,
      snapAccent: Color.lerp(snapAccent, other.snapAccent, t)!,
      snapGuideColor: Color.lerp(snapGuideColor, other.snapGuideColor, t)!,
      snapInactiveColor: Color.lerp(
        snapInactiveColor,
        other.snapInactiveColor,
        t,
      )!,
      chromeButtonHover: Color.lerp(
        chromeButtonHover,
        other.chromeButtonHover,
        t,
      )!,
      chromeCloseHover: Color.lerp(
        chromeCloseHover,
        other.chromeCloseHover,
        t,
      )!,
      chromeIconColor: Color.lerp(chromeIconColor, other.chromeIconColor, t)!,
      statusConnected: Color.lerp(statusConnected, other.statusConnected, t)!,
      statusStarting: Color.lerp(statusStarting, other.statusStarting, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
      statusStopped: Color.lerp(statusStopped, other.statusStopped, t)!,
      slotPalette: t < 0.5 ? slotPalette : other.slotPalette,
    );
  }
}
