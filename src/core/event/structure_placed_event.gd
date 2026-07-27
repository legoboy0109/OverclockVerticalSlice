## StructurePlacedEvent — fired when a [BuildAction] commits a new structure.
##
## Base & Production-owned event type (ADR-0004/ADR-0017), Story 002. Appended
## by [method BaseProduction.apply_build] as the sole event of a successful
## [BuildAction] commit, carrying enough detail for the HUD action-log
## (TR-hud-014) and the Board Renderer (ADR-0013) to react without
## re-querying state — mirrors [UnitMovedEvent]'s established
## constructor-init shape.
##
## Usage:
## [codeblock]
## # inside BaseProduction.apply_build():
## var evt := StructurePlacedEvent.new()
## evt.entity_id = structure.entity_id
## evt.structure_type = action.structure_type
## evt.owner = player
## evt.tile = action.tile
## return [evt] as Array[Event]
## [/codeblock]
class_name StructurePlacedEvent
extends Event

## The newly placed structure's [member EntityState.entity_id].
@export var entity_id: int = -1

## The [StructureTypeDef] template the placed structure was instantiated
## from (Resource-reference identity against the [code]StructureTypes[/code]
## registry).
@export var structure_type: StructureTypeDef

## Which player owns the placed structure.
@export var owner: int = -1

## The tile the structure was placed on.
@export var tile: Vector2i
