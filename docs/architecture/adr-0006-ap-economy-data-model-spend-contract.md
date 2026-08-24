# ADR-0006: AP & Credits Economy Data Model & Spend Contract

## Status
Accepted

> **Revised 2026-08-05 (economy pivot).** The original single-AP-pool decision (Accepted
> 2026-07-23) is revised **in place** — not superseded — because ~10 downstream ADRs cite
> "ADR-0006" as the economy's architectural home and the two pools are one tightly-coupled
> economy (dual-cost binds them). This revision splits the single pool into **two resources**:
> **AP** (flat tactical budget, capped carryover) and **Credits** (banked economic pool, funded
> by the old income curve re-denominated). It tracks the `ap-economy.md` pivot ("AP & Credits
> Economy", 2026-08-05). The static-utility module shape, the `Balance` autoload, the
> forward-declared cross-system contracts, and the determinism/integer invariants all carry over
> unchanged; the *data model* (two pools) and *spend contract* (split `AP.*`/`Credits.*` + a
> dual-cost both-or-neither gate) are what changed.

## Date
2026-07-23 (revised 2026-08-05)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Economy |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md`, `deprecated-apis.md`; ADR-0001 (`Resource` + `@export` storage pattern, thin logic-free Autoload precedent), ADR-0005 (`Resource`-as-config-asset precedent: `MapDefinition`) |
| **Post-Cutoff APIs Used** | None — the pivot adds one mirror static class (`Credits`), one `int` field (`current_credits`), and five `EconomyConfig` fields, all on shapes already engine-verified by ADR-0001/ADR-0005; no new API surface |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`PlayerState.current_ap` / `current_credits` / `has_economy_tech` fields this ADR reads and writes — `current_credits` is a **new** field this revision adds), ADR-0002 (`apply_action`'s `apply()` step calls `AP.spend()` / `Credits.spend()` as the sole pool deductors, and its validate-before-mutate atomicity is what makes the dual-cost both-or-neither gate safe — this ADR fulfills that forward reference) |
| **Enables** | ADR-0008 (start-of-turn sequencing invokes `AP.reset_turn()` **and** `Credits.add_income()` at the correct pipeline position — the old single `AP.reset_turn()` call splits in two; `AP.discard()` is **removed** from `EndTurnAction`); every economic verb handler (Base & Production/Research, per ADR-0002/0017/0018) gates on the **dual** `Credits.can_afford() AND AP.can_afford()` and pays via a both-or-neither spend; every tactical verb handler (Movement/Combat) gates on `AP.can_afford()` and pays via `AP.spend()`; ADR-0007 (entity/stat schema) implements `completed_outpost_count()` / `economy_tech_income_bonus()` and adds `TechDef.ap_surcharge`; ADR-0016 (HUD) renders `Credits.credit_income_breakdown()` and a dual counter |
| **Blocks** | Epic "Foundation: AP & Credits Economy" and any Core verb handler needing `AP`/`Credits` afford/spend to gate or pay for its action |
| **Ordering Note** | Third Foundation ADR to draft (after 0001, 0002). Does not require ADR-0007/ADR-0008 to be written first — it forward-declares the cross-system contracts it needs (`completed_outpost_count`, `economy_tech_income_bonus`, and now `TechDef.ap_surcharge`) the same way ADR-0002 forward-declared `AP.spend()` before this ADR existed. All 8 Foundation ADRs (0001–0008) must Accept together before Core-layer coding starts (architecture.md's Foundation gate). |

## Context

### Problem Statement
`ap-economy.md` (revised to "AP & Credits Economy", 2026-08-05) specifies **two** resources — a flat
tactical **AP** pool with capped carryover, and a banked economic **Credits** pool funded by the
diminishing-outpost income curve that formerly drove AP — plus a **dual-cost** rule where economic
actions cost both Credits (the resource gate) and a small AP surcharge (the tempo gate), spent
**both-or-neither**. Like `GameState` (ADR-0001) and `apply_action` (ADR-0002), the GDD defers its
*structural* home: are the two pools' primitives static utilities, instantiated services, or
`GameState` methods? Where do the (now ten) tuning constants live so they stay data-driven per
`coding-standards.md`? How does the income formula's `completed_outpost_count(player)` term and the
Economy Tech bonus resolve when neither Base & Production nor Research has its own Foundation ADR? And
where is the dual-cost both-or-neither guarantee enforced so a verb handler can never spend one pool
and fail the other? ADR-0002's pipeline already forward-references `AP.spend()` as *a* pool deductor
inside `apply()`'s step 5 — this ADR makes that real for **both** pools and defines the dual-cost
contract on top.

**What the pivot changed vs. the original decision:** the single `AP` pool became two; the income
formula moved from `AP.income()` to `Credits.credit_income()` (same math, → Credits); `AP.reset_turn()`
changed from an income snapshot to a flat-plus-capped-carryover reset; `AP.discard()` was removed (AP
now carries, not discarded); and a dual-cost gate was added. Everything about *module shape*, config
storage, the `Balance` autoload, and the forward-declared contracts is unchanged from the original.

### Constraints
- Static GDScript typing; `Resource`-based state per ADR-0001 (`GameState extends Resource`,
  `duplicate_deep()` clone).
- `direct_game_state_field_write` (registry, ADR-0001) is forbidden — AP & Credits Economy is
  `current_ap`/`current_credits`'s registered writer, but only from inside `apply_action`'s pipeline
  (ADR-0002) or the turn-reset sequence (ADR-0008), never as an out-of-band setter.
- `mutation_in_validate` (registry, ADR-0002) — `AP.can_afford()` / `Credits.can_afford()` must stay
  pure queries; only `AP.spend()` / `Credits.spend()` / `Credits.credit()` mutate, and only from
  inside a verb handler's `apply()` or the turn reset.
- `float_in_state` (registry, ADR-0003) — `current_ap`/`current_credits` are `int`; no float anywhere
  in either pool's stored inputs or outputs (GDD Rule 12: deterministic, integer pools).
- `nondeterministic_iteration_order` (registry, ADR-0003) — `completed_outpost_count` must not depend
  on `Dictionary` hash/insertion order once ADR-0007 implements it.
- Gameplay values must be data-driven / external config (`coding-standards.md`) — none of the ten
  tuning constants may be GDScript `const`s.

### Requirements
- **AP (tactical):** `AP.reset_turn(state, player)` — flat budget plus capped carryover (GDD Rule 1/2);
  `AP.can_afford(state, player, amount) -> bool` pure query (GDD afford gate); `AP.spend(state, player,
  amount) -> bool` sole atomic mutator, active-player-gated (GDD Rule 4). **No `discard`** — AP carries
  (GDD Rule 2). Invariant `0 ≤ current_ap ≤ FLAT_AP_PER_TURN + AP_CARRYOVER_CAP` by construction (Rule 5).
- **Credits (economic):** `Credits.credit_income(state, player) -> int` pure tiered formula (GDD
  Formulas); `Credits.add_income(state, player)` banks income (added, no cap — GDD Rule 6);
  `Credits.can_afford` pure query; `Credits.spend` sole atomic mutator mirror of `AP.spend`;
  `Credits.credit(state, player, amount)` the cancel-build refund writer (GDD Rule 9). Invariant
  `current_credits ≥ 0` by construction (Rule 10).
- **Dual-cost (the AP×Credits gate):** an economic action is legal iff **both** pools can pay, and
  applies **both-or-neither** (GDD Rule 11) — enforced structurally (see Decision), not by a new
  transaction/rollback mechanism.
- `completed_outpost_count(player)`, the Economy Tech bonus term, and the per-tech AP surcharge must
  resolve without requiring Base & Production's or Research's data yet (GDD's stub-based test strategy),
  but the contracts must be concrete enough that ADR-0007 implements against them.

## Decision

**Two static utility classes: `AP` (revised) and `Credits` (new), mirroring each other.** Each is a
`class_name X extends RefCounted` top-level file (`ap.gd`, `credits.gd`) holding only pure/static
functions that take a `GameState` and mutate/read it explicitly passed — no instance fields. This keeps
the verb-handler shape ADR-0002 established for every other Core system, and makes `Credits` a
line-for-line mirror of `AP`'s afford/spend pair (plus the income formula it owns). The single-`Economy`
alternative (both pools' logic in one class) was rejected (Alternatives) — two mirrored classes keep
each pool's surface minimal and match the sibling-verb-handler convention.

- **`AP` owns the tactical pool.** `reset_turn()` now writes a **flat budget plus capped carryover**
  (`FLAT_AP_PER_TURN + min(leftover, AP_CARRYOVER_CAP)`, reading the leftover already sitting in
  `current_ap` — never discarded at end of turn), not an income snapshot. `AP.discard()` is **deleted**
  (GDD Rule 2). `can_afford`/`spend`/`current_ap` are unchanged in shape.
- **`Credits` owns the economic pool and the income formula.** `credit_income()` /
  `credit_income_breakdown()` are the former `AP.income()` / `AP.ap_income_breakdown()`, moved verbatim
  (same tiered math, same C3 double-cap discipline — see Key Interfaces), now granting Credits.
  `add_income()` **banks** income (`current_credits += credit_income()`, no cap, no snapshot-reset — GDD
  Rule 6). `can_afford`/`spend` mirror `AP`. `credit()` is the third writer of `current_credits` (the
  cancel-build refund, invoked by Base & Production's `CancelBuildAction.apply()`).

**Tuning constants live in the same `EconomyConfig` Resource** (`.tres`), grown from 5 fields to 10: the
five credit-income-curve fields (unchanged) plus `flat_ap_per_turn`, `ap_carryover_cap`, and the three
AP logistics surcharges (`produce_ap_cost`, `build_ap_cost`, `research_ap_cost`). The AP surcharges live
**here** because they are a property of the tactical budget, not of any one structure/tech (GDD Rule 3);
Base & Production and Research **read** them cross-system, the same AP-Economy-owned-but-others-applied
pattern already used for `economy_tech_tier_threshold`. `research_ap_cost` is only the **base** — a tech
may override it via `TechDef.ap_surcharge` (ADR-0007 schema field, defaulting to this base), which the
research verb handler reads (ADR-0018). `EconomyConfig` is still **not** stored on `GameState` (static,
shared, read-only build data — must never ride a `duplicate_deep()` clone); the same thin, logic-free
`Balance` autoload loads it once at boot and exposes it by reference.

**Dual-cost is enforced by ADR-0002's validate-before-mutate — no new machinery.** An economic verb
handler (Produce/Build/Research) checks **both** pools in `validate()`
(`Credits.can_afford(credit_cost) AND AP.can_afford(ap_cost)`) and spends **both** in `apply()`
(`Credits.spend(credit_cost); AP.spend(ap_cost)`). Because ADR-0002 guarantees an illegal action makes
zero state change (validate runs fully before any mutation) and nothing changes affordability between
validate and apply (single-threaded, deterministic), neither spend can fail after the gate — a
half-commit is structurally impossible. This ADR therefore defines the **dual-cost contract** (validate
both, spend both, in that order) rather than a transaction/rollback object. An optional
`spend_dual(state, player, credit_cost, ap_cost) -> bool` convenience (checks both, then spends both) may
be added by the verb-handler layer to keep the both-legs guarantee in one place; it is not required for
correctness and introduces no third class if inlined.

**`completed_outpost_count(state, player)`, the Economy Tech bonus, and `TechDef.ap_surcharge` are
forward-declared cross-system contracts**, resolved as ADR-0002 forward-declared `AP.spend()`:
`Credits.credit_income()` calls `BaseProduction.completed_outpost_count(state, player) -> int` and, when
`has_economy_tech` is set, `Research.economy_tech_income_bonus(state, player) -> int`; the research verb
handler reads `TechDef.ap_surcharge` (falling back to `research_ap_cost`). Their concrete bodies land
with ADR-0007. `has_economy_tech` is a `PlayerState` field (ADR-0001), read directly.

### Architecture Diagram

```
   Balance (Autoload, logic-free)
        │ economy: EconomyConfig   (loaded once at boot from .tres; 10 fields)
        ▼
   AP (static utility, class_name AP extends RefCounted)        ── tactical pool ──
        ├─ reset_turn(state, player)          [writer] flat + min(leftover, cap)   (ADR-0008 step 4a)
        ├─ can_afford(state, player, amount) -> bool   [pure query]
        ├─ spend(state, player, amount) -> bool        [sole AP mutator; inside apply() (ADR-0002)]
        └─ current_ap(state, player) -> int   [pure read facade]
           # AP.discard() REMOVED — AP carries, not discarded (GDD Rule 2)

   Credits (static utility, class_name Credits extends RefCounted)   ── economic pool ──
        ├─ credit_income(state, player) -> int          [pure] = credit_income_breakdown().sum()
        │     reads Balance.economy; calls BaseProduction.completed_outpost_count (ADR-0007)
        │     calls Research.economy_tech_income_bonus (ADR-0007, if tech held)
        ├─ credit_income_breakdown(state, player) -> Dictionary   [pure; HUD, TR-hud-019, ADR-0016]
        ├─ add_income(state, player)          [writer] current_credits += credit_income   (ADR-0008 step 4b)
        ├─ can_afford(state, player, amount) -> bool   [pure query]
        ├─ spend(state, player, amount) -> bool        [sole spend mutator; inside apply()]
        ├─ credit(state, player, amount)      [3rd writer] cancel-build refund (Base & Production)
        └─ current_credits(state, player) -> int   [pure read facade]

   Dual-cost gate (Produce/Build/Research verb handlers, ADR-0002/0017/0018):
        validate(): Credits.can_afford(credit_cost) AND AP.can_afford(ap_cost)   → both-or-neither
        apply():    Credits.spend(credit_cost); AP.spend(ap_cost)                → safe (validated first)

   Callers: Command & Action Interface / AI (can_afford ×2, credit_income — legality/preview)
            Movement / Combat verb handlers (AP.spend, inside apply())
            Base & Production / Research verb handlers (dual-cost gate, inside validate()+apply())
            Game State & Turn Manager / ADR-0008 (AP.reset_turn + Credits.add_income; NO AP.discard)
            Base & Production / CancelBuildAction (Credits.credit — refund)
```

### Key Interfaces

```gdscript
# ap.gd — top-level file, class_name AP. No instance state. Tactical pool. REVISED for the pivot.
class_name AP extends RefCounted

static func reset_turn(state: GameState, player: int) -> void:
    # Flat budget + capped carryover (GDD Rule 1/2). The "leftover" is whatever unspent AP is still
    # sitting in current_ap (AP is NEVER discarded at end of turn), so this reads it and overwrites.
    var cfg: EconomyConfig = Balance.economy
    var leftover: int = state.per_player[player].current_ap
    state.per_player[player].current_ap = cfg.flat_ap_per_turn + min(leftover, cfg.ap_carryover_cap)

static func current_ap(state: GameState, player: int) -> int:
    # Thin read facade over ADR-0001's PlayerState.current_ap, mirroring GameState.current_ap(player).
    return state.per_player[player].current_ap

static func can_afford(state: GameState, player: int, amount: int) -> bool:
    return amount >= 0 and amount <= state.per_player[player].current_ap

static func spend(state: GameState, player: int, amount: int) -> bool:
    if player != state.active_player: return false   # Rule 4 — only the active player's pool is mutable
    if amount < 0:                    return false
    if amount == 0:                   return true    # no-op success
    var ps: PlayerState = state.per_player[player]
    if amount > ps.current_ap:        return false
    ps.current_ap -= amount
    return true

# AP.discard() — DELETED in the pivot. AP is no longer zeroed at end of turn; unspent AP becomes the
# "leftover" that reset_turn() consumes (capped) at the next reset (GDD Rule 2). EndTurnAction (ADR-0008)
# must remove its old AP.discard() call.
# AP.income() / AP.ap_income_breakdown() — MOVED to Credits (the income curve now funds Credits).
```

```gdscript
# credits.gd — top-level file, class_name Credits. No instance state. NEW: economic pool + income.
class_name Credits extends RefCounted

static func credit_income_breakdown(state: GameState, player: int) -> Dictionary:
    # The three additive terms of credit income, kept separate for the HUD readout (was
    # AP.ap_income_breakdown; TR-hud-019, consumed by ADR-0016). credit_income() is their sum below,
    # so the per-term breakdown and the total can never drift.
    var cfg: EconomyConfig = Balance.economy
    var n: int = max(0, BaseProduction.completed_outpost_count(state, player))
    var base: int = cfg.base_income
    var outpost: int = cfg.outpost_bonus_tier1 * min(n, cfg.tier_threshold) \
        + cfg.outpost_bonus_tier2 * max(0, n - cfg.tier_threshold)
    # economy_tech_income_bonus() already returns the fully-tiered, has_economy_tech-guarded,
    # cap-applied term (research-tech.md formula; ADR-0007 impl). Add it verbatim; MUST NOT re-apply
    # economy_tech_tier_threshold — the cap lives inside that one function. (2026-07-24 /architecture-
    # review C3 fix carried over from AP.ap_income_breakdown unchanged: the prior extra `* min(n, thr)`
    # double-applied the cap, squaring the tier factor — 36 at n=6 instead of 6.)
    var econ_tech: int = Research.economy_tech_income_bonus(state, player)
    return { "base": base, "outpost": outpost, "econ_tech": econ_tech }

static func credit_income(state: GameState, player: int) -> int:
    var b: Dictionary = credit_income_breakdown(state, player)
    return b["base"] + b["outpost"] + b["econ_tech"]

static func add_income(state: GameState, player: int) -> void:
    # Start-of-turn: BANK income (GDD Rule 6) — ADDED to the running balance, no cap, no snapshot-reset.
    # Contrast AP.reset_turn(), which overwrites. Called by ADR-0008 step 4b, AFTER the build-timer
    # advance (step 3) so an outpost completing this turn counts this turn.
    state.per_player[player].current_credits += credit_income(state, player)

static func current_credits(state: GameState, player: int) -> int:
    return state.per_player[player].current_credits

static func can_afford(state: GameState, player: int, amount: int) -> bool:
    return amount >= 0 and amount <= state.per_player[player].current_credits

static func spend(state: GameState, player: int, amount: int) -> bool:   # mirror of AP.spend
    if player != state.active_player: return false
    if amount < 0:                    return false
    if amount == 0:                   return true
    var ps: PlayerState = state.per_player[player]
    if amount > ps.current_credits:   return false
    ps.current_credits -= amount
    return true

static func credit(state: GameState, player: int, amount: int) -> void:
    # Third writer of current_credits: the cancel-build refund (GDD Rule 9). Invoked ONLY from
    # CancelBuildAction.apply() (Base & Production) for the active player, so no active-player gate is
    # re-checked here. amount = floor(build_cost * CANCEL_REFUND_RATE), computed by Base & Production.
    if amount > 0:
        state.per_player[player].current_credits += amount
```

```gdscript
# economy_config.gd — top-level file, class_name EconomyConfig. GROWS from 5 fields to 10.
class_name EconomyConfig extends Resource
# --- Credit-income curve (unchanged values; re-denominated AP → Credits) ---
@export var base_income: int = 10
@export var outpost_bonus_tier1: int = 2
@export var outpost_bonus_tier2: int = 1
@export var tier_threshold: int = 4
@export var economy_tech_tier_threshold: int = 6
# --- AP tactical budget (NEW) ---
@export var flat_ap_per_turn: int = 10       # GDD Rule 1
@export var ap_carryover_cap: int = 5        # GDD Rule 2
# --- AP logistics surcharges (NEW — owned here; read cross-system by B&P/Research, GDD Rule 3) ---
@export var produce_ap_cost: int = 1         # AP surcharge to produce a unit
@export var build_ap_cost: int = 2           # AP surcharge to build a structure
@export var research_ap_cost: int = 1        # BASE research AP surcharge; per-tech TechDef.ap_surcharge
                                             # (ADR-0007) overrides, defaulting to this value
```

```gdscript
# balance.gd — Autoload "Balance", logic-free lookup only (mirrors MatchService, ADR-0001) — UNCHANGED
extends Node
var economy: EconomyConfig = preload("res://data/balance/economy_config.tres")
# No other fields. No methods beyond direct property access. Never mutates, validates, or interprets.
```

```gdscript
# Forward-declared contracts this ADR depends on — implemented by ADR-0007, not this ADR:
#   static func BaseProduction.completed_outpost_count(state: GameState, player: int) -> int
#   static func Research.economy_tech_income_bonus(state: GameState, player: int) -> int
#     ^ RETURNS THE FULLY-CAPPED TERM (research-tech.md formula). credit_income_breakdown()/
#       credit_income() add it as-is and never re-apply the cap.
#   var TechDef.ap_surcharge: int   # per-tech override of EconomyConfig.research_ap_cost (defaults to it)
# ECONOMY_TECH_INCOME_BONUS (value 1) is owned by Research's config; ap-economy.md is explicit it is NOT
# an economy tuning knob. economy_tech_tier_threshold (6) lives in EconomyConfig above and is read
# cross-system by Research's economy_tech_income_bonus() — economy-owned, Research-applied. The three
# *_ap_cost surcharges are likewise economy-owned, B&P-/Research-applied.
#
# Contract this ADR OWNS and forward-declares to consumers:
#   static func Credits.credit_income_breakdown(state, player) -> Dictionary { base, outpost, econ_tech }
#     — the per-term income decomposition the HUD renders (TR-hud-019, consumed by ADR-0016). Was
#       AP.ap_income_breakdown before the pivot; renamed with the pool it now denominates.
#
# Dual-cost contract this ADR OWNS (enforced by ADR-0002 validate-before-mutate; no rollback object):
#   economic verb handler validate(): Credits.can_afford(state, p, credit_cost)
#                                      AND AP.can_afford(state, p, ap_cost)
#   economic verb handler apply():     Credits.spend(state, p, credit_cost); AP.spend(state, p, ap_cost)
#   (optional convenience) spend_dual(state, p, credit_cost, ap_cost) -> bool  # check both, spend both
```

## Alternatives Considered

### Alternative 0 (pivot — pool count): Two mirrored classes `AP` + `Credits` — CHOSEN
- **Description**: Split the economy into two static utility classes, `Credits` a mirror of `AP` plus
  the income formula it owns.
- **Pros**: Each pool's public surface stays minimal and self-documenting (`AP.spend` vs
  `Credits.spend`); `Credits` reuses `AP`'s exact afford/spend shape; matches the sibling-verb-handler
  convention; the dual-cost gate reads as two named calls, not one overloaded one.
- **Cons**: Two files instead of one; a shared income/afford idiom is expressed twice (trivially).
- **Rejection Reason**: n/a (chosen).

### Alternative 0b (pivot — pool count): One `Economy` class owning both pools
- **Description**: A single `Economy` static class with `ap_spend`/`credits_spend`/`credit_income`/…
- **Pros**: One file; a natural home for a `spend_dual` helper.
- **Cons**: One class carries two distinct resources' full surfaces (afford/spend/reset/read ×2 plus
  income), a wider type than any sibling verb handler; the pool a call targets is a name *prefix* rather
  than the class, so mis-targeting (crediting AP, spending Credits) is a plain typo instead of a type
  mismatch.
- **Rejection Reason**: Two mirrored classes keep each pool's surface minimal and make the pool an
  identity (`AP.`/`Credits.`), not a prefix convention; `spend_dual`, if wanted, is a two-line free
  function or verb-handler helper that needs no shared class.

### Alternative 1 (module shape): Static utility classes — CHOSEN
- **Description**: Pure/static functions on stateless classes, `state` passed explicitly.
- **Pros**: Matches the verb-handler convention ADR-0002 set for every other Core system; trivially
  unit-testable (no instance to construct/inject); no lifetime-management question.
- **Cons**: None material — Godot has no meaningful cost difference between a static-function class and
  an instance holding no fields.
- **Rejection Reason**: n/a (chosen).

### Alternative 2 (module shape): Instance-based economy service object(s)
- **Description**: `AP`/`Credits` constructed once per match, injected into `apply_action`'s dispatch
  table like services.
- **Pros**: Would allow instance-scoped caching if `credit_income()` ever became expensive.
- **Cons**: The afford/spend/income functions have no per-instance state to justify an object; adds a
  construction/injection step ADR-0002's dispatch table doesn't otherwise need (Movement, Combat, etc.
  are all static too).
- **Rejection Reason**: No state to own; inconsistent with every sibling verb handler for no benefit.

### Alternative 3 (module shape): Methods directly on `GameState`/`PlayerState`
- **Description**: `credit_income()`/`spend()`/`can_afford()` become `GameState` methods, no separate
  `AP`/`Credits` classes.
- **Pros**: One fewer type; call sites read as `state.spend_ap(player, amount)`.
- **Cons**: Bloats `GameState`'s surface with every Core system's logic — directly against the
  module-ownership map, which keeps `GameState` a thin data/mutation-pipeline holder (ADR-0002's stated
  rationale, reused here).
- **Rejection Reason**: Would re-centralize logic ADR-0002 deliberately decentralized.

### Alternative 4 (config storage): One shared `EconomyConfig` Resource (grown to 10 fields) — CHOSEN
- **Description**: The existing `.tres` gains the AP-budget and surcharge fields, staying one config
  asset owned by the economy (mirroring `MapDefinition`, ADR-0005).
- **Pros**: Self-contained, inspector-editable; the AP budget, carryover, surcharges and income curve
  are one system's knobs and belong together; no coupling to unrelated systems' tuning.
- **Cons**: The AP surcharges are *read* by Base & Production and Research (cross-system read).
- **Rejection Reason**: n/a (chosen). The cross-system read is the same economy-owned/others-applied
  pattern already accepted for `economy_tech_tier_threshold`; the surcharges are a property of the
  tactical budget, so the economy is their correct owner (GDD Rule 3).

### Alternative 5 (config storage): AP surcharges on each structure/tech instead of `EconomyConfig`
- **Description**: `build_ap_cost` on `StructureTypeDef`, `produce_ap_cost` on `UnitTypeDef`, etc.
- **Pros**: The surcharge sits next to the Credit cost it accompanies.
- **Cons**: The AP surcharge is a global tempo rate-limit, not a per-structure trait — putting it per
  type invites divergent per-entity values that defeat the "how many economic actions fit in a turn"
  knob the pivot needs to tune globally; a single tempo pass would edit dozens of assets.
- **Rejection Reason**: The surcharge is one economy-wide tempo lever (GDD Rule 3). The **research**
  surcharge is the deliberate exception — techs legitimately want per-tech tempo cost — so
  `research_ap_cost` is a base with a per-tech `TechDef.ap_surcharge` override, not a per-tech-only field.

### Alternative 6 (config storage): GDScript `const`s on the classes
- **Rejection Reason**: Explicit `coding-standards.md` violation ("data-driven, never hardcoded"), same
  as the original decision.

### Alternative 7 (dual-cost enforcement): A transaction/rollback object
- **Description**: A `Transaction` that stages both spends and rolls back if either leg fails.
- **Pros**: Makes both-or-neither explicit at the mechanism level.
- **Cons**: Redundant — ADR-0002 already guarantees an illegal action makes zero state change (validate
  before mutate), and validating both pools before spending either means no leg can fail after the gate
  (deterministic, single-threaded). A rollback mechanism guards against a failure mode that can't occur.
- **Rejection Reason**: The both-or-neither guarantee already falls out of ADR-0002's atomicity plus a
  dual `can_afford` check in `validate()`; the optional `spend_dual` helper centralizes it without any
  rollback machinery or state-copying.

### Alternative 8 (outpost count source): Credits iterates `entities_by_id` directly
- **Rejection Reason**: Ownership violation — the forward-declared
  `BaseProduction.completed_outpost_count()` keeps structure-type/completion vocabulary inside Base &
  Production, same as the original decision (only the caller class changed from `AP` to `Credits`).

## Consequences

### Positive
- The economy's whole public surface is two small mirrored classes: `AP` (reset/afford/spend/read) for
  tactics, `Credits` (income/breakdown/add/afford/spend/credit/read) for economy — matching the GDD's
  documented interface exactly, no signature drift, and reusing the afford/spend shape verbatim.
- Config lives in one small, inspector-editable `.tres` (now 10 fields), satisfying the data-driven
  standard with no new machinery; the AP-budget/surcharge knobs sit beside the income curve they balance
  against.
- `EconomyConfig` staying off `GameState` keeps `duplicate_deep()`'s clone cost independent of the tuning
  surface — the AI's per-candidate clone loop (ADR-0011) never pays to copy constants, even with the five
  new fields.
- Dual-cost both-or-neither needs **no** new transaction/rollback code — it is a two-line pattern
  (validate both, spend both) that rides ADR-0002's existing atomicity, so the pivot adds a resource
  without adding a mutation vector.
- The C3 double-cap discipline, the forward-declared contracts, and the stub-based unit-test strategy all
  carry over unchanged — the pivot is a data-model change, not an architecture-pattern change.

### Negative
- Three forward-declared function contracts (`BaseProduction.completed_outpost_count`,
  `Research.economy_tech_income_bonus`) plus one forward-declared field (`TechDef.ap_surcharge`) exist
  only as signatures until ADR-0007 lands — `credit_income()` and the research surcharge can't be
  exercised end-to-end (only unit-tested against stubs) until then.
- Two thin static classes instead of one, and `current_credits` is a second `PlayerState` int the turn
  reset and spend paths must both maintain (mirrors `current_ap`, so low marginal risk).
- The dual-cost contract is a **discipline** the economic verb handlers must follow (validate both,
  spend both) rather than a mechanism that forces it — a handler that spends without validating both
  pools could half-commit. Mitigation: the optional `spend_dual` helper, plus a validation-criteria test
  per economic verb; flagged for the control manifest.

### Risks
- **A future system reaches into `EconomyConfig` and mutates it at runtime** — same determinism risk as
  the original decision; mitigation unchanged (code review; tuning data, not runtime state).
- **`completed_outpost_count`/`economy_tech_income_bonus`/`TechDef.ap_surcharge` signature drift** when
  ADR-0007 is authored. Mitigation: ADR-0007 must satisfy these contracts or explicitly supersede this
  section per the registry's `superseded_by` discipline.
- **An economic verb handler forgets the AP-surcharge leg** (spends Credits only), silently making an
  action free of tempo cost. Mitigation: the both-or-neither validation-criteria test per verb, the
  optional `spend_dual` helper, and a control-manifest guardrail that economic `apply()` bodies spend
  both pools.
- **Credit banking → snowball** (GDD Open Question): Credits now accumulate with no cap, so a saved war
  chest funds larger single-turn bursts than the old use-it-or-lose-it pool. The income *rate* is still
  capped (~26/~32) and the AP surcharge rate-limits bursts, but stock is unbounded. Out of scope for this
  ADR (a balance/tuning question owned by the GDD + playtest), flagged so a future economy revision or a
  soft Credit cap finds this note.
- **Faction Identity's income delta fold** (`Δ_base`/`Δ_tier1`/`Δ_tier2` + `BASE_INCOME_FLOOR`) now folds
  into `credit_income` rather than AP income — still deferred to the faction-asymmetry prototype and a
  no-op under the VS Neutral default; this ADR intentionally does not add a floor field or delta hooks to
  `EconomyConfig` now (ADR-0012 or a revision adds them when that prototype starts). The only change from
  the original note is the target formula's name.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ap-economy.md | Rule 1: AP is a flat per-turn budget (`FLAT_AP_PER_TURN + min(leftover, cap)`), not income-driven | `AP.reset_turn()` writes flat + capped carryover, reading the undiscarded leftover from `current_ap` |
| ap-economy.md | Rule 2: limited carryover, AP not discarded; max AP = flat + cap | `AP.reset_turn()`'s `min(leftover, ap_carryover_cap)`; `AP.discard()` removed; invariant enforced by construction |
| ap-economy.md | Rule 3: AP pays tactics plus a logistics surcharge (`PRODUCE/BUILD/RESEARCH_AP_COST`) | Three `*_ap_cost` fields on `EconomyConfig` (economy-owned), read by the economic verb handlers; `research_ap_cost` base + per-tech `TechDef.ap_surcharge` override |
| ap-economy.md | Rule 4: `ap_spend` sole atomic AP mutator, active-player-gated, no partial spend | `AP.spend()` — single gated deduction, all-or-nothing |
| ap-economy.md | Rule 5: `0 ≤ current_ap ≤ FLAT_AP_PER_TURN + AP_CARRYOVER_CAP`; only active player mutable | Enforced by construction: `reset_turn()`'s cap + `spend()`'s `amount ≤ current_ap` and active-player gates |
| ap-economy.md | Rule 6: Credits are a banked pool — income **added**, no cap, no discard | `Credits.add_income()` does `current_credits += credit_income()`, never a reset-to-snapshot |
| ap-economy.md | Rule 7: Credit income is a diminishing function of *completed* outposts, frozen at start-of-turn after build completions | `Credits.credit_income()` pure formula; `add_income()` invoked by ADR-0008 step 4b, after the build-timer advance |
| ap-economy.md | Rule 8: only completed outposts count; under-construction excluded | `n = max(0, completed_outpost_count())`, the forward-declared count returns completed-only |
| ap-economy.md | Rule 9/10: `credits_spend` sole atomic spend mutator; `credits_credit` cancel refund; `current_credits ≥ 0`, active-player-gated | `Credits.spend()` (mirror of `AP.spend`), `Credits.credit()` (third writer), non-negativity by construction |
| ap-economy.md | Rule 11: economic actions cost both, legal iff both afford, applied both-or-neither | Dual-cost contract: verb-handler `validate()` checks both `can_afford`, `apply()` spends both — safe under ADR-0002 validate-before-mutate |
| ap-economy.md | Rule 12: deterministic AP + Credit trajectories | Both classes' functions are pure/integer-only; no RNG, no float (satisfies ADR-0003's bans) |
| ap-economy.md | Formulas: tiered `credit_income` (`BASE_INCOME`, `OUTPOST_BONUS_TIER1/2`, `TIER_THRESHOLD`, `ECONOMY_TECH_TIER_THRESHOLD`) | `Credits.credit_income()` implements the exact formula; five income-curve fields on `EconomyConfig`, `ECONOMY_TECH_INCOME_BONUS` deliberately excluded (Research-owned) |
| ap-economy.md | Interactions: B&P supplies `completed_outpost_count`; Research supplies the Economy Tech bonus + `has_economy_tech`; both read the AP surcharges | Forward-declared `BaseProduction.completed_outpost_count()` / `Research.economy_tech_income_bonus()`; `*_ap_cost` read cross-system; `has_economy_tech` from the ADR-0001 field |
| coding-standards.md | Gameplay values must be data-driven (external config), never hardcoded | `EconomyConfig` `.tres` (10 fields), not GDScript consts |

## Performance Implications
- **CPU**: `credit_income()`/`can_afford()`/`spend()`/`reset_turn()`/`add_income()` are O(1) integer
  arithmetic. `credit_income()`'s cost is dominated by `BaseProduction.completed_outpost_count()` once
  ADR-0007 implements it (a per-player entity scan) — that budget belongs to ADR-0007/ADR-0011 (AI loop),
  flagged here so ADR-0007 accounts for `credit_income()` being called once per player per turn-reset at
  minimum and potentially many times per AI candidate evaluation. The dual-cost gate is two O(1)
  `can_afford` calls plus two O(1) `spend` calls — no added complexity class.
- **Memory**: `EconomyConfig` is a single small resource loaded once at boot, not per-clone — the five
  new fields add zero incremental cost to the AI's `duplicate_deep()` lookahead loop. `current_credits`
  is one new `int` per player on `GameState` (clones with it, negligible).
- **Load Time**: Negligible — one `.tres` preload at Autoload init.
- **Network**: N/A.

## Migration Plan
N/A — greenfield. Both `AP` and `Credits` classes and the `current_credits` field are on as-yet-
unimplemented Foundation classes (`GameState` is still `Proposed` at the code level); this revision
predates any AP-Economy implementation code, so there is no running code to migrate — only the ADR/GDD
corpus to keep consistent (tracked by the 2026-08-05 change-impact report).

## Validation Criteria
- **AP flat+carry**: `reset_turn()` with `ap_leftover = 0 → current_ap = 10`; `= 3 → 13`; `= 5 → 15`;
  `= 9 → 15` (carry capped at 5, not 19). Ending a turn with `current_ap = 7` then resetting → 15.
- **Credit income correctness**: for each GDD worked example (`n=0→10`, `n=4→18`, `n=5→19`, `n=8→22`;
  with Economy Tech `n=2→16`, `n=4→22`, `n=6→26`, `n=12→32`), `Credits.credit_income()` against stubbed
  `completed_outpost_count`/`has_economy_tech` returns the exact published value.
- **Credit banking**: `add_income()` with `current_credits = 6` and income 10 → 16 (added, not reset);
  two turns' income 10 then 12 without spending → 22 (accumulation, no cap, no discard).
- **Spend atomicity (both pools)**: over-budget `spend()` returns `false` leaving the field unchanged;
  `spend(0)` returns `true` and no-ops; negative returns `false`. Applies identically to `AP.spend` and
  `Credits.spend`.
- **Active-player gate**: `AP.spend()`/`Credits.spend()` against a non-active player's pool returns
  `false` and mutates nothing.
- **Dual-cost both-or-neither**: a (4 Credits, 1 AP) action with `current_credits=4, current_ap=10` →
  succeeds, pools reach `(0, 9)`; with `current_credits=4, current_ap=0` → **fails, neither pool
  changes**; with `current_credits=3, current_ap=10` → fails, neither changes. A (9 Credits, 2 AP) action
  with exactly `(9, 2)` → succeeds, both reach 0.
- **Cancel refund**: `Credits.credit(player, floor(build_cost × CANCEL_REFUND_RATE))` adds Credits back;
  no AP is refunded.
- **Frozen-income immunity**: after `add_income()`, mutating the stubbed `completed_outpost_count`
  mid-"turn" does not change `current_credits` until the next `add_income()` call.
- **Config load**: `Balance.economy` loads and matches defaults (`base_income=10`, tier1=2, tier2=1,
  threshold=4, economy_tech_tier_threshold=6, flat_ap_per_turn=10, ap_carryover_cap=5, produce_ap_cost=1,
  build_ap_cost=2, research_ap_cost=1).
- **Negative-count defense**: a stubbed `completed_outpost_count` returning negative still yields
  `credit_income() == base_income` (the `max(0, n)` floor), never below.

## Related Decisions
- ADR-0001: State model ownership & lifecycle (`PlayerState.current_ap`/**`current_credits`** [new]/
  `has_economy_tech` fields this ADR is the sole writer of; the `MatchService`-style thin-Autoload
  precedent reused for `Balance`)
- ADR-0002: Action / `apply_action` command model (`AP.spend()`/`Credits.spend()` called from inside a
  verb handler's `apply()`; its validate-before-mutate atomicity is what makes the dual-cost
  both-or-neither gate safe)
- ADR-0003: Deterministic simulation & RNG isolation (both classes' functions are integer-only, RNG-free,
  order-independent)
- ADR-0005: Grid representation & map-definition format (`EconomyConfig`-as-`.tres` reuses the
  `MapDefinition` config-asset pattern)
- ADR-0007: Data-driven entity/stat schema (implements `completed_outpost_count()` /
  `economy_tech_income_bonus()`; adds `TechDef.ap_surcharge`; cost fields are now Credit-denominated)
- ADR-0008: Shared start-of-turn sequencing (owns *when* `AP.reset_turn()` and `Credits.add_income()` are
  called — the old single `AP.reset_turn()` step splits into 4a+4b; `AP.discard()` is removed from
  `EndTurnAction`)
- ADR-0016: Game HUD (renders `Credits.credit_income_breakdown()` and a dual AP+Credits counter)
- ADR-0017 / ADR-0018: Base & Production / Research (the dual-cost economic verb handlers; refunds via
  `Credits.credit()`)
- ADR-0012: Faction cross-cutting fold pattern (future home of the deferred income-delta fold +
  `BASE_INCOME_FLOOR` guard, now targeting `credit_income`)
