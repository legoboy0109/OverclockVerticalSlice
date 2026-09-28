## VehicleCapturedEvent — [member vehicle_id] changed hands: [member pilot_id] climbed in and it
## now belongs to [member new_owner] (unit-abilities.md CAPTURE_VEHICLE).
class_name VehicleCapturedEvent
extends Event

@export var vehicle_id: int = -1
@export var pilot_id: int = -1
@export var new_owner: int = -1
