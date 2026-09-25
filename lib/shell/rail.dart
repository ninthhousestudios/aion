import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slots/slot_state.dart';
import '../theme/aion_theme.dart';
import 'rail_state.dart';

/// Slim persistent left edge strip: the mouse-first entry to everything.
///
/// Section buttons open flyouts; [onPalette] opens the command palette;
/// buttons whose feature isn't wired pass a null callback and render
/// disabled.
class Rail extends ConsumerWidget {
  const Rail({super.key, this.onPalette, this.onSettings});

  static const double width = 44;

  final VoidCallback? onPalette;

  /// Settings opens a card rather than a flyout.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final open = ref.watch(railProvider);
    final rail = ref.read(railProvider.notifier);
    final activeSlot = ref.watch(slotsProvider.select((s) => s.activeSlot));

    Widget button(
      IconData icon,
      String tooltip, {
      RailSection? section,
      VoidCallback? onTap,
      Widget? badge,
    }) {
      final selected = section != null && open == section;
      final enabled = onTap != null || section != null;
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: !enabled
              ? null
              : onTap ?? () => rail.toggle(section ?? RailSection.catalog),
          child: Container(
            width: width,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? t.chromeButtonHover : null,
              border: Border(
                left: BorderSide(
                  color: selected ? t.snapAccent : t.canvasBackground,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled ? t.chromeIconColor : t.snapInactiveColor,
                ),
                if (badge != null)
                  Positioned(right: 8, bottom: 8, child: badge),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.surfaceOverlay,
        border: Border(right: BorderSide(color: t.surfaceBorder)),
      ),
      child: Column(
        children: [
          button(Icons.search, 'Command palette (Ctrl+K)', onTap: onPalette),
          button(
            Icons.dashboard_customize_outlined,
            'View catalog',
            section: RailSection.catalog,
          ),
          button(
            Icons.link,
            'Chart slots',
            section: RailSection.slots,
            badge: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: t.slotColor(activeSlot.colorIndex),
                shape: BoxShape.circle,
              ),
            ),
          ),
          button(
            Icons.view_quilt_outlined,
            'Workspaces',
            section: RailSection.workspaces,
          ),
          // Time cursor is out of scope for this run (aion/78, aion/79).
          button(Icons.schedule, 'Time (coming later)'),
          const Spacer(),
          button(Icons.settings_outlined, 'Settings', onTap: onSettings),
        ],
      ),
    );
  }
}

/// Frame for a rail flyout: a titled panel next to the rail.
class FlyoutPanel extends StatelessWidget {
  const FlyoutPanel({
    super.key,
    required this.title,
    required this.child,
    this.width = 360,
  });

  final String title;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    return Material(
      color: t.surfaceOverlay,
      elevation: 8,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: t.surfaceBorder)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: t.cardLabelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
