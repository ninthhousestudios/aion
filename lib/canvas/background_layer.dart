import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/preset_store.dart';
import '../theme/theme_preset.dart';

class BackgroundLayer extends ConsumerWidget {
  const BackgroundLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset =
        ref.watch(presetStoreProvider).valueOrNull?.activePreset ??
        ThemePreset.dark;

    if (preset.backgroundType == BackgroundType.image &&
        preset.backgroundImagePath != null) {
      return _ImageBackground(
        imagePath: preset.backgroundImagePath!,
        fallbackColor: preset.backgroundColor,
      );
    }

    return ColoredBox(color: preset.backgroundColor);
  }
}

class _ImageBackground extends StatelessWidget {
  const _ImageBackground({
    required this.imagePath,
    required this.fallbackColor,
  });

  final String imagePath;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => ColoredBox(color: fallbackColor),
    );
  }
}
