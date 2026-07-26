## MoveAction — commits a unit's move via [method GameState.apply_action].
##
## Core-layer command model per ADR-0002/ADR-0009. Mirrors [EndTurnAction]'s
## shape: its own top-level file with a [code]class_name[/code] (never a
## nested inner class), setting [member Action.verb] to
## [constant Action.Verb.MOVE] in [code]_init()[/code]. Its
## [code]validate()[/code]/[code]apply()[/code] handlers live on [Movement]
## (the owning Core system), never on this class (ADR-0002 forbids the
## command-pattern of methods directly on an [Action] subclass).
##
## Carries [member from]/[member to]/[member tiles_entered] rather than a full
## path array (ADR-0009 Implementation Notes) — cost is a pure function of
## path *length*, not path identity (the GDD's "same-length -> same-cost"
## invariant), so [member tiles_entered] alone is sufficient for the cost/AP
## contract this story owns. A full path array for move-feedback animation is
## a Presentation-epic (Command & Action Interface) concern, out of scope here.
##
## Usage:
## [codeblock]
## var action := MoveAction.new()
## action.player = unit.owner
## action.from = unit.position
## action.to = Vector2i(6, 5)
## action.tiles_entered = 2
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name MoveAction
extends Action

## The mover's current tile at submission time — resolved back to a
## [UnitState] via [method GameState.entity_at] inside [method Movement.validate]/
## [method Movement.apply].
@export var from: Vector2i

## The destination tile — must be present in [method Movement.reachable]'s
## result set at the reported cost for [member tiles_entered].
@export var to: Vector2i

## How many tiles this move enters, the sole input to
## [method Movement.move_path_cost] (shared verbatim with [method Movement.reachable]'s
## per-depth cost — the reachable-vs-billed agreement invariant).
@export var tiles_entered: int


func _init() -> void:
	verb = Action.Verb.MOVE
