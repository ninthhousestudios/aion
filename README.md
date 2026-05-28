[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

# aion

Desktop astrology workspace built with Flutter. Core aion has zero astrological knowledge — all domain functionality lives in MCP servers (plugins).

## architecture

Three-layer model:

- **Canvas** — infinite workspace with draggable, resizable cards, snap physics, z-ordering
- **Card bindings** — cards hold `ExpressionRef` references to computed data, no domain knowledge
- **ChartStore / WorkspaceStore** — manages chart lifecycle and live expression data from plugins via MCP

Key packages: `mcp_dart` for MCP transport, `rxdart` for reactive streams, Riverpod for UI state, `chart_db_core` for chart database.

## bundled plugins

| Plugin | Role |
|--------|------|
| drishti | Astrological calculations via arjuna/arrow |
| chart-db | Chart storage, indexing, vector similarity search |
| mundus | Geographic lookup + historic timezone resolution |

## build and run

```bash
flutter run -d linux
flutter test
flutter analyze
```

## project structure

```
lib/
  canvas/       — workspace, cards, snap physics
  mcp/          — plugin host, chart store, expression state
  theme/        — AionTheme color tokens
  widgets/      — title bar, plugin status
packages/
  chart_db/     — chart-db MCP server
  chart_db_core/ — chart database engine (sqlite, vectors)
docs/           — architecture docs, roadmap
```
