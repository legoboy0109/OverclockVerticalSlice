## RushAction — spend AP to take one turn off a structure's timer (user decision 2026-09-30).
##
## Targets a structure the active player owns that is either UNDER_CONSTRUCTION or producing a
## vehicle/aircraft (never infantry or a builder). Each rush removes ONE turn; the timer never
## goes below 1, i.e. "ready at the start of your next turn" — so a rushed unit or building is
## still never usable the turn it was rushed. Costs [member EconomyConfig.rush_ap_cost] AP,
## not refunded by a later cancel (AP bought tempo, the same rule as every AP surcharge).
## Validated and applied by [method BaseProduction.validate_rush]/[method BaseProduction.apply_rush].
class_name RushAction
extends Action

## The structure whose construction or production is being rushed.
@export var structure_id: int = -1


func _init() -> void:
	verb = Action.Verb.RUSH
