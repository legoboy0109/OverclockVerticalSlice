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
## [br]• [b]Credit-income curve[/b] (`base_income`, `econ_tier_bonuses`, `max_economy_tier`)
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
## var income: int = cfg.base_income + Credits.tier_income(tier)
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
## ★ 2026-09-29 (user decision): 1000 → 1500. At 1000 the AI fielded under 2 fighters at a time,
## so armies never formed groups and big-map games dragged on (Highlands HQ kills averaged 84
## rounds). At 1500: Crossroads 28/30 decisive in ~34 rounds, Highlands 25/30 in ~51, and groups
## of 3+ on 17-31% of turns (design/decision-log.md, "Army size is the real lever").
@export var base_income: int = 1500

## Credit income each economy research tier ADDS, in order: tier 1, tier 2, tier 3.
## ★ 2026-10-01 (user decision): escalating, +500 / +800 / +1,200 (was a flat +500), and every
## Economy-tree tech now grants a tier — so a fully researched economy earns 1,500 -> 4,000.
## Faction slopes ([member FactionDef.econ_tier_bonus_delta], Ross +200) still add per tier.
## Length must equal [member max_economy_tier].
@export var econ_tier_bonuses: PackedInt32Array = PackedInt32Array([500, 800, 1200])

## Number of economy tiers that exist. ★ THIS IS THE ECONOMY'S HARD CEILING:
## income tops out at `base_income + sum(econ_tier_bonuses)` (4,000)
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
## (Legacy: these costs predate the branching tech trees, whose Economy techs carry their own
## prices; only the AI's load-time lethal-floor invariant still reads tier 1's.)
@export var econ_tier_costs: PackedInt32Array = PackedInt32Array([1000, 2000, 3500])

# --- Upkeep (the Credit drain; S6-02, unit-upkeep.md) ------------------------

## ★ 2026-09-30 (user decision): match rule — false turns the whole upkeep drain off (units AND
## structures cost nothing per turn), for testing the economy with and without it. Chosen on the
## skirmish setup screen ([member MatchSettings.upkeep_enabled]) and applied to the per-match
## copy by [method Balance.apply_match]; the shipped config keeps it on.
@export var upkeep_enabled: bool = true

## Divisor in the derived-upkeep convention. Lower = harsher, smaller armies,
## faster games. ★ Tune this to hit a TARGET EQUILIBRIUM ARMY of 7-9 units rather
## than for its own sake — the army size is the number with a felt meaning.
@export var upkeep_divisor: int = 3

## ★ 2026-09-29 (user decision): class scaling on the derived upkeep convention
## ([method Upkeep.default_upkeep]). Cheaper infantry and dearer vehicles, so that with the
## infantry cap raised to 16 upkeep — not the cap — still limits army size, and infantry keep a
## late-game niche besides piloting. Percent of the price-derived figure.
## ★ 2026-10-01 (user decision): vehicles 150 -> 75 "so the AI fields more vehicles" — at 150 a
## Tank's upkeep equalled 5 Troopers' and the AI's army upkeep already ate its whole income —
## and then infantry 75 -> 50 ("reduce the infantry" upkeep). Measured (12-game batches): vehicle
## production share Accord 7% -> 11%, Wolf v Ross 3% -> 7%; armies on the board grow (Accord
## 3.2 -> 3.8 per side, toward the 7-9 target above) and Crossroads games run longer (77 -> 106
## turns). 60% infantry was worse on both counts (vehicle share fell, round-cap stalemates).
@export var infantry_upkeep_pct: int = 50
@export var vehicle_upkeep_pct: int = 75

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
##
## ⚠ [b]SET TO 20 ON 2026-08-26 (user decision, S8-23) — DELIBERATELY AGAINST THE
## ADVICE IN THE `ap_carryover_cap` NOTE BELOW.[/b] That note says the restoring dial
## for AP scarcity is the `*_ap_cost` surcharges and NOT cutting this value, because
## cutting it re-creates the idle-army problem the ×3 rescale was made to fix.
## [br][br]The idle-army arithmetic at 20, stated so it is not rediscovered:
## a Trooper costs 4 AP to move and attack, so [b]20 AP fully activates 5 units[/b]
## (7 at 30). Population caps at `base_infantry_cap` 4 + 2 per Barracks = 10 realistic,
## so [b]a full army leaves ~5 units idle every turn.[/b]
## [br][br]★ Taken anyway and on purpose: it is an [i]experiment in tempo pressure[/i].
## AP being cheap is what the rescale note itself records as diluting Pillar 1, and
## whether scarcity feels like a meaningful constraint or like being denied your turn
## is exactly the kind of question only a person playing can answer. ⛔ [b]It is
## therefore UNMEASURED: every balance sweep (S7-09…S7-17) ran at 30.[/b]
@export var flat_ap_per_turn: int = 20

## Max unspent AP that carries into the next turn (any excess is lost). Start-of-turn
## AP = flat_ap_per_turn + min(leftover, ap_carryover_cap), so max AP = 45 at defaults.
## ★ Rescaled ×3 on 2026-08-24 (user decision) while AP ACTION costs were deliberately
## left unchanged: at 10 AP an army above ~5 units had members standing idle every turn
## regardless of player intent, which made larger rosters unusable. Accepted cost — AP is
## now less scarce, which dilutes Pillar 1. The restoring dial is the *_ap_cost surcharges
## below, NOT cutting this back (that re-creates the idle-army problem).
## ⚠ 15 -> 10 on 2026-08-26 (S8-25, user decision), restoring the RATIO the rescale set.
## Carryover was 50% of a turn's budget at 15/30; leaving it at 15 against S8-23's new 20
## made it 75%. 10/20 is 50% again — a correction back to the intended proportion.
##
## ⛔ [b]KNOW WHAT THIS MEANS BEFORE READING `flat_ap_per_turn` AS THE BUDGET.[/b] Turn 1
## starts at 20; every turn after starts at [b]30[/b] for any player who ended the previous
## turn with 10+ unspent — which, with a small early army, is most turns. So the shipped
## economy is [b]20 flat / 30 effective[/b], and the S8-23 cut only bites on turns you
## spend hard.
## ★ Raised as a possible defect on 2026-08-26 ("the build still has 30 AP per turn") and
## [b]KEPT DELIBERATELY[/b] (user decision, same day) once measured. It is not an
## oversight and should not be "fixed" by a later reader: banking a quiet turn into the
## next one is the intended rule, and 0 carryover was the offered alternative and was
## declined.
@export var ap_carryover_cap: int = 10

## ★ S7-16 — one-off AP granted to the player who moves FIRST, on their first turn only.
##
## [b]Compensation for a measured second-mover advantage.[/b] With every enumeration-order bias
## removed (S7-13/14/15) the mirror cell — the only cell that can measure a turn-order effect,
## since every handicap cell starts with a material asymmetry that swamps it — reads:
## [codeblock]
##   12 symmetric openings, alternating who starts
##   the SECOND mover wins 10/12
##   the two the FIRST mover wins are the only two that resolve on play (43 turns)
## [/codeblock]
## ★ The shape matters: the second mover's ten wins are all at the round cap, decided by the
## unit-count tiebreak. The first player commits into the open, the second answers with full
## information about that commitment, and the first ends marginally behind on units. That is
## exactly the mechanism `S5-04` guessed at before any of this was measured.
##
## ⚠ [b]Direction was reversed twice before it was trusted.[/b] Measured with the movement bias
## present it looked like a FIRST-mover advantage; with movement fixed but placement still
## biased it looked like one again. Only once the seat matrix read a clean 7/7 did the sign
## settle. **Do not re-derive this from a partially-cleaned batch.**
##
## Applied by [method GameState.start_turn] on round 1 to
## [member GameState.starting_player] only. 0 disables it entirely.
##
## ⛔⛔ [b]MEASURED AND IT DOES NOT WORK. Ships at 0 deliberately — do not raise it without
## reading this.[/b] Swept 0 / 5 / 10 / 15 / 20 / 30 against the 12-opening mirror cell:
## [codeblock]
##   bonus    first-mover wins    resolved on play    mean turns
##     0           2/12                2/12              73.8
##     5           2/12                2/12              73.8
##    10           2/12                2/12              73.8
##    15           2/12                2/12              73.8
##    20           2/12                2/12              73.8
##    30           2/12                2/12              73.8
## [/codeblock]
## Not one game changed, at any value, including one that DOUBLES the opening turn. The bonus
## verifiably lands (turn-1 AP reads 30 → 60 in the batch rows), so this is a real negative,
## not another silent no-op.
##
## ★★ [b]Why: AP was never the scarce resource.[/b] The first player spends [b]11 of 30[/b] AP
## on turn 1, and by turn 3 is sitting at 45 — [member ap_carryover_cap] saturated — while
## spending 6. **They already discard AP every single turn.** Handing them more is handing them
## more of something they are throwing away.
##
## ★ And the advantage being compensated is [b]informational, not economic[/b]: the second
## mover answers a commitment it can already see. No amount of a non-binding currency addresses
## that.
##
## ⚠ Kept rather than deleted so the idea is not re-tried from scratch. A compensation that
## could work has to be denominated in something actually scarce — production rate
## (⚠ S7-10 said `production_cooldown_turns` was the binding constraint; that field was retired at S8-28 and the constraint is now `UnitTypeDef.production_turns`) or material. ★ Or note that
## all ten second-mover wins are [b]round-cap tiebreak[/b] wins on unit count, while the only
## two games that resolve on play go to the FIRST mover — which suggests the effect may be an
## artifact of the tiebreak metric rather than a play advantage at all.
@export var first_turn_ap_bonus: int = 0

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

## ★ 2026-09-30 (user decision): AP to RUSH a construction site or a vehicle/aircraft in
## production — each rush removes one turn from its timer, never below "ready at the start of
## the owner's next turn", so a rushed thing is still never usable the turn it was rushed.
## Flat per turn removed (not scaled by price) so the cost reads at a glance. ⚠ Starting value,
## untuned: against a 20-AP turn, 4 = one rush costs about two moves.
@export var rush_ap_cost: int = 4
