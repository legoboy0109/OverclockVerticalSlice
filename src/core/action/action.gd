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

## The committable verbs in Vertical-Slice scope (DISBAND added by S6-02). Only [constant
## Verb.END_TURN] has a concrete handler in this story — the rest are
## forward-declared dispatch slots, registered by their own Core epics
## (Movement/Combat/Base & Production/Research) when those land
## (out of scope here, per ADR-0002/Story 002).
## [constant Verb.WAIT] appended 2026-08-25 (see [WaitAction]) — appended, never
## inserted, so every existing ordinal is preserved.
## ⚠ APPENDED ONLY, never inserted — CommandFSM and several callers index this by
## ordinal, and renumbering an existing verb silently rewires every one of them.
## (S8-13 learned this when appending BUILD; CANCEL_PRODUCTION follows the rule.)
enum Verb { MOVE, ATTACK, BUILD, PRODUCE, RESEARCH, CANCEL_BUILD, END_TURN, DISBAND, WAIT, CANCEL_PRODUCTION }

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
	NOT_COMPLETED,
	NOT_PRODUCIBLE,
	NOT_LEGAL_DEPLOY_TILE,
	NOT_UNDER_CONSTRUCTION,
	NOTHING_IN_PRODUCTION,
	GAME_OVER,
	FACTION_LOCKED,
	NO_SUCH_ENTITY,
	UNKNOWN_VERB,
	# Insufficient Credits for a dual-cost economic action (ADR-0006 pivot); an
	# AP-surcharge shortfall still uses CANT_AFFORD, so the Command interface can
	# name the binding pool. Appended at the end to preserve existing ordinals.
	CANT_AFFORD_CREDITS,
	# In deficit: upkeep exceeds income and the bank is empty (unit-upkeep.md UR-6).
	# Locks produce/build/research for the turn while leaving move, attack and
	# disband available. Distinct from CANT_AFFORD_CREDITS: the player may hold
	# nothing at all, and the block persists for the whole turn even if a disband
	# restores solvency mid-turn. Appended to preserve existing ordinals.
	IN_DEFICIT,
	# Disband targeting something that is not an own, living unit (UR-7).
	NOT_OWN_UNIT,
	# The owner is at their infantry cap (S6-04, population-cap.md PC-2). Distinct from
	# PRODUCTION_CAP_REACHED, which is a per-producer per-TURN throughput limit; this is
	# a limit on how many units may exist at once.
	POPULATION_CAP_REACHED,
	# The producer is still on its post-production cooldown (S6-07). Distinct from
	# PRODUCTION_CAP_REACHED (a per-TURN throughput limit) -- this spans turns and is the
	# lever that makes losing a unit cost TIME rather than a turn's Credits.
	PRODUCER_ON_COOLDOWN,
	# This structure type is already at its per-player maximum, counting both completed
	# and under-construction instances (S6-03). Distinct from PRODUCTION_CAP_REACHED,
	# which is a per-producer per-turn unit limit, not a structure-count limit.
	STRUCTURE_MAX_REACHED,
	# Build was ordered without a living, owned unit that can build it (user decision
	# 2026-08-25 — Build belongs to a Builder, not to the player). Covers "no builder
	# named", "that entity is gone", "it is not yours" and "it is not a Builder"
	# alike: to a player those are one situation, "you have no builder for this".
	NOT_A_BUILDER,
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
