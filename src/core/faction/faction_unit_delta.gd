## FactionUnitDelta — one entry per faction-modified unit type (Story 007 subset).
##
## Feature-layer data schema per ADR-0012 §1. A tiny typed [Resource] entry,
## keyed by Resource-reference [member type] identity (ADR-0007's identity
## discipline — never a string/enum key). Authored as an element of
## [member FactionDef.unit_deltas].
##
## This is a [b]strict subset[/b] of ADR-0012 §1's full [code]FactionUnitDelta[/code]
## schema: only the two cost/mobility domains this story folds
## ([member cost_delta], [member move_cost_delta]). [code]soft_move_cap_delta[/code]
## and [code]combat_delta[/code] are out of this story's scope — the Faction
## Identity epic adds them with zero rework to this file's existing fields.
class_name FactionUnitDelta
extends Resource

## The unit type this delta modifies. Resource-reference identity — compared
## via [code]==[/code] against a live [UnitTypeDef] registry const
## ([code]UnitTypes.SCOUT[/code] etc.), never a string/enum discriminator.
@export var type: UnitTypeDef = null

## Additive delta folded into [method Unit.effective_produce_cost]. [code]0[/code]
## is identity (no-op). Never multiplicative (ADR-0012: integer-AP invariant).
@export var cost_delta: int = 0

## Additive delta folded into [method Unit.effective_move_cost]. [code]0[/code]
## is identity (no-op). Never multiplicative.
@export var move_cost_delta: int = 0
