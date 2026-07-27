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


## `REACHABILITY_MULTIPLIER`'s fixed 3-band (GDD Formulas/Tuning Knobs,
## ADR-0011 §6 / Story 001's exclusion list) — deliberately [b]code
## constants[/b], never [AIConfig] fields ("the GDD itself calls the
## multiplier band 'fixed 3-band', deliberately not meant to be casually
## retuned"). See [method _reachability_multiplier] for the selection rule.
const _REACHABILITY_MULTIPLIER_REACHABLE := 1.1
const _REACHABILITY_MULTIPLIER_IN_CONTACT := 1.0
const _REACHABILITY_MULTIPLIER_ISOLATED := 0.9


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


## Per-unit attack candidate enumeration (ADR-0011 §2, Story 003) — scores
## [param entity]'s legal attacks, both stationary (zero-move,
## [method Combat.legal_targets]) and move+attack combos (every
## [method Movement.reachable] tile, via [method Combat.legal_targets_from]),
## via [method _combat_value]/[method _action_score]. [b]Bare, non-attacking
## repositioning moves (pure advance/retreat/setup) are Story 004's scope —
## not enumerated here.[/b] Only a [code]UnitState[/code] [param entity] that
## can still attack ([method Unit.can_attack]) is considered; a
## [code]StructureState[/code] (Defensive Structure) is scored too, at its
## real position only (structures never move).
##
## Cost of a stationary attack is [member CombatConfig.attack_cost] (unit) or
## [code]BaseProduction.defensive_attack_cost()[/code] (structure), read
## indirectly by constructing the same [AttackAction] [method Combat.apply]
## would charge — this helper does not duplicate Combat's cost table, it
## composes [method Movement.move_path_cost] with that same per-attacker-kind
## cost via [method _attack_ap_cost_for]. A move+attack combo's cost is
## [code]move_path_cost + attack_cost[/code] (Edge Cases' combo rule, AC-21).
##
## Every candidate is affordability-gated via [method AP.can_afford] before
## scoring (TR-ai-005) — an unaffordable candidate never reaches
## [method _action_score]/the running-best comparison. Replaces [param best]
## with a strictly higher-scoring candidate (interim `>` comparator — the
## epsilon/[code]ap_cost[/code]/[code]entity_id[/code] tie-break is Story 005's
## scope per this story's Implementation Notes; this story only proves the
## formulas produce the documented worked-example numbers).
static func _score_move_and_attack_candidates(lookahead: GameState, entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	if entity is UnitState and not Unit.can_attack(entity):
		return best

	# Stationary (zero-move) attacks from the entity's real position.
	for tr: Combat.TargetResult in Combat.legal_targets(lookahead, entity):
		var target: EntityState = lookahead.entity_at(tr.tile)
		var cost: int = _attack_ap_cost_for(entity)
		best = _consider_attack(lookahead, entity, target, entity.position, tr.tile, cost, best)

	# Move+attack combos — every reachable tile, scored via legal_targets_from
	# at the combined move + attack AP cost (Edge Cases, AC-21). Structures
	# never move, so this only applies to a UnitState entity.
	if entity is UnitState:
		var unit: UnitState = entity
		for r: Movement.ReachableTile in Movement.reachable(lookahead, unit):
			for tr: Combat.TargetResult in Combat.legal_targets_from(lookahead, unit, r.tile):
				var target: EntityState = lookahead.entity_at(tr.tile)
				var cost: int = r.min_cost + _attack_ap_cost_for(unit)
				best = _consider_attack(lookahead, unit, target, r.tile, tr.tile, cost, best)

	return best


## Scores one candidate attack ([param attacker] at hypothetical
## [param from_tile] against the entity occupying [param target_tile]) and
## folds it into [param best] if affordable and strictly better. Isolated so
## both the stationary and move+attack combo loops in
## [method _score_move_and_attack_candidates] share exactly one scoring/gate/
## fold path (never two parallel copies). The constructed [AttackAction] is
## returned unattempted — [b]never applied[/b] here; only the caller
## ([code]AITurnDriver[/code]) ever calls [code]apply_action[/code] (ADR-0011 §1).
static func _consider_attack(lookahead: GameState, attacker: EntityState, target: EntityState, \
		from_tile: Vector2i, target_tile: Vector2i, ap_cost: int, best: _Candidate) -> _Candidate:
	if not AP.can_afford(lookahead, attacker.owner, ap_cost):
		return best

	var hp_removed: int = mini(Combat.preview_damage(lookahead, attacker, target), _current_hp_of(target))
	var is_kill: bool = hp_removed >= _current_hp_of(target)
	var value: float = _combat_value(hp_removed, is_kill, target)
	var base_score: float = value / float(ap_cost)
	var score: float = _action_score(base_score, is_kill)

	if score > best.score:
		var action := AttackAction.new()
		action.player = attacker.owner
		action.attacker_tile = from_tile
		action.target_tile = target_tile
		return _Candidate.new(action, score, ap_cost, attacker.entity_id)
	return best


## `combat_value(attacker, target)` (GDD Formulas, AC-1/AC-6/AC-7):
## `ap_cost_opponent_paid_for(target) × (hp_removed / target_max_hp) +
## (is_kill ? KILL_DENIAL_RATE × ap_cost_opponent_paid_for(target) : 0)`.
## [param hp_removed] and [param is_kill] are pre-computed by the caller
## (shared with the [code]is_immediately_lethal[/code] read [method _action_score]
## needs — computed once, never re-derived). Strictly positive for any legal
## target, including a non-lethal HQ chip, because [param hp_removed] is never
## 0 (Combat's [code]MIN_DAMAGE=1[/code] floor on any legal, landed attack) and
## [method _ap_cost_opponent_paid_for] is never 0/undefined for any target kind.
static func _combat_value(hp_removed: int, is_kill: bool, target: EntityState) -> float:
	var ap_cost_opponent_paid: float = float(_ap_cost_opponent_paid_for(target))
	var target_max_hp: float = float(_max_hp_of(target))
	var value: float = ap_cost_opponent_paid * (float(hp_removed) / target_max_hp)
	if is_kill:
		value += AIBalance.ai.kill_denial_rate * ap_cost_opponent_paid
	return value


## `ap_cost_opponent_paid_for(target)` (GDD Formulas, AC-1) — read [b]live[/b]
## from the target's own field, never a memorized/hardcoded table: a
## [code]UnitState[/code] target's [code]type.produce_cost[/code]; a
## [code]StructureState[/code] target's [code]type.build_cost[/code] —
## [b]except[/b] the HQ (identified via [method StructureState.is_hq], never a
## parallel flag), which has no [code]build_cost[/code] and substitutes
## [code]AIBalance.ai.hq_siege_value[/code] (12) instead (AC-29's regression
## guard: an undefined/0 HQ weight would silently zero every siege attack's
## score).
static func _ap_cost_opponent_paid_for(target: EntityState) -> int:
	if target is StructureState and (target as StructureState).is_hq():
		return AIBalance.ai.hq_siege_value
	if target is UnitState:
		return (target as UnitState).type.produce_cost
	return (target as StructureState).type.build_cost


## [param target]'s full (undamaged) hp stat — [code]type.hp[/code] for either
## entity kind (the [code]combat_value[/code] denominator; never
## [code]current_hp[/code], which is the pre-attack remaining hp the numerator
## already accounts for).
static func _max_hp_of(target: EntityState) -> int:
	if target is UnitState:
		return (target as UnitState).type.hp
	return (target as StructureState).type.hp


## [param target]'s current hp at scoring time — the shared read both
## [method _consider_attack]'s [code]hp_removed[/code] clamp and
## [code]is_kill[/code] check use, isolated so both entity kinds resolve
## through one accessor.
static func _current_hp_of(target: EntityState) -> int:
	if target is UnitState:
		return (target as UnitState).current_hp
	return (target as StructureState).current_hp


## The real AP cost [param attacker] would spend on this attack — mirrors
## [code]Combat._attack_cost_for[/code]'s attacker-kind dispatch exactly
## (Combat's own cost function is private, so this composes the two public
## costs it dispatches between: [member CombatConfig.attack_cost] for a
## [code]UnitState[/code] attacker, [code]BaseProduction.defensive_attack_cost()[/code]
## for a [code]StructureState[/code] attacker) rather than reaching into
## Combat's private internals — keeps this read on the approved query surface
## (ADR-0011 §5: [code]CombatConfig[/code]/[code]BaseProduction[/code] public
## reads only).
static func _attack_ap_cost_for(attacker: EntityState) -> int:
	if attacker is StructureState:
		return BaseProduction.defensive_attack_cost()
	return CombatBalance.combat.attack_cost


## Per-structure unit-production candidate enumeration (ADR-0011 §2, Story
## 003) — per owned, [constant StructureState.BuildStatus.COMPLETED]
## [param entity] with at least one [code]producible_types[/code] entry, walks
## [method BaseProduction.legal_deploy_tiles] once and scores every
## (unit_type, deploy_tile) pair via [method _production_value]/
## [method _action_score]. Affordability-gated via [method AP.can_afford]
## before scoring (TR-ai-005) — an unaffordable candidate never reaches the
## running-best comparison. A non-producer structure (0 AP cost to check,
## empty [code]producible_types[/code]) or an under-construction producer
## contributes nothing.
static func _score_production_candidates(lookahead: GameState, entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	if not (entity is StructureState):
		return best
	var producer: StructureState = entity
	if producer.build_status != StructureState.BuildStatus.COMPLETED:
		return best
	if producer.type.producible_types.is_empty():
		return best

	var deploy_tiles: Array[Vector2i] = BaseProduction.legal_deploy_tiles(lookahead, producer, null)
	if deploy_tiles.is_empty():
		return best

	for unit_type: UnitTypeDef in producer.type.producible_types:
		var cost: int = Unit.effective_produce_cost(lookahead, unit_type, producer.owner)
		if not AP.can_afford(lookahead, producer.owner, cost):
			continue
		for tile: Vector2i in deploy_tiles:
			var multiplier: float = _reachability_multiplier(lookahead, producer.owner, tile, unit_type)
			var value: float = _production_value(unit_type, multiplier)
			var score: float = _action_score(value / float(cost), false)
			if score > best.score:
				var action := ProduceAction.new()
				action.player = producer.owner
				action.producer_id = producer.entity_id
				action.unit_type = unit_type
				action.tile = tile
				best = _Candidate.new(action, score, cost, producer.entity_id)

	return best


## `production_value(unit_type, deploy_tile)` (GDD Formulas, AC-1/AC-6):
## `produce_cost(unit_type) × REACHABILITY_MULTIPLIER`. [param multiplier] is
## pre-selected by [method _reachability_multiplier] — kept as a separate,
## directly-testable function so the worked example (Trooper 4 ×
## 1.1 = 4.4, AC-14) is checkable without re-deriving the band selection.
static func _production_value(unit_type: UnitTypeDef, multiplier: float) -> float:
	return float(unit_type.produce_cost) * multiplier


## `REACHABILITY_MULTIPLIER`'s fixed 3-band (GDD Formulas/Tuning Knobs) — a
## [b]code constant[/b], deliberately never an [AIConfig] field (ADR-0011 §6,
## Story 001's exclusion list). [b]1.1[/b] if [param unit_type], deployed on
## [param deploy_tile], could reach at least one live enemy entity this turn
## (within [code]attack_range + soft_move_cap[/code] of some enemy, measured
## via [method GridState.manhattan_distance] — the deterministic proxy for
## "within reach": a unit that could close the remaining distance and still
## attack this same turn). [b]1.0[/b] if not reachable-this-turn but the two
## sides are already [b]in contact[/b] — operationally: some friendly entity
## and some enemy entity are each within the [i]other's[/i]
## [code]attack_range + soft_move_cap[/code] reach (GDD's operational
## definition, verbatim). [b]0.9[/b] otherwise (isolated / opening-turn
## production). Deterministic and constructable from board state alone — no
## vague "active fight" judgment.
static func _reachability_multiplier(lookahead: GameState, owner: int, deploy_tile: Vector2i, unit_type: UnitTypeDef) -> float:
	var enemies: Array[EntityState] = []
	var friendlies: Array[EntityState] = []
	for e: EntityState in lookahead.entities():
		if e.owner == owner:
			friendlies.append(e)
		else:
			enemies.append(e)

	var own_reach: int = unit_type.attack_range + unit_type.soft_move_cap
	for enemy: EntityState in enemies:
		if lookahead.grid.manhattan_distance(deploy_tile, enemy.position) <= own_reach:
			return _REACHABILITY_MULTIPLIER_REACHABLE

	for friendly: EntityState in friendlies:
		if not (friendly is UnitState):
			continue
		var friendly_unit: UnitState = friendly
		var friendly_reach: int = friendly_unit.type.attack_range + friendly_unit.type.soft_move_cap
		for enemy: EntityState in enemies:
			if not (enemy is UnitState):
				continue
			var enemy_unit: UnitState = enemy
			var enemy_reach: int = enemy_unit.type.attack_range + enemy_unit.type.soft_move_cap
			var dist: int = lookahead.grid.manhattan_distance(friendly_unit.position, enemy_unit.position)
			if dist <= friendly_reach or dist <= enemy_reach:
				return _REACHABILITY_MULTIPLIER_IN_CONTACT

	return _REACHABILITY_MULTIPLIER_ISOLATED


## `action_score(action)` (GDD Formulas, AC-1/AC-6b, CR-7) — the one shared
## scale every verb's [code]base_score[/code] lands on:
## [code]is_immediately_lethal(action) ? max(base_score, LETHAL_FLOOR_BONUS) :
## base_score[/code]. Applied [b]post-hoc[/b], strictly after
## [param base_score] has already been computed from the real formula — never
## a pre-filter that short-circuits enumeration (CR-7, control-manifest
## Required rule for this layer). Two competing lethal candidates therefore
## both reach this function with their own real [param base_score] before
## either is floored, which is what lets Story 005's tie-break compare them
## correctly once both land on the identical [code]LETHAL_FLOOR_BONUS[/code]
## floor rather than "first lethal found wins."
static func _action_score(base_score: float, is_immediately_lethal: bool) -> float:
	if is_immediately_lethal:
		return maxf(base_score, AIBalance.ai.lethal_floor_bonus)
	return base_score


## Per-structure build/economy candidate enumeration (ADR-0011 §2) — stub for
## Story 002. The real implementation will walk


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
