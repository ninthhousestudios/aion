# aion — architecture deepening pass (2026-05-31, all of HEAD `e883a4e`)

This is the architecture-deepening half of the release review. It does not hunt
correctness bugs or naming — it surfaces structural friction and proposes
refactors that turn shallow modules deep, improving locality, leverage, and
test surface. Vocabulary follows LANGUAGE.md (module / interface / depth / seam /
adapter / leverage / locality; deletion test) and CONTEXT.md (Chart, Expression,
Config, Card, Renderer, Plugin, Workspace).

The central contract to hold the design against is "core aion has zero
astrological knowledge — all domain logic lives in out-of-process MCP plugins."
That contract is mostly intact, but it is carried by an **unowned, untyped
Expression JSON shape** that several modules each re-parse with their own string
keys. That is the dominant theme below.

Candidates are ordered by leverage, highest first.

---

## 1. The Expression shape is an unowned, untyped contract — and its consumers already disagree

**Files:** `lib/renderer/expression_data.dart` (`ExpressionKeys`),
`lib/renderer/south_indian/south_indian_renderer.dart`,
`lib/renderer/renderer_host.dart`, `lib/renderer/dev_data.dart`,
`lib/mcp/chart_store.dart` (`_compute`),
`packages/chart_db_core/lib/src/vector_extractor.dart`.

**Problem.** An **Expression** (per CONTEXT.md: a Chart processed through a Config)
is, on the wire, the JSON object drishti's `calculate_chart` returns. There is no
module that owns that shape. Instead it is a `Map<String, dynamic>` that at least
three modules independently reach into with their own hardcoded string keys:

- The South Indian **Renderer** reads `planet['sign_index']`, `planet['house']`,
  `planet['retrograde']`, `expr['ascendant']`, and houses keyed `cusp_longitude`
  (via `ExpressionKeys`, documented against the hand-written `dev_data.dart`
  fixture).
- `vector_extractor.extractVector` (the chart-DB engine) reads the *same* drishti
  output but with **different key names**: `planet['house_number']`,
  `planet['is_retrograde']`, `chartJson['ascmc']`, and houses keyed `longitude`.
- `ChartStore._compute` just `json.decode`s the blob and hands the raw map onward,
  asserting nothing.

> **Orchestrator correction (verified against drishti source, 2026-05-31).** This paragraph
> originally asserted the renderer was out of sync and the extractor correct. That is **backwards**.
> `arjuna/drishti/lib/src/formatting/chart_formatter.dart` emits planets keyed `retrograde`/`house`
> and houses keyed `cusp_longitude` — i.e. **the renderer (`ExpressionKeys` + `south_indian_renderer`)
> is correct against live drishti, and `vector_extractor` is the divergent consumer** (it reads
> `is_retrograde`/`house_number`/house-`longitude`, which drishti does not emit). The `ascmc` block
> the extractor reads *does* match. Severity drops from the original framing: `ChartService.createChart`
> (the only caller of `extractVector`) is wired to nothing — `import_charts` inserts via
> `ChartRepository.insert` directly — so this is a **latent** bug that bites when similarity-search is
> wired to live drishti output. `vector_extractor_test` passes only because its fixture is
> self-consistently wrong. The structural diagnosis below still holds; only the "which side is broken"
> detail flips — fix the extractor + its fixture, not the renderer.

The divergence is the textbook symptom the skill warns about: parsing pushed to
the edges, so each consumer carries a private, drifting copy of the contract and
the divergence is invisible. `dev_data.dart` has zero callers in `lib/`, so the
renderer's notion of the shape was pinned to a fixture rather than to a shared owned type — the same
fixture-pinning that hid the extractor's drift.

**Solution.** Introduce one module that owns the Expression shape — a typed
parse-once boundary (e.g. an `Expression` value type with `planets`, `houses`,
`ascendant`, plus the `ascmc`/aux block) constructed from the decoded drishti map
in one place. Renderers and the vector extractor consume the typed object, not raw
maps. `ExpressionKeys` and `_sweAuxKeyMap` collapse into this one module; the
divergent field names get reconciled there once. drishti's output schema becomes
the single thing this module is tested against.

**Benefits.** Leverage: every Renderer and the vector path gain the parsed shape
for free instead of re-deriving it. Locality: a drishti schema change is fixed in
one module, not chased across `ExpressionKeys`, `extractVector`, and each painter.
The interface becomes the test surface — you test "drishti JSON → Expression"
once with table-driven cases, and the renderer/extractor tests stop needing to
fabricate raw maps that may not match reality. This is the highest-leverage change
because the bug *already exists* (renderer vs extractor key mismatch) and is
currently untestable through the present shape.

---

## 2. `WorkspaceStore` is a superseded duplicate of `ChartStore` — delete it

**Files:** `lib/mcp/workspace_store.dart`, `lib/providers/workspace_providers.dart`,
`lib/mcp/chart_store.dart`, `test/mcp/workspace_store_test.dart`.

**Problem.** `WorkspaceStore` keys a `BehaviorSubject<ExpressionState>` map by
`ExpressionRef` and runs an MCP-result-decode block (call tool → check `isError`
→ pull `TextContent` → `json.decode` → emit `ExpressionReady`/`ExpressionError`).
`ChartStore._compute` contains the **same block, line for line** (chart_store.dart
110–148 ≈ workspace_store.dart 27–65), plus chart loading, config hashing, and
in-flight dedup. Applying the deletion test: the canvas path
(`canvas_card`, `canvas_workspace`, `load_chart_action`) reads only
`chartStoreProvider`. `workspaceStoreProvider`/`expressionProvider` have **zero
consumers** anywhere in `lib/` outside their own provider file. Deleting
`WorkspaceStore` concentrates no complexity — it just removes a second, unused
adapter over the same seam. This is a pass-through, not a module earning its keep.

**Solution.** Delete `WorkspaceStore`, `workspace_providers.dart`, and its test
(move to `/tmp` per repo deletion policy). If the per-slot `ExpressionRef` watch
provider is wanted, re-expose it as a thin family provider over `ChartStore`.

**Benefits.** Locality: one decode path instead of two that can drift. Removes the
"which store do I use?" ambiguity that already cost a reviewer a lookup. Less
surface to keep green. (This also makes candidate 1 cheaper — only one decode site
needs to construct the typed Expression.)

---

## 3. The chart-DB MCP tool layer is eight hand-rolled adapters with a duplicated, untested handler shape

**Files:** all of `packages/chart_db/lib/src/tools/*.dart` (8 files),
`packages/chart_db/lib/src/server.dart`. No `test/` dir exists.

**Problem.** Every tool repeats the same module shape: a private `_inputSchema`, a
`register*` that wires `callback: (args, extra) => _handle(...)`, a `_handle` that
manually parses `args['x'] as String?` with null/empty checks, calls one
`chart_db_core` repository method inside a `try`, serializes the result, and on
failure calls a **copy-pasted `_errorResult`** (duplicated in at least 5 of the 8
files). The real logic in this unit — argument coercion (`_parseNum`, the
`weights` string-key-to-`Map<int,double>` parse in `similar_charts`), the
null-required-field guards, and the domain serialization — is exactly the part
that is **entirely untested** (the engine below has 172 tests; this layer has 0).
Two serializers for the same `Chart` already disagree: `get_chart` emits every
field including nulls, `search_charts._chartToMap` omits nulls with `if`. The
`_handle` functions are the test surface, but nothing crosses it.

**Solution.** Two moves, both deepening:
(a) Factor the repeated mechanics — `_errorResult`, the `try/catch →
CallToolResult` wrapper, and `Chart → Map` serialization — into one small shared
module (a tool-result helper + one canonical chart serializer). Each tool's
`_handle` shrinks to "parse args, call repo, return."
(b) Make `_handle` the tested seam: give each tool a plain function that takes
parsed args + repo and returns a `CallToolResult`, then test it directly against a
real in-memory `ChartDatabase`. No MCP transport needed — the engine already runs
headless in tests.

**Benefits.** Locality: the chart-serialization contract and error formatting live
once; the null-handling divergence disappears. Leverage: one serializer pays back
across `get_chart`, `search_charts`, and any future tool. Test surface: the eight
handlers become directly exercisable, closing the single largest coverage gap in
the repo. This also deserves an ADR (see closing note) recording "MCP tool
handlers are tested as plain functions against the engine, not over stdio."

---

## 4. The Chart → Expression → Card binding lives inside a UI event handler

**Files:** `lib/canvas/canvas_workspace.dart` (`_showContextMenu`, the
`open_chart` case), `lib/mcp/chart_store.dart`, `lib/actions/load_chart_action.dart`.

**Problem.** The orchestration that realizes CONTEXT.md's core lifecycle — load a
Chart from TOML, compute an Expression via a plugin, bind it to a new Card with a
Renderer — is inlined in a `switch` arm of a 350-line `ConsumerStatefulWidget`'s
context-menu handler. The plugin name `'drishti'`, the tool name
`'calculate_chart'`, the empty Config `const {}`, and the Renderer id
`'south_indian'` are all hardcoded string literals at the call site (canvas_workspace.dart
83–102). The Card→Expression binding rule from CONTEXT.md ("a Card displays one
or more Expressions using one Renderer") has no module of its own; it is smeared
across a UI gesture handler. There is no seam at which to alter "which plugin/tool
computes this Expression" or "which Renderer a freshly bound Chart gets."

**Solution.** Extract a binding module — plain Dart, no Flutter — that takes a
loaded `chartId` (+ Config) and produces a bound `CardModel`: it calls
`ChartStore.computeExpression`, handles the error/ready states, and returns the
Card (or a typed failure). The widget's job collapses to "call the binding module,
show a snackbar on failure, hand the Card to the notifier." The `'drishti' /
'calculate_chart'` pairing becomes data owned by this module (eventually keyed by
System/Config per CONTEXT.md), not a literal in a UI switch.

**Benefits.** Locality: the load→compute→bind rule lives in one testable place;
today changing it means editing a UI handler. Leverage: the same module serves the
context menu, a future command palette, and Preset application — all three need
"bind a Chart to a Card." Test surface: the binding flow becomes a `dart test`
against a fake `ChartStore`/`PluginHost`, instead of being reachable only by
driving a widget through a right-click menu.

---

## 5. The Renderer registry is a one-adapter global wired at import time

**Files:** `lib/canvas/canvas_card.dart` (top-level `rendererRegistry`),
`lib/renderer/renderer_registry.dart`, `lib/renderer/chart_renderer.dart`.

**Problem.** `RendererRegistry` is the intended seam for the Renderer axis —
CONTEXT.md treats Renderer and Expression as independent axes with many planned
types (north Indian, western wheel, data table, dasha timeline). Right now there
is exactly **one adapter** (`SouthIndianRenderer`), and the registry is a
top-level mutable global initialized with a cascade in `canvas_card.dart`, a UI
file. One adapter = a hypothetical seam, not a real one; and a global built at
import time can't be substituted in a test or scoped per Workspace. `CanvasCard`
reaches for `rendererRegistry.get(...)` directly rather than receiving it,
coupling every card to the global. The registry's `forSystem`/`systems` filtering
(the part with actual behaviour) has no test surface because the only way in is the
global.

**Solution.** Don't over-build the seam before a second adapter exists, but stop
it being a UI-file global: own the registry in a Riverpod provider (overridable in
tests and per Workspace), inject it into `CanvasCard`, and move registration out of
`canvas_card.dart` into a renderer wiring file. The interface (`register` /
`get` / `forSystem`) stays as-is. When the second Renderer lands, the seam is
already real and tested.

**Benefits.** Leverage: registry becomes substitutable — tests can register a fake
Renderer and assert `forSystem` filtering; Workspaces can scope which Renderers
are available (matches CONTEXT.md's System-gates-Renderers rule). Locality: renderer
registration stops being a side effect of importing a card widget. Low cost — this
is mostly relocation, deferring the real interface design until the second adapter
justifies it.

---

## Note on ADRs

There are no ADRs yet, so nothing above contradicts one. Two decisions are worth
recording so future passes don't re-litigate them:

- **The Expression JSON shape and its owner** (candidate 1): once a typed
  Expression module exists, an ADR should state that drishti's `calculate_chart`
  output is the canonical Expression schema and that exactly one module parses it.
  This is the invariant that, unrecorded, let the renderer/extractor key
  divergence happen.
- **MCP tool handlers tested as plain functions against the engine** (candidate 3):
  worth pinning so the chart-DB server doesn't grow more untested handlers on the
  assumption that "it's just MCP glue."
