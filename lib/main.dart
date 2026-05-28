import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas/canvas_workspace.dart';

void main() {
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
