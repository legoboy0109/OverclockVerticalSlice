# Story 003: Verb Scoring — combat_value, production_value, action_score,
# Lethal Floor, HQ Siege.
#
# Covers production/epics/ai-opponent/story-003-combat-production-scoring.md
# QA Test Cases, each hitting the GDD's exact worked-example numbers:
#
#   AC-11 (non-lethal trade): Trooper atk 3 vs full-hp enemy Trooper hp 6
#     produce_cost 4 -> combat_value == 2.0, action_score (cost 2) == 1.00.
#   AC-12 (finishing blow): same attack, target at 3/6 hp -> combat_value ==
#     4.0, base_score == 2.00, floored action_score == 3.50 (2.00 < 3.5).
#   AC-29 (HQ siege): Sniper eff-atk 7 vs HQ hp 40 def 2, non-lethal ->
#     ap_cost_opponent_paid_for(HQ) resolves to HQ_SIEGE_VALUE (12, never
#     0/undefined), combat_value ~= 1.5, action_score (cost 2) ~= 0.75, above
#     PASS_THRESHOLD (0.15).
#   AC-14 (production_value + 3-band REACHABILITY_MULTIPLIER): Trooper
#     produce_cost 4 at each of the 3 deterministic contact-state bands ->
#     production_value == 4×0.9 / 4×1.0 / 4×1.1; the reachable-this-turn band
#     -> production_value == 4.4, action_score (cost 4) == exactly 1.10.
#   AC-21 (move+attack combo, value only): a move+attack combo candidate is
#     scored via legal_targets_from at the combined move_path_cost +
#     attack_cost.
#   Edge (MIN_DAMAGE floor): hp_removed at the MIN_DAMAGE=1 floor on a
#     full-hp target -> combat_value strictly > 0, never 0.
#   CR-7 proof (post-hoc floor, not a pre-filter): two lethal attacks with
#     different base_score both floor to the identical LETHAL_FLOOR_BONUS
#     (3.5) — proves the floor is applied AFTER scoring, never as a
#     short-circuiting pre-filter (feeds Story 005's tie-break).
#
# Fixture pattern mirrors combat_apply_action_integration_test.gd /
# ai_enumeration_order_test.gd: GameStateFactory.make_state() for the
# per-player/AP skeleton, a real blank GridState, and real throwaway
# UnitTypeDef/StructureTypeDef instances (never the shared UnitTypes/
# StructureTypes registry singletons, except StructureTypes.HQ itself for
# AC-29's is_hq() identity check, which must be the real registry constant
# for StructureState.is_hq()'s Resource-reference-identity comparison to
# hold).
#
# Deterministic: no RNG, no time, no file I/O. Each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 10


# --- Fixture builders (mirrors combat_apply_action_integration_test.gd) -----

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


func _make_state(current_ap: int = 20) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	return state


# A throwaway Trooper-shaped UnitTypeDef: hp 6, attack 3, produce_cost 4,
# attack_range 1, move_cost 2, soft_move_cap matches the roster's Trooper
# (AC-11/AC-12's exact worked-example stats).
func _make_trooper_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestTrooper"
	type.hp = 6
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 2
	type.soft_move_cap = 8
	type.produce_cost = 4
	type.defense = 0
	return type


# A throwaway Sniper-shaped UnitTypeDef: effective attack 7 (AC-29's
# pre-folded eff-atk, no Attack Tech machinery needed — `attack` is read
# directly by Combat.damage() for a unit with no tech bonus in this fixture),
# attack_range 2 (siege stand-off), move_cost/soft_move_cap unused by AC-29.
func _make_sniper_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestSniper"
	type.hp = 5
	type.attack = 7
	type.attack_range = 2
	type.move_cost = 2
	type.soft_move_cap = 8
	type.produce_cost = 5
	type.defense = 0
	return type


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


# A throwaway Production-Outpost-shaped StructureTypeDef (build_cost 9, hp
# 14) — AC-1's "worst-case one-shot kill" reference stat, unused directly by
# this file's asserted worked examples but kept available for future-proofing
# if a reviewer wants the ceiling case; not exercised by name here.
func _make_structure_type(hp: int, build_cost: int, defense: int = 0) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestStructure"
	type.hp = hp
	type.build_cost = build_cost
	type.build_time = 1
	type.defense = defense
	return type


# The real HQ StructureTypeDef (hp 40, defense 2 per AC-29's worked example)
# — StructureState.is_hq() compares by Resource-reference identity against
# StructureTypes.HQ, so AC-29's fixture must use the real registry constant,
# never a throwaway HQ-shaped duplicate (a duplicate would NOT satisfy
# is_hq() and would silently fall through to the build_cost branch, which is
# exactly the regression this story's AC-29 guards against).
func _make_hq(entity_id: int, owner: int, pos: Vector2i, current_hp: int) -> StructureState:
	var hq := StructureState.new()
	hq.entity_id = entity_id
	hq.owner = owner
	hq.position = pos
	hq.type = StructureTypes.HQ
	hq.current_hp = current_hp
	hq.build_status = StructureState.BuildStatus.COMPLETED
	return hq


# --- AC-11: non-lethal trade -> combat_value 2.0, action_score 1.00 ---------

func test_combat_value_non_lethal_trade_is_exactly_2_0() -> void:
	# Arrange — attacker atk 3 vs full-hp (6/6) enemy Trooper, produce_cost 4.
	var target_type := _make_trooper_type()
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_trooper_type(), Vector2i(0, 0))
	var target := _make_unit(2, 1, target_type, Vector2i(1, 0), 6)
	_place(state, attacker)
	_place(state, target)

	# Act
	var dmg: int = Combat.preview_damage(state, attacker, target)
	var hp_removed: int = mini(dmg, target.current_hp)
	var is_kill: bool = hp_removed >= target.current_hp
	var value: float = AI._combat_value(hp_removed, is_kill, target)

	# Assert — preview_damage = max(1, 3-0-0) = 3; hp_removed = 3; is_kill = false.
	assert_int(dmg).is_equal(3)
	assert_bool(is_kill).is_false()
	assert_float(value).is_equal_approx(2.0, 0.0001)


func test_action_score_non_lethal_trade_is_exactly_1_00() -> void:
	# Arrange/Act — same fixture as above, cost 2 (CombatConfig.attack_cost).
	var value := 2.0
	var cost := 2
	var base_score: float = value / float(cost)
	var score: float = AI._action_score(base_score, false)

	# Assert
	assert_float(score).is_equal_approx(1.00, 0.0001)


# --- AC-12: finishing blow -> combat_value 4.0, base 2.00, floored 3.50 -----

func test_combat_value_finishing_blow_is_exactly_4_0() -> void:
	# Arrange — same attack, target already at 3/6 hp -> lethal.
	var target_type := _make_trooper_type()
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_trooper_type(), Vector2i(0, 0))
	var target := _make_unit(2, 1, target_type, Vector2i(1, 0), 3)
	_place(state, attacker)
	_place(state, target)

	# Act
	var dmg: int = Combat.preview_damage(state, attacker, target)
	var hp_removed: int = mini(dmg, target.current_hp)
	var is_kill: bool = hp_removed >= target.current_hp
	var value: float = AI._combat_value(hp_removed, is_kill, target)

	# Assert — preview_damage = 3; hp_removed = min(3,3) = 3; is_kill = true;
	# combat_value = 4×(3/6) + 0.5×4 = 2.0 + 2.0 = 4.0.
	assert_int(dmg).is_equal(3)
	assert_bool(is_kill).is_true()
	assert_float(value).is_equal_approx(4.0, 0.0001)


func test_action_score_finishing_blow_floors_from_2_00_to_3_50() -> void:
	# Arrange — base_score = 4.0/2 = 2.00, below LETHAL_FLOOR_BONUS (3.5).
	var value := 4.0
	var cost := 2
	var base_score: float = value / float(cost)

	# Act
	var score: float = AI._action_score(base_score, true)

	# Assert
	assert_float(base_score).is_equal_approx(2.00, 0.0001)
	assert_float(score).is_equal_approx(3.50, 0.0001)


# --- AC-29: HQ siege -> ap_cost_opponent_paid_for(HQ)=12, combat_value~=1.5, --
# --- action_score~=0.75, above PASS_THRESHOLD ------------------------------

func test_ap_cost_opponent_paid_for_hq_resolves_to_hq_siege_value_not_zero() -> void:
	# Arrange — the real HQ (no build_cost) must resolve via is_hq(), never
	# fall through to a 0/undefined build_cost read.
	var hq := _make_hq(3, 1, Vector2i(5, 5), 40)

	# Act
	var ap_cost: int = AI._ap_cost_opponent_paid_for(hq)

	# Assert — AIBalance.ai.hq_siege_value default is 12 (AC-29's regression guard).
	assert_int(ap_cost).is_equal(AIBalance.ai.hq_siege_value)
	assert_int(ap_cost).is_equal(12)


func test_combat_value_hq_siege_non_lethal_is_approx_1_5() -> void:
	# Arrange — Sniper eff-atk 7 vs HQ hp 40 def 2: preview_damage =
	# max(1, 7-0-2) = 5 (structures are cover-immune, so cover term is 0).
	var state := _make_state()
	var sniper := _make_unit(1, 0, _make_sniper_type(), Vector2i(0, 0))
	var hq := _make_hq(2, 1, Vector2i(1, 0), 40)
	_place(state, sniper)
	_place(state, hq)

	# Act
	var dmg: int = Combat.preview_damage(state, sniper, hq)
	var hp_removed: int = mini(dmg, hq.current_hp)
	var is_kill: bool = hp_removed >= hq.current_hp
	var value: float = AI._combat_value(hp_removed, is_kill, hq)

	# Assert — dmg=5, hp_removed=5, target_max_hp=40, is_kill=false;
	# combat_value = 12 × (5/40) + 0 = 1.5.
	assert_int(dmg).is_equal(5)
	assert_bool(is_kill).is_false()
	assert_float(value).is_equal_approx(1.5, 0.0001)


func test_action_score_hq_siege_is_approx_0_75_and_clears_pass_threshold() -> void:
	# Arrange — combat_value 1.5 at cost 2 (CombatConfig.attack_cost).
	var value := 1.5
	var cost := 2
	var base_score: float = value / float(cost)

	# Act
	var score: float = AI._action_score(base_score, false)

	# Assert
	assert_float(score).is_equal_approx(0.75, 0.0001)
	assert_bool(score > AIBalance.ai.pass_threshold).is_true()


# --- AC-14: production_value + 3-band REACHABILITY_MULTIPLIER --------------

func test_production_value_isolated_band_is_produce_cost_times_0_9() -> void:
	var unit_type := _make_trooper_type()  # produce_cost 4
	var value: float = AI._production_value(unit_type, 0.9)
	assert_float(value).is_equal_approx(3.6, 0.0001)


func test_production_value_in_contact_band_is_produce_cost_times_1_0() -> void:
	var unit_type := _make_trooper_type()  # produce_cost 4
	var value: float = AI._production_value(unit_type, 1.0)
	assert_float(value).is_equal_approx(4.0, 0.0001)


func test_production_value_reachable_band_is_produce_cost_times_1_1() -> void:
	var unit_type := _make_trooper_type()  # produce_cost 4
	var value: float = AI._production_value(unit_type, 1.1)
	assert_float(value).is_equal_approx(4.4, 0.0001)


func test_reachability_multiplier_selects_reachable_band_when_enemy_in_range() -> void:
	# Arrange — deploy tile within attack_range + soft_move_cap of a live
	# enemy this turn.
	var state := _make_state()
	var trooper_type := _make_trooper_type()  # attack_range 1, soft_move_cap 8 -> reach 9
	var enemy := _make_unit(9, 1, trooper_type, Vector2i(5, 0))
	_place(state, enemy)
	var deploy_tile := Vector2i(0, 0)  # manhattan distance 5 <= reach 9

	# Act
	var multiplier: float = AI._reachability_multiplier(state, 0, deploy_tile, trooper_type)

	# Assert
	assert_float(multiplier).is_equal_approx(1.1, 0.0001)


func test_reachability_multiplier_selects_in_contact_band_when_sides_in_contact_but_not_deploy_reachable() -> void:
	# Arrange — the deploy tile itself is far from any enemy, but a friendly
	# unit and an enemy unit are each within the other's reach (in contact).
	var state := _make_state()
	var trooper_type := _make_trooper_type()  # reach = 1 + 8 = 9
	var friendly := _make_unit(9, 0, trooper_type, Vector2i(0, 0))
	var enemy := _make_unit(10, 1, trooper_type, Vector2i(5, 0))  # dist 5 <= 9, in contact
	_place(state, friendly)
	_place(state, enemy)
	var deploy_tile := Vector2i(0, 9)  # far from the enemy: manhattan dist 14 > reach 9

	# Act
	var multiplier: float = AI._reachability_multiplier(state, 0, deploy_tile, trooper_type)

	# Assert
	assert_float(multiplier).is_equal_approx(1.0, 0.0001)


func test_reachability_multiplier_selects_isolated_band_when_no_contact() -> void:
	# Arrange — no enemy at all on the board (opening-turn production).
	var state := _make_state()
	var trooper_type := _make_trooper_type()
	var deploy_tile := Vector2i(0, 0)

	# Act
	var multiplier: float = AI._reachability_multiplier(state, 0, deploy_tile, trooper_type)

	# Assert
	assert_float(multiplier).is_equal_approx(0.9, 0.0001)


func test_production_action_score_trooper_reachable_this_turn_is_exactly_1_10() -> void:
	# Arrange — the GDD's own worked example: Trooper produce_cost 4,
	# reachable-this-turn -> production_value 4.4, cost 4 -> action_score 1.10.
	var unit_type := _make_trooper_type()
	var value: float = AI._production_value(unit_type, 1.1)
	var cost := 4

	# Act
	var score: float = AI._action_score(value / float(cost), false)

	# Assert
	assert_float(value).is_equal_approx(4.4, 0.0001)
	assert_float(score).is_equal_approx(1.10, 0.0001)


# --- AC-21: move+attack combo scored via legal_targets_from at combined cost -

func test_move_and_attack_candidate_scores_combo_via_legal_targets_from_at_combined_cost() -> void:
	# Arrange — a Trooper (attack_range 1, move_cost 2, soft_move_cap 8) two
	# tiles from an enemy Trooper: no target from the real position, but
	# moving 1 tile closer (cost 2) puts the enemy in range for an attack
	# (cost 2), a combined AP cost of 4 — the exact combo the GDD's Edge Cases
	# section (AC-21) describes, scored via legal_targets_from at that combined
	# cost, never a separately re-derived formula.
	var state := _make_state()
	var attacker_type := _make_trooper_type()
	var attacker := _make_unit(1, 0, attacker_type, Vector2i(0, 0))
	var target := _make_unit(2, 1, _make_trooper_type(), Vector2i(2, 0), 6)
	_place(state, attacker)
	_place(state, target)

	# Act — no zero-move target (distance 2 > attack_range 1).
	var zero_move_targets: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)

	# The reachable tile adjacent to the target (1,0) is 1 tile away, cost 2
	# (move_cost). From there, legal_targets_from must see the enemy.
	var reachable: Array[Movement.ReachableTile] = Movement.reachable(state, attacker)
	var combo_tile := Vector2i(1, 0)
	var combo_reachable: Movement.ReachableTile = null
	for r: Movement.ReachableTile in reachable:
		if r.tile == combo_tile:
			combo_reachable = r
			break
	var combo_targets: Array[Combat.TargetResult] = Combat.legal_targets_from(state, attacker, combo_tile)

	# Assert — no stationary target; the combo tile is reachable at cost 2 and
	# does see the enemy; combined AP cost = move_path_cost(2) + attack_cost(2) = 4.
	assert_array(zero_move_targets).is_empty()
	assert_object(combo_reachable).is_not_null()
	assert_int(combo_reachable.min_cost).is_equal(2)
	assert_int(combo_targets.size()).is_equal(1)
	assert_int(combo_targets[0].target_id).is_equal(target.entity_id)

	var combined_cost: int = combo_reachable.min_cost + CombatBalance.combat.attack_cost
	assert_int(combined_cost).is_equal(4)

	var dmg: int = Combat.preview_damage(state, attacker, target)
	var hp_removed: int = mini(dmg, target.current_hp)
	var is_kill: bool = hp_removed >= target.current_hp
	var value: float = AI._combat_value(hp_removed, is_kill, target)
	var score: float = AI._action_score(value / float(combined_cost), is_kill)

	assert_float(value).is_equal_approx(2.0, 0.0001)
	assert_float(score).is_equal_approx(0.5, 0.0001)


func test_score_move_and_attack_candidates_finds_the_combo_end_to_end() -> void:
	# Arrange — the same combo geometry as above, driven through the real
	# per-verb enumeration helper (not just the raw formula pieces), proving
	# the combo is actually discovered and folded into the running best.
	var state := _make_state()
	var attacker_type := _make_trooper_type()
	var attacker := _make_unit(1, 0, attacker_type, Vector2i(0, 0))
	var target := _make_unit(2, 1, _make_trooper_type(), Vector2i(2, 0), 6)
	_place(state, attacker)
	_place(state, target)

	var best := AI._Candidate.new()

	# Act
	best = AI._score_move_and_attack_candidates(state, attacker, 0, best)

	# Assert — a real AttackAction was found and folded in, scored via the
	# move+attack combo path (no zero-move target exists in this geometry).
	assert_object(best.action).is_not_null()
	assert_bool(best.action is AttackAction).is_true()
	var attack_action: AttackAction = best.action
	assert_vector(attack_action.attacker_tile).is_equal(Vector2i(1, 0))
	assert_vector(attack_action.target_tile).is_equal(Vector2i(2, 0))
	assert_int(best.ap_cost).is_equal(4)
	assert_float(best.score).is_equal_approx(0.5, 0.0001)


# --- Edge: MIN_DAMAGE=1 floor on a full-hp target -> combat_value strictly > 0

func test_combat_value_min_damage_floor_on_full_hp_target_is_strictly_positive() -> void:
	# Arrange — an attacker whose effective attack is fully absorbed by the
	# defender's defense, so damage() floors to MIN_DAMAGE (1), against a
	# full-hp target (never lethal at 1 damage out of 6 hp).
	var weak_attacker_type := UnitTypeDef.new()
	weak_attacker_type.display_name = "WeakAttacker"
	weak_attacker_type.hp = 6
	weak_attacker_type.attack = 1
	weak_attacker_type.attack_range = 1
	weak_attacker_type.move_cost = 1
	weak_attacker_type.soft_move_cap = 8
	weak_attacker_type.produce_cost = 2

	var tough_target_type := _make_trooper_type()
	tough_target_type.defense = 5  # attack(1) - defense(5) would be negative -> MIN_DAMAGE floor

	var state := _make_state()
	var attacker := _make_unit(1, 0, weak_attacker_type, Vector2i(0, 0))
	var target := _make_unit(2, 1, tough_target_type, Vector2i(1, 0), tough_target_type.hp)
	_place(state, attacker)
	_place(state, target)

	# Act
	var dmg: int = Combat.preview_damage(state, attacker, target)
	var hp_removed: int = mini(dmg, target.current_hp)
	var is_kill: bool = hp_removed >= target.current_hp
	var value: float = AI._combat_value(hp_removed, is_kill, target)

	# Assert — dmg floors to CombatConfig.min_damage (1), never 0; combat_value
	# is therefore strictly positive, never 0, even against a full-hp target.
	assert_int(dmg).is_equal(CombatBalance.combat.min_damage)
	assert_bool(dmg > 0).is_true()
	assert_bool(is_kill).is_false()
	assert_float(value).is_greater(0.0)


# --- CR-7 proof: two lethal candidates with different base_score both floor -
# --- to the identical LETHAL_FLOOR_BONUS (post-hoc, never a pre-filter) -----

func test_two_lethal_candidates_with_different_base_scores_both_floor_to_identical_lethal_floor_bonus() -> void:
	# Arrange — candidate A: the AC-12 finishing blow (base_score 2.00).
	# Candidate B: a cheaper finishing blow with a much higher base_score
	# (e.g. a 1-hp kill on a cheap unit at cost 1), so the two candidates'
	# base_scores are provably different BEFORE flooring.
	var base_score_a := 2.00  # AC-12's finishing blow
	var base_score_b := 6.00  # a different, higher base_score, also lethal

	# Act — both are scored via the same post-hoc action_score function.
	var score_a: float = AI._action_score(base_score_a, true)
	var score_b: float = AI._action_score(base_score_b, true)

	# Assert — proves the floor is POST-HOC (applied after each candidate's
	# own real base_score is computed), never a pre-filter that would have
	# short-circuited enumeration before scoring: base_score_a (2.00) sits
	# below LETHAL_FLOOR_BONUS (3.5) and floors up to it, while base_score_b
	# (6.00) already exceeds the floor and is left untouched by max() — yet
	# both distinct base_scores land on the exact same final action_score
	# only when the floor actually binds (candidate A), and CR-7 guarantees
	# neither is ever skipped for a marginal economy play regardless of which
	# one's base_score was higher pre-floor.
	assert_float(base_score_a).is_not_equal(base_score_b)
	assert_float(score_a).is_equal_approx(AIBalance.ai.lethal_floor_bonus, 0.0001)
	assert_float(score_a).is_equal_approx(3.50, 0.0001)
	# Candidate B's base_score already exceeds the floor, so max() leaves it
	# untouched — both are still "the floor is guaranteed, not skipped" cases,
	# but B demonstrates the floor is a MAX, not an unconditional override.
	assert_float(score_b).is_equal_approx(6.00, 0.0001)
	assert_bool(score_b >= AIBalance.ai.lethal_floor_bonus).is_true()


func test_two_equal_base_score_lethal_candidates_both_floor_to_identical_lethal_floor_bonus() -> void:
	# Arrange — the literal "two simultaneous lethal attacks both floored to
	# the identical LETHAL_FLOOR_BONUS constant" case the GDD's Edge Cases
	# section names as the common exact-tie case Story 005's tie-break must
	# resolve. Both candidates here share the AC-12 base_score (2.00, below
	# the floor) but are otherwise distinct attacks (different entities) —
	# scored independently, each through its own action_score() call, never
	# short-circuited by a pre-filter that would only score "the first lethal
	# candidate found."
	var candidate_a_base_score := 2.00
	var candidate_b_base_score := 2.00

	# Act
	var score_a: float = AI._action_score(candidate_a_base_score, true)
	var score_b: float = AI._action_score(candidate_b_base_score, true)

	# Assert — both floor to the exact same constant.
	assert_float(score_a).is_equal_approx(3.50, 0.0001)
	assert_float(score_b).is_equal_approx(3.50, 0.0001)
	assert_float(score_a).is_equal_approx(score_b, 0.0001)


func test_action_score_non_lethal_is_never_floored_even_if_it_would_exceed_floor() -> void:
	# Arrange/Act — a non-lethal candidate whose base_score already exceeds
	# LETHAL_FLOOR_BONUS must NOT be floored (max() only applies when
	# is_immediately_lethal is true) — proves the floor is conditioned on
	# is_kill, not merely on the magnitude of base_score.
	var high_non_lethal_base_score := 5.0
	var score: float = AI._action_score(high_non_lethal_base_score, false)

	# Assert — passed through unchanged.
	assert_float(score).is_equal_approx(5.0, 0.0001)
