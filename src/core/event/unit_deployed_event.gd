## UnitDeployedEvent — fired when a [ProduceAction] commits a new unit.
##
## Base & Production-owned event type (ADR-0004/ADR-0017 D4), Story 004.
## Appended by [method BaseProduction.apply_produce] as the sole event of a
## successful [ProduceAction] commit, carrying enough detail for the HUD
## action-log (TR-hud-014) and the Board Renderer (ADR-0013) to react without
## re-querying state — mirrors [StructurePlacedEvent]'s established
## constructor-init shape (build places a structure; produce deploys a unit).
##
## Usage:
## [codeblock]
## # inside BaseProduction.apply_produce():
## var evt := UnitDeployedEvent.new()
## evt.entity_id = unit.entity_id
## evt.unit_type = action.unit_type
## evt.owner = player
## evt.tile = action.tile
## return [evt] as Array[Event]
## [/codeblock]
class_name UnitDeployedEvent
extends Event

## The newly deployed unit's [member EntityState.entity_id].
@export var entity_id: int = -1

## The [UnitTypeDef] template the deployed unit was instantiated from
## (Resource-reference identity against the [code]UnitTypes[/code] registry).
@export var unit_type: UnitTypeDef

## Which player owns the deployed unit.
@export var owner: int = -1

## The tile the unit was deployed on.
@export var tile: Vector2i
