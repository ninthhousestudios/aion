import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (Platform.isMacOS) const SizedBox(width: 72),
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          if (!Platform.isMacOS) ...[
            _WindowButton(
              icon: Icons.minimize,
              onPressed: windowManager.minimize,
            ),
            _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: windowManager.close,
              hoverColor: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: TitleBar.height,
          color: _hovered
              ? (widget.hoverColor ?? Colors.white12)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
