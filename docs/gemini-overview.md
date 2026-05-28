# Aion & GUI-Spike: Architectural Overview

This document summarizes the current state, weaknesses, and strategic direction for the Aion project and its associated GUI spike.

## Current State

### Aion (Service Layer)
- **Architecture:** Powered by the Model Context Protocol (MCP).
- **Functionality:** Orchestrates external "tools" (Drishti for calculations, Mundus for locations, Chart DB for storage).
- **Core Pattern:** `PluginHost` manages child processes; `WorkspaceStore` manages computation "slots".

### GUI-Spike (Presentation Layer)
- **Architecture:** Infinite canvas with free-floating, snappable cards.
- **Functionality:** Spatial organization of astrological widgets.
- **Core Pattern:** `InteractiveViewer` with custom `SnapPhysics`.

## Architectural Weaknesses

### 1. Fragmentation
The calculation logic (`aion`) and the spatial UI (`gui-spike`) are currently disconnected. The UI uses dummy data, and the service layer lacks a visual home.

### 2. State Management Scaling
`gui-spike` relies on a massive `setState` in `CanvasWorkspace`. This will become unmanageable and performant-heavy as card complexity increases.

### 3. Static Configuration
Plugin definitions in `aion` are hardcoded in Dart, making it difficult for users to add their own MCP servers without a rebuild.

### 4. Data Binding
There is no formal "contract" between an MCP tool's output and a Card's visual representation.

## Strategic Direction

1. **Merge Projects:** Migrate the `gui-spike` canvas into `aion` as the primary workspace.
2. **Reactive Architecture:** Move canvas state to Riverpod to handle complex card-to-service interactions.
3. **The "Slot" Contract:** Define a clear mapping where a `Card` in the UI acts as a view for a `Slot` in the `WorkspaceStore`.
4. **Declarative Plugins:** Transition to a JSON-based plugin registry.
