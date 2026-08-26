## ProductionCancelledEvent — a unit under production was cancelled (S8-28).
##
## Mirrors [StructureCancelledEvent] for units. The refund is
## [code]CANCEL_REFUND_RATE x produce_cost[/code], the same rate structures use — the
## game already had one cancellation rule and this reuses it rather than inventing a
## second.
class_name ProductionCancelledEvent
extends Event

## The producer whose build was cancelled.
@export var entity_id: int = -1

## What was being built, and is now not.
@export var unit_type: UnitTypeDef

## Which player cancelled it.
@export var owner: int = -1

## Credits returned to the owner.
@export var refund: int = 0
