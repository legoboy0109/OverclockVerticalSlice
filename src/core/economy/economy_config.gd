## EconomyConfig — data-driven tuning constants for the AP & Credits Economy.
##
## Foundation-layer config asset per ADR-0006. A dedicated [Resource] (`.tres`),
## mirroring the `MapDefinition` config-asset pattern (ADR-0005) — never
## GDScript `const`s, never stored on [GameState] (it is static, shared,
## read-only build data, not per-match mutable state, so it must never ride
## along on [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]Balance[/code] Autoload
## and read via [code]Balance.economy[/code] — never threaded through call
## sites as an explicit parameter. Its ten fields fall in three groups
## (the 2026-08-05 AP↔Credits pivot added the last five):
## [br]• [b]Credit-income curve[/b] (`base_income`, `econ_tier_bonus`, `max_economy_tier`)
##   — read by [code]Credits.credit_income()[/code] (the research-tier income curve).
## [br]• [b]AP tactical budget[/b] (`flat_ap_per_turn`, `ap_carryover_cap`) — read by
##   [code]AP.reset_turn()[/code]. Flat per-turn, not income-driven.
## [br]• [b]AP logistics surcharges[/b] (`produce_ap_cost`, `build_ap_cost`,
##   `research_ap_cost`) — economy-owned, read cross-system by Base & Production /
##   Research on each economic action (the tempo half of the dual-cost gate).
##
## [b]Deliberately excluded (see ADR-0006 Risks):[/b] no `base_income_floor`
## field and no faction income-delta fields exist here. ADR-0006's Risks
## section explicitly defers the Faction Identity income-delta fold and its
## `BASE_INCOME_FLOOR` guard to the Alpha faction-asymmetry prototype
## (ADR-0012) — adding them now would be speculative, unexercised surface.
##
## Usage:
## [codeblock]
## var cfg: EconomyConfig = Balance.economy
## var income: int = cfg.base_income + cfg.econ_tier_bonus * tier
## [/codeblock]
class_name EconomyConfig
extends Resource

# --- Credit-income curve (funds the banked Credits pool; ADR-0006) ---
#
# ★ RE-BASED 2026-08-24 (S6-01). Income was driven by a diminishing per-outpost
# curve; the Economy Outpost is now DELETED and income comes from a finite
# research spine. The removed fields were `outpost_bonus_tier1`,
# `outpost_bonus_tier2`, `tier_threshold` and `economy_tech_tier_threshold`.
#
# WHY: production/vertical-slice/REPORT.md returned PIVOT. Credits were unbounded
# (peak 5,724, still climbing linearly at turn 200), so economy actions always
# outscored manoeuvring and no match ever resolved. The old curve tiered DOWN but
# never stopped — a soft brake. Three research tiers is a hard stop.
#
# ★ All Credit quantities are ×100 vs the pre-2026-08-24 scale (user decision):
# the extra granularity is what lets upkeep differentiate units that would
# otherwise be forced onto the same integer.

## Flat Credit income every player earns each turn regardless of board state.
## ★ The board no longer contributes to income at all — this plus the tier term
## is the whole formula.
@export var base_income: int = 1000

## Credit income added per completed economy research tier.
@export var econ_tier_bonus: int = 500

## Number of economy tiers that exist. ★ THIS IS THE ECONOMY'S HARD CEILING:
## income tops out at `base_income + econ_tier_bonus * max_economy_tier` (2,500)
## and cannot grow further by any means. Raising it re-opens the unbounded-economy
## defect the PIVOT verdict diagnosed — do not treat it as a routine tuning knob.
@export var max_economy_tier: int = 3

## Credit cost of each economy tier, escalating: 1,000 / 2,000 / 3,500. Length must
## equal [member max_economy_tier].
##
## [b]Temporarily housed here.[/b] Tier costs are Research-owned by design
## (design/gdd/research-tech.md), but the Research system does not exist yet — only a
## test stub. Parking them in the economy config keeps them data-driven and keeps the
## AI's load-time lethal-floor invariant computable against a real number instead of a
## literal. ★ Move to Research's own config resource when that system lands (S6-05+).
##
## Flat +[member econ_tier_bonus] per tier against an escalating cost gives diminishing
## returns on investment without a diminishing benefit: each tier still feels like a
## real upgrade, but the third pays back in ~7 turns against a 30-round match.
@export var econ_tier_costs: PackedInt32Array = PackedInt32Array([1000, 2000, 3500])

# --- Upkeep (the Credit drain; S6-02, unit-upkeep.md) ------------------------

## Divisor in the derived-upkeep convention. Lower = harsher, smaller armies,
## faster games. ★ Tune this to hit a TARGET EQUILIBRIUM ARMY of 7-9 units rather
## than for its own sake — the army size is the number with a felt meaning.
@export var upkeep_divisor: int = 3

## Rounding step for derived upkeep. ★ LOAD-BEARING, not cosmetic: before the ×100
## Credit rescale the derivation was a bare `ceil(produce_cost / 3)`, and it produced
## the intended 1/2/2/3 only because `ceil` rounded hard on single-digit numbers. At
## the new scale that rounding vanishes (67/134/167/234), every value drifts LOW, the
## roster mean falls 200 -> ~150, and the sustainable army rises ~9 -> ~12 against a
## cap of 10 — silently breaking the "cap binds first, upkeep binds shortly after"
## relationship population-cap.md is built on. Rounding up to this step restores it.
@export var upkeep_granularity: int = 100

## AP spent to voluntarily destroy one's own unit (unit-upkeep.md UR-7). ★ Disband is
## the escape valve the deficit lock depends on: without it, an over-extended player
## has no agency in recovering, only the hope of losing units in combat.
@export var disband_ap_cost: int = 1

## Fraction of `produce_cost` refunded in Credits on disband, as a percentage.
## ★ A rate, not a quantity — unaffected by the ×100 rescale. Above ~60 invites
## produce/disband churn; at 0 nobody uses the escape valve UR-6 depends on.
@export var disband_refund_pct: int = 50

# --- AP tactical budget (the per-turn action-point pool; ADR-0006 pivot) ---

## Flat AP granted at every start-of-turn reset — the tactical budget floor.
## Not income-driven: AP does not scale with the economy (contrast the Credit curve).
@export var flat_ap_per_turn: int = 30

## Max unspent AP that carries into the next turn (any excess is lost). Start-of-turn
## AP = flat_ap_per_turn + min(leftover, ap_carryover_cap), so max AP = 45 at defaults.
## ★ Rescaled ×3 on 2026-08-24 (user decision) while AP ACTION costs were deliberately
## left unchanged: at 10 AP an army above ~5 units had members standing idle every turn
## regardless of player intent, which made larger rosters unusable. Accepted cost — AP is
## now less scarce, which dilutes Pillar 1. The restoring dial is the *_ap_cost surcharges
## below, NOT cutting this back (that re-creates the idle-army problem).
@export var ap_carryover_cap: int = 15

# --- AP logistics surcharges (economy-owned; read by B&P / Research per action) ---

## AP surcharge spent (on top of the Credit cost) to produce a unit — the tempo
## half of produce's dual-cost gate.
@export var produce_ap_cost: int = 1

## AP surcharge spent (on top of the Credit cost) to build a structure.
@export var build_ap_cost: int = 2

## BASE AP surcharge spent (on top of the Credit cost) to research a tech. A tech
## may override this per-tech via `TechDef.ap_surcharge` (Research-owned), which
## defaults to this value.
@export var research_ap_cost: int = 1
