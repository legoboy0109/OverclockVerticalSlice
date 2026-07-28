## ActionResult — the single, uniform return type of [method GameState.apply_action].
##
## Foundation-layer command model per ADR-0002. Every verb — [EndTurnAction]
## and every future Movement/Combat/Base & Production/Research verb alike —
## returns this same shape; verb-specific detail rides in [member events],
## never in a per-verb result subtype (a per-verb [code]MoveResult[/code]/
## [code]AttackResult[/code]/... is an explicitly forbidden pattern, ADR-0002
## Alternative 5).
##
## Declared as its own top-level [code]class_name[/code] file (not nested
## inside [code]action.gd[/code]) so it is independently type-hintable
## everywhere it is used as a return/parameter type (e.g.
## [code]func apply_action(action: Action) -> ActionResult[/code]) — GDScript
## inner classes are not auto-registered as global [code]class_name[/code]
## symbols (see the [code]Movement.ReachableTile[/code] precedent, control
## manifest Core Layer Engine API Constraints), so a nested [code]ActionResult[/code]
## would need an [code]Action.ActionResult[/code] prefix everywhere instead of
## reading as a plain global type. This is a clarification of ADR-0002's Key
## Interfaces sketch (which showed [code]ActionResult[/code] textually inside
## the same fenced code block as [code]Action[/code], without mandating
## nesting), not a deviation from its Decision.
##
## Transient, like [Action] — never part of cloned [GameState] data.
##
## Usage:
## [codeblock]
## var result: ActionResult = state.apply_action(action)
## if result.ok:
##     for event in result.events:
##         if event is DamageEvent:
##             pass # handle typed event
## else:
##     push_warning("rejected: %d" % result.reason)  # an Action.Reason value
## [/codeblock]
class_name ActionResult
extends RefCounted

## Whether the action committed. When [code]false[/code], [member GameState]
## is guaranteed field-wise-unchanged (ADR-0002 validate-before-mutate
## atomicity) and [member events] is always empty.
var ok: bool = false

## The rejection cause when [member ok] is [code]false[/code] (an
## [enum Action.Reason] value); [constant Action.Reason.OK] when
## [member ok] is [code]true[/code].
var reason: int = Action.Reason.OK

## What happened, in resolution order — an [code]Array[Event][/code]. Always
## empty on rejection. Consumers narrow with [code]if e is DamageEvent:[/code],
## never a [code]match[/code] on runtime type (ADR-0004).
var events: Array = []


## Convenience constructor. Usage:
## [codeblock]
## return ActionResult.new(false, Action.Reason.CANT_AFFORD, [])
## [/codeblock]
func _init(p_ok: bool = false, p_reason: int = Action.Reason.OK, p_events: Array = []) -> void:
	ok = p_ok
	reason = p_reason
	events = p_events
