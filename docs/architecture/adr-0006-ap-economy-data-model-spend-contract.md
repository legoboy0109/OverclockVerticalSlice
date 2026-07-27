# ADR-0006: AP Economy Data Model & Spend Contract

## Status
Accepted

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Economy |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md`, `deprecated-apis.md`; ADR-0001 (`Resource` + `@export` storage pattern, thin logic-free Autoload precedent), ADR-0005 (`Resource`-as-config-asset precedent: `MapDefinition`) |
| **Post-Cutoff APIs Used** | None — `EconomyConfig` follows the same `Resource` + `@export` shape already engine-verified by ADR-0001/ADR-0005; no new API surface |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`PlayerState.current_ap` / `income_this_turn` / `has_economy_tech` fields this ADR reads and writes), ADR-0002 (`apply_action`'s `apply()` step calls `AP.spend()` as the sole AP deductor — this ADR fulfills that forward reference) |
| **Enables** | ADR-0008 (start-of-turn sequencing invokes `AP.reset_turn()` / `AP.discard()` at the correct pipeline position); every Core verb handler that spends AP (Movement/Combat/Base & Production/Research, per ADR-0002) gates on `AP.can_afford()` and pays via `AP.spend()`; ADR-0007 (entity/stat schema) implements the `completed_outpost_count()` / `economy_tech_income_bonus()` contracts this ADR forward-declares |
| **Blocks** | Epic "Foundation: AP Economy" and any Core verb handler needing `AP.can_afford()`/`AP.spend()` to gate or pay for its action |
| **Ordering Note** | Third Foundation ADR to draft (after 0001, 0002). Does not require ADR-0007/ADR-0008 to be written first — it forward-declares the two cross-system contracts it needs (`completed_outpost_count`, `economy_tech_income_bonus`) the same way ADR-0002 forward-declared `AP.spend()` before this ADR existed. All 8 Foundation ADRs (0001–0008) must Accept together before Core-layer coding starts (architecture.md's Foundation gate). |

## Context

### Problem Statement
`ap-economy.md` fully specifies the income formula, the `can_afford`/`spend` invariants, and the
frozen-snapshot reset/discard semantics — but, like `GameState` (ADR-0001) and `apply_action`
(ADR-0002), it defers its *structural* home: is `income()`/`can_afford()`/`spend()` a static
utility, an instantiated service, or a set of `GameState` methods? Where do the six tuning
constants live so they are genuinely data-driven per `coding-standards.md`, not hardcoded consts?
And how does the income formula's `completed_outpost_count(player)` term and the Economy Tech
bonus value resolve when neither Base & Production nor Research has a dedicated architecture
decision yet? ADR-0002's pipeline diagram already forward-references `AP.spend()` as the sole AP
deductor inside `apply()`'s step 5 — this ADR is what makes that reference real and complete.

### Constraints
- Static GDScript typing; `Resource`-based state per ADR-0001 (`GameState extends Resource`,
  `duplicate_deep()` clone).
- `direct_game_state_field_write` (registry, ADR-0001) is forbidden — AP Economy is
  `current_ap`/`income_this_turn`'s registered writer, but only from inside `apply_action`'s
  pipeline (ADR-0002) or the turn-reset sequence (ADR-0008), never as an out-of-band setter some
  other system calls directly.
- `mutation_in_validate` (registry, ADR-0002) — `AP.can_afford()` must stay a pure query; only
  `AP.spend()` mutates, and only from inside a verb handler's `apply()`.
- `float_in_state` (registry, ADR-0003) — `current_ap`/`income_this_turn` are `int`; no float
  anywhere in the formula's stored inputs or outputs (GDD Rule 8: deterministic, integer pool).
- `nondeterministic_iteration_order` (registry, ADR-0003) — `completed_outpost_count` must not
  depend on `Dictionary` hash/insertion order once ADR-0007 implements it.
- Gameplay values must be data-driven / external config (`coding-standards.md`) — the six tuning
  constants cannot be GDScript `const`s.

### Requirements
- `income(state, player) -> int` — pure, implements the tiered formula (GDD Formulas).
- `can_afford(state, player, amount) -> bool` — pure query, no mutation (GDD Rule 3).
- `spend(state, player, amount) -> bool` — sole mutator, atomic, active-player-gated (GDD Rule 4/7).
- `reset_turn(state, player)` / `discard(state, player)` — write the frozen `income_this_turn`
  snapshot and reset/zero `current_ap` (GDD Rule 1/5); invoked by ADR-0008 at the correct point in
  the start-of-turn sequence (after the build-timer advance, per GDD Rule 5's ordering cite).
- Non-negativity and single-active-player-mutable invariants enforced by construction (GDD Rule 7).
- `completed_outpost_count(player)` and the Economy Tech bonus term must resolve without requiring
  Base & Production's or Research's data yet (GDD's stub-based test strategy) — but the contract
  must be concrete enough that ADR-0007 implements against it rather than re-deriving it.

## Decision

**`AP` is a static utility class** (`class_name AP extends RefCounted`, top-level file `ap.gd`),
holding only pure/static functions that take a `GameState` and mutate/read it explicitly passed —
no instance fields of its own. This mirrors the verb-handler shape ADR-0002 already established for
Movement/Combat/Base & Production/Research (`validate`/`apply` held by the owning system, not an
instantiated object), so AP Economy fits the same call convention every other Core system uses.

**Tuning constants live in a dedicated `EconomyConfig` Resource** (`.tres`), following the same
config-asset pattern ADR-0005 used for `MapDefinition`: typed fields, inspector-authorable, no
second source of truth. `EconomyConfig` is **not** stored on `GameState` — it is static, shared,
read-only build data, not per-match mutable state, so it must never ride along on every
`duplicate_deep()` clone (the AI's hottest per-turn loop). Instead, a **thin, logic-free `Balance`
Autoload** — the same "read-only lookup convenience" idiom ADR-0001 established for `MatchService`
— loads `EconomyConfig` once at boot and exposes it by reference. `AP`'s functions read
`Balance.economy` internally, so the public signatures match the GDD's documented interface exactly
(`income(player)`, not `income(player, config)`); `Balance` never mutates, validates, or interprets
anything, matching `MatchService`'s discipline.

**`completed_outpost_count(state, player)` and the Economy Tech bonus value are forward-declared
cross-system contracts**, resolved the same way ADR-0002 forward-declared `AP.spend()` before this
ADR existed: `AP.income()` calls `BaseProduction.completed_outpost_count(state, player) -> int` and,
when `has_economy_tech` is set, `Research.economy_tech_income_bonus(state, player) -> int`. Neither
function is implemented by this ADR — their concrete bodies land with ADR-0007 (data-driven
entity/stat schema), which defines the structure-type/status vocabulary (`completed`,
`Economy Outpost`) and the tech-effect schema needed to write them. `has_economy_tech` itself needs
no cross-system call — it is already a `PlayerState` field (ADR-0001), read directly.

### Architecture Diagram

```
   Balance (Autoload, logic-free)
        │ economy: EconomyConfig   (loaded once at boot from .tres)
        ▼
   AP (static utility, class_name AP extends RefCounted)
        │
        ├─ income(state, player) -> int          [pure]
        │     reads Balance.economy (constants)
        │     reads state.per_player[player].has_economy_tech        (ADR-0001 field)
        │     calls BaseProduction.completed_outpost_count(state, player)   [ADR-0007 impl]
        │     calls Research.economy_tech_income_bonus(state, player)      [ADR-0007 impl, if tech held]
        │
        ├─ can_afford(state, player, amount) -> bool   [pure query]
        │
        ├─ spend(state, player, amount) -> bool        [sole mutator]
        │     called ONLY from inside a verb handler's apply() (ADR-0002 step 5)
        │
        └─ reset_turn(state, player) / discard(state, player)   [writers]
              called ONLY from ADR-0008's start-of-turn sequence

   Callers: Command & Action Interface / AI (can_afford, income — legality/preview)
            Movement / Combat / Base & Production / Research verb handlers (spend, inside apply())
            Game State & Turn Manager / ADR-0008 (reset_turn, discard)
```

### Key Interfaces

```gdscript
# ap.gd — top-level file, class_name AP. No instance state; every function takes `state` explicitly.
class_name AP extends RefCounted

static func ap_income_breakdown(state: GameState, player: int) -> Dictionary:
    # The three additive terms of ap_income, kept separate for the HUD income readout
    # (TR-hud-019, consumed by ADR-0016). income() is defined as their sum below, so the
    # per-term breakdown and the total can never drift.
    var cfg: EconomyConfig = Balance.economy
    var n: int = max(0, BaseProduction.completed_outpost_count(state, player))
    var base: int = cfg.base_income
    var outpost: int = cfg.outpost_bonus_tier1 * min(n, cfg.tier_threshold) \
        + cfg.outpost_bonus_tier2 * max(0, n - cfg.tier_threshold)
    # economy_tech_income_bonus() already returns the fully-tiered, has_economy_tech-guarded,
    # cap-applied term (research-tech.md line 263 formula; ADR-0007 impl). AP Economy adds it
    # verbatim and MUST NOT re-apply ECONOMY_TECH_TIER_THRESHOLD — the cap lives inside that one
    # function. (2026-07-24 /architecture-review C3 fix: the previous `* min(n, threshold)` here
    # double-applied the cap, squaring the tier factor — bonus was 36 at n=6 instead of 6.)
    var econ_tech: int = Research.economy_tech_income_bonus(state, player)
    return { "base": base, "outpost": outpost, "econ_tech": econ_tech }

static func income(state: GameState, player: int) -> int:
    var b: Dictionary = ap_income_breakdown(state, player)
    return b["base"] + b["outpost"] + b["econ_tech"]

static func current_ap(state: GameState, player: int) -> int:
    # Thin read facade over ADR-0001's PlayerState.current_ap, mirroring GameState.current_ap(player).
    # (2026-07-24 /architecture-review C1 fix: ADR-0011/0015/0016 call AP.current_ap(state, player)
    # but this ADR had not declared it — the read now exists on AP as those consumers assume.)
    return state.per_player[player].current_ap

static func can_afford(state: GameState, player: int, amount: int) -> bool:
    return amount >= 0 and amount <= state.per_player[player].current_ap

static func spend(state: GameState, player: int, amount: int) -> bool:
    if player != state.active_player: return false   # Rule 7 — only the active player's pool is mutable
    if amount < 0:                    return false
    if amount == 0:                   return true    # no-op success
    var ps: PlayerState = state.per_player[player]
    if amount > ps.current_ap:        return false
    ps.current_ap -= amount
    return true

static func reset_turn(state: GameState, player: int) -> void:
    var ps: PlayerState = state.per_player[player]
    ps.income_this_turn = income(state, player)   # frozen snapshot for the whole turn (GDD Rule 5)
    ps.current_ap = ps.income_this_turn

static func discard(state: GameState, player: int) -> void:
    state.per_player[player].current_ap = 0        # end-of-turn discard, no banking (GDD Rule 1)
```

```gdscript
# economy_config.gd — top-level file, class_name EconomyConfig
class_name EconomyConfig extends Resource
@export var base_income: int = 10
@export var outpost_bonus_tier1: int = 2
@export var outpost_bonus_tier2: int = 1
@export var tier_threshold: int = 4
@export var economy_tech_tier_threshold: int = 6
```

```gdscript
# balance.gd — Autoload "Balance", logic-free lookup only (mirrors MatchService, ADR-0001)
extends Node
var economy: EconomyConfig = preload("res://data/balance/economy_config.tres")
# No other fields. No methods beyond direct property access. Never mutates, validates, or
# interprets — systems read Balance.economy.* directly; only Balance decides where the .tres lives.
```

```gdscript
# Forward-declared contracts this ADR depends on — implemented by ADR-0007, not this ADR:
#   static func BaseProduction.completed_outpost_count(state: GameState, player: int) -> int
#   static func Research.economy_tech_income_bonus(state: GameState, player: int) -> int
#     ^ RETURNS THE FULLY-CAPPED TERM: has_economy_tech ? ECONOMY_TECH_INCOME_BONUS ×
#       min(completed_outpost_count, ECONOMY_TECH_TIER_THRESHOLD) : 0 (research-tech.md formula).
#       ap_income_breakdown()/income() add it as-is and never re-apply the cap.
# ECONOMY_TECH_INCOME_BONUS (the constant, value 1) is owned by Research's own config resource —
# ap-economy.md is explicit that this value is NOT an AP Economy tuning knob. ECONOMY_TECH_TIER_THRESHOLD
# (6, this system's own brake on the term) lives in EconomyConfig above and is read cross-system by
# Research's economy_tech_income_bonus() implementation — AP-Economy-owned but Research-applied.
#
# Contract this ADR OWNS and forward-declares to consumers (added 2026-07-24, /architecture-review C2):
#   static func AP.ap_income_breakdown(state, player) -> Dictionary { base, outpost, econ_tech }
#     — the per-term income decomposition the HUD renders (TR-hud-019, consumed by ADR-0016).
```

## Alternatives Considered

### Alternative 1 (module shape): Static utility class `AP` — CHOSEN
- **Description**: Pure/static functions on a stateless class, `state` passed explicitly.
- **Pros**: Matches the verb-handler convention ADR-0002 already set for every other Core system;
  trivially unit-testable (no instance to construct/inject); no lifetime-management question.
- **Cons**: None material — Godot has no meaningful cost difference between a static-function class
  and an instance holding no fields.
- **Rejection Reason**: n/a (chosen).

### Alternative 2 (module shape): Instance-based AP Economy service object
- **Description**: `AP` constructed once per match, injected into `apply_action`'s dispatch table
  like a service.
- **Pros**: Would allow instance-scoped caching if `income()` ever became expensive.
- **Cons**: `income()`/`can_afford()`/`spend()` have no per-instance state to justify an object;
  adds a construction/injection step ADR-0002's dispatch table doesn't otherwise need (Movement,
  Combat, etc. are all static too).
- **Rejection Reason**: No state to own; would be inconsistent with every sibling verb handler for
  no benefit.

### Alternative 3 (module shape): Methods directly on `GameState`/`PlayerState`
- **Description**: `income()`/`spend()`/`can_afford()` become `GameState` methods, no separate `AP`
  class at all.
- **Pros**: One fewer type; call sites read as `state.spend(player, amount)`.
- **Cons**: Bloats `GameState`'s surface with every Core system's logic (Movement, Combat, Base &
  Production, Research would each want the same treatment) — directly against the module-ownership
  map, which keeps `GameState` a thin data/mutation-pipeline holder and pushes verb-specific rules
  into owning systems (ADR-0002's stated rationale for Alternative 3 there, reused here).
- **Rejection Reason**: Would re-centralize logic ADR-0002 deliberately decentralized.

### Alternative 4 (config storage): Dedicated `EconomyConfig` Resource — CHOSEN
- **Description**: A `.tres` resource owned by AP Economy, mirroring `MapDefinition` (ADR-0005).
- **Pros**: Self-contained, inspector-editable, no coupling to unrelated systems' tuning passes;
  satisfies the data-driven coding standard with a precedent already engine-verified.
- **Cons**: One config asset per system, versus a single project-wide balance file.
- **Rejection Reason**: n/a (chosen).

### Alternative 5 (config storage): One shared `BalanceConfig` Resource for all systems
- **Description**: A single `.tres` holding every system's tuning constants together.
- **Pros**: One place to open for a full balance pass.
- **Cons**: Couples unrelated systems (AP Economy, Movement, Combat) into one file — a Combat
  balance edit now risk-touches the same asset AP Economy depends on; git-diff noise across
  unrelated changes; no system owns its own knobs cleanly.
- **Rejection Reason**: Cross-system coupling with no corresponding benefit once per-system configs
  are just as easy to open individually; each future system ADR can follow the same
  `EconomyConfig`-style precedent independently.

### Alternative 6 (config storage): GDScript `const`s on the `AP` class
- **Description**: `const BASE_INCOME := 10` etc., directly in `ap.gd`.
- **Pros**: Simplest possible mechanism; zero indirection.
- **Cons**: Directly violates `coding-standards.md`'s "Gameplay values must be data-driven (external
  config), never hardcoded" — every tuning pass would require a code change + redeploy instead of
  editing a `.tres` in the inspector.
- **Rejection Reason**: Explicit coding-standard violation with no compensating benefit.

### Alternative 7 (config access): Explicit `config` parameter on every `AP` function
- **Description**: `income(state, player, config: EconomyConfig) -> int`, threaded in by every caller.
- **Pros**: Maximal dependency-injection purity — no Autoload involved at all.
- **Cons**: `EconomyConfig` never changes mid-match; threading it through every call site
  (`apply_action`, AI enumeration loops, HUD projections, Command & Action Interface previews)
  changes signatures across the whole codebase for a value that is effectively load-time-constant.
- **Rejection Reason**: ADR-0001 already accepted exactly this tradeoff for `MatchService` (a
  logic-free Autoload lookup, with tests/AI free to bypass it and construct/pass state directly);
  extending the same idiom to read-only config keeps the public API matching the GDD's documented
  signatures (`income(player)`) instead of growing a config parameter everywhere.

### Alternative 8 (outpost count source): AP Economy iterates `entities_by_id` directly
- **Description**: `AP.income()` walks `state.entities_by_id`, filtering by owner/type/status itself
  instead of calling `BaseProduction.completed_outpost_count()`.
- **Pros**: No forward-declared cross-system contract to keep in sync.
- **Cons**: Requires AP Economy to know structure-type and completion-status vocabulary that
  `base-production.md` owns — violates the module-ownership map exactly the way ADR-0002's
  Alternative 3 rejection warned against; if Base & Production's entity schema changes (ADR-0007),
  AP Economy's formula code would need to change too instead of just the owning system.
- **Rejection Reason**: Ownership violation; the forward-declared function-call contract keeps the
  count's *definition* inside Base & Production where `ap-economy.md`'s own Dependencies table
  already says it belongs, at the cost of one contract ADR-0007 must satisfy — the same cost
  ADR-0002 already paid for `AP.spend()` itself.

## Consequences

### Positive
- `AP`'s four functions are the entire public surface every other system needs — `can_afford`/
  `income` for legality/preview (Command & Action Interface, AI, HUD), `spend` for commitment
  (verb handlers), `reset_turn`/`discard` for turn boundaries (ADR-0008) — matching the GDD's
  documented interface exactly, no signature drift.
- Config lives in one small, inspector-editable `.tres`, satisfying the data-driven standard without
  inventing new machinery beyond what ADR-0005 already established.
- `EconomyConfig` staying off `GameState` keeps `duplicate_deep()`'s clone cost independent of the
  tuning surface — the AI's per-candidate-action clone loop (ADR-0011) never pays to copy constants.
- Forward-declared contracts (`completed_outpost_count`, `economy_tech_income_bonus`) let this ADR
  and ADR-0007 be written in either order without redesign, and keep the GDD's stub-based unit-test
  strategy valid at the architecture level, not just the GDD level.

### Negative
- Two forward-declared function contracts (`BaseProduction.completed_outpost_count`,
  `Research.economy_tech_income_bonus`) exist only as signatures until ADR-0007 lands — `income()`
  cannot be exercised end-to-end (only unit-tested against stubs, per the GDD's own test strategy)
  until then.
- `Balance` is one more thin Autoload alongside `MatchService` — same discipline risk ADR-0001 flagged
  (must never grow logic), now doubled.

### Risks
- **A future system reaches into `EconomyConfig` and mutates it at runtime** (e.g. a "temporary
  buff" hack) — would break determinism (income would no longer be a pure function of board state)
  and violate `float_in_state`/`direct_game_state_field_write`'s spirit even though `EconomyConfig`
  isn't `GameState`. Mitigation: code review; `EconomyConfig` fields are tuning data, not runtime
  state, and no ADR grants write access to them outside the resource editor.
- **`completed_outpost_count`/`economy_tech_income_bonus` signature drift** when ADR-0007 is
  authored (e.g. it decides a different parameter shape). Mitigation: ADR-0007 must either satisfy
  this exact contract or explicitly supersede this section with a documented reason, per the
  registry's `superseded_by` discipline.
- **Faction Identity's income delta fold** (`ap-economy.md` Dependencies: `Δ_base`/`Δ_tier1`/
  `Δ_tier2` + a `BASE_INCOME_FLOOR` guard) is explicitly deferred to the Alpha faction-asymmetry
  prototype and is a no-op under the VS's Neutral default — this ADR intentionally does **not** add
  a floor field or delta hooks to `EconomyConfig` now (nothing in the VS scope exercises them); ADR-0012
  (Faction fold pattern) or a revision of this ADR adds them when that prototype starts.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ap-economy.md | Rule 1: start-of-turn reset to frozen income snapshot, end-of-turn discard (no banking) | `AP.reset_turn()` writes the snapshot; `AP.discard()` zeroes `current_ap` |
| ap-economy.md | Rule 3: `can_afford` is a pure precondition query, no deduction | `AP.can_afford()` — read-only, no state mutation |
| ap-economy.md | Rule 4/7: `spend` is the sole atomic mutator, active-player-gated, no partial spend | `AP.spend()` — single gated deduction, all-or-nothing |
| ap-economy.md | Rule 5: income is a diminishing function of *completed* outposts, frozen at start-of-turn, evaluated after the build-timer advance | `AP.income()` pure formula; `reset_turn()` is the only writer of `income_this_turn`, invoked by ADR-0008 at the correct sequence position |
| ap-economy.md | Rule 6/Formulas: tiered `OUTPOST_BONUS_TIER1/2`, `TIER_THRESHOLD`, `ECONOMY_TECH_TIER_THRESHOLD`, `ECONOMY_TECH_INCOME_BONUS` (Research-owned) composed into one formula | `AP.income()` implements the exact formula; `EconomyConfig` holds this system's four constants, `ECONOMY_TECH_INCOME_BONUS` deliberately excluded (Research-owned) |
| ap-economy.md | Rule 7: `0 ≤ current_ap ≤ income_this_turn` invariant; non-negativity; single active-player mutability | Enforced by construction: `income()`'s outer `max(0, n)` + floor `base_income`; `spend()`'s `amount ≤ current_ap` and `player == active_player` gates |
| ap-economy.md | Rule 8: deterministic AP trajectory | `AP`'s functions are pure/integer-only; no RNG, no float (satisfies ADR-0003's `float_in_state`/`global_rng` bans) |
| ap-economy.md | Interactions table: Base & Production supplies `completed_outpost_count`; Research supplies the Economy Tech bonus value + `has_economy_tech` | Forward-declared `BaseProduction.completed_outpost_count()` / `Research.economy_tech_income_bonus()` contracts; `has_economy_tech` read from the ADR-0001 `PlayerState` field |
| coding-standards.md | Gameplay values must be data-driven (external config), never hardcoded | `EconomyConfig` `.tres` resource, not GDScript consts |

## Performance Implications
- **CPU**: `income()`/`can_afford()`/`spend()` are O(1) integer arithmetic. `income()`'s cost is
  dominated by whatever `BaseProduction.completed_outpost_count()` costs once ADR-0007 implements
  it (a per-player entity scan) — that budget belongs to ADR-0007/ADR-0011 (AI loop budget), not
  this ADR; flagging it here so ADR-0007 accounts for `income()` being called once per player per
  turn-reset at minimum, and potentially many more times per AI candidate-action evaluation (GDD
  Interactions: "`ap_income` ... may still be evaluated live for projections").
- **Memory**: `EconomyConfig` is a single small resource loaded once at boot, not per-clone —
  zero incremental cost to the AI's `duplicate_deep()` lookahead loop.
- **Load Time**: Negligible — one `.tres` preload at Autoload init.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Formula correctness**: for each GDD worked example (`n=0→10`, `n=4→18`, `n=5→19`, `n=8→22`,
  `n=12→26`; with Economy Tech `n=2→16`, `n=4→22`, `n=6→26`, `n=12→32`), `AP.income()` against
  stubbed `completed_outpost_count`/`has_economy_tech` returns the exact published value.
- **Spend atomicity**: `spend()` on an over-budget amount returns `false` and leaves `current_ap`
  field-wise-unchanged; `spend(0)` returns `true` and no-ops; negative amount returns `false`.
- **Active-player gate**: `spend()` against a non-active player's pool returns `false` and mutates
  nothing (two-player scenario, GDD's Player A/B AC).
- **Reset/discard cycle**: `reset_turn()` sets `current_ap == income_this_turn == income()`;
  `discard()` sets `current_ap` to exactly `0`, not merely "irrelevant."
- **Frozen-snapshot immunity**: after `reset_turn()`, mutating the stubbed `completed_outpost_count`
  mid-"turn" does not change `income_this_turn` until the next `reset_turn()` call (build-this-turn
  and destroyed-this-turn GDD ACs, both directions).
- **Config load**: `Balance.economy` loads without error and matches the default `EconomyConfig`
  values (`base_income=10`, tier1=2, tier2=1, threshold=4, economy_tech_tier_threshold=6).
- **Negative-count defense**: a stubbed `completed_outpost_count` returning a negative value still
  yields `income() == base_income` (the `max(0, n)` floor), never below.

## Related Decisions
- ADR-0001: State model ownership & lifecycle (`PlayerState.current_ap`/`income_this_turn`/
  `has_economy_tech` fields this ADR is the sole writer of; the `MatchService`-style thin-Autoload
  precedent this ADR reuses for `Balance`)
- ADR-0002: Action / `apply_action` command model (`AP.spend()` is called from inside a verb
  handler's `apply()`, step 5 of the pipeline; fulfills that ADR's forward reference)
- ADR-0003: Deterministic simulation & RNG isolation (`AP`'s functions are integer-only, RNG-free,
  and order-independent — satisfies `float_in_state`/`global_rng`/`nondeterministic_iteration_order`)
- ADR-0005: Grid representation & map-definition format (`EconomyConfig`-as-`.tres` reuses the
  `MapDefinition` config-asset pattern)
- ADR-0007: Data-driven entity/stat schema (implements the forward-declared
  `BaseProduction.completed_outpost_count()` / `Research.economy_tech_income_bonus()` contracts)
- ADR-0008: Shared start-of-turn sequencing (owns *when* `AP.reset_turn()`/`AP.discard()` are
  called; this ADR owns only the *amounts*, per `ap-economy.md` Rule 1's ownership split)
- ADR-0012: Faction cross-cutting fold pattern (future home of the deferred income-delta fold +
  `BASE_INCOME_FLOOR` guard noted in Risks)
