# ADR-0004: Event / Signal Architecture (State → Presentation)

## Status
Proposed

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Signals |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None — custom `signal` declarations and `Callable`-based `.connect()` on a non-`Node` `Object`/`Resource` subclass are a stable, pre-4.0-vintage Godot feature |
| **Verification Required** | None. **godot-specialist review 2026-07-23 (live-docs + GitHub-issue verified):** (1) `Resource.duplicate_deep()` copies only `PROPERTY_USAGE_STORAGE`-flagged data — clones carry ZERO signal connections (CONFIRMED, and stronger than the ADR first framed it — see Risks); (2) custom signals on a `Resource` subclass via modern `Callable` `.connect()`/`.emit()` are fully idiomatic, and the disk-load/caching pitfalls don't apply since `GameState` is `.new()`-only per ADR-0001 (CONFIRMED); (3) no 4.4–4.6 changes to signal-connection semantics, typed custom-class signal params, or synchronous emission ordering (no positive evidence of change; consistent with "Post-Cutoff APIs Used: None"). One deprecation note applies project-wide (not new to this ADR): string-based `connect("signal", obj, "method")` was removed in 4.0 in favor of `signal.connect(callable)` — all connections here use the modern form. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState` — this ADR adds a `signal` declaration to that class), ADR-0002 (`ActionResult`/`events: Array[Event]` — this ADR's signal payload *is* that object; also formally defines the `Event` base class ADR-0002 only forward-referenced) |
| **Enables** | ADR-0013 (Board Renderer — subscribes for sprite move/depth re-sort), ADR-0016 (HUD read-facade — subscribes for AP tick, hp-pip drain, action-log append, dirty-flag coalescing) |
| **Blocks** | Epic "Foundation: Game State Core" (presentation cannot react to any commit without this contract) and both Presentation modules (Board Renderer, HUD) |
| **Ordering Note** | Fourth Foundation ADR to draft. Resolves QQ-02 (architecture.md). Must Accept alongside ADR-0001/0002 as part of the Foundation cluster — Presentation-layer ADRs (0013, 0016) assume this signal exists. |

## Context

### Problem Statement
`game-state-turn-manager.md` (TR-gamestate-012) requires the renderer to be "a pure consumer
observing change events/signals, never mutating truth," citing an example signal contract
(`unit_moved`, `turn_ended`, `game_over`). `game-hud.md` (CR-1) independently requires the same
push-not-poll reactivity (TR-hud-001/023) plus dirty-flag coalescing to at most one redraw per
frame regardless of event count (TR-hud-002). Both GDDs explicitly defer the concrete mechanism to
architecture, flagging the same open question from two angles — architecture.md tracks it as
**QQ-02: typed signals vs. one aggregate `state_changed` diff, High risk**. ADR-0001 already ruled
out one candidate (a global event-bus-core owning state) and explicitly left the door open for this
ADR to have `GameState` emit typed signals directly with "no bus object required." ADR-0002
independently already produces a typed `events: Array[Event]` per commit but never formally defines
`Event` itself or how presentation learns a commit happened at all — this ADR closes both gaps.

### Constraints
- `GameState extends Resource` (ADR-0001) — `Resource` is an `Object` subclass, so it can declare
  and emit its own `signal`s without becoming a `Node` or breaking headless testability.
- Single-threaded, synchronous (`apply_action` per ADR-0002) — no cross-thread emission concerns.
- `authoritative_game_state` / `direct_game_state_field_write` (registry, ADR-0001) — the signal
  must not become a second mutation path; it is strictly an outbound notification.
- `mutation_in_validate` (registry, ADR-0002) — emission must happen only after a commit fully
  succeeds (step 5 `apply()` has run), never during `validate()`.
- Determinism (ADR-0003) — event *ordering* within one commit must be a property of the data
  (append order inside `apply()`), not of signal/connection order.
- The AI's `clone()`-based lookahead (ADR-0001, ADR-0011) evaluates many hypothetical `GameState`
  instances per turn; none of those evaluations may visibly "leak" into real presentation.

### Requirements
- Presentation (HUD, Board Renderer) must react to state changes via subscription, never polling
  `_process` against live state (TR-hud-023).
- A single committed action that produces multiple sub-events (e.g. a multi-hit kill, or a batch of
  build/research completions at start-of-turn) must be observable as one coalesced unit, not force
  each subscriber to reassemble what happened across N separate signal firings (TR-hud-002,
  supports AC-1a's "N events → 1 redraw").
- Event ordering within a commit must be deterministic and must match the log's required
  "resolution order" (TR-hud-014/AC-14 — e.g. a kill that also destroys the HQ logs both, in order).
- The renderer needs a stable, minimal set of typed signals to key off (TR-gamestate-012's named
  examples: `unit_moved`, `turn_ended`, `game_over`), not a single opaque diff blob it must
  structurally re-interpret every time.
- Must not require a second lookup mechanism beyond what ADR-0001 already gave Presentation
  (`MatchService.get_current()`).

## Decision

**`GameState` declares and emits its own signal directly — no separate Event-bus Autoload.**
`Resource` (which `GameState` extends, ADR-0001) is an `Object` subclass and supports `signal`
declarations natively; routing through a bus Autoload would only be justified if Presentation had
no other way to reach the live `GameState` instance, but `MatchService` (ADR-0001) already solves
exactly that lookup problem. Adding a second Autoload for the same purpose would be redundant
indirection with no compensating benefit, and it is the option ADR-0001's own Alternative 3
rejection anticipated and explicitly left this ADR free to avoid.

**One unified signal, not several, and not a generic diff:**

```gdscript
signal action_applied(result: ActionResult)
```

Emitted **once**, synchronously, at the very end of `apply_action`'s pipeline (after step 6's
win-check, as part of step 7 — see ADR-0002's pipeline), and **only when `result.ok == true`**. A
rejected action is, by ADR-0002's atomicity guarantee, a true no-op — there is nothing for
Presentation to react to, so nothing is emitted. The direct caller (e.g. Command & Action
Interface) still receives `result` synchronously from its own `apply_action()` call and uses that
return value for inline rejection feedback (an unaffordable/illegal-target message); the signal is
reserved for "a commit actually happened."

This resolves QQ-02 as a **hybrid, not either literal extreme**: it is a *single event surface*
(the GDD's "not five" requirement — one subscription per Presentation node, one call site to
reason about), but the payload is **not** a generic diff — `result.events` is the same typed
`Array[Event]` ADR-0002 already produces, so subscribers keep full static-type information
(`if e is DamageEvent:`) instead of re-deriving meaning from a structural diff. Coalescing an
N-sub-event commit into one signal firing is automatic: `apply_action` already computes all of a
commit's events in one synchronous call before returning/emitting, so "one commit → one signal → N
typed events in one payload" requires no batching logic at the bus layer at all.

**This ADR formally defines `Event`**, which ADR-0002 only forward-referenced:

```gdscript
# event.gd — top-level file, class_name Event. Base for every typed event a verb handler can emit.
class_name Event extends RefCounted
```

Each owning Core system defines its own `Event` subclasses as top-level files (mirroring ADR-0002's
per-verb `Action` subclass convention) and appends instances to the `events` array it returns from
its `apply()`, in the order those effects actually happened — that append order **is** the
resolution order (TR-hud-014/AC-14); nothing downstream (the bus, the signal, a subscriber) may
reorder it. Illustrative examples, owned by their respective systems (not exhaustively enumerated
here — each owning GDD/ADR defines its own event vocabulary as it is built):

```gdscript
# unit_moved_event.gd (Movement)      : entity_id, from: Vector2i, to: Vector2i
# damage_event.gd (Combat)            : target_id, amount, is_crit    (already named in ADR-0002)
# entity_destroyed_event.gd (Combat/Base&Prod) : entity_id
# hq_destroyed_event.gd == GameOverEvent (Combat/win-check) : winner: int
# build_completed_event.gd (Base&Prod): structure_id
# turn_changed_event.gd (turn seq, ADR-0008): active_player, round_number
```

**Dirty-flag coalescing (TR-hud-002) is a Presentation-side pattern this ADR enables but does not
implement** — that belongs to ADR-0013/ADR-0016, which own the render loop. The pattern this ADR's
single-signal design makes trivial:

```gdscript
# Sketch only — authoritative implementation lives in ADR-0013 (Board Renderer) / ADR-0016 (HUD).
func _ready() -> void:
    MatchService.get_current().action_applied.connect(_on_action_applied)

func _on_action_applied(result: ActionResult) -> void:
    _dirty = true
    _pending_events.append_array(result.events)

func _process(_delta: float) -> void:
    if _dirty:
        _redraw(_pending_events)
        _pending_events.clear()
        _dirty = false
```
Because a rapid sequence of AI-driven commits within one process frame each fire their own
`action_applied` signal, this dirty-flag pattern is still required (not merely "one signal = one
redraw always") — the single-signal design guarantees each *commit* is coalesced internally, while
the mark-dirty/redraw-once-per-frame pattern coalesces across *multiple commits* landing in the
same frame.

**Command & Action Interface's `selection_changed` signal is explicitly out of scope for this
ADR.** It is a presentation-internal, one-way UI-state signal (`#9 → #10`, TR-hud-013), not a
`GameState` mutation event — it is owned by ADR-0016 alongside the rest of the HUD's read-facade.

**AI lookahead silence falls out for free.** `duplicate_deep()` (ADR-0001) copies only
storage-flagged (`@export`) fields; signal *connections* are runtime-only `Object` state and are
never part of a `Resource`'s exported data, so a cloned `GameState` used for AI evaluation starts
with **zero subscribers** on `action_applied`. The AI can call `apply_action` on its clones freely
without ever visibly perturbing Presentation — no opt-out logic needed anywhere. This is
**architecturally guaranteed, not merely a default** (godot-specialist, 2026-07-23): unlike
`Node.duplicate()`, `Resource` has **no `DUPLICATE_SIGNALS`/`CONNECT_PERSIST` opt-in mechanism at
all** — there is no flag anyone could flip to make clones inherit subscribers; Resource duplication
has no code path to copy connections, full stop.

### Architecture Diagram

```
   MatchService.get_current()  ──(read-only lookup, ADR-0001)──▶  live GameState instance
                                                                        │
   Board Renderer  ──_ready()── .action_applied.connect(...) ──────────┤
   HUD             ──_ready()── .action_applied.connect(...) ──────────┤
                                                                        │
   apply_action(action):                                               │
       1..6  (validate / apply / win-check — ADR-0002)                 │
       7a  result := ActionResult{ok, reason, events}                  │
       7b  if result.ok: emit_signal("action_applied", result)  ───────┘   [synchronous,
       7c  return result                                                   same call stack]

   Subscribers each independently: mark dirty + buffer result.events,
   redraw once per _process (TR-hud-002) — pattern only, owned by ADR-0013/0016.

   AI clone() (ADR-0001, duplicate_deep()) → fresh GameState, ZERO signal connections
   → apply_action on a clone never reaches Presentation. No silencing logic required.
```

### Key Interfaces

```gdscript
# On GameState (ADR-0001), added by this ADR:
signal action_applied(result: ActionResult)   # emitted once, synchronously, ONLY when result.ok

# event.gd — top-level file, class_name Event
class_name Event extends RefCounted
# No fields on the base — every subclass is its own top-level file with class_name, owned by
# whichever Core system's apply() produces it. Consumers narrow with `if e is SomeEvent:`.
```

```gdscript
# apply_action's step 7 (extends ADR-0002's pipeline sketch):
apply_action(action):
    1..6  # unchanged — validate / apply / win-check, per ADR-0002
    var result := ActionResult.new(ok, reason, events)
    if result.ok:
        action_applied.emit(result)     # step 7b — this ADR's addition
    return result                       # step 7c — unchanged
```

## Alternatives Considered

### Alternative 1 (bus location): `GameState` emits its own signal directly — CHOSEN
- **Description**: No separate Autoload; `GameState` (an `Object` subclass via `Resource`) declares
  `signal action_applied`; Presentation connects via `MatchService.get_current()`.
- **Pros**: One fewer moving part; reuses the lookup ADR-0001 already built; signal lifetime is
  tied to the instance that's actually mutating, which is exactly the semantics wanted; AI clones
  are silent by construction (no exported connection state to carry over).
- **Cons**: If the VS ever needed a live "rematch without scene reload" (a new `GameState` replacing
  the old one mid-session), Presentation nodes connected to the old instance's signal would need to
  re-connect to the new one via `MatchService`. Not a VS-scope concern (each match is a fresh scene
  load); noted for future.
- **Rejection Reason**: n/a (chosen).

### Alternative 2 (bus location): Dedicated `EventBus` Autoload, all systems emit through it
- **Description**: A global signal-relay Autoload; `GameState`/systems call
  `EventBus.emit_action_applied(result)` instead of emitting on themselves.
- **Pros**: A single, permanently-stable subscription target regardless of which `GameState`
  instance is currently live — solves the "rematch without reload" case Alternative 1 defers.
- **Cons**: Redundant with `MatchService`'s already-solved lookup problem; couples every emitting
  system to one more global; ADR-0001's Alternative 3 already rejected folding state-ownership and
  event-propagation into one global construct — a bus Autoload as a pure relay avoids that specific
  conflation, but still adds a second lookup indirection for no capability the VS needs.
- **Rejection Reason**: Solves a problem the VS doesn't have yet, at the cost of an extra
  indirection layer for every single emission.

### Alternative 3 (payload shape): Several typed signals (`ap_changed`, `hp_changed`, `entity_added`, …)
- **Description**: `GameState` (or a bus) exposes 5+ separate signals, one per change category, each
  fired individually as its underlying value changes.
- **Pros**: Subscribers can connect only to what they care about; no need to filter an `events`
  array by type.
- **Cons**: A single commit with N sub-effects (multi-hit kill, batch build completion) fires N
  separate signals with no inherent ordering/grouping guarantee between them — the coalescing
  TR-hud-002 requires becomes real work (must correlate which signals belong to "the same commit"),
  and TR-hud-014's resolution-order requirement has no natural home (order across independently-
  fired signals isn't guaranteed the way append-order-within-one-array is). Also multiplies
  `GameState`'s public surface for marginal subscriber convenience `if e is X:` already provides.
- **Rejection Reason**: Loses the free per-commit coalescing and deterministic intra-commit
  ordering that a single array-payload signal gives for free; the GDD's own framing ("single event
  surface, not five") already leaned against this.

### Alternative 4 (payload shape): One aggregate `state_changed` signal with a generic diff
- **Description**: `GameState` emits `state_changed(diff: Dictionary)` — a structural before/after
  diff subscribers parse.
- **Pros**: Fewest signal declarations; one universal payload shape for any future state addition.
- **Cons**: Throws away the static typing ADR-0002 already built (`events: Array[Event]`,
  `if e is DamageEvent:`) in favor of re-deriving meaning from a generic structure at every call
  site; a diff-based approach also has to reconstruct "what actually happened" (was this HP change
  from combat or from a Lab-revert effect?) rather than being told directly by a typed event —
  directly against the project's static-typing convention (`.claude/docs/technical-preferences.md`).
- **Rejection Reason**: Strictly worse than the chosen hybrid on both type-safety and semantic
  richness, for no simplicity gain — ADR-0002's typed `events` array already exists; this
  alternative would have to discard and reinvent it as an untyped diff.

### Alternative 5 (emit condition): Emit on every `apply_action` call, subscribers filter on `result.ok`
- **Description**: `action_applied` fires unconditionally; every subscriber (including the direct
  caller) checks `result.ok` before reacting.
- **Pros**: One code path for "a commit attempt finished," used uniformly whether it succeeded or not.
- **Cons**: Fires (and every subscriber re-evaluates) on every rejected/no-op action too — wasted
  work for an event that, by the atomicity guarantee, changed nothing; also means "a signal fired"
  no longer implies "state changed," weakening the contract every future subscriber can rely on.
- **Rejection Reason**: Emitting only on success keeps the invariant "a fired `action_applied`
  signal always means a real state change happened" exactly true, which is a stronger and simpler
  contract for every subscriber to code against.

## Consequences

### Positive
- One subscription (`action_applied`), one payload type (`ActionResult`), fully statically typed
  down to individual event subclasses — no generic-diff parsing anywhere in Presentation.
- Per-commit coalescing is automatic (the events array is already batched before the signal fires);
  only cross-commit-per-frame coalescing (the dirty-flag pattern) is left for Presentation to
  implement, and that pattern is trivial given the single-signal design.
- AI lookahead is silent by construction — `duplicate_deep()` clones carry no connections, so no
  "don't render during AI evaluation" flag or check is needed anywhere in the codebase.
- Zero new Autoloads — reuses `MatchService`'s lookup, keeping the Autoload surface exactly as
  small as ADR-0001 intended.
- "A signal fired" and "state actually changed" are the same fact, by construction (success-only
  emission) — a strong, simple invariant for every future subscriber.

### Negative
- A hypothetical future "rematch without scene reload" would need Presentation to explicitly
  re-connect to the new `GameState`'s signal via `MatchService` on match-restart — not built now
  (no VS requirement for it), tracked as a Risk below rather than speculative code added today.
- Every Core system defining its own `Event` subclasses (mirroring `Action`) adds a small
  per-system file each — same cheap-but-more-files tradeoff ADR-0002 already accepted for `Action`.

### Risks
- **Rematch/new-match-without-reload** (deferred): if a future feature needs a new `GameState`
  instance while old Presentation nodes are still alive and connected to the previous instance's
  signal, those nodes would silently stop receiving events. Mitigation: not a VS-scope risk (each
  match is a fresh scene load, per architecture.md's boot-order flow); if this changes, `MatchService`
  gains a `current_changed` signal of its own so Presentation can re-subscribe — an ADR-0004
  revision, not a design flaw in this decision.
- **A verb handler appends events out of intended presentation order.** Mitigation: code review +
  a per-verb test asserting `events` order matches the documented resolution-order rule (e.g. a
  kill's `DamageEvent` precedes a resulting `GameOverEvent`); this is the same discipline ADR-0002
  already imposes on `validate()`/`apply()` purity.
- **A subscriber mutates state from inside its `_on_action_applied` handler** — would violate
  `direct_game_state_field_write` from inside what's meant to be a pure-read reaction. Mitigation:
  code review; Presentation modules (ADR-0013/0016) are read-only by their own GDD contracts
  (CR-1, TR-gamestate-012) independent of this ADR.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-state-turn-manager.md | TR-gamestate-012: renderer is a pure signal consumer, signal contract (unit_moved, turn_ended, game_over) | `action_applied(result)` carries typed `Event` subclasses including these; renderer only ever reads via the signal, never mutates |
| game-hud.md | TR-hud-001: HUD is pure-read, event-driven, no mutation, signal-bus | `action_applied` is the sole state-change signal HUD subscribes to; HUD never calls `apply_action` for its own rendering |
| game-hud.md | TR-hud-002: coalesce to ≤1 redraw/frame regardless of event count | Per-commit coalescing is automatic (one signal, N typed events in `result.events`); cross-commit dirty-flag pattern (Decision) handles multiple commits landing in one frame |
| game-hud.md | TR-hud-023: event-driven (signal-subscribed), not per-`_process` polling | HUD connects to `action_applied` at `_ready()`; no live-state polling anywhere |
| game-hud.md | CR-1: synchronous same-call-stack emission ordering (for AC-14's deterministic log resolution order) | Emission happens inline inside `apply_action` step 7, after `events` is fully built in append (= resolution) order |
| command-action-interface.md (TR-cmdui-023) | Commit-flash + AP tick-down fire off the SAME shared `apply_action`-result event, same frame | Both subscribe to the one `action_applied` signal; no separate per-consumer events to desync |

## Performance Implications
- **CPU**: One `emit_signal` call per successful commit; cost scales with subscriber count (2–3 in
  VS scope: HUD, Board Renderer) and is negligible next to `apply_action`'s own validate/apply work.
- **Memory**: `Event` subclasses are small, short-lived `RefCounted` objects held only in
  `result.events`, discarded once Presentation has consumed them (post-redraw `.clear()` per the
  dirty-flag sketch).
- **Load Time**: N/A.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Signal fires on success only**: commit a legal action → `action_applied` fires exactly once with
  `result.ok == true`; submit an illegal action → the signal does not fire at all.
- **Event order preserved**: a commit producing multiple events (mocked multi-effect apply()) yields
  `result.events` in the exact append order the handler produced, unmodified by emission.
- **Per-commit coalescing**: a single commit with N events triggers exactly one `action_applied`
  emission (not N) — verified via an emission-count spy.
- **AI clone silence**: `state.clone()`, connect a spy to the ORIGINAL's `action_applied`, call
  `apply_action` on the CLONE — assert the spy is never invoked.
- **Subscriber read-only discipline**: a sample `_on_action_applied` handler that only reads
  `result.events` never triggers `direct_game_state_field_write` (structural code-review check, not
  automatable beyond the existing atomicity tests).

## Related Decisions
- ADR-0001: State model ownership & lifecycle (`GameState` this ADR adds a signal to; the
  `duplicate_deep()`/clone mechanism that makes AI lookahead silent by construction; the
  `MatchService` lookup this ADR reuses instead of a bus Autoload; explicitly anticipated this
  ADR's direction in its Alternative 3 rejection)
- ADR-0002: Action / `apply_action` command model (the pipeline step this ADR's emission hooks into;
  the `ActionResult`/`events: Array[Event]` this ADR's signal carries and formally bases `Event` on)
- ADR-0003: Deterministic simulation & RNG isolation (event append order must be data-derived, not
  incidental — same determinism discipline)
- ADR-0013: Isometric board rendering (subscribes to `action_applied` for sprite move / depth re-sort)
- ADR-0016: HUD read-facade, animation & audio priority (subscribes to `action_applied` for AP tick,
  hp-pip drain, action-log append; owns the authoritative dirty-flag coalescing implementation this
  ADR only sketches)
