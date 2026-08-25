# Base & Production Story 009: Production HUD Read-Surface.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-009-production-hud-read-surface.md
# (TR-baseprod-017) — the B&P read accessors added to the shipped getters-only
# `GameStateReader` facade (game_state_reader.gd):
#   AC1 legal_build_tiles(player, structure_type)      -- pass-through
#   AC2 legal_deploy_tiles(producer_id, unit_type)      -- pass-through, resolves id
#   AC3 build-timer progress (structure_info.build_turns_remaining)
#   AC4 remaining production_cap (structure_info.remaining_production_cap)
#   AC5 affordability (can_afford_build / can_afford_produce)
#   AC6 cancel-refund preview (structure_info.cancel_refund) == apply_cancel's
#       actual refund expression: BaseProduction.cancel_refund(type.build_cost)
#   AC7 current/max hp (structure_info.current_hp / .hp)
#   AC8 no reachable mutation path -- getters-only shape + value-snapshot proof
#
# Each accessor's return is asserted equal to the DIRECT BaseProduction/Unit/AP
# query (proves pass-through, non-vacuous) against a GameState built with real
# registry types (StructureTypes.*, UnitTypes.*) -- mirrors the sibling suites'
# real-schema convention (determinism_clone_isolation_test.gd,
# structure_destruction_hq_win_hook_test.gd). No mocks, no RNG, no
# time-dependence, no file I/O; each test builds its own isolated state via
# GameStateFactory. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 10


# None of the accessors under test fold Research (effective_build_cost/
# effective_production_cap/cancel_refund are Neutral no-ops with no tech read;
# Unit.effective_produce_cost folds Faction, not Research) -- reset anyway,
# matching the suite-wide isolation convention.
func before_test() -> void:
	Research.reset()


func after_test() -> void:
	Research.reset()


# --- Fixture builders --------------------------------------------------------

func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(current_ap: int = 20) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, status: int = StructureState.BuildStatus.COMPLETED, build_turns_remaining: int = 0, units_produced_this_turn: int = 0) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = type
	s.current_hp = type.hp
	s.build_status = status
	s.build_turns_remaining = build_turns_remaining
	s.units_produced_this_turn = units_produced_this_turn
	return s


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	return u


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# The story's QA setup: a player owning one Under-Construction Economy Outpost
# (2 turns remaining), one Completed Production Outpost (produced 1 of cap 4),
# and a selectable Defensive Structure -- wrapped in a GameStateReader.
func _make_story_state() -> GameState:
	var state := _make_state()
	_place(state, _make_structure(1, 0, Vector2i(2, 2), StructureTypes.FACTORY, StructureState.BuildStatus.UNDER_CONSTRUCTION, 2))
	_place(state, _make_structure(2, 0, Vector2i(4, 4), StructureTypes.BARRACKS, StructureState.BuildStatus.COMPLETED, 0, 1))
	_place(state, _make_structure(3, 0, Vector2i(6, 6), StructureTypes.DEFENSIVE_STRUCTURE))
	return state


# --- AC1: legal_build_tiles pass-through -------------------------------------

func test_legal_build_tiles_matches_direct_base_production_query() -> void:
	# Arrange
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	# Act
	var via_reader: Array[Vector2i] = reader.legal_build_tiles(0, StructureTypes.FACTORY)
	var via_direct: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- non-vacuous (friendly structures give candidate tiles) and equal.
	assert_int(via_reader.size()).is_greater(0)
	assert_array(via_reader).is_equal(via_direct)


func test_legal_build_tiles_mutation_does_not_perturb_state() -> void:
	# Arrange
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	var tiles: Array[Vector2i] = reader.legal_build_tiles(0, StructureTypes.FACTORY)
	var before: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Act -- mutate the returned Array.
	tiles.clear()
	tiles.append(Vector2i(99, 99))
	# Assert -- a fresh call from state is unaffected (no aliasing leak-back).
	var after: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	assert_array(after).is_equal(before)


# --- AC2: legal_deploy_tiles pass-through + total/safe contract --------------

func test_legal_deploy_tiles_matches_direct_base_production_query() -> void:
	# Arrange -- the Completed Production Outpost is the producer.
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	var producer: StructureState = state.entities_by_id[2]
	# Act
	var via_reader: Array[Vector2i] = reader.legal_deploy_tiles(2, UnitTypes.TROOPER)
	var via_direct: Array[Vector2i] = BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- non-vacuous (empty adjacent tiles exist) and equal.
	assert_int(via_reader.size()).is_greater(0)
	assert_array(via_reader).is_equal(via_direct)


func test_legal_deploy_tiles_missing_id_returns_empty_array() -> void:
	# Arrange
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	# Act / Assert -- total/safe: an id with no live entity returns [].
	var tiles: Array[Vector2i] = reader.legal_deploy_tiles(999, UnitTypes.TROOPER)
	assert_array(tiles).is_empty()


func test_legal_deploy_tiles_unit_id_returns_empty_array() -> void:
	# Arrange -- id 4 resolves to a UnitState, not a StructureState.
	var state := _make_story_state()
	_place(state, _make_unit(4, 0, UnitTypes.SCOUT, Vector2i(8, 8)))
	var reader := GameStateReader.new(state)
	# Act / Assert -- total/safe: wrong entity type returns [], never a runtime
	# type error from an internal `as StructureState` cast.
	var tiles: Array[Vector2i] = reader.legal_deploy_tiles(4, UnitTypes.TROOPER)
	assert_array(tiles).is_empty()


# --- AC3: build-timer progress -----------------------------------------------

func test_structure_info_build_turns_remaining_matches_field() -> void:
	# Arrange -- the Under-Construction Economy Outpost, 2 turns remaining.
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	# Act
	var info: Dictionary = reader.structure_info(1)
	# Assert
	assert_int(info["build_turns_remaining"]).is_equal(2)
	assert_int(info["build_turns_remaining"]).is_equal((state.entities_by_id[1] as StructureState).build_turns_remaining)


# --- AC4: remaining production_cap -------------------------------------------

func test_structure_info_remaining_production_cap_matches_cap_minus_produced() -> void:
	# Arrange -- the Completed Production Outpost, cap 4, produced 1 -> remaining 3.
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	var producer: StructureState = state.entities_by_id[2]
	# Act
	var info: Dictionary = reader.structure_info(2)
	var direct_cap: int = BaseProduction.effective_production_cap(state, producer, producer.owner)
	# Assert -- matches the story's stated value (3) and the direct-query formula.
	assert_int(info["remaining_production_cap"]).is_equal(3)
	assert_int(info["remaining_production_cap"]).is_equal(direct_cap - producer.units_produced_this_turn)


# --- AC5: affordability -------------------------------------------------------

func test_can_afford_build_matches_dual_cost_credits_and_ap_surcharge() -> void:
	# can_afford_build is DUAL-cost (ADR-0006 pivot): the Credit main cost
	# (effective_build_cost) AND the AP surcharge (build_ap_cost). It matches the
	# conjunction of the two owning queries verbatim, never a single-pool check.
	var state := _make_story_state()
	state.per_player[0].current_credits = 20000  # fund Credits (build_cost is Credits; ★ S6-02 ×100 rescale)
	var reader := GameStateReader.new(state)
	# Act
	var via_reader: bool = reader.can_afford_build(0, StructureTypes.FACTORY)
	var cost: int = BaseProduction.effective_build_cost(state, StructureTypes.FACTORY, 0)
	var via_direct: bool = Credits.can_afford(state, 0, cost) \
		and AP.can_afford(state, 0, Balance.economy.build_ap_cost)
	# Assert -- non-vacuous true (both pools afford) and matches the dual query.
	assert_bool(via_reader).is_true()
	assert_bool(via_reader).is_equal(via_direct)


func test_can_afford_build_false_when_ap_insufficient() -> void:
	# Arrange -- 0 AP cannot afford anything.
	var state := _make_story_state()
	state.per_player[0].current_ap = 0
	var reader := GameStateReader.new(state)
	# Act / Assert
	assert_bool(reader.can_afford_build(0, StructureTypes.FACTORY)).is_false()


func test_can_afford_produce_matches_dual_cost_credits_and_ap_surcharge() -> void:
	# can_afford_produce is DUAL-cost (ADR-0006 pivot): the Credit main cost
	# (effective_produce_cost) AND the AP surcharge (produce_ap_cost). It matches
	# the conjunction of the two owning queries verbatim, never a single-pool check.
	var state := _make_story_state()
	state.per_player[0].current_credits = 20000  # fund Credits (produce_cost is Credits; ★ S6-02 ×100 rescale)
	var reader := GameStateReader.new(state)
	# Act
	var via_reader: bool = reader.can_afford_produce(0, UnitTypes.TROOPER)
	var cost: int = Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)
	var via_direct: bool = Credits.can_afford(state, 0, cost) \
		and AP.can_afford(state, 0, Balance.economy.produce_ap_cost)
	# Assert -- non-vacuous true (both pools afford) and matches the dual query.
	assert_bool(via_reader).is_true()
	assert_bool(via_reader).is_equal(via_direct)


func test_can_afford_produce_false_when_ap_insufficient() -> void:
	# Arrange
	var state := _make_story_state()
	state.per_player[0].current_ap = 0
	var reader := GameStateReader.new(state)
	# Act / Assert
	assert_bool(reader.can_afford_produce(0, UnitTypes.TROOPER)).is_false()


# --- AC6: cancel-refund preview == apply_cancel's ACTUAL refund --------------

func test_structure_info_cancel_refund_matches_base_production_cancel_refund_on_base_cost() -> void:
	# Arrange -- the Under-Construction Factory (was the Economy Outpost; renamed in
	# S6-03 and re-statted to its design values in S6-09).
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	var structure: StructureState = state.entities_by_id[1]
	# Act
	var info: Dictionary = reader.structure_info(1)
	var expected: int = BaseProduction.cancel_refund(structure.type.build_cost)
	# Assert -- the exact refund expression, derived from the type's own build_cost.
	# ★ S6-09: was pinned to a literal 200 (half of the Factory's then-400 cost).
	# This test's subject is that structure_info and BaseProduction.cancel_refund
	# agree, not what the Factory happens to cost, so the literal was pure coupling.
	assert_int(info["cancel_refund"]).is_equal(expected)
	assert_int(info["cancel_refund"]).is_equal(
		BaseProduction.cancel_refund(StructureTypes.FACTORY.build_cost))


func test_structure_info_cancel_refund_equals_apply_cancels_actual_credit() -> void:
	# Arrange -- an isolated Under-Construction structure and a clone to cancel.
	var state := _make_state(0)
	_place(state, _make_structure(1, 0, Vector2i(2, 2), StructureTypes.FACTORY, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1))
	var reader := GameStateReader.new(state)
	var preview: int = reader.structure_info(1)["cancel_refund"]

	var clone: GameState = state.clone()
	var action := CancelBuildAction.new()
	action.player = 0
	action.structure_id = 1
	BaseProduction.apply_cancel(clone, action)
	# Refund lands in CREDITS now (ADR-0006 pivot), not AP.
	var actual_credit: int = clone.per_player[0].current_credits - state.per_player[0].current_credits

	# Assert -- the preview equals what a real cancel actually credited (both
	# routes are BaseProduction.cancel_refund(type.build_cost) -- proving the
	# preview never re-derives via effective_build_cost).
	assert_int(preview).is_equal(actual_credit)


# --- AC7: current/max hp ------------------------------------------------------

func test_structure_info_hp_matches_current_hp_and_type_hp() -> void:
	# Arrange -- the Defensive Structure (hp 10), damaged to 6.
	var state := _make_story_state()
	(state.entities_by_id[3] as StructureState).current_hp = 6
	var reader := GameStateReader.new(state)
	# Act
	var info: Dictionary = reader.structure_info(3)
	# Assert
	assert_int(info["current_hp"]).is_equal(6)
	assert_int(info["hp"]).is_equal(StructureTypes.DEFENSIVE_STRUCTURE.hp)
	assert_int(info["hp"]).is_equal(10)


# --- structure_info: simple pass-through keys (type / build_status / produced) -

func test_structure_info_surfaces_type_build_status_and_units_produced_keys() -> void:
	# Direct key assertions for the plain field-copy keys (type, build_status,
	# units_produced_this_turn) — a typo'd/renamed key or a swapped source field
	# would otherwise slip past the formula-bearing tests. Covers BOTH enum values.
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	# Under-Construction Economy Outpost (id 1): UC, produced 0.
	var uc: Dictionary = reader.structure_info(1)
	assert_object(uc["type"]).is_same(StructureTypes.FACTORY)
	assert_int(uc["build_status"]).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(uc["units_produced_this_turn"]).is_equal(0)
	# Completed Production Outpost (id 2): COMPLETED, produced 1.
	var done: Dictionary = reader.structure_info(2)
	assert_object(done["type"]).is_same(StructureTypes.BARRACKS)
	assert_int(done["build_status"]).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(done["units_produced_this_turn"]).is_equal(1)


# --- structure_info: total/safe contract + no-mutation snapshot proof (AC8) --

func test_structure_info_missing_id_returns_empty_dictionary() -> void:
	# Arrange
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	# Act / Assert
	assert_dict(reader.structure_info(999)).is_empty()


func test_structure_info_unit_id_returns_empty_dictionary() -> void:
	# Arrange -- id 4 resolves to a UnitState, not a StructureState.
	var state := _make_story_state()
	_place(state, _make_unit(4, 0, UnitTypes.SCOUT, Vector2i(8, 8)))
	var reader := GameStateReader.new(state)
	# Act / Assert -- total/safe: wrong entity type returns {}.
	assert_dict(reader.structure_info(4)).is_empty()


func test_structure_info_mutation_does_not_perturb_live_structure() -> void:
	# Arrange
	var state := _make_story_state()
	var reader := GameStateReader.new(state)
	var structure: StructureState = state.entities_by_id[2]
	var info: Dictionary = reader.structure_info(2)
	# Act -- mutate the returned snapshot Dictionary.
	info["current_hp"] = -999
	info["build_turns_remaining"] = -999
	info["remaining_production_cap"] = -999
	# Assert -- the live StructureState's fields are untouched (distinct object,
	# no aliasing leak-back -- structural AC8 read-only proof).
	assert_int(structure.current_hp).is_equal(structure.type.hp)
	assert_int(structure.build_turns_remaining).is_equal(0)
	assert_int(structure.units_produced_this_turn).is_equal(1)
	# A fresh call reflects the real (unperturbed) state, not the mutated copy.
	var fresh: Dictionary = reader.structure_info(2)
	assert_int(fresh["current_hp"]).is_equal(structure.type.hp)


# --- AC8: no reachable mutation path (structural, getters-only) --------------

func test_reader_exposes_no_mutating_method() -> void:
	# Structural proof (mirrors unit_info's contract): GameStateReader has no
	# apply_action/setter reachable from a held reference. Enumerated here as
	# an explicit negative assertion against the known mutation-vector names,
	# so a future accidental addition of e.g. `apply_action` fails this test.
	var reader := GameStateReader.new(_make_story_state())
	assert_bool(reader.has_method("apply_action")).is_false()
	assert_bool(reader.has_method("apply_build")).is_false()
	assert_bool(reader.has_method("apply_produce")).is_false()
	assert_bool(reader.has_method("apply_cancel")).is_false()
	assert_bool(reader.has_method("spend")).is_false()
	assert_bool(reader.has_method("credit")).is_false()
