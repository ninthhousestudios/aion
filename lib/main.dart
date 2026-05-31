import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'canvas/canvas_workspace.dart';
import 'mcp/plugin_manifest.dart';
import 'providers/plugin_host_provider.dart';
import 'theme/aion_theme.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        extensions: const [AionTheme.dark],
      ),
      home: const Scaffold(body: CanvasWorkspace()),
    );
  }
}
