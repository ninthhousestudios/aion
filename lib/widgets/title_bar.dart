import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/aion_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
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
              defaultHoverColor: t.chromeButtonHover,
              iconColor: t.chromeIconColor,
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
              defaultHoverColor: t.chromeButtonHover,
              iconColor: t.chromeIconColor,
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: windowManager.close,
              hoverColor: t.chromeCloseHover,
              defaultHoverColor: t.chromeButtonHover,
              iconColor: t.chromeIconColor,
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
    required this.defaultHoverColor,
    required this.iconColor,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color defaultHoverColor;
  final Color iconColor;
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
              ? (widget.hoverColor ?? widget.defaultHoverColor)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.iconColor,
          ),
        ),
      ),
    );
  }
}
