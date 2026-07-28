# ADR-0018: Research & Tech Mechanics — Tech Unlocks, Per-Lab Research State, and Selection

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 / Redot 26.2 (Godot-4.x-compatible) |
| **Domain** | Core (game logic / state mutation) |
| **Knowledge Risk** | LOW — pure GDScript logic (static class, PlayerState bool fields, Resource-ref scans); no engine subsystem, no rendering, no post-cutoff API surface |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; established-pattern precedent `adr-0017-base-production-mechanics` (sibling Core-mechanics ADR, same static-utility shape), `adr-0006` (config/static-utility), `adr-0007` (TechDef/StructureState schema, preload'd registry), `adr-0008` (advance_research_timers sequencing), `adr-0010` (on_lab_destroyed trigger) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None engine-specific. All queries are bounded by per-player Lab count (≤ handful) and the fixed 3-tech registry; no perf spike gate. |
| **Engine Review** | godot-specialist 2026-07-24 — NO BLOCKING issues, no minor notes. Confirmed: `RefCounted` static-utility shape, nullable `TechDef` Resource-ref field with `==` identity (`null == tech` → false; `current_research_target == tech` correct) and clean `duplicate_deep()` clone (null copies trivially; non-null preload'd `TechDef` stays SHARED per ADR-0007's confirmed finding, which explicitly covers `current_research_target` — the guarantee the post-clone `==` relies on), 3 `@export` bool `PlayerState` fields value-copy correctly, cross-Resource `cancel_refund_pct` read + integer-div floor, static cross-class dispatch, `Array[TechDef]` construction (no covariance trap). No deprecated/post-cutoff API. Matches ADR-0017/0007 exactly. TD-ADR strategic review skipped — Lean review mode. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameState/PlayerState — this ADR adds the 3 tech-unlock bool fields to PlayerState), ADR-0002 (apply_action verb dispatch, validate-before-mutate atomicity, stateless re-validation), ADR-0003 (determinism: no RNG, stable iteration order, integer state), ADR-0006 (AP `can_afford`/`spend`), ADR-0007 (TechDef templates + preload'd `Techs` registry, StructureState Lab fields `current_research_target`/`research_turns_remaining`), ADR-0017 (Research Labs are built/cancelled/destroyed via BaseProduction's structure lifecycle; `cancel_research` reuses `BaseProductionConfig.cancel_refund_pct`) |
| **Enables** | Closes TR-research-003/004/005 (the last 3 Partial TRs → 200/200 covered); unblocks ADR-0011 (AI research start/cancel + `legal_research_targets`) and ADR-0015/0016 (research menu + tech-status panel); unblocks the **Research/Tech epic**. Completes the 18-ADR plan. |
| **Blocks** | Research/Tech epic (start/cancel research, tech-unlock, per-Lab state stories) cannot start implementation until this ADR is Accepted |
| **Ordering Note** | Coordinates-not-depends with ADR-0008 (this ADR supplies the concrete `Research.advance_research_timers` body that ADR-0008 forward-declared and *sequences* at start-of-turn step 3, order-independent vs `advance_build_timers`), ADR-0010 (this ADR supplies the `Research.on_lab_destroyed` body that `GameState.destroy_entity` calls before Lab removal), ADR-0006/0007 (`economy_tech_income_bonus`, whose body ADR-0007 implements, reads this ADR's `has_economy_tech` flag; `ECONOMY_TECH_TIER_THRESHOLD` is AP-Economy-owned), and ADR-0012 (`legal_research_targets` folds `Faction.faction_allows`; `effective_research_cost`/`effective_research_time` are Research-owned `effective_*` sites, == base under Neutral) |

## Context

### Problem Statement
Research is the last system with no dedicated ADR for its *mechanics*. Three technical requirements were mis-parked and disclaimed by ADR-0010 (Combat):

- **TR-research-003** — Per-player tech-unlock: 3 terminal boolean flags (`has_attack_tech`/`has_defense_tech`/`has_economy_tech`), one-time permanent, surviving Lab destruction.
- **TR-research-004** — Per-Lab research state (`current_research_target` + `research_turns_remaining`), parallel Labs, cross-Lab mutual exclusion (the same tech may not be Under Research at two of a player's Labs).
- **TR-research-005** — `legal_research_targets(lab) -> set<tech>` excluding Completed + Under-Research-elsewhere; empty for an Under-Construction Lab.

The rest of Research is already owned: TechDef/Lab-field *schema* (ADR-0007), start/cancel verb *dispatch* + atomicity (ADR-0002), research-timer *sequencing* (ADR-0008), Lab-destruction *trigger* (ADR-0010), `economy_tech_income_bonus` *body* (ADR-0007, reads this ADR's flag), determinism policy (ADR-0003), Lab structure *lifecycle* (ADR-0017), faction `effective_*` framework (ADR-0012). This ADR owns exactly the tech-unlock representation and per-Lab research-selection mechanics.

### Constraints
- **Determinism (ADR-0003)**: pure functions of `GameState`; no RNG; integer state; stable iteration (Labs by `entity_id`, techs by registry order); clone-safe for AI look-ahead (research-tech.md Rule 9).
- **Single mutation vector (ADR-0002)**: start/cancel flow through `apply_action`; validate-before-mutate, no rollback.
- **Type identity by Resource-ref (ADR-0007)**: techs are `Techs.ATTACK_TECH`-style preload'd consts; `current_research_target` is a `TechDef` ref (or null = Idle); never a string/enum discriminator or a `load()`'d copy (`runtime_load_of_type_templates` forbidden).
- **Lab lifecycle is B&P's (ADR-0017)**: this ADR never builds/destroys the Lab structure; it reads Lab `build_status` and reuses `cancel_refund_pct`.

### Requirements
- Represent the 3 permanent per-player unlocks; make completion survive Lab loss.
- Own per-Lab research state, parallel-Lab independence, and cross-Lab same-tech mutual exclusion.
- Own `legal_research_targets`, `start_research`/`cancel_research` validate+apply, and the concrete `advance_research_timers` / `on_lab_destroyed` bodies.
- Satisfy every research-tech.md rule for start (Rule 3), exclusion (Rule 4), timer/completion (Rule 5), destruction-revert (Rule 6), cancel (Rule 7), live flags (Rule 8) — without re-owning the Lab lifecycle (ADR-0017), timer sequencing (ADR-0008), income math (ADR-0007), or unit buff formulas (Unit System).

## Decision

**`Research` is a static utility class** (`class_name Research extends RefCounted`, no instance state) exposing pure functions over `GameState`, exactly mirroring `BaseProduction` (ADR-0017), `AP` (ADR-0006), `Movement` (ADR-0009), `Combat` (ADR-0010). Start/Cancel are typed `Action` subclasses (ADR-0002) whose `validate`/`apply` the `apply_action` verb-enum dispatcher routes to `Research.validate_*` / `apply_*`. No `Research` instance lives on `GameState`.

### D1 — Tech unlocks: 3 named bool flags on PlayerState (TR-research-003)

Each permanent unlock is a bool field on `PlayerState`:

```gdscript
# PlayerState (ADR-0001 — this ADR formally adds these three fields, same follow-up
# pattern ADR-0008 used for starting_player, ADR-0011 for is_ai_controlled, ADR-0012 for faction)
@export var has_attack_tech: bool = false     # Setup-init false; @export for duplicate_deep() clone survival (ADR-0001)
@export var has_defense_tech: bool = false
@export var has_economy_tech: bool = false
```

- **Sole writer**: `advance_research_timers` (D5), which flips exactly one flag `true` on completion. Nothing else writes them; they are never reset to `false` (permanence).
- **Accessors** `has_attack_tech(state, player) -> bool` (etc.) are trivial getters read live by Unit System (`effective_attack`/`effective_defense`) and by ADR-0007's `economy_tech_income_bonus` (`has_economy_tech`).
- **Permanence / survive-Lab-loss is structural**: the flag lives on `PlayerState`, never on a Lab, so no Lab destruction can touch it (research-tech.md Rule 6/8). Confirmed against ADR-0008's registered `advance_research_timers` signature, which already names these three fields.
- The VS tech tree is fixed at 3 flat techs (GDD flat-tree toggle). A 4th tech is an explicit Alpha lever; it would add a 4th field (or, if the roster grows materially, a later ADR may migrate to a data-driven set — out of VS scope).

### D2 — Per-Lab research state + cross-Lab mutual exclusion (TR-research-004)

Per-Lab state lives on `StructureState` (ADR-0007 folded the Lab fields onto the generic `StructureState`):

```gdscript
current_research_target: TechDef        # null == Idle
research_turns_remaining: int           # meaningful only when target != null
```

- **Parallel Labs are independent**: each Lab tracks its own `(current_research_target, research_turns_remaining)`. A player builds a second Lab to research a *different* tech concurrently.
- **Cross-Lab same-tech mutual exclusion** is enforced at `validate_start_research` and mirrored in `legal_research_targets` (D4) by scanning the *same player's other Labs* for `current_research_target == tech` (Resource-ref equality). "Under Research at two of a player's Labs" is thereby structurally unreachable — a same-tech double-completion on one start-of-turn cannot occur (only *different* techs co-complete). Cross-*player* is unrestricted (Player B may research a tech Player A is researching).

### D3 — Tech status is DERIVED, not stored (TR-research-003/004)

There is **no separate per-(player,tech) status table**. The tri-state is computed:

```
status(state, player, tech):
    if has_<tech>_tech(state, player):                         -> COMPLETED
    elif any(lab.current_research_target == tech               -> UNDER_RESEARCH
             for lab in player's Completed Labs):
    else:                                                       -> NOT_STARTED
```

This keeps a single source of truth: "Completed" ⇔ the player flag; "Under Research" ⇔ some Lab holds the target. Destroying a Lab therefore **auto-reverts** its in-progress tech to Not Started (the target vanishes with the erased Lab) with no bookkeeping — see D6. A stored table would duplicate (flags + Lab targets) and could drift.

### D4 — `legal_research_targets` (TR-research-005)

```gdscript
# Pure query. Deterministic tech order (Techs registry declaration order).
static func legal_research_targets(state: GameState, lab: StructureState) -> Array[TechDef]:
    if lab.build_status != StructureState.BuildStatus.COMPLETED:
        return []                                          # Under-Construction Lab: empty (Rule 3)
    if lab.current_research_target != null:
        return []                                          # already busy: one tech at a time per Lab
    var owner: int = lab.owner
    var out: Array[TechDef] = []
    for tech: TechDef in Techs.ALL:                        # fixed 3-tech registry, canonical order
        if _has_tech(state, owner, tech):                  continue   # exclude Completed
        if _under_research_by_player(state, owner, tech):  continue   # exclude Under-Research-elsewhere
        if not Faction.faction_allows(state, owner, tech): continue   # faction gate (ADR-0012; all-true under Neutral)
        out.append(tech)
    return out
```

`_under_research_by_player` scans the owner's Completed Labs (by ascending `entity_id`) for `current_research_target == tech`. Live — recomputed each call (a destroyed Lab frees its tech next call).

### D5 — `start_research` / `cancel_research` + `advance_research_timers` (TR-research-004; Rules 3–7)

```gdscript
static func validate_start_research(state, lab: StructureState, tech: TechDef) -> ActionResult:
    # (1) lab.build_status == COMPLETED;  (2) lab.current_research_target == null (Idle);
    # (3) tech in legal_research_targets(state, lab)  [covers not-Completed, not-Under-Research-elsewhere, faction_allows];
    # (4) AP.can_afford(state, lab.owner, Research.effective_research_cost(state, tech, lab.owner))  [ADR-0012 fold].
    # Any failure -> ActionResult{ok=false, reason}. No mutation (ADR-0002).

static func apply_start_research(state, lab, tech) -> Array[Event]:
    # AP.spend(effective_research_cost); lab.current_research_target = tech;
    # lab.research_turns_remaining = Research.effective_research_time(state, tech, lab.owner).

static func validate_cancel_research(state, lab: StructureState) -> ActionResult:
    # lab is owner's AND lab.current_research_target != null (Idle Lab -> reject/no-op).

static func apply_cancel_research(state, lab) -> Array[Event]:
    # refund = lab.current_research_target.research_cost * BaseProductionConfig.cancel_refund_pct / 100  (int div; ADR-0017 reuse)
    # AP credit refund to owner; lab.current_research_target = null; research_turns_remaining = 0.

static func advance_research_timers(state: GameState, player: int) -> Array[Event]:
    # ADR-0008 step 3 body (order-independent vs advance_build_timers). For each of player's Labs with
    # current_research_target != null: research_turns_remaining -= 1; if it reaches 0 -> set the owner's
    # has_<target>_tech flag true, clear current_research_target, append one TechCompletedEvent.
```

- **Upfront cost** (Rule 3): full `research_cost` spent at start, not amortized (mirrors `build_cost`).
- **Cancel refund** reuses ADR-0017's `BaseProductionConfig.cancel_refund_pct` fixed-point (integer division) — `floor(research_cost × 0.5)` = Attack/Defense 5, Economy 3 — cross-system config read, same pattern as Combat reading `defensive_attack_cost`. Research introduces **no new config Resource**: `research_cost`/`research_time` and the effect magnitudes (`RESEARCH_ATK_BONUS`/`DEFENSE_TECH_BONUS`/`ECONOMY_TECH_INCOME_BONUS`) live on the `TechDef` templates (ADR-0007); `ECONOMY_TECH_TIER_THRESHOLD` is AP-Economy-owned (EconomyConfig).
- **Completion sets the flag** (Rule 8): `advance_research_timers` is the sole flag-writer; on reaching 0 it flips exactly the completing tech's `PlayerState` flag and clears the Lab target, matching ADR-0008's registered signature verbatim.

### D6 — `on_lab_destroyed` body (Rule 6; TR-research-008 trigger owned by ADR-0010)

`GameState.destroy_entity` (ADR-0010) calls `Research.on_lab_destroyed(state, lab)` **while the Lab is still live** (before Grid/entities removal). In the derived-status model (D3) the revert is *automatic* — erasing the Lab removes its `current_research_target`, so the tech's Under-Research status vanishes with it. The hook is retained per ADR-0010's contract and, defensively, sets `lab.current_research_target = null` explicitly (harmless; the Lab is about to be erased). It **never** refunds `research_cost` (the boom punish) and **never** touches a completed `PlayerState` flag (permanence, Rule 6/8). A tech reverted this way reappears in `legal_research_targets` at any Completed Lab next query.

### Architecture Diagram

```
apply_action(action)                        [ADR-0002: sole mutation vector]
    ├── START_RESEARCH  → Research.validate_start_research / apply_start_research
    └── CANCEL_RESEARCH → Research.validate_cancel_research / apply_cancel_research
                            │
   reads ────────────┬─────┴───────────────┬─────────────────────┐
   AP.can_afford/spend│  StructureState     │  Techs.ALL registry  │  effective_* / faction_allows (ADR-0012)
   (ADR-0006)         │  .current_research_ │  TechDef refs        │  effective_research_cost/_time
                      │   target / _turns_  │  (ADR-0007 preload)  │  (== base under Neutral)
                      │   remaining         │
                      │  BaseProductionConfig.cancel_refund_pct (ADR-0017 reuse, cancel refund)
   writes (only inside apply / sequenced bodies):
     apply_start_research   → spend + set Lab target/timer
     apply_cancel_research  → refund + clear Lab target
     advance_research_timers→ set PlayerState.has_<X>_tech + clear target (ADR-0008 step 3)   [SOLE flag writer]
     on_lab_destroyed       → clear target (auto-revert); NEVER touches completed flags/refund (ADR-0010 hook)
   queries (pure, live, derived):
     legal_research_targets(state, lab) -> Array[TechDef]
     has_attack_tech / has_defense_tech / has_economy_tech (state, player) -> bool
```

### Key Interfaces

```gdscript
class_name Research extends RefCounted   # static-only; never instantiated

# Queries (pure, live)
static func legal_research_targets(state: GameState, lab: StructureState) -> Array[TechDef]
static func has_attack_tech(state: GameState, player: int) -> bool
static func has_defense_tech(state: GameState, player: int) -> bool
static func has_economy_tech(state: GameState, player: int) -> bool   # read by ADR-0007's economy_tech_income_bonus

# Verb validate/apply pairs (dispatched by apply_action — ADR-0002)
static func validate_start_research(state, lab: StructureState, tech: TechDef) -> ActionResult
static func apply_start_research(state,   lab: StructureState, tech: TechDef) -> Array[Event]
static func validate_cancel_research(state, lab: StructureState) -> ActionResult
static func apply_cancel_research(state,   lab: StructureState) -> Array[Event]   # credits reused cancel_refund_pct

# Start-of-turn + destruction contract bodies (declared by ADR-0008 / ADR-0010; sequenced/triggered by them)
static func advance_research_timers(state: GameState, player: int) -> Array[Event]   # ADR-0008 step 3; SOLE flag writer
static func on_lab_destroyed(state: GameState, lab: StructureState) -> void          # ADR-0010 destroy_entity hook

# Effective (faction-folded) reads — Research-owned effective_X sites per ADR-0012; == base under Neutral
static func effective_research_cost(state, tech: TechDef, player: int) -> int
static func effective_research_time(state, tech: TechDef, player: int) -> int
```

## Alternatives Considered

### Alternative 1: Data-driven `completed_techs` set on PlayerState
- **Description**: `completed_techs: Array[TechDef]` (or `Dictionary[TechDef,bool]`), `has_X_tech` derived by Resource-ref membership.
- **Pros**: Scales to more techs without new fields; matches ADR-0007's type-identity-by-Resource-ref philosophy.
- **Cons**: **Contradicts ADR-0008's already-registered `advance_research_timers` signature** ("sets the owner's PlayerState tech flag has_attack_tech/…"), forcing a reshape of that registered contract (and ADR-0010's) for a marginal VS benefit; the VS tech tree is fixed at 3.
- **Rejection Reason**: Corpus consistency — the named flags are already registered by ADR-0008/0010; extensibility beyond 3 is an explicit Alpha lever. User-confirmed.

### Alternative 2: Stored per-(player,tech) tri-state status table
- **Description**: `Dictionary[TechDef, Status]` on `PlayerState` holding each tech's Not Started / Under Research / Completed explicitly.
- **Pros**: Mirrors the GDD's States table literally.
- **Cons**: Redundant with (flags + Lab `current_research_target`); two sources of truth for "Under Research" that can drift; `on_lab_destroyed` must actively rewrite it (vs. auto-revert on Lab erasure).
- **Rejection Reason**: The derived model (D3) keeps one source of truth and makes destruction-revert automatic. User-confirmed.

### Alternative 3: A `ResearchConfig` Resource for research constants
- **Description**: A dedicated config Resource holding research magnitudes/costs.
- **Pros**: Consistent with other per-system configs.
- **Cons**: Redundant — `research_cost`/`research_time`/effect magnitudes are per-*tech* data that belong on the `TechDef` templates (ADR-0007), not a flat config; `CANCEL_REFUND_RATE` is already B&P's; `ECONOMY_TECH_TIER_THRESHOLD` is AP-Economy's.
- **Rejection Reason**: Tech data is template-shaped, not config-shaped; ADR-0018 introduces no new config Resource.

## Consequences

### Positive
- Closes the final 3 Partial TRs → **200/200 covered**; completes the 18-ADR plan.
- Concretely fulfills the forward-declared `advance_research_timers` (ADR-0008) and `on_lab_destroyed` (ADR-0010) bodies, and ADR-0011/0015/0016's `legal_research_targets` dependency.
- Derived status + permanence-on-PlayerState make Rules 6/8 (survive Lab loss, revert-in-progress-only) structural, not enforced-by-review.
- Uniform with BaseProduction/AP/Movement/Combat: same static-utility shape, apply_action dispatch, no new config Resource, clone-free.

### Negative
- `has_X_tech` flags are per-specific-tech fields on `PlayerState` — a 4th VS tech would need a new field (accepted: VS tree is fixed at 3).
- `advance_research_timers`' body lives here while its sequencing lives in ADR-0008, and `on_lab_destroyed`'s body lives here while its trigger lives in ADR-0010 — a two-ADR read for each (mitigated by explicit cross-references both ways).

### Risks
- **`on_lab_destroyed` mistakenly refunding or touching a completed flag** would break the boom-punish (Rule 6) or permanence (Rule 8). *Mitigation*: the body only clears the in-progress target; it has no refund path and never writes a `PlayerState` flag; covered by the "destroyed mid-research → Not Started, no refund; completed flag survives all Labs destroyed" tests.
- **Order-dependence within start-of-turn step 3** — `advance_research_timers` must be commutative with `advance_build_timers` (registered `start_of_turn_step_reordering` forbidden; Economy Tech's completion is income-affecting but the step-3/step-4 boundary, not intra-step order, guarantees the income snapshot sees it). *Mitigation*: neither timer body reads the other's output; income snapshot (step 4) strictly follows all of step 3.
- **Same-tech double-completion** if mutual exclusion leaked. *Mitigation*: exclusion enforced at both `validate_start_research` and `legal_research_targets`; a second same-tech `start_research` is rejected before a second timer can exist (research-tech.md negative-space AC).
- **`cancel_refund_pct` cross-system read** couples Research to ADR-0017's config. *Mitigation*: read-only shared constant (GDD Rule 7 explicitly reuses the same registered rate); no duplication.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| research-tech.md | Rule 1/8 — 3 flat permanent per-player unlocks, read live (TR-research-003) | D1 three named `PlayerState` bool flags; live `has_X_tech` accessors; sole writer `advance_research_timers` |
| research-tech.md | Rule 3/4 — one tech at a time per Lab; parallel Labs; same tech not at 2 of a player's Labs (TR-research-004) | D2 per-Lab `current_research_target`/`research_turns_remaining`; cross-Lab exclusion at validate + legal query |
| research-tech.md | Rule 4/Interface — `legal_research_targets` excludes Completed + Under-Research-elsewhere; empty for Under-Construction Lab (TR-research-005) | D4 exact filter set, faction_allows fold, canonical tech order, live recompute |
| research-tech.md | Rule 3/7 — `start_research` spends upfront; `cancel_research` refunds `floor(cost×0.5)`, reverts to Not Started | D5 validate/apply pairs; refund reuses ADR-0017 `cancel_refund_pct` fixed-point |
| research-tech.md | Rule 5 — research-timer advance completes at start-of-turn, effect live that turn | D5 `advance_research_timers` body (ADR-0008 sequences at step 3, before income snapshot) |
| research-tech.md | Rule 6 — Lab destroyed mid-research: progress lost, no refund, revert to Not Started; completed techs survive all Labs dying | D3 derived status auto-reverts on Lab erasure; D6 `on_lab_destroyed` hook; flags on PlayerState never touched |
| research-tech.md | Rule 9 — deterministic, headless, clone-safe | Pure static functions over `GameState`; Labs iterated by `entity_id`, techs by registry order; no RNG (ADR-0003) |

## Performance Implications
- **CPU**: `legal_research_targets` ≈ 3 techs × (player Lab count) scan — negligible; `advance_research_timers` ≈ player Lab count. Trivial; safe to recompute live.
- **Memory**: zero persistent — static class, no instance state; +3 bool fields per PlayerState; no new config Resource.
- **Load Time**: none new (TechDef templates already preload'd via ADR-0007's `Techs` registry).
- **Network**: N/A.

## Migration Plan
No existing code. Greenfield: the Research/Tech epic implements this ADR. The `advance_research_timers` and `on_lab_destroyed` bodies (forward-declared by ADR-0008/0010) and the 3 PlayerState fields are implemented here at the same time.

## Validation Criteria
- research-tech.md Pure-Logic gate passes against injected Grid + AP + Lab/tech fixtures: start legality (Completed+Idle+affordable), one-tech-per-Lab, cross-Lab same-tech exclusion (Lab A researching X ⇒ excluded at Lab B; second `start_research` rejected), per-player independence (A researching X ⇒ B may research X), Under-Construction Lab ⇒ empty `legal_research_targets`; timer decrement/completion + batch co-completion of *different* techs; destruction → Not Started + no refund + reappears in legal targets; completed flag survives all Labs destroyed; cancel refund 5/5/3; determinism under `clone()`.
- Integration gate (real Grid + AP + Turn Manager + Unit + Combat + B&P): Lab build/cancel via real BaseProduction; Rule 5 ordering (tech live same turn it completes); Economy Tech + Economy Outpost co-completing → income reflects both (step-3-before-step-4); real Lab destroyed mid-research → revert observable via `legal_research_targets`.
- A `/architecture-review` after Accept confirms research-003/004/005 flip Covered (200/200) and no signature drift vs ADR-0008/0010/0011/0015.

## Related Decisions
- ADR-0001 (state model) — PlayerState gains the 3 tech-unlock bool fields
- ADR-0002 (apply_action) — start/cancel verb dispatch + atomicity + idempotent re-validate
- ADR-0006 (AP economy) — cost gate
- ADR-0007 (entity/stat schema) — TechDef templates, `Techs` registry, StructureState Lab fields; `economy_tech_income_bonus` body reads `has_economy_tech`
- ADR-0008 (start-of-turn sequencing) — sequences `advance_research_timers` (step 3, commutative with build-timer advance)
- ADR-0010 (combat/destruction) — `destroy_entity` calls `on_lab_destroyed` before Lab removal
- ADR-0011 (AI) / ADR-0015 (command FSM) / ADR-0016 (HUD) — consumers of `legal_research_targets` + tech status
- ADR-0012 (faction framework) — `effective_research_cost`/`_time` + `faction_allows` folds
- ADR-0017 (base & production mechanics) — Lab structure lifecycle; `cancel_refund_pct` reuse
