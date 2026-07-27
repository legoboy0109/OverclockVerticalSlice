## StructureCancelledEvent — fired when a [CancelBuildAction] commits, removing
## an under-construction structure and refunding part of its build cost.
##
## Base & Production-owned event type (ADR-0004/ADR-0017 D5), Story 005.
## Appended by [method BaseProduction.apply_cancel] as the sole event of a
## successful [CancelBuildAction] commit. Carries the [member refund] amount so
## the Command FSM / HUD render the AP credited [b]from this event[/b] rather
## than re-deriving it from `build_cost * pct / 100` in the presentation layer
## (registry `balance_constant_in_presentation_layer` forbidden, ADR-0017).
## Mirrors [StructurePlacedEvent]'s constructor-init shape (build places a
## structure; cancel removes one).
##
## Usage:
## [codeblock]
## # inside BaseProduction.apply_cancel():
## var evt := StructureCancelledEvent.new()
## evt.entity_id = structure.entity_id
## evt.structure_type = structure.type
## evt.owner = player
## evt.tile = structure.position
## evt.refund = refund
## return [evt] as Array[Event]
## [/codeblock]
class_name StructureCancelledEvent
extends Event

## The cancelled structure's former [member EntityState.entity_id] — already
## erased from [member GameState.entities_by_id] and cleared from the grid by
## the time this event is observed.
@export var entity_id: int = -1

## The [StructureTypeDef] template the cancelled structure was instantiated from
## (Resource-reference identity against the [code]StructureTypes[/code] registry).
@export var structure_type: StructureTypeDef

## Which player owned the cancelled structure (and received the refund).
@export var owner: int = -1

## The tile the cancelled structure occupied (now empty).
@export var tile: Vector2i

## The AP refunded to [member owner]'s pool — `build_cost * cancel_refund_pct / 100`
## via integer division (floors), computed once by [method BaseProduction.apply_cancel]
## and carried here so presentation never re-derives it.
@export var refund: int = 0
