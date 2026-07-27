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

## `ap_cost_opponent_paid_for` weight for the enemy HQ (which has no
## `build_cost`) — a siege-priority weight, not a sunk-cost figure.
@export var hq_siege_value: int = 12

## Tolerance below which two `action_score` values are treated as tied,
## triggering the deterministic tie-break (lowest `ap_cost`, then lowest
## entity ID) instead of a fragile raw-float `==`.
@export var score_tie_epsilon: float = 1e-6

## Real-time seconds `AITurnDriver` awaits between streamed commits so
## presentation can render each one before the next is decided. Not one of
## the 15 GDD-named scoring knobs, but lives on the same tuning surface per
## ADR-0011 §6.
@export var commit_pacing_sec: float = 0.35
