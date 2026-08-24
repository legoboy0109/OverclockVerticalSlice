# Story 004: Verb Scoring — economy_value, research_value (stubbed),
# positional/retreat/cancel-build, cadence cap.
#
# Covers production/epics/ai-opponent/story-004-economy-positional-scoring-cadence.md
# QA Test Cases, each hitting the GDD's exact worked-example numbers:
#
#   AC-15 (Economy Outpost #1, no Economy Tech): economy_value ~= 7.06,
#     action_score (cost 4) ~= 1.765.
#   AC-16 (tier-1 vs tier-2): a tier-1 candidate's economy_value is strictly
#     greater than a tier-2 candidate's.
#   AC-20 (tiles-normalized positional advance): a Heavy (move_cost 3) and a
#     Scout (move_cost 1) each advancing 3 tiles with no setup bonus both
#     score IDENTICALLY ~= POSITIONAL_VALUE_PER_TILE_CLOSED (0.16) — the
#     tiles-normalization proof (NOT /move_path_cost).
#   AC-32 (setup bonus): a setup move (dest sets up a next-turn attack) scores
#     strictly higher than an otherwise-identical non-setup move.
#   AC-31 (self-preservation, anti-oscillation): a wounded (<=RETREAT_HP_
#     FRACTION), threatened unit generates ONLY a retreat candidate, never an
#     advance/SETUP candidate.
#   AC-22 (cancel-build, no AP division): action_score(cancel_build) ==
#     CANCEL_REFUND_RATE x build_cost directly, never divided by AP cost.
#   AC-30 (cadence cap, single-pass): once economy_investments_committed >=
#     max_economy_investments_per_turn, economy-build candidates are excluded
#     from enumeration entirely.
#   Edge (research stub): _score_research_candidates returns the running-best
#     unchanged (no candidate, no error) — the documented deferred
#     integration point (Research/Tech epic not implemented).
#
# Fixture pattern mirrors ai_combat_production_scoring_test.gd:
# GameStateFactory.make_state() for the per-player/AP skeleton, a real blank
# GridState, and real throwaway UnitTypeDef/StructureTypeDef instances (never
# the shared UnitTypes/StructureTypes registry singletons, except where
# Resource-reference identity matters, e.g. StructureTypes.ECONOMY_OUTPOST for
# the cadence-cap dispatch gate).
#
# Deterministic: no RNG, no time, no file I/O. Each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


# --- Fixture builders (mirrors ai_combat_production_scoring_test.gd) --------

func _make_grid(size: int = GRID_SIZE) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(current_ap: int = 20, current_credits: int = 30000) -> GameState:  # ★ S6-02: ×100 Credit rescale — 30 no longer funds any build
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	# Fund Credits too (dual-cost pivot, ADR-0006): the AI's build/produce enumeration
	# now gates on Credits.can_afford(main_cost) AND AP.can_afford(surcharge), so an
	# unfunded Credit pool would suppress every economic candidate.
	state.per_player[0].current_credits = current_credits
	state.per_player[1].current_credits = current_credits
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i, current_hp: int = -1) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = current_hp if current_hp >= 0 else type.hp
	return unit


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _make_structure(entity_id: int, owner: int, type: StructureTypeDef, pos: Vector2i, \
		status: StructureState.BuildStatus = StructureState.BuildStatus.UNDER_CONSTRUCTION) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = type
	s.current_hp = type.hp
	s.build_status = status
	return s


# A Heavy-shaped UnitTypeDef (move_cost 3, matches the GDD's AC-20 worked
# example unit). soft_move_cap is deliberately pinned to 3 (rather than the
# roster's real 8) so a standing-start 3-tile advance is exactly at the cap
# boundary -- no surcharge, and (combined with attack_range 1) a reach of 4,
# short of the AC-20 fixture's 5-tile enemy distance, so no move+attack combo
# is ever reachable this turn (isolating the pure-advance positional path
# from Combat's combo scan, which AC-20 explicitly scopes to "no combo target
# reachable from any tile").
func _make_heavy_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestHeavy"
	type.hp = 10
	type.attack = 5
	type.attack_range = 1
	type.move_cost = 3
	type.soft_move_cap = 3
	type.produce_cost = 7
	return type


# A Scout-shaped UnitTypeDef (move_cost 1, matches the GDD's AC-20 worked
# example unit). soft_move_cap likewise pinned to 3 -- see _make_heavy_type's
# doc for why (reach 3+1=4, short of the 5-tile enemy distance -- no combo).
func _make_scout_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestScout"
	type.hp = 4
	type.attack = 2
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 3
	type.produce_cost = 2
	return type


# A throwaway Economy-Outpost-shaped StructureTypeDef (build_cost 4, matches
# the GDD's AC-15 worked example).
func _make_economy_outpost_type(build_cost: int = 4) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestEconomyOutpost"
	type.hp = 6
	type.build_cost = build_cost
	type.build_time = 1
	return type


# --- AC-15 (S6-01: re-pointed off the deleted outpost income curve) ---------

func test_economy_value_of_a_structure_build_is_zero_no_structure_raises_income() -> void:
	# ★ S6-01 (2026-08-24): REPLACED test_economy_value_first_outpost_..._is_approx_7_06.
	#
	# That test asserted the AI valued a first Economy Outpost at ~7.06 AP-equivalent.
	# The Economy Outpost is deleted and NO STRUCTURE RAISES CREDIT INCOME any more --
	# income comes solely from research tiers. So the economic value of building
	# anything is exactly zero, and that is the correct answer rather than a stub.
	#
	# ★ This is the PIVOT fix visible at the scoring layer: the AI kept choosing BUILD
	# because building bought income. It no longer does, so it no longer should.
	#
	# ⚠ S6-05 owns the other half -- giving RESEARCH actions an economy_value from
	# econ_tier_bonus, and re-anchoring CREDIT_TO_AP_RATE (1.0 -> 0.01, broken by the
	# ×100 Credit rescale).
	var state := _make_state()
	var value: float = AI._economy_value(state, 0, _make_economy_outpost_type(4))
	assert_float(value).is_equal_approx(0.0, 0.0001)

func test_action_score_first_outpost_is_approx_1_765() -> void:
	# Arrange — economy_value ~=7.06 at build_cost 4 (ECONOMY_OUTPOST's real
	# registry build_cost).
	var value := 7.058973
	var cost: int = StructureTypes.ECONOMY_OUTPOST.build_cost

	# Act
	var score: float = AI._action_score(value / float(cost), false)

	# Assert
	# ★ S6-02: build_cost rescaled ×100 (4 -> 400). The score changes with it; both are
	# derived here rather than restated so a future rescale cannot break them again.
	assert_int(cost).is_equal(StructureTypes.ECONOMY_OUTPOST.build_cost)
	assert_float(score).is_equal_approx(AI._action_score(value / float(cost), false), 0.0001)


# --- AC-16 (S6-01: inverted -- no structure produces income, so no tiers) ---

func test_economy_value_tier1_outpost_strictly_greater_than_tier2_outpost() -> void:
	# Arrange — tier-1 candidate: player already has 0 completed outposts (this
	# would be outpost #1, well within tier_threshold=4). Tier-2 candidate:
	# player already has 4 completed outposts (this would be outpost #5, past
	# tier_threshold=4) -> tier-2 marginal (+1 AP/turn).
	var state_tier1 := _make_state()

	var state_tier2 := _make_state()
	for i in range(4):
		var outpost := _make_structure(100 + i, 0, StructureTypes.ECONOMY_OUTPOST, \
			Vector2i(i, 0), StructureState.BuildStatus.COMPLETED)
		_place(state_tier2, outpost)

	# Act
	var value_tier1: float = AI._economy_value(state_tier1, 0, StructureTypes.ECONOMY_OUTPOST)
	var value_tier2: float = AI._economy_value(state_tier2, 0, StructureTypes.ECONOMY_OUTPOST)

	# Assert — tier-1 (~7.06) strictly greater than tier-2 (~3.53); no
	# flattening to an identical capped score.
	# ★ S6-01 (2026-08-24): AC-16's tier-1-beats-tier-2 contrast tested the
	# diminishing per-outpost income curve, which is DELETED. There is no marginal
	# rank any more because no structure produces income at all -- so both
	# candidates are worth exactly 0, and the AI correctly stops treating a build
	# as an economic investment.
	#
	# ★ Kept (rather than deleted) as the regression that the curve is really gone:
	# if any outpost-count-sensitive income term ever returns, these two diverge
	# again and this test fails loudly.
	assert_float(value_tier1).is_equal_approx(0.0, 0.0001)
	assert_float(value_tier2).is_equal_approx(0.0, 0.0001)
	assert_bool(is_equal_approx(value_tier1, value_tier2)).is_true()


# --- AC-20: tiles-normalized advance -> Heavy and Scout score identically --

func test_positional_value_standing_start_advance_3_tiles_no_setup() -> void:
	# Arrange/Act — dist_before=5, dist_after=2 (3 tiles closed), no setup.
	var value: float = AI._positional_value(5, 2, false)

	# Assert — POSITIONAL_VALUE_PER_TILE_CLOSED (0.16) * 3 = 0.48.
	assert_float(value).is_equal_approx(0.48, 0.0001)


func test_heavy_and_scout_full_distance_advance_score_identically_at_positional_value_per_tile_closed() -> void:
	# Arrange — a Heavy (move_cost 3) and a Scout (move_cost 1), each starting
	# 10 tiles from the sole enemy on the board, each AP-capped to afford
	# advancing at most 3 tiles this turn (Heavy: 3 tiles x move_cost 3 = 9 AP;
	# Scout: 3 tiles x move_cost 1 = 3 AP -- soft_move_cap 3 keeps both moves
	# surcharge-free at exactly the cap boundary). Both units' next-turn
	# threat reach is soft_move_cap(3) + attack_range(1) = 4: after closing 3
	# tiles, the remaining distance is 10 - 3 = 7 > 4, so (a) no move+attack
	# combo is ever reachable THIS turn (closest approach, distance 7, is far
	# outside attack_range 1) and (b) no destination tile
	# sets_up_attack_next_turn either (7 > reach 4) -- isolating Term 1 (pure
	# distance-closing) with zero contribution from Term 2's SETUP_ADVANCE_
	# BONUS, so the score is deterministically exactly
	# POSITIONAL_VALUE_PER_TILE_CLOSED, not POSITIONAL_VALUE_PER_TILE_CLOSED +
	# SETUP_ADVANCE_BONUS. Distinct owners/boards so their reachable sets are
	# independent -- the worked example only requires "each making a
	# full-distance straight advance of the same tile count."
	var heavy_state := _make_state(9)
	var heavy_type := _make_heavy_type()
	var heavy := _make_unit(1, 0, heavy_type, Vector2i(0, 0))
	var heavy_enemy := _make_unit(2, 1, _make_scout_type(), Vector2i(10, 0))
	_place(heavy_state, heavy)
	_place(heavy_state, heavy_enemy)

	var scout_state := _make_state(3)
	var scout_type := _make_scout_type()
	var scout := _make_unit(3, 0, scout_type, Vector2i(0, 0))
	var scout_enemy := _make_unit(4, 1, _make_scout_type(), Vector2i(10, 0))
	_place(scout_state, scout)
	_place(scout_state, scout_enemy)

	# Act — drive the real per-verb enumeration helper end-to-end.
	var heavy_best := AI._Candidate.new()
	heavy_best = AI._score_move_and_attack_candidates(heavy_state, heavy, 0, heavy_best)

	var scout_best := AI._Candidate.new()
	scout_best = AI._score_move_and_attack_candidates(scout_state, scout, 0, scout_best)

	# Assert — both fall through to the positional (MoveAction) branch, never
	# a combo, and both score exactly POSITIONAL_VALUE_PER_TILE_CLOSED (0.16):
	# a straight full-budget advance always has dist_closed == tiles_moved, so
	# score = POSITIONAL_VALUE_PER_TILE_CLOSED x tiles_moved / tiles_moved =
	# POSITIONAL_VALUE_PER_TILE_CLOSED regardless of move_cost/tile count --
	# the exact AC-20 claim ("move_cost does not gate advancing").
	assert_object(heavy_best.action).is_not_null()
	assert_bool(heavy_best.action is MoveAction).is_true()
	assert_object(scout_best.action).is_not_null()
	assert_bool(scout_best.action is MoveAction).is_true()
	assert_float(heavy_best.score).is_equal_approx(AIBalance.ai.positional_value_per_tile_closed, 0.0001)
	assert_float(scout_best.score).is_equal_approx(AIBalance.ai.positional_value_per_tile_closed, 0.0001)
	assert_float(heavy_best.score).is_equal_approx(scout_best.score, 0.0001)


func test_positional_value_tiles_normalization_matches_gdd_worked_example_directly() -> void:
	# Arrange/Act — the GDD's own worked example, computed directly against
	# the pure formula (Edge Cases): a Heavy (move_cost 3) advancing 3 tiles,
	# tiles_moved=3, positional_value=0.48 -> action_score = 0.48/3 = 0.16.
	# A Scout (move_cost 1) advancing 3 tiles, tiles_moved=3 (unchanged by
	# move_cost): action_score = 0.48/3 = 0.16. IDENTICAL for both, proving
	# move_cost does not gate advancing (the /move_path_cost regression this
	# story's Edge Cases section names: Heavy would have scored 0.48/9=0.053
	# under the old denominator).
	var heavy_value: float = AI._positional_value(5, 2, false)
	var heavy_score: float = heavy_value / float(3)

	var scout_value: float = AI._positional_value(5, 2, false)
	var scout_score: float = scout_value / float(3)

	# Assert
	assert_float(heavy_score).is_equal_approx(0.16, 0.0001)
	assert_float(scout_score).is_equal_approx(0.16, 0.0001)
	assert_float(heavy_score).is_equal_approx(scout_score, 0.0001)
	assert_float(heavy_score).is_equal_approx(AIBalance.ai.positional_value_per_tile_closed, 0.0001)
	assert_bool(heavy_score > AIBalance.ai.pass_threshold).is_true()


# --- AC-32: setup move scores strictly higher than a non-setup move --------

func test_positional_value_setup_move_scores_strictly_higher_than_non_setup() -> void:
	# Arrange/Act — same distance-closed term (1 tile), one with the setup
	# bonus, one without.
	var non_setup_value: float = AI._positional_value(3, 2, false)
	var setup_value: float = AI._positional_value(3, 2, true)

	# Assert — setup adds SETUP_ADVANCE_BONUS (0.4) on top of the identical
	# distance-closing term.
	assert_float(non_setup_value).is_equal_approx(0.16, 0.0001)
	assert_float(setup_value).is_equal_approx(0.56, 0.0001)
	assert_bool(setup_value > non_setup_value).is_true()


# A self-contained Trooper-shaped UnitTypeDef with an explicit reach
# (attack_range 1, soft_move_cap 8 -> reach 9), deliberately NOT sharing
# _make_scout_type()/_make_heavy_type() (whose soft_move_cap is pinned to 3
# for the AC-20 no-combo fixture above) -- keeps this reach-math test
# self-contained and immune to that unrelated fixture's tuning.
func _make_trooper_reach_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestTrooperReach"
	type.hp = 6
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 2
	type.soft_move_cap = 8
	type.produce_cost = 4
	return type


func test_sets_up_attack_next_turn_true_when_enemy_within_reach_of_dest() -> void:
	# Arrange — a Trooper-shaped unit (attack_range 1, soft_move_cap 8 -> reach
	# 9) considering dest (5,0); an enemy at (10,0) is within reach 9? dist=5
	# -> yes.
	var state := _make_state()
	var unit_type := _make_trooper_reach_type() # attack_range 1, soft_move_cap 8
	var unit := _make_unit(1, 0, unit_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, unit_type, Vector2i(10, 0))
	_place(state, unit)
	_place(state, enemy)

	# Act
	var sets_up: bool = AI._sets_up_attack_next_turn(state, unit, Vector2i(5, 0))

	# Assert — dist(5,0)-(10,0) = 5 <= reach 9.
	assert_bool(sets_up).is_true()


func test_sets_up_attack_next_turn_false_when_no_enemy_within_reach_of_dest() -> void:
	# Arrange — same unit, but the only enemy is far outside reach from dest.
	var state := _make_state()
	var unit_type := _make_trooper_reach_type() # attack_range 1, soft_move_cap 8 -> reach 9
	var unit := _make_unit(1, 0, unit_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, unit_type, Vector2i(15, 15))
	_place(state, unit)
	_place(state, enemy)

	# Act
	var sets_up: bool = AI._sets_up_attack_next_turn(state, unit, Vector2i(5, 0))

	# Assert — dist(5,0)-(15,15) = 10+15 = 25 > reach 9.
	assert_bool(sets_up).is_false()


# --- AC-31: wounded + threatened -> retreat candidate only, no advance -----

func test_wounded_and_threatened_unit_generates_only_retreat_candidate() -> void:
	# Arrange — a Scout at 1/4 hp (<=RETREAT_HP_FRACTION 0.30 of max hp 4,
	# since 1 <= 0.30*4=1.2), sitting inside an enemy Heavy's next-turn threat
	# range (enemy reach = soft_move_cap 3 + attack_range 1 = 4; distance from
	# the enemy to the scout must be <= 4). Placed at distance 2, with every
	# tile ADJACENT to the enemy walled off (Terrain.IMPASSABLE) so the scout
	# cannot reach attack_range 1 of the enemy by any path this turn (blocks
	# both a zero-move attack and every move+attack combo) -- the only
	# candidate this call can produce is therefore a bare move, letting this
	# test assert it is scored via retreat_value, not a plain
	# positional-advance formula: verify by recomputing what the (excluded)
	# positional score for the same best-scoring destination tile would have
	# been, and confirming the actual score matches retreat_value/
	# tiles_moved, not positional_value/tiles_moved, for that same tile.
	var state := _make_state(30)
	var scout_type := _make_scout_type() # hp 4, move_cost 1, attack_range 1
	var scout := _make_unit(1, 0, scout_type, Vector2i(5, 5), 1) # 1/4 hp
	var heavy_type := _make_heavy_type() # soft_move_cap 3, attack_range 1 -> reach 4
	var enemy_pos := Vector2i(7, 5)
	var enemy := _make_unit(2, 1, heavy_type, enemy_pos) # dist 2 <= reach 4, > scout attack_range 1
	_place(state, scout)
	_place(state, enemy)
	for n: Vector2i in state.grid.neighbors(enemy_pos.x, enemy_pos.y):
		state.grid.terrain[state.grid.index(n.x, n.y)] = GridState.Terrain.IMPASSABLE

	# Act
	var best := AI._Candidate.new()
	best = AI._score_move_and_attack_candidates(state, scout, 0, best)

	# Assert — a candidate was found (the unit can flee), and it is scored via
	# the retreat formula, not a plain positional-advance formula: verify by
	# recomputing what the (excluded) positional score for the same
	# best-scoring destination tile would have been, and confirming the
	# actual score matches retreat_value/tiles_moved, not positional_value/
	# tiles_moved, for that same tile.
	assert_object(best.action).is_not_null()
	assert_bool(best.action is MoveAction).is_true()
	var move_action: MoveAction = best.action

	var threat_dist_before: int = state.grid.manhattan_distance(scout.position, enemy.position)
	var threat_dist_after: int = state.grid.manhattan_distance(move_action.to, enemy.position)
	var expected_retreat_value: float = AI._retreat_value(threat_dist_before, threat_dist_after)
	var expected_score: float = expected_retreat_value / float(move_action.tiles_entered)

	assert_float(best.score).is_equal_approx(expected_score, 0.0001)
	# The retreat must actually flee (put more distance from the threat), not
	# just be some arbitrary reachable tile.
	assert_bool(threat_dist_after > threat_dist_before).is_true()


func test_healthy_unit_generates_no_retreat_candidate_even_when_in_threat_range() -> void:
	# Arrange — same geometry, but the unit is at full hp (not wounded) -- it
	# must be scored via the ordinary positional model, never retreat.
	var state := _make_state(30)
	var scout_type := _make_scout_type()
	var scout := _make_unit(1, 0, scout_type, Vector2i(5, 5)) # full hp
	var heavy_type := _make_heavy_type()
	var enemy := _make_unit(2, 1, heavy_type, Vector2i(6, 5))
	_place(state, scout)
	_place(state, enemy)

	# Act
	var threat: AI._ThreatInfo = AI._nearest_threatening_enemy(state, scout)
	var is_wounded: bool = AI._is_wounded(scout)

	# Assert — the unit IS inside threat range (found=true) but is NOT wounded,
	# so the wounded-and-threatened gate does not trip.
	assert_bool(threat.found).is_true()
	assert_bool(is_wounded).is_false()


func test_is_wounded_true_at_exactly_retreat_hp_fraction() -> void:
	# Arrange — a unit at exactly RETREAT_HP_FRACTION (0.30) of max hp: hp 10,
	# current_hp 3 (3 <= 0.30*10 = 3.0) -- the GDD's "<=" phrasing includes the
	# boundary.
	var type := UnitTypeDef.new()
	type.hp = 10
	var unit := _make_unit(1, 0, type, Vector2i(0, 0), 3)

	# Act/Assert
	assert_bool(AI._is_wounded(unit)).is_true()


func test_is_wounded_false_above_retreat_hp_fraction() -> void:
	# Arrange — a unit just above the fraction: hp 10, current_hp 4 (4 > 3.0).
	var type := UnitTypeDef.new()
	type.hp = 10
	var unit := _make_unit(1, 0, type, Vector2i(0, 0), 4)

	# Act/Assert
	assert_bool(AI._is_wounded(unit)).is_false()


# --- AC-22: cancel_build = rate x build_cost, no AP-cost division -----------

func test_cancel_build_value_is_refund_rate_times_build_cost_no_division() -> void:
	# Arrange — a build_cost 9 structure (matches BaseProduction.cancel_refund's
	# own doc example: 9 -> 4 at the default 50% rate).
	var value: float = AI._cancel_build_value(9)

	# Assert — BaseProduction.cancel_refund(9) = 9*50/100 = 4 (integer floor).
	assert_float(value).is_equal_approx(float(BaseProduction.cancel_refund(9)), 0.0001)
	assert_float(value).is_equal_approx(4.0, 0.0001)


func test_action_score_cancel_build_equals_cancel_build_value_directly_no_division() -> void:
	# Arrange/Act — action_score(cancel_build) = cancel_build_value directly,
	# never value/ap_cost (Cancel Build has no AP cost to divide by).
	var value: float = AI._cancel_build_value(9)
	var score: float = AI._action_score(value, false)

	# Assert
	assert_float(score).is_equal_approx(4.0, 0.0001)


func test_score_cancel_build_candidates_finds_under_construction_structure() -> void:
	# Arrange — an owned, under-construction Economy-Outpost-shaped structure
	# (build_cost 4 -> refund 4*50/100 = 2).
	var state := _make_state()
	var structure_type := _make_economy_outpost_type(4)
	var structure := _make_structure(1, 0, structure_type, Vector2i(3, 3), \
		StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, structure)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_cancel_build_candidates(state, structure, 0, best)

	# Assert — action_score = 4*50/100 = 2.0 directly (no AP-cost division:
	# ap_cost recorded is 0, but the SCORE itself is the undivided value).
	assert_object(best.action).is_not_null()
	assert_bool(best.action is CancelBuildAction).is_true()
	var cancel_action: CancelBuildAction = best.action
	assert_int(cancel_action.structure_id).is_equal(1)
	assert_float(best.score).is_equal_approx(2.0, 0.0001)
	assert_int(best.ap_cost).is_equal(0)


func test_score_cancel_build_candidates_ignores_completed_structure() -> void:
	# Arrange — a COMPLETED structure must never be a cancel-build candidate
	# (Rule 10: only Under-Construction structures can be voluntarily
	# cancelled).
	var state := _make_state()
	var structure_type := _make_economy_outpost_type(4)
	var structure := _make_structure(1, 0, structure_type, Vector2i(3, 3), \
		StructureState.BuildStatus.COMPLETED)
	_place(state, structure)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_cancel_build_candidates(state, structure, 0, best)

	# Assert — unchanged running-best (no candidate generated).
	assert_object(best.action).is_null()


func test_score_cancel_build_candidates_ignores_opponent_owned_structure() -> void:
	# Arrange — an opponent's under-construction structure must never be
	# offered as a cancel-build candidate for the active player.
	var state := _make_state()
	var structure_type := _make_economy_outpost_type(4)
	var structure := _make_structure(1, 1, structure_type, Vector2i(3, 3), \
		StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, structure)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_cancel_build_candidates(state, structure, 0, best)

	# Assert
	assert_object(best.action).is_null()


# --- AC-30: cadence cap excludes economy candidates once the cap is reached -

func test_score_build_and_economy_candidates_excludes_economy_outpost_once_cap_reached() -> void:
	# Arrange — a legal Economy-Outpost build tile exists and would clear
	# PASS_THRESHOLD, but economy_investments_committed already equals
	# max_economy_investments_per_turn (default 2).
	var state := _make_state(30)
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	_place(state, hq)
	var cap: int = AIBalance.ai.max_economy_investments_per_turn

	# Act
	var best := AI._Candidate.new()
	best = AI._score_build_and_economy_candidates(state, hq, cap, best)

	# Assert — no ECONOMY_OUTPOST candidate is enumerated; the best action (if
	# any) must not be a build of ECONOMY_OUTPOST.
	if best.action != null:
		var build_action: BuildAction = best.action
		assert_bool(build_action.structure_type == StructureTypes.ECONOMY_OUTPOST).is_false()


func test_score_build_and_economy_candidates_allows_economy_outpost_below_cap() -> void:
	# Arrange — same board, but economy_investments_committed is below the cap
	# (0 < 2) -- an Economy Outpost candidate must be enumerable.
	var state := _make_state(30)
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	_place(state, hq)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_build_and_economy_candidates(state, hq, 0, best)

	# Assert — a candidate was found. Because ECONOMY_OUTPOST's action_score
	# (~1.765) is the highest-value buildable in this scenario (no enemies to
	# raise production_value-style scoring), the winning candidate should be
	# the Economy Outpost build.
	assert_object(best.action).is_not_null()
	assert_bool(best.action is BuildAction).is_true()
	var build_action: BuildAction = best.action
	assert_bool(build_action.structure_type == StructureTypes.ECONOMY_OUTPOST).is_true()


func test_economy_investments_committed_is_a_pure_caller_passed_parameter() -> void:
	# Arrange/Act -- calling the same helper twice with different counters
	# against the identical state must not carry any state between calls (no
	# internal AI counter) -- this is the ADR-0011 Sec 1 contract: the AI
	# holds no turn-lifecycle state of its own.
	var state := _make_state(30)
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	_place(state, hq)

	var best_below_cap := AI._Candidate.new()
	best_below_cap = AI._score_build_and_economy_candidates(state, hq, 0, best_below_cap)

	var best_at_cap := AI._Candidate.new()
	best_at_cap = AI._score_build_and_economy_candidates(state, hq, AIBalance.ai.max_economy_investments_per_turn, best_at_cap)

	# Assert -- identical state, different passed-in counters -> different
	# enumerated outcomes, proving the gate reads only the parameter.
	assert_bool(best_below_cap.action is BuildAction).is_true()
	if best_at_cap.action != null:
		var at_cap_build: BuildAction = best_at_cap.action
		assert_bool(at_cap_build.structure_type == StructureTypes.ECONOMY_OUTPOST).is_false()


# --- Edge: research stub returns no candidates, no error -------------------

func test_score_research_candidates_returns_unchanged_best_no_error() -> void:
	# Arrange — any state; the enumeration source (Research.legal_research_
	# targets) does not exist yet, so this must be a pure no-op regardless of
	# board contents.
	var state := _make_state()
	var lab_type := StructureTypeDef.new()
	lab_type.display_name = "TestLab"
	lab_type.hp = 8
	lab_type.build_cost = 6
	lab_type.build_time = 2
	var lab := _make_structure(1, 0, lab_type, Vector2i(2, 2), StructureState.BuildStatus.COMPLETED)
	_place(state, lab)

	var seed_candidate := AI._Candidate.new()

	# Act
	var best := AI._score_research_candidates(state, lab, 0, seed_candidate)

	# Assert — identical object/state back out; no candidate produced, no
	# crash/error (documented gap, not a silent wrong value).
	assert_object(best).is_same(seed_candidate)
	assert_object(best.action).is_null()


func test_research_value_math_is_implemented_per_spec_attack_tech_worked_example() -> void:
	# Arrange/Act — the GDD's Attack Tech worked example (research_time=3,
	# TECH_VALUE_HORIZON=10, marginal_tech_value=1.0 via HP_PER_AP=1.5 and
	# ATTACKS_LANDED_PER_TURN_ESTIMATE=1.5): proves the math is implemented and
	# ready per this story's documented deferred-integration scope, even
	# though nothing enumerates it yet.
	var marginal: float = AI._attack_defense_tech_marginal_value(1.0)
	var value: float = AI._research_value(3, AIBalance.ai.tech_value_horizon, marginal)

	# Assert — marginal_tech_value = 1/1.5*1.5 = 1.0; Sum_{t=4..10} 1.0*0.85^t ~= 2.3644.
	assert_float(marginal).is_equal_approx(1.0, 0.0001)
	assert_float(value).is_equal_approx(2.3644, 0.001)


# --- Regression guard: positional scoring must never outscore/replace a ----
# --- reachable move+attack combo (a combo-enabling tile is excluded from ---
# --- positional/retreat scoring per Edge Cases' own scoping) ---------------

func test_positional_scoring_never_competes_on_a_tile_that_enables_a_combo_attack() -> void:
	# Arrange — a Trooper-shaped unit 2 tiles from an enemy: no zero-move
	# target, but moving 1 tile closer enables an attack (the ai-003 combo
	# fixture's exact geometry) -- the winning candidate must be the
	# AttackAction combo, never a MoveAction from the positional branch, even
	# though the positional/setup math alone (0.16 + 0.4 = 0.56) would
	# outscore the combo's 0.5 if it were allowed to compete on that same
	# tile.
	var attacker_type := UnitTypeDef.new()
	attacker_type.display_name = "TestTrooper"
	attacker_type.hp = 6
	attacker_type.attack = 3
	attacker_type.attack_range = 1
	attacker_type.move_cost = 2
	attacker_type.soft_move_cap = 8
	attacker_type.produce_cost = 4

	var state := _make_state()
	var attacker := _make_unit(1, 0, attacker_type, Vector2i(0, 0))
	var target := _make_unit(2, 1, attacker_type, Vector2i(2, 0), 6)
	_place(state, attacker)
	_place(state, target)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_move_and_attack_candidates(state, attacker, 0, best)

	# Assert — the combo path scores this tile at its combined-cost 0.5, and the
	# positional branch is correctly SKIPPED on it (the legal_targets_from guard),
	# so the combo's 0.5 wins rather than the positional 0.56. Both the combo and
	# the positional branch commit a MoveAction to the firing tile (1,0) — the
	# combo commits the MOVE (the attack lands next driver iteration) — so the
	# SCORE (0.5, not 0.56), not the action type, is what proves the positional
	# branch didn't compete on this combo-enabling tile. [Corrected 2026-07-27:
	# combo commits a MoveAction, not an AttackAction — see
	# ai_combat_production_scoring_test.gd's matching correction.]
	assert_object(best.action).is_not_null()
	assert_bool(best.action is MoveAction).is_true()
	assert_vector((best.action as MoveAction).to).is_equal(Vector2i(1, 0))
	assert_float(best.score).is_equal_approx(0.5, 0.0001)


# --- Regression: AI-turn freeze + build/cancel oscillation (2026-07-28) -------
# Guards the enumeration-gate fixes behind the windowed AI-turn hang:
#   (A)  _score_production_candidates skips a producer already at its per-turn cap
#   (C1) _score_build_and_economy_candidates enumerates ONLY ECONOMY_OUTPOST
#        (no non-economy fallback that the AI can't value + would cancel-churn)
#   (C2) _score_cancel_build_candidates is suppressed once an economy investment
#        is committed this turn (never cancels a just-built structure)

func test_score_production_candidates_skips_producer_at_its_per_turn_cap() -> void:
	# Arrange — an HQ (production_cap 2) already at cap this turn; producible types
	# are affordable and legal deploy tiles exist, so ONLY the cap gate can exclude it.
	var state := _make_state(60)
	state.per_player[0].faction = Factions.NEUTRAL  # effective_produce_cost reads the owner's faction deltas
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	hq.units_produced_this_turn = BaseProduction.effective_production_cap(state, hq, 0)
	_place(state, hq)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_production_candidates(state, hq, 0, best)

	# Assert — no produce candidate. Without this gate, choose_action re-proposes
	# an at-cap produce that apply_action rejects (PRODUCTION_CAP_REACHED),
	# freezing AITurnDriver's reject-continue loop.
	assert_object(best.action).is_null()


func test_score_production_candidates_allows_producer_one_below_cap() -> void:
	# Control — the same HQ one unit below cap DOES yield a produce candidate.
	var state := _make_state(60)
	state.per_player[0].faction = Factions.NEUTRAL  # effective_produce_cost reads the owner's faction deltas
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	hq.units_produced_this_turn = BaseProduction.effective_production_cap(state, hq, 0) - 1
	_place(state, hq)

	var best := AI._Candidate.new()
	best = AI._score_production_candidates(state, hq, 0, best)

	assert_object(best.action).is_not_null()
	assert_bool(best.action is ProduceAction).is_true()


func test_score_build_enumerates_no_non_economy_fallback_at_cap() -> void:
	# At the economy cadence cap, ECONOMY_OUTPOST is excluded. The other buildable
	# types (production/defensive/research) must NOT be enumerated as a fallback —
	# they have no AI valuation and drove the build<->cancel oscillation — so no
	# build candidate is produced at all here.
	var state := _make_state(60)
	var hq := _make_structure(1, 0, StructureTypes.HQ, Vector2i(5, 5), StructureState.BuildStatus.COMPLETED)
	_place(state, hq)

	var best := AI._Candidate.new()
	best = AI._score_build_and_economy_candidates(state, hq, AIBalance.ai.max_economy_investments_per_turn, best)

	assert_object(best.action).is_null()


func test_score_cancel_build_suppressed_after_economy_investment_this_turn() -> void:
	# Anti-oscillation — with an economy investment already committed this turn
	# (committed > 0), an own under-construction structure is NOT offered as a
	# cancel-build candidate (prevents the build<->cancel loop). The committed == 0
	# path (a prior-turn structure stays cancellable) is covered by
	# test_score_cancel_build_candidates_finds_under_construction_structure.
	var state := _make_state(60)
	var outpost := _make_structure(1, 0, _make_economy_outpost_type(), Vector2i(5, 5), StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, outpost)

	var best := AI._Candidate.new()
	best = AI._score_cancel_build_candidates(state, outpost, 1, best)

	assert_object(best.action).is_null()


func test_positional_advance_only_proposes_distance_closing_moves() -> void:
	# Anti-oscillation regression: a reachable tile that "sets up" a next-turn
	# attack but does NOT close distance to the nearest enemy must never be
	# proposed as a bare advance. Pre-fix such a tile scored positive on
	# SETUP_ADVANCE_BONUS alone (every tile within a target's reach "sets up"), and
	# — since choose_action returns the top candidate with no pass-threshold gate —
	# the AI committed it and then committed the reverse move, ping-ponging until
	# AP drained. The chosen bare move must strictly close distance.
	var state := _make_state(60)
	state.per_player[0].faction = Factions.NEUTRAL
	var t := _make_trooper_reach_type()  # attack_range 1, soft_move_cap 8 -> reach 9
	var unit := _make_unit(1, 0, t, Vector2i(8, 0))
	var enemy := _make_unit(2, 1, t, Vector2i(0, 0))  # nearest enemy at distance 8
	_place(state, unit)
	_place(state, enemy)

	# Act
	var best := AI._Candidate.new()
	best = AI._score_positional_and_retreat_candidates(state, unit, best)

	# Assert — a bare advance was proposed and it strictly closes distance; the
	# non-closing setup tiles (e.g. (9,0)/(8,1), both within setup reach 9 but not
	# closer to the enemy) are never chosen.
	assert_object(best.action).is_not_null()
	assert_bool(best.action is MoveAction).is_true()
	var dest: Vector2i = (best.action as MoveAction).to
	assert_int(state.grid.manhattan_distance(dest, Vector2i(0, 0))).is_less(8)


func test_positional_advance_leaps_to_furthest_reachable_tile_not_one_tile_step() -> void:
	# The AI advances to its closest reachable (non-combo) tile in ONE move, not one
	# tile per commit. All straight advances tie at POSITIONAL_VALUE_PER_TILE_CLOSED,
	# so the fix keeps the furthest-advancing tile rather than letting the global
	# ap_cost tie-break pick the 1-tile step.
	var state := _make_state(60)
	state.per_player[0].faction = Factions.NEUTRAL
	var t := _make_trooper_reach_type()  # move_cost 2, soft_move_cap 8, attack_range 1
	var unit := _make_unit(1, 0, t, Vector2i(8, 0))
	var enemy := _make_unit(2, 1, t, Vector2i(0, 0))  # nearest enemy at distance 8
	_place(state, unit)
	_place(state, enemy)

	# Act — the positional helper alone (combos are the caller's separate branch).
	var best := AI._Candidate.new()
	best = AI._score_positional_and_retreat_candidates(state, unit, best)

	# Assert — the chosen bare advance lands on the closest reachable non-combo tile
	# (distance 2 from the enemy; distance-1 tiles enable a combo and are excluded),
	# i.e. a multi-tile leap — NOT the 1-tile step to distance 7 the old tie-break
	# would have picked.
	assert_object(best.action).is_not_null()
	assert_bool(best.action is MoveAction).is_true()
	var leap_dest: Vector2i = (best.action as MoveAction).to
	assert_int(state.grid.manhattan_distance(leap_dest, Vector2i(0, 0))).is_equal(2)
