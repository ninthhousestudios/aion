import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../actions/bind_chart_action.dart';
import '../actions/load_chart_action.dart';
import '../commands/app_action.dart';
import '../commands/view_actions.dart';
import '../providers/chart_store_provider.dart';
import '../providers/renderer_registry_provider.dart';
import '../renderer/chart_renderer.dart';
import '../slots/card_binding.dart';
import '../slots/chart_slot.dart';
import '../slots/expression_resolution.dart';
import '../slots/slot_state.dart';
import '../theme/display_options.dart';
import '../theme/theme_resolver.dart';
import 'card_model.dart';
import 'workspace_notifier.dart';

/// Default size for a new card showing [meta].
Size defaultCardSize(RendererMeta? meta) => meta?.preferredAspectRatio != null
    ? const Size(500, 500)
    : const Size(500, 400);

/// Where to drop a card when the surface gives no position: a cascade that
/// keeps successive cards visible instead of stacking them exactly.
Offset cascadePosition(int existingCards) {
  final step = (existingCards % 10) * 30.0;
  return Offset(80 + step, 60 + step);
}

String slotConfigActionId(String slotId) => 'slot.config.$slotId';
String slotLoadActionId(String slotId) => 'slot.load.$slotId';
String slotRemoveActionId(String slotId) => 'slot.remove.$slotId';

/// Card menu layout: action ids in order, `null` for a divider. Entries
/// whose action is missing or disabled are skipped.
List<String?> cardMenuIds(
  Iterable<RendererMeta> renderers,
  Iterable<ChartSlot> slots,
) => [
  for (final r in renderers) 'card.open_as.${r.id}',
  null,
  for (final r in renderers) 'card.switch_to.${r.id}',
  null,
  'display.toggle.useSignGlyphs',
  'display.toggle.usePlanetGlyphs',
  'display.toggle.showOuterPlanets',
  null,
  'card.duplicate',
  'card.reset_size',
  'card.delete',
  'card.cycle_slot_color',
  null,
  'card.config',
  'card.clear_config',
  null,
  for (final s in slots) 'slot.bind.${s.id}',
  'card.pin',
  'card.unpin',
];

/// Canvas (background) menu layout.
List<String?> canvasMenuIds(Iterable<RendererMeta> renderers) => [
  'canvas.add_card',
  for (final r in renderers) 'view.open_chart.${r.id}',
];

/// Every canvas-, card-, slot- and display-level action, as registry
/// entries. The context menus, rail and palette all execute these.
List<AppAction> buildCanvasActions(Ref ref) {
  final metas = [
    for (final r in ref.read(rendererRegistryProvider).all) r.meta,
  ];
  final slots = ref.read(slotsProvider).slots;

  WorkspaceNotifier workspace() => ref.read(workspaceProvider.notifier);
  CardModel? cardOf(ActionContext ctx) {
    final id = ctx.cardId;
    return id == null ? null : ref.read(workspaceProvider).cardById(id);
  }

  bool bound(ActionContext ctx) => cardOf(ctx)?.binding != null;

  void addView(RendererMeta meta, ActionContext ctx) {
    final slot = ref.read(slotsProvider).activeSlot;
    workspace().addCard(
      ctx.position ?? cascadePosition(ref.read(workspaceProvider).cards.length),
      defaultCardSize(meta),
      slot.chartName ?? meta.displayName,
      binding: SlotBinding(slot.id),
      rendererType: meta.id,
      preferredAspectRatio: meta.preferredAspectRatio,
    );
  }

  /// Picks a chart file and loads it into [slotId] (the active slot when
  /// null), so every card bound to that slot follows. Returns whether a
  /// chart was loaded.
  Future<bool> loadChartIntoSlot(String? slotId, ActionContext ctx) async {
    final store = ref.read(chartStoreProvider);
    final loadResult = await loadChartFromFile(store);
    if (loadResult is ChartLoadCancelled) return false;
    final slots = ref.read(slotsProvider);
    final slot = slotId == null
        ? slots.activeSlot
        : slots.slotOrDefault(slotId);
    final result = await bindChartToCard(
      store,
      loadResult,
      config: canonicalConfig(slot.config),
    );
    switch (result) {
      case ChartBound(:final chartName, :final expressionRef):
        ref
            .read(slotsProvider.notifier)
            .setChart(slot.id, expressionRef.chartId, chartName: chartName);
        return true;
      case BindFailed(:final message):
        ctx.onError?.call(message);
        return false;
    }
  }

  AppAction displayToggle(
    String field,
    String title,
    bool Function(DisplayOptions) get,
    CardModel Function(CardModel card, bool value) set,
  ) => AppAction(
    id: 'display.toggle.$field',
    title: title,
    category: ActionCategory.display,
    requiresCard: true,
    isEnabled: (ctx) => cardOf(ctx)?.kind == CardKind.chart,
    isChecked: (ctx) {
      final card = cardOf(ctx);
      if (card == null) return false;
      return get(ref.read(themeResolverProvider).resolve(card).displayOptions);
    },
    execute: (ctx) {
      final card = cardOf(ctx);
      if (card == null) return;
      final current = get(
        ref.read(themeResolverProvider).resolve(card).displayOptions,
      );
      workspace().updateCardDisplayOverrides(
        card.id,
        set(card, !current).displayOverrides,
      );
    },
  );

  return [
    // Views: one per renderer, added to the active slot.
    ...viewActionsFromRenderers(metas, onAdd: addView),

    // Canvas.
    AppAction(
      id: 'canvas.add_card',
      title: 'Add Card',
      category: ActionCategory.workspace,
      execute: (ctx) {
        final state = ref.read(workspaceProvider);
        workspace().addCard(
          ctx.position ?? cascadePosition(state.cards.length),
          const Size(240, 160),
          'Card ${state.cardCounter}',
        );
      },
    ),
    for (final meta in metas)
      AppAction(
        id: 'view.open_chart.${meta.id}',
        title: 'Open ${meta.displayName}…',
        category: ActionCategory.slots,
        execute: (ctx) async {
          if (await loadChartIntoSlot(null, ctx)) addView(meta, ctx);
        },
      ),
    AppAction(
      id: 'workspace.toggle_snap',
      title: 'Snap to Edges',
      category: ActionCategory.workspace,
      aliases: const ['snap', 'magnet'],
      isChecked: (_) => ref.read(workspaceProvider).snapEnabled,
      execute: (_) => workspace().toggleSnap(),
    ),

    AppAction(
      id: 'settings.open',
      title: 'Settings',
      category: ActionCategory.settings,
      aliases: const ['preferences', 'theme', 'options'],
      icon: Icons.settings_outlined,
      execute: (ctx) => workspace().openSettingsCard(
        settingsCardRect(ctx.viewportSize ?? const Size(1280, 800)),
      ),
    ),

    // Slots.
    AppAction(
      id: 'slot.load_chart',
      title: 'Load Chart into Active Slot…',
      category: ActionCategory.slots,
      aliases: const ['open', 'load', 'chart', 'client'],
      icon: Icons.folder_open,
      execute: (ctx) => loadChartIntoSlot(null, ctx),
    ),
    AppAction(
      id: 'slot.add',
      title: 'Add Slot',
      category: ActionCategory.slots,
      execute: (_) => ref.read(slotsProvider.notifier).addSlot(),
    ),
    for (final slot in slots) ...[
      AppAction(
        id: slotLoadActionId(slot.id),
        title: 'Load Chart into ${slotMenuLabel(slot)}…',
        category: ActionCategory.slots,
        icon: Icons.folder_open,
        execute: (ctx) => loadChartIntoSlot(slot.id, ctx),
      ),
      if (slot.id != SlotState.kDefaultSlotId)
        AppAction(
          id: slotRemoveActionId(slot.id),
          title: 'Remove ${slotMenuLabel(slot)}',
          category: ActionCategory.slots,
          execute: (_) => ref.read(slotsProvider.notifier).removeSlot(slot.id),
        ),
    ],
    for (final slot in slots)
      AppAction(
        id: 'slot.activate.${slot.id}',
        title: 'Activate ${slotMenuLabel(slot)}',
        category: ActionCategory.slots,
        isChecked: (_) => ref.read(slotsProvider).activeSlotId == slot.id,
        execute: (_) => ref.read(slotsProvider.notifier).setActive(slot.id),
      ),

    // Card: open as / switch renderer.
    for (final meta in metas) ...[
      AppAction(
        id: 'card.open_as.${meta.id}',
        title: 'Open as ${meta.displayName}',
        category: ActionCategory.card,
        requiresCard: true,
        isEnabled: bound,
        execute: (ctx) {
          final source = cardOf(ctx);
          if (source == null) return;
          workspace().addCard(
            source.position + const Offset(30, 30),
            defaultCardSize(meta),
            source.label,
            binding: source.binding,
            configOverride: source.configOverride,
            rendererType: meta.id,
            preferredAspectRatio: meta.preferredAspectRatio,
          );
        },
      ),
      AppAction(
        id: 'card.switch_to.${meta.id}',
        title: meta.displayName,
        category: ActionCategory.card,
        requiresCard: true,
        isEnabled: bound,
        isChecked: (ctx) => cardOf(ctx)?.rendererType == meta.id,
        execute: (ctx) {
          final card = cardOf(ctx);
          if (card == null || card.rendererType == meta.id) return;
          workspace().setCardRenderer(
            card.id,
            meta.id,
            preferredAspectRatio: meta.preferredAspectRatio,
          );
        },
      ),
    ],

    // Display toggles (per-card overrides).
    displayToggle(
      'useSignGlyphs',
      'Sign Glyphs',
      (d) => d.useSignGlyphs,
      (c, v) => c.copyWith(
        displayOverrides: c.displayOverrides.copyWith(useSignGlyphs: v),
      ),
    ),
    displayToggle(
      'usePlanetGlyphs',
      'Planet Glyphs',
      (d) => d.usePlanetGlyphs,
      (c, v) => c.copyWith(
        displayOverrides: c.displayOverrides.copyWith(usePlanetGlyphs: v),
      ),
    ),
    displayToggle(
      'showOuterPlanets',
      'Outer Planets',
      (d) => d.showOuterPlanets,
      (c, v) => c.copyWith(
        displayOverrides: c.displayOverrides.copyWith(showOuterPlanets: v),
      ),
    ),

    // Card lifecycle.
    AppAction(
      id: 'card.duplicate',
      title: 'Duplicate',
      category: ActionCategory.card,
      requiresCard: true,
      isEnabled: (ctx) => cardOf(ctx)?.kind != CardKind.settings,
      execute: (ctx) {
        if (ctx.cardId case final id?) workspace().duplicateCard(id);
      },
    ),
    AppAction(
      id: 'card.reset_size',
      title: 'Reset Size',
      category: ActionCategory.card,
      requiresCard: true,
      execute: (ctx) {
        final card = cardOf(ctx);
        if (card == null) return;
        final type = card.rendererType;
        final meta = type == null
            ? null
            : ref.read(rendererRegistryProvider).get(type)?.meta;
        workspace().resetCardSize(card.id, defaultCardSize(meta));
      },
    ),
    AppAction(
      id: 'card.delete',
      title: 'Delete',
      category: ActionCategory.card,
      requiresCard: true,
      execute: (ctx) {
        if (ctx.cardId case final id?) workspace().deleteCard(id);
      },
    ),
    AppAction(
      id: 'card.cycle_slot_color',
      title: 'Cycle Slot Color',
      category: ActionCategory.card,
      requiresCard: true,
      isEnabled: (ctx) => cardOf(ctx)?.binding is SlotBinding,
      execute: (ctx) {
        if (cardOf(ctx)?.binding case SlotBinding(:final slotId)) {
          final slot = ref.read(slotsProvider).slotOrDefault(slotId);
          ref
              .read(slotsProvider.notifier)
              .setColorIndex(slot.id, slot.colorIndex + 1);
        }
      },
    ),

    // Expression config: per-card override (the opt-in exception).
    AppAction(
      id: 'card.config',
      title: 'Expression Config…',
      category: ActionCategory.card,
      requiresCard: true,
      icon: Icons.tune,
      isEnabled: (ctx) => bound(ctx) && ctx.editConfig != null,
      execute: (ctx) {
        final card = cardOf(ctx);
        if (card == null) return;
        final base = switch (card.binding) {
          SlotBinding(:final slotId) =>
            ref.read(slotsProvider).slotOrDefault(slotId).config,
          PinnedBinding(:final config) => config,
          null => const <String, Object>{},
        };
        ctx.editConfig?.call(
          ConfigEditRequest(
            title: 'Card config override — ${card.label}',
            initial: card.configOverride ?? base,
            onChanged: (config) =>
                workspace().setCardConfigOverride(card.id, config),
          ),
        );
      },
    ),
    AppAction(
      id: 'card.clear_config',
      title: 'Clear Config Override',
      category: ActionCategory.card,
      requiresCard: true,
      isEnabled: (ctx) => cardOf(ctx)?.configOverride != null,
      execute: (ctx) {
        if (ctx.cardId case final id?) {
          workspace().setCardConfigOverride(id, null);
        }
      },
    ),
    for (final slot in slots)
      AppAction(
        id: slotConfigActionId(slot.id),
        title: 'Configure ${slotMenuLabel(slot)}…',
        category: ActionCategory.slots,
        icon: Icons.tune,
        isEnabled: (ctx) => ctx.editConfig != null,
        execute: (ctx) => ctx.editConfig?.call(
          ConfigEditRequest(
            title: 'Slot ${slot.id} config',
            initial: ref.read(slotsProvider).slotOrDefault(slot.id).config,
            onChanged: (config) =>
                ref.read(slotsProvider.notifier).setConfig(slot.id, config),
          ),
        ),
      ),

    // Card slot binding.
    for (final slot in slots)
      AppAction(
        id: 'slot.bind.${slot.id}',
        title: 'Bind to ${slotMenuLabel(slot)}',
        category: ActionCategory.card,
        requiresCard: true,
        isEnabled: bound,
        isChecked: (ctx) => cardOf(ctx)?.binding == SlotBinding(slot.id),
        execute: (ctx) {
          if (ctx.cardId case final id?) {
            workspace().setCardBinding(id, SlotBinding(slot.id));
          }
        },
      ),
    AppAction(
      id: 'card.pin',
      title: 'Pin',
      category: ActionCategory.card,
      requiresCard: true,
      icon: Icons.push_pin_outlined,
      isEnabled: (ctx) {
        final card = cardOf(ctx);
        return card != null &&
            pinnedBindingFor(
                  card.binding,
                  ref.read(slotsProvider),
                  configOverride: card.configOverride,
                ) !=
                null;
      },
      execute: (ctx) {
        final card = cardOf(ctx);
        if (card == null) return;
        final pinned = pinnedBindingFor(
          card.binding,
          ref.read(slotsProvider),
          configOverride: card.configOverride,
        );
        if (pinned != null) workspace().pinCard(card.id, pinned);
      },
    ),
    AppAction(
      id: 'card.unpin',
      title: 'Unpin',
      category: ActionCategory.card,
      requiresCard: true,
      isEnabled: (ctx) => cardOf(ctx)?.binding is PinnedBinding,
      execute: (ctx) {
        if (ctx.cardId case final id?) {
          workspace().setCardBinding(
            id,
            SlotBinding(ref.read(slotsProvider).activeSlotId),
          );
        }
      },
    ),
  ];
}
