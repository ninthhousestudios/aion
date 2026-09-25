import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'canvas/canvas_workspace.dart';
import 'mcp/plugin_manifest.dart';
import 'providers/plugin_host_provider.dart';
import 'theme/aion_theme.dart';
import 'theme/preset_store.dart';
import 'theme/theme_preset.dart';
import 'workspaces/workspace_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(640, 480),
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      if (Platform.isMacOS) {
        await windowManager.setMovable(true);
      }
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const ProviderScope(child: AionApp()));
}

class AionApp extends ConsumerStatefulWidget {
  const AionApp({super.key});

  @override
  ConsumerState<AionApp> createState() => _AionAppState();
}

class _AionAppState extends ConsumerState<AionApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(pluginHostProvider).startAll(BundledManifests.all);
      ref.read(workspaceLibraryProvider.notifier).openInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final preset =
        ref.watch(presetStoreProvider).valueOrNull?.activePreset ??
        ThemePreset.dark;
    final aionTheme = AionTheme.fromPreset(preset);
    final brightness = preset.backgroundColor.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;

    return MaterialApp(
      title: 'Aion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: preset.accentSeed,
          brightness: brightness,
        ),
        extensions: [aionTheme],
      ),
      home: const Scaffold(body: CanvasWorkspace()),
    );
  }
}
