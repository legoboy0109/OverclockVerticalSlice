## EntityStoodDownEvent — fired when a [WaitAction] marks an entity finished for
## the turn.
##
## GameState-owned event type (ADR-0004), 2026-08-25. Carries only the entity id:
## unlike a move or a deploy, nothing about the board changed, so a consumer that
## wants more re-reads state rather than being handed a snapshot that could drift.
##
## [b]Exists so a rules-free verb is still visible.[/b] Standing down spends
## nothing and forbids nothing, which would make it the one commit that leaves no
## trace in the action log — a player scanning the log to reconstruct their turn
## would find the tidying they did missing from it.
##
## Usage:
## [codeblock]
## # inside GameState._apply_wait():
## return [EntityStoodDownEvent.new(action.entity_id)] as Array[Event]
## [/codeblock]
class_name EntityStoodDownEvent
extends Event

## The entity that was stood down.
@export var entity_id: int = -1


func _init(p_entity_id: int = -1) -> void:
	entity_id = p_entity_id
