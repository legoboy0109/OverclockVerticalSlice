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

## Every player-buildable [StructureTypeDef] (Story 004) — deliberately a
## [b]code constant[/b] here, not a [code]StructureTypes[/code] registry
## method: the HQ is setup-placed, never a [BuildAction] candidate (GDD
## Formulas `production_value` note / [method BaseProduction.legal_build_tiles]
## doc, "The HQ is never a candidate"), so it is excluded from this list. Order
## is irrelevant to correctness (every entry is folded into the same
## running-best scan) but fixed for determinism (ADR-0003).
const _BUILDABLE_STRUCTURE_TYPES: Array[StructureTypeDef] = [
	StructureTypes.ECONOMY_OUTPOST,
	StructureTypes.PRODUCTION_OUTPOST,
	StructureTypes.DEFENSIVE_STRUCTURE,
	StructureTypes.RESEARCH_LAB,
]


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


## Deterministic tie-break comparator (Story 005, AC-1; ADR-0011 §2 verbatim;
## ADR-0003 Rule 4) — the sole predicate every per-verb helper's running-best
## fold uses to decide whether a new candidate replaces [param best]. Pure,
## side-effect-free, reads only [code]AIBalance.ai.score_tie_epsilon[/code]
## (an [AIConfig] tunable, never a hardcoded literal) — [b]no engine RNG
## anywhere[/b] (control-manifest Forbidden rule, this layer).
##
## Implements exactly:
## [codeblock]
## score > best_score + SCORE_TIE_EPSILON        -> true  (strictly better)
## score < best_score - SCORE_TIE_EPSILON        -> false (strictly worse)
## else (tied within epsilon):
##     ap_cost != best_ap_cost -> ap_cost < best_ap_cost   (cheaper wins)
##     else                    -> entity_id < best_entity_id
## [/codeblock]
##
## [b]Exact ties resolve to the oldest eligible entity[/b] (lowest
## [code]entity_id[/code], which is assigned by a monotonic creation-order
## counter per ADR-0001/ADR-0003) — this is [b]intentional[/b] per the GDD's
## own Edge Cases and ADR-0003 Rule 4, not a latent bug: it is what makes a
## replayed exact-tie scenario select the identical candidate every run on the
## same build (TR-ai-011, AC-23's "replayed... same candidate every time").
##
## [b]Empty running-best[/b]: an as-yet-unset [_Candidate] defaults to
## [code]score = -INF[/code] (see [method _Candidate._init]), so the very
## first real candidate a helper folds in always satisfies
## [code]score > -INF + SCORE_TIE_EPSILON[/code] (float arithmetic:
## [code]-INF + finite == -INF[/code]) and therefore always wins — no special-
## cased "is best still empty?" branch is needed anywhere a helper calls this
## comparator.
##
## [b]Strict `>`/`<`, never `>=`/`<=`[/b]: a candidate whose score differs from
## [param best_score] by [i]exactly[/i] [code]SCORE_TIE_EPSILON[/code] does
## [b]not[/b] clear the strictly-better branch — it falls through to the tied
## branch and is resolved by [code]ap_cost[/code]/[code]entity_id[/code] like
## any other within-epsilon tie (see
## [code]ai_tiebreak_determinism_test.gd[/code]'s boundary test for the exact
## proof of which side of `>` this lands on).
static func _is_better(score: float, ap_cost: int, entity_id: int, \
		best_score: float, best_ap_cost: int, best_entity_id: int) -> bool:
	if score > best_score + AIBalance.ai.score_tie_epsilon:
		return true
	if score < best_score - AIBalance.ai.score_tie_epsilon:
		return false
	if ap_cost != best_ap_cost:
		return ap_cost < best_ap_cost
	return entity_id < best_entity_id


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
## only when a helper returns a strictly better one under [method _is_better]
## (ADR-0011 §2, Story 005) — the deterministic
## [code]score[/code]-then-[code]ap_cost[/code]-then-[code]entity_id[/code]
## tie-break comparator every per-verb helper folds its candidates through.
static func choose_action(state: GameState, economy_investments_committed: int) -> Action:
	var lookahead: GameState = state.clone()

	var best := _Candidate.new()
	for entity: EntityState in _entities_in_enumeration_order(lookahead):
		best = _score_move_and_attack_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_production_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_build_and_economy_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_research_candidates(lookahead, entity, economy_investments_committed, best)
		best = _score_cancel_build_candidates(lookahead, entity, economy_investments_committed, best)

	# Pass-threshold gate (ADR-0011 §1, AC-9): a candidate that does not clear
	# AIBalance.ai.pass_threshold is not worth the AP — return null so the driver
	# ends the turn (its documented "no candidate cleared pass_threshold" exit,
	# previously unenforced). The move-scoring config sits just above the floor by
	# design (positional 0.16, retreat 0.20 > pass_threshold 0.15), so genuine moves
	# clear it; only sub-threshold busy-work is filtered.
	if best.action == null or best.score <= AIBalance.ai.pass_threshold:
		return null
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
## via [method _is_better] (Story 005's deterministic epsilon/
## [code]ap_cost[/code]/[code]entity_id[/code] tie-break comparator), never a
## bare score comparison.
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

		# Bare, non-attacking repositioning (Story 004: positional/retreat,
		# Edge Cases). Tiles-normalized, NOT AP-cost-divided (the documented
		# exception to CR-3's value-per-AP scale) — see
		# [method _score_positional_and_retreat_candidates].
		best = _score_positional_and_retreat_candidates(lookahead, unit, best)

	return best


## Bare, non-attacking move scoring (GDD Edge Cases, Story 004 AC-20/AC-22/
## AC-31/AC-32) — folds every [method Movement.reachable] destination into
## [param best] via the two-term positional model, OR (mutually exclusive,
## anti-oscillation) the retreat model, never both for the same unit.
##
## Wounded-unit exclusion is checked [b]first[/b] (Implementation Notes: "must
## be checked before generating advance candidates" — an excluded unit
## generates zero advance/[code]SETUP_ADVANCE_BONUS[/code] candidates, not a
## suppressed one): if [param unit] is at/below
## [code]AIBalance.ai.retreat_hp_fraction[/code] of max hp AND currently inside
## some live enemy's next-turn threat range, every reachable tile is scored
## [b]only[/b] via [method _retreat_value] — the positional/setup branch is
## never entered for this unit this call. Otherwise every reachable tile is
## scored via [method _positional_value] (Term 1 closing-distance +
## Term 2 [code]SETUP_ADVANCE_BONUS[/code]).
##
## Both branches normalize by [param tiles_moved] — the BFS step count to the
## candidate tile, recovered via [method _tiles_moved_for] — never
## [code]r.min_cost[/code] (Edge Cases: "not `/ move_path_cost`"). A tile
## reached at [code]tiles_moved == 0[/code] (the unit's own current position,
## which [method Movement.reachable] never returns per its own contract) is
## impossible here, so no divide-by-zero guard is needed.
static func _score_positional_and_retreat_candidates(lookahead: GameState, unit: UnitState, best: _Candidate) -> _Candidate:
	var nearest_enemy_dist_before: int = _nearest_live_enemy_distance(lookahead, unit.position, unit.owner)
	var threat: _ThreatInfo = _nearest_threatening_enemy(lookahead, unit)
	var is_wounded_and_threatened: bool = _is_wounded(unit) and threat.found

	# Single best advance, folded once after the loop. Every straight-line advance
	# ties at POSITIONAL_VALUE_PER_TILE_CLOSED (dist_closed == tiles_moved, AC-20),
	# so folding each tile through the global ap_cost tie-break would pick the
	# 1-tile step and the unit would crawl one tile per commit. Instead we keep the
	# tile that ends CLOSEST to the nearest enemy (max progress in one move),
	# tie-broken among equally-close tiles by the standard comparator (score — e.g.
	# a setup tile — then cheapest path).
	var adv_found: bool = false
	var adv_tile: Vector2i = Vector2i.ZERO
	var adv_tiles_moved: int = 0
	var adv_dist_after: int = nearest_enemy_dist_before
	var adv_score: float = 0.0
	var adv_ap_cost: int = 0

	# --- Siege drive ---------------------------------------------------------
	# Folded exactly like the advance above, and for the same reason: every tile of
	# progress ties on a per-tile rate, so folding each through the global tie-break
	# would pick the 1-tile step and the unit would crawl.
	var hq: StructureState = _enemy_hq(lookahead, unit.owner)
	var siege_dist_before: int = -1
	if hq != null:
		siege_dist_before = lookahead.grid.manhattan_distance(unit.position, hq.position)
	var siege_found: bool = false
	var siege_tile: Vector2i = Vector2i.ZERO
	var siege_tiles_moved: int = 0
	var siege_dist_after: int = siege_dist_before
	var siege_score: float = 0.0
	var siege_ap_cost: int = 0

	for r: Movement.ReachableTile in Movement.reachable(lookahead, unit):
		if not AP.can_afford(lookahead, unit.owner, r.min_cost):
			continue
		var tiles_moved: int = _tiles_moved_for(unit, r.min_cost)
		if tiles_moved <= 0:
			continue # Defensive — reachable() never returns the start tile itself.
		if not Combat.legal_targets_from(lookahead, unit, r.tile).is_empty():
			continue # Edge Cases/AC-20: positional scoring applies only to a
			         # tile with "no combo target reachable FROM IT" — a tile
			         # that enables a move+attack combo is already scored by
			         # the combo loop above and must not also compete here
			         # (this is the exact case a caller's regression test
			         # (ai_combat_production_scoring_test.gd) guards: a
			         # combo-enabling tile must never be silently outscored/
			         # replaced by this tiles-normalized exception).

		if is_wounded_and_threatened:
			var threat_dist_before: int = threat.distance
			var threat_dist_after: int = lookahead.grid.manhattan_distance(r.tile, threat.entity.position)
			var value: float = _retreat_value(threat_dist_before, threat_dist_after)
			var score: float = value / float(tiles_moved)
			if _is_better(score, r.min_cost, unit.entity_id, best.score, best.ap_cost, best.entity_id):
				best = _Candidate.new(_make_move_action(unit, r.tile, tiles_moved), score, r.min_cost, unit.entity_id)
			continue # Anti-oscillation: no advance/SETUP candidate this call.

		# Siege is evaluated BEFORE the nearest-enemy closure gate below, because the
		# tiles that matter for a siege are precisely the ones that gate rejects: a
		# step toward the enemy HQ usually does not close on the nearest enemy unit.
		if siege_dist_before > 0:
			var hq_dist_after: int = lookahead.grid.manhattan_distance(r.tile, hq.position)
			# Same strict-closure rule the advance uses, and for the same
			# anti-oscillation reason: only tiles that genuinely make progress.
			if hq_dist_after < siege_dist_before:
				var s_value: float = AIBalance.ai.siege_value_per_tile_closed \
					* float(siege_dist_before - hq_dist_after)
				var s_score: float = s_value / float(tiles_moved)
				var s_take: bool = false
				if not siege_found:
					s_take = true
				elif hq_dist_after < siege_dist_after:
					s_take = true
				elif hq_dist_after == siege_dist_after \
						and _is_better(s_score, r.min_cost, unit.entity_id, siege_score, siege_ap_cost, unit.entity_id):
					s_take = true
				if s_take:
					siege_found = true
					siege_tile = r.tile
					siege_tiles_moved = tiles_moved
					siege_dist_after = hq_dist_after
					siege_score = s_score
					siege_ap_cost = r.min_cost

		var dist_after: int = _nearest_live_enemy_distance(lookahead, r.tile, unit.owner)
		# Anti-oscillation: consider a bare advance ONLY if it strictly closes
		# distance to the nearest enemy. A non-closing tile (lateral/backward) would
		# otherwise score positive purely on SETUP_ADVANCE_BONUS — any tile within
		# reach of a nearby target "sets up" — and since choose_action returns the
		# top candidate with no pass-threshold gate, the AI would commit it and then
		# commit the reverse move next iteration, ping-ponging until AP drained.
		# Requiring strict closure makes bare advances distance-monotonic.
		if dist_after >= nearest_enemy_dist_before:
			continue
		var sets_up: bool = _sets_up_attack_next_turn(lookahead, unit, r.tile)
		var value: float = _positional_value(nearest_enemy_dist_before, dist_after, sets_up)
		var score: float = value / float(tiles_moved)
		# Keep the furthest-advancing tile (smallest resulting distance); among tiles
		# reaching the same closest frontier, break ties with the standard comparator.
		var take: bool = false
		if not adv_found:
			take = true
		elif dist_after < adv_dist_after:
			take = true
		elif dist_after == adv_dist_after and _is_better(score, r.min_cost, unit.entity_id, adv_score, adv_ap_cost, unit.entity_id):
			take = true
		if take:
			adv_found = true
			adv_tile = r.tile
			adv_tiles_moved = tiles_moved
			adv_dist_after = dist_after
			adv_score = score
			adv_ap_cost = r.min_cost

	if adv_found and _is_better(adv_score, adv_ap_cost, unit.entity_id, best.score, best.ap_cost, best.entity_id):
		best = _Candidate.new(_make_move_action(unit, adv_tile, adv_tiles_moved), adv_score, adv_ap_cost, unit.entity_id)

	if siege_found and _is_better(siege_score, siege_ap_cost, unit.entity_id, best.score, best.ap_cost, best.entity_id):
		best = _Candidate.new(_make_move_action(unit, siege_tile, siege_tiles_moved), siege_score, siege_ap_cost, unit.entity_id)

	return best


## `positional_value(move)` (GDD Edge Cases, AC-20/AC-32):
## `POSITIONAL_VALUE_PER_TILE_CLOSED × max(0, dist_before − dist_after) +
## (sets_up_attack_next_turn(dest) ? SETUP_ADVANCE_BONUS : 0)`. Pure arithmetic
## — isolated so the worked example (Heavy/Scout both ≈0.16, AC-20) and the
## setup-bonus proof (AC-32) are directly testable without re-deriving the
## enumeration.
static func _positional_value(dist_before: int, dist_after: int, sets_up_attack_next_turn: bool) -> float:
	var value: float = AIBalance.ai.positional_value_per_tile_closed * float(maxi(0, dist_before - dist_after))
	if sets_up_attack_next_turn:
		value += AIBalance.ai.setup_advance_bonus
	return value


## `retreat_value(move)` (GDD Edge Cases, AC-31):
## `RETREAT_VALUE_PER_TILE_FLED × max(0, threat_dist_after − threat_dist_before)`.
## Pure arithmetic, isolated for direct testing exactly like
## [method _positional_value].
static func _retreat_value(threat_dist_before: int, threat_dist_after: int) -> float:
	return AIBalance.ai.retreat_value_per_tile_fled * float(maxi(0, threat_dist_after - threat_dist_before))


## True iff [param unit] is at or below [code]AIBalance.ai.retreat_hp_fraction[/code]
## of its max hp (GDD Edge Cases, self-preservation). Integer hp compared
## against a float fraction of the (int) max hp — matches the GDD's own
## `<=` phrasing exactly (a unit sitting precisely at the fraction is included).
static func _is_wounded(unit: UnitState) -> bool:
	return float(unit.current_hp) <= AIBalance.ai.retreat_hp_fraction * float(unit.type.hp)


## Carrier for [method _nearest_threatening_enemy]'s result — the nearest live
## enemy entity whose next-turn threat range currently covers [param unit]'s
## position, plus the (pre-computed) distance to it. [member found] is
## [code]false[/code] (and [member entity]/[member distance] unused) when no
## live enemy threatens [param unit] from its current position.
class _ThreatInfo extends RefCounted:
	var found: bool = false
	var entity: EntityState = null
	var distance: int = 0


## Finds the nearest live enemy entity whose next-turn threat range
## ([code]soft_move_cap + attack_range[/code] for a [UnitState] attacker,
## [code]attack_range[/code] alone for an immobile [StructureState] attacker,
## per [method _sets_up_attack_next_turn]'s same reach definition) currently
## covers [param unit]'s [b]own[/b] position — the self-preservation trigger
## (GDD Edge Cases, AC-31). Ties (equal distance) resolve to the
## lowest-[code]entity_id[/code] enemy for determinism (ADR-0003), mirroring
## [method _nearest_live_enemy_distance]'s own tie-break.
static func _nearest_threatening_enemy(state: GameState, unit: UnitState) -> _ThreatInfo:
	var result := _ThreatInfo.new()
	var best_dist: int = -1
	for e: EntityState in state.entities():
		if e.owner == unit.owner:
			continue
		var reach: int = _threat_reach_of(e)
		var dist: int = state.grid.manhattan_distance(unit.position, e.position)
		if dist > reach:
			continue
		if best_dist == -1 or dist < best_dist or (dist == best_dist and e.entity_id < result.entity.entity_id):
			best_dist = dist
			result.entity = e
			result.distance = dist
			result.found = true
	return result


## The next-turn threat reach of [param entity] as a potential attacker: a
## [UnitState]'s [code]soft_move_cap + attack_range[/code] (it can close
## distance and still attack next turn), or a [StructureState]'s bare
## [code]attack_range[/code] (structures never move — mirrors
## [method _sets_up_attack_next_turn]'s identical reach rule from the
## defender's perspective).
static func _threat_reach_of(entity: EntityState) -> int:
	if entity is UnitState:
		var u: UnitState = entity
		return u.type.soft_move_cap + u.type.attack_range
	var s: StructureState = entity
	return s.type.attack_range


## Manhattan distance from [param from_tile] to the [b]nearest live enemy
## entity[/b] (unit or structure) owned by anyone other than [param owner] —
## the GDD Edge Cases' Term 1 distance measure, "nearest live enemy," not the
## earlier-rejected "nearest forward entity" phrasing. Returns
## [code]0[/code] if no live enemy exists on the board (a legitimate,
## if rare, end-state; [method _positional_value]'s
## [code]max(0, dist_before - dist_after)[/code] degrades gracefully to 0 in
## that case, never a negative or undefined closing value).
static func _nearest_live_enemy_distance(state: GameState, from_tile: Vector2i, owner: int) -> int:
	var best_dist: int = -1
	for e: EntityState in state.entities():
		if e.owner == owner:
			continue
		var dist: int = state.grid.manhattan_distance(from_tile, e.position)
		if best_dist == -1 or dist < best_dist:
			best_dist = dist
	return maxi(0, best_dist)


## The enemy HQ [StructureState] for [param owner], or [code]null[/code] if the
## opponent has none (it was destroyed, or setup never placed one).
##
## The objective the siege drive advances on. Identified via
## [method StructureState.is_hq] — a Resource-ref check against the real HQ template
## per ADR-0007, never a parallel flag. Deterministic: [method GameState.entities] is
## entity_id-ordered, so a hypothetical two-HQ opponent always yields the same one.
##
## O(entity count), one pass — the same cost class as the enumeration already running.
static func _enemy_hq(state: GameState, owner: int) -> StructureState:
	for e: EntityState in state.entities():
		if e.owner == owner:
			continue
		if e is StructureState and (e as StructureState).is_hq():
			return e as StructureState
	return null


## `sets_up_attack_next_turn(dest)` (GDD Edge Cases Term 2, AC-32) — true iff,
## from hypothetical [param dest], [param unit] could legally attack some live
## enemy [b]next[/b] turn: some enemy entity lies within
## [code]dest[/code]'s [code]soft_move_cap + attack_range[/code] reach. A cheap
## one-step distance check (never a second lookahead search, per
## Implementation Notes/ADR-0011 §2) reusing only
## [method GridState.manhattan_distance] — no [method Movement.reachable] call
## against a hypothetical future turn.
static func _sets_up_attack_next_turn(state: GameState, unit: UnitState, dest: Vector2i) -> bool:
	var reach: int = unit.type.soft_move_cap + unit.type.attack_range
	for e: EntityState in state.entities():
		if e.owner == unit.owner:
			continue
		if state.grid.manhattan_distance(dest, e.position) <= reach:
			return true
	return false


## Recovers the BFS step count (tiles traversed) that produced
## [param reported_cost] for [param unit], by linear search over
## [method Movement.move_path_cost] — the single public cost primitive
## [method Movement.reachable] itself is built on (ADR-0009's
## reachable-vs-billed agreement invariant). [code]move_path_cost[/code] is
## strictly increasing in tile count (each entered tile costs at least
## [code]move_cost >= 1[/code] in-cap, or the [code]>= move_cost[/code]
## surcharge over-cap — [code]UnitConfig[/code]'s own contract), so this
## search is well-founded and terminates at the first exact match. Bounded by
## the board's own diagonal (a handful of iterations in the VS's 14×16 board),
## never a second BFS. Returns [code]0[/code] (never negative) if no depth
## reproduces [param reported_cost] — defensive only; cannot happen for a cost
## [method Movement.reachable] itself just reported.
static func _tiles_moved_for(unit: UnitState, reported_cost: int) -> int:
	var depth: int = 1
	while depth <= unit.type.soft_move_cap + unit.tiles_moved_this_turn + 64:
		if Movement.move_path_cost(unit, depth) == reported_cost:
			return depth
		depth += 1
	return 0


## Builds a [MoveAction] for [param unit] to hypothetical [param dest] at
## [param tiles_moved] tiles entered — the sole [Action] constructor the
## positional/retreat branch uses, mirroring [method _consider_attack]'s
## "construct, never apply" discipline (ADR-0011 §1: only the caller commits).
static func _make_move_action(unit: UnitState, dest: Vector2i, tiles_moved: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = unit.owner
	action.from = unit.position
	action.to = dest
	action.tiles_entered = tiles_moved
	return action


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

	if _is_better(score, ap_cost, attacker.entity_id, best.score, best.ap_cost, best.entity_id):
		var action: Action
		if from_tile == attacker.position:
			# Stationary attack — the unit is already on the firing tile, so a
			# single AttackAction commits cleanly.
			var atk := AttackAction.new()
			atk.player = attacker.owner
			atk.attacker_tile = from_tile
			atk.target_tile = target_tile
			action = atk
		else:
			# Move+attack combo (from_tile is a reachable tile the unit is NOT on
			# yet). A single Action cannot both move AND attack, and an
			# AttackAction whose attacker_tile is the not-yet-occupied firing tile
			# is uncommittable against the real state (apply_action → NO_SUCH_ENTITY,
			# which the driver would re-loop on forever). So commit the MOVE to the
			# firing tile now; the attack lands next driver iteration once the unit
			# is actually there (the loop re-clones after every commit, AC-26). The
			# combo's combined-cost score is retained so the AI still prefers the
			# approach that sets up the best attack.
			var move_cost: int = ap_cost - _attack_ap_cost_for(attacker)
			action = _make_move_action(attacker as UnitState, from_tile, \
					_tiles_moved_for(attacker as UnitState, move_cost))
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
	# Per-turn production-cap gate — mirrors BaseProduction.validate_produce's
	# PRODUCTION_CAP_REACHED gate (base_production.gd). A producer already at its
	# effective cap this turn contributes no ProduceAction candidate. Without this,
	# choose_action re-proposes an at-cap produce every call, apply_action rejects
	# it (PRODUCTION_CAP_REACHED), and the driver's reject-continue loop spins
	# forever with no await — the AI-turn freeze (headless tests missed it because
	# rejections emit no action_applied, so the commit-count bound never trips).
	if producer.units_produced_this_turn >= BaseProduction.effective_production_cap(lookahead, producer, producer.owner):
		return best

	var deploy_tiles: Array[Vector2i] = BaseProduction.legal_deploy_tiles(lookahead, producer, null)
	if deploy_tiles.is_empty():
		return best

	for unit_type: UnitTypeDef in producer.type.producible_types:
		var cost: int = Unit.effective_produce_cost(lookahead, unit_type, producer.owner)
		# Dual-cost affordability (ADR-0006 pivot): produce needs BOTH the Credit
		# main cost AND the AP surcharge, else apply_action rejects it — skip such
		# candidates so the driver never enters an unaffordable-commit reject loop.
		# NOTE (Landing 4b): scoring below still uses the Credit `cost` as the
		# value/cost denominator (== ap_equiv_cost at CREDIT_TO_AP_RATE=1); the full
		# two-currency scoring is deferred to the AI CREDIT_TO_AP_RATE rework.
		if not Credits.can_afford(lookahead, producer.owner, cost) \
				or not AP.can_afford(lookahead, producer.owner, Balance.economy.produce_ap_cost):
			continue
		for tile: Vector2i in deploy_tiles:
			var multiplier: float = _reachability_multiplier(lookahead, producer.owner, tile, unit_type)
			var value: float = _production_value(unit_type, multiplier)
			var score: float = _action_score(value / float(cost), false)
			if _is_better(score, cost, producer.entity_id, best.score, best.ap_cost, best.entity_id):
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


## Per-structure-type build/economy candidate enumeration (ADR-0011 §2, Story
## 004) — walks [method BaseProduction.legal_build_tiles] for every
## [constant _BUILDABLE_STRUCTURE_TYPES] entry and scores every
## (structure_type, tile) pair, dispatching [method _economy_value] for
## [constant StructureTypes.ECONOMY_OUTPOST] vs. [method _production_value]-style
## scoring (a flat [code]1.0[/code] multiplier — a build has no
## [code]REACHABILITY_MULTIPLIER[/code] analogue; this mirrors
## [code]production_value[/code]'s "value anchors to the resource's own sunk
## cost" shape without inventing a second board-context band) for every other
## buildable structure.
##
## [param entity] is unused (this helper's candidate universe is
## player-scoped via [method BaseProduction.legal_build_tiles], not
## per-entity) — kept in the signature only to match every other per-verb
## helper's [code](lookahead, entity, economy_investments_committed, best)[/code]
## shape the streaming [method choose_action] scan calls uniformly.
## [method BaseProduction.legal_build_tiles] is documented "safe to recompute
## every preview frame" (O(friendly_count × 4 × enemy_structure_count)), so
## calling it once per entity in the outer scan (rather than threading a
## once-per-player precomputed result through) is cheap and correct — the
## running-best fold is naturally idempotent against the resulting redundant
## re-consideration of the same candidates.
##
## Cadence cap (AC-30): once [param economy_investments_committed] >=
## [code]AIBalance.ai.max_economy_investments_per_turn[/code], every
## [constant StructureTypes.ECONOMY_OUTPOST] candidate is excluded from
## enumeration entirely — the loop below never even constructs/scores one,
## never merely down-scores it. Non-economy buildable structures are
## unaffected by the cap (CR-5 / the GDD's cadence-cap scope is
## economy-outpost + research investments only).
static func _score_build_and_economy_candidates(lookahead: GameState, _entity: EntityState, \
		economy_investments_committed: int, best: _Candidate) -> _Candidate:
	var player: int = lookahead.active_player
	var cap_reached: bool = economy_investments_committed >= AIBalance.ai.max_economy_investments_per_turn

	for structure_type: StructureTypeDef in _BUILDABLE_STRUCTURE_TYPES:
		# Only ECONOMY_OUTPOST has a real AI valuation (_economy_value). The other
		# buildable types have no strategic model yet; enumerating them on the
		# placeholder value==build_cost basis made the AI build structures it could
		# not value and immediately cancel-build them for the refund — a
		# build<->cancel oscillation that consumed the whole turn. Excluded until
		# real valuations exist, mirroring the stubbed research enumeration.
		if structure_type != StructureTypes.ECONOMY_OUTPOST:
			continue
		if cap_reached:
			continue

		var cost: int = BaseProduction.effective_build_cost(lookahead, structure_type, player)
		# Dual-cost affordability (ADR-0006 pivot): build needs BOTH the Credit main
		# cost AND the AP surcharge, else apply_action rejects it — skip such
		# candidates so the driver never enters an unaffordable-commit reject loop.
		# NOTE (Landing 4b): scoring below still uses the Credit `cost` as the
		# value/cost denominator (== ap_equiv_cost at CREDIT_TO_AP_RATE=1); the full
		# two-currency scoring is deferred to the AI CREDIT_TO_AP_RATE rework.
		if not Credits.can_afford(lookahead, player, cost) \
				or not AP.can_afford(lookahead, player, Balance.economy.build_ap_cost):
			continue

		var tiles: Array[Vector2i] = BaseProduction.legal_build_tiles(lookahead, player, structure_type)
		if tiles.is_empty():
			continue

		var value: float = _economy_value(lookahead, player, structure_type)
		var score: float = _action_score(value / float(cost), false)
		var candidate_entity_id: int = _lowest_owned_entity_id(lookahead, player)
		if _is_better(score, cost, candidate_entity_id, best.score, best.ap_cost, best.entity_id):
			var action := BuildAction.new()
			action.player = player
			action.structure_type = structure_type
			action.tile = tiles[0]
			best = _Candidate.new(action, score, cost, candidate_entity_id)

	return best


## `economy_value(build_action)` (GDD Formulas, AC-15/AC-16):
## `raw_immediate_value(0) + Σ_{t=1}^{ECONOMY_HORIZON} marginal_ap_income(t) ×
## ECONOMY_DECAY^t`, uncapped. [param structure_type] is always
## [constant StructureTypes.ECONOMY_OUTPOST] here (the caller's dispatch
## gate) — kept as an explicit parameter (rather than hardcoding the type
## internally) so a future non-Outpost economy building, if one is ever added,
## slots in without a signature change. `raw_immediate_value` is fixed 0 (an
## a structure's `build_time` produces no immediate board effect the turn it
## starts, GDD Formulas table) — never computed, just the literal.
##
## `marginal_credit_income(t)` is [b]this candidate's own marginal contribution[/b]
## at future turn `t`. ★ [b]S6-01 (2026-08-24): it is now always 0 for a structure
## build.[/b] The per-outpost income curve this once read is deleted; no structure
## raises Credit income any more (see [method Credits.credit_income_breakdown]), so
## building something is not an economic investment and must not be scored as one.
## That is the PIVOT verdict's fix arriving at the scoring layer.
##
## No cap is applied anywhere in this sum (the GDD's 2026-07-22 decoupling
## note) — the dominant-strategy guardrail is [param economy_investments_committed]'s
## cadence cap in the caller, never a valuation ceiling here.
static func _economy_value(lookahead: GameState, player: int, structure_type: StructureTypeDef) -> float:
	# ★ S6-01 (2026-08-24): re-pointed off the deleted per-outpost income curve.
	#
	# NO STRUCTURE RAISES CREDIT INCOME ANY MORE. Income comes solely from completed
	# economy research tiers (Credits.credit_income_breakdown), so the marginal income
	# of *building* anything is exactly zero — and this function is only ever called
	# with a structure candidate (see the build-scoring loop above).
	#
	# Returning 0 here is CORRECT, not a stub: the AI should no longer treat any build
	# as an economic investment, because none is. That is precisely the behaviour the
	# PIVOT verdict wanted — the AI kept choosing BUILD because building bought income.
	#
	# ⚠ S6-05 owns the other half: giving RESEARCH actions an economy_value computed
	# from econ_tier_bonus, and re-anchoring CREDIT_TO_AP_RATE (1.0 -> 0.01, broken by
	# the ×100 Credit rescale). Until then the AI simply has no economic play to score,
	# which is a *safe* failure direction — it under-invests rather than over-builds.
	var marginal_income: float = 0.0

	var raw_immediate_value: float = 0.0
	var decayed_sum: float = 0.0
	for t in range(1, AIBalance.ai.economy_horizon + 1):
		decayed_sum += marginal_income * pow(AIBalance.ai.economy_decay, t)
	return raw_immediate_value + decayed_sum


## Resolves the lowest owned [code]entity_id[/code] for [param player]
## (deterministic tie-break surrogate for a build/economy candidate, which —
## unlike an attack/production/move candidate — has no single "acting entity"
## of its own; the builder is the player, not a specific unit/structure).
## Mirrors [method _entities_in_enumeration_order]'s own ascending-id
## ordering (ADR-0003) rather than inventing a second sort. Falls back to
## [code]0[/code] (never a crash) if [param player] owns no entities yet — an
## unreachable case in practice (a player with zero entities has no AP-earning
## producers left to build from), kept only as a defensive floor.
static func _lowest_owned_entity_id(lookahead: GameState, player: int) -> int:
	for e: EntityState in lookahead.entities():
		if e.owner == player:
			return e.entity_id
	return 0


## Per-Lab research candidate enumeration (ADR-0011 §2). [b]Story 004 scope
## note (deferred integration point, flagged per this story's Implementation
## Notes — surfaced explicitly, not silently skipped):[/b] the
## [code]research_value[/code] MATH below ([method _research_value]) is fully
## implemented per the GDD Formulas section and is ready to enumerate the
## instant Research/Tech lands, but the enumeration [b]source[/b] this helper
## would walk — [code]Research.legal_research_targets(state, lab)[/code] — does
## not exist yet (the Research/Tech epic is not implemented in this corpus).
## This helper therefore [b]always returns [param best] unchanged[/b], the
## same documented-stub contract Story 002 shipped, so [method choose_action]
## never enumerates a research candidate today (Edge case: "returns no
## candidates without error"). Re-enable point: once
## [code]Research.legal_research_targets[/code] exists, replace this body with
## a loop mirroring [method _score_build_and_economy_candidates]'s cadence-cap
## gate (exclude every candidate once [param economy_investments_committed] >=
## [code]AIBalance.ai.max_economy_investments_per_turn[/code], per CR-5 —
## research counts toward the same cadence cap as economy builds) around
## [method _research_value] / [method _action_score].
static func _score_research_candidates(_lookahead: GameState, _entity: EntityState, \
		_economy_investments_committed: int, best: _Candidate) -> _Candidate:
	return best


## `research_value(tech)` (GDD Formulas, AC-17/AC-17a/AC-17b) — implemented now
## per spec so it is ready the instant [method _score_research_candidates] is
## re-enabled (this story's documented deferred integration point), even
## though nothing calls this function yet (Research/Tech is not implemented).
##
## `Σ_{t=research_time+1}^{horizon} marginal_tech_value × ECONOMY_DECAY^t`,
## where [param horizon] is [code]AIBalance.ai.tech_value_horizon[/code] for
## Attack/Defense Tech (permanent army-wide buffs) or
## [code]AIBalance.ai.economy_horizon[/code] for Economy Tech (an income
## projection) — the caller selects which via [param horizon], never decided
## inside this pure sum. [param marginal_tech_value] is likewise pre-computed
## by the caller (via [method _attack_defense_tech_marginal_value] or
## [method _economy_tech_marginal_value] below) and passed in flat, since it
## is constant across every summed turn for both tech families in this GDD
## (mirrors how [method _economy_value] pre-selects its own
## [code]marginal_income[/code] once, not per-`t`).
static func _research_value(research_time: int, horizon: int, marginal_tech_value: float) -> float:
	var decayed_sum: float = 0.0
	for t in range(research_time + 1, horizon + 1):
		decayed_sum += marginal_tech_value * pow(AIBalance.ai.economy_decay, t)
	return decayed_sum


## `marginal_tech_value(tech, t)` for Attack/Defense Tech (GDD Formulas,
## AC-17/AC-17a): `tech_attack_or_defense_bonus / HP_PER_AP ×
## ATTACKS_LANDED_PER_TURN_ESTIMATE`. Flat across every summed turn (a
## permanent stat buff), so [method _research_value] receives this pre-computed
## once, not re-evaluated per-`t`.
static func _attack_defense_tech_marginal_value(tech_bonus: float) -> float:
	return tech_bonus / AIBalance.ai.hp_per_ap * AIBalance.ai.attacks_landed_per_turn_estimate


## `marginal_tech_value(tech, t)` for Economy Tech (GDD Formulas, AC-17b):
## `ECONOMY_TECH_INCOME_BONUS × min(projected_completed_outposts,
## ECONOMY_TECH_TIER_THRESHOLD)`. [param projected_completed_outposts] is the
## researching player's completed [b]plus[/b] under-construction Economy
## Outposts (the caller's responsibility to compute — this function is pure
## arithmetic only, per the GDD's "counting in-flight outposts" fix).
## ★ S6-01 (2026-08-24): Economy Tech's income no longer scales with outpost count —
## it is a flat [code]econ_tier_bonus[/code] per completed tier, and the outpost count
## it multiplied against no longer exists. Kept as a one-line pass-through rather than
## deleted so the call graph and its tests stay intact until S6-05 rewrites the research
## scoring path properly.
static func _economy_tech_marginal_value(econ_tier_bonus: int, _unused_projected: int, _unused_threshold: int) -> float:
	return float(econ_tier_bonus)


## Per-under-construction-structure cancel-build candidate enumeration
## (ADR-0011 §2, Story 004, AC-22) — considers cancelling [param entity] if it
## is an owned, [constant StructureState.BuildStatus.UNDER_CONSTRUCTION]
## [StructureState]. Scored via [method _cancel_build_value] and folded into
## [param best] with [b]no affordability gate[/b] (Cancel Build refunds AP, it
## never spends any — TR-ai-005's affordability check has nothing to check
## here, mirroring [method BaseProduction.apply_cancel]'s own AP-credit-only
## contract).
static func _score_cancel_build_candidates(lookahead: GameState, entity: EntityState, \
		economy_investments_committed: int, best: _Candidate) -> _Candidate:
	if not (entity is StructureState):
		return best
	var structure: StructureState = entity
	if structure.owner != lookahead.active_player:
		return best
	if structure.build_status != StructureState.BuildStatus.UNDER_CONSTRUCTION:
		return best
	# Anti-oscillation (mirrors the retreat gate, AC-31): once the AI has committed
	# any economy investment this turn it stops enumerating cancel-build, so it
	# never cancels a structure it just built. Cancel-build is scored on an
	# absolute-AP refund basis (_cancel_build_value), which otherwise makes
	# cancelling a just-built structure look profitable and drives a build<->cancel
	# oscillation. A structure under construction from a prior turn stays
	# cancellable on a turn where the AI has not itself built (committed == 0).
	if economy_investments_committed > 0:
		return best

	var value: float = _cancel_build_value(structure.type.build_cost)
	var score: float = _action_score(value, false)
	if _is_better(score, 0, structure.entity_id, best.score, best.ap_cost, best.entity_id):
		var action := CancelBuildAction.new()
		action.player = lookahead.active_player
		action.structure_id = structure.entity_id
		best = _Candidate.new(action, score, 0, structure.entity_id)

	return best


## `cancel_build_value = CANCEL_REFUND_RATE × build_cost(structure)` (GDD Edge
## Cases, AC-22) — delegates to [method BaseProduction.cancel_refund], the
## Base & Production-owned fixed-point integer refund primitive
## ([member BaseProductionConfig.cancel_refund_pct], read via the
## [code]StructureBalance[/code] Autoload), rather than duplicating
## `CANCEL_REFUND_RATE` as a second float constant here (GDD Tuning Knobs:
## "Owned by Base & Production... listed here only because `cancel_build_value`
## reads it"). Returned as a [code]float[/code] so it composes with
## [method _action_score]'s float signature, even though the refund itself is
## computed in exact integer arithmetic internally.
##
## `action_score(cancel_build) = cancel_build_value` directly — [b]no division
## by AP cost[/b] (Cancel Build returns AP, it doesn't spend it), which is why
## the caller passes this value straight into [method _action_score] rather
## than a `value / ap_cost` ratio the way every other verb does.
static func _cancel_build_value(build_cost: int) -> float:
	return float(BaseProduction.cancel_refund(build_cost))
