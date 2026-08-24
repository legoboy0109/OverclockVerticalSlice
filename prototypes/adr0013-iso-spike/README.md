# ADR-0013: Isometric Board Rendering — Pre-Accepted Engine Spike

## Hypothesis

ADR-0013 (isometric board rendering, picking, overlays) proposes:

1. `TileSet.TILE_SHAPE_ISOMETRIC` renders correct 2:1 dimetric diamonds when configured
   with `tile_size = Vector2i(128, 64)`.
2. `Node2D.y_sort_enabled` on an `OccupantLayer` produces correct front-to-back draw
   order for occupants (a movable unit) and a tall prop, using only native Y-sort — no
   custom depth math.
3. The ADR's hand-rolled `grid_to_screen()`/`screen_to_grid()` closed-form pair are exact
   inverses of each other over the full pinned 14x16 board, and a custom, occupant-aware
   `pick_at()`-style click routing correctly prefers a visually-occluding sprite over the
   raw diamond geometry underneath it.

Per the ADR's own Status/Risks sections, (1) and (2) are **asserted from documentation/
precedent, not yet spiked live** in Redot 26.2 / Godot 4.6 — this is the residual
verification item blocking Accepted. (3)'s math was already godot-specialist-verified via
Python (exact full-board round-trip, max err ~7e-15); this spike re-confirms it holds
through the actual live GDScript class the interactive scene uses, and adds a click-driven
interactive re-confirmation on top of the headless math check.

This spike does **not** re-derive or question the math — it exists solely to produce the
one artifact the ADR says is still missing: a human looking at the live Redot editor.

## How to Run

### Headless round-trip self-check (automated, no visual confirmation needed)

```
cd prototypes/adr0013-iso-spike
../../redot --headless --script headless_roundtrip_check.gd --path .
```

Prints PASS/FAIL for `screen_to_grid(grid_to_screen(t)) == t` over every tile `t` in
`[0, 14) x [0, 16)` (224 tiles — the ADR's pinned board size). No GdUnit4 dependency —
a plain `SceneTree` script, consistent with `prototypes/qq05-reachable-bench` and
`prototypes/spikes/qq06_ai_loop_bench.gd`.

### Interactive scene (requires a human to confirm rendering)

```
cd prototypes/adr0013-iso-spike
../../redot --path .
```

This is a **standalone mini-project** — its own `project.godot`, isolated from the repo
root `project.godot` (owned by a different spike; this spike never touches it). The repo
root's `./redot` binary is reused via relative path; no separate engine install needed.

First-time setup note: this project's `.godot/` class-name cache is regenerated
automatically the first time the editor opens it. If you ever add/rename a
`class_name`-declared script in this directory and a run reports "Identifier ... not
declared in the current scope", rebuild the cache once with:

```
../../redot --headless --import --path .
```

then re-run normally.

## Status

Concluded (spike artifact complete) — 2026-07-25. **Awaiting human visual confirmation**
of the two live-rendering checks (see INTERACTIVE RUN PROTOCOL in the delivery report) —
this is the one part of "concluded" that requires a human, not an agent, per the ADR's own
Validation Criteria ("Engine spike (pre-Accepted)").

## Findings

- **Headless round-trip**: PASS. All 224 tiles in the 14x16 board round-trip exactly
  through the live GDScript `BoardTransform` class (the same class the interactive scene
  uses) — re-confirms the ADR's Python-verified math holds in the actual runtime, not just
  in an offline derivation.
- **API surface confirmed present on this build** (Redot 26.2 / Godot 4.6, engine binary
  `26.2.stable.official.4f5b14aba`): `TileMapLayer.set_cell`/`erase_cell`,
  `TileSetAtlasSource.create_tile`, `TileSet.TILE_SHAPE_ISOMETRIC`, `Node2D.y_sort_enabled`
  — all present and callable with zero deprecation warnings under `--verbose`.
- **Two bugs caught and fixed during this spike** (see delivery report for full detail):
  a `var transform` declaration in `iso_spike.gd` silently shadowed `Node2D`'s own built-in
  `transform` property (renamed to `iso_transform`); and the newly-added `IsoTileSetBuilder`
  global class required a one-time `--headless --import` cache rebuild before the scene
  would parse (documented above as a recurring gotcha for this directory).
- **Live visual checks (TILE_SHAPE_ISOMETRIC diamond rendering, y_sort_enabled draw order,
  click-to-pick)**: not agent-verifiable — require a human running the windowed scene.
  See the delivery report's INTERACTIVE RUN PROTOCOL for exact PASS/FAIL criteria.

## Caveats

- Placeholder art only (runtime-generated flat-color diamonds/rectangles via `Image`/
  `ImageTexture` in `iso_tileset_builder.gd`) — this validates geometry and draw order,
  not final art. No imported binary assets, so nothing here needs an import step beyond
  the class-cache rebuild noted above.
- The scene's `_handle_click()` picking logic is a simplified stand-in for the ADR's real
  `pick_at()`/`PickResult` (no `GameState`/entity ids exist yet — this project is still in
  ADR/design phase for those systems, per the same convention `qq06_ai_loop_bench.gd`
  documents). It demonstrates the same occupant-priority-then-diamond-fallback shape,
  not the final production API.
- This directory's `project.godot` is throwaway and isolated — it must never be merged
  into or referenced by the repo root project, per the prototype-code rule ("Prototypes
  must not modify files outside `prototypes/`").
