# Aion

Desktop astrology workspace shell. A universal canvas for multiple astrological systems — Vedic, Uranian, Hellenistic, Human Design, Cards of Truth. Core aion has zero astrological knowledge; all domain functionality lives in plugins (MCP servers).

## Language

**Chart**:
A moment in spacetime — defined by a Julian Day and geographic coordinates `(jd, lat, lon)`. May represent a birth, a transit, an event, or any other astronomically significant instant. The persistent, shareable unit of data. Stored as TOML, indexed in chart-db.
_Avoid_: horoscope (ambiguous), natal chart (too specific — Chart covers all moment types)

**Expression**:
A Chart processed through a specific configuration — ayanamsa, house system, calculation options. `(Chart, config) → Expression`. One Chart has infinitely many possible Expressions. Sidereal-Lahiri is one Expression; Tropical-Placidus is another; Uranian is another. Expressions are derived, ephemeral, and cached — not persisted as primary data.
_Avoid_: calculation (verb-like), view (Flutter collision), reading (collides with interpretive act)

**System**:
A top-level astrological framework — Vedic, Western, Uranian, Hellenistic, Human Design, Cards of Truth. Determines which Configs are available, which Renderers apply, and which context menu items appear. A System contains traditions, schools, and methodological variations within it (e.g., Lahiri vs Raman ayanamsa are variations within the Vedic System, not separate Systems).
_Avoid_: tradition (has specific meaning within Systems — a school or methodological lineage), framework (too academic), paradigm

**Config**:
The parameter set that fully determines how a Chart becomes an Expression — ayanamsa, house system, tradition-specific options. Tradition-typed in Arrow (VedicConfig, UranianConfig, etc.). Two Configs are equal when their content hashes match. A Config change produces a new Expression.
_Avoid_: settings (too generic, collides with app settings), options (ambiguous)

**Card**:
A rectangle on the canvas — position, size, z-order. References one or more Expressions and a Renderer type. Immutable (copyWith pattern). Has an independent lifecycle from Charts — closing a Card doesn't unload its Charts; unloading a Chart clears Cards bound to its Expressions.
_Avoid_: widget (Flutter collision), panel (too generic), window (desktop collision)

**Renderer**:
A visualization type that paints Expression data on a Card. South Indian grid, north Indian diamond, western wheel, data table, dasha timeline. Renderer and Expression are independent axes — the same Renderer can display different Expressions, and the same Expression can be shown by different Renderers.
_Avoid_: view (Flutter collision), component

## Relationships

- A **Chart** produces zero or more **Expressions** (one per unique configuration)
- An **Expression** belongs to exactly one **Chart**
- A **Card** displays one or more **Expressions** using one **Renderer**
- Multiple **Cards** can reference the same **Expression**

## Example dialogue

> **Dev:** "The user opened Ravi's chart and switched from Lahiri to KP ayanamsa. Is that a new Chart?"
> **Domain expert:** "No — same Chart, different Expression. The Chart is Ravi's birth moment. Lahiri and KP are two Expressions of it."

> **Dev:** "What about a transit chart for today?"
> **Domain expert:** "That's a different Chart entirely — different moment in spacetime. It gets its own Expressions too."

> **Dev:** "The astrologer wants to compare Vimshottari dasha under Dhruva vs Vedanga Jyotisha ayanamsa. How does that work?"
> **Domain expert:** "Same Chart, two Expressions with different ayanamsa configs, two Cards side by side — both using the dasha timeline Renderer."

> **Dev:** "What about synastry — two people's charts overlaid?"
> **Domain expert:** "One Card referencing two Expressions from two different Charts, using a synastry Renderer."

**Collection**:
A named flat group of Charts — "my clients", "celebrity charts", "rectification cases." Stored in a sidecar `_collections.json`. Not hierarchical; use Tags for cross-cutting grouping.
_Avoid_: folder (implies hierarchy), category (implies mutual exclusivity)

**Tag** (chart-db):
A freeform user-facing label on a Chart — "celebrity", "rectification", "vedic". Multiple per Chart. Stored in the Chart's TOML file. Distinct from chitta's structured tag system (`chart:<uuid>`, `book:<id>`), which serves cross-entity linking in the memory subsystem.

**Workspace**:
The runtime environment encompassing everything the user has open — loaded Charts, computed Expressions, Cards on the Canvas, active plugin connections. The umbrella concept for "what I'm working with right now."
_Avoid_: project (too heavy), session (too transient)

**Layout**:
The serializable visual arrangement of Cards on the Canvas — positions, sizes, z-order, Renderer types. Switching Layouts does not unload Charts or discard Expressions.

**Preset**:
A saved Layout. Aion ships with starter Presets (e.g., "Vedic starter" with south Indian grid + data table + dasha timeline already arranged) so users don't face a blank Canvas. Users can also save their own. Applying a Preset creates Cards at predefined positions — the user then binds Charts to them.
_Avoid_: template (implies abstraction/indirection that doesn't exist)

**Canvas**:
The infinite 2D surface that hosts Cards. Handles geometry — pan, zoom, drag, resize, snap physics. Has no domain knowledge.

**Plugin**:
An MCP server managed by PluginHost — a separate process communicating over stdio (local) or streamable HTTP (remote). Bundled plugins ship with aion (drishti, mundus); third-party plugins are installed from elsewhere. In-process dart packages (chart-db-core, native renderers) are libraries, not plugins.
_Avoid_: extension, module, add-on

## Storage

- **TOML files are the source of truth** for Charts. Sqlite index and vectors are derived, rebuildable artifacts.
- **Natural key `(jd, lat, lon)`** identifies the astronomical moment. Used for deduplication hints, not hard uniqueness — two Charts may share a natural key with different metadata (name, tags, notes). Collisions at JD precision are rare but must be handled.
- **Sharing** a Chart means sharing a `.toml` file. **Importing** means dropping TOML files in a directory. **Backup** means copying the folder.

## Context menu behavior

- **Global System preset** — the user's default System (e.g., Vedic). Determines layer-1 context menu items when right-clicking empty Canvas. Set to "none" for System-agnostic defaults (new chart, load chart, ephemeris).
- **Card overrides global** — right-clicking a Card uses that Card's Expression's System for layer-1, regardless of the global preset.
- The global preset is a default, not a mode — it shapes the experience without restricting what Expressions or Systems are available.

## Flagged ambiguities

- "chart" is used colloquially to mean both the data record and the visual on screen — in aion's domain, Chart is strictly the data record. The visual is a Card displaying an Expression through a Renderer.
