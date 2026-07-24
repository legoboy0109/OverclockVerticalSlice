# ADR-0013: Isometric Board Rendering, Picking & Overlays

## Status
Proposed

> ⚠️ **HIGH engine risk, per architecture.md's own flag.** QQ-03 is already WebSearch-verified
> (2026-07-23): Godot's `local_to_map()` has a documented accuracy bug for isometric tile shapes
> ([GH#89423](https://github.com/godotengine/godot/issues/89423)), confirming custom
> inverse-projection is mandatory for picking, not optional caution. No further engine research is
> needed before drafting; the godot-specialist validation pass (§5.5 of this ADR's authoring
> process) still runs to confirm the specific API surface below (`TILE_SHAPE_ISOMETRIC`,
> `y_sort_enabled`) is correct for Redot 26.2 / Godot 4.6.

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Rendering (2D) / Input (picking) |
| **Knowledge Risk** | HIGH — flagged by architecture.md as one of two ADRs (0013, 0014) requiring WebSearch verification before Accepted. QQ-03 is verified; residual risk is confined to confirming `TileSet.TILE_SHAPE_ISOMETRIC` and `Node2D.y_sort_enabled` behave as documented in the live 4.6 editor (godot-specialist pass, not a training-data gap — both APIs predate the LLM cutoff and are unaffected by any 4.4–4.6 change in `breaking-changes.md`). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; `docs/architecture/architecture.md` (QQ-03 verification, Board Renderer sketch); `docs/architecture/change-impact-2026-07-23-isometric-projection.md`; `design/art/art-bible.md` §8.4/§8.7/§8.8 |
| **Post-Cutoff APIs Used** | None. `TileSet.TILE_SHAPE_ISOMETRIC` and `Node2D.y_sort_enabled` are both pre-4.0-cutoff, stable APIs. |
| **Verification Required** | QQ-03 (done — cited above). Residual: confirm `TILE_SHAPE_ISOMETRIC` iso cell placement and `y_sort_enabled` draw-order behavior in the live Redot 26.2 editor before this ADR moves to Accepted (a spike, not a research task). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState`/`entities()`/`entity_at()` — what Board Renderer reads to know what to draw), ADR-0005 (`GridState.manhattan_distance`/`terrain_at`/`occupant_at`/`GRID_WIDTH`/`GRID_HEIGHT` — the logical grid this ADR projects), ADR-0004 (`action_applied` signal — how Board Renderer knows *when* to redraw, without polling) |
| **Enables** | Command & Action Interface's click routing and overlay rendering (ADR-0014/0015 consume `BoardRenderer.pick_at()`/`grid_to_screen()` rather than deriving their own iso math), Game HUD's on-board glyph layer (ADR-0016 consumes `grid_to_screen()` for glyph anchors) |
| **Blocks** | Board Renderer implementation; any Command & Action Interface or Game HUD story that touches board-space rendering or click routing (all currently blocked pending this ADR, per systems-index) |
| **Ordering Note** | Should land before ADR-0014 (Input & focus) and ADR-0015 (Command FSM), since both consume this ADR's `pick_at()` for click routing rather than re-deriving hit-testing. Not a hard blocker on ADR-0012 (Faction) — no overlap. |

## Context

### Problem Statement
`design/art/art-bible.md`'s Map Projection Decision (2026-07-23) commits OVERCLOCK to 2:1 dimetric
isometric rendering. The change-impact report already confirmed this is **purely a view-layer
change** — every GDD's rules stay in logical grid space (Manhattan distance, 4-directional
adjacency, integer AP costs) and needed zero rule changes. But "purely view-layer" still needs
concrete architecture: 7 TRs across three GDDs (grid-008, cmdui-003/004/016/017, hud-010/011) all
assume a working grid↔screen transform, a reliable mouse-to-tile hit-test, correct depth-sort, and
re-derived overlay/glyph rendering — none of which exist yet, and one of which (picking) is
explicitly confirmed to break if built on the wrong engine API (QQ-03).

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- Must never call `TileMapLayer.local_to_map()` for picking (registry-adjacent constraint this ADR
  itself will register — QQ-03/GH#89423).
- Must uphold Architecture Principle 5 ("preview equals commitment") applied to the render seam:
  the forward (`grid_to_screen`) and inverse (`screen_to_grid`) transforms must be exact
  mathematical inverses of each other — a click must never resolve to a tile visually
  inconsistent with where that tile is actually drawn.
- Board Renderer is Presentation-layer: it reads `GameState`/`GridState` read-only and reacts to
  `action_applied` (ADR-0004); it never mutates authoritative state (Architecture Principle 1).
- Draw-call budget: < 500 total, with the 14×16 board itself targeted at ~5–10 (art bible §8.7) —
  any overlay/glyph strategy must not blow this via per-tile individual draw calls.
- Zero gameplay rule changes (change-impact report) — this ADR is not authorized to alter any
  GDD's Detailed Rules/Formulas, only to define how they render.

### Requirements
- A closed-form `grid_to_screen(tile: Vector2i) -> Vector2` and its exact inverse
  `screen_to_grid(px: Vector2) -> Vector2i`, both custom (never `local_to_map`/`map_to_local` for
  our own coordinate math — TR-grid-008, TR-cmdui-003).
- Occupant/prop-aware hit-testing that resolves TR-cmdui-004's stacked/occluded-sprite ambiguity,
  not just raw diamond geometry.
- Depth-sort correct for the flat VS board (no elevation) given tall props/units can still visually
  overhang an adjacent tile's diamond (art bible §8.8).
- Overlay rendering for the GDD's existing 9-class taxonomy, re-derived for 2:1 diamonds
  (TR-cmdui-016), within the draw-call budget.
- On-board glyph anchor points for both Command & Action Interface's D-3 echo and Game HUD's six
  glyph classes (TR-cmdui-017, TR-hud-010/011), with hp-pip-never-occluded priority preserved.

## Decision

### 1. The transform is one shared closed-form linear pair — hand-rolled, never engine `local_to_map`/`map_to_local`

```gdscript
class_name BoardRenderer extends Node2D   # Presentation-layer; owns the floor + overlay
                                            # TileMapLayers and the occupant Y-sort group

const TILE_WIDTH_PX: float = 128.0    # even integer, whole-pixel scaling (art bible §8.4);
const TILE_HEIGHT_PX: float = 64.0    # exact value owed to technical-art, not this ADR — 2:1 ratio is the ADR-level constraint
@export var origin_offset_px: Vector2 = Vector2.ZERO   # board-layout placement, technical-art/UX's call

func grid_to_screen(tile: Vector2i) -> Vector2:
    return origin_offset_px + Vector2(
        (tile.x - tile.y) * TILE_WIDTH_PX * 0.5,
        (tile.x + tile.y) * TILE_HEIGHT_PX * 0.5
    )

func screen_to_grid(px: Vector2) -> Vector2i:
    var local := px - origin_offset_px
    var u := local.x / TILE_WIDTH_PX + local.y / TILE_HEIGHT_PX
    var v := local.y / TILE_HEIGHT_PX - local.x / TILE_WIDTH_PX
    return Vector2i(floori(u), floori(v))
```

**Why this is exact, not an approximation.** The forward map is a linear transform of the integer
grid lattice onto a diamond lattice (a shear + scale, the standard 2:1 dimetric construction) —
its continuous extension to all of ℝ² is bijective, so the algebraic inverse above is the *exact*
preimage, and `floori()` on that exact preimage picks the correct containing diamond with the same
precision class as `floor(x / tile_width)` does for an ordinary axis-aligned grid. A screen point
landing *exactly* on a shared tile boundary (measure-zero in continuous space, but a real pixel a
mouse can land on) is resolved **deterministically and consistently** — `floori` always breaks the
tie toward the lower-index tile, identical to how `floor(x / tile_size)` behaves on an axis-aligned
grid (godot-specialist verified numerically, 2026-07-24: the point equidistant between
`(0,0)/(1,0)/(0,1)/(1,1)` resolves to `(0,0)` every run). So the precise claim is "the boundary
tie-break is deterministic," **not** "there is no boundary" — this is why Godot's own
`local_to_map()` bug (GH#89423) is very likely an *implementation* defect in the engine's C++, not
evidence the math is hard; reimplementing from this closed form sidesteps it entirely rather than
working around it. **Round-trip identity is the acceptance test**:
`screen_to_grid(grid_to_screen(t)) == t` for every `t` in `[0, GRID_WIDTH) × [0, GRID_HEIGHT)`
(Validation Criteria) — godot-specialist confirmed this holds exactly over the full 14×16 board,
and that the exactness argument is **independent of the final tile dimensions**: it was verified for
power-of-two (128×64) and non-power-of-two (100×50, 127×63) sizes alike, so technical-art's eventual
`TILE_WIDTH_PX`/`TILE_HEIGHT_PX` choice need not stay power-of-two for this guarantee to hold.

**`grid_to_screen(tile)` is also the sprite placement anchor.** Because art bible §8.4 mandates
every unit/structure/prop sprite be authored with its pivot at the ground-contact point
(bottom-center of footprint), `sprite.position = grid_to_screen(tile)` places it correctly with no
additional offset — the anchor-point convention and the ground-contact-pivot art convention are the
same point by construction, which is also what makes automatic Y-sort (§2 below) work without a
per-sprite fudge factor.

### 2. Depth-sort: native `y_sort_enabled`, not custom math (art bible §8.8 — already specified)

```
BoardRenderer (Node2D)
 ├─ FloorTileMapLayer      (TileSet.TILE_SHAPE_ISOMETRIC; static terrain art; z_index 0)
 ├─ OverlayTileMapLayer    (TileSet.TILE_SHAPE_ISOMETRIC; reachable/target/build overlays; z_index 1)
 └─ OccupantLayer (Node2D, y_sort_enabled = true; z_index 2)
      ├─ unit/structure sprites (position = grid_to_screen(tile), pivot = ground-contact point)
      └─ tall props with vertical overhang (pulled out of the floor layer per art bible §8.8)
```

Draw order is fixed by this z-index/node ordering: floor → overlays → Y-sorted occupants, so a
highlighted overlay tile never draws over a unit standing on it, and occupants always correctly
depth-sort against each other and against any tall prop via the engine's own global-Y comparison —
**no custom depth math**, per art bible §8.8's explicit instruction. `FloorTileMapLayer` and
`OverlayTileMapLayer` sit *outside* the Y-sort group (also per §8.8) since they are flat and never
need Y-sort against occupants.

### 3. Overlays: a second iso `TileMapLayer`, same `TileSet` config as the floor

`OverlayTileMapLayer` shares the floor's `TileSet` iso configuration (same `TILE_WIDTH_PX`/
`TILE_HEIGHT_PX`, same `TILE_SHAPE_ISOMETRIC`), with a dedicated tile-source containing one atlas
entry per member of the GDD's existing 9-class taxonomy (in-cap fill, over-cap hatch, target ring,
blocked-by-friendly, out-of-range dim, AREA dead-zone, build/deploy go-tile, cancel-refund, D-3
echo — command-action-interface.md's Visual/Audio B), re-drawn as 2:1 diamonds instead of squares.
Command & Action Interface calls `BoardRenderer.set_overlay(tiles: Array[Vector2i], class_id: int)`
/ `clear_overlay()` — it never touches `grid_to_screen`/pixel math itself for overlay placement,
only for anything genuinely off-grid (none identified). Because this reuses the same alignment
config as the floor layer, overlay-to-floor screen alignment is guaranteed by construction, not by
a second hand-verified transform — and it batches the same cheap way art bible §8.7 already budgets
for iso `TileMapLayer`s (~5–10 draw calls for the whole 14×16 board, floor + overlay together).

### 4. Picking: occupant-priority, then diamond fallback (resolves TR-cmdui-004)

```gdscript
class PickResult extends RefCounted:
    var tile: Vector2i          # always populated (the diamond under the point, via screen_to_grid)
    var occupant_entity_id: int # -1 if none; the Y-sorted occupant sprite actually hit, if any

func pick_at(screen_pos: Vector2) -> PickResult:
    # 1. Test occupant sprites front-to-back in Y-sort draw order (closest-to-camera first —
    #    i.e. reverse of the engine's Y-sort paint order, since a later-drawn/"in front" sprite
    #    visually occludes what's behind it and must win the click).
    # 2. Each occupant's clickable region is its own sprite's visual rect (or a per-sprite
    #    Rect2/mask authored alongside the art, not derived from grid_to_screen alone — a tall
    #    sprite's clickable area legitimately extends above its own tile's diamond).
    # 3. If an occupant's region contains screen_pos, return {tile: that occupant's own grid
    #    tile (read from GameState, not re-derived geometrically), occupant_entity_id: its id}.
    # 4. Otherwise, fall through to plain screen_to_grid(screen_pos) — an empty-tile click
    #    (move destination, build/deploy tile) — occupant_entity_id = -1.
    ...
```

This resolves the ambiguity TR-cmdui-004 names: even though `screen_to_grid` alone is
mathematically exact for the *diamond* geometry (§1), a tall sprite's silhouette can still visually
overlap a different tile's diamond in screen space (a real case even on the VS's flat, no-elevation
board — art bible §8.8 explicitly anticipates tall Impassable-terrain props needing this treatment).
Occupant-priority hit-testing means the click resolves to what the player *sees* on top, matching
"the readable board is a lie if the preview can disagree with the result" (Architecture Principle
5) applied to clicking, not just previewing. **Command & Action Interface (ADR-0014/0015) consumes
`pick_at()` as its one click-routing entry point** — it does not call `screen_to_grid` directly for
routing decisions, only `grid_to_screen` for its own overlay/preview positioning needs.

### 5. On-board glyph anchoring (TR-cmdui-017, TR-hud-010/011)

Every on-board glyph (hp pips, has-acted marker, tech marker, structure hp, build-timer badge,
research marker, AP-cost badge, damage number, cover glyph, turns numeral, target bracket, D-3
echo) anchors at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, where `GLYPH_OFFSETS` is a
per-glyph-class fixed pixel offset table (art/UX-authored data, not an architecture-level value —
this ADR defines that the anchor point exists and is `grid_to_screen(tile)`, not the specific
offset numbers, consistent with how this corpus generally leaves exact tuning values to
implementation). game-hud.md CR-5/hud-011's "hp legibility wins any conflict" is enforced by
offset-table authoring discipline (hp pips get first claim on non-overlapping screen space), not by
any runtime arbitration this ADR needs to build.

**Camera model (OQ-8) intentionally left open, per explicit decision this session** — the transform
above is camera-model-agnostic (it maps grid→a fixed local 2D space; whatever camera/viewport views
that space is a separate concern). Glyph *caching* strategy (recompute-on-move vs. per-frame
reproject) depends on OQ-8's eventual answer and is not decided here; both of OQ-8's own named
patterns (fixed → cache once; pan/zoom → parent under the zoomable root, or a `CanvasLayer` with
per-frame reproject) compose cleanly with `grid_to_screen()` regardless of which is chosen later.

### Architecture Diagram

```
   GameState (headless)                    Command & Action Interface (ADR-0014/0015)
        │  entities()/entity_at()                 │  calls pick_at(mouse_pos) for click routing
        │  action_applied signal (ADR-0004)        │  calls set_overlay()/clear_overlay()
        ▼                                          ▼
   BoardRenderer (Node2D, Presentation)  ◀──────────┘
    ├─ FloorTileMapLayer      (static terrain art, iso shape)
    ├─ OverlayTileMapLayer    (9-class overlay taxonomy, iso shape)
    ├─ OccupantLayer (y_sort_enabled) — unit/structure sprites @ grid_to_screen(tile)
    ├─ grid_to_screen(tile) -> Vector2      [exact forward, §1]
    ├─ screen_to_grid(px) -> Vector2i       [exact inverse, §1]
    └─ pick_at(px) -> PickResult            [occupant-priority + diamond fallback, §4]
                                          │
                                          ▼  glyph anchors: grid_to_screen(tile) + GLYPH_OFFSETS
                                     Game HUD (ADR-0016)
```

### Key Interfaces

```gdscript
# board_renderer.gd — top-level file, class_name BoardRenderer extends Node2D
const TILE_WIDTH_PX: float = 128.0
const TILE_HEIGHT_PX: float = 64.0
@export var origin_offset_px: Vector2 = Vector2.ZERO

func grid_to_screen(tile: Vector2i) -> Vector2        # exact forward transform
func screen_to_grid(px: Vector2) -> Vector2i           # exact inverse; NEVER local_to_map/map_to_local
func pick_at(screen_pos: Vector2) -> PickResult        # occupant-priority, then diamond fallback
func set_overlay(tiles: Array[Vector2i], class_id: int) -> void
func clear_overlay() -> void

class PickResult extends RefCounted:
    var tile: Vector2i
    var occupant_entity_id: int   # -1 if none
```

## Alternatives Considered

### Alternative A (transform): Hand-rolled forward + inverse, exact by construction — CHOSEN
- **Pros**: Provably exact round-trip; sidesteps the confirmed `local_to_map()` bug entirely rather
  than patching around it; both directions share one formula family so they can never silently
  drift apart.
- **Cons**: A few more lines of code than delegating to the engine for the forward direction.
- **Rejection Reason**: n/a (chosen).

### Alternative B: Engine `map_to_local()` forward + custom inverse
- **Description**: Use `TileMapLayer.map_to_local()` for tile→screen (the direction QQ-03's bug
  report does *not* name), keep custom math only for the buggy inverse direction.
- **Pros**: Less code for the forward direction; the forward direction is plausibly reliable (the
  bug report only names `local_to_map()`).
- **Cons**: Two independently-sourced math paths (one engine, one hand-rolled) for what must be
  exact inverses of each other — a subtle engine-internal rounding choice in `map_to_local()`
  disagreeing with our hand-rolled inverse at even one edge pixel reproduces exactly the
  preview-vs-commit-style bug Architecture Principle 5 exists to prevent, just at the render seam
  instead of the gameplay seam. Not proven safe; not worth the risk for a few saved lines.
- **Rejection Reason**: The correctness guarantee of one shared formula family is cheap to keep and
  expensive to lose; chosen against per the framing decision already confirmed this session.

### Alternative C: No `TileMapLayer` at all — hand-placed Polygon2D/Sprite2D diamonds
- **Description**: Render floor and overlay tiles as individually placed 2D nodes positioned by
  `grid_to_screen()`, bypassing the `TileMapLayer` iso-shape API entirely.
- **Pros**: Total per-tile control (arbitrary per-tile animation, no `TileSet` authoring constraints).
- **Cons**: Forfeits `TileMapLayer`'s native batching — art bible §8.7 already budgets iso
  `TileMapLayer`s at ~5–10 draw calls for the whole 14×16 board; individually placed nodes would
  cost meaningfully more without a clear benefit the GDD's overlay taxonomy actually needs (no
  overlay class requires per-tile procedural animation).
- **Rejection Reason**: No requirement justifies giving up the draw-call budget headroom.

### Alternative (hit-testing): Pure diamond math only, no occupant priority
- **Description**: `screen_to_grid()` alone resolves every click; no occupant-sprite-aware layer.
- **Pros**: Simpler — one function, no `PickResult`/priority ordering.
- **Cons**: A click on a tall sprite's visually-overlapping upper silhouette could silently resolve
  to the wrong tile — exactly the ambiguity TR-cmdui-004 names and requires resolved, not merely
  documented as a known limitation.
- **Rejection Reason**: Fails to actually resolve the TR; rejected per the framing decision already
  confirmed this session.

### Alternative (overlays): Custom-drawn nodes instead of a second `TileMapLayer`
- Covered above as Alternative C — same rejection reasoning applies specifically to the overlay layer.

## Consequences

### Positive
- One shared, provably-exact transform formula family eliminates an entire class of
  render-vs-input-disagreement bugs before they can occur, rather than relying on testing to catch them.
- Reusing the floor `TileMapLayer`'s exact config for overlays makes alignment a structural
  guarantee, not a second thing to hand-verify.
- `pick_at()` gives every downstream consumer (Command & Action Interface, future systems) one
  correct click-routing entry point instead of each re-deriving occupant-vs-tile precedence.
- Depth-sort costs zero custom code — art bible §8.8 already specified the exact native mechanism.

### Negative
- `BoardRenderer` is the one Presentation-layer module in this ADR set that is *not* a headless
  static utility (unlike `AI`/`Movement`/`Combat`) — it is inherently `Node2D`-based and
  scene-tree-coupled, so its own tests are Integration-typed, not Logic-typed (consistent with how
  the GDDs themselves classify all view-layer ACs as Integration/Visual-Feel, never Logic).
- `pick_at()`'s occupant-region test needs each occupant sprite to carry its own clickable-region
  data (not purely derivable from `grid_to_screen` alone) — a small additional authoring/import
  requirement on unit/structure scenes, not just a code-level concern.
- Leaving OQ-8 (camera model) open means glyph-anchoring's *caching* strategy is provisional — not
  a correctness risk (both of OQ-8's named patterns compose with this ADR's transform), but real
  implementation work is deferred, not avoided.

### Risks
- **`TileSet.TILE_SHAPE_ISOMETRIC` cell-placement and `y_sort_enabled` draw-order behavior are
  asserted from documentation/precedent, not yet spiked in the live Redot 26.2 editor** — this is
  exactly what the godot-specialist validation pass (§5.5) and the Status-section note above flag as
  the residual verification before Accepted. Mitigation: a one-scene spike (a handful of tiles +
  one tall prop + one unit) before this ADR moves past Proposed.
- **`GLYPH_OFFSETS`/`origin_offset_px`/`TILE_WIDTH_PX` are unpinned numeric values** — this ADR
  defines the formula shape, not the numbers; a technical-art/UX pass must set them before any
  glyph visibly renders correctly. Mitigation: treat as a data-driven config (mirrors this corpus's
  `gameplay_config_storage` convention) rather than hardcoded literals, so retuning needs no code change.
- **Occupant clickable-region authoring is a new per-asset requirement** with no existing owner
  named in any ADR yet — flagged for whichever ADR/epic actually implements unit/structure scene
  authoring (likely ADR-0014's Input & focus architecture, since it owns overall click/hover
  precedence) to pick up explicitly rather than let slip between this ADR and that one.
- **The `z_index` / `y_sort_enabled` division of labor must be protected going forward**
  (godot-specialist, 2026-07-24). Godot's rule (stable since 4.0, unaffected by any 4.4–4.6 change):
  `z_index` is the coarse cross-tree sort key; `y_sort_enabled` only re-sorts children *within* a
  Y-sort group at the same effective z-index — a Y-sorted child cannot "escape" its parent's z-index
  band. This ADR's ordering (Floor `z_index 0` → Overlay `z_index 1` → `OccupantLayer z_index 2`)
  uses `z_index` for the coarse floor→overlay→occupant bands and reserves `y_sort_enabled` purely for
  occupant-vs-occupant/prop depth *inside* `OccupantLayer` — idiomatic and correct today. The
  forward risk: a future node added under `OccupantLayer` (e.g. a VFX node authored later assuming
  root-level z-index semantics) that sets its own conflicting `z_index` could break occupant
  depth-sort. Mitigation: children of `OccupantLayer` must not set a `z_index` that fights the
  Y-sort — a code-review/scene-authoring guardrail, not a code check. (`CanvasGroup` is irrelevant
  to depth-sort — material compositing only — and this ADR correctly never invokes it.)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| grid-terrain.md | TR-grid-008: render-side projection layer separate from logical grid, grid→screen 2:1 transform, inverse picking, depth-sort | §1 (`grid_to_screen`/`screen_to_grid`), §2 (native Y-sort), §4 (`pick_at`) — all in `BoardRenderer`, never touching `GridState`'s own logical fields |
| command-action-interface.md | TR-cmdui-003: custom inverse screen→grid hit-test for 2:1 dimetric | §1's `screen_to_grid`, exact by construction |
| command-action-interface.md | TR-cmdui-004: resolve hit-test ambiguity from stacked/occluded iso tiles | §4's occupant-priority-then-diamond-fallback `pick_at()` |
| command-action-interface.md | TR-cmdui-016: re-derive iso overlays for 2:1 diamonds | §3's `OverlayTileMapLayer` + `set_overlay()`/`clear_overlay()` |
| command-action-interface.md | TR-cmdui-017: iso-space anchors for on-board glyphs w/ occlusion avoidance | §5's `grid_to_screen(tile) + GLYPH_OFFSETS` anchor convention |
| game-hud.md | TR-hud-010: on-board glyph layer anchored per-entity, reprojecting under iso | §5, same anchor convention, shared by both consumer GDDs |
| game-hud.md | TR-hud-011: fixed per-tile sub-positions + occlusion-priority (hp pips never occluded) | §5 — offset-table authoring discipline (hp pips claim first) |

## Performance Implications
- **CPU**: `grid_to_screen`/`screen_to_grid` are O(1) closed-form arithmetic — negligible.
  `pick_at()` is O(visible occupants) in the worst case (a linear front-to-back scan), bounded by
  the same N≤24 worst-case army size ADR-0011 already budgets against — not a new perf surface.
- **Memory**: `FloorTileMapLayer`/`OverlayTileMapLayer` are standard engine-managed tile storage;
  no new per-tile heap allocation beyond what any `TileMapLayer` already costs.
- **Load Time**: Negligible — one `TileSet` resource per layer, loaded once.
- **Network**: N/A.
- **Draw calls**: Floor + overlay together stay within art bible §8.7's ~5–10 call budget for the
  14×16 board (both are `TileMapLayer`s with native batching); occupants batch per §8.7's existing
  shared-atlas/shared-material rules — this ADR introduces no new draw-call category.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Round-trip identity**: for every tile `t` in `[0, GRID_WIDTH) × [0, GRID_HEIGHT)`,
  `screen_to_grid(grid_to_screen(t)) == t` exactly.
- **Boundary correctness**: sample screen points exactly on a diamond edge/vertex and confirm
  `screen_to_grid` resolves deterministically (no NaN, no off-by-one flicker) to one of the two
  adjacent tiles consistently, not alternating between runs.
- **Occupant-priority picking**: construct a tall prop/unit whose sprite visually overlaps an
  adjacent tile's diamond; click within the overlap region and assert `pick_at()` returns the
  occupant, not the geometrically-underlying empty tile.
- **Overlay/floor alignment**: render a floor tile and an overlay tile at the same grid coordinate;
  assert their screen-space diamonds coincide exactly (same `TileSet` config, §3).
- **Depth-sort**: place two occupants at different grid rows and confirm draw order matches
  `y_sort_enabled`'s global-Y comparison, with no custom sort code involved.
- **Engine spike (pre-Accepted)**: one scene with floor + overlay + a tall prop + a unit, confirming
  `TILE_SHAPE_ISOMETRIC` and `y_sort_enabled` render as this ADR assumes in the live Redot 26.2 editor.

## Related Decisions
- ADR-0001: State model ownership (`GameState`/`entities()`/`entity_at()` — Board Renderer's read surface)
- ADR-0004: Event/signal architecture (`action_applied` — how Board Renderer knows when to redraw)
- ADR-0005: Grid representation (`GridState` — the logical grid this ADR projects; explicitly never
  altered by this ADR, per the change-impact report's zero-rule-change finding)
- ADR-0011: AI opponent decision loop (shares the N≤24 worst-case army-size assumption `pick_at()`'s
  perf bound reuses)
- `docs/architecture/change-impact-2026-07-23-isometric-projection.md` — the 7 architecture concerns
  this ADR resolves (concerns 1–5 directly; concern 6 (unit facing) and 7 (board-cursor
  directional-navigation mapping) are out of this ADR's scope — facing is presentation/animation
  content, not a coordinate/picking decision, and board-cursor is explicitly named a `/ux-design`
  decision in that report)
- `design/art/art-bible.md` §8.4 (2:1 dimetric standard, ground-contact pivot), §8.7 (draw-call
  budget), §8.8 (Y-sort depth mechanism)
