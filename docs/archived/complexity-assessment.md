# complexity assessment

2026-04-24 — where the real difficulty lives in aion.

## the domain is bounded

astrology software is not enterprise software. a chart is a
deterministic function of time and place. the data model is small.
the user base is individual professionals, not multi-tenant orgs.
there's no auth, no distributed state, no eventual consistency — it's
a desktop app with a local database and some child processes.

the MCP spine helps further: it pushes complexity out of aion and into
isolated servers. drishti owns calculations, chart-db owns storage,
mundus owns geo/timezone. aion itself is just the host + UI. each
piece is simple in isolation.

this is why the architecture sketches feel clean. the problem actually
is clean compared to infrastructure or enterprise systems.

## where the difficulty actually lives

### 1. the canvas UI

smooth interaction at 60fps with drag, resize, snap, multiple
renderers painting live data, layout presets animating between states.
this is a real engineering problem regardless of domain. it's the
hardest single piece of aion by a wide margin.

### 2. the workflow feel

how it actually feels to go from "client calls, gives me a birth
time" to "I'm looking at their chart next to the current transits
with dasha periods visible." that's dozens of small UX decisions that
only surface when you use it end to end. no amount of architecture
docs will surface these — only building and using the thing will.

### 3. edge cases in the seams

- timezone ambiguity for historical dates
- rectification workflows (multiple near-identical charts, iterative)
- charts that don't fit the model: event charts with no "person,"
  composite charts that aren't a single jd/lat/lon, progressed
  charts derived from a natal
- import formats that carry different data than our model expects
- calculation differences between traditions that affect the same
  UI surface (a "house" means different things in different systems)

these aren't architecture problems. they're the kind of thing that
shows up when a working astrologer tries to do their actual work and
the tool doesn't handle a case they encounter weekly.

## the pattern

the individual pieces (MCP host, chart-db, drishti, mundus) are each
straightforward. the architecture is simple because the domain is
simple. but the pieces fitting together into a tool that a
professional reaches for daily — that's the hard part, and it's not
solvable on paper.

the last 20% of making it feel right is where most of the actual
effort will go. this is true of any professional tool. keep this in
mind when the architecture phase feels "too easy" — it's supposed to
be. the real work comes after.
