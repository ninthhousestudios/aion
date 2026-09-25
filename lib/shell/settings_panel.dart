import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/workspace_notifier.dart';
import '../theme/aion_theme.dart';
import '../theme/display_options.dart';
import '../theme/display_options_store.dart';
import '../theme/preset_store.dart';

/// Interior of the settings card: Theme, Display, General tabs wired to the
/// existing theme and display-options stores.
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final label = TextStyle(color: t.cardLabelColor, fontSize: 13);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: t.cardLabelColor,
            unselectedLabelColor: t.cardDimColor,
            indicatorColor: t.snapAccent,
            dividerColor: t.surfaceBorder,
            tabs: const [
              Tab(text: 'Theme'),
              Tab(text: 'Display'),
              Tab(text: 'General'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ThemeTab(label: label),
                _DisplayTab(label: label),
                _GeneralTab(label: label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTab extends ConsumerWidget {
  const _ThemeTab({required this.label});

  final TextStyle label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final store = ref.watch(presetStoreProvider).valueOrNull;
    if (store == null) {
      return Center(child: CircularProgressIndicator(color: t.cardDimColor));
    }
    return ListView(
      children: [
        for (final preset in store.presets)
          ListTile(
            dense: true,
            leading: Icon(
              preset.name == store.activePresetName
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: t.chromeIconColor,
            ),
            title: Text(preset.name, style: label),
            trailing: Container(
              width: 28,
              height: 16,
              decoration: BoxDecoration(
                color: preset.backgroundColor,
                border: Border.all(color: t.surfaceBorder),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            onTap: () =>
                ref.read(presetStoreProvider.notifier).setActive(preset.name),
          ),
      ],
    );
  }
}

class _DisplayTab extends ConsumerWidget {
  const _DisplayTab({required this.label});

  final TextStyle label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(displayOptionsProvider).valueOrNull?.options ??
        DisplayOptions.defaultOptions;
    void set(DisplayOptions next) =>
        ref.read(displayOptionsProvider.notifier).setOptions(next);
    return ListView(
      children: [
        SwitchListTile(
          dense: true,
          title: Text('Sign glyphs', style: label),
          value: options.useSignGlyphs,
          onChanged: (v) => set(options.copyWith(useSignGlyphs: v)),
        ),
        SwitchListTile(
          dense: true,
          title: Text('Planet glyphs', style: label),
          value: options.usePlanetGlyphs,
          onChanged: (v) => set(options.copyWith(usePlanetGlyphs: v)),
        ),
        SwitchListTile(
          dense: true,
          title: Text('Outer planets', style: label),
          value: options.showOuterPlanets,
          onChanged: (v) => set(options.copyWith(showOuterPlanets: v)),
        ),
      ],
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.label});

  final TextStyle label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);
    return ListView(
      children: [
        SwitchListTile(
          dense: true,
          title: Text('Edit layout (unlock cards)', style: label),
          value: workspace.editMode,
          onChanged: notifier.setEditMode,
        ),
        SwitchListTile(
          dense: true,
          title: Text('Snap cards to edges', style: label),
          value: workspace.snapEnabled,
          onChanged: (_) => notifier.toggleSnap(),
        ),
      ],
    );
  }
}
