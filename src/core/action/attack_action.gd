## AttackAction — commits an attack via [method GameState.apply_action].
##
## Core-layer command model per ADR-0002/ADR-0010. Mirrors [MoveAction]'s
## shape: its own top-level file with a [code]class_name[/code] (never a
## nested inner class), setting [member Action.verb] to
## [constant Action.Verb.ATTACK] in [code]_init()[/code]. Its
## [code]validate()[/code]/[code]apply()[/code] handlers live on [Combat]
## (the owning Core system), never on this class (ADR-0002 forbids the
## command-pattern of methods directly on an [Action] subclass).
##
## Carries only the attacker's and target's tiles — [member attacker_tile]/
## [member target_tile] are resolved back to their [EntityState]s via
## [method GameState.entity_at] inside [method Combat.validate]/
## [method Combat.apply], exactly as [MoveAction] resolves the mover. Entity
## references are never carried on an [Action] itself (it is a transient,
## per-input object, never part of cloned [GameState] data).
##
## Usage:
## [codeblock]
## var action := AttackAction.new()
## action.player = attacker.owner
## action.attacker_tile = attacker.position
## action.target_tile = target.position
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name AttackAction
extends Action

## The attacker's current tile at submission time — resolved back to an
## [EntityState] (a [UnitState] in this story's scope; see [method Combat.validate]'s
## [code]TODO(Story 005)[/code] structure-attacker note) via
## [method GameState.entity_at] inside [method Combat.validate]/[method Combat.apply].
@export var attacker_tile: Vector2i

## The target's tile at submission time — resolved back to an [EntityState]
## (a [UnitState] or [code]StructureState[/code] defender, ADR-0010) via
## [method GameState.entity_at]. Must be present in
## [method Combat.legal_targets]'s result set for the attacker at
## [member attacker_tile].
@export var target_tile: Vector2i


func _init() -> void:
	verb = Action.Verb.ATTACK
