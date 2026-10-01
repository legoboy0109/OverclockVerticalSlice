## AIConfig — AI Opponent's 15 externally-tunable scoring knobs + pacing.
##
## Feature-layer config asset per ADR-0011 §6. A dedicated [Resource] (`.tres`),
## mirroring [CombatConfig]/[EconomyConfig]/[UnitConfig]'s config-as-Resource
## pattern (ADR-0006/0009/0010) — never GDScript `const`s, never stored on
## [GameState] (it is static, shared, read-only tuning data, so it must never
## ride along on [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]AIBalance[/code] Autoload
## (a sibling of [code]Balance[/code]/[code]UnitBalance[/code]/
## [code]CombatBalance[/code]/[code]StructureBalance[/code]) and read via
## [code]AIBalance.ai.*[/code].
##
## [b]Pure data only.[/b] This Resource holds no invariant-checking logic of
## its own — the `lethal_floor_bonus > economy_ceiling_score` cross-knob
## invariant (TR-ai-008) is enforced by [code]AIBalance[/code] at load time,
## never here (ADR-0011 §6: "the invariant check belongs in the loader
## Autoload... not inside AIConfig, which stays a pure data Resource").
##
## [b]Deliberately excluded (ADR-0011 §6):[/b] `REACHABILITY_MULTIPLIER`'s
## fixed `{0.9, 1.0, 1.1}` band is a code constant inside the future `AI`
## class, not a field here (the GDD calls it a deliberately-non-tunable
## "fixed 3-band"). `CANCEL_REFUND_RATE` is Base & Production-owned
## ([member BaseProductionConfig.cancel_refund_pct]) and is read from there,
## never duplicated here.
class_name AIConfig
extends Resource

## Global hp-to-AP exchange rate anchoring `combat_value` and
## `research_value`'s Attack/Defense Tech term.
## ★★ Converts one Credit into AP-equivalent terms, so CR-3's single scoring scale can
## compare an economic action against a tactical one (`ai-opponent.md`).
##
## [b]0.01, and the value is derived rather than tuned.[/b] The 2026-08-24 rescale
## multiplied every Credit quantity by 100 while deliberately leaving AP *action* costs
## alone, so 1 Credit is worth 1/100th of what it was against an unchanged AP cost.
##
## ★ [b]Left at 1.0 this is not a rounding error, it is the PIVOT defect returning.[/b]
## Credit-denominated VALUE terms (a target's `produce_cost`, a unit's `produce_cost`)
## scale ×100 while AP-native terms (`positional_value_per_tile_closed` 0.16) do not — so
## a kill would outscore a march by ~100×, the AI would only ever trade, and the
## regression batch would report that the economy fix had failed when it had not.
##
## ★ [b]Do NOT apply it to a term that is already AP-equivalent[/b] — notably
## [member hq_siege_value], which is a weight rather than a Credit quantity. Converting it
## twice would restore exactly the "armies trade in the middle and never siege" behaviour
## the verdict diagnosed.
@export var credit_to_ap_rate: float = 0.01

@export var hp_per_ap: float = 1.5

## Fraction of a kill victim's sunk AP credited as bonus `combat_value`.
@export var kill_denial_rate: float = 0.5

## Future turns of income counted toward `economy_value` and Economy Tech's
## `research_value`.
@export var economy_horizon: int = 6

## Horizon for permanent tech effects (turns). ★ 2026-10-01: raised 10 -> 20: a tech is
## permanent, so counting only 10 turns made research lose to units every time — in sims the AI
## never researched past tier 1. Capped by the rounds the match has left ([method AI._tech_horizon]).
## Income techs (Economy Tech) stay on [member economy_horizon] like every other income projection:
## at 20 turns +500 Credits/turn outscored the whole opening and the AI fielded no army.
@export var tech_value_horizon: int = 20

## Per-turn discount for tech value. Gentler than [member economy_decay] (0.85) because a
## tech's payoff is certain and permanent, where projected income/positions are speculative.
@export var tech_value_decay: float = 0.9

## Research is not considered until the AI owns this many fighting (non-Builder) units.
## ★ 2026-10-01: with tier 1 at 800 Credits the AI could afford Industrial Base on turn 1, which
## pushed its first fighter past turn 6 (tests/integration/ai-opponent/ai_plays_a_real_opening_test).
@export var research_min_army: int = 1

## How far a match's seed may lean each tech's research score: a factor in
## [code][1 - v, 1 + v][/code], fixed for the whole match. Big enough to flip close branch
## choices from match to match, not to make the AI take a clearly worse tech. 0 = off.
@export var research_variety: float = 0.5

## Per-turn discount applied to projected future value.
@export var economy_decay: float = 0.85

## Secondary cadence guardrail: max economy-outpost + research commits the
## AI makes in one turn. Cap *enforcement* lands in Story 004 — this Resource
## only stores the knob, per this story's scope.
@export var max_economy_investments_per_turn: int = 2

## Fixed `action_score` floor for a finishing/immediately-lethal attack
## (CR-7). Must stay above `economy_ceiling_score` — enforced at load time
## by [code]AIBalance[/code], not here.
@export var lethal_floor_bonus: float = 3.5

## Minimum `action_score` a candidate must clear for the AI to act on it.
@export var pass_threshold: float = 0.15

## Stated assumption for attacks landed per turn — converts a flat
## Attack/Defense Tech stat bonus into a per-turn AP-equivalent rate.
@export var attacks_landed_per_turn_estimate: float = 1.5

## Positional value per tile of distance closed toward the contested front,
## for a non-attacking move (tiles-normalized, not AP-cost-divided).
@export var positional_value_per_tile_closed: float = 0.16

## Flat `positional_value` bonus when a non-attacking move lands on a tile
## that sets up a next-turn attack (the push-enabler term).
@export var setup_advance_bonus: float = 0.4

## An owned unit at/below this fraction of max hp, if also inside an enemy's
## next-turn threat range, generates a retreat candidate.
@export var retreat_hp_fraction: float = 0.30

## Positional value per tile a wounded, endangered unit puts between itself
## and the nearest threat (tiles-normalized).
@export var retreat_value_per_tile_fled: float = 0.20


## ★ S8-27 — value multiplier for producing a unit onto a deploy tile where an enemy
## can [b]kill it outright[/b] before it ever acts.
##
## ⛔ [b]Fixes a total deadlock in a third of matches.[/b] Both AIs build a Barracks
## toward the middle, so their deploy rings end up adjacent. Production scoring rewarded
## forward tiles through `_reachability_multiplier` and had [b]no counterweight for the
## unit dying immediately[/b] — so each side produced one Sniper per turn (attack 6 vs a
## Sniper's 3 hp, an instant one-shot), traded it, and repeated. Population never exceeded
## 1 on either side, no HQ was ever damaged, and both banked ~24,000 Credits until the
## round cap. Measured 10/30 games before this, 0 after.
##
## ★ A MULTIPLIER, NOT A VETO, and that distinction matters: if every deploy tile is
## threatened — a base under siege — a vetoed candidate would leave the AI unable to
## produce [i]at all[/i], which is a worse deadlock than the one being fixed. At 0.15 a
## safe tile beats a lethal one decisively while a lethal deploy still beats doing nothing.
##
## ⚠ Applies only to an [b]outright kill[/b] (predicted damage >= the new unit's full hp),
## not to any threatened tile. Deploying into danger is often correct; deploying into
## guaranteed death before the unit acts never is.
@export var deploy_into_death_penalty: float = 0.15

## ★ S7-11 — flat `positional_value` / `retreat_value` bonus for ENDING a move on a
## Cover tile.
##
## [b]Sized against what Cover actually buys.[/b] [member CombatConfig.cover_dr] is a flat
## −1 damage, and only for a [UnitState] defender (structures are cover-immune,
## combat-resolution Rule 6). Against the roster's commonest attack (Trooper, 3) that turns
## a 2-hit kill into a 3-hit kill — about +50% effective durability, which is worth more
## than closing one tile (0.16) and less than enabling a next-turn attack (0.4).
##
## ⚠ [b]Applied only to tiles the AI would already consider[/b] — a strictly-closing advance,
## or a wounded unit's retreat. It deliberately does NOT create a new "sidestep onto cover"
## move category: a non-closing move scored on a flat bonus is exactly the shape that made
## the AI ping-pong until its AP drained, which is why every branch in
## `_score_positional_and_retreat_candidates` carries a strict-progress gate. Cover breaks
## ties among good moves; it never becomes a reason to stop advancing.
##
## ⚠ The attack side needs no term at all — `_consider_attack` scores through
## [method Combat.preview_damage], which already applies `cover_dr`, so a target standing in
## cover scores lower automatically and always has.
@export var cover_value: float = 0.30

## ★ S7-11 — how many tiles of approach a Cover tile is worth when the advance fold picks
## which closing tile to take.
##
## [b]Measured at 0, and that is not laziness.[/b] The obvious idea — let a unit accept one
## tile less progress to end in cover — was implemented and tested, and it made cover usage
## WORSE, not better:
##
## [codeblock]
## cover-blind AI (incidental only)      5.5 % of units standing in cover
## cover_value only (tie-break)          6.1 %
## cover_value + discount 1              4.7 %   <-- worse than blind
## [/codeblock]
##
## ★ The reason is instructive: a unit that steps back into cover is further from the enemy,
## so next turn it advances again and immediately LEAVES the cover. The discount bought more
## time walking, not more time protected. **Cover pays a defender who stays put, and this AI
## does not stay put** — every branch of its movement scoring is advance, siege or retreat.
##
## Left as a live knob because it becomes correct the moment the AI gains a hold-position
## behaviour. Until then it should stay 0.
## ★ 2026-10-01: that behaviour now exists, but only for a player owning a Cover tech — see
## [member cover_seek_discount] / [member cover_hold_radius]. Without one, still 0.
@export var cover_tile_discount: int = 0

## ★ Cover play (2026-10-01, user direction: "make the AI use cover when it has Ambush or Dig In").
## Applies only to infantry of a player owning a Cover tech (a nonzero
## [code]infantry_cover_attack[/code] or [code]cover_heal[/code]):
## [br]• An advancing unit counts a Cover tile as [member cover_seek_discount] tiles nearer than
## it is, so it will take a little less ground to end in Cover.
## [br]• A unit already in Cover HOLDS — no advance or siege step — while an enemy is within
## [member cover_hold_radius] tiles, unless its group is pushing for the HQ. It still attacks from
## where it stands (Ambush applies) and heals there (Dig In). This is the "stays put" half the
## [member cover_tile_discount] measurement said was missing.
@export var cover_seek_discount: int = 2
@export var cover_hold_radius: int = 5

## ★ Saving for vehicles (2026-10-01, user direction: "tune the AI to use more vehicles").
## Measured: with a Factory standing idle, 340 of 351 turns the AI could not afford a Tank — it
## held ~560 Credits against a 1,400 price because it spent every Credit on infantry as soon as it
## had it. When a vehicle/aircraft at an idle producer outscores the best infantry buy by
## [member vehicle_save_margin], and net income covers the gap within [member vehicle_save_turns]
## turns, the AI keeps that vehicle's price in reserve: no infantry production or research may
## spend below it (Builders exempt). Off = the old spend-everything behaviour.
@export var vehicle_saving: bool = true
@export var vehicle_save_turns: int = 3
@export var vehicle_save_margin: float = 1.0

## ★ Army mix (2026-10-01). Saving alone barely moved vehicle counts (16 -> 19 per 12 games):
## on value per lifetime Credit the AI rates a Heavy above a Tank in most matchups, so it never
## WANTS the vehicle it could save for. Below [member vehicle_share_target] of its fighters being
## vehicles/aircraft, those types' production value is multiplied by up to
## [code]1 + vehicle_mix_bonus[/code], tapering to 1 as the share reaches the target. 0 = off.
@export var vehicle_share_target: float = 0.3
@export var vehicle_mix_bonus: float = 0.6

## ★ Upkeep room for a vehicle (2026-10-01). The mix bonus alone moved little (17 -> 21 vehicles
## per 12 games) because the real limit is UPKEEP: the AI's army upkeep averaged ~1,500/turn,
## i.e. its whole income, filled with infantry first — so a Tank's 750/turn never fitted, and
## buying one anyway tipped it into deficit (which freezes production). While vehicles are under
## [member vehicle_share_target], an idle vehicle producer exists and the AI fields at least
## [member vehicle_room_min_army] fighters, it buys no infantry whose upkeep would leave less net
## income than the best vehicle's upkeep. Losses then free budget for the vehicle instead.
@export var vehicle_room_min_army: int = 3

## `ap_cost_opponent_paid_for` weight for the enemy HQ (which has no
## `build_cost`) — a siege-priority weight, not a sunk-cost figure.
## ★★ RAISED 12 -> 60 (S6-07c, user's lever: "make the objective outscore trading").
##
## At 12, a 5-damage HQ chip scored **0.75** against **3.00** for killing a full-hp Trooper,
## so a unit standing beside an enemy HQ would break off and fight rather than finish the
## job. Four measured batches showed damage reaching 21 of 40 hp and stalling for exactly
## that reason. **48 is the arithmetic break-even; 60 gives a ~25% margin** so the objective
## wins clearly rather than by a rounding error.
##
## ⚠ [b]This number compensates for a modelling flaw rather than fixing it, and that is worth
## knowing before it is tuned again.[/b] [method AI._combat_value] scales value by
## `hp_removed / max_hp`, which is right for a UNIT — a half-dead unit is still a unit, and
## damage to it is worth roughly its share of the whole. It is wrong for a WIN CONDITION: an
## HQ at 1 hp is nearly a victory, not "1/40th of a structure". The proportional form makes
## every individual chip look small no matter how close the game is to ending.
##
## ★ The principled fix is to value HQ damage as progress toward victory (superlinear, or
## flat-per-hp) rather than as a share of the target's health. Recorded as the next thing to
## do here if 60 proves either too weak or too suicidal.
@export var hq_siege_value: int = 60

## Score per tile of distance closed toward the ENEMY HQ, for a bare advance that is
## not closing on the nearest enemy — [b]the siege drive[/b].
##
## [b]Why this exists.[/b] An AI-vs-AI simulation over 20 matches recorded ZERO HQ
## damage across 4,182 turn-rows: the AI values the HQ as a TARGET generously
## ([member hq_siege_value] 12) but had no term pulling it TOWARD one. Its only
## positional objective was "close on the nearest enemy", and since both sides keep
## producing, the nearest enemy is always a unit and the armies stall mid-map forever.
## A high value on something you never stand next to is never realised. See
## `production/playtests/swing-back-simulation-appendix-2026-08-21.md`.
##
## [b]Why it sits ABOVE [member positional_value_per_tile_closed] (0.16).[/b] Below it,
## the AI keeps preferring to shuffle toward whichever enemy is nearest and the stall
## simply returns. Actual attacks are unaffected — the move+attack combo loop scores far
## higher than any bare advance — so this only ever competes with aimless advancing, and
## there it should win: progress toward the objective beats progress toward nothing in
## particular.
##
## Must stay above [member pass_threshold] (0.15) or the AI will decline to siege at all.
@export var siege_value_per_tile_closed: float = 0.20

## ★ Ammo (2026-10-01): value per tile an EMPTY vehicle/aircraft closes on its nearest own
## resupplying structure. Above the siege rate so a dry unit always heads home rather than
## being folded into the push, and above [member pass_threshold] so the move is committed.
@export var resupply_value_per_tile_closed: float = 0.25

## ★ Supply Depots (2026-10-01). A depot is valued by the resupply trip it saves: the sum, over
## every own ammo-using unit, of how many tiles nearer its nearest supplier would be with the
## depot on the candidate tile, times this rate (AP-equivalent per unit-tile). A depot at home
## saves nothing — the HQ and factories already supply there — so it scores ~0 on its own.
@export var depot_value_per_unit_tile: float = 0.15

## A depot is only worth considering once this many own vehicles/aircraft exist.
@export var depot_min_units: int = 2

## The most Supply Depots (built + under construction) the AI keeps at once.
@export var depot_max_owned: int = 2

## A Builder only walks forward to raise a depot when some ammo-using unit is at least this many
## tiles from its nearest supplier — a shorter trip is not worth risking the Builder.
@export var depot_trip_trigger_tiles: int = 5

## ★ Rush (2026-10-01). One turn sooner is worth this fraction of what is being made (its
## Credit cost, in AP-equivalent). 0.07 × a 1400-Credit Tank ≈ 0.98 AP of value against a 4 AP
## rush ⇒ score ≈ 0.245: worth it when nothing better is on offer, never ahead of a good attack.
## (0.15 scored a Tank rush at 0.525, above most moves, so the AI rushed every Tank.)
@export var rush_turn_value_fraction: float = 0.07

## Multiplier on rush value when an enemy unit is within [member rush_threat_radius] tiles of the
## structure — a defender or a finished building arriving a turn early matters most under attack.
@export var rush_threat_multiplier: float = 2.0
@export var rush_threat_radius: int = 6

## Tolerance below which two `action_score` values are treated as tied,
## triggering the deterministic tie-break (lowest `ap_cost`, then lowest
## entity ID) instead of a fragile raw-float `==`.
@export var score_tie_epsilon: float = 1e-6

## Real-time seconds `AITurnDriver` awaits between streamed commits so
## presentation can render each one before the next is decided. Not one of
## the 15 GDD-named scoring knobs, but lives on the same tuning surface per
## ADR-0011 §6.
@export var commit_pacing_sec: float = 0.35


# --- CR-14 research re-enable (2026-09-28) ---------------------------------
# The knobs below back [method AI._score_research_candidates]'s per-tech marginal-value
# models for the CR-14 tier-2 effects that have no GDD `research_value` precedent
# (Attack/Defense/Economy Tech already had one; see `ai-opponent.md` §`research_value`).
# Each is a stated assumption in the same spirit as `attacks_landed_per_turn_estimate` —
# this AI has no lookahead into future board composition, so these convert a permanent,
# situational effect into a flat per-turn rate.

## Volley's `attack_range_bonus` is folded into an attack-bonus-equivalent before reusing
## [method AI._attack_defense_tech_marginal_value]'s HP_PER_AP/ATTACKS_LANDED_PER_TURN_
## ESTIMATE conversion. A range point trades reach for damage, not damage for damage, so
## it is valued as a FRACTION of one flat attack point, never the full point.
@export var range_bonus_attack_equivalent: float = 0.5

## Assumed fraction of the AI's landed attacks that would otherwise have been reduced by
## [member CombatConfig.cover_dr] — what Penetration's Cover-ignore is worth per attack,
## fed through the same HP_PER_AP/ATTACKS_LANDED_PER_TURN_ESTIMATE conversion as Attack
## Tech. This AI has no target-composition lookahead (whether the NEXT enemy it fights
## happens to be in Cover), so this is a stated assumption, not a measured rate.
@export var penetration_cover_uptime_estimate: float = 0.35

## Assumed fraction of the AI's units that are idle (start-of-turn eligible for Field
## Repair's heal) on a given turn. [b]Deliberately low[/b]: this AI is built to always
## advance, attack or retreat when it legally can ([member cover_tile_discount]'s doc —
## "this AI does not stay put"), so a unit is idle only when it had no legal move at
## all. A low default keeps Field Repair from being valued as though the whole army
## held position.
@export var field_repair_idle_uptime_estimate: float = 0.15

## Assumed Produce commits per turn once a producer is available — converts Logistics'
## `produce_ap_discount` (already AP-native, no `credit_to_ap_rate`) and Foundry's
## `produce_cost_discount_pct` (Credit-native, converted via `credit_to_ap_rate`) from a
## per-action saving into a per-turn rate. Mirrors `attacks_landed_per_turn_estimate`'s
## role for the combat techs.
@export var produce_actions_per_turn_estimate: float = 1.0

## The Build sibling of [member produce_actions_per_turn_estimate], sized much lower:
## builds are far rarer than produces, gated both by the shared economy cadence cap
## ([member max_economy_investments_per_turn]) and by each structure's own low
## `max_count` (1-3). Backs Logistics' `build_ap_discount` leg only.
@export var build_actions_per_turn_estimate: float = 0.25

## Multiplier on a Research Lab's build value against the best tier-2 tech it would
## unlock ([method AI._lab_value]).
##
## ★ 1.0, measured 2026-09-28. The first value (0.4) reasoned that the Lab "only buys
## eligibility". The batch showed the result: the Lab scored ~0.03 against a
## [member pass_threshold] of 0.15, so across 30 AI-vs-AI games NO side ever built one and
## tier 2 never happened. The discount double-counted — the tech's own Credits, AP and
## research time are charged by the research scorer when it is researched, and the Lab is
## the ONLY route to it, so its worth is what it unlocks. Army production is protected
## by the build scorer's ordinary ratio competition (a Barracks scores ~1.1), not by this.
@export var lab_unlock_value_discount: float = 1.0

## Fraction of an unpiloted vehicle's Credit price the AI assigns to crewing it
## ([method AI._score_crewing_candidates]). The vehicle is already bought; a pilot is what
## makes it a unit. 0.5 puts crewing a Tank (~7 AP-equivalent per AP) well above a routine
## move, so the AI crews before it wanders — without letting it outrank a kill on its HQ.
@export var crew_vehicle_value_fraction: float = 0.5

## Fraction of its build price a promoting faction's AI adds to a rank-support structure it
## lacks (PV-7: without one, every veteran drops a rank a turn). 1.0 makes building it worth
## what it costs — measured: at 0 the Empire AI never built a Cathedral in 60 games, so
## promotion, the faction's whole identity, did almost nothing.
@export var rank_support_value_fraction: float = 1.0

## ★ Faction-aware production ([method AI._matchup_multiplier]). A unit's production value is
## scaled by floor + scale × (how much of the enemy it can hit, and how hard: 0..1).
## floor 0.25 keeps a unit that cannot hit anything present purchasable at a quarter of its
## value (the enemy may field its targets later); scale 1.25 makes a unit that kills in one
## hit worth 1.5×. A typical mid-roster infantry lands near 0.9 — close to the old flat value.
@export var matchup_floor: float = 0.25
@export var matchup_scale: float = 1.25

## Added to a pilot-capable unit's matchup multiplier while the AI owns a vehicle nobody is
## crewing — a pilot is then worth the whole vehicle it unlocks, not its own weak gun.
@export var crew_need_bonus: float = 1.5

## ★ Transports (AI._score_transport_candidates). Infantry farther than this many tiles from the
## nearest enemy is "far from the fight": worth carrying, and what a transport is valued by.
@export var transport_far_distance: int = 6

## Turns of carriage an embark is assumed to buy (value = per-tile positional value × the
## transport's tiles per turn × this). 2 makes boarding clearly better than walking for a
## slow infantry unit, without letting it outrank an attack.
@export var transport_turns_estimate: float = 2.0

## How many Builders the AI keeps at once (counting one in production). More are worth nothing
## to it. 1 is enough: a structure is raised in one action, and the next Builder is ordered the
## turn this one is consumed. See AI._matchup_multiplier for the measured reason.
@export var max_builders: int = 1

## ★ Mass before advancing (AI._advance_is_premature). A unit steps into enemy reach only with at
## least max(threatening enemies, mass_minimum) friendly fighters — itself included — within
## mass_radius tiles of where it lands. Otherwise it holds just outside range for the army.
@export var mass_radius: int = 3
@export var mass_minimum: int = 2

## ★ Push for the HQ (user direction 2026-09-28: "prioritize pushing to the HQ instead of
## destroying other buildings when the AI has a group of units ready and there is an opening").
## A unit is READY TO PUSH when at least push_group_size friendly fighters (itself included) stand
## within mass_radius of it, AND the enemy has fewer armed defenders within push_defence_radius of
## its HQ than that group. While pushing, an attack on an unarmed non-HQ building is worth only
## push_structure_value_factor of its usual value and never gets the lethal floor, and each tile
## closed on the enemy HQ is worth push_siege_multiplier × siege_value_per_tile_closed. Enemy units
## and armed buildings keep their full value — they are what stands in the way.
## Measured reason: big-map armies spent the game razing and re-razing Barracks and Factories
## (one 30-game Highlands batch: 265 Barracks, 162 Factories rebuilt) instead of the HQ.
@export var push_group_size: int = 3
@export var push_defence_radius: int = 4
@export var push_structure_value_factor: float = 0.1
@export var push_siege_multiplier: float = 3.0

## ★ AP priority switches (kept as knobs so each rule can be measured on its own with the
## simulator's --ai=<knob>=<value>). efficient_moves_first: the advance/siege folds prefer a tile
## that clears pass_threshold over a further, diluted one. fortify_hold_rule: 0 = Fortify
## whenever threatened (the old behaviour); 1 = never in a push-ready group; 2 = also never when
## the unit has a worthwhile move.
## ⚠ A third rule — spend AP that would be lost over the carry-over cap on any positive,
## credit-free action — was built and measured (2026-09-29) and removed: it changed nothing,
## because by the end of a turn the AI genuinely has nothing useful left to do. AP is not what
## limits it; Credits (army size) are. See design/decision-log.md.
@export var efficient_moves_first: bool = true
@export var fortify_hold_rule: int = 2

## ★ AP-aware moves (AI._overcap): advances and HQ drives prefer the furthest tile inside the
## unit's soft move cap over one that pays the over-cap surcharge. Off = the old per-tile choice.
@export var avoid_overcap_moves: bool = true

## ★ Durability (AI._durability_factor, faction balance pass 2026-09-29): production values a unit's
## offence × how many enemy hits it survives ÷ durability_reference_hits, clamped. Off = offence only.
@export var durability_weighting: bool = true
@export var durability_reference_hits: float = 2.0
@export var durability_min: float = 0.5
@export var durability_max: float = 2.0

## ★ Price dependence of production value (AI._production_value). 1 = value ∝ price (the old,
## cost-blind rule); 0 = price-independent (cheaper is better at equal fit). The reference sum
## keeps the value on the same scale as before for a typical unit.
@export var production_price_exponent: float = 0.5   # measured: 1 starved Solar's swarm, 0 spammed Scouts
@export var production_reference_cost: float = 600.0
