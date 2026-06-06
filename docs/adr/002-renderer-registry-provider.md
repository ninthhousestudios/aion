# ADR-002: RendererRegistry as Riverpod provider

## Status

Accepted (2026-06-06)

## Context

`RendererRegistry` was a mutable top-level `final` initialized at import time in `canvas_card.dart`. Not injectable, not overridable in tests, not scopable per workspace. The `forSystem()` filtering method had no test surface because the only entry point was the global.

## Decision

Move the registry to a `Provider<RendererRegistry>` created at app startup. Renderer registration happens in the provider factory. `CanvasCard` becomes a `ConsumerStatefulWidget` and reads the registry via `ref.watch(rendererRegistryProvider)`.

A simple `Provider` (not `Provider.family` per workspace) — all renderers are built-in capabilities available everywhere. Workspace-level *preference* for a default renderer is a workspace-model concern, not a registry-scoping concern.

## Consequences

- Tests can override the registry via `ProviderScope.overrides`.
- New renderers are added by registering them in the provider factory — one location.
- `CanvasCard` gained a Riverpod dependency (was previously a plain `StatefulWidget`). This is consistent with the rest of the widget tree which is already wrapped in `ProviderScope`.
