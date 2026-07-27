# ADR-0003: Deterministic Simulation & RNG Isolation

## Status
Accepted

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (no RNG/determinism changes 4.4→4.6), `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None. Uses `RandomNumberGenerator` (stable, pre-cutoff) with an explicit seed |
| **Verification Required** | None. Engine-specialist review deliberately skipped: this is a pure-policy ADR with no post-cutoff or engine-specific API surface — `RandomNumberGenerator` seeding behavior is stable, in-training-data Godot behavior. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (State model — the integer-only fields this ADR constrains live there) |
| **Enables** | ADR-0005 (Grid seeded map-gen), ADR-0009 (Movement iteration order + fixed-point penalty), ADR-0011 (AI tie-break determinism); reinforces ADR-0002 (pipeline stays RNG-free) |
| **Blocks** | Epic "Foundation: Game State Core" — determinism is a precondition for the entire automated test suite and for AI lookahead |
| **Ordering Note** | Cross-cutting policy ADR. Every gameplay ADR must conform to the rules here; best pinned before the Core-verb ADRs are written |

## Context

### Problem Statement
GDD Core Rule 6 requires that *"given the same initial state and the same ordered sequence of
actions, the resulting state is identical every run. No RNG participates in turn or state
advancement."* ADR-0001 gave us the state model and ADR-0002 the mutation pipeline, but determinism
is a **cross-cutting property** no single-system ADR owns: it constrains what RNG is allowed and
where, whether state may hold floats, how iteration order is fixed, and how the whole thing is kept
from silently rotting. This ADR sets those rules once, for every system to conform to. Two consumers
make it non-negotiable: the automated test suite (a nondeterministic sim cannot have stable
assertions) and the AI's `clone()`-based lookahead (a hypothetical future must resolve the same way
every time it is evaluated).

### Constraints
- Must uphold ADR-0001 (`Resource` state, `clone()` via `duplicate_deep()`) and ADR-0002
  (`apply_action` pipeline) without weakening them.
- Must accommodate the one place randomness is legitimately needed: Grid procedural map generation
  at load (TR-grid-009).
- Must accommodate the AI's use of *floating-point scoring* (ai-opponent GDD) without letting it
  make state nondeterministic.
- No netcode and no portable/cross-machine replay in Vertical-Slice scope — so full cross-platform
  bit-determinism is not a requirement (it would be for lockstep multiplayer, which is out of scope).

### Requirements
- No engine RNG in state transitions (TR-gamestate-008, TR-apecon-013, TR-combat-013).
- No floating-point-driven nondeterminism in state (TR-gamestate-009).
- Deterministic, container-independent iteration order for order-sensitive operations
  (TR-movement-006, -007).
- Fractional gameplay coefficients represented without float state (TR-movement-011).
- Seeded, reproducible procedural map generation (TR-grid-009).
- AI selection deterministic, with float scoring reproducible on the same build and ties broken by
  integer keys (TR-ai-011).

## Decision

**Adopt same-build integer-state determinism** (Alternative B). The guarantee is: *for a given build,
identical initial state + identical ordered action sequence ⇒ field-wise-identical resulting state,
on any platform* — because all **state** is integer-valued, integer arithmetic is exact and
platform-independent. Four rules make this hold:

**Rule 1 — RNG is isolated to map generation, via a dedicated seeded instance.** The only randomness
in the entire project is Grid procedural map generation, run **once at load**. It uses a dedicated
`RandomNumberGenerator` instance whose `seed` is the map definition's `PROC_SEED` (TR-grid-009). The
global `randi()` / `randf()` / `randomize()` / `seed()` functions are **banned project-wide** — they
share one hidden global stream, so any stray call anywhere (an effect, a test, a shader helper)
silently perturbs the sequence. No RNG of any kind touches per-turn state advancement.

**Rule 2 — All state is 100% integer.** Every field on `GameState`, `PlayerState`, `EntityState`,
and `GridState` is `int` / `enum` / `Vector2i` — **no float in state, ever**. The handful of
fractional gameplay coefficients (`SOFT_MOVE_PENALTY`, `CANCEL_REFUND_RATE`) are stored as **scaled
integers** (e.g. `PENALTY_X10 = 15` for ×1.5) and computed with integer ceil/floor-division
(TR-movement-011, TR-baseprod-013). Integer arithmetic is bit-identical across platforms; this is
what lets the guarantee hold platform-independently for state.

**Rule 3 — Iteration order is a property of the data, not the container.** Spatial iteration uses
flat arrays indexed by `index(x,y) = y*GRID_WIDTH + x` (TR-movement-006). Any order-sensitive pass
over `entities_by_id` — batch build/research completion in one tick, AI action enumeration,
multi-event resolution within one `apply_action` — iterates a list **sorted by a stable key**
(`entity_id`, or tile index), never relying on `Dictionary` hash or insertion order. (Godot
dictionaries do preserve insertion order, but coupling correctness to insertion history is fragile
across `clone()`/rebuild — the movement GDD explicitly distrusts it, TR-movement-006/007.)

**Rule 4 — Floats live only outside state, and never drive a nondeterministic choice.** Floating
point is permitted in exactly two places: (a) the AI's **advisory scoring** (never written back to
state), and (b) **pure presentation** (animation curves, tweens). Where a float could influence a
*decision*, it must not select nondeterministically: the AI resolves score ties by integer keys —
`score` difference `< SCORE_TIE_EPSILON` ⇒ pick lowest `ap_cost`, then lowest `entity_id`
(TR-ai-011). Consequently AI float-score reproducibility is scoped to the **same build/machine**
(cross-platform float bit-equality is explicitly *not* promised, per the AI GDD), while the resulting
*state* remains fully integer-deterministic everywhere.

**Scope note:** cross-platform *bit*-determinism of the whole simulation (needed only for lockstep
netcode or a replay file shared between machines) is **out of scope** — the VS is single-player with
no netcode. If lockstep multiplayer is ever added, Rule 4's float scoring would need to move to
fixed-point (a localized, AI-only change); Rules 1–3 already satisfy cross-platform state determinism.

### Architecture Diagram

```
  ┌─────────────────────────── STATE (integer-only) ────────────────────────────┐
  │  GameState / PlayerState / EntityState / GridState                            │
  │  int · enum · Vector2i           ← no floats, ever (Rule 2)                    │
  │  fractional coeffs → scaled ints (PENALTY_X10) + integer ceil/floor-div        │
  └──────────────────────────────────────────────────────────────────────────────┘
        ▲ mutated only by apply_action (ADR-0002), which contains NO RNG (Rule 1)
        │
  ┌─────┴───────────────┐        ┌──────────────────────────────────────────────┐
  │ Grid map-gen (load) │        │ AI scoring (advisory)      Presentation        │
  │ dedicated seeded    │        │ floats OK, never written    floats OK          │
  │ RandomNumberGenerator│       │ back to state; ties broken   (anim/tween)      │
  │ seed = PROC_SEED    │        │ by int keys (Rule 4)                            │
  │ (Rule 1 — only RNG) │        └──────────────────────────────────────────────┘
  └─────────────────────┘
  Order-sensitive iteration: flat array (y*W+x) OR sort-by-entity_id — never hash order (Rule 3)
```

### Key Interfaces

```gdscript
# Rule 1 — the ONLY sanctioned RNG. Global randi()/randf()/randomize()/seed() are banned.
var rng := RandomNumberGenerator.new()
rng.seed = map_def.proc_seed          # explicit integer seed from the map definition
# ... map generation consumes `rng` exclusively, once, at load ...

# Rule 2 — scaled-integer fractional coefficient (no float in state)
const PENALTY_X10: int = 15            # represents ×1.5
func surcharge(move_cost: int) -> int:
    return (move_cost * PENALTY_X10 + 9) / 10     # integer ceil-div, exact & platform-independent

# Rule 3 — deterministic order-sensitive iteration
func entities_in_stable_order() -> Array:         # sorted by entity_id, not hash/insertion order
    var ids := entities_by_id.keys()
    ids.sort()                                     # stable, deterministic
    return ids.map(func(id): return entities_by_id[id])

# Rule 4 — AI tie-break by integer keys (float score never selects nondeterministically)
#   candidates sorted by: (-score bucket) then ap_cost asc then entity_id asc
#   two scores within SCORE_TIE_EPSILON are treated as tied → integer keys decide
```

## Alternatives Considered

### Alternative A: Full cross-platform bit-determinism (fixed-point everywhere)
- **Description**: No floats anywhere, including AI scoring — all math in fixed-point so the entire
  simulation is bit-identical across platforms and compilers.
- **Pros**: Enables lockstep netcode and replay files portable between machines.
- **Cons**: Forces the AI's scoring math (and any future weighting) into fixed-point, which is more
  code and harder to tune; pays a portability cost the VS has no consumer for.
- **Rejection Reason**: The VS is single-player with no netcode and no cross-machine replay. State is
  already integer-deterministic under Rule 2 without constraining AI scoring; buying full bit-
  determinism now is cost with no beneficiary. Reversible later (Rule 4 scope note) if netcode lands.

### Alternative B: Same-build integer-state determinism — CHOSEN
- **Description**: State is integer-only (bit-identical on any platform); floats confined to
  non-state advisory computation with integer tie-breaks.
- **Pros**: Matches exactly what the GDDs already assume; state determinism holds cross-platform;
  AI scoring stays in natural floating point; minimal discipline beyond "no float in state."
- **Cons**: AI float-score reproducibility is same-build only (not cross-platform) — acceptable and
  already documented in the AI GDD.
- **Rejection Reason**: n/a (chosen).

### Alternative C: Best-effort (seed the RNG, no further discipline)
- **Description**: Seed randomness at match start; otherwise allow floats in state and rely on
  Godot's ordered dictionaries.
- **Pros**: Least upfront discipline.
- **Cons**: Float accumulation and hash/insertion-order coupling make the sim subtly irreproducible;
  the test suite cannot make stable assertions and AI lookahead can disagree with itself.
- **Rejection Reason**: Unshippable — it defeats the two consumers (tests, AI) determinism exists for.

## Consequences

### Positive
- The whole test suite can assert on exact state; a golden-replay test becomes possible (Validation).
- AI `clone()`-lookahead always resolves a given hypothetical identically — no flaky evaluations.
- State is bit-identical across platforms for free (integer arithmetic), pre-conditioning any future
  netcode/replay without committing to fixed-point now.
- "One banned global RNG" is a simple, lintable rule with no gray area.

### Negative
- **Scaled-integer discipline** for fractional coefficients (e.g. `PENALTY_X10`) is slightly less
  readable than a float literal and must be applied consistently.
- **Sort-for-order** adds a small cost (a `keys().sort()`) to order-sensitive entity passes vs. raw
  dictionary iteration — negligible at VS entity counts, and only where order actually matters.
- AI float scoring is same-build reproducible only; a cross-platform replay of an AI turn is not
  guaranteed (accepted; documented).

### Risks
- **A stray `randf()`/`randi()` call** (in an effect, a helper, a test) would silently break map-gen
  reproducibility by sharing the global stream. Mitigation: ban is registered as a forbidden pattern
  + a grep/lint check in CI for `randi(`/`randf(`/`randomize(`/`seed(` outside the sanctioned RNG.
- **A float sneaking into a state field** would reintroduce nondeterminism. Mitigation: the
  golden-replay + field-wise-equality test catches divergence; a schema/review check flags float
  fields on state classes.
- **Relying on dictionary order** somewhere order matters. Mitigation: Rule 3 + the determinism test
  exercising a batch-completion / multi-event scenario where order would show.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-state-turn-manager.md | TR-gamestate-008: fully deterministic transitions, no RNG | Rule 1 (RNG isolated to map-gen); Rule 3 (stable order) |
| game-state-turn-manager.md | TR-gamestate-009: no float-driven nondeterminism in state | Rule 2 (state 100% integer) |
| ap-economy.md | TR-apecon-013: bit-identical AP trajectory, no RNG | Rules 1 + 2 (integer AP, no RNG in spend/income) |
| combat-resolution.md | TR-combat-013: identical attack on cloned states → equal result | Rules 1 + 2 (integer damage, no RNG) |
| movement-system.md | TR-movement-006/007: flat-array visited table, pinned expansion order | Rule 3 |
| movement-system.md | TR-movement-011: `SOFT_MOVE_PENALTY` as fixed-point int, integer ceil-div | Rule 2 (scaled integers) |
| grid-terrain.md | TR-grid-009: seeded procedural gen, byte-identical per seed | Rule 1 (dedicated seeded RNG, seed in map-def) |
| ai-opponent.md | TR-ai-011: deterministic selection, no engine RNG, integer tie-breaks | Rule 4 (floats advisory-only; ties by ap_cost then entity_id) |

## Performance Implications
- **CPU**: Integer arithmetic is as fast or faster than float; `keys().sort()` on order-sensitive
  passes is O(n log n) over a small entity set — negligible. No RNG in the hot path.
- **Memory**: N/A.
- **Load Time**: Seeded map-gen runs once at load; unchanged.
- **Network**: N/A (and the integer-state guarantee pre-conditions future netcode).

## Migration Plan
N/A — greenfield. The rules here shape every system as it is written.

## Validation Criteria
- **Golden-replay determinism**: apply a fixed ordered action sequence to two freshly-constructed
  states; assert the two results are field-wise-equal (the GDD Core Rule 6 AC). Run in CI as a
  blocking gate.
- **Clone parity** (with ADR-0001): mutating a `clone()` never affects the original, and two clones
  of the same state are field-wise-equal.
- **AI tie-break determinism**: a scenario with two equal-score candidate actions always selects the
  same one (lowest `ap_cost`, then lowest `entity_id`) across repeated runs.
- **No-global-RNG check**: a CI grep asserts no `randi(`/`randf(`/`randomize(`/`seed(` appears
  outside the single sanctioned map-gen `RandomNumberGenerator`.
- **Order-sensitivity**: a batch-completion scenario (two structures completing in one tick) resolves
  identically regardless of entity insertion order.

## Related Decisions
- ADR-0001: State model ownership & lifecycle (the integer-only state fields this ADR constrains)
- ADR-0002: apply_action command model (the pipeline this ADR keeps RNG-free and stable-ordered)
- ADR-0005: Grid representation & map format (owns `PROC_SEED` and the seeded map-gen this ADR sanctions)
- ADR-0009: Movement (flat-array visited table + fixed-point penalty conform to Rules 2/3)
- ADR-0011: AI Opponent (float scoring + integer tie-breaks conform to Rule 4)
- `docs/architecture/architecture.md` — Architecture Principle 3 ("Determinism is a correctness
  property") is the prose statement of this ADR
