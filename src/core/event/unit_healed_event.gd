## UnitHealedEvent — a unit regained HP at its owner's start-of-turn (Field Repair).
## [member amount] is what was actually restored after clamping to max HP, never 0.
class_name UnitHealedEvent
extends Event

@export var entity_id: int = -1
@export var amount: int = 0
