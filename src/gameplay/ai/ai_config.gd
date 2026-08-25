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

## Horizon for permanent army-wide buffs (Attack/Defense Tech).
@export var tech_value_horizon: int = 10

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
@export var cover_tile_discount: int = 0

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

## Tolerance below which two `action_score` values are treated as tied,
## triggering the deterministic tie-break (lowest `ap_cost`, then lowest
## entity ID) instead of a fragile raw-float `==`.
@export var score_tie_epsilon: float = 1e-6

## Real-time seconds `AITurnDriver` awaits between streamed commits so
## presentation can render each one before the next is decided. Not one of
## the 15 GDD-named scoring knobs, but lives on the same tuning surface per
## ADR-0011 §6.
@export var commit_pacing_sec: float = 0.35
