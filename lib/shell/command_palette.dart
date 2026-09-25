import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commands/action_registry.dart';
import '../commands/app_action.dart';
import '../theme/aion_theme.dart';
import 'palette_entries.dart';

/// Opens the command palette overlay. Selecting an action closes the
/// palette and runs it with [ctx].
Future<void> showCommandPalette(
  BuildContext context, {
  required ActionRegistry registry,
  required ActionContext ctx,
}) async {
  final barrier = Theme.of(
    context,
  ).extension<AionTheme>()!.canvasBackground.withValues(alpha: 0.4);
  final chosen = await showGeneralDialog<AppAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command palette',
    barrierColor: barrier,
    pageBuilder: (context, _, _) =>
        _CommandPalette(registry: registry, ctx: ctx),
  );
  if (chosen != null) await registry.execute(chosen.id, ctx);
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.registry, required this.ctx});

  final ActionRegistry registry;
  final ActionContext ctx;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String? _category;
  int _selected = 0;

  List<PaletteEntry> get _entries => paletteEntries(
    widget.registry,
    widget.ctx,
    query: _controller.text,
    category: _category,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _activate(PaletteEntry entry) {
    switch (entry) {
      case PaletteCategoryEntry(:final category):
        setState(() {
          _category = category;
          _selected = 0;
        });
      case PaletteActionEntry(:final action):
        Navigator.of(context).pop(action);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final entries = _entries;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _selected = moveSelection(_selected, 1, entries.length));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(
          () => _selected = moveSelection(_selected, -1, entries.length),
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_selected < entries.length) _activate(entries[_selected]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace
          when _controller.text.isEmpty && _category != null:
        setState(() => _category = null);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AionTheme>()!;
    final entries = _entries;
    final text = TextStyle(color: t.cardLabelColor, fontSize: 13);
    final dim = TextStyle(color: t.cardDimColor, fontSize: 11);

    return Align(
      alignment: const Alignment(0, -0.6),
      child: Material(
        color: t.surfaceOverlay,
        elevation: 12,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: text,
                  cursorColor: t.snapAccent,
                  decoration: InputDecoration(
                    hintText: 'Type a view, command, or alias (d9, vim)…',
                    hintStyle: dim,
                    prefixIcon: Icon(Icons.search, color: t.cardDimColor),
                    prefix: _category == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              label: Text(_category ?? '', style: dim),
                              onDeleted: () => setState(() => _category = null),
                            ),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() => _selected = 0),
                ),
              ),
              Divider(height: 1, color: t.surfaceBorder),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No matches', style: dim),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          final selected = i == _selected;
                          return InkWell(
                            onTap: () => _activate(entry),
                            onHover: (on) {
                              if (on) setState(() => _selected = i);
                            },
                            child: Container(
                              color: selected ? t.chromeButtonHover : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: switch (entry) {
                                PaletteCategoryEntry(
                                  :final category,
                                  :final count,
                                ) =>
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.folder_outlined,
                                        size: 16,
                                        color: t.cardDimColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(category, style: text),
                                      ),
                                      Text('$count', style: dim),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 16,
                                        color: t.cardDimColor,
                                      ),
                                    ],
                                  ),
                                PaletteActionEntry(:final action) => Row(
                                  children: [
                                    Icon(
                                      action.icon ?? Icons.bolt_outlined,
                                      size: 16,
                                      color: t.cardDimColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(action.title, style: text),
                                    ),
                                    if (action.isChecked?.call(widget.ctx) ??
                                        false)
                                      Icon(
                                        Icons.check,
                                        size: 14,
                                        color: t.snapAccent,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(action.category, style: dim),
                                  ],
                                ),
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
