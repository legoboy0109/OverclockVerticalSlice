## StructureCompletedEvent — fired when a structure finishes its build timer.
##
## Foundation-layer event type per ADR-0008. Appended by
## [code]BaseProduction.advance_build_timers[/code] during
## [method GameState.start_turn]'s step 3, flowing through the existing
## [signal GameState.action_applied] signal like every other [Event] — no new
## signal or polling path (control-manifest forbidden pattern).
##
## [b]Ownership note:[/b] this event type reports one of Base & Production's
## state transitions. It was scoped in [code]src/core/event/[/code] early per
## ADR-0008/GS-003 so start_turn's step-3 contract had a concrete completion
## event to emit before Base & Production existed. [b]Reconciled by Base &
## Production Story 002[/b] — the real [code]advance_build_timers[/code] now
## populates the identifying fields below (the doc's original "flag for
## reconciliation once [code]StructureTypeDef[/code] exists" — it now does).
## The file stays in [code]src/core/event/[/code] (Event subclasses live here
## regardless of owning system).
##
## Payload mirrors [StructurePlacedEvent] so a consumer (HUD action-log
## TR-hud-014, Board Renderer ADR-0013, save/replay) can identify [b]which[/b]
## structure completed, for [b]which[/b] player, of [b]which[/b] type.
##
## Usage:
## [codeblock]
## # inside BaseProduction.advance_build_timers(), on a structure reaching 0:
## var evt := StructureCompletedEvent.new()
## evt.entity_id = structure.entity_id
## evt.structure_type = structure.type
## evt.owner = structure.owner
## evt.tile = structure.position
## events.append(evt)
## [/codeblock]
class_name StructureCompletedEvent
extends Event

## The completed structure's entity id (key into [member GameState.entities_by_id]).
@export var entity_id: int = -1

## The completed structure's immutable stat template (Resource-ref into the
## [code]StructureTypes[/code] registry).
@export var structure_type: StructureTypeDef

## The owning player of the completed structure.
@export var owner: int = -1

## The tile the completed structure occupies.
@export var tile: Vector2i
