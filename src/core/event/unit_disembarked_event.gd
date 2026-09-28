## UnitDisembarkedEvent — [member unit_id] left [member vehicle_id] onto [member tile]
## (by disembarking, or by paradrop when [member paradrop] is set).
class_name UnitDisembarkedEvent
extends Event

@export var unit_id: int = -1
@export var vehicle_id: int = -1
@export var tile: Vector2i
@export var paradrop: bool = false
