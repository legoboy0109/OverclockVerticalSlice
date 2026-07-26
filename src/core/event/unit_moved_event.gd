## UnitMovedEvent — fired when a committed move actually relocates a unit.
##
## Movement-owned event type (ADR-0004/ADR-0009). Appended by
## [method Movement.apply] as the sole event of a successful [MoveAction]
## commit, carrying enough detail for the HUD action-log (TR-hud-014) and the
## Board Renderer (ADR-0013) to react without re-querying state.
##
## Usage:
## [codeblock]
## # inside Movement.apply():
## return [UnitMovedEvent.new(unit.entity_id, action.from, action.to, cost)] as Array[Event]
## [/codeblock]
class_name UnitMovedEvent
extends Event

## The moved unit's [member EntityState.entity_id].
@export var entity_id: int

## The tile the unit moved from.
@export var from: Vector2i

## The tile the unit moved to.
@export var to: Vector2i

## The exact integer AP cost billed for this move ([method Movement.move_path_cost]).
@export var cost: int


func _init(p_entity_id: int, p_from: Vector2i, p_to: Vector2i, p_cost: int) -> void:
	entity_id = p_entity_id
	from = p_from
	to = p_to
	cost = p_cost
