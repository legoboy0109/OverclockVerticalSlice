## UnitResuppliedEvent — a unit's ammo was refilled by an adjacent supply structure (2026-10-01).
class_name UnitResuppliedEvent
extends Event

## The unit refilled.
@export var entity_id: int = -1

## Its owner.
@export var owner: int = -1

## The structure that resupplied it.
@export var supplier_id: int = -1
