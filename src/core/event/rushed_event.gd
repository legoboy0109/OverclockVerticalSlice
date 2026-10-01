## RushedEvent — a construction site or a vehicle in production was rushed (2026-09-30).
class_name RushedEvent
extends Event

## The structure whose timer was cut.
@export var entity_id: int = -1

## Who rushed it.
@export var owner: int = -1

## True when the structure itself was being built; false when it was a unit in production.
@export var construction: bool = false

## The unit being produced (null for construction).
@export var unit_type: UnitTypeDef

## Turns left after the rush (1 = ready at the start of the owner's next turn).
@export var turns_remaining: int = 0

## AP spent on this rush.
@export var ap_cost: int = 0
