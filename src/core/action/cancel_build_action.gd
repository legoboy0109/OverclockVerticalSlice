## CancelBuildAction — voluntarily cancels an under-construction structure via
## [method GameState.apply_action], refunding a fraction of its build cost.
##
## Core-layer command model per ADR-0002/ADR-0017 (D5). Mirrors [BuildAction]'s
## shape: its own top-level file with a [code]class_name[/code] (never a nested
## inner class), setting [member Action.verb] to
## [constant Action.Verb.CANCEL_BUILD] in [code]_init()[/code]. Its
## [code]validate()[/code]/[code]apply()[/code] handlers live on
## [BaseProduction] (the owning Core system), never on this class (ADR-0002
## forbids the command-pattern of methods directly on an [Action] subclass).
##
## The canceller is [b]always[/b] [member GameState.active_player] at commit
## time ([member Action.player] IS the acting player per ADR-0002, gated to the
## active player by [method GameState.apply_action]'s step 2). [member structure_id]
## names which of the player's own under-construction structures to cancel —
## [method BaseProduction.validate_cancel] rejects an id that is not the active
## player's, or that is already [constant StructureState.BuildStatus.COMPLETED]
## (a Completed structure can only be combat-destroyed, never cancelled).
##
## Usage:
## [codeblock]
## var action := CancelBuildAction.new()
## action.player = state.active_player
## action.structure_id = under_construction_outpost.entity_id
## var result: ActionResult = state.apply_action(action)
## # result.events[0] is StructureCancelledEvent; .refund is the AP credited.
## [/codeblock]
class_name CancelBuildAction
extends Action

## The [member EntityState.entity_id] of the [StructureState] to cancel.
## Resolved to the live entity by [method BaseProduction.validate_cancel],
## which rejects with [constant Action.Reason.NO_SUCH_ENTITY] if it names no
## live [StructureState], [constant Action.Reason.ILLEGAL_TARGET] if that
## structure is not owned by the active player, and
## [constant Action.Reason.NOT_UNDER_CONSTRUCTION] if it is already Completed.
@export var structure_id: int = -1


func _init() -> void:
	verb = Action.Verb.CANCEL_BUILD
