## Action — base type for every command committed through [method GameState.apply_action].
##
## Foundation-layer command model per ADR-0002. A transient, per-input
## [RefCounted] object — created by the caller (Command & Action Interface /
## AI), submitted once to [method GameState.apply_action], then discarded. It
## is [b]never[/b] part of cloned [GameState] data (ADR-0002 Engine Notes).
##
## Each concrete verb is its own top-level file with a [code]class_name[/code]
## (never a nested inner class), extending [Action] and setting [member verb]
## in its own [code]_init()[/code] (e.g. [EndTurnAction] sets
## [code]verb = Verb.END_TURN[/code]). [method GameState.apply_action] never
## inspects an [Action]'s runtime type directly — dispatch is exclusively by
## [member verb] through a [code]Dictionary[int, Callable][/code] table
## (never [code]get_class()[/code], which returns the base engine class name
## [code]"RefCounted"[/code] for a GDScript-defined class, not its
## [code]class_name[/code] — ADR-0002 Engine Notes).
##
## [b]Command-pattern is deliberately NOT used here[/b]: an [Action] subclass
## never carries its own [code]validate()[/code]/[code]apply()[/code] methods
## (forbidden pattern, ADR-0002) — those live on the owning Core system
## (Movement, Combat, Base & Production, Research, or [GameState] itself for
## [EndTurnAction]) as pure functions matching the contract:
## [code]validate(state: GameState, action: Action) -> int[/code] (a
## [enum Reason] code) and
## [code]apply(state: GameState, action: Action) -> Array[/code] (returns
## [code]Array[Event][/code]).
##
## Usage:
## [codeblock]
## var action := EndTurnAction.new()
## action.player = state.active_player
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name Action
extends RefCounted

## The seven committable verbs in Vertical-Slice scope. Only [constant
## Verb.END_TURN] has a concrete handler in this story — the rest are
## forward-declared dispatch slots, registered by their own Core epics
## (Movement/Combat/Base & Production/Research) when those land
## (out of scope here, per ADR-0002/Story 002).
enum Verb { MOVE, ATTACK, BUILD, PRODUCE, RESEARCH, CANCEL_BUILD, END_TURN }

## Every rejection cause [method GameState.apply_action] can return, plus
## [constant Reason.OK] for a passing [code]validate()[/code]. Deliberately an
## [code]int[/code]-returning enum, never wrapped as a [code]Reason[/code]
## object return type on [code]validate()[/code] (ADR-0002 — GDScript enums
## are plain ints at the signature level; do not "fix" this).
enum Reason {
	OK,
	NOT_ACTIVE_PLAYER,
	CANT_AFFORD,
	ILLEGAL_TARGET,
	OUT_OF_RANGE,
	TILE_OCCUPIED,
	NOT_LEGAL_BUILD_TILE,
	PRODUCTION_CAP_REACHED,
	GAME_OVER,
	FACTION_LOCKED,
	NO_SUCH_ENTITY,
	UNKNOWN_VERB,
}

## Which verb this is — the dispatch key [method GameState.apply_action] uses
## to look up the owning system's [code]validate[/code]/[code]apply[/code]
## [Callable]s. Set by each concrete subclass's [code]_init()[/code]; never
## assigned by a caller directly.
var verb: int = -1

## The acting player. [method GameState.apply_action] rejects with
## [constant Reason.NOT_ACTIVE_PLAYER] unless this equals
## [member GameState.active_player] (including for [EndTurnAction] — only the
## active player may end their own turn).
var player: int = -1
