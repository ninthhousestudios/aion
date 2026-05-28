import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'canvas/canvas_workspace.dart';

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

class AionApp extends StatelessWidget {
  const AionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const CanvasWorkspace(),
    );
  }
}
