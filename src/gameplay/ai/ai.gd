## AI — static utility class for the AI Opponent's evaluate->commit decision loop.
##
## Feature-layer system per ADR-0011 §1/§2 (Decision + Enumeration). Mirrors
## the established static-utility shape [code]AP[/code]/[code]Movement[/code]/
## [code]Combat[/code]/[code]BaseProduction[/code] already use: no instance
## fields, every function takes [code]state[/code] explicitly.
##
## [b]This story (Story 002) builds the skeleton only[/b] — the enumeration
## order, the query boundary, and the no-array-materialization shape. The five
## private per-verb helpers below are stubs: they type-check and document the
## future contract but score nothing (placeholder scores only). Real
## [code]combat_value[/code]/[code]production_value[/code]/[code]economy_value[/code]/
## [code]research_value[/code]/positional math lands in Stories 003/004; the
## tie-break epsilon comparator lands in Story 005; [code]AITurnDriver[/code]
## and cadence-cap enforcement land in Stories 006/004 respectively.
##
## [b]Headless by construction (TR-ai-001):[/b] nothing in this file touches a
## [Node], a signal connection, the scene tree, or [code]await[/code] — it is
## directly unit-testable exactly like [code]Movement.reachable()[/code] or
## [code]Combat.legal_targets()[/code].
##
## [b]Approved query allowlist (ADR-0011 §5, TR-ai-014):[/b] every read in the
## enumeration path routes only through: [code]GameState.clone/active_player/
## current_ap/entities/entity_at/match_status/faction_of[/code],
## [code]Movement.reachable[/code], [code]Combat.legal_targets/
## legal_targets_from/preview_damage[/code], [code]AP.can_afford/current_ap/
## income[/code], [code]BaseProduction.legal_build_tiles/legal_deploy_tiles/
## completed_outpost_count[/code], [code]Research.legal_research_targets[/code]
## (stubbed empty — Research epic not built), [code]GridState.
## manhattan_distance/terrain_at/occupant_at[/code] — plus public typed fields
## on entities already returned by those calls. This is a static-analysis /
## code-review boundary (AC-5/AC-6b per ADR-0011 §5); the CI lint enforcing it
## is a separate, later task owed to godot-specialist/CI tooling, not authored
## here. [b]Never[/b] reach into [code]entities_by_id[/code]/[code]GridState[/code]
## packed-array internals directly, and [b]never[/b] call
## [code]state.apply_action()[/code] from inside this class — committing is
## the caller's ([code]AITurnDriver[/code]'s) job.
##
## Usage:
## [codeblock]
## var action: Action = AI.choose_action(state, economy_investments_committed)
## if action != null:
##     var result: ActionResult = state.apply_action(action) # caller commits, not AI
## [/codeblock]
class_name AI
extends RefCounted


## Running-best candidate carrier (ADR-0011 §2) — the sole mutable slot the
## streaming max-scan reassigns per iteration. Never collected into an
## [code]Array[/code]; exactly one instance is live at a time during
## [method choose_action], satisfying the no-array-materialization shape
## (AC "no array" / control-manifest forbidden pattern: never materialize the
## full candidate array then [code]sort()[/code]).
class _Candidate extends RefCounted:
	var action: Action
	var score: float
	var ap_cost: int
	var entity_id: int

	func _init(a: Action = null, s: float = -INF, cost: int = 0, id: int = -1) -> void:
		action = a
		score = s
		ap_cost = cost
		entity_id = id


## The AI's single public entry point (ADR-0011 §1, TR-ai-001/003). Pure,
## headless, side-effect-free: internally clones [param state]
## ([method GameState.clone] — CR-2 step 1), enumerates every legal/affordable
## candidate across every verb against the clone in entity-id-ascending order
## (ADR-0003), scores each via the five private per-verb helpers below (real
## scoring formulas land in Stories 003/004 — this story's helpers are
## placeholder stubs), and returns the single best candidate's [Action] — or
## [code]null[/code] if no candidate was ever recorded. [b]Never calls
## [method GameState.apply_action] itself[/b] — committing is the caller's
## (future [code]AITurnDriver[/code]'s) job, which is what keeps this class
## headless (ADR-0011 §1).
##
## [param economy_investments_committed] is the one deliberate escape from
## full statelessness (ADR-0011 §1): it is threaded through to
## [method _score_build_and_economy_candidates]/[method _score_research_candidates]
## unchanged so a future story can gate economy/research candidates against
## [code]AIBalance.ai.max_economy_investments_per_turn[/code] without adding
## instance state to this class. Cadence-cap *enforcement* is Story 004's
## scope; this story only threads the parameter through.
##
## Never materializes a full candidate [Array] — walks each verb family once
## per entity via a streaming max-scan, replacing the running [_Candidate]
## only when a helper returns a strictly better one (ADR-0011 §2; the real
## [code]_is_better[/code] tie-break comparator is Story 005's scope — this
## story's stub helpers never produce a non-null candidate, so no comparator
## is exercised yet, but the running-best plumbing is already in its final
## shape).
static func choose_action(state: GameState, economy_investments_committed: int) -> Action:
	var lookahead: GameState = state.clone()

	var best := _Candidate.new()
	for entity: EntityState in _entities_in_enumeration_order(lookahead):
		best = _score_move_and_attack_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_production_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_build_and_economy_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_research_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_cancel_build_candidates(lookahead, entity, economy_investments_committed, best)

	return best.action


## Test/enumeration seam (ADR-0011 §2, ADR-0003): returns [param state]'s
## [member GameState.active_player]'s owned entities, in stable
## [member EntityState.entity_id]-ascending order — collected once, never raw
## [code]entities_by_id[/code] Dictionary order. A thin filter over
## [method GameState.entities] (which already returns its result sorted
## ascending by [code]entity_id[/code] per its own contract, ADR-0003), so no
## second sort is performed here.
##
## Exposed as its own static function (rather than inlined in
## [method choose_action]) so a unit test can assert the enumeration order
## directly without depending on the stub helpers ever producing a non-null
## [Action] — mirrors the existing [code]AIBalance._check_lethal_floor_invariant[/code]/
## [code]economy_ceiling_score[/code] precedent of exposing a pure static
## sub-step for direct testing rather than inventing mock/DI machinery.
##
## O(entity count) — one filtered pass over [method GameState.entities]
## (control-manifest Performance Guardrail).
static func _entities_in_enumeration_order(state: GameState) -> Array[EntityState]:
	var out: Array[EntityState] = []
	for e: EntityState in state.entities():
		if e.owner == state.active_player:
			out.append(e)
	return out


## Per-unit move/attack candidate enumeration (ADR-0011 §2) — stub for Story
## 002. The real implementation (Stories 003/004) will walk
## [method Movement.reachable] for positional/retreat/setup-advance scoring
## plus [method Combat.legal_targets_from] for every reachable tile (covering
## bare moves and move+attack combos in one pass) and the zero-move
## [method Combat.legal_targets] case — scored against [code]AIBalance.ai[/code]'s
## knobs. This story only proves the call boundary and the running-best
## threading shape: it performs no enumeration and returns [param best]
## unchanged.
static func _score_move_and_attack_candidates(_lookahead: GameState, _entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best


## Per-structure unit-production candidate enumeration (ADR-0011 §2) — stub
## for Story 002. The real implementation will walk
## [method BaseProduction.legal_deploy_tiles] per producible unit type,
## scoring via [code]production_value[/code] (Story 003/004). This story
## performs no enumeration and returns [param best] unchanged.
static func _score_production_candidates(_lookahead: GameState, _entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best


## Per-structure build/economy candidate enumeration (ADR-0011 §2) — stub for
## Story 002. The real implementation will walk
## [method BaseProduction.legal_build_tiles], dispatching
## [code]production_value[/code]-style scoring for non-economy structures vs.
## [code]economy_value[/code] for Economy Outposts, gated by
## [param economy_investments_committed] against
## [code]AIBalance.ai.max_economy_investments_per_turn[/code] (cadence-cap
## *enforcement* is Story 004's scope). This story performs no enumeration and
## returns [param best] unchanged.
static func _score_build_and_economy_candidates(_lookahead: GameState, _entity: EntityState, \
		economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best


## Per-Lab research candidate enumeration (ADR-0011 §2) — stub for Story 002,
## [b]deliberately permanently empty until the Research epic lands[/b] (per
## this story's Implementation Notes: "Research/Tech is NOT implemented yet").
## [code]Research.legal_research_targets[/code] does not exist as a real query
## yet, so this helper never calls it and never blocks this story on Research.
## Returns [param best] unchanged, always.
static func _score_research_candidates(_lookahead: GameState, _entity: EntityState, \
		economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best


## Per-under-construction-structure cancel-build candidate enumeration
## (ADR-0011 §2) — stub for Story 002. The real implementation will consider
## cancelling [param entity] if it is an owned, under-construction
## [code]StructureState[/code], scored against the refund via
## [code]BaseProductionConfig.cancel_refund_pct[/code] (Story 003/004). This
## story performs no enumeration and returns [param best] unchanged.
static func _score_cancel_build_candidates(_lookahead: GameState, _entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best
