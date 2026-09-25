import 'package:flutter/material.dart';

import '../theme/aion_theme.dart';
import 'config_dimension.dart';
import 'config_values.dart';

/// Progressive-disclosure editor for an expression config. Embeddable:
/// use it inside any panel, or via [showConfigDialog].
///
/// Sections are collapsed by default and summarize "name: value" per
/// dimension; expanding shows the full controls.
class ConfigEditor extends StatefulWidget {
  const ConfigEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final Map<String, Object> config;
  final ValueChanged<Map<String, Object>> onChanged;

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  final _expanded = <String>{};
  late Map<String, Object> _config = widget.config;

  @override
  void didUpdateWidget(ConfigEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.config, widget.config)) _config = widget.config;
  }

  void _set(ConfigDimension d, Object value) {
    setState(() => _config = setConfigValue(_config, d, value));
    widget.onChanged(_config);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final (group, dims) in configSections()) _section(t, group, dims),
      ],
    );
  }

  Widget _section(AionTheme t, ConfigGroup group, List<ConfigDimension> dims) {
    final open = _expanded.contains(group.key);
    final label = TextStyle(color: t.cardLabelColor, fontSize: 13);
    final dim = TextStyle(color: t.cardDimColor, fontSize: 11);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: t.surfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(
              () =>
                  open ? _expanded.remove(group.key) : _expanded.add(group.key),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: t.cardDimColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(group.label, style: label)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.surfaceBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(stageLabel(sectionStage(dims)), style: dim),
                  ),
                ],
              ),
            ),
          ),
          if (!open)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
              child: Text(
                [
                  for (final d in dims)
                    '${d.name}: ${formatConfigValue(d, configValue(_config, d))}',
                ].join('  ·  '),
                style: dim,
              ),
            )
          else
            for (final d in dims) _control(t, d),
        ],
      ),
    );
  }

  Widget _control(AionTheme t, ConfigDimension d) {
    final value = configValue(_config, d);
    final label = TextStyle(color: t.cardLabelColor, fontSize: 12);
    final choices = d.choices ?? const <ConfigChoice>[];
    final Widget control = switch (d.type) {
      ConfigDimensionType.boolean => Switch(
        value: value == true,
        onChanged: (v) => _set(d, v),
      ),
      ConfigDimensionType.enumPick => DropdownButton<String>(
        value: choices.any((c) => c.value == value) ? '$value' : null,
        dropdownColor: t.surfaceOverlay,
        style: label,
        isDense: true,
        items: [
          for (final c in choices)
            DropdownMenuItem(value: c.value, child: Text(c.label)),
        ],
        onChanged: (v) {
          if (v != null) _set(d, v);
        },
      ),
      ConfigDimensionType.multiSelect => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final c in choices)
            FilterChip(
              label: Text(c.label, style: label),
              selected: value is Set<String> && value.contains(c.value),
              onSelected: (on) {
                final current = value is Set<String> ? value : <String>{};
                _set(
                  d,
                  on ? {...current, c.value} : ({...current}..remove(c.value)),
                );
              },
            ),
        ],
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 2, 8, 6),
      child: d.type == ConfigDimensionType.multiSelect
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: label),
                const SizedBox(height: 4),
                control,
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(d.name, style: label)),
                control,
              ],
            ),
    );
  }
}

/// Shows [ConfigEditor] as a floating panel. With [anchor] (global
/// position, e.g. the source card) the panel opens next to it, clamped to
/// the window; otherwise centered. Every change is reported via
/// [onChanged] immediately.
Future<void> showConfigDialog(
  BuildContext context, {
  required String title,
  required Map<String, Object> initial,
  required ValueChanged<Map<String, Object>> onChanged,
  Offset? anchor,
}) {
  const panelWidth = 440.0;
  final barrier = Theme.of(
    context,
  ).extension<AionTheme>()!.surfaceOverlay.withValues(alpha: 0);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: barrier,
    pageBuilder: (context, _, _) {
      final t = Theme.of(context).extension<AionTheme>()!;
      final screen = MediaQuery.sizeOf(context);
      final maxHeight = screen.height * 0.75;
      final panel = Material(
        color: t.surfaceOverlay,
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: panelWidth,
            maxHeight: maxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: t.cardLabelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: t.cardDimColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Flexible(
                  child: ConfigEditor(config: initial, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      );
      if (anchor == null) return Center(child: panel);
      final left = anchor.dx.clamp(8.0, screen.width - panelWidth - 8);
      final top = anchor.dy.clamp(8.0, screen.height - maxHeight - 8);
      return Stack(
        children: [Positioned(left: left, top: top, child: panel)],
      );
    },
  );
}
