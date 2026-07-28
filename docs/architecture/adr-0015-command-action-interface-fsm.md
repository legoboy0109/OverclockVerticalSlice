# ADR-0015: Command & Action Interface FSM (State Machine, Recompute Tiers, Commit Routing)

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Input / UI (FSM + preview/commit orchestration) |
| **Knowledge Risk** | MEDIUM — the FSM core is pure GDScript logic (no engine API). The engine-touching parts (mouse-motion tile-change gating, the Cancel-Build hold timer, subscribing to `action_applied`) all consume surfaces ADR-0013 (`pick_at`) and ADR-0014 (`BoardCursor`, `input_locked`) already define and validate; this ADR introduces no new post-cutoff API of its own. The two HIGH-risk items in this cluster (iso picking, dual-focus input order) live in ADR-0013/0014 and are gated there. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `modules/ui.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/command-action-interface.md` (full); `design/gdd/game-hud.md` (the #9↔#10 shared-signal seam); `docs/architecture/adr-0002-apply-action-command-model.md`, `adr-0004-event-signal-architecture.md`, `adr-0009-reachable-search-pathfinding.md`, `adr-0010-combat-resolution-destruction-wincheck.md`, `adr-0013-isometric-board-rendering.md`, `adr-0014-input-focus-architecture.md` |
| **Post-Cutoff APIs Used** | None new. The Cancel-Build hold is a `_process`-delta accumulator + `Input.is_action_pressed` poll (both stable ≤4.3, chosen over `create_timer` for free early-release detection — §2); the `input_locked` debounce reuses ADR-0014's `await get_tree().create_timer().timeout` (stable since 4.0). `InputEventMouseMotion`/`event.position` handling is unchanged since ≤4.3 and unaffected by the 4.6 dual-focus split (that changes `Control` focus routing only, not raw event delivery to a plain `Node`). |
| **Verification Required** | None net-new — inherits ADR-0013's picking spike and ADR-0014's input-order/dual-focus spike as prerequisites (both must pass before this ADR's consuming code is trustworthy). This ADR's own logic is Logic-typed and covered by unit tests, not an engine spike. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState` read API — `active_player`, `match_status`, `entities()`, `entity_at()`, the selected entity), ADR-0002 (`apply_action`/`ActionResult` — the sole commit vector this FSM routes through, and the accept/reject it reacts to for Tier-4), ADR-0004 (`action_applied` signal — the board-change re-issue trigger, the commit-flash shared event, and how a `GameOver` transition is observed), ADR-0006 (`AP.can_afford`/`current_ap`/`income` — affordability + `projected_remaining_ap`), ADR-0009 (`Movement.reachable` — Tier-1 move set with `is_surcharged`), ADR-0010 (`Combat.legal_targets`/`legal_targets_from`/`preview_damage`/`blocked_reason` — Tier-1 attack set + D-3 hypothetical), ADR-0013 (`BoardRenderer.pick_at`/`grid_to_screen`/`set_overlay`/`clear_overlay` — picking + overlay render), ADR-0014 (`BoardCursor`, the active-locus precedence, `input_locked`, and `InputConfig` — the input substrate; this ADR **adds one field** to `InputConfig`) |
| **Enables** | Command & Action Interface epic implementation (this ADR is the last architectural gate on it). No downstream ADR *depends* on it — it is a leaf Presentation system (command-action-interface.md: "Downstream dependents: None"). |
| **Blocks** | Every Command & Action Interface story (selection, menu, preview, commit, cancel, End Turn, the four recompute tiers). |
| **Ordering Note** | Lands after ADR-0013 (consumes `pick_at`/overlays) and ADR-0014 (consumes `BoardCursor`/`input_locked`/`InputConfig`). Coordinates with — but does not block — ADR-0016 (Game HUD): the commit-flash (this ADR) and the AP-tick (ADR-0016) both subscribe to ADR-0004's one `action_applied` signal; the `projected_remaining_ap` *number* this ADR produces renders on the HUD's *counter* (ADR-0016). The `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant ADR-0014 forward-declared is enforced by ADR-0016 at load. |

## Context

### Problem Statement
`command-action-interface.md` is the pre-commit action layer for every AP-costed action — the
select → preview → confirm loop the whole game routes through. It is fully designed (35 ACs, an
explicit States table, the four-tier CR-10 recompute rules, the Pass-Through Invariant), but every
one of those is stated as *design intent*, not architecture. Concretely unresolved: (1) the FSM's
concrete shape and how its many Logic-typed ACs stay unit-testable; (2) the CR-6a destructive
Cancel-Build gesture's mechanism, constrained by the GDD to a bounded sub-condition inside
`ENTITY_SELECTED` that a double-click can't produce; (3) the four-tier query strategy — when each
of `reachable()`/`legal_targets()`/the D-3 frontier batch/the hover read/the commit re-validation
actually fires, and where the held sets live; (4) how the Pass-Through Invariant (zero balance
constants in this layer) is structurally enforced, not just asserted; (5) how the interface consumes
each dependency's query/commit surface; (6) how the commit-flash this system owns fires off the
*same* `apply_action`-result event as Game HUD's AP-tick, "synced within one frame" — the GDD's
named highest-desync-risk item.

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- **Pass-Through Invariant (CR-2, TR-cmdui-010)**: this layer owns *no* cost/damage/legality/AP math
  and holds *zero* copies of any owning-system balance constant. Every displayed value is the literal
  return of an owning-system query, evaluated at render time.
- **No hover-only interactions** (`technical-preferences.md`, TR-cmdui-024): every interaction has a
  keyboard/gamepad path — satisfied by consuming ADR-0014's `BoardCursor` (the cursor position *is*
  the hover for non-mouse input) and native `Control` focus for the menu.
- **Single mutation vector**: the FSM commits *only* via `GameState.apply_action` (ADR-0002); it
  never writes state, never deducts AP, never re-validates legality itself (Tier-4 re-validation
  happens *inside* the owning system's `apply_action`, and the FSM only reacts to the result).
- **All queries are side-effect-free** (a contract owed by the dependencies, ADR-0009/0010/0006) —
  so the FSM may re-issue them freely on board-change without perturbing state.
- Board-change is defined against the **logical** `GameState` model, never scene-tree node presence
  (command-action-interface.md's hard implementation constraint).

### Requirements
- An explicit 7-state FSM with a terminal, no-return `GAME_OVER` (TR-cmdui-001), whose transition and
  menu-filtering logic is unit-testable headless (satisfies the ~18 Logic-typed ACs).
- A Cancel-Build gesture that is a bounded sub-condition of `ENTITY_SELECTED`, not a new top state,
  and structurally un-producible by a rapid double-click (CR-6a, TR-cmdui-002).
- A concrete four-tier recompute strategy: Tier-1 set queries once per preview entry + per
  board-change; Tier-2 the D-3 `legal_targets(unit, from_tile)` batch once per `PREVIEW_MOVE` entry;
  Tier-3 O(1) hover reads; Tier-4 commit-time re-validation inside the owning `apply_action`
  (TR-cmdui-006/007/008/009).
- Consumption contracts for Movement, Combat, Base & Production, AP Economy, and Turn Manager
  (TR-cmdui-011/012/013/014/015), routing every commit through `apply_action`.
- The commit-flash ↔ AP-tick single-shared-event wiring (TR-cmdui-023).

## Decision

### 1. Split shape: a pure headless `CommandFSM` core + a `CommandInterface` Node

Mirrors the corpus's established pure-logic/driving-Node split (`AI`/`AITurnDriver`, ADR-0011):

```gdscript
# command_fsm.gd — headless, no scene tree, unit-testable with zero mocks
class_name CommandFSM extends RefCounted

enum State { IDLE, ENTITY_SELECTED, PREVIEW_MOVE, PREVIEW_ATTACK, PREVIEW_PRODUCE, PREVIEW_BUILD, GAME_OVER }
enum Trigger { SELECT_OWN, SELECT_ENEMY_OR_EMPTY, PICK_MOVE, PICK_ATTACK, PICK_PRODUCE, PICK_BUILD_CMD,
               COMMIT, BACK_OUT, WAIT, END_TURN, OBSERVE_GAME_OVER }

## PURE, TOTAL: the next state given the current state, a trigger, and read-only GameState.
## GAME_OVER is absorbing — once entered, every trigger except a fresh match returns GAME_OVER.
static func next_state(current: State, trigger: Trigger, state: GameState) -> State: ...

## PURE: the CR-4 contextual menu for a selected entity — the list of {verb, enabled, reason}.
## Calls ONLY the owning systems' side-effect-free queries (Movement.reachable, Combat.legal_targets,
## AP.can_afford, BaseProduction.legal_* / production_cap). Holds no balance constant of its own.
static func menu_model(state: GameState, entity: EntityState) -> Array[VerbEntry]: ...

## PURE display derivations (Formulas D-1/D-2/D-3) — each computed EXCLUSIVELY from query returns.
static func projected_remaining_ap(state: GameState, player: int, previewed_cost: int) -> int:
    return AP.current_ap(state, player) - previewed_cost   # D-1: no re-derivation, one subtraction
static func attack_possible_after_move(state: GameState, unit: UnitState, tile: Vector2i,
        reachable_cost: int) -> bool: ...                   # D-3: composes Combat.legal_targets_from + AP.can_afford
```

Everything in `CommandFSM` is a pure function of `GameState` + the owning systems' (also pure)
query returns, so **every Logic-typed AC (AC-1..10, 13..15, 24, 26, 30) tests it headless with no
scene tree** — the same testability bar ADR-0011 set for `AI`. `menu_model` is the structural
enforcement of the Pass-Through Invariant (§4): because it can only reach cost/legality data by
*calling a query*, there is nowhere for a hardcoded balance constant to live.

```gdscript
# command_interface.gd — the Presentation Node that drives the pure core
class_name CommandInterface extends Node

var _fsm_state: CommandFSM.State = CommandFSM.State.IDLE
var _selected_id: int = -1
var _board_cursor: BoardCursor = BoardCursor.new()      # ADR-0014
@onready var _renderer: BoardRenderer = ...             # ADR-0013 (set_overlay/clear_overlay/pick_at/grid_to_screen)
# held recompute sets (Tier-1/Tier-2, §3) — ephemeral view-state, NOT authoritative:
var _reachable: Dictionary = {}                         # Vector2i -> Movement.ReachableTile  (Tier-1/Tier-3)
var _targets: Dictionary = {}                           # Vector2i -> Combat.TargetResult      (Tier-1/Tier-3)
var _after_move_attackable: Dictionary = {}             # Vector2i -> bool                      (Tier-2)
var _input_locked: bool = false                         # ADR-0014 §4 debounce
```

The `CommandInterface` Node owns: input routing (reading `active_locus`/`active_tile` per ADR-0014
§3, and `_renderer.pick_at()` for mouse clicks), overlay rendering (via `_renderer.set_overlay()`),
the `action_applied` subscription (§3/§6), and commit dispatch (§5). It holds the ephemeral
recompute sets and the FSM's *current* state, but delegates every *decision* (what state comes next,
what the menu contains, what a tile's preview value is) to the pure `CommandFSM`.

### 2. The FSM: 7 states, terminal `GAME_OVER`, Cancel-Build as an in-state hold sub-condition

The States table transcribes command-action-interface.md's own table directly — this ADR does not
invent transitions, it formalizes the GDD's. The two structural commitments:

**`GAME_OVER` is absorbing (TR-cmdui-001).** `next_state()` returns `GAME_OVER` for any trigger once
in `GAME_OVER`. The Node enters it the moment it *observes* `match_status == GameOver` in its
`action_applied` handler — **whether or not this instance's own commit caused the win-check**
(TR-cmdui-015). Because both players' `CommandInterface` instances subscribe to the same
`GameState.action_applied` (ADR-0004) and read the same shared `match_status`, the non-committing
instance converges on `GAME_OVER` on the same signal that carries the `GameOverEvent` (ADR-0010's
`run_win_check` sets `match_status` + emits it). No polling; no "who won" bookkeeping.

**Cancel-Build is a hold sub-condition inside `ENTITY_SELECTED`, never a new top state
(TR-cmdui-002, CR-6a).** When an under-construction structure is selected, the menu offers Cancel
Build; committing it requires pressing-and-holding the Cancel-Build affordance for
`InputConfig.cancel_build_hold_ms` (a new knob, §5). Mechanism: while the affordance is held, the
Node accumulates `_cancel_hold_elapsed_ms += delta * 1000.0` in `_process` and polls
`Input.is_action_pressed(&"cancel_build")` for release — chosen over an `await create_timer`
because per-frame polling detects a release-before-threshold abort for free (a bare `create_timer`
await would need extra early-release cancellation logic). This `_process` cost is active **only**
while the hold sub-condition is live (a bounded ~500 ms window, one selected entity) — it is not a
steady-state per-frame cost (see Performance Implications). It is tracked *within* `ENTITY_SELECTED`
— the States table is not amended (satisfying the GDD's binding input-shape constraint). A rapid
double-click cannot produce a sustained hold, so it can never trigger the refund-destroy (the AC-27
race stays inert). Releasing before the threshold aborts with no refund and no state change.

### 3. Four-tier recompute (TR-cmdui-006/007/008/009) — the load-bearing performance contract

| Tier | What | When it fires | Where it lives |
|------|------|---------------|----------------|
| **Tier 1** | `Movement.reachable(state, unit)` (→ `_reachable`) or `Combat.legal_targets(state, unit)` (→ `_targets`) | Once on `PREVIEW_MOVE`/`PREVIEW_ATTACK` entry, **and re-issued whenever `action_applied` fires while a preview is open** (board changed mid-turn — a blocker died, etc.) | Held in the Node's `_reachable`/`_targets` dict for the life of that preview |
| **Tier 2** | `Combat.legal_targets_from(state, unit, from_tile)` batched across **every** tile in the just-computed `reachable()` frontier (→ `_after_move_attackable`) | Once per `PREVIEW_MOVE` entry (and per board-change re-issue) — **not per hover** | Held in `_after_move_attackable` |
| **Tier 3** | A hover read: `_reachable[tile]` / `_targets[tile]` / `_after_move_attackable[tile]` | On every `active_tile` change (mouse tile-change OR board-cursor move) | **O(1) dict lookup** — no query re-run |
| **Tier 4** | Single-option legality re-validation | At the commit click — but **inside** the owning system's `apply_action` (ADR-0002 validate step), *not* a recompute by this FSM | The FSM only reads `ActionResult.ok`; on reject it swallows, re-issues Tier-1, and stays in the menu (Edge Cases) |

**Tile-change gating (TR-cmdui-005).** Raw `InputEventMouseMotion` is *not* acted on per event.
The Node reads motion in the **same `_unhandled_input` tier ADR-0014 established** for board input
(so a focused menu `Control` consumes its events first, and board-space motion is only seen when no
menu widget claims it — consistent with ADR-0014 §2's input-consumption-order arbitration, not a
separate `_input`-tier read that would race the menu). It computes
`_renderer.pick_at(event.position).tile` (or `screen_to_grid` for empty tiles) and
only calls `_on_mouse_moved_to_tile(tile)` (ADR-0014 §3) **when the resolved tile differs from the
last** — so a `PREVIEW_HOVER_LATENCY_MS = 0` sweep across sub-tile pixels fires at most one Tier-3
lookup per tile entered, never a per-motion-event flood. This is the concrete answer to the GDD's
"tile-change-gated, flagged for `/architecture-decision`" note. Board-cursor moves (ADR-0014) are
already one-tile-per-press, so they are inherently tile-gated.

Because the held sets are keyed by `Vector2i`, Tier-3 is a genuine O(1) dictionary read — the FSM
never re-flood-fills `reachable()` on hover, satisfying the GDD's explicit performance guarantee.
The board-change re-issue (Tier-1) is safe precisely because every query is side-effect-free (a
dependency contract, not this FSM's to enforce).

### 4. Pass-Through Invariant enforcement (TR-cmdui-010) — structural, not just stated

Every display value flows through `CommandFSM`'s pure derivations (§1), which reach cost/damage/
legality data **only by calling an owning system's query**. There is no code path in either
`CommandFSM` or `CommandInterface` that references a balance constant (`move_cost`,
`SOFT_MOVE_PENALTY`, `attack_cost`, `COVER_DR`, `CANCEL_REFUND_RATE`, …) by name — the refund shown
for Cancel Build is Base & Production's `cancel_build` preview return, the damage shown is
`Combat.preview_damage`'s return, the surcharge split is `Movement.reachable`'s `is_surcharged` flag
(TR-cmdui-011 — consumed, never inferred from `min_cost`). **A future lint/CI rule (candidate,
per the GDD) greps this layer's two files for any owning-system constant name and fails on a match**
— the same static-allowlist discipline ADR-0011 established for the AI's read set (CR-4). This is
registered as a forbidden pattern so the constraint outlives this ADR.

### 5. Consumption + commit contracts (TR-cmdui-011..015); `InputConfig` gains one field

The interface calls only side-effect-free queries for preview and only `apply_action` for commit —
per the GDD's per-dependency contract table:

- **Movement** (TR-cmdui-011): `reachable(state, unit) -> Array[ReachableTile{tile, min_cost,
  is_surcharged}]` (ADR-0009) for the Tier-1 move set; renders in-cap vs. over-cap from the
  `is_surcharged` flag directly. Commit: a `MoveAction` through `apply_action`.
- **Combat** (TR-cmdui-012): `legal_targets`/`legal_targets_from`/`preview_damage`/`blocked_reason`
  (ADR-0010) for the Tier-1 attack set, the D-3 Tier-2 batch, the exact post-mitigation damage, and
  the three blocked-shot states. Commit: an `AttackAction` through `apply_action`.
- **Base & Production** (TR-cmdui-013): `legal_build_tiles`/`legal_deploy_tiles`/
  `completed_outpost_count`/per-producer `production_cap` (forward-declared by ADR-0011/0006,
  implemented by the B&P epic) for the build/deploy overlays and pickers. Commit: `Build`/`Produce`/
  `CancelBuild` actions through `apply_action`.
- **AP Economy** (TR-cmdui-014): `can_afford`/`current_ap`/`income` (ADR-0006) for affordability
  gating and `projected_remaining_ap` — the FSM never deducts AP (`spend()` runs inside each
  system's `apply()`).
- **Turn Manager / GameState** (TR-cmdui-015): reads `active_player`/`match_status`; routes every
  commit through `apply_action`; input is live **only** during the local player's Action phase
  (the Node ignores input triggers otherwise, staying inspection-only); both instances observe
  `GameOver` (§2).

**`InputConfig` (ADR-0014) gains `cancel_build_hold_ms: int = 500`** — the CR-6a hold threshold.
Adding it here (rather than minting a second config Resource) matches how ADR-0008 added
`starting_player` to ADR-0001's `GameState`: the field's *mechanism* is decided by the ADR that
needs it, appended to the owning Resource. Registered as a `referenced_by` update on
`gameplay_config_storage`, not a new stance.

### 6. Commit-flash ↔ AP-tick: one shared `action_applied` event (TR-cmdui-023 — the named top risk)

The commit flash (this system, #9) and the AP-counter tick-down (Game HUD, #10) must read as *one*
event, "synced within one frame." The mechanism: **both subscribe to ADR-0004's single
`GameState.action_applied(result)` signal** — neither polls for an AP delta, and neither reacts to
the other. This ADR owns the flash: on `action_applied` with `result.ok`, `CommandInterface`
fires the tile/target confirm-flash. ADR-0016 owns the tick off the same signal. Because
`action_applied` fires exactly once per commit, synchronously, at `apply_action` step 7 (ADR-0004),
both animations start on the same frame by construction — the "two independent reactive renders"
failure mode the GDD warns about is designed out, not styled around.

Sequencing across a fast chain is held by ADR-0014's `input_locked` debounce (this ADR reuses it,
§1) plus the `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant (ADR-0014 forward-declared it; ADR-0016
enforces it at load). **Attack commits fire no interface audio from this system** — Combat triggers
its own per-weight-class cue off the same `action_applied` event (command-action-interface.md
Section D / combat GDD), so exactly one system calls `play()` and there is no double-trigger.

### Architecture Diagram

```
   Input (mouse click / motion; BoardCursor keys — ADR-0014)
        │  pick_at()/screen_to_grid() (ADR-0013), active_tile (ADR-0014 §3)
        ▼
   CommandInterface (Node, this ADR) ──── holds _fsm_state, _selected_id, _board_cursor,
        │   │                              _reachable/_targets/_after_move_attackable, _input_locked
        │   │  delegates every DECISION to ↓
        │   ▼
        │  CommandFSM (RefCounted, pure) ── next_state() · menu_model() · D-1/D-2/D-3 derivations
        │        │  calls only side-effect-free queries:
        │        ├─ Movement.reachable (ADR-0009)      ├─ AP.can_afford/current_ap/income (ADR-0006)
        │        ├─ Combat.legal_targets(_from)/preview_damage (ADR-0010)
        │        └─ BaseProduction.legal_build_tiles/legal_deploy_tiles/production_cap (fwd-decl)
        │
        ├─ render:  BoardRenderer.set_overlay()/clear_overlay()/grid_to_screen() (ADR-0013)
        ├─ commit:  GameState.apply_action(action) -> ActionResult (ADR-0002) ── Tier-4 reject → refresh
        └─ subscribe: GameState.action_applied (ADR-0004) ── board-change Tier-1 re-issue;
                       commit-flash (§6, shared with Game HUD's AP-tick); GAME_OVER observation (§2)
```

### Key Interfaces

```gdscript
# command_fsm.gd — top-level file, class_name CommandFSM extends RefCounted
enum State { IDLE, ENTITY_SELECTED, PREVIEW_MOVE, PREVIEW_ATTACK, PREVIEW_PRODUCE, PREVIEW_BUILD, GAME_OVER }
enum Trigger { SELECT_OWN, SELECT_ENEMY_OR_EMPTY, PICK_MOVE, PICK_ATTACK, PICK_PRODUCE, PICK_BUILD_CMD,
               COMMIT, BACK_OUT, WAIT, END_TURN, OBSERVE_GAME_OVER }
static func next_state(current: State, trigger: Trigger, state: GameState) -> State
static func menu_model(state: GameState, entity: EntityState) -> Array[VerbEntry]   # {verb:int, enabled:bool, reason:int}
static func projected_remaining_ap(state: GameState, player: int, previewed_cost: int) -> int
static func attack_possible_after_move(state: GameState, unit: UnitState, tile: Vector2i, reachable_cost: int) -> bool

# command_interface.gd — top-level file, class_name CommandInterface extends Node
#   (holds FSM state, BoardCursor, held recompute sets, input_locked; drives CommandFSM;
#    renders via BoardRenderer; commits via GameState.apply_action; subscribes to action_applied)

# input_config.gd (ADR-0014) gains:
@export var cancel_build_hold_ms: int = 500
```

## Alternatives Considered

### Alternative A (shape): split pure `CommandFSM` core + `CommandInterface` Node — CHOSEN
- **Pros**: The ~18 Logic-typed ACs test the transition table and menu-filtering headless, no scene
  tree; the Pass-Through Invariant becomes structural (the pure core can only reach cost/legality by
  calling a query); mirrors the corpus's `AI`/`AITurnDriver` and Movement/Combat static-core precedent.
- **Cons**: Two files instead of one; the Node must forward triggers into the pure core.
- **Rejection Reason**: n/a (chosen).

### Alternative B: single `CommandInterface` Node holding transitions + rendering + input
- **Description**: One Node owns everything, no separable pure core.
- **Cons**: Every FSM-transition/menu-filter AC becomes Integration-typed (needs a scene tree to
  instantiate the Node) — breaking the "logic stays headless" discipline ADR-0001/0011 established,
  and making the Pass-Through Invariant a matter of code-review vigilance rather than structure.
- **Rejection Reason**: Rejected per explicit decision this session — headless-testability of the
  transition/menu logic is worth the second file.

### Alternative C: FSM state as a Resource; State-pattern handler classes (one class per state)
- **Description**: A base `State` class with 7 subclasses each owning `enter`/`exit`/`handle`.
- **Cons**: 7 states is small; per-state classes are harder to test as one transition table and add
  a class hierarchy the corpus has otherwise avoided (cf. ADR-0007's "no growing subclass
  hierarchy"). A plain `enum State` + pure `next_state()` matches ADR-0002's verb-enum-Dictionary
  dispatch precedent and is trivially table-testable.
- **Rejection Reason**: Rejected per explicit decision this session — enum + pure transition function
  over a class-per-state hierarchy.

### Alternative (Cancel-Build gesture): affordance + separate confirm click
- **Description**: Click to arm, second click on a distinct confirm control to commit.
- **Cons**: Adds a transient armed sub-state and a second UI target; the hold-to-confirm timer is a
  single bounded sequence inside `ENTITY_SELECTED` with no extra control, and is equally
  double-click-proof.
- **Rejection Reason**: Rejected per explicit decision this session — hold-to-confirm timer chosen.

### Alternative (recompute): re-run `reachable()` on every hover instead of holding the Tier-1 set
- **Description**: No held set; each hover recomputes.
- **Cons**: `reachable()` is a BFS/uniform-cost search, not O(1) (ADR-0009); re-running it per
  mouse-motion event at `PREVIEW_HOVER_LATENCY_MS = 0` risks frame hitches — exactly what CR-10 and
  the GDD's tile-change-gating note exist to prevent.
- **Rejection Reason**: Fails the GDD's explicit Tier-3-is-O(1) performance requirement.

## Consequences

### Positive
- The Command & Action Interface's transition and menu-filtering logic — the bulk of its 35 ACs — is
  unit-testable headless, so the interface's correctness is provable before any scene exists.
- The Pass-Through Invariant is enforced by construction (the pure core has no place to hold a
  balance constant) plus a greppable lint, not by reviewer vigilance alone.
- The four recompute tiers are pinned to concrete trigger points, resolving the GDD's flagged
  perf-budget items (Tier-2 fan-out, tile-change gating) with an O(1) hover guarantee.
- The commit-flash ↔ AP-tick desync — the GDD's named top risk — is designed out by routing both
  through ADR-0004's single `action_applied` signal.

### Negative
- The `CommandInterface` Node is scene-tree-coupled and its own input/render behaviors are
  Integration/Visual-Feel-typed (consistent with how the GDD classifies every view-layer AC) — only
  the extracted `CommandFSM` core is Logic-typed.
- The Pass-Through lint is a candidate, not yet a built check — until it exists, the invariant leans
  partly on review discipline (mitigated by the structural pure-core design, which removes the
  *place* a constant would live).
- Cancel-Build's `cancel_build_hold_ms` is an unpinned feel value owed to `/ux-design` (the GDD
  already defers the exact affordance/timing there).

### Risks
- **This ADR inherits ADR-0013's and ADR-0014's pre-Accepted engine spikes as hard prerequisites**
  — its picking (`pick_at`) and input-order (`BoardCursor` vs. `Control` focus) both depend on those
  spikes passing. If either spike disproves its ADR's assumption, this ADR's consuming code changes.
  Mitigation: sequence the spikes (ADR-0013/0014) before implementing this ADR's stories.
- **Board-change Tier-1 re-issue correctness depends on every query being genuinely side-effect-free**
  — a purity contract owed by Movement/Combat/AP (ADR-0009/0010/0006), verified in *their* test
  suites, not black-box-testable from this layer (command-action-interface.md's own caveat).
  Mitigation: the purity obligation is already registered against those systems; this ADR only
  consumes it.
- **The commit-flash ↔ AP-tick single-frame sync requires ADR-0016 to actually subscribe the AP-tick
  to `action_applied`** (not build an independent AP-delta poll) and to enforce `INPUT_LOCK_MS ≥
  AP_TICK_DURATION_MS` at load. Named here so ADR-0016's authoring pass cannot skip it — the same
  cross-ADR handoff discipline ADR-0014 used for the invariant.
- **Signal-connection lifecycle across match restarts** (godot-specialist, 2026-07-24): Godot
  auto-drops connections to freed objects, so a torn-down `CommandInterface` never leaves a dangling
  call — crash-safety is automatic. But *if* `GameState` is reused across a match restart within one
  process (rather than reconstructed), `CommandInterface` must `disconnect` from `action_applied` in
  `_exit_tree()` so connections don't accumulate on the persistent emitter across repeated restarts.
  If each match constructs a fresh `GameState` (the likely VS path — ADR-0001's `GameState` is
  `.new()`-constructed per match), the old connections are moot and no explicit disconnect is needed.
  A one-line implementation guardrail, not an architecture change.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| command-action-interface.md | TR-cmdui-001: explicit FSM (7 states incl. terminal no-return GAME_OVER) | §1 (`CommandFSM.State` enum + pure `next_state`), §2 (absorbing GAME_OVER) |
| command-action-interface.md | TR-cmdui-002: CR-6a Cancel-Build gesture = internal duration-tracked sub-condition in ENTITY_SELECTED, no new top state | §2 (`_cancel_hold_elapsed_ms` hold accumulator inside ENTITY_SELECTED, States table unamended) |
| command-action-interface.md | TR-cmdui-005: tile-change-gate InputEventMouseMotion; PREVIEW_HOVER_LATENCY_MS=0 no debounce | §3 (pick_at→tile, act only on tile change; board-cursor already one-tile-per-press) |
| command-action-interface.md | TR-cmdui-006: Tier-1 reachable()/legal_targets() once per preview entry + per board-change, hold set | §3 Tier-1 (`_reachable`/`_targets` held, re-issued on `action_applied`) |
| command-action-interface.md | TR-cmdui-007: Tier-2 batch legal_targets(unit,from_tile) across reachable frontier once per PREVIEW_MOVE entry | §3 Tier-2 (`_after_move_attackable` batched once per entry) |
| command-action-interface.md | TR-cmdui-008: Tier-3 hover reads O(1) into precomputed sets | §3 Tier-3 (Vector2i-keyed dict lookup, no query re-run) |
| command-action-interface.md | TR-cmdui-009: Tier-4 commit-time re-validation inside owning apply_action; UI reacts; reject → refresh Tier-1, spend 0 | §3 Tier-4 (reads `ActionResult.ok`; reject → re-issue Tier-1, stay in menu) |
| command-action-interface.md | TR-cmdui-010: Pass-Through Invariant — zero balance constants, no local formula re-derive | §1 + §4 (pure `CommandFSM` reaches cost/legality only via queries; greppable lint + forbidden-pattern registration) |
| command-action-interface.md | TR-cmdui-011: consume reachable()→{tile,min_cost,is_surcharged}, render in-cap/over-cap from is_surcharged, never infer | §5 Movement bullet (renders from the `is_surcharged` flag directly) |
| command-action-interface.md | TR-cmdui-012: consume Combat legal_targets/preview_damage/hypothetical overload; call atomic attack() | §5 Combat bullet + §3 Tier-1/Tier-2 |
| command-action-interface.md | TR-cmdui-013: consume B&P legal_build_tiles/legal_deploy_tiles/completed_outpost_count/production_cap; call build/produce/cancel_build | §5 Base & Production bullet |
| command-action-interface.md | TR-cmdui-014: consume AP can_afford/current_ap/income for affordability + projected_remaining_ap; UI never deducts | §5 AP bullet + §1 D-1 derivation |
| command-action-interface.md | TR-cmdui-015: read active_player/phase, route commits via apply_action, scope to active player Action phase; both instances observe GameOver | §5 Turn Manager bullet + §2 (absorbing GAME_OVER observed by both instances via `action_applied`) |
| command-action-interface.md | TR-cmdui-023: commit-flash (this) + AP tick-down (HUD) off single shared apply_action-result event, same frame | §6 (both subscribe to ADR-0004's single `action_applied`; this ADR owns the flash, ADR-0016 the tick) |

## Performance Implications
- **CPU**: Tier-3 hover is O(1) (dict read). Tier-1 `reachable()`/`legal_targets()` fire once per
  preview entry (+ per board-change), bounded by ADR-0009/0010's existing per-call budgets. Tier-2's
  `legal_targets_from` batch is O(|reachable| × candidate targets) once per `PREVIEW_MOVE` entry —
  the GDD's named fan-out item, bounded by the same N≤24 army-size assumption ADR-0011 budgets and
  never re-run per hover. The Node is otherwise event-driven, not `_process`-polled — the **one**
  bounded exception is the Cancel-Build hold sub-condition (§2), which polls `_process` for ~500 ms
  while a single under-construction structure is selected, then stops. Negligible and non-steady-state.
- **Memory**: Three `Vector2i`-keyed dicts sized to one unit's reachable/target frontier — ephemeral,
  cleared on preview exit. No per-tile persistent allocation.
- **Load Time**: Negligible (one added `InputConfig` field).
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Transition table**: `next_state()` is exhaustively table-tested — every (state, trigger) pair
  returns the GDD States-table target; `GAME_OVER` is absorbing for every trigger.
- **Menu filter**: `menu_model()` returns each verb enabled iff `is_legal AND can_afford` per its
  owning query; disabled verbs carry the correct reason; both failure reasons surface when both fail
  (AC-8) — all headless.
- **Pass-Through**: a grep of `command_fsm.gd`/`command_interface.gd` finds zero owning-system
  balance-constant names (the candidate lint); `projected_remaining_ap`/`attack_possible_after_move`
  return values equal to the queries' returns (AC-4/5/11).
- **Tier-3 O(1)**: a hover sweep across the reachable frontier issues zero `reachable()`/
  `legal_targets()` calls after the Tier-1 entry query (spy/counter on the query functions).
- **Tier-4 reject**: a commit on a tile made illegal since preview entry returns `ActionResult.ok ==
  false`, spends 0 AP, and leaves the FSM in the menu with a refreshed overlay (AC-19/20).
- **GAME_OVER convergence**: both a committing and a non-committing `CommandInterface` instance enter
  `GAME_OVER` on the `action_applied` carrying the `GameOverEvent` (AC-34/35).
- **Cancel-Build hold**: a hold ≥ `cancel_build_hold_ms` commits the refund; a bare click and a
  release-before-threshold do not (AC-18).

## Related Decisions
- ADR-0002: apply-action command model (the sole commit vector; the Tier-4 re-validation lives in
  `validate()` inside `apply_action`, which this FSM reacts to but never re-implements)
- ADR-0004: event/signal architecture (`action_applied` — the board-change re-issue trigger, the
  commit-flash shared event, and how `GAME_OVER` is observed by both instances)
- ADR-0009 / ADR-0010 / ADR-0006: the Movement / Combat / AP query surfaces this FSM consumes read-only
- ADR-0013: isometric board rendering (`pick_at`/`grid_to_screen`/`set_overlay` — picking and overlay
  render; this FSM never re-derives iso math)
- ADR-0014: input & focus (`BoardCursor`, active-locus precedence, `input_locked`, `InputConfig` —
  the input substrate; this ADR appends `cancel_build_hold_ms`)
- ADR-0016 (forthcoming): Game HUD (co-subscriber to `action_applied` for the AP-tick; enforces the
  `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant; renders this ADR's `projected_remaining_ap` on its
  counter)
- `design/gdd/command-action-interface.md` — the full design this ADR makes concrete (States table,
  CR-10 four tiers, Pass-Through Invariant, per-dependency contract table)

## Addenda

### 2026-07-28 — `selection_changed` signal implemented (discharges ADR-0016 §6 forward-declaration)

ADR-0016 §6 forward-declared `CommandInterface.selection_changed(target: SelectionTarget)` — the
one-way, outward-in seam the Game HUD's detail panel (TR-hud-013) subscribes to — and noted "a
back-reference should be added to ADR-0015's registry entry." That signal is now **implemented** in
the Command & Action Interface epic (Game HUD Story 006 was blocked on it):

- New type `SelectionTarget` (`src/ui/command_action_interface/selection_target.gd`,
  `class_name SelectionTarget extends RefCounted`) — `{entity_id: int, pinned: bool}`;
  `entity_id == -1` means "no target".
- `CommandInterface` gains `signal selection_changed(target: SelectionTarget)`, emitted through a
  single de-duplicating choke point `_emit_selection(entity_id, pinned)` at every selection-mutation
  point (`try_select` / `enter_preview` → pinned; `_reselect_after_commit` → pinned or cleared;
  `_enter_game_over` → cleared) plus a new `inspect(state, tile)` peek entry point (pinned=false for
  an occupied tile; falls back to the pinned selection for an empty tile). One-way outward-in — the
  interface never calls into a HUD node, preserving the HUD's leaf status (TR-hud-020).
- Tests: `tests/unit/command-action-interface/selection_changed_test.gd` (9, pass). Additive — no
  existing CAI behavior changed (full suite 730/730 green).
