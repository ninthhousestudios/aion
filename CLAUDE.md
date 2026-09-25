# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and run

```bash
flutter run -d linux          # run on linux desktop
flutter test --exclude-tags integration   # unit/widget tests (integration tests need a local drishti checkout)
flutter test test/<file>      # run a single test file
flutter analyze               # static analysis
```

## Architecture

Aion is a desktop astrology workspace shell. Core aion has zero astrological knowledge — all domain functionality lives in MCP servers (plugins).

Three-layer model: Canvas (pure geometry) → Card bindings (declarative data references) → Workspace Store (live chart data from plugins via MCP).

Key packages: `mcp_dart` for MCP transport, `drift` for chart-db sqlite, Riverpod for state.

See `docs/architecture-plan-overview.md` and `docs/roadmap.md` for full design. `docs/code-map.md` has the directory index, key types, providers, and data flow.

## Theming

All UI colors must come from `AionTheme` (`lib/theme/aion_theme.dart`) via `Theme.of(context).extension<AionTheme>()!`. Never hardcode colors in widgets. Add new tokens to `AionTheme` if needed.

## Domain docs

`CONTEXT.md` (domain glossary) and `docs/adr/` (architecture decisions) at repo root.
