import 'package:flutter/material.dart';

import '../commands/action_registry.dart';
import '../commands/app_action.dart';
import '../theme/aion_theme.dart';
import 'rail.dart';

/// View catalog groups: each view category with its add-view actions.
/// Registry-driven — a new renderer shows up with no catalog change.
List<(String, List<AppAction>)> catalogGroups(ActionRegistry registry) => [
  for (final category in ActionCategory.views)
    if (registry.inCategory(category) case final actions
        when actions.isNotEmpty)
      (category, actions..sort((a, b) => a.title.compareTo(b.title))),
];

/// Browsable grid of views grouped by category. Clicking a tile runs its
/// action (adds the view to the active slot).
class CatalogFlyout extends StatelessWidget {
  const CatalogFlyout({
    super.key,
    required this.registry,
    required this.onSelect,
  });

  final ActionRegistry registry;
  final ValueChanged<AppAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final groups = catalogGroups(registry);
    return FlyoutPanel(
      title: 'Add view',
      child: groups.isEmpty
          ? Text('No views available', style: TextStyle(color: t.cardDimColor))
          : ListView(
              children: [
                for (final (category, actions) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: t.cardDimColor,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actions)
                        _CatalogTile(
                          action: action,
                          onTap: () => onSelect(action),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.action, required this.onTap});

  final AppAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 104,
        height: 84,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: t.surfaceBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon ?? Icons.grid_view, color: t.chromeIconColor),
            const SizedBox(height: 6),
            Text(
              action.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.cardLabelColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
