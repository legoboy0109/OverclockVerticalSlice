## ProduceAction — commits a unit production via [method GameState.apply_action].
##
## Core-layer command model per ADR-0002/ADR-0017 (D4). Mirrors [BuildAction]'s
## shape: its own top-level file with a [code]class_name[/code] (never a nested
## inner class), setting [member Action.verb] to [constant Action.Verb.PRODUCE]
## in [code]_init()[/code]. Its [code]validate()[/code]/[code]apply()[/code]
## handlers live on [BaseProduction] (the owning Core system), never on this
## class (ADR-0002 forbids the command-pattern of methods directly on an
## [Action] subclass).
##
## Unlike [BuildAction] (whose builder is implicitly the active player), a
## produce commit names [b]which[/b] producer structure spawns the unit via
## [member producer_id] — a player may own several producers, and the acting
## player still must own the one referenced (gated in
## [method BaseProduction.validate_produce], not here). [member Action.player]
## is the acting player per ADR-0002's base contract and is gated to the active
## player by [method GameState.apply_action]'s step 2 before the handler runs.
##
## Usage:
## [codeblock]
## var action := ProduceAction.new()
## action.player = state.active_player
## action.producer_id = barracks.entity_id
## action.unit_type = UnitTypes.TROOPER
## action.tile = Vector2i(3, 4)
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name ProduceAction
extends Action

## The producing [StructureState]'s [member EntityState.entity_id]. Resolved to
## the live entity by [method BaseProduction.validate_produce], which rejects
## with [constant Action.Reason.NO_SUCH_ENTITY] if it names no live
## [StructureState] and [constant Action.Reason.ILLEGAL_TARGET] if that
## structure is not owned by the active player.
@export var producer_id: int = -1

## The [UnitTypeDef] template to produce — a preload'd reference into the
## [code]UnitTypes[/code] registry (ADR-0007), never a runtime-loaded duplicate.
## Membership in the producer's [member StructureTypeDef.producible_types] is
## checked by Resource-reference identity (never a string/enum compare).
@export var unit_type: UnitTypeDef

## The tile to deploy the new unit on. Must be present in
## [method BaseProduction.legal_deploy_tiles]'s result set for the producer and
## [member unit_type] at commit time (empty/passable/in-bounds, manhattan==1
## from the producer).
@export var tile: Vector2i


func _init() -> void:
	verb = Action.Verb.PRODUCE
