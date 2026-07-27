## UnitDestroyedEvent — fired when a UnitState is destroyed (hp reaches 0).
##
## Foundation-layer event type per ADR-0010. The real producer of this event
## is the shared [method GameState.destroy_entity] hook (Combat Resolution
## Story 005), called from inside [method Combat.apply] whenever a unit
## reaches 0 hp. Mirrors [StructureDestroyedEvent] as the unit-kind sibling of
## [method GameState.destroy_entity]'s two possible appended events — this one
## carries only [member entity_id] (units have no HQ-equivalent win-check
## concern; [method GameState.run_win_check] only ever scans for
## [StructureDestroyedEvent]).
##
## Usage:
## [codeblock]
## # inside GameState.destroy_entity(), for a non-StructureState entity:
## evts.append(UnitDestroyedEvent.new(entity_id))
## [/codeblock]
class_name UnitDestroyedEvent
extends Event

## The destroyed unit's former [code]entity_id[/code] — already removed from
## [code]GameState.entities_by_id[/code] by the time this event is observed.
@export var entity_id: int = -1


func _init(id: int = -1) -> void:
	entity_id = id
