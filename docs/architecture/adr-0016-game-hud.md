# ADR-0016: Game HUD (Read-Only Facade, AP-Counter FSM, Audio Ownership)

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | UI (HUD Control tree, audio dispatch) |
| **Knowledge Risk** | MEDIUM — the HUD is reactive `Control`-tree rendering + a pure animation-state core (no post-cutoff API of its own). Its two engine-adjacent surfaces are the dual-focus `Control` conventions (already validated + gated by ADR-0014) and `AudioStreamPlayer.play()` dispatch (stable ≤4.3). No new HIGH-risk item; the cluster's HIGH-risk items (iso picking, dual-focus input order) live in ADR-0013/0014. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `modules/ui.md`, `modules/audio.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/game-hud.md` (full); `design/gdd/command-action-interface.md` (the #9↔#10 seams); `docs/architecture/adr-0001`, `adr-0002`, `adr-0004`, `adr-0006`, `adr-0008`, `adr-0013`, `adr-0014`, `adr-0015` |
| **Post-Cutoff APIs Used** | None. `AudioStreamPlayer.play()`, `Control` focus (`grab_focus`/`grab_click_focus`, `focus`/`hover` StyleBox, `FOCUS_NONE`), `_process` dirty-flag redraw — all stable ≤4.3 or already validated in ADR-0014. |
| **Verification Required** | None net-new — inherits ADR-0014's dual-focus spike (this ADR's four interactive controls follow those conventions) and ADR-0013's glyph-anchor spike (on-board readouts anchor via `grid_to_screen`). This ADR's own logic (AP-FSM transitions, log ring buffer, pip/numeric branch, audio priority) is Logic-typed and unit-tested, not spiked. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState` read API — `active_player`/`round_number`/`match_status`/`current_ap`/`entities()`/`entity_at`), ADR-0002 (`ActionResult.events` — the log source, one entry per event in resolution order), ADR-0004 (`action_applied` signal — the per-commit trigger the AP-tick/hp-drain/log/commit-flash all ride; the single event surface), ADR-0006 (`ap_income_breakdown`/`can_afford` + `gameplay_config_storage` — the income breakdown, Build affordability, and where `HUDConfig` loads), ADR-0008 (`start_turn` — the start-of-turn signal that drives the fill-flourish + `income_this_turn` snapshot), ADR-0013 (`BoardRenderer.grid_to_screen` — on-board readout anchors, the GLYPH_OFFSETS layer), ADR-0014 (dual-focus `Control` conventions for the four interactive controls; `InputConfig.input_lock_ms` — the other half of the cross-config invariant this ADR enforces), ADR-0015 (`projected_remaining_ap` for the inline echo; `CommandInterface.selection_changed` for the detail panel; the `PREVIEW_BUILD` state for the Build-button pressed cue; the shared `action_applied` commit-flash↔AP-tick contract) |
| **Enables** | Game HUD epic implementation (last architectural gate on it). No downstream ADR depends on it — leaf Presentation system (game-hud.md: "Downstream dependents: None"). |
| **Blocks** | Every Game HUD story (AP counter, income breakdown, turn/banner, action log, detail panel, on-board readouts, victory/defeat, the two controls, audio dispatch). |
| **Ordering Note** | The LAST ADR in the 16-ADR plan and the last of the Presentation cluster (0013/0014/0015/0016). Consumes ADR-0015's `projected_remaining_ap`/`selection_changed`/`PREVIEW_BUILD`; **closes ADR-0014's forward-declared `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant** by creating `HUDConfig` and adding the load-time guard. Forward-declares one signal owed back to ADR-0015 (`CommandInterface.selection_changed`, §6). |

## Context

### Problem Statement
`game-hud.md` is the persistent read-only information layer — AP counter, turn/round + banners,
action log, detail panel, on-board readouts, victory/defeat, and the two hosted controls (Build,
End Turn). It is fully designed but its architecture is unresolved: (1) how the "never mutates game
state" guarantee is made *structural* rather than review-enforced (the GDD asks for a read-only
facade, TR-hud-003); (2) the AP counter's explicit four-state animation FSM and how its Logic-typed
ACs stay testable (TR-hud-005..008); (3) the action log's ring-buffer + one-entry-per-event
ordering (TR-hud-014); (4) the pip-vs-numeric hp branch (TR-hud-012); (5) the detail panel's
outward-in subscription to #9's selection without #9 depending on the HUD (TR-hud-013); (6) the
victory/defeat one-frame preemption (TR-hud-016); (7) the Pass-Through Invariant enforcement
(TR-hud-018); (8) the single-owner audio dispatch + total priority order (TR-hud-021); and (9) where
`HUDConfig` lives and how it closes ADR-0014's forward-declared
`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant (TR-hud-008).

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- **Pure read, never mutates** (CR-1, TR-hud-001): the HUD reads authoritative state and never
  writes it, calls no `apply_action`, holds no game logic.
- **Pass-Through Invariant** (CR-1/Formulas, TR-hud-018): every displayed value is the literal
  return of an owning-system query; the HUD holds zero balance constants. **Carve-out**: retaining
  one frame of *prior displayed value* purely to compute an animation delta (AP tick `N = old−new`,
  hp-pip drain count) is transient presentation state, not an owned balance value — explicitly exempt.
- **HUD is a leaf** (TR-hud-020): it depends on 7 upstream systems + one coordination seam with #9,
  and is depended on by nobody. #9 must never call into a HUD-owned node (TR-hud-013 — the
  outward-in data-flow that protects the leaf claim).
- **No duplication of #9** (CR-11): no selection, previews, action menu, or commit routing here.
- The four interactive controls follow ADR-0014's dual-focus conventions; inert controls use
  `FOCUS_NONE` (TR-hud-022, ADR-0014-owned but honored here).

### Requirements
- A read-only facade making "never mutates" structurally true (TR-hud-003).
- The AP counter's four-state animation FSM (Committed/Fill/Tick/PreviewEcho), opponent-AP muting,
  the turn-transition echo-force-clear race fix, and the GameOver tick-snap (TR-hud-005/006/007/008).
- Turn/round indicator + self-clearing YOUR/ENEMY banner (TR-hud-009).
- Pip-vs-numeric hp branch on `PIP_MAX_HP` (TR-hud-012).
- Detail panel following #9's selection via an outward-in signal (TR-hud-013).
- Action-log ring buffer, one entry per event, deterministic order (TR-hud-014).
- Build-button live affordability + PREVIEW_BUILD pressed cue (TR-hud-015).
- Victory/defeat one-frame preemption of the banner (TR-hud-016).
- Turn-scoped inert controls (TR-hud-017).
- The 7-system read binding + leaf status (TR-hud-020).
- Single-owner audio with the total priority order + ducking (TR-hud-021).
- `HUDConfig` + the cross-config invariant enforcement (TR-hud-008 half).

## Decision

### 1. Read-only facade: `GameStateReader` (TR-hud-003) — never-mutates is structural, not reviewed

```gdscript
# game_state_reader.gd — the ONLY handle HUD scripts get on game state
class_name GameStateReader extends RefCounted

var _state: GameState   # private; never exposed

func _init(state: GameState) -> void:
    _state = state

# getters ONLY — no apply_action, no setters, no mutating method reachable
func active_player() -> int: return _state.active_player
func round_number() -> int: return _state.round_number
func match_status() -> int: return _state.match_status
func current_ap(player: int) -> int: return AP.current_ap(_state, player)
func income_breakdown(player: int) -> Dictionary: return AP.ap_income_breakdown(_state, player)   # {base, outpost, econ_tech} — FORWARD-DECLARED, owed by AP Economy (see below)
func can_afford(player: int, amount: int) -> bool: return AP.can_afford(_state, player, amount)
func entities() -> Array[EntityState]: return _state.entities()
func entity_at(tile: Vector2i) -> EntityState: return _state.entity_at(tile)
# ...one getter per read the HUD needs; NO write path exists on this object
```

> **Forward-declared (owed to ADR-0006 / AP Economy):** `AP.ap_income_breakdown(state, player) ->
> {base: int, outpost: int, econ_tech: int}` — the *pre-labeled, pre-computed* income decomposition
> the income breakdown renders as named fields (CR-3 / TR-hud-019). The HUD must **not** receive the
> raw inputs (outpost count, tech flag) and split locally — that is exactly the Pass-Through
> violation §1's facade exists to prevent. ADR-0006 defines `AP.income()` (the total) but **not**
> this decomposition; TR-hud-019 assigns it to AP Economy, so it is owed by the AP Economy epic
> (a `referenced_by`/back-declaration on ADR-0006, registry step below) — the same consumer-names-
> producer-contract pattern this ADR uses for `CommandInterface.selection_changed` (§6). The Econ-Tech
> coefficient and outpost cap stay AP-Economy-owned constants and are never restated in HUD code
> (game-hud.md Edge Cases).

The HUD is injected with a `GameStateReader`, **never the live mutable `GameState`**. Because the
facade exposes no `apply_action` and no setter, a stray mutating call from a HUD script is
*unreachable* — a compile-time impossibility given GDScript has no access modifiers, achieved by not
handing the object a write path in the first place. This makes AC-2 ("HUD interactions invoke zero
`apply_action`") structurally true, not review-enforced (TR-hud-003). A companion **lint rule
restricts which Autoload methods `src/ui/` scripts may call** (candidate CI check, the same
static-allowlist discipline ADR-0011/0015 established) — belt-and-suspenders against reaching around
the facade to a global.

### 2. AP counter: a pure `ApCounterFsm` core + a Control widget (TR-hud-005/006/007)

Mirrors ADR-0015's `CommandFSM`/`CommandInterface` split — the animation-state *decision* is pure
and headless-testable; the *rendering* is the widget's.

```gdscript
# ap_counter_fsm.gd — pure, headless
class_name ApCounterFsm extends RefCounted
enum State { COMMITTED, FILL_FLOURISH, TICK_DOWN, PREVIEW_ECHO }
enum Trigger { TURN_START_FILL, COMMIT_SPEND, PREVIEW_OPEN, PREVIEW_CLOSE, TURN_TRANSITION, GAME_OVER }

## PURE: the next animation state. GAME_OVER resolves to COMMITTED (rest) with a
## snap-to-final flag; TURN_TRANSITION force-clears any PREVIEW_ECHO before a fill can trigger.
static func next_state(current: State, trigger: Trigger) -> State: ...
```

- **Four states** (TR-hud-005): `COMMITTED` (static, "trust" state — the value is real), `FILL_FLOURISH`
  (start-of-turn, once), `TICK_DOWN` (steps down by exactly N on a real commit), `PREVIEW_ECHO`
  (committed value frozen, `→ projected` renders beside it). Only the local player's counter reaches
  all four; the opponent's reaches only `COMMITTED` (+ `FILL_FLOURISH` iff `SHOW_OPPONENT_FILL_FLOURISH`,
  + `TICK_DOWN` for their own commits) — `PREVIEW_ECHO` is unreachable over opponent AP (only local #9
  drives previews). Opponent AP carries the persistent `OPPONENT` label + muted treatment (CR-3b).
- **Turn-transition echo force-clear (TR-hud-006)**: on any `PlayerTurn`/`EndTurn` transition the
  widget tears down the preview echo **synchronously as the first step**, before evaluating the
  incoming fill trigger — closing the one-frame race where #9's exit-to-IDLE and the HUD's fill are
  driven by different signals with no ordering guarantee. The HUD never *infers* the echo is gone.
- **GameOver tick-snap (TR-hud-007)**: a commit that triggers `GameOver` forces any in-flight
  tick-down to complete instantly (snap committed value to final within the one-frame bound AC-17
  requires for the overlay). The killing commit's hp-pip drain is the exception — **not** truncated
  (Player-Fantasy load-bearing) but **not** gated either (plays beneath the overlay without delaying
  its one-frame appearance).
- **Preview echo SNAPS, no tween** (inherits #9's "numbers snap in, never count up"); the committed
  value moves *only* on a real commit.

### 3. AP-tick serialization: consume ADR-0014's `input_locked`, do NOT build a tick queue (TR-hud-008)

The HUD renders one AP-tick at a time as commits arrive; it **must not** build its own tick
queue/interrupt logic. The serialization is upstream: ADR-0015's `input_locked` debounce +
`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` guarantee one tick fully resolves before the next commit
dispatches. hp-pip drains and an AP tick from the *same* resolution animate concurrently (different
elements, no shared serialization); only same-element (AP counter) commits serialize.

### 4. `HUDConfig` + closing ADR-0014's forward-declared invariant (TR-hud-008)

```gdscript
# hud_config.gd — a new per-system config Resource (gameplay_config_storage pattern, ADR-0006)
class_name HUDConfig extends Resource
@export var pip_max_hp: int = 10
@export var action_log_length: int = 20
@export var ap_fill_flourish_ms: int = 400
@export var ap_tick_duration_ms: int = 120
@export var turn_banner_duration_ms: int = 1000
@export var hud_audio_duck_ms: int = 150
@export var show_opponent_ap: bool = true
@export var show_opponent_fill_flourish: bool = false
@export var income_breakdown_default_expanded: bool = false
```

Loaded once by the same thin Balance-style loader Autoload as `EconomyConfig`/`InputConfig`/etc.
(`gameplay_config_storage`, ADR-0006). **The loader closes ADR-0014's forward-declared cross-config
invariant**: after loading both `InputConfig` and `HUDConfig`, it checks
`InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms` (Game HUD's tick must finish inside the
input-lock window or the commit-flash↔AP-tick sequencing breaks). **Because a bare `assert()` is
stripped in Godot release exports** (godot-specialist, ADR-0011 — the shared `*Config` caveat), this
uses a **release-surviving guard**: `push_error(...)` + a clamp (raise the effective
`ap_tick_duration_ms` down to `input_lock_ms` if violated) rather than a bare `assert`, mirroring how
`AIConfig`'s `LETHAL_FLOOR_BONUS > economy_ceiling_score` invariant is enforced (ADR-0011). This
discharges the obligation ADR-0014 §5 named.

### 5. Action log: an append-newest-on-top ring buffer, one entry per event (TR-hud-014)

The log subscribes to ADR-0004's `action_applied(result)` and appends **one entry per
`result.events` element, in the events' append order** (which ADR-0004 fixed as the deterministic
resolution order — so a single commit that resolves a kill + an HQ-destroy logs each in order). A
fixed-capacity ring buffer of `HUDConfig.action_log_length` (default 20) drops the oldest when full;
newest renders on top. Deterministic because the ordering is a property of `result.events`, not of
signal-fire timing (leans on ADR-0004's synchronous same-call-stack emission).

### 6. Detail panel: outward-in subscription to #9 (TR-hud-013) — forward-declares one #9 signal

The detail panel's *content* follows #9's selection/inspection; its *chrome* is HUD-owned. The
data-flow is **outward-in**: the HUD subscribes to a signal #9 emits — **#9 never calls into a
HUD-owned node** (which would make #9 depend on the HUD and falsify the leaf claim). This requires a
signal ADR-0015's `CommandInterface` did not yet declare:

> **Forward-declared (owed back to ADR-0015):** `CommandInterface.selection_changed(target:
> SelectionTarget)` — emitted whenever #9's selection or inspection target changes (`target` carries
> the entity_id + a `pinned`-vs-`peek` flag for the persistent-selection-vs-transient-inspection
> visual distinction, CR-6). The HUD's detail panel subscribes and re-renders from a read query for
> that entity via `GameStateReader`. Implemented by the Command & Action Interface epic (ADR-0015);
> named here because ADR-0016 is the consumer that pins the contract, the same forward-declaration
> pattern ADR-0006 used for `completed_outpost_count`. **A back-reference should be added to
> ADR-0015's registry entry** (registry step below).

The panel carries a distinct visual state for pinned (selected) vs. peek (inspecting) — a
requirement binding by *more than content alone* (non-hue redundant, CR-6/Accessibility E); exact
treatment defers to `/ux-design`.

### 7. Single-owner audio dispatch + total priority order (TR-hud-021)

A single HUD-owned `HudAudioDispatcher` is the **sole `play()` chokepoint** for every HUD audio
event — no widget plays its own sound, and #9's commit-flash / the AP-counter tick subscribe to the
same signals for their *visuals only* and stay audio-silent (AC-20: the AP-tick `play()` is invoked
exactly once across #9 and the HUD). **"Sole caller" is a code-level chokepoint (one dispatcher
class owns every `.play()` call), not a single `AudioStreamPlayer` node** — one `AudioStreamPlayer`
plays one stream at a time (a second `play()` replaces the current stream, it does not layer), so
true ducking (the lower-priority cue plays *quieter but still audible* under `hud_audio_duck_ms`)
requires ≥2 `AudioStreamPlayer` children (or bus sends) the dispatcher manages internally, e.g. one
for stinger/GameOver and one for fill/completion (godot-specialist, 2026-07-24 — the engine's audio
pooling guidance). The architecture is unchanged (one logical owner/decision point); only the
under-the-hood player count is an implementation detail. The dispatcher subscribes to:
- ADR-0004's `action_applied` → the AP-tick sound (bound to the **commit** signal, never an
  `ap_changed` value-change that could double-fire).
- ADR-0008's `start_turn` → the AP-fill arpeggio + the turn-change stinger.
- `StructureCompletedEvent`/`TechCompletedEvent` (ride `action_applied`, ADR-0008) → completion cues.
- `match_status → GameOver` → victory/defeat cue.

It resolves collisions against a **single total priority order** (highest first):
**`GameOver > turn-change stinger > completion cue (deduped) > AP-fill arpeggio`.** Lower-priority
cues in a collision are **ducked** under `HUDConfig.hud_audio_duck_ms`, except `GameOver`, which
**hard-preempts** (cut, not ducked). Simultaneous completion cues dedupe to one played cue that
frame (on-board markers still update individually). The attack-commit sound is **not** owned here —
Combat triggers it off the same `action_applied` event (ADR-0015 §6 / combat GDD), so exactly one
system calls `play()`.

### 8. Reactive render: dirty-flag coalescing over the single event surface (TR-hud-004/012/015/016/017/020)

The HUD is one subscriber to ADR-0004's `action_applied` (+ the turn-boundary signal). On any
signal a HUD `Control` calls **`queue_redraw()`** — Godot's native redraw-coalescing: N calls in one
frame still trigger exactly one `NOTIFICATION_DRAW`/`_draw()` that frame, so a single commit firing
N events yields one coalesced redraw, not N. This is preferred over a hand-rolled `_process`
dirty-flag poll (godot-specialist, 2026-07-24 — `queue_redraw()` coalesces for free and avoids an
always-on per-frame callback; confirmed unchanged for 4.6). The Logic contract the ACs test is the
≤1-redraw-per-commit outcome, independent of the mechanism underneath. This one redraw path drives:
- **Always-present chrome** (TR-hud-004): AP counter, turn/round indicator, End Turn, Build, action
  log — continuously present during the active player's Action phase regardless of selection/preview.
- **hp pip-vs-numeric branch** (TR-hud-012): `max_hp < HUDConfig.pip_max_hp` → discrete drain-on-damage
  pips; `max_hp >= pip_max_hp` → numeric `current/max` stepping in whole integers (never a smooth bar).
  The `>=` boundary is load-bearing (a Production Outpost at hp exactly 14 must flip to numeric).
- **Build affordability + PREVIEW_BUILD cue** (TR-hud-015): the Build button reads `can_afford`
  across structure types (dimmed, never hidden, when none affordable) and holds a pressed/active
  treatment while #9's `PREVIEW_BUILD` is live (subscribing to #9's build-preview state — outward-in,
  same direction as §6).
- **Victory/defeat one-frame preemption** (TR-hud-016): on `match_status = GameOver(winner)` the
  overlay appears within one frame, **truncating any in-flight or pending turn banner** (the win must
  read as immediate, not gated behind a banner's leftover `turn_banner_duration_ms`).
- **Turn-scoped inert controls** (TR-hud-017): Build + End Turn are live only in the local Action
  phase; during the opponent's turn / `EndTurn` transient / resolution they render but are inert
  (`FOCUS_NONE`, ADR-0014), readouts stay live.
- **Leaf binding** (TR-hud-020): all reads go through `GameStateReader` (§1) across the 7 upstream
  systems; the HUD is depended on by nobody.

### Architecture Diagram

```
   GameState (authoritative)          Command & Action Interface (#9, ADR-0015)
        │  read-only via                   │  emits selection_changed (§6, outward-in)
        │  GameStateReader (§1)            │  emits build-preview state (§8)
        ▼                                  │  projected_remaining_ap (inline echo)
   ┌─────────────────────────────────┐    │
   │ Game HUD (leaf, this ADR)        │◀───┘
   │  ├─ ApCounterFsm (pure, §2)      │
   │  ├─ AP counter widget           │◀── action_applied (ADR-0004): AP-tick + hp-drain + log
   │  ├─ action log ring buffer (§5) │◀── start_turn (ADR-0008): fill-flourish + stinger
   │  ├─ detail panel (§6)           │
   │  ├─ on-board readouts ──────────┼──▶ BoardRenderer.grid_to_screen (ADR-0013) glyph anchors
   │  ├─ Build / End Turn controls   │    (dual-focus per ADR-0014)
   │  └─ HudAudioDispatcher (§7) ────┼──▶ single play() owner, total priority order
   └─────────────────────────────────┘
   HUDConfig (§4) ── loader Autoload closes INPUT_LOCK_MS >= AP_TICK_DURATION_MS (ADR-0014 §5)
```

### Key Interfaces

```gdscript
# game_state_reader.gd — class_name GameStateReader extends RefCounted (getters only, §1)
# ap_counter_fsm.gd — class_name ApCounterFsm extends RefCounted
enum State { COMMITTED, FILL_FLOURISH, TICK_DOWN, PREVIEW_ECHO }
static func next_state(current: State, trigger: Trigger) -> State
# hud_config.gd — class_name HUDConfig extends Resource (9 @export knobs, §4)

# Forward-declared, owed to ADR-0015's CommandInterface (§6):
signal selection_changed(target: SelectionTarget)   # {entity_id: int, pinned: bool} — one-way #9 -> HUD
# Forward-declared, owed to ADR-0006 / AP Economy (§1):
static func ap_income_breakdown(state: GameState, player: int) -> Dictionary   # {base, outpost, econ_tech}
```

## Alternatives Considered

### Alternative A (shape): read-only facade + pure `ApCounterFsm` + single audio dispatcher — CHOSEN
- **Pros**: `GameStateReader` makes never-mutates structural (no write path exists on the injected
  object); the pure `ApCounterFsm` makes AC-3a/4/5a/25 headless-testable; one audio dispatcher makes
  AC-20's single-`play()` guarantee a structural property, not a coordination hope. Mirrors ADR-0015.
- **Cons**: More classes (facade + FSM + dispatcher) than a flat widget tree.
- **Rejection Reason**: n/a (chosen).

### Alternative B: widgets subscribe directly, hold own state, no facade
- **Cons**: Never-mutates reverts to review/lint-only (a widget holding the live `GameState` *could*
  call `apply_action`); the AP animation states aren't cleanly headless-testable; audio ownership
  scatters across widgets, reopening the double-`play()` risk AC-20 exists to catch.
- **Rejection Reason**: Rejected per explicit decision this session — structural guarantees over
  flatter wiring.

### Alternative C: HUD reads the live mutable `GameState` directly (no facade)
- **Cons**: Directly violates the structural never-mutates guarantee (TR-hud-003) — a HUD script
  could reach `apply_action`. Fails the whole point of the facade.
- **Rejection Reason**: Rejected — the facade is the mechanism that makes AC-2 load-bearing.

### Alternative (invariant enforcement): `HUDConfig` self-validates in `_init()`
- **Cons**: `HUDConfig` can't see `InputConfig` (a separate Resource) at its own `_init` — the
  cross-resource check needs a place holding both, which is the loader Autoload. Self-validation
  would force `HUDConfig` to reach for `InputConfig`, coupling the two Resources.
- **Rejection Reason**: Rejected per explicit decision this session — the loader Autoload holds both
  and is the natural home for the cross-config guard.

### Alternative (invariant enforcement): bare `assert(input_lock_ms >= ap_tick_duration_ms)`
- **Cons**: `assert()` is stripped in Godot release exports (godot-specialist, ADR-0011) — the guard
  would silently vanish in the shipped build, exactly where a misconfigured `.tres` would bite.
- **Rejection Reason**: Rejected — must be a release-surviving `push_error` + clamp.

### Alternative (audio): each cue's owning system plays its own sound
- **Cons**: Reintroduces the double-`play()` risk (e.g. #9 and the HUD both reacting to a commit) and
  scatters the total-priority-order resolution across systems that can't see each other's cues,
  making the GameOver-hard-preempt/duck ordering impossible to guarantee.
- **Rejection Reason**: Rejected — a single dispatcher is the only place the total order can be
  resolved coherently (TR-hud-021).

## Consequences

### Positive
- Never-mutates and single-`play()` become *structural* (no write path on the facade; one dispatcher),
  not review-enforced — AC-2 and AC-20 are load-bearing tests, not reminders.
- The AP-counter animation logic is headless-testable via the pure `ApCounterFsm`.
- ADR-0014's forward-declared cross-config invariant is discharged with a release-surviving guard,
  closing the last open cross-ADR handoff in the Presentation cluster.
- The action log's determinism inherits ADR-0004's `result.events` ordering — no HUD-side sort.

### Negative
- Two contracts this ADR consumes are forward-declared back to their producers (neither is a re-open
  of a written ADR — both are named here + back-declared on the producer's registry entry): (a)
  `CommandInterface.selection_changed` (ADR-0015 — the detail-panel outward-in seam), and (b)
  `AP.ap_income_breakdown` (ADR-0006 / AP Economy — the income decomposition, TR-hud-019, which
  ADR-0006 did not define; it has `AP.income()` for the total only).
- `GameStateReader` is hand-maintained (one getter per read the HUD needs) — a small ongoing
  surface, the cost of not exposing the live object.
- Many HUD knobs (`pip_max_hp` boundary interactions, banner/fill/tick feel) are unpinned values
  owed to `/ux-design` + `/art-bible` — this ADR fixes the mechanism (config Resource + branch
  points), not the numbers.

### Risks
- **The single-`play()` audio guarantee depends on every other system honoring "subscribe for
  visuals, stay audio-silent"** — the dispatcher can't force silence on a system that wrongly calls
  `play()` itself. Mitigation: AC-20's call-count spy on the audio entry point is the regression
  guard; the single-owner rule is registered (registry step) so it outlives this ADR.
- **The cross-config clamp masks a misconfiguration rather than failing loudly in release** — a
  `.tres` with `ap_tick_duration_ms > input_lock_ms` is silently clamped, not rejected, in a shipped
  build. Mitigation: the `push_error` fires in the editor/debug run where authors will see it; the
  clamp only protects the release player from a broken sequencing feel. (A hard `OS.crash` in release
  was considered worse — a shipped hard-crash on a tuning typo.)
- **Inherits ADR-0013's glyph-anchor spike and ADR-0014's dual-focus spike** as prerequisites for
  the on-board readouts and the four controls respectively. Named so the HUD epic sequences after them.
- **`SHOW_OPPONENT_AP` is mechanics-adjacent, not purely cosmetic** (game-hud.md flags it) — flipping
  it changes information available for play (opponent-budget threat reads). This ADR keeps it a
  `HUDConfig` knob (default on) but flags that a balance owner, not just UX, should sign off changes.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-hud.md | TR-hud-003: read-only facade (getters-only), not convention; facade + lint | §1 (`GameStateReader`, no write path + companion `src/ui/` lint) |
| game-hud.md | TR-hud-004: bind AP counter/turn indicator/End Turn/Build/log always-present during active turn | §8 (always-present chrome on the coalesced redraw path) |
| game-hud.md | TR-hud-005: AP counter 4-state anim FSM; opponent AP muted | §2 (`ApCounterFsm` four states; opponent-AP reachable-state restriction + `OPPONENT` label) |
| game-hud.md | TR-hud-006: on transition, preview echo force-cleared before fill-flourish evaluates | §2 (synchronous echo teardown as first transition step) |
| game-hud.md | TR-hud-007: GameOver snaps in-flight AP tick to final in one frame; killing hp-pip drain plays unclipped non-gating | §2 (GameOver tick-snap; hp-drain exempt from truncation and from gating) |
| game-hud.md | TR-hud-008: AP tick relies on upstream INPUT_LOCK_MS>=AP_TICK_DURATION_MS, no own tick queue | §3 (consumes ADR-0015 `input_locked`, no HUD-side queue) + §4 (the invariant's load-time guard) |
| game-hud.md | TR-hud-009: turn/round indicator + YOUR/ENEMY banner from active_player/round_number/match_status, self-clearing | §8 chrome + §2 (banner on `PlayerTurn`, `turn_banner_duration_ms` self-clear) |
| game-hud.md | TR-hud-012: hp display branch on PIP_MAX_HP (>=): pips below, numeric at/above, no smooth bar | §8 (pip-vs-numeric branch, `>=` boundary) |
| game-hud.md | TR-hud-013: detail panel subscribes outward-in to #9 selection-changed (one-way #9->HUD), pinned vs peek | §6 (forward-declared `CommandInterface.selection_changed`; HUD subscribes, #9 never calls in) |
| game-hud.md | TR-hud-014: action log append-newest-on-top ring buffer (20), one entry per apply_action event, oldest dropped, deterministic | §5 (ring buffer over `result.events` in resolution order) |
| game-hud.md | TR-hud-015: Build button real-time affordability (dimmed never hidden), mirrors #9 PREVIEW_BUILD pressed cue | §8 Build bullet |
| game-hud.md | TR-hud-016: victory/defeat reads GameOver(winner)+win_condition, preempts turn banner within one frame | §8 victory/defeat bullet |
| game-hud.md | TR-hud-017: End Turn + Build inert during opponent turn + EndTurn transient, readouts live; reads match_status/phase | §8 turn-scoped-controls bullet (`FOCUS_NONE`) |
| game-hud.md | TR-hud-018: every HUD value verbatim read, zero local balance constants, zero recompute (exempt transient anim delta) | §1 facade + Pass-Through carve-out for animation-delta state (Constraints) |
| game-hud.md | TR-hud-020: bind read-only to 7 upstream + coordination seam w/ #9, zero downstream dependents (leaf) | §1 (`GameStateReader` across 7 systems) + §6 (outward-in #9 seam preserving the leaf claim) |
| game-hud.md | TR-hud-021: audio single-owner play() per event; total priority GameOver>stinger>completion(deduped)>AP-fill; duck except GameOver hard-cut | §7 (`HudAudioDispatcher` sole `play()` owner + total priority order + duck/preempt) |

## Performance Implications
- **CPU**: The HUD is event-driven, not `_process`-polled — it marks dirty on signal and coalesces to
  ≤1 redraw/frame (§8), so an N-event commit costs one redraw, not N. `ApCounterFsm.next_state` is
  O(1). Log append is O(1) amortized (ring buffer). No per-frame query polling (all reads happen on
  the dirty redraw).
- **Memory**: One `GameStateReader` (a thin wrapper), one ring buffer of `action_log_length` entries,
  one `HUDConfig` Resource. Negligible.
- **Load Time**: Negligible — one added config Resource + the loader's cross-config check.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Never-mutates (structural)**: `GameStateReader` exposes no method that mutates `GameState`; a HUD
  script cannot reach `apply_action` through it (AC-2 — call-count spy on the commit entry point).
- **AP-FSM transitions**: `ApCounterFsm.next_state` table-tested — fill fires once at turn start
  (AC-3a); no committed-value animation on hover/cancel/illegal/selection (AC-4); tick steps by
  exactly N and serializes (AC-5a); no `→` when no preview (AC-25); GameOver snaps to final (AC-17).
- **Cross-config guard**: with `ap_tick_duration_ms > input_lock_ms`, the loader emits a `push_error`
  in debug AND the effective tick is clamped in a release build (not a stripped bare assert).
- **Log**: one entry per `result.events` element in resolution order; > `action_log_length` drops
  oldest (AC-14/15).
- **Pip/numeric branch**: `max_hp == pip_max_hp` renders numeric (the `>=` boundary, AC-10).
- **Single audio play()**: the AP-tick `play()` is invoked exactly once across #9 and the HUD per
  commit (AC-20 — call-count spy).
- **Detail-panel outward-in**: the HUD re-renders the panel on `CommandInterface.selection_changed`;
  #9 makes no call into any HUD node (AC-13 + the leaf-claim check).

## Related Decisions
- ADR-0001: state model (the `GameState` read API `GameStateReader` wraps)
- ADR-0002: apply-action model (`ActionResult.events` — the log source)
- ADR-0004: event/signal architecture (`action_applied` — the single event surface + coalescing
  contract the HUD consumes; the commit-flash↔AP-tick shared signal)
- ADR-0006: AP economy (`ap_income_breakdown`/`can_afford`; `gameplay_config_storage` — where
  `HUDConfig` loads and the cross-config guard runs)
- ADR-0008: start-of-turn sequencing (`start_turn` — the fill-flourish + stinger trigger;
  Structure/Tech-CompletedEvents the completion cues fire on)
- ADR-0013: isometric board rendering (`grid_to_screen` — on-board readout anchors)
- ADR-0014: input & focus (dual-focus conventions for the four controls; `InputConfig.input_lock_ms`
  — the other half of the invariant this ADR closes)
- ADR-0015: command & action FSM (`projected_remaining_ap`, `PREVIEW_BUILD` state, the
  `selection_changed` signal this ADR forward-declares back to it, the shared commit-flash contract)
- `design/gdd/game-hud.md` — the full design this ADR makes concrete
