## UseAbilityAction — [member unit_id] uses [member ability] on [member target_tile]
## (unit-abilities.md AB-4). Data only; handled by [method Ability.validate] /
## [method Ability.apply].
##
## For DISEMBARK and PARADROP the acting unit is the VEHICLE and [member passenger_id] names
## who leaves it — a carried unit is off the board and cannot be selected (TP-1).
class_name UseAbilityAction
extends Action

@export var unit_id: int = -1
@export var ability: AbilityDef
@export var target_tile: Vector2i
@export var passenger_id: int = -1


func _init() -> void:
	verb = Action.Verb.USE_ABILITY
