# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and run

```bash
flutter run -d linux          # run on linux desktop
flutter test                  # run all tests
flutter test test/<file>      # run a single test file
flutter analyze               # static analysis
```

## Architecture

Aion is a desktop astrology workspace shell. Core aion has zero astrological knowledge — all domain functionality lives in MCP servers (plugins).

Three-layer model: Canvas (pure geometry) → Card bindings (declarative data references) → Workspace Store (live chart data from plugins via MCP).

Key packages: `mcp_dart` for MCP transport, `drift` for chart-db sqlite, Riverpod for state.

See `docs/architecture-plan-overview.md` and `docs/roadmap.md` for full design.

## Theming

All UI colors must come from `AionTheme` (`lib/theme/aion_theme.dart`) via `Theme.of(context).extension<AionTheme>()!`. Never hardcode colors in widgets. Add new tokens to `AionTheme` if needed.

## Agent skills

### Issue tracker

Yojana (local MCP task graph). Project slug: `aion`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary — statuses match yojana's status enum directly. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout. `CONTEXT.md` + `docs/adr/` at repo root (created lazily by `/vidhi-domain`). See `docs/agents/domain.md`.
