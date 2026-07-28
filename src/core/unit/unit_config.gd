## UnitConfig — Unit-owned global movement tuning constants (fixed-point).
##
## Core-layer config asset per ADR-0009. A dedicated [Resource] (`.tres`),
## mirroring [EconomyConfig]'s config-as-Resource pattern (ADR-0006) — never
## GDScript `const`s, never stored on [GameState] (it is static, shared,
## read-only tuning data, so it must never ride along on
## [method GameState.clone]'s `duplicate_deep()` pass — same reasoning as
## [EconomyConfig]).
##
## Loaded once at boot by the thin, logic-free [code]UnitBalance[/code] Autoload
## and read via [code]UnitBalance.units[/code].
##
## [b]Ownership:[/b] `SOFT_MOVE_PENALTY` is a Unit-owned [b]global[/b] constant
## (not per-type — ADR-0007's [UnitTypeDef] is per-type and the wrong home). It
## is stored fixed-point as [member soft_move_penalty_x10] (an integer, ×10) so
## the over-cap surcharge is computed with integer ceil-division — no float ever
## enters the AP path (the Integer-AP invariant, TR-movement-011). Movement's
## reachable-search and its move-billing both call [method surcharge_for], the
## single shared over-cap primitive.
##
## Usage:
## [codeblock]
## var surcharge: int = UnitConfig.surcharge_for(unit.move_cost) # ceil(cost * 2.0)
## [/codeblock]
class_name UnitConfig
extends Resource

## Over-cap move surcharge multiplier, fixed-point ×10: `20` = 2.0 (the VS
## default; GDD range 1.5–3.0 → 15–30). Every over-cap tile costs
## `ceil(move_cost * soft_move_penalty_x10 / 10)` AP. Integer, never a float.
@export var soft_move_penalty_x10: int = 20


## The flat AP surcharge for one over-cap tile at [param move_cost]:
## `ceil(move_cost * SOFT_MOVE_PENALTY)`, reading the live-tunable penalty from
## the [code]UnitBalance[/code] Autoload. This is the single-arg form Movement
## calls (ADR-0009's [code]UnitConfig.surcharge_for(unit.move_cost)[/code] call
## site). Always ≥ `move_cost` and always an integer. O(1).
static func surcharge_for(move_cost: int) -> int:
	return surcharge_with_penalty(move_cost, UnitBalance.units.soft_move_penalty_x10)


## Pure integer ceil-division primitive: `ceil(move_cost * penalty_x10 / 10)`.
## Takes the penalty explicitly (dependency injection) so the surcharge math is
## unit-testable without the [code]UnitBalance[/code] Autoload — the boundary
## cases (e.g. penalty 1.5 → `ceil(1 × 1.5) = 2`, not 1) are tested against this
## form. [method surcharge_for] is the Autoload-reading wrapper over it. O(1).
static func surcharge_with_penalty(move_cost: int, penalty_x10: int) -> int:
	return (move_cost * penalty_x10 + 9) / 10   # integer ceil-division (+9 = +(10-1))
