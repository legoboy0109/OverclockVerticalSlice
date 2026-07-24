# OVERCLOCK — Master Architecture

## Document Status
- Version: 1.0
- Last Updated: 2026-07-23
- Engine: Redot 26.2 (Godot 4.6-compatible fork)
- GDDs Covered: grid-terrain, game-state-turn-manager, ap-economy, unit-system, movement-system, combat-resolution, base-production, research-tech, command-action-interface, game-hud, ai-opponent, faction-identity (12 Vertical-Slice systems)
- Technical Requirements: 200 TRs (TR-<system>-NNN) → 16 ADRs, 200/200 mapped, zero orphans
- ADRs Referenced: 16 required (ADR-0001..0016), all Proposed/not-yet-written
- Technical Director Sign-Off: 2026-07-23 — APPROVED WITH CONDITIONS (write+Accept Foundation ADRs 0001–0008 before coding; perf spikes for QQ-05/QQ-06 before ADR-0009/0011 Accept). Both HIGH-risk engine assumptions (iso picking, dual-focus) WebSearch-verified 2026-07-23 — no longer blocking.
- Lead Programmer Feasibility: SKIPPED (Lean mode — LP-FEASIBILITY is not a PHASE-GATE)

## Engine Knowledge Gap Summary

**Engine:** Redot 26.2 (Godot 4.6-compatible fork). **LLM training covers:** ~Godot 4.3.
**Post-cutoff versions:** 4.4, 4.5, 4.6. Cross-reference `docs/engine-reference/godot/`
before acting on any decision flagged ⚠️ below.

### 🔴 HIGH RISK — both verified 2026-07-23 (WebSearch)
- **UI dual-focus system (Godot 4.6)** — ✅ **VERIFIED PRESENT.** Godot 4.6 officially separates
  mouse/touch focus from keyboard/gamepad focus with independent styling
  ([4.6 release notes](https://godotengine.org/releases/4.6/)). OVERCLOCK is mouse-primary +
  gamepad-secondary with a custom on-board cursor — the GDD assumption (TR-cmdui-021, TR-hud-022)
  holds. Redot 26.2 is backward-compatible with Godot 4.x core APIs; still confirm the exact
  `grab_click_focus`/`grab_focus` signature via ClassDB introspection at implementation (residual LOW).
- **Isometric `TileMapLayer` picking / depth-sort** — ✅ **VERIFIED, and it confirms the custom-work
  decision.** Godot's built-in `local_to_map()` has a *documented accuracy bug* with isometric tile
  shapes ([GitHub #89423](https://github.com/godotengine/godot/issues/89423)) — the engine does NOT
  give reliable 2:1 dimetric picking for free. The architecture's stance (custom inverse-projection
  in Board Renderer, never engine `local_to_map` for iso picking) is therefore mandatory, not
  optional (TR-grid-008, TR-cmdui-003/004/016/017, TR-hud-010). Largest new surface; now
  well-understood rather than speculative.

### 🟡 MEDIUM RISK
- **`duplicate_deep()` (Godot 4.5)** — the `clone()` deep-copy the whole headless-simulation +
  AI-lookahead architecture rests on. Old `duplicate()` no longer deep-copies nested resources.
  Touches Game State, AI, Faction, Unit, Research. See `deprecated-apis.md` line 29.
- **`TileMapLayer` replaces `TileMap` (4.3)** + scene-tile rotation (4.6) — board rendering.
- **`FileAccess.store_*` returns `bool` (4.4)** — save/load path (deferred to Alpha).

### 🟢 LOW RISK
- Core game logic, grid math, deterministic combat/AP formulas, data-driven Resources, static
  typing — in training data, unchanged.
- **Dedicated 2D navigation server (4.5)** — sidestepped: Movement hand-rolls BFS, no `AStarGrid2D`.
- Physics (Jolt 4.6) and 3D rendering (glow/D3D12/SSR) — not used by a flat-2D grid tactics game.

## System Layer Map

The defining architectural fact: the GDD corpus was authored on a **render-decoupled,
headless-simulatable, deterministic state model** (a Technical-Director seed) from day one.
Game logic lives in plain, statically-typed GDScript objects (not Nodes); rendering and input
are pure consumers layered on top. That single decision shapes every boundary below.

```
┌───────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER   (pure consumers — read state, render, take input) │
│    • Command & Action Interface (#9)   — FSM, iso picking, overlays     │
│    • Game HUD (#10)                     — readouts, on-board glyphs, SFX │
│    • Board Renderer / iso view          — [new module]                  │
├───────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER        (gameplay policy on top of Core)                  │
│    • AI Opponent (#11)                  — headless tempo heuristic       │
│    • Faction Identity (#12)             — cross-cutting effective_X fold │
├───────────────────────────────────────────────────────────────────────┤
│  CORE LAYER           (the gameplay verbs — all spend from one pool)    │
│    • Unit System (#4)                   • Combat Resolution (#6)         │
│    • Movement System (#5)               • Base & Production (#7)         │
│    • Research / Tech (#8)                                                │
├───────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER     (authoritative state — headless, deterministic)   │
│    • Game State & Turn Manager (#2)     — owns the model + apply_action  │
│    • AP Economy (#3)                    — the one pool; spend/can_afford │
│    • Grid & Terrain (#1)                — board data model + map load    │
│    • Event/Signal bus                   — [new module, state→render]     │
├───────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER       (Redot 26.2 / Godot 4.6 API surface)              │
│    • TileMapLayer, Control/CanvasLayer, Resource, Input, FileAccess      │
└───────────────────────────────────────────────────────────────────────┘
```

### Layer assignment rationale

| System | Layer | Why here (and not elsewhere) |
|--------|-------|------------------------------|
| **Grid & Terrain (#1)** | Foundation | Pure data model (occupancy, terrain, `manhattan_distance`) owned by game state — not Core, it holds no gameplay policy and everything spatial depends on it. Its `TileMapLayer` render side lives in Presentation (Board Renderer). |
| **AP Economy (#3)** | Foundation | Systems-index: "a pure Foundation system queried by all spenders." Holds no gameplay verb; it is the resource substrate. |
| **Game State & Turn Manager (#2)** | Foundation | Owns `apply_action`, the turn FSM, `clone()`, win-check. The bottleneck everything routes through. |
| **Unit / Movement / Combat / Base&Prod / Research (#4–#8)** | Core | The five gameplay verbs. Each mutates via `apply_action` and spends via AP Economy. Research is Core (a spend-verb), not Feature (opponent policy). |
| **AI Opponent (#11)** | Feature | Pure policy — reads Core/Foundation via `clone()` + queries, commits via `apply_action`. No system depends on it. |
| **Faction Identity (#12)** | Feature | A **cross-cutting concern**, not a vertical system: injects `effective_X()` folds into Unit/AP/Base&Prod/Combat/Research read-sites. Placed in Feature (data+policy over Core) but its wiring is cross-layer — see Module Ownership. |
| **Command & Action Interface (#9), Game HUD (#10)** | Presentation | Pure consumers. Both hold zero copies of balance constants, read live queries, route commits through `apply_action`. |

### Two new modules the GDDs imply but the systems-index does not name

1. **Board Renderer / iso view** (Presentation) — the `TileMapLayer` + grid→screen 2:1 dimetric
   transform + inverse picking + depth-sort. Grid-terrain: "the on-screen TileMapLayer is only a
   view." The 2026-07-23 iso change-impact report makes this a first-class module.
   ⚠️ **HIGH RISK** (iso picking/depth-sort is custom, not free from the engine).
2. **Event/Signal bus** (Foundation) — state emits change events (`unit_moved`, `turn_ended`,
   `game_over`); HUD/renderer subscribe. Required by TR-hud-001 and TR-gamestate-012. Typed-signal
   set vs. aggregate bus is an open ADR (from TR-gamestate-019).

### Engine-awareness flags (Foundation & Core)

- ⚠️ **Game State `clone()`** (Foundation) → depends on `duplicate_deep()` (Godot 4.5, MEDIUM).
  Old `duplicate()` won't deep-copy nested resources. Verify vs `deprecated-apis.md:29` before coding.
- 🟢 **Movement** (Core) → hand-rolled BFS, avoids `AStarGrid2D` — sidesteps the 4.5 nav-server change.
- 🟢 **AP Economy, Unit, Combat, Research** → pure integer logic, in training data.

## Module Ownership

Ownership rules that govern the whole system:
- **Game State & Turn Manager is a `RefCounted`/`Resource`, NOT a `Node`** — the headless requirement.
- **`AP Economy.spend()` is the sole AP deductor**; **Grid's `place`/`remove`/`move` are the sole
  occupancy mutators**; **`apply_action` is the sole state-mutation vector.**
- **Faction Identity owns `effective_X()` folds** that inject into five other systems' read-sites.

### Foundation Layer

| Module | Owns | Exposes (read / mutate) | Consumes | Engine APIs |
|--------|------|-------------------------|----------|-------------|
| **Game State & Turn Manager** | Authoritative state object (grid ref, entity set, per-player state, `active_player`, `round_number`, `match_status`, `faction_of`); turn FSM; `entity_id` counter | **read:** `active_player`, `current_ap(p)`, `round_number`, `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(p)` · **mutate:** `apply_action(action)` (sole vector), `clone()`, `end_turn()` | AP Economy (income snapshot at start-of-turn); all Core systems; Grid (owns instance) | `RefCounted`/`Resource` (⚠️ **not** `Node`); `duplicate_deep()` ⚠️4.5 |
| **AP Economy** | `current_ap[p]`, `income_this_turn[p]` snapshot; income coefficients | **read:** `current_ap(p)`, `can_afford(p,amt)`, `ap_income(p)`, `ap_income_breakdown(p)` · **mutate:** `spend(p,amt)` (sole deductor) | `completed_outpost_count(p)` (Base&Prod), `has_economy_tech(p)` (Research), faction income Δ | none (pure logic) |
| **Grid & Terrain** | Tile terrain array, occupancy map, dimensions, map-def loader | **read:** `in_bounds`, `terrain_at`, `is_cover`, `occupant_at`, `is_passable`, `neighbors`, `manhattan_distance` · **mutate:** `place`, `remove`, `move` | Map definition assets; `PROC_SEED` PRNG | `Resource` (map defs `.tres`/JSON); seeded RNG (not global) |
| **Event/Signal bus** | The change-event channel | Emits `unit_moved`, `unit_destroyed`, `ap_changed`, `hp_changed`, `turn_changed`, `build_tick`, `game_over` | Called by apply_action post-mutation | Godot typed `Signal` — ADR: typed signals vs aggregate bus |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **Unit System** | `UnitStats` templates (`.tres`); per-unit runtime state (hp, pos, flags) | `can_attack`, `reset_turn_flags`, `duplicate`, `apply_hp_delta`, `effective_attack/defense`, HUD read-surface | Research tech flags; AP `spend`; Grid occupancy; Faction `effective_produce/move_cost` | `Resource` (UnitStats), `duplicate_deep()` ⚠️4.5 |
| **Movement** | Reachable-search algorithm; visited/cost flat array | `reachable(state,unit)→{tile,min_cost,is_surcharged}`, `move(unit,dest)→Result` | Grid `neighbors/is_passable/occupant_at`; Unit costs; AP `can_afford/spend` | none (hand-rolled BFS, **no** `AStarGrid2D`) |
| **Combat Resolution** | Damage formula; targeting; counter logic; stat fields (`targeting_mode`, `min_range`, `defense`, `can_counterattack`) | `legal_targets(unit[,from_tile])`, `preview_damage`, `attack(a,t)→Result`, blocked-shot reasons | Unit stats; Grid; AP `spend`; Turn Manager win-check hook | none |
| **Base & Production** | Structure templates + instances; build/production queues; `MAX_OUTPOST_COUNT` (disabled) | `build`, `produce`, `cancel_build`, `legal_build_tiles`, `legal_deploy_tiles`, `completed_outpost_count` | Grid; AP; Unit (instantiation); Combat (structure-attacker, destruction) | `Resource` (structure templates) |
| **Research / Tech** | Per-player tech flags; per-Lab research state; tech table | `legal_research_targets`, `start_research`, `cancel_research`, `has_*_tech` flags | AP; Base&Prod (Lab lifecycle + outpost count); shared destruction trigger | `Resource` (tech table) |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **AI Opponent** | Scoring function; 15 tunable knobs; decision loop | `take_turn(state)` (commits via apply_action) | `clone()`; all Core query APIs; AP; Grid distance | none (headless; must not touch render/UI) |
| **Faction Identity** | `FactionDef` resources; per-player faction assignment | `effective_*()` fold functions; `faction_of`, `faction_allows`, `faction_hue`, `faction_pattern_id` | Base tables of Unit/AP/Base&Prod/Combat/Research | `Resource` (FactionDef); `duplicate_deep()` ⚠️4.5 |

### Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **Command & Action Interface** | Command FSM; iso hit-test; overlay compute; BoardCursor | (leaf — emits `selection_changed` to HUD; commits to apply_action) | All Core query APIs; AP; Grid; Board Renderer transform | ⚠️ `TileMapLayer` iso picking (HIGH); ⚠️ dual-focus `grab_focus/grab_click_focus` (HIGH); `InputEvent*` |
| **Game HUD** | Screen-space widgets; on-board glyph layer; action-log ring buffer; audio dispatch | (leaf — zero downstream dependents) | 7 upstream read APIs via `GameStateReader` facade; Event bus | ⚠️ dual-focus (HIGH); `CanvasLayer`/`Control`; `TileMapLayer.map_to_local()` |
| **Board Renderer / iso view** | grid→screen 2:1 transform; depth-sort; tile rendering | `grid_to_screen(tile)`, `screen_to_grid(px)` | Grid read API; Event bus | ⚠️ `TileMapLayer` isometric + Y-sort (HIGH) |

### Dependency Diagram (arrows = "depends on / calls into")

```
        Command&Action ──┐        ┌── Game HUD
             │           │        │      │
             │      Board Renderer │      │   (Presentation → read-only + apply_action)
             ▼           ▼        ▼      ▼
   ┌─────────────────────────────────────────────┐
   │  AI Opponent          Faction Identity       │  (Feature)
   │      │                  │ (effective_X folds) │
   └──────┼──────────────────┼─────────────────────┘
          ▼                  ▼   (into read-sites of ↓)
   ┌─────────────────────────────────────────────┐
   │  Unit  Movement  Combat  Base&Prod  Research  │  (Core)
   └──────┬─────┬────────┬────────┬─────────┬──────┘
          ▼     ▼        ▼        ▼         ▼
   ┌─────────────────────────────────────────────┐
   │  Game State & Turn Manager  ──owns──▶ Grid    │  (Foundation)
   │  AP Economy        Event bus                  │
   └─────────────────────────────────────────────┘
```
No upward dependencies. No cycles (AP Economy is queried by all spenders; income is a read-only
query over structures — confirmed acyclic in systems-index).

### Engine API verification flags

- ⚠️ **`duplicate_deep()`** — Godot 4.5, MEDIUM. Game State `clone()`, Unit `duplicate()`, Faction
  deep-copy. Verified against `deprecated-apis.md:29` (old `duplicate()` shallow-copies nested
  resources). Behaviour confirmed in reference doc; verify exact signature at implementation.
- ⚠️ **`TileMapLayer` isometric picking + `map_to_local()`** — Godot 4.3/4.6, HIGH. Board Renderer,
  Command Interface, HUD glyphs. **NEEDS VERIFICATION via WebSearch** — reference confirms the
  `TileMap`→`TileMapLayer` rename but not 2:1 dimetric picking behaviour.
- ⚠️ **Dual-focus `grab_focus()`/`grab_click_focus()`** — Godot 4.6, HIGH. Command Interface, HUD.
  **NEEDS VERIFICATION** — Redot 26.2 fork parity unconfirmed (TR-cmdui-021).

## Data Flow

### 3.1 — Player action path (hover → preview → commit)

```
Mouse motion ──▶ Command&Action FSM
  │  (1) screen_to_grid(px)  ← Board Renderer  [⚠️ iso inverse hit-test]
  │  (2) tile-change gate — abort if same logical tile (perf, TR-cmdui-005)
  ▼
On preview ENTRY (once, not per hover):
  Tier1: Movement.reachable(state,unit) ─▶ {tile,min_cost,is_surcharged}   [call]
  Tier2: Combat.legal_targets(unit,from_tile) across frontier              [call]
  Tier3: hover reads = O(1) lookups into held sets                         [read]
  ▼
On COMMIT (click/confirm):
  Command&Action ──▶ GameState.apply_action(action)                        [mutate]
       apply_action{  validate legality (re-check, Tier4)
                      AP.spend(p, cost)              ← sole deductor
                      Grid.move/place/remove         ← sole occupancy mutator
                      Combat.attack / Unit.apply_hp_delta
                      win-check (HQ destroyed?) → match_status=GameOver
                      emit Event bus signals  }      [synchronous, atomic]
  ▼
  Event bus ──▶ HUD (AP tick-down, hp-pip drain, action-log append)        [signal]
            ──▶ Board Renderer (sprite move, depth re-sort)                [signal]
  Command-flash (Cmd&Action) + AP tick-down (HUD) fire off the SAME
  apply_action-result event, same frame  (TR-cmdui-023 — named desync risk)
```
- **Data:** `action` object (verb + params) → produces a `Result` + emitted signals.
- **Sync/async:** `apply_action` is a synchronous atomic call. Rendering reacts via signals.
- **Thread boundary:** none — single-threaded (turn-based, no simulation deadline).

### 3.2 — Event/signal path (state → presentation, decoupled)

```
GameState mutation ──emit──▶ Event bus ──▶ [HUD, Board Renderer]  (subscribers)
```
- Presentation never polls state in `_process`; it subscribes (TR-hud-023).
- HUD coalesces N signals/frame → ≤1 redraw (TR-hud-002). A multi-kill = 1 redraw.
- One-way only: `#9 Command&Action ──selection_changed──▶ #10 HUD` (HUD is a leaf, TR-hud-013).
- **Open ADR:** typed signals (`ap_changed`, `hp_changed`, …) vs. one aggregate `state_changed` diff.

### 3.3 — Save/load path (deferred to Alpha, pre-conditioned now)

```
Save:  GameState ──serialize──▶ plain-value snapshot (grid, entities, per-player, tech, faction)
Load:  snapshot ──reconstruct──▶ GameState  (identical instance)
Map:   map-def (.tres/JSON) ──load──▶ Grid  (independent of live session)
```
- **Owner:** Game State owns serialization; every field is already a plain serializable value, no
  engine object refs (TR-gamestate-015) — this is why `clone()` works today and save/load will work
  later. Nothing new to build for the VS; the constraint is enforced now.
- ⚠️ `FileAccess.store_*` returns `bool` in 4.4 (MEDIUM) — relevant only when save/load lands.

### 3.4 — Initialization / boot order

```
1. Load map definition ──▶ Grid (terrain + reachability validate)   [TR-grid-010]
2. Resolve faction_of(player) at SELECTING→ASSIGNED               [TR-faction-008/009]
3. Apply each faction starting_loadout to the board (once)
4. GameState constructed → enter Setup phase
5. Setup → PlayerTurn(P0): start-of-turn canonical 4-step sequence:
      a. set active player
      b. clear per-turn flags (units + structures)
      c. apply start-of-turn effects (build-timer, research-timer advance)  ← step 3
      d. reset AP to income snapshot  ← step 4 (observes 5c results)
6. Presentation binds read-only facades + subscribes to Event bus
7. AI Opponent (if P1 is AI) waits for its Action phase
```
- **Critical ordering:** faction lock before first start-of-turn; build/research timers (5c) before
  income snapshot (5d) — batch-completed structures must be counted in that turn's income.

**Cross-cutting determinism guarantee (all four flows):** no engine RNG in state transitions; the
only seeded RNG is Grid procedural map-gen at load (TR-grid-009, TR-gamestate-008). Identical state
+ identical ordered actions → byte-identical result.

## API Boundaries

Typed GDScript pseudocode (per `technical-preferences.md`). ⚠️ = engine-type flag.

### Foundation

```gdscript
# Game State & Turn Manager — the mutation choke point
class GameState extends RefCounted:            # ⚠️ RefCounted, NOT Node (headless)
    func apply_action(action: Action) -> ActionResult   # SOLE mutation vector; atomic; runs win-check
    func clone() -> GameState                            # ⚠️ deep-copy via duplicate_deep() (4.5)
    func end_turn() -> ActionResult                      # unconditionally legal (no softlock)
    # read (all side-effect-free):
    func active_player() -> int
    func current_ap(player: int) -> int
    func round_number() -> int
    func match_status() -> int                           # enum: InProgress | GameOver
    func entities() -> Array[Entity]
    func entity_at(tile: Vector2i) -> Entity             # null if empty
    func faction_of(player: int) -> FactionDef
    var grid: Grid
    # Invariant callers respect: mutate ONLY through apply_action. Never write a field.
    # Guarantee to callers: illegal action → zero state change (incl. AP); win-check is synchronous.
```
```gdscript
# AP Economy
func current_ap(player: int) -> int
func can_afford(player: int, amount: int) -> bool        # pure; any player
func ap_income(player: int) -> int
func ap_income_breakdown(player: int) -> Dictionary      # {base, outpost, econ_tech}  (TR-hud-019)
func spend(player: int, amount: int) -> bool             # SOLE deductor; reject if not active/<0/>ap
# Invariant: only spend() and start-of-turn reset write current_ap. Guarantee: 0 ≤ ap ≤ income.
```
```gdscript
# Grid & Terrain
func in_bounds(t: Vector2i) -> bool
func terrain_at(t: Vector2i) -> int                      # enum Plain|Cover|Impassable
func is_cover(t: Vector2i) -> bool
func is_passable(t: Vector2i) -> bool
func occupant_at(t: Vector2i) -> Entity
func neighbors(t: Vector2i) -> Array[Vector2i]           # O(4)
func manhattan_distance(a: Vector2i, b: Vector2i) -> int
func place(e: Entity, t: Vector2i) -> void               # SOLE occupancy mutators
func remove(e: Entity) -> void
func move(e: Entity, to: Vector2i) -> void
# Invariant: single occupant per tile. Guarantee: all O(1) except neighbors O(4).
```

### Core

```gdscript
# Movement — reachable() and move() share ONE cost-summation path (preview == billed)
func reachable(state: GameState, unit: Entity) -> Dictionary   # tile -> {min_cost, is_surcharged}
func move(unit: Entity, dest: Vector2i) -> MoveResult          # atomic: path+afford → spend+occupy
```
```gdscript
# Combat — preview_damage() EXACTLY equals hp removed on commit
func legal_targets(unit: Entity) -> Array[Target]
func legal_targets(unit: Entity, from_tile: Vector2i) -> Array[Target]   # hypothetical overload
func preview_damage(attacker: Entity, target: Target) -> int
func attack(attacker: Entity, target: Target) -> AttackResult            # atomic; via apply_action
func blocked_reason(unit: Entity, tile: Vector2i) -> int  # enum by_friendly|out_of_range|dead_zone
```
```gdscript
# Base & Production
func legal_build_tiles(player: int, structure_type: int) -> Array[Vector2i]
func legal_deploy_tiles(producer: Entity, unit_type: int) -> Array[Vector2i]
func completed_outpost_count(player: int) -> int         # Economy Outposts only; 0 not null
func build(player, structure_type, tile) -> BuildResult
func produce(producer, unit_type, tile) -> ProduceResult
func cancel_build(structure: Entity) -> CancelResult      # Under-Construction only; refund via AP
```
```gdscript
# Research / Tech
func legal_research_targets(lab: Entity) -> Array[int]    # excludes Completed + in-progress-elsewhere
func start_research(lab: Entity, tech: int) -> ResearchResult
func cancel_research(lab: Entity) -> CancelResult
func has_attack_tech(p) -> bool ; func has_defense_tech(p) -> bool ; func has_economy_tech(p) -> bool
```

### Feature

```gdscript
# AI Opponent — headless; must not touch render/UI
func take_turn(state: GameState) -> void   # loops: clone → enumerate → score → apply_action → repeat
# Invariant: reads ONLY via approved query set (reachable/legal_targets/preview_damage/can_afford/
#   legal_build_tiles/legal_deploy_tiles/completed_outpost_count/legal_research_targets). Deterministic.
```
```gdscript
# Faction Identity — cross-cutting effective_X folds; no-op under Neutral (all Δ=0)
func effective_produce_cost(base: int, player: int) -> int        # max(1, base+Δ)
func effective_move_cost(base: int, player: int) -> int           # max(MIN_MOVE_COST, base+Δ)
func effective_ap_income(player: int) -> int                      # folds Δ; floored BASE_INCOME_FLOOR
func effective_production_cap(base_cap: int, player: int) -> int  # base≥1→max(1,..); base==0→ALWAYS 0
func effective_build_cost/build_time/research_cost/research_time(base, player) -> int
func tech_available(tech: int, player: int) -> bool               # AND-gate, not a clamp
func faction_of(player) -> FactionDef ; faction_hue ; faction_pattern_id
# Invariant: effective_X(base, player) == base exactly when player is Neutral (TR-faction-011).
#   effective_production_cap MUST branch on base_cap sign (not a single max() clamp) — TR-faction-006.
```

### Presentation (leaf contracts)

```gdscript
# Command & Action Interface — emits one signal, commits via apply_action, holds NO balance constants
signal selection_changed(entity: Entity, mode: int)      # mode: pinned | peek  (→ HUD only)
# Board Renderer — the iso seam
func grid_to_screen(tile: Vector2i) -> Vector2            # ⚠️ 2:1 dimetric (HIGH)
func screen_to_grid(px: Vector2) -> Vector2i              # ⚠️ inverse hit-test + depth resolve (HIGH)
# Game HUD — binds via GameStateReader facade (getters only); zero downstream dependents
```

### Cross-system hard constraints (must hold at the boundary)

- `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` — Command Interface ↔ HUD (TR-cmdui-022 / TR-hud-008). Candidate CI lint check.
- `min_range ≤ attack_range` — Combat schema invariant, validated at data-load (TR-combat-011).
- `move_cost ≥ 1`, `soft_move_cap ≥ 0` — Unit schema, validated at load (TR-movement-012).

⚠️ **Engine-type flags:** `Vector2i`/`Vector2`/`RefCounted`/`Signal`/`Resource` confirmed present and
unchanged in Godot 4.6. Only the Board Renderer iso transforms (custom math) and dual-focus focus-grab
calls need runtime verification.

## ADR Audit

**ADR Quality Check:** `docs/architecture/` contains **zero ADRs** (only `tr-registry.yaml`
skeleton + change-impact reports). Technical Setup just began — there is nothing to audit for
engine-compatibility, version, or conflicts. The audit table is empty by construction.

**Traceability Coverage:** 200 TRs across 12 GDDs → **0 covered, 200 gaps** (expected — no ADRs
exist). Phase 6 folds all 200 into a minimal, complete set of 16 ADRs; every TR maps to exactly one.
**Coverage: 200 / 200 mapped, zero orphans.**

## Required ADRs

All 16 are new. The two ⚠️HIGH-risk ADRs (0013, 0014) must have their engine assumptions
WebSearch-verified before they are moved to Accepted.

### 🔴 Must have before ANY coding starts (Foundation)

| ADR | Title | Covers |
|-----|-------|--------|
| **ADR-0001** | State model ownership & lifecycle (RefCounted-not-Node, `clone()`, headless) — **resolves open blocker TR-gamestate-019** | gamestate-001..003/011/014..017/019, grid-005/006 |
| **ADR-0002** | Action / `apply_action` command model (atomicity, validation, idempotency-by-revalidation, Result types) | gamestate-004/005/010/018; atomic-commit for movement/combat/base/research |
| **ADR-0003** | Deterministic simulation & RNG isolation (no engine RNG in transitions; integer-only state; seeded RNG only in map-gen) | gamestate-008/009, apecon-013, grid-009, combat-013, movement-006/007 |
| **ADR-0004** | Event/signal architecture (typed signals vs aggregate bus; state→presentation decoupling; redraw coalescing) | gamestate-012, hud-001/002/023 |
| **ADR-0005** | Grid representation & map-definition format (flat array, occupancy-separate, map-def asset schema, procedural-gen + reachability validator) | grid-001..004/007/009..014 |
| **ADR-0006** | AP economy data model & spend contract (single pool, `spend`/`can_afford`, income snapshot, data-driven coefficients) | apecon-001..012/014 |
| **ADR-0007** | Data-driven entity/stat schema as Resources (`UnitStats`, structure/tech templates, `entities.yaml`, static typing, test injectability) | unit-001/002/014, combat-010/011, baseprod-001, research-001/002 |
| **ADR-0008** | Shared start-of-turn sequencing (canonical 4-step; timers before income snapshot; flag resets) | gamestate-006/007, apecon-004, baseprod-006/009, research-007 |

### 🟡 Should have before the relevant system is built

| ADR | Title | Covers |
|-----|-------|--------|
| **ADR-0009** | Reachable-search / pathfinding strategy (hand-rolled BFS, flat visited array, no `AStarGrid2D`, fixed-point penalty, alloc + perf budget) | movement-001..014 |
| **ADR-0010** | Combat resolution & shared destruction/win-check hook (damage formula, cover-immunity, counter, same-step destruction, Lab-revert, HQ win) | combat-001..009/012/014, baseprod-010..012, research-008, gamestate-010 |
| **ADR-0011** | AI query-façade & headless decision loop (DI façade, clone-loop, rejection handling, 15 knobs, cross-knob invariant validation, perf budget) | ai-001..017 |
| **ADR-0012** | Faction `effective_X` cross-cutting fold pattern (injection sites, Neutral no-op, cap-0 sign-branch, `FactionDef` schema, orphan handling) | faction-001..015, unit-011, apecon-012 |
| **ADR-0013** ⚠️HIGH | Isometric board rendering, picking & overlays (grid→screen 2:1, inverse hit-test, depth-sort, iso overlays, glyph anchoring) | grid-008, cmdui-003/004/016/017, hud-010/011 |
| **ADR-0014** ⚠️HIGH | Input & focus architecture (dual-focus, `BoardCursor`, hover/cursor precedence, keyboard/gamepad reachability) | cmdui-018..024, hud-022 |
| **ADR-0015** | Command FSM & preview-query tiering (FSM states, 4-tier query caching, tile-change gating, pass-through invariant) | cmdui-001/002/005..015 |
| **ADR-0016** | HUD read-facade, animation & audio priority (`GameStateReader` facade, AP-anim FSM, action-log ring, audio priority order) | hud-003..009/012..021 |

### 🟢 Can defer to implementation
- Save/load serialization format (deferred to Alpha with Persistence & Campaign)
- Specific overlay shader / hatch-rendering technique (within ADR-0013's frame)

## Architecture Principles

1. **The state model is the source of truth; rendering is a pure consumer.** Game logic is plain,
   statically-typed GDScript (`RefCounted`/`Resource`), never a `Node`. Presentation reads via
   facades and reacts to signals — it never owns or mutates authoritative state. This is what makes
   the game headless-simulatable and testable, and it is non-negotiable.
2. **One mutation vector, one resource pool.** All state change flows through `apply_action`
   (atomic, validated, win-checked); all AP change flows through `AP.spend`. No system writes another
   system's fields. This upholds Pillar 1 (One Economy, Every Choice) at the code level.
3. **Determinism is a correctness property, not a nicety.** No engine RNG in state transitions;
   integers over floats; pinned iteration order; the only seeded randomness is map generation at
   load. Identical state + identical actions → byte-identical result. AI lookahead and automated
   tests both depend on this (Pillar 2).
4. **Gameplay values are data, computed live.** Stats, costs, and coefficients live in external
   Resources, never as code literals; tech buffs and faction deltas are folded at read-time
   (`effective_X`), never baked at construction — so a mid-game change takes effect immediately.
5. **Preview equals commitment.** Every previewed number (`reachable` cost, `preview_damage`,
   `projected_remaining_ap`) is computed by the same code path that later commits it. The readable
   board (Pillar 3) is a lie if the preview can disagree with the result.

## Open Questions

| ID | Summary | Priority | Resolution path |
|----|---------|----------|-----------------|
| QQ-01 | State-model location: Autoload singleton vs. passed object vs. event-bus core (GDD-flagged blocker TR-gamestate-019) | High | ADR-0001 |
| QQ-02 | Event architecture: typed signals vs. single aggregate `state_changed` diff | High | ADR-0004 |
| QQ-03 | ✅ *Verified 2026-07-23:* engine `local_to_map()` is buggy for iso ([GH#89423](https://github.com/godotengine/godot/issues/89423)) → custom inverse-projection is mandatory. Remaining work: pin the projection/depth-sort math | Medium | ADR-0013 |
| QQ-04 | ✅ *Verified 2026-07-23:* Godot 4.6 dual-focus present ([4.6 notes](https://godotengine.org/releases/4.6/)); Redot 4.x API-compatible. Residual: ClassDB-check `grab_click_focus` signature at impl | Low | ADR-0014 |
| QQ-05 | `reachable()` performance budget (ms/call on 24×24) — interactive + AI-repeat; drives alloc strategy | Medium | ADR-0009 (perf-analyst spike) |
| QQ-06 | AI evaluate→commit wall-clock budget (~O(N²·W·H)); incremental enumeration vs accepted stall ceiling | Medium | ADR-0011 (perf-analyst spike) |
| QQ-07 | `LETHAL_FLOOR_BONUS` > uncapped economy-ceiling cross-knob invariant has no automated check | Medium | ADR-0011 (startup assertion) |
| QQ-08 | `duplicate_deep()` (4.5) exact signature/behaviour for nested-Resource `clone()` | Low | ADR-0001 (verify at impl) |
| QQ-09 | Faction `effective_X` additive contracts owed to 5 upstream GDDs (no-op under Neutral, deferrable) | Low | ADR-0012 / `/propagate-design-change` |
