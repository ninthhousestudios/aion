import 'package:flutter/material.dart';

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

  static const dark = AionTheme(
    canvasBackground: Color(0xFF0F0F1A),
    surfaceOverlay: Color(0xFF1E1E2E),
    surfaceBorder: Colors.white12,
    cardBorderSelected: Colors.white,
    cardBorderHovered: Colors.white54,
    cardBorderIdle: Colors.white24,
    cardShadow: Color(0x1EFFFFFF),
    cardLabelColor: Colors.white,
    cardDimColor: Color(0x78FFFFFF),
    snapAccent: Color(0xFF6366F1),
    snapGuideColor: Color(0x556366F1),
    snapInactiveColor: Colors.white38,
    chromeButtonHover: Colors.white12,
    chromeCloseHover: Colors.red,
    chromeIconColor: Colors.white54,
    statusConnected: Colors.green,
    statusStarting: Colors.amber,
    statusError: Colors.red,
    statusStopped: Colors.grey,
  );

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
    );
  }

  @override
  AionTheme lerp(AionTheme? other, double t) {
    if (other == null) return this;
    return AionTheme(
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      cardBorderSelected: Color.lerp(cardBorderSelected, other.cardBorderSelected, t)!,
      cardBorderHovered: Color.lerp(cardBorderHovered, other.cardBorderHovered, t)!,
      cardBorderIdle: Color.lerp(cardBorderIdle, other.cardBorderIdle, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      cardLabelColor: Color.lerp(cardLabelColor, other.cardLabelColor, t)!,
      cardDimColor: Color.lerp(cardDimColor, other.cardDimColor, t)!,
      snapAccent: Color.lerp(snapAccent, other.snapAccent, t)!,
      snapGuideColor: Color.lerp(snapGuideColor, other.snapGuideColor, t)!,
      snapInactiveColor: Color.lerp(snapInactiveColor, other.snapInactiveColor, t)!,
      chromeButtonHover: Color.lerp(chromeButtonHover, other.chromeButtonHover, t)!,
      chromeCloseHover: Color.lerp(chromeCloseHover, other.chromeCloseHover, t)!,
      chromeIconColor: Color.lerp(chromeIconColor, other.chromeIconColor, t)!,
      statusConnected: Color.lerp(statusConnected, other.statusConnected, t)!,
      statusStarting: Color.lerp(statusStarting, other.statusStarting, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
      statusStopped: Color.lerp(statusStopped, other.statusStopped, t)!,
    );
  }
}
