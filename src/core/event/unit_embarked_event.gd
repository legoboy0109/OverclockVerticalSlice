## UnitEmbarkedEvent — [member unit_id] climbed into [member vehicle_id] as its pilot or as a
## passenger, and left the board (transport-and-pilots.md TP-1).
class_name UnitEmbarkedEvent
extends Event

@export var unit_id: int = -1
@export var vehicle_id: int = -1
@export var as_pilot: bool = false
