import 'package:flutter/material.dart';

import '../theme/aion_theme.dart';

/// Minimal single-line text prompt. Completes with the entered text, or
/// null if cancelled.
Future<String?> showTextPrompt(
  BuildContext context,
  String title, {
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final t = Theme.of(context).extension<AionTheme>()!;
      final text = TextStyle(color: t.cardLabelColor);
      return AlertDialog(
        backgroundColor: t.surfaceOverlay,
        title: Text(title, style: text),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: text,
          cursorColor: t.snapAccent,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: t.cardDimColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text('OK', style: text),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
