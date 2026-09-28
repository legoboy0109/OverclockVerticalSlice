## AbilityUsedEvent — [member unit_id] used [member ability] at [member target_tile].
## Carries the outcome [member amount] (hp repaired, damage dealt, defence gained).
class_name AbilityUsedEvent
extends Event

@export var unit_id: int = -1
@export var ability: AbilityDef
@export var target_tile: Vector2i
@export var amount: int = 0
