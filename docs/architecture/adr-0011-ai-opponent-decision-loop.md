# ADR-0011: AI Opponent Decision Loop & Scoring Module Shape

## Status
Accepted

> **Revised 2026-08-05 — economy pivot: `CREDIT_TO_AP_RATE` + AP-equivalent scoring.** The single AP pool
> split into **two resources** (see ADR-0006, ap-economy.md → "AP & Credits Economy"): **AP** (flat tactical
> budget for move/attack + a small AP surcharge on economic actions) and **Credits** (banked, uncapped, paying
> the main cost of produce/build/research). This ADR is updated in place to keep the AI's single-scale scoring
> intact under two currencies — the loop architecture (clone + enumerate + score + pick-best; determinism;
> headless) is unchanged. Specific deltas, all tracking the pivoted GDD (ai-opponent.md, Phase 1, source of
> truth): (1) a new AI-only knob `CREDIT_TO_AP_RATE` (default 1.0, range 0.5–2.0) added to `AIConfig`, raising
> its knob count from 15 to **16**; (2) the cost axis becomes an AP-equivalent combined cost
> `ap_equiv_cost = ap_cost + credit_cost × CREDIT_TO_AP_RATE`, and `_is_better(...)`/the tie-break now compare
> `ap_equiv_cost` then `entity_id`; (3) the affordability gate becomes **dual** — economic candidates require
> `AP.can_afford(ap_surcharge) AND Credits.can_afford(credit_cost)`, move/attack stay AP-only; (4) the score
> becomes `ap_equiv_value / ap_equiv_cost` (per the GDD's `action_score`), with Credit-denominated value terms
> × `CREDIT_TO_AP_RATE`; (5) the `LETHAL_FLOOR_BONUS > economy_ceiling_score` invariant is re-validated — it now
> reads against the **AP-equivalent** ceiling `economy_ceiling_score × CREDIT_TO_AP_RATE` and holds at defaults
> (≈1.77 < 3.5), the invariant being linear in the rate so it survives up to rate **≈1.98** before the default
> `LETHAL_FLOOR_BONUS` (3.5) is breached — flagged so a future rate change past ≈1.98 is caught (GDD AC-38,
> OQ-11). Where the GDD and this ADR could still disagree, the GDD wins.

> **QQ-06 perf spike CLEARED 2026-07-25 (performance-analyst, PASS).** The enumerate→commit loop
> (TR-ai-012) at N≤24 units on the pinned 14×16 board measures **~3.7 ms p95 / ~3.68 ms mean** per
> full `choose_action()` pass (845 candidates scored per pass, under a deliberately upward-biased
> clone-cost model); a full 5-commit streaming turn totals ~16.4 ms of compute — the entire turn's
> enumeration fits inside one 60 FPS frame, before the 0.35 s `commit_pacing_sec` even applies. The
> full-re-enumeration strategy below meets budget with ~2 orders of magnitude of headroom, so OQ-1's
> incremental-invalidation fallback is not needed at this scale. Bench:
> `prototypes/spikes/qq06_ai_loop_bench.gd`.
>
> **ACCEPTED 2026-07-25** as part of the bottom-up 18-ADR Accept batch (this ADR's Depends-On set
> reached Accepted together). Non-blocking follow-ups: (a) replace ai-opponent.md AC-9b's
> `[PLACEHOLDER]` with ~3.7 ms; (b) re-run the bench against the real `AI`/`Movement`/`Combat`
> classes once `src/` exists, as a regression check (this spike used faithful stand-ins).

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Scripting (AI decision logic + a small presentation-adjacent coroutine) |
| **Knowledge Risk** | LOW — this ADR composes patterns already validated in ADR-0001/0002/0003/0004/0006/0009/0010 (static utility class, `Resource`-based config, `clone()`/`apply_action`, typed Dictionary). The one new element, a `Node` coroutine using `await get_tree().create_timer(...).timeout` for inter-commit pacing, is standard GDScript 2.0 async syntax (stable since 4.0, unaffected by any 4.4–4.6 change in `breaking-changes.md`). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; `docs/registry/architecture.yaml` (full read) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | QQ-06 perf spike (TR-ai-012) before Accepted; no engine-API verification needed. **QQ-06 CLEARED 2026-07-25 (PASS, ~3.7 ms p95 — see Status).** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState`/`clone()`/`entities()`/`entity_at()` — the AI's entire read surface), ADR-0002 (`apply_action`/typed `Action` subclasses/verb-handler shape — the AI constructs and commits through the exact same pipeline a human does), ADR-0003 (determinism: no RNG, stable iteration order — directly binds this ADR's entity-enumeration order), ADR-0004 (`action_applied` signal — how presentation observes each AI commit for TR-ai-013's streaming requirement), ADR-0006 (AP & Credits Economy — `AP.can_afford`/`current_ap` **and** `Credits.can_afford`/`current_credits`/`Credits.credit_income`; `gameplay_config_storage`/`ap_economy_module_shape` patterns this ADR's `AIConfig`/`AI` mirror; the two-currency split this ADR's dual affordability gate consumes), ADR-0007 (`UnitTypeDef`/`StructureTypeDef` fields the scoring formulas read: `produce_cost`, `build_cost`, `hp`, `attack`), ADR-0009 (`Movement.reachable()` — candidate move tiles + cost), ADR-0010 (`Combat.legal_targets()`/`legal_targets_from()`/`preview_damage()`; `GameState.destroy_entity()`'s win-check path the AI's own lethal commits ride) |
| **Enables** | None yet. Faction Identity (ADR-0012, per faction-identity.md AC-24/TR-faction-015) will later confirm the AI reads `effective_X` through the same shared call sites with no AI-only branch — this ADR's "AI reads only through approved queries, no direct field access" decision is exactly what makes that possible without changes here. |
| **Blocks** | AI Opponent epic implementation; Game State & Turn Manager's turn-handoff wiring (needs `PlayerState.is_ai_controlled` and the `AITurnDriver` hookup point this ADR introduces) |
| **Ordering Note** | Eleventh ADR; the last of the seven Hard-dependency systems' architecture to land before this one could be written. **QQ-06 CLEARED 2026-07-25 (PASS); ACCEPTED 2026-07-25 as part of the bottom-up 18-ADR Accept batch.** |

## Context

### Problem Statement
ai-opponent.md specifies a pure, verb-agnostic evaluate→commit greedy heuristic (CR-1–CR-7,
17 TRs) with three properties that pull in different directions unless the module shape is
chosen deliberately:

1. **Headless, render-decoupled** (TR-ai-001) — the AI's decision logic must be unit-testable
   with zero scene-tree dependency, exactly like `Movement`/`Combat`/`AP`.
2. **Streamed, not batched** (TR-ai-013, AC-9b) — each committed action must visibly resolve
   before the next is decided, which needs *some* real-time pacing mechanism.
3. **A 16-knob tunable scoring model** (TR-ai-007; 15 pre-pivot + `CREDIT_TO_AP_RATE` added by the
   2026-08-05 two-currency pivot) with a cross-knob invariant
   (`LETHAL_FLOOR_BONUS > economy_ceiling_score × CREDIT_TO_AP_RATE`, TR-ai-008) that can silently break
   CR-7 if a future tuning pass raises `ECONOMY_HORIZON`/`ECONOMY_DECAY`/`CREDIT_TO_AP_RATE` without
   re-checking it. (The invariant is now linear in `CREDIT_TO_AP_RATE`: it holds at the 1.0 default and up to
   rate ≈1.98 before the default `LETHAL_FLOOR_BONUS` of 3.5 is breached — GDD AC-38/OQ-11.)

A naive single-class design satisfies at most two of these three: a `Node`-based AI that awaits
frames for pacing is not headless; a purely synchronous static function has no way to pace itself
without an external driver. This ADR resolves the split, defines the `AI` module's internal
scoring/enumeration shape, forward-declares the two query surfaces this GDD depends on that don't
have their own ADR yet (Base & Production's `legal_build_tiles`/`legal_deploy_tiles`, Research's
`legal_research_targets`), and closes a data-model gap the GDD's prose assumes but never specifies:
nothing on `PlayerState` currently distinguishes a human-controlled player from an AI-controlled one.

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- Must uphold every already-registered stance in `docs/registry/architecture.yaml`: `apply_action`
  is the sole mutation vector (`direct_game_state_field_write` forbidden); no `get_class()` verb
  dispatch; no RNG (`global_rng` forbidden); no float on any state class (`float_in_state` —
  this ADR is the concrete case that pattern's "AI advisory scoring" carve-out exists for); no
  `Dictionary`/insertion-order-dependent iteration for order-sensitive passes
  (`nondeterministic_iteration_order` — which names "AI action enumeration" explicitly); config
  Resources are load-time-only, never mutated at runtime (`config_resource_runtime_mutation`).
- Must preserve `clone()`/`duplicate_deep()` parity: no new state-class field may be a raw
  `EntityState`/`Node` reference (`entity_ref_in_spatial_index`-style aliasing risk).
- Single-threaded, turn-based — no real concurrency exists, so "the state changed between
  `clone()` and commit" (AC-24) is a defensive case, not a real race, and needs no lock/mutex design.

### Requirements
- A pure, headless, single-step decision function usable from unit tests with no scene tree
  (TR-ai-001; covers AC-2/3/4/7/10–33 wherever the AC is phrased as "Logic").
- A separate, explicitly paced loop-driver that yields real frames/time between commits so
  presentation can render each one before the next is decided (TR-ai-013, AC-9b — "Integration").
- All 16 scoring weights externally tunable via a data Resource (the pre-pivot 15 plus
  `CREDIT_TO_AP_RATE`), with the cross-knob invariant enforced automatically rather than left to tribal
  memory (TR-ai-007, TR-ai-008).
- Deterministic candidate ordering: no `Dictionary` hash/insertion-order dependence anywhere in
  enumeration (AC-3, AC-23; `nondeterministic_iteration_order`).
- The `MAX_ECONOMY_INVESTMENTS_PER_TURN` cadence cap (AC-30) needs turn-scoped memory (how many
  economy/research actions committed *this turn*) despite the scoring function itself being
  stateless — resolved without breaking the "no instance state" module shape.
- CR-4's "no privileged reads" claim is, by the GDD's own routing note, a code-review/static-analysis
  property, not a runtime-testable one (AC-5/AC-6b) — this ADR must define what a lint rule checks
  against, not build runtime DI machinery for a compile-time-verifiable property.

## Decision

### 1. Module shape: `AI` is a static utility, mirroring `AP`/`Movement`/`Combat`

```gdscript
class_name AI extends RefCounted   # no instance state — mirrors ap_economy_module_shape,
                                    # movement_search_module_shape, combat_module_shape exactly
```

`AI` exposes exactly **one** public entry point:

```gdscript
static func choose_action(state: GameState, economy_investments_committed: int) -> Action
```

**Pure, headless, side-effect-free.** It internally clones (`var lookahead := state.clone()`,
satisfying CR-2 step 1 / TR-ai-001's "evaluate clone"), enumerates every legal+affordable
candidate across every verb against `lookahead`, scores each with the GDD's formulas, and returns
the single highest-`action_score` candidate's `Action` — or `null` if none clears
`AIConfig.pass_threshold` (CR-2/CR-6's termination signal). **It never calls `apply_action`
itself.** Committing (CR-2 step 4, "the real `apply_action()`, not the clone") is the caller's job.
This split is what makes `AI` headless: nothing inside it ever touches a `Node`, a signal
connection, or the scene tree, so it is trivially unit-testable exactly like `Movement.reachable()`
or `Combat.legal_targets()` — the same test harness pattern already used for those.

**Why a clone every call, when every query it calls (`reachable`, `legal_targets_from`,
`preview_damage`, `can_afford`) is already pure and mutates nothing?** Because CR-2 states it as a
Core Rule regardless, and OQ-1 pre-authorizes a *future* incremental-invalidation/caching strategy
that WOULD need a scratch copy to mutate speculatively — keeping the clone in place now means that
future substitution (which OQ-1 requires be proven behaviorally identical via differential testing
before landing) has a stable seam to plug into, rather than retrofitting cloning discipline in
later. It also makes "the AI can never accidentally mutate the authoritative state during
enumeration" true by construction, not by discipline.

**The `economy_investments_committed: int` parameter is the one deliberate escape from full
statelessness** — it is how `AIConfig.max_economy_investments_per_turn`'s cadence cap (AC-30) is
enforced without adding instance state to `AI` itself: `choose_action` excludes economy-build and
research-start candidates from enumeration once
`economy_investments_committed >= AIConfig.max_economy_investments_per_turn`. The caller (the
driver, §3) owns the counter — incrementing it whenever the returned action's verb is
`BUILD` (on an Economy Outpost) or `RESEARCH`, resetting it to 0 at the start of each AI turn. `AI`
stays free of any *turn-lifecycle* state; the counter is just another explicit input, like `state`.

### 2. Enumeration: streaming max-scan, deterministic order, tie-break by construction

`choose_action` never materializes a full candidate array. It walks each verb family once,
computing a running best `(action: Action, score: float, ap_equiv_cost: float, entity_id: int)` and
replacing it only when a new candidate is strictly better under the GDD's tie-break rule. **The
tie-break axis is the AP-equivalent combined cost** `ap_equiv_cost = ap_cost + credit_cost ×
CREDIT_TO_AP_RATE` (2026-08-05 two-currency pivot), not the raw `ap_cost` — so a cheaper *total*
(AP + converted Credits) equal-value action is preferred, matching the GDD's `action_score`
denominator exactly. Move/attack carry `credit_cost = 0`, so their `ap_equiv_cost` equals their
`ap_cost` and their tie-break is unchanged from the single-pool model:

```gdscript
static func _is_better(score: float, ap_equiv_cost: float, entity_id: int,
                       best_score: float, best_ap_equiv_cost: float, best_entity_id: int) -> bool:
    if score > best_score + AIConfig.score_tie_epsilon: return true
    if score < best_score - AIConfig.score_tie_epsilon: return false
    # AP-equivalent cost is a float now (Credit leg × CREDIT_TO_AP_RATE); compare with the same
    # score_tie_epsilon tolerance so a rate-scaled Credit cost can't create a spurious raw-float tie-break
    if absf(ap_equiv_cost - best_ap_equiv_cost) > AIConfig.score_tie_epsilon:
        return ap_equiv_cost < best_ap_equiv_cost
    return entity_id < best_entity_id
```

This directly satisfies AC-23's tie-break (lowest `ap_equiv_cost`, then lowest `entity_id`) as a pure
comparator, and avoids ever allocating an O(candidates) array on top of the enumeration cost OQ-1
already flags as the dominant perf risk — a candidate's `(action, score)` is compared and then
immediately discarded unless it wins. *(The pre-pivot comparator keyed on an `int` `ap_cost`; the
Credit leg makes the combined cost a `float`, so the secondary key now compares with the same
`score_tie_epsilon` tolerance used for the score, keeping the "no fragile raw-float `==`" discipline
the GDD's determinism note requires.)*

**Entity iteration order is `entity_id`-ascending, never raw `GameState.entities()`/
`entities_by_id` Dictionary order.** The registry's `nondeterministic_iteration_order` forbidden
pattern names "AI action enumeration" as its own example of an order-sensitive pass that must not
depend on Dictionary hash/insertion order — `choose_action` satisfies this by collecting the
active player's owned entity ids, sorting them once (`Array.sort()`, ascending int), and iterating
that sorted list for every verb family. This also happens to make AC-23's "lowest entity ID"
tie-break (the final key, after `ap_equiv_cost`) trivially consistent with enumeration order, though
the comparator above is what actually enforces it (sort order is for determinism of *iteration*, not
correctness of the tie-break itself).

**Per-verb enumeration helpers**, each a private static function taking `(lookahead: GameState,
unit_or_structure, economy_investments_committed: int) -> void` that folds candidates into the
caller's running-best via `_is_better` (passed the running-best by `inout`-style return, since
GDScript has no `inout` — each helper returns an updated `(action, score, ap_equiv_cost, entity_id)`
tuple or the unchanged input; `ap_equiv_cost` is the AP-equivalent combined cost, a `float`):

- `_score_move_and_attack_candidates` — per unit: `Movement.reachable(lookahead, unit)` for
  positional/retreat/setup-advance scoring (Edge Cases) and `Combat.legal_targets_from(lookahead,
  unit, tile)` for every reachable tile, covering both bare moves and move+attack combos in one
  pass (Edge Cases' combo rule) plus the zero-move `Combat.legal_targets(lookahead, unit)` case.
- `_score_production_candidates` — per structure with `legal_deploy_tiles`, per producible unit type.
- `_score_build_and_economy_candidates` — per `legal_build_tiles` result, dispatching
  `production_value`-style scoring for non-economy structures vs. `economy_value` for Economy
  Outposts (gated by `economy_investments_committed`).
- `_score_research_candidates` — per Lab, per `legal_research_targets` result (gated by
  `economy_investments_committed`, since research counts toward the same cadence cap per CR-5).
- `_score_cancel_build_candidates` — per under-construction owned structure.

Each helper calls only the approved query surface (§5) and `AIConfig` — never a raw
`UnitState`/`StructureState`/`PlayerState`/`GridState` field outside what `entity_at()`/`entities()`
already exposes as public typed accessors.

**Dual affordability gate before scoring (CR-4a, 2026-08-05 two-currency pivot).** Each helper
affordability-gates a candidate *before* folding it into the running best, and the gate is now
**dual**, matching the GDD's `ap_can_afford` AND `credits_can_afford`:

- **Move / attack** (`_score_move_and_attack_candidates`): `credit_cost = 0`, so the gate is
  `AP.can_afford(state, player, action.ap_cost)` only — unchanged from the single-pool model.
- **Produce / build / research** (`_score_production_candidates`, `_score_build_and_economy_candidates`,
  `_score_research_candidates`): the candidate is enumerated only if **both** legs pass —
  `AP.can_afford(state, player, action.ap_cost)` (the AP surcharge: `PRODUCE_AP_COST` 1 /
  `BUILD_AP_COST` 2 / the tech's `ap_surcharge`, base `RESEARCH_AP_COST` 1) **and**
  `Credits.can_afford(state, player, action.credit_cost)` (the Credit price: produce 2/4/5/7,
  build 4/9/6/8, research 7/10/10). A candidate affordable on exactly one leg is **not** enumerated
  (never scored, neither pool touched) — mirroring AP & Credits Economy's both-or-neither atomic
  commit (GDD AC-36). Because `Credits.can_afford` reads *banked* Credits (uncapped, carried across
  turns), the greedy loop naturally leaves Credits banked and only enumerates an expensive build/tech
  once income lifts the balance to it (GDD AC-37) — no explicit "save up" planner.
- **Cancel-build** (`_score_cancel_build_candidates`): no affordability gate — it *refunds* Credits.

**AP-equivalent value and cost (the one scale survives two currencies, CR-3).** Once a candidate is
gated in, its score is `ap_equiv_value(action) / ap_equiv_cost(action)` (the GDD's `action_score`),
where:

- `ap_equiv_cost(action) = action.ap_cost + action.credit_cost × CREDIT_TO_AP_RATE` — move/attack
  reduce to `ap_cost` (their `credit_cost` is 0); economic actions fold the Credit price, converted at
  the rate, into the same denominator as the AP surcharge.
- `ap_equiv_value(action)` dispatches to the four GDD value formulas, with **every Credit-denominated
  value term multiplied by `CREDIT_TO_AP_RATE`** so the unified number stays in AP-equivalent units:
  `combat_value` (opponent's sunk `produce_cost`/`build_cost`, and `HQ_SIEGE_VALUE`),
  `production_value` (the produced unit's `produce_cost` anchor), `economy_value` (the projected
  `credit_income` sum), and the **Economy-Tech income branch** of `research_value`. The **Attack/Defense
  Tech branch of `research_value` is a combat effect already in AP-equivalent via `HP_PER_AP` and is
  NOT rate-multiplied** — doing so would double-convert a value that never left the AP domain (GDD
  `research_value`, AC-17/AC-17a). At the default rate 1.0 every value term reproduces the single-pool
  number exactly; the only structural change at 1.0 is the added AP surcharge growing economic
  denominators (which only widens the lethal-floor headroom).

`CREDIT_TO_AP_RATE` is a fixed constant read from `AIConfig`, identical for every candidate in a turn,
so it rescales the whole value/cost space uniformly and introduces **no new nondeterminism**.

### 3. Loop driver: `AITurnDriver` — a small `Node`, owned by Game State & Turn Manager's turn handoff

Nothing in this corpus yet owns "drive a sequence of actions with real-time pacing between them" —
a human player's actions are naturally paced by their own input, so no prior system needed this.
The AI is the first. This ADR introduces one small new component:

```gdscript
class_name AITurnDriver extends Node   # NOT an Autoload; NOT authoritative; instantiated once
                                        # per match alongside MatchService, in the match-bootstrap scene

func run_ai_turn(state: GameState) -> void:
    var economy_investments := 0
    while true:
        var action := AI.choose_action(state, economy_investments)
        if action == null:
            break
        var result := state.apply_action(action)   # fires action_applied synchronously (ADR-0004);
                                                     # presentation begins animating this commit now
        if not result.ok:
            continue   # AC-24 defensive path: stale/rejected candidate, re-loop immediately,
                        # no AP spent, no pacing delay (nothing rendered to pace against)
        if _is_economy_or_research(action):
            economy_investments += 1
        if state.match_status == GameState.MatchStatus.GAME_OVER:
            return       # AC-35: the AI's own lethal commit ended the match — stop immediately,
                         # never enumerate again against a terminal state
        await get_tree().create_timer(AIConfig.commit_pacing_sec).timeout
    state.apply_action(EndTurnAction.new(state.active_player))
```

`AITurnDriver` holds **zero authoritative state** of its own (mirrors `MatchService`'s
logic-free-reference-holder discipline) — `economy_investments` is turn-scoped local, not a field,
so nothing here is deep-copied by `clone()` and nothing here needs to survive past one `run_ai_turn`
call. It is invoked by whatever code observes `state.active_player` becoming a player with
`PlayerState.is_ai_controlled == true` (§4) after a `start_turn()` — the exact call site (a
top-level match script's `action_applied`/`start_turn` handler) is Presentation/implementation
detail this ADR does not need to pin down further, matching the precedent ADR-0009 set for
`UnitConfig`'s loader-Autoload naming ("reconciled at implementation, not a blocking ambiguity").

**This split is what satisfies TR-ai-001 and TR-ai-013 simultaneously**: `AI.choose_action` never
awaits anything and never touches a `Node`, so it is fully headless and synchronously unit-testable
(every "Logic"-typed AC in the GDD tests `AI.choose_action` + a manual `apply_action` call, with no
scene tree needed). `AITurnDriver` is the only thing that awaits — and it contains no scoring logic
of its own, so its own tests are "Integration"-typed exactly as the GDD's own AC-9b already
classifies that requirement.

### 4. New field: `PlayerState.is_ai_controlled`

game-state-turn-manager.md's prose ("the active player, human or AI") has never had a data-model
field backing the distinction — nothing tells `AITurnDriver` (or anything else) which player is
AI-controlled. This ADR adds the minimal field needed, owned by Game State & Turn Manager (not by
this ADR's `AI` module), mirroring the existing `faction` lock pattern exactly:

```gdscript
# On PlayerState (ADR-0001):
@export var is_ai_controlled: bool = false   # set once at Setup, immutable after Setup->PlayerTurn,
                                              # same lock semantics as PlayerState.faction
```

Set once at match setup (single-player-vs-AI skirmish: player 0 human, player 1 AI, per the
Vertical Slice's scope) and never written again — `apply_action`'s existing Setup→PlayerTurn
transition gate is the natural place to lock it, the same gate that already locks `faction`.

### 5. Approved query surface (the lint rule's allowlist, resolving TR-ai-014/AC-5/AC-6b)

Per the GDD's own "Coverage notes" (echoing the same routing decision this corpus already made for
Command & Action Interface's and Game HUD's Pass-Through Invariant claims), **CR-4's "no privileged
reads" claim is a static-analysis / code-review property, not a black-box runtime test.** This ADR
defines the allowlist a future lint check (owed to `godot-specialist`/CI, not authored here) verifies
`ai.gd` never reaches outside of:

- `GameState`: `clone()`, `active_player`, `current_ap(player)`, `current_credits(player)`, `entities()`,
  `entity_at(tile)`, `match_status`, `faction_of(player)`, `apply_action()` (called only by `AITurnDriver`,
  never by `AI` itself)
- `Movement.reachable(state, unit)`
- `Combat.legal_targets(state, unit)`, `Combat.legal_targets_from(state, unit, tile)`,
  `Combat.preview_damage(state, attacker, target)`
- `AP.can_afford(state, player, amount)`, `AP.current_ap(state, player)`
- `Credits.can_afford(state, player, amount)`, `Credits.current_credits(state, player)`,
  `Credits.credit_income(state, player)` (the second leg of the dual affordability gate, and the income
  projection `economy_value`/Economy-Tech `research_value` read — 2026-08-05 two-currency pivot)
- `BaseProduction.legal_build_tiles(state, player, structure_type)`, `BaseProduction.legal_deploy_tiles(state, producer, unit_type)`, `BaseProduction.completed_outpost_count(state, player)` (forward-declared, §7)
- `Research.legal_research_targets(state, lab)` (forward-declared, §7)
- `GridState.manhattan_distance`, `terrain_at`, `occupant_at` (only reached indirectly, through the above)
- Public typed fields on `EntityState`/`UnitState`/`StructureState`/`PlayerState` instances *already
  returned by* `entity_at()`/`entities()`/the query calls above (e.g. `target.hp`, `unit.attack`,
  `structure.build_cost`) — these are the approved read API per ADR-0001, not a violation; the
  boundary AC-5 actually cares about is `entities_by_id`/`GridState`'s raw packed-array internals,
  never touched directly by anything outside `GameState`/`GridState` themselves.

**AC-6b (never reads any Command & Action Interface UI/preview/hover artifact) holds by
construction**, not by a runtime check: `AI.choose_action`'s only parameter besides the turn-scoped
int is `state: GameState`, and `GameState` has no reference anywhere to any Presentation-layer
object (confirmed by ADR-0001's own "no rendering dependency anywhere in the class"). There is
nothing for `AI` to read even if it wanted to.

**AC-24's between-clone-and-commit rejection test needs no special seam.** Because `choose_action`
and the commit are already two separate calls (§1), a test can call `AI.choose_action(state, 0)` to
get an `Action`, mutate `state` directly (simulating the hypothetical race — e.g. destroy the
target), and then call `state.apply_action(action)` itself, asserting `ok == false`. No mock/DI
facade needed; the split module shape is the seam.

### 6. `AIConfig` — 16 tunables, cross-knob invariant enforced at load

New Resource, extending the `gameplay_config_storage` pattern (`EconomyConfig`/`UnitConfig`/
`CombatConfig` precedent) and loaded by the **same** thin `Balance`-style Autoload those already
use — no new loader Autoload:

```gdscript
class_name AIConfig extends Resource
@export var hp_per_ap: float = 1.5
@export var kill_denial_rate: float = 0.5
@export var economy_horizon: int = 6
@export var tech_value_horizon: int = 10
@export var economy_decay: float = 0.85
@export var max_economy_investments_per_turn: int = 2
@export var lethal_floor_bonus: float = 3.5
@export var pass_threshold: float = 0.15
@export var attacks_landed_per_turn_estimate: float = 1.5
@export var positional_value_per_tile_closed: float = 0.16
@export var setup_advance_bonus: float = 0.4
@export var retreat_hp_fraction: float = 0.30
@export var retreat_value_per_tile_fled: float = 0.20
@export var hq_siege_value: int = 12
@export var credit_to_ap_rate: float = 1.0     # NEW (2026-08-05 two-currency pivot). AI-only Credit→AP
                                                # exchange rate; safe range 0.5–2.0. Multiplies every
                                                # Credit-denominated cost leg AND value term so the two
                                                # currencies reconcile onto CR-3's single scale. 1.0 is the
                                                # derived 1:1 anchor (Credit costs == old AP costs).
@export var score_tie_epsilon: float = 1e-6
@export var commit_pacing_sec: float = 0.35   # AITurnDriver-only; not a GDD-named scoring knob,
                                                # but lives here since it's the same tuning surface
```

`REACHABILITY_MULTIPLIER`'s fixed `{0.9, 1.0, 1.1}` band and `CANCEL_REFUND_RATE` are **not**
`AIConfig` fields: the GDD itself calls the multiplier band "fixed 3-band" (deliberately not meant
to be casually retuned — kept as code constants inside `AI`), and `CANCEL_REFUND_RATE` is Base &
Production-owned (the GDD's own Tuning Knobs table says so) — `AI` reads it from
`BaseProductionConfig` rather than duplicating it (note it is now Credit-denominated and the AI's
`cancel_build_value` converts it by `credit_to_ap_rate`, matching the GDD's Edge-Cases treatment).
This keeps `AIConfig`'s count at exactly the **16** knobs TR-ai-007 names as externally tunable
(the pre-pivot 15 plus `credit_to_ap_rate`).

**Cross-knob invariant, enforced at load, not left as a comment (now AP-equivalent, coupling in
`credit_to_ap_rate` — 2026-08-05 re-validation):** the `Balance`-style loader Autoload, immediately
after loading `AIConfig`, computes the **AP-equivalent** first-outpost economy ceiling
`economy_ceiling_score = OUTPOST_BONUS_TIER1 * Σ_{t=1}^{economy_horizon} economy_decay^t /
first_economy_outpost.build_cost` (where `build_cost` is now the Credit price 4) and asserts
`lethal_floor_bonus > economy_ceiling_score * credit_to_ap_rate`, failing loudly (`assert()`,
load-time, before the match can start) if a tuning pass raised
`economy_horizon`/`economy_decay`/**`credit_to_ap_rate`** without raising `lethal_floor_bonus` to
match — resolving TR-ai-008/QQ-07 as a real automated check instead of a documentation-only warning.

**Re-validation at default tuning (2026-08-05):** at `economy_horizon` 6, `economy_decay` 0.85,
`build_cost` 4, and `credit_to_ap_rate` 1.0, `economy_ceiling_score ≈ 1.77` (the pivot-neutral ceiling
the GDD states, measured against the Credit `build_cost` alone — the conservative worst case that
ignores the AP build surcharge's help), so `lethal_floor_bonus` (3.5) `> 1.77 × 1.0 = 1.77` holds with
comfortable headroom — CR-7 is preserved by the pivot. Because the ceiling is now **linear in
`credit_to_ap_rate`**, the invariant holds up to rate **≈1.98** (`1.77 × 1.98 ≈ 3.50`) before the
default `lethal_floor_bonus` is breached; the GDD's AC-38 pins the worked violation at rate 2.0
(≈1.765 × 2 ≈ 3.53 > 3.5). Any future rate change past ≈1.98 (or any `economy_horizon`/`economy_decay`
increase) must recompute `economy_ceiling_score × credit_to_ap_rate` and raise `lethal_floor_bonus` to
stay above it — the load-time assert above is exactly what flags this (GDD OQ-11).

### Architecture Diagram

```
   Game State & Turn Manager's turn handoff
   (start_turn() makes player P active; P.is_ai_controlled == true)
        │
        ▼
   AITurnDriver.run_ai_turn(state)  ── Node, owns pacing only ──┐
        │  loop:                                                │
        │    action = AI.choose_action(state, econ_count) ─────▶│  AI (static, headless, RefCounted)
        │      │                                                │    clone() → enumerate all verbs
        │      │  (null → break)                                │    → score (AIConfig) → return best
        │    result = state.apply_action(action)  ──────────────▶  GameState (ADR-0002 pipeline)
        │      │  fires action_applied (ADR-0004) synchronously  │    (same path a human commit takes)
        │    await commit_pacing_sec timer                       │
        │  end loop
        │  state.apply_action(EndTurnAction)
        ▼
   next start_turn() (opponent's turn)
```

### Key Interfaces

```gdscript
# ai.gd — top-level file, class_name AI extends RefCounted, no instance state
static func choose_action(state: GameState, economy_investments_committed: int) -> Action  # nullable

# ai_turn_driver.gd — top-level file, class_name AITurnDriver extends Node
func run_ai_turn(state: GameState) -> void   # awaits AIConfig.commit_pacing_sec between commits

# ai_config.gd — top-level file, class_name AIConfig extends Resource (16 @export knobs incl.
#                credit_to_ap_rate, see §6)

# Forward-declared (see §7):
# static func legal_build_tiles(state: GameState, player: int, structure_type) -> Array[Vector2i]      # BaseProduction
# static func legal_deploy_tiles(state: GameState, producer: StructureState, unit_type) -> Array[Vector2i]  # BaseProduction
# static func legal_research_targets(state: GameState, lab: StructureState) -> Array                   # Research

# New field on PlayerState (ADR-0001):
# @export var is_ai_controlled: bool = false   # set once at Setup, locked identically to `faction`
```

## Alternatives Considered

### Alternative A (module shape): Headless static `AI` + external paced `AITurnDriver` — CHOSEN
- **Pros**: Satisfies TR-ai-001 (headless) and TR-ai-013 (streamed) simultaneously without
  compromise; mirrors the established `Movement`/`Combat`/`AP` static-utility precedent exactly;
  `choose_action` alone is directly unit-testable for every "Logic"-typed AC with zero scene tree.
- **Cons**: Two files instead of one; the cadence-cap counter has to be threaded through as an
  explicit parameter rather than living as internal state.
- **Rejection Reason**: n/a (chosen).

### Alternative B: `AI` owns the whole loop and its own pacing (`Node`/coroutine)
- **Description**: A single `AI` class extends `Node`, contains the loop, and `await`s its own
  timers between commits.
- **Pros**: One file, one entry point (`AI.run_turn(state)`), no driver/scoring split to keep in sync.
- **Cons**: Directly violates TR-ai-001 — a scene-tree-coupled class cannot be instantiated or
  driven from a headless unit test the way `AC-2` through `AC-33` require; every "Logic"-typed AC
  in the GDD would degrade to "Integration" (needs a running `SceneTree`), which is a strictly
  worse test posture the GDD explicitly avoided for the other Core systems.
- **Rejection Reason**: Fails the GDD's own explicit headless requirement; no offsetting benefit
  once the split costs almost nothing (a two-file, ~15-line driver).

### Alternative C: Event-driven — AI reacts to `action_applied` to pick its next move
- **Description**: `AI` subscribes to the `action_applied` signal and, on each fire where the new
  `active_player` is AI-controlled, computes and commits its next action from inside the signal
  handler — no explicit loop anywhere.
- **Pros**: Fully decoupled from any driver; "just another signal subscriber," consistent with
  ADR-0004's event architecture.
- **Cons**: A signal handler reacting to its own emitted signal (the AI's own `apply_action` inside
  the handler re-fires `action_applied`, re-entering the same handler) is a synchronous re-entrant
  call chain with no natural place to insert pacing — reproducing Alternative B's headlessness
  problem (pacing needs `await`, which needs a `Node`) while additionally making the control flow
  harder to reason about (a recursive signal handler vs. an explicit `while` loop) and harder to
  unit-test as a whole-turn sequence (AC-3, AC-9 want "run a full AI turn and inspect the ordered
  result," which a signal-reactive design has no single call site for).
- **Rejection Reason**: Strictly worse than Alternative A on both headlessness and testability,
  for no offsetting benefit — `duplicate_deep()` clones carry zero signal connections anyway
  (registry: `event_dispatch_shape`), so an event-driven AI would need its subscription re-wired
  per clone regardless, which the pull-based `choose_action(state)` design never has to think about.

### Alternative (enumeration): Materialize full candidate array, then `sort()`
- **Description**: Build an `Array` of every `(action, score, ap_equiv_cost, entity_id)` candidate this
  iteration, then sort and take the head.
- **Pros**: Simpler to log/inspect the whole candidate set for debugging; a single well-tested
  `sort()` call instead of a hand-written tie-break comparator used during a running-best scan.
- **Cons**: Adds an `O(candidates)` allocation and an `O(candidates·log(candidates))` sort on top
  of the enumeration cost OQ-1 already flags as the dominant perf risk (`O(N²·W·H)`), for a result
  that only ever needs the single maximum, not a full ordering.
- **Rejection Reason**: Streaming max-scan gets the identical answer (same comparator, same
  tie-break) for strictly less work — chosen given OQ-1's explicit perf sensitivity.

### Alternative (invariant enforcement): Dedicated offline validation tool
- **Description**: A standalone script/CI tool that validates `AIConfig.tres` against the
  `LETHAL_FLOOR_BONUS > economy_ceiling_score × CREDIT_TO_AP_RATE` invariant, run manually or in CI,
  separate from the runtime load path.
- **Pros**: No runtime assert cost; can run without booting the game.
- **Cons**: Relies on someone remembering to run it after any tuning pass — exactly the "silent
  regression on a future retune" TR-ai-008 exists to prevent. A load-time assert cannot be forgotten.
- **Rejection Reason**: The load-time assert is strictly more robust for near-zero cost (one
  computation, once, at config load — not a hot path).

## Consequences

### Positive
- `AI.choose_action` is unit-testable exactly like `Movement.reachable`/`Combat.legal_targets` —
  every "Logic"-typed AC in the GDD (the large majority) needs no scene tree, no timers, no mocks.
- The cadence-cap counter living outside `AI` (as an explicit parameter) means `AI` never
  accretes turn-lifecycle state — it stays as stateless as `Movement`/`Combat`/`AP`, so a future
  difficulty-tier system (OQ-4) or per-faction weighting (OQ-6) can wrap/parametrize it without
  fighting hidden state.
- The `choose_action`/commit split makes AC-24 (stale-clone rejection) trivially testable with no
  new mock/DI machinery — a direct benefit of the module boundary, not an added test seam.
- The load-time cross-knob assert makes TR-ai-008 a real safety net instead of a comment a future
  tuning pass could silently violate.
- `AITurnDriver` introduces the project's first reusable "paced multi-commit loop" pattern —
  available if a future system (e.g. a replay/fast-forward mode) needs the same shape.

### Negative
- Two new files (`ai_turn_driver.gd` alongside `ai.gd`) plus the module boundary to keep in sync —
  a contributor could be tempted to fold pacing logic into `AI` "for convenience," re-breaking
  headlessness. Mitigated by the lint rule (§5) and this ADR's explicit rejection of Alternative B.
  Wait — the lint rule only checks the *query* boundary, not the Node/RefCounted boundary; add a
  second, cheap check to the same lint pass: `ai.gd` must not `extends Node` and must contain no
  `await`.
- `PlayerState.is_ai_controlled` is a new field on an already-Proposed ADR (ADR-0001) that this ADR
  introduces from the AI side — ADR-0001 itself is not edited here (out of this ADR's scope to
  modify another ADR's file), so implementation must land the field in `PlayerState` as part of
  this epic, with a note added to ADR-0001 pointing here (tracked as a follow-up, not blocking).

### Risks
- **Enumeration cost (OQ-1) is still an open question this ADR does not close** — it documents the
  chosen strategy (full re-enumeration, streaming max-scan) and leaves the numeric budget to the
  QQ-06 spike per Status. If the spike shows the budget is missed, OQ-1's pre-authorized
  incremental-invalidation substitution is the fallback — but per OQ-1's own condition, it may not
  land without a differential-test proof of identical ranking/tie-break behavior against the
  strategy this ADR describes now.
- **A future contributor implementing `_score_move_and_attack_candidates` etc. could reach into a
  raw field instead of the approved query surface** (e.g. `unit.hp` off a stale reference instead of
  through `entity_at()`) — mitigated by the lint rule (§5) and code review, same mitigation this
  corpus already relies on for Command & Action Interface's and Game HUD's identical claims.
- **`is_ai_controlled` lock timing must match `faction`'s lock exactly** — if a future edit moves
  the Setup→PlayerTurn gate without also covering `is_ai_controlled`, a mid-match reassignment could
  silently redirect a human's turn to `AITurnDriver` or vice versa. Mitigated by implementing both
  locks in the same `apply_action` validation branch, not two independent checks.
- **The §6 cross-knob invariant `assert()` is stripped from release exports unless debug asserts are
  enabled** (godot-specialist, 2026-07-24) — a bare `assert()` no-ops in a shipped build, which would
  silently defeat TR-ai-008's whole purpose (the invariant would be enforced in the editor/tests but
  not in the shipped game). This is a **shared** risk across every `*Config` load-time assert in the
  corpus (`EconomyConfig`/`UnitConfig`/`CombatConfig`), not unique to this ADR. Mitigation: the
  `Balance`-style loader must enforce this invariant with an unconditional check that fails in release
  too (a `push_error` + hard `OS.crash`/quit, or a release-surviving guard), **not** a bare `assert()`
  — flagged for a single corpus-wide loader convention rather than a per-ADR fix, but called out here
  because this specific invariant guards a gameplay-correctness property (CR-7), not just a tuning
  sanity check. **The 2026-08-05 pivot adds a third coupled knob** — `CREDIT_TO_AP_RATE` scales the
  economy ceiling linearly, so the invariant `LETHAL_FLOOR_BONUS > economy_ceiling_score ×
  CREDIT_TO_AP_RATE` can now also be tripped by a rate change alone (it holds only up to ≈1.98 at the
  default floor). This *widens* the surface a silent-in-release assert would fail to catch, reinforcing
  the case for the release-surviving guard.
- **Minor, non-blocking (godot-specialist, 2026-07-24):** (a) if a future "pause mid-AI-turn" feature
  is ever added, `AITurnDriver` will need an explicit `process_mode` override so its
  `create_timer()` pacing does not stall against a paused tree — no pause feature exists in scope
  today. (b) `Array.sort()` on the entity-id list (§2) is not a guaranteed-stable sort, but the ids
  are unique (ADR-0001/0003), so there are no equal keys for instability to affect — revisit only if
  enumeration ever sorts non-unique-keyed tuples (it does not today; the tie-break is a separate
  hand-written comparator, never fed through `sort()`).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ai-opponent.md | TR-ai-001: headless, render-decoupled; evaluate clone, commit real | `AI.choose_action` clones internally, never calls `apply_action`; commit is the caller's (`AITurnDriver`'s) job |
| ai-opponent.md | TR-ai-002: AI acts only as second `active_player` in its own Action phase | `AITurnDriver.run_ai_turn` is invoked only when `PlayerState.is_ai_controlled` is the new `active_player` |
| ai-opponent.md | TR-ai-003: iterative evaluate→commit loop | `AITurnDriver.run_ai_turn`'s `while` loop |
| ai-opponent.md | TR-ai-004: enumerate via the named query set | §2's per-verb enumeration helpers, each calling only §5's approved surface |
| ai-opponent.md | TR-ai-005: every candidate costed/affordability-gated before scoring | Each enumeration helper applies the **dual** gate (§2) before folding a candidate into the running best — `AP.can_afford` for move/attack; `AP.can_afford` AND `Credits.can_afford` for produce/build/research (CR-4a, GDD AC-36) |
| ai-opponent.md | TR-ai-006: single normalized `action_score`, verb-dispatch, no hardcoded priority | `_is_better` comparator operates on one `float` regardless of which helper produced it; the score is `ap_equiv_value / ap_equiv_cost`, both in AP-equivalent units so the two currencies stay on one scale (§2) |
| ai-opponent.md | TR-ai-007: 16 knobs externally tunable (15 pre-pivot + `CREDIT_TO_AP_RATE`) | `AIConfig` Resource (§6) |
| ai-opponent.md | TR-ai-008: enforce `LETHAL_FLOOR_BONUS > economy_ceiling_score × CREDIT_TO_AP_RATE` invariant | Load-time assert in the `Balance`-style loader, now AP-equivalent and coupling in `credit_to_ap_rate` (§6); re-validated at defaults (holds; linear in the rate up to ≈1.98) |
| ai-opponent.md | TR-ai-009: guaranteed loop termination | `choose_action` returning `null`, or `match_status == GAME_OVER`, both explicit `break`/`return` points in `run_ai_turn` |
| ai-opponent.md | TR-ai-010: `apply_action()` rejection handled defensively | `run_ai_turn`'s `if not result.ok: continue` |
| ai-opponent.md | TR-ai-011: deterministic selection, ties by cost then `entity_id` | `_is_better` comparator (§2), now keyed on `ap_equiv_cost` (`ap_cost + credit_cost × CREDIT_TO_AP_RATE`) then `entity_id` (GDD AC-23) |
| ai-opponent.md | TR-ai-012: perf budget for the loop | Flagged as the Status-gating QQ-06 spike; strategy documented, numeric ceiling deferred |
| ai-opponent.md | TR-ai-013: incremental rendering, not silent batch | `AITurnDriver`'s per-commit `await` (§3) — pacing lives outside the headless `AI` module |
| ai-opponent.md | TR-ai-014: query-call instrumentation seam | Resolved as a static-analysis lint allowlist (§5), not runtime DI, per the GDD's own routing note |
| ai-opponent.md | TR-ai-015: field-level diff harness vs. human commits | Satisfied by construction — `AITurnDriver` commits through the identical `apply_action` pipeline (ADR-0002) a human's UI uses; no AI-specific mutation path exists to diverge |
| ai-opponent.md | TR-ai-016: fixture + fuzz corpus, `current_ap` never negative | Enabled by `AI.choose_action`'s headlessness (§1) — the corpus is ordinary unit tests, no scene tree |
| ai-opponent.md | TR-ai-017: Grid queries for positional/retreat scoring, tiles-normalized | `_score_move_and_attack_candidates` reads `GridState.manhattan_distance` only via `Movement.reachable`'s already-computed tiles (§2, §5) |
| ai-opponent.md | CR-4a / AC-36: dual affordability gate (economic candidate needs both AP surcharge and Credit legs affordable) | §2's dual gate — `_score_production_candidates`/`_score_build_and_economy_candidates`/`_score_research_candidates` enumerate only if `AP.can_afford` AND `Credits.can_afford` both pass (2026-08-05 pivot) |
| ai-opponent.md | CR-4a / CR-5 / AC-37: banked-Credit saving emerges from the greedy loop | `Credits.can_afford` reads *banked*, uncapped Credits (§2); an unaffordable expensive candidate is simply not enumerated until income lifts the balance — no explicit "save up" planner in `run_ai_turn` |
| ai-opponent.md | AC-38: `CREDIT_TO_AP_RATE` cross-knob invariant (rate ≳1.98 breaches `LETHAL_FLOOR_BONUS`) | Load-time assert on `lethal_floor_bonus > economy_ceiling_score × credit_to_ap_rate` (§6); the rate reaches every value term via `ap_equiv_value` (§2) |
| game-state-turn-manager.md | (implicit) "active player, human or AI" needs a data-model backing | New `PlayerState.is_ai_controlled` field (§4) |

## Performance Implications
- **CPU**: The dominant cost is enumeration (OQ-1's `O(N²·W·H)` shape), not scoring itself (each
  formula is O(1) arithmetic). The streaming max-scan (§2) removes the *additional* allocation/sort
  cost an array-then-sort design would add on top of that, but does not change the enumeration
  complexity itself — that remains the QQ-06 spike's job to measure and, if needed, OQ-1's
  pre-authorized caching strategy to address later.
- **Memory**: One `lookahead` clone per `choose_action` call (per-commit, not per-candidate) — the
  same `clone()` cost every other AI-adjacent system already budgets for (`clone()` is "the
  designated lookahead mechanism," per the GDD). No candidate array is retained.
- **Load Time**: Negligible — one new `AIConfig.tres` load + one assert, alongside the existing
  `EconomyConfig`/`UnitConfig`/`CombatConfig` loads.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Headlessness**: `AI.choose_action` is called from a plain `GDScript` unit test with no
  `SceneTree`/`Node` instantiated anywhere in the test — if this ever requires a running scene
  tree, TR-ai-001 has regressed.
- **Streaming**: an integration test drives `AITurnDriver.run_ai_turn` inside a running scene tree
  and asserts `action_applied` fires once per commit with the configured `commit_pacing_sec` gap
  between them (AC-9b; the QQ-06 spike set the ceiling at ~3.7 ms p95 per pass — 2026-07-25, PASS).
- **Cross-knob invariant**: loading an `AIConfig.tres` with `economy_horizon`/`economy_decay`/**`credit_to_ap_rate`**
  raised toward their safe-range maxima without also raising `lethal_floor_bonus` must fail the load-time
  assert, not silently start the match. Concretely, `credit_to_ap_rate = 2.0` at default
  `economy_horizon`/`economy_decay`/`lethal_floor_bonus` must fail (≈1.765 × 2 ≈ 3.53 > 3.5), and rate 1.0
  must pass (≈1.77 < 3.5) — the re-validated defaults per §6 (GDD AC-38).
- **Determinism**: run a fixed board+AP-total+Credit-total AI turn twice via `AITurnDriver`/`choose_action` and
  assert an identical ordered sequence of committed actions (AC-3); `credit_to_ap_rate` is a fixed per-turn
  constant, so it introduces no new nondeterminism.
- **Dual affordability gate**: construct an economic candidate the AI can afford on exactly one leg (Credits
  sufficient but AP surcharge not, or vice versa) and assert it is **not** enumerated (neither pool touched);
  with both legs affordable, assert it is enumerated and scored (AC-36). Across successive turns with rising
  Credit income and no competing above-threshold play, assert the AI leaves Credits **banked** and commits an
  expensive build only once its banked balance clears the price (AC-37).
- **Tie-break**: construct two candidates with `action_score` values differing by less than
  `AIConfig.score_tie_epsilon`, differing `ap_equiv_cost` (`ap_cost + credit_cost × credit_to_ap_rate`), and
  assert the lower-`ap_equiv_cost` one is chosen (AC-23), then repeat with equal `ap_equiv_cost` and differing
  `entity_id`.
- **Cadence cap**: construct a state with more than `max_economy_investments_per_turn` clearing
  candidates and assert `run_ai_turn` commits at most that many before falling through to
  non-economy actions (AC-30).

## Related Decisions
- ADR-0001: State model ownership & lifecycle (`GameState`/`clone()`/`entities()`; this ADR adds
  `PlayerState.is_ai_controlled`, to be reflected there as a follow-up)
- ADR-0002: `apply_action` command model (the sole commit path `AITurnDriver` uses — no AI-specific
  mutation path exists)
- ADR-0003: Determinism & RNG isolation (binds this ADR's entity-iteration-order decision, §2)
- ADR-0004: Event/signal architecture (`action_applied` is how presentation observes each streamed commit)
- ADR-0006: AP & Credits Economy (two-resource; `AP.can_afford`/`current_ap` **and**
  `Credits.can_afford`/`current_credits`/`credit_income`; `ap_economy_module_shape`/
  `gameplay_config_storage` precedents this ADR's `AI`/`AIConfig` mirror; the two-currency split
  this ADR converts to AP-equivalent via `CREDIT_TO_AP_RATE`)
- ADR-0007: Entity stat schema (`produce_cost`/`build_cost`/`hp`/`attack` fields the formulas read)
- ADR-0009: Movement/reachable search (`Movement.reachable()` — candidate move tiles)
- ADR-0010: Combat resolution (`Combat.legal_targets`/`legal_targets_from`/`preview_damage`;
  `destroy_entity()`'s win-check path an AI lethal commit rides identically to a human's)
- ai-opponent.md — the GDD this ADR implements; ADR-0011 supersedes none of it, only resolves its
  module-shape/loop-architecture Open Questions (OQ-1's strategy choice, TR-ai-008/014's enforcement
  mechanism) that the GDD explicitly deferred to architecture.
