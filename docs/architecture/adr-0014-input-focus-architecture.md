# ADR-0014: Input & Focus Architecture (Board Cursor, Dual-Focus, Input Lock)

## Status
Accepted

> ⚠️ **HIGH engine risk, per architecture.md's own flag** (one of the two ADRs — 0013, 0014 —
> architecture.md named as requiring WebSearch verification before Accepted). The load-bearing
> residual item — "confirm Redot 26.2 inherited Godot 4.6's dual-focus behavior unmodified"
> (OQ-6/TR-cmdui-021) — is **already verified**: `game-hud.md`'s 2026-07-22 review did a direct
> `ClassDB` introspection of the `Redot Engine LTS v26.2.stable` binary and confirmed
> `grab_click_focus()`/`grab_focus()`, `gui_get_hovered_control()`/`gui_get_focus_owner()`, and
> distinct `focus`/`hover` `StyleBox` slots are all present. This ADR formalizes that finding into
> an accepted architectural fact (rather than a GDD-embedded spot-check) and adds the one genuinely
> new piece of engine reasoning this ADR needs: how `BoardCursor` keyboard/gamepad input and native
> `Control` focus traversal share the same input actions without colliding — confirmed by the
> godot-specialist validation pass (§5.5), and now independently spiked live.
>
> **Engine spike CLEARED 2026-07-25 (user, windowed Redot session, PASS).** All checks confirmed:
> a focused `Button` eats arrow keys via `focus_neighbor` traversal; `BoardCursor` moves when no
> `Control` holds focus; a `Control` holding keyboard-focus-only still intercepts; the genuine
> unknown — a `Control` holding mouse-hover-focus-only — correctly does **not** intercept arrow
> keys; and `Control.FOCUS_CLICK` is skipped by keyboard/gamepad traversal as expected. **ACCEPTED
> 2026-07-25** as part of the bottom-up 18-ADR Accept batch.

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Input / UI (Control focus) |
| **Knowledge Risk** | HIGH per architecture.md's flag, downgraded to LOW residual — the dual-focus API surface this ADR depends on was already confirmed present via direct `ClassDB` binary introspection (`game-hud.md`, 2026-07-22). The one previously-unverified piece — Godot's input-consumption order (Control focus vs. `_unhandled_input`) — is now **CLEARED 2026-07-25 (PASS)**, see Status and Validation Criteria. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/game-hud.md` (Input notes, OQ-5 resolution — the ClassDB check); `design/gdd/command-action-interface.md` (Input mapping, OQ-6); `docs/architecture/adr-0005-grid-representation-map-format.md`, `docs/architecture/adr-0013-isometric-board-rendering.md` |
| **Post-Cutoff APIs Used** | `Control.grab_click_focus()` (4.6, mouse-click focus, distinct from `grab_focus()`); dual-focus `focus`/`hover` `StyleBox` theme slots (4.6); optionally the 4.5 "recursive Control disable" feature for inert-container suppression (its exact property identifier is not confirmed against this project's engine-reference corpus — named as a possibility, not relied upon; see §6). None are deprecated (`deprecated-apis.md` clean for this domain). |
| **Verification Required** | Engine spike (arrow-key routing between focused-`Control` `focus_neighbor` traversal and `_unhandled_input`-driven `BoardCursor`, plus `Control.FOCUS_CLICK` suppression semantics) — see Validation Criteria. **CLEARED 2026-07-25 (PASS)** — see Status. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (`GridState.in_bounds` — `BoardCursor.step()`'s bounds check), ADR-0013 (`BoardRenderer.grid_to_screen()`/`screen_to_grid()`/`pick_at()` — mouse-hover tile resolution and the board cursor's on-screen anchor), ADR-0006 (`gameplay_config_storage` — the config-Resource convention this ADR's `InputConfig` follows) |
| **Enables** | ADR-0015 (Command & Action Interface's FSM consumes `BoardCursor`, the active-locus precedence rule, and the `input_locked` flag as its input-routing substrate — this ADR supplies the primitives, 0015 wires the concrete FSM Node), ADR-0016 (Game HUD wires its four interactive controls per this ADR's dual-focus conventions, and must close the forward-declared `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant once `HUDConfig` exists) |
| **Blocks** | Command & Action Interface epic's input-handling stories (board-cursor movement, cycle/jump, commit-lock gating); Game HUD epic's focus-wiring stories (Build/End Turn/breakdown-toggle/action-log) |
| **Ordering Note** | Lands after ADR-0013 (consumes its transform/picking) and before ADR-0015 (which consumes this ADR's `BoardCursor`/precedence/lock primitives to build the concrete FSM). Not a hard blocker on ADR-0012 (Faction) or ADR-0016 beyond the one forward-declared invariant — no other overlap. |

## Context

### Problem Statement
Two authored GDDs defer the same unresolved architecture question in different words.
`command-action-interface.md` (OQ-6) names three distinct "focus" concepts a tactics board
actually needs — mouse-hover, a custom `BoardCursor` (explicitly *not* a Godot `Control` focus
concept), and native `Control` keyboard-focus on menu widgets — and asks how the second and third
compose without colliding, plus whether Redot 26.2 kept Godot 4.6's dual-focus behavior intact.
`game-hud.md` (OQ-5) independently confirms the dual-focus *API* exists (via a direct `ClassDB`
binary check) but leaves the *keyboard traversal order* across its own controls to `/ux-design` and
assumes this ADR settles the underlying mechanism. Neither GDD, nor any ADR so far, defines: (1) what
`BoardCursor` concretely is, (2) how arrow-key/gamepad input is routed to it vs. to a focused menu
`Control` without dual-binding or manual arbitration code, (3) how mouse-hover and `BoardCursor`
resolve disagreement (the GDD's "most-recently-moved wins" rule is stated but not implemented), and
(4) what mechanism actually backs `INPUT_LOCK_MS` (explicitly *not* the correctness guarantee —
that's structural — but a real post-commit UX debounce that still needs a concrete timer).

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- No hover-only interactions (`technical-preferences.md`): every board-space and menu interaction
  reachable by mouse must also be reachable by keyboard/gamepad (TR-cmdui-024).
- `BoardCursor` must not be a Godot `Control` — a free grid cursor over a `TileMapLayer`-backed
  board is not what `Control`'s focus-neighbor system is built for (command-action-interface.md,
  Input mapping).
- Must reuse ADR-0013's `grid_to_screen`/`screen_to_grid`/`pick_at` for all screen-space math —
  this ADR introduces no second coordinate transform (Architecture Principle 5 / the
  `local_to_map_for_iso_picking` forbidden pattern's spirit extends to any new picking-adjacent code).
- Must not duplicate `INPUT_LOCK_MS`'s correctness role: the GDD is explicit that single-commit
  safety is already structurally guaranteed (synchronous single-threaded input dispatch + the FSM's
  immediate state transition, ADR-0002/CR-6) — this ADR's lock is a UX debounce only, not a second
  safety mechanism.
- Config values are data-driven, never hardcoded (coding standard) — `INPUT_LOCK_MS` and
  `MENU_KEYBOARD_NAV` must live in an inspector-editable Resource, per the established
  `gameplay_config_storage` convention (ADR-0006).

### Requirements
- A headless, unit-testable `BoardCursor` construct: a `Vector2i` grid position, steppable by
  cardinal direction (grid axes, never screen axes — TR-cmdui-019), and jumpable to the next
  "salient" tile in a caller-supplied candidate set (TR-cmdui-019).
- A precedence rule resolving mouse-hover vs. `BoardCursor` disagreement, with no dedicated polling
  or timestamp bookkeeping beyond what the engine's own synchronous input dispatch already gives
  for free (TR-cmdui-020).
- A concrete answer to "how does `BoardCursor` input avoid colliding with `Control` focus
  traversal" that needs no manual arbitration code (TR-cmdui-018, OQ-6).
- A concrete mechanism for the `INPUT_LOCK_MS` post-commit debounce (TR-cmdui-022).
- Confirmation, formalized as an accepted architectural fact, that Redot 26.2's dual-focus API
  matches Godot 4.6 (TR-cmdui-021), and the dual-focus conventions (`grab_click_focus`/`grab_focus`,
  focus/hover `StyleBox`, `focus_mode`) Game HUD's controls must follow (TR-hud-022).

## Decision

### 1. `BoardCursor` — a headless `RefCounted` value object, mirroring the corpus's static-utility shape

```gdscript
# board_cursor.gd
class_name BoardCursor extends RefCounted

var grid_pos: Vector2i = Vector2i.ZERO

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)

## Steps one tile in a grid-axis direction (NEVER a screen-axis direction — TR-cmdui-019).
## Returns false and leaves grid_pos unchanged if the target tile is out of bounds.
func step(direction: Vector2i, grid: GridState) -> bool:
    var target := grid_pos + direction
    if not grid.in_bounds(target):
        return false
    grid_pos = target
    return true

## Jumps to the next tile in `candidates` (the caller's current salient-tile set — the
## reachable() frontier in Move preview, legal_targets in Attack preview, legal tiles in
## Build/Deploy). Deterministic ascending tile-index order (y*GRID_WIDTH+x), wrapping from
## last back to first — matches ADR-0003's nondeterministic_iteration_order forbidden pattern.
## No-op if candidates is empty.
func jump_to_next(candidates: Array[Vector2i], grid: GridState) -> void:
    if candidates.is_empty():
        return
    var sorted_tiles := candidates.duplicate()
    sorted_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        return _tile_index(a, grid) < _tile_index(b, grid))
    var current_index := sorted_tiles.find(grid_pos)
    grid_pos = sorted_tiles[(current_index + 1) % sorted_tiles.size()] if current_index != -1 else sorted_tiles[0]

static func _tile_index(tile: Vector2i, grid: GridState) -> int:
    return tile.y * grid.width + tile.x
```

`BoardCursor` holds no reference to a scene tree, no input-polling of its own, and no game rules —
it is pure grid-space arithmetic, testable with zero mocks (same headless bar ADR-0011 set for
`AI`). **Who calls `step()`/`jump_to_next()` and when — the actual input polling — is owned by
whichever Node drives the Command & Action Interface's input (ADR-0015's FSM Node instantiates and
holds one `BoardCursor`)**, exactly as `AITurnDriver` (a `Node`) owns and calls the headless `AI`
utility (ADR-0011's split). This ADR fixes the primitive; ADR-0015 fixes the concrete owning Node.

**Grid-axis mapping, not screen-axis (TR-cmdui-019).** `NORTH`/`SOUTH`/`EAST`/`WEST` map directly
to the logical grid's own `(x, y)` axes (`ui_up` → `NORTH` → `y - 1`, etc.) — never to the iso
screen's visually-diagonal directions. This is the same "purely view-layer" boundary ADR-0013 drew
for rendering: the 2:1 dimetric projection is a screen-space concern only, and `BoardCursor`
movement, like every other logical-grid operation in this corpus (Movement's BFS, Combat's
manhattan distance), stays entirely in grid space. No transform math appears in this ADR at all.

### 2. Input routing: `BoardCursor` and `Control` focus share input actions; Godot's own consumption order is the arbitration (resolves OQ-6)

The GDD's open question — "how does `BoardCursor` avoid colliding with `Control` keyboard focus,
since both would otherwise want arrow-key input" — has a zero-code answer: **bind `BoardCursor`
stepping to the same `ui_up`/`ui_down`/`ui_left`/`ui_right` actions the menu's `Control` nodes
already consume for `focus_neighbor` traversal, and read them in `_unhandled_input`.**

```gdscript
# on the owning Presentation Node (ADR-0015's FSM Node)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"ui_up"):
        board_cursor.step(BoardCursor.NORTH, state.grid)
        _on_board_locus_moved(board_cursor)
    elif event.is_action_pressed(&"ui_down"):
        board_cursor.step(BoardCursor.SOUTH, state.grid)
        _on_board_locus_moved(board_cursor)
    # ...ui_left / ui_right analogously
    elif event.is_action_pressed(&"board_cursor_cycle"):
        board_cursor.jump_to_next(_current_salient_tiles(), state.grid)
        _on_board_locus_moved(board_cursor)
```

Godot dispatches input top-down through the tree and gives focused `Control`s (and their built-in
focus-neighbor handling) first refusal via `_gui_input`/the GUI input pass — an event a `Control`
consumes is marked handled and **never reaches `_unhandled_input`**. So: when a menu `Control`
currently holds keyboard focus, an arrow-key press is consumed by that `Control`'s
`focus_neighbor_*` traversal and the board-cursor handler above never sees it. When no `Control`
holds focus (every `PREVIEW_*` state — the menu is closed during a live preview per the FSM's own
design), the same keypress reaches `_unhandled_input` and drives `BoardCursor`. **No dual-binding,
no manual "who owns this keypress right now" flag** — the arbitration is a structural consequence
of Godot's own input-consumption order, not code this ADR has to write. `board_cursor_cycle` is a
**dedicated action** (shoulder-button primary), distinct from `ui_focus_next` (Tab), so a future
menu re-authoring that wires `Tab` for `Control` traversal can never accidentally shadow cycle-jump.

### 3. Mouse-hover vs. `BoardCursor` precedence: last-updated wins, no timestamps (TR-cmdui-020)

```gdscript
# fields on the same owning Presentation Node
enum Locus { MOUSE, BOARD_CURSOR }
var active_locus: Locus = Locus.MOUSE
var active_tile: Vector2i

func _on_mouse_moved_to_tile(tile: Vector2i) -> void:   # called on tile-change, not per motion event
    active_tile = tile
    active_locus = Locus.MOUSE

func _on_board_locus_moved(cursor: BoardCursor) -> void:
    active_tile = cursor.grid_pos
    active_locus = Locus.BOARD_CURSOR
```

Because Godot's input dispatch is synchronous and single-threaded, whichever handler runs *last*
is definitionally the most-recently-moved input — there is no race to resolve and no timestamp
comparison needed. The cost/damage readout and D-3 marker (Command & Action Interface's Formulas)
read `active_tile` as their single active locus, exactly per the GDD's rule. `_on_mouse_moved_to_tile`
is called by ADR-0015's tile-change-gated mouse-motion handling (TR-cmdui-005, that ADR's own
scope) — this ADR only fixes the two-field precedence state and its update rule, not the gating logic.

### 4. `INPUT_LOCK_MS`: a UX debounce timer, not a correctness mechanism (TR-cmdui-022)

```gdscript
# on the same owning Presentation Node
var input_locked: bool = false

func _dispatch_commit(action: Action) -> void:
    if input_locked:
        return   # a legal second click landing during the commit-flash/AP-tick window — inert
    input_locked = true
    var result := state.apply_action(action)
    # ...handle result...
    await get_tree().create_timer(InputConfig.input_lock_ms / 1000.0).timeout
    input_locked = false
```

This reuses the `await get_tree().create_timer(...).timeout` idiom ADR-0011's `AITurnDriver`
already established and the godot-specialist already confirmed correct for 4.6 (including that
`create_timer`'s `process_always` parameter defaults to `true`, so the lock timer runs even against
a paused tree — matching ADR-0011's precedent, no pause-stall). **`input_locked`
gates only new commit dispatch** — hover, board-cursor movement, and menu focus traversal remain
fully live during the lock window, per the GDD framing that this is a commit-specific debounce, not
a general input freeze. True single-commit safety remains what ADR-0002/CR-6 already guarantee
structurally (synchronous dispatch + immediate FSM transition); this timer exists only so a second
*legal* click can't land mid-animation, per the GDD's own framing.

### 5. `InputConfig` — a new per-system config Resource, following the established convention

```gdscript
# input_config.gd
class_name InputConfig extends Resource

@export var input_lock_ms: int = 120
@export var menu_keyboard_nav_enabled: bool = true
```

Loaded once by the same thin, logic-free Balance-style Autoload that already loads
`EconomyConfig`/`UnitConfig`/`CombatConfig`/`AIConfig` (`gameplay_config_storage`, ADR-0006) — kept
off `GameState` for the same reason those configs are: it must never be deep-copied by the AI's
clone loop, and it is load-time tuning data, never runtime-mutated (`config_resource_runtime_mutation`,
ADR-0006).

**Forward-declared cross-config invariant (owed to ADR-0016).** The GDD names a hard constraint:
`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` (Game HUD's tick-down animation must finish inside the lock
window, or the commit-flash↔AP-tick sequencing guarantee breaks). `HUDConfig.ap_tick_duration_ms`
does not exist yet — it is Game HUD's (ADR-0016's) to create. This ADR forward-declares the
invariant now, the same way ADR-0006 forward-declared `completed_outpost_count()` for ADR-0007:
**ADR-0016 MUST add a load-time assert** (mirroring `AIConfig`'s `LETHAL_FLOOR_BONUS >
economy_ceiling_score` cross-knob assert, ADR-0011) checking `InputConfig.input_lock_ms >=
HUDConfig.ap_tick_duration_ms`, evaluated after both config Resources are loaded. Until ADR-0016
lands and adds that assert, this invariant is *documented but unenforced* — flagged in Risks below.

### 6. Dual-focus conventions for interactive `Control`s (ratifies game-hud.md's Input notes; resolves TR-hud-022)

`game-hud.md`'s Input notes already specified the correct 4.6 API from a direct `ClassDB` check;
this ADR adopts it verbatim as the project-wide convention for every interactive `Control`
(HUD's Build button, End Turn control, income-breakdown toggle, action-log scroll; the Command &
Action Interface's action-menu verbs):

- **Mouse-click focus** via `grab_click_focus()`; **keyboard/gamepad focus** via `grab_focus()` —
  distinct methods, distinct StyleBoxes (`hover` vs. `focus`) on the default `Theme` — no custom
  focus-ring wiring.
- **Keyboard traversal order** via `focus_neighbor_top/bottom/left/right` (or `focus_next`/
  `focus_previous` for a linear order) — the *specific* order across HUD's three IA zones is a
  `/ux-design` call (game-hud.md OQ-5's remaining sub-item); this ADR fixes only the *mechanism*.
- **Present-but-inert controls** (opponent's Action phase, `GAME_OVER`) set `focus_mode =
  FOCUS_NONE` — never hand-rolled per-frame focus-ring suppression. (The 4.5 "recursive Control
  disable" feature — `breaking-changes.md`, disable mouse/focus across a whole hierarchy — is an
  optional convenience for whole-panel inerting; its exact property name is not confirmed against
  this project's engine-reference corpus, so it is named here only as a possibility, not a
  load-bearing dependency — verify the exact identifier before any story cites it.)
- **`MENU_KEYBOARD_NAV = false`** (`InputConfig.menu_keyboard_nav_enabled`) sets interactive
  `Control`s to `focus_mode = FOCUS_CLICK` rather than `FOCUS_NONE` — mouse click must still
  register even with keyboard/gamepad traversal disabled; only `Tab`/`ui_focus_next`-style
  traversal is suppressed. (Flagged for the godot-specialist pass and the pre-Accepted spike —
  `FOCUS_CLICK`'s exact traversal-suppression behavior is this ADR's one unverified engine claim.)

### Architecture Diagram

```
                    Mouse motion (tile-changed, gated by ADR-0015)      Keyboard/gamepad (ui_up/down/left/right,
                              │                                          board_cursor_cycle)
                              ▼                                                   │
                    BoardRenderer.screen_to_grid()/pick_at()                      ▼
                              │                                          BoardCursor.step()/jump_to_next()
                              │                                          (headless RefCounted, this ADR §1)
                              └──────────────┬───────────────────────────────────┘
                                             ▼
                          active_locus / active_tile (last-updated-wins, this ADR §3)
                                             │
                                             ▼
                     Command & Action Interface FSM (ADR-0015) — reads active_tile for
                     hover-preview target; dispatches commits gated by input_locked (§4)

     Control focus (menu verbs, HUD controls) ── arbitrated for free by Godot's own
     input-consumption order (§2) — a focused Control consumes ui_up/down/left/right
     before BoardCursor's _unhandled_input handler ever sees them.
```

### Key Interfaces

```gdscript
# board_cursor.gd — top-level file, class_name BoardCursor extends RefCounted
var grid_pos: Vector2i
func step(direction: Vector2i, grid: GridState) -> bool
func jump_to_next(candidates: Array[Vector2i], grid: GridState) -> void
const NORTH: Vector2i
const SOUTH: Vector2i
const EAST: Vector2i
const WEST: Vector2i

# input_config.gd — top-level file, class_name InputConfig extends Resource
@export var input_lock_ms: int = 120
@export var menu_keyboard_nav_enabled: bool = true

# Precedence state + input_locked flag: fields owned by ADR-0015's FSM Node (not a
# standalone class this ADR names) — enum Locus{MOUSE, BOARD_CURSOR}, active_locus,
# active_tile, input_locked.
```

## Alternatives Considered

### Alternative A (BoardCursor shape): headless `RefCounted` value object — CHOSEN
- **Pros**: Zero-scene-tree, unit-testable with no mocks (same bar as `AI`/`Movement`/`Combat`);
  mirrors the corpus's established `AI`/`AITurnDriver`-style split (pure logic vs. the Node that
  drives it); no risk of a second Node fielding its own `_unhandled_input` racing the FSM Node's.
- **Cons**: The owning Node (ADR-0015) must remember to call `step()`/`jump_to_next()` explicitly —
  no automatic per-frame update.
- **Rejection Reason**: n/a (chosen).

### Alternative B: `BoardCursor extends Node` with its own `_unhandled_input`
- **Description**: `BoardCursor` polls its own input and updates `grid_pos` autonomously.
- **Pros**: Self-contained; the owning FSM Node doesn't need to forward input to it.
- **Cons**: Two Nodes (`BoardCursor` and the FSM Node) would independently listen for overlapping
  input categories (both care about commit-adjacent state), risking input-order bugs and making the
  "last-updated-wins" precedence rule (§3) harder to reason about, since two Nodes' `_unhandled_input`
  ordering within one frame is tree-order-dependent rather than obviously sequential. Also breaks
  headless testability — a `Node`-based cursor needs a scene tree to test at all.
- **Rejection Reason**: The single-owner input model (one Node reads all input, calls into headless
  helpers) is what keeps precedence and commit-locking reasoning simple; splitting input listening
  across two Nodes reintroduces exactly the ordering ambiguity this ADR's §3 solves for free.

### Alternative C: fully custom focus system, bypassing native `Control` dual-focus
- **Description**: Build a project-specific focus manager for menu widgets instead of using
  `Control.grab_focus()`/`grab_click_focus()`.
- **Pros**: Total control over traversal semantics; no dependency on engine focus internals.
- **Cons**: Reimplements an engine-native, already-confirmed-correct subsystem (dual-focus is
  verified present and correct on Redot 26.2 via direct `ClassDB` check) for no identified benefit;
  forfeits `Control`'s free focus/hover `StyleBox` styling and any future `AccessKit`
  screen-reader integration (4.5+) that rides native `Control` focus.
- **Rejection Reason**: No requirement justifies discarding a verified-correct native subsystem.

### Alternative (precedence): timestamp/frame-delta comparison instead of last-handler-wins
- **Description**: Track a timestamp per input source and compare on read.
- **Cons**: Adds bookkeeping and a `Time`/frame-count dependency for a comparison the engine's own
  synchronous single-threaded dispatch already resolves for free (whichever handler runs later in
  a frame *is* the more recent input, by construction).
- **Rejection Reason**: Solves a problem that doesn't exist given Godot's dispatch model.

### Alternative (cycle order): nearest-tile-first instead of tile-index order
- **Description**: Sort `jump_to_next()`'s candidates by Manhattan distance from the cursor.
- **Pros**: Arguably more intuitive ("jump to the nearest thing").
- **Cons**: A second, novel ordering concept this corpus hasn't used anywhere else; tile-index
  order already satisfies ADR-0003's `nondeterministic_iteration_order` convention with zero new
  concepts and is trivially testable (one fixed sort key, not a distance-from-a-moving-point
  computation re-run on every jump).
- **Rejection Reason**: Rejected per explicit decision this session — consistency with the existing
  deterministic-ordering convention outweighs the marginal UX difference.

### Alternative (config): fold `INPUT_LOCK_MS`/`MENU_KEYBOARD_NAV` into ADR-0015's future `CommandUIConfig`
- **Cons**: Defers this ADR's own knobs to a later ADR that would then have to re-litigate the
  input-lock mechanism this ADR defines, and delays a config Resource existing for values this ADR
  already needs to name concretely (the forward-declared invariant in particular needs a home now).
- **Rejection Reason**: Rejected per explicit decision this session — knobs live with the ADR that
  defines their mechanism, consistent with how every other per-system config (Economy/Unit/Combat/AI)
  is owned by its defining ADR, not a downstream consumer.

## Consequences

### Positive
- The trickiest-sounding part of OQ-6 — "how do `BoardCursor` and `Control` focus share input" —
  resolves to zero arbitration code, using only Godot's existing input-consumption order.
- `BoardCursor` is trivially headless-testable, extending the corpus's "logic stays out of the
  scene tree" discipline into the input layer for the first time.
- Redot 26.2's dual-focus parity graduates from a GDD-embedded spot-check (`game-hud.md`'s ClassDB
  note) into a cited, accepted architectural fact other ADRs (and `/create-stories`) can reference.
- `INPUT_LOCK_MS`'s UX-debounce role is now mechanically concrete (a timer + flag) rather than a
  prose description, removing ambiguity about what ADR-0015's FSM actually needs to build.

### Negative
- `BoardCursor`'s on-screen indicator glyph remains an art-bible gap (both GDDs already named
  this) — this ADR fixes the anchor math (`grid_to_screen(cursor.grid_pos)`, reusing ADR-0013) but
  not the pixels.
- The `FOCUS_CLICK` fallback for `MENU_KEYBOARD_NAV = false` was asserted from documentation and
  is now confirmed live — see Risks.
- The forward-declared `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant has no enforcement code
  until ADR-0016 lands; a default violating it could ship silently in the interim.

### Risks
- **Input-consumption-order claim (§2)** — was asserted from documented Godot input-dispatch
  behavior, not yet spiked live in Redot 26.2. **CLEARED 2026-07-25 (user, windowed session,
  PASS)** — the one-scene spike (one focusable menu `Button` + `BoardCursor` wired per §2) confirmed
  the claim, including both dual-focus-specific asymmetric cases (see Validation Criteria).
- **`Control.FOCUS_CLICK`'s exact traversal-suppression semantics are asserted, not verified** —
  flagged for the same godot-specialist pass. Mitigation: if `FOCUS_CLICK` doesn't behave as
  expected, `MENU_KEYBOARD_NAV = false` can fall back to manually clearing `focus_neighbor_*` on
  affected Controls instead — a fallback that doesn't change this ADR's other decisions.
- **The forward-declared `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant is unenforced until
  ADR-0016** — named explicitly here (§5) so ADR-0016's authoring pass cannot skip adding the
  load-time assert, mirroring how ADR-0006's forward-declarations were later closed by ADR-0007.
- **`board_cursor_cycle`'s physical binding is not yet assigned** (shoulder-button primary,
  keyboard fallback) — an input-map authoring task, not an architecture question, but named so it
  doesn't silently fall through to implementation with no owner.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| command-action-interface.md | TR-cmdui-018: custom `BoardCursor` (`Vector2i` grid pos from input) as keyboard/gamepad nav distinct from `Control` focus; 3 focus states | §1 (`BoardCursor` construct), §2 (input-consumption-order arbitration vs. `Control` focus), §3 (precedence state) — together the three focus states (mouse-hover, `BoardCursor`, menu focus) and their relationships |
| command-action-interface.md | TR-cmdui-019: D-pad cursor stepping maps to grid axes not screen axes; cycle/jump between salient tiles; one-tile-per-press | §1's `step()` (grid-axis constants, one call per `is_action_pressed`) and `jump_to_next()` (deterministic salient-tile cycling) |
| command-action-interface.md | TR-cmdui-020: mouse-hover vs. board-cursor precedence — most-recently-moved source owns active locus | §3 (last-handler-wins precedence, no timestamps) |
| command-action-interface.md | TR-cmdui-021: verify Redot 26.2 inherited Godot 4.6 dual-focus unmodified before relying on it | Status-section note + Engine Compatibility — formalizes `game-hud.md`'s ClassDB-verified finding as an accepted architectural fact |
| command-action-interface.md | TR-cmdui-022: gate destructive input behind synchronous dispatch + immediate FSM transition, `INPUT_LOCK_MS` (120ms); cross-system constraint vs. `AP_TICK_DURATION_MS` | §4 (`input_locked` timer mechanism) + §5 (forward-declared cross-config invariant, owed to ADR-0016) |
| command-action-interface.md | TR-cmdui-024: every core interaction reachable via keyboard/gamepad + mouse; no hover-only | §1–§3 collectively give every board-space interaction a keyboard/gamepad path (`BoardCursor` *is* the hover for non-mouse input, per the GDD's own framing); §6 gives every menu/HUD control the same guarantee via native `Control` focus |
| game-hud.md | TR-hud-022: HUD controls reachable via click + keyboard/gamepad focus, dual-focus `grab_click_focus()`/`grab_focus()` + distinct focus/hover `StyleBox`; inert = `FOCUS_NONE` | §6 (dual-focus conventions ratified project-wide, `FOCUS_NONE` for inert controls, `FOCUS_CLICK` for the `MENU_KEYBOARD_NAV = false` fallback) |

## Performance Implications
- **CPU**: `BoardCursor.step()` is O(1); `jump_to_next()` is O(k log k) in the candidate-set size
  k, which is already bounded by the same `reachable()`/`legal_targets()` budgets ADR-0009/0010
  established (not a new perf surface — k never exceeds an already-budgeted set size). Native
  `Control` focus traversal is engine-internal, negligible.
- **Memory**: `BoardCursor` is a single `Vector2i` field per interface instance; `InputConfig` is
  one small `Resource`, loaded once. No new per-frame allocation.
- **Load Time**: Negligible — one additional config Resource.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Bounds**: `BoardCursor.step()` never sets `grid_pos` outside `[0, GRID_WIDTH) × [0, GRID_HEIGHT)`
  for any direction/starting-position combination.
- **Cycle completeness**: `jump_to_next()` over a fixed candidate set visits every candidate exactly
  once per full cycle, in ascending tile-index order, wrapping from last to first.
- **Precedence**: a scripted sequence (mouse move → key press → mouse move) leaves `active_locus`
  reflecting the last input processed, in dispatch order, with no timestamp comparison in the code.
- **Engine spike**: one scene with a focusable menu `Button` (using `focus_neighbor_*`
  for arrow-key traversal) and `BoardCursor` wired per §2 — confirm arrow keys drive the `Button`'s
  focus traversal when it holds focus, and drive `BoardCursor.step()` when no `Control` holds focus,
  with no double-handling in either case. **Test the dual-focus-specific asymmetric cases explicitly**
  (godot-specialist, 2026-07-24): the reference docs confirm the pre-4.6 propagation order but say
  nothing about how 4.6's mouse-vs-keyboard focus *split* interacts with `focus_neighbor_*`
  consumption — so the spike must specifically exercise (a) a `Control` holding *keyboard/gamepad
  focus only* (via `grab_focus()`, never mouse-clicked) — does it still intercept `ui_up` before
  `_unhandled_input`? and (b) a `Control` holding *mouse-hover focus only* — does it wrongly also
  intercept the arrow key? These two cases, not the single-focus case, are where 4.6 behavior could
  diverge from training-data assumptions. Also confirm `Control.FOCUS_CLICK` suppresses keyboard/
  gamepad traversal while still allowing mouse-click focus, for the `MENU_KEYBOARD_NAV = false` path.
  **CLEARED 2026-07-25 (user, windowed session, PASS)** — all cases confirmed, including both
  asymmetric cases (a) and (b); (b) — mouse-hover-only — correctly does not intercept.
- **Dual-focus parity (residual sanity check, not fresh research)**: re-confirm
  `grab_click_focus()`/`grab_focus()`, `gui_get_hovered_control()`/`gui_get_focus_owner()`, and the
  `focus`/`hover` `StyleBox` slots exist and behave as `game-hud.md`'s 2026-07-22 `ClassDB` check found.

## Related Decisions
- ADR-0005: Grid representation (`GridState.in_bounds` — `BoardCursor.step()`'s bounds check;
  the grid's own `(x, y)` axes are what `BoardCursor` moves along, never a screen axis)
- ADR-0006: AP economy data model (`gameplay_config_storage` — the config-Resource convention
  `InputConfig` follows; the cross-knob-invariant-at-load pattern `INPUT_LOCK_MS ≥
  AP_TICK_DURATION_MS` reuses from `AIConfig`)
- ADR-0011: AI opponent decision loop (the pure-logic/driving-Node split `BoardCursor`/owning-Node
  mirrors; the `await get_tree().create_timer(...).timeout` idiom `input_locked` reuses)
- ADR-0013: Isometric board rendering (`grid_to_screen`/`screen_to_grid`/`pick_at` — this ADR's
  mouse-hover resolution and `BoardCursor`'s on-screen anchor both consume these, never re-deriving
  iso math)
- `design/gdd/command-action-interface.md` OQ-6 (the question this ADR resolves) and Input mapping
  section (the three-focus-states framing and precedence rule this ADR implements)
- `design/gdd/game-hud.md` OQ-5 (the dual-focus API confirmation this ADR formalizes) and Input
  notes (the `grab_click_focus`/`grab_focus`/`focus_neighbor_*` conventions this ADR ratifies
  project-wide)
