# Story S6-03: per-structure maximums.
#
# ★★ THIS IS THE LOAD-BEARING HALF OF THE PIVOT FIX AT THE RULES LAYER.
#
# production/vertical-slice/REPORT.md diagnosed the failure as: the AI always had
# another thing worth building, so AP was consumed by BUILD before any unit could
# march, so nobody ever attacked the objective, so no game ever resolved. Bounding the
# economy (S6-01/S6-02) removes the FUNDING for endless building; this removes the
# TARGETS. With every structure capped, a player reaches a state with nothing left to
# build -- at which point AP has nowhere to go but manoeuvre.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


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


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.active_player = 0
	state.per_player[0].current_ap = 999
	state.per_player[0].current_credits = 999999
	return state


func _add(state: GameState, player: int, type: StructureTypeDef, pos: Vector2i, \
		status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = status
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


# --- Counting -----------------------------------------------------------------

func test_structure_count_counts_completed_and_under_construction_together() -> void:
	# ★ Under-construction MUST count, or the maximum does nothing -- a player could
	# queue any number at once and only be stopped after they finished.
	var state := _state()
	_add(state, 0, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(1, 1))
	_add(state, 0, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(2, 1), \
		StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(BaseProduction.structure_count(state, 0, StructureTypes.DEFENSIVE_STRUCTURE)).is_equal(2)


func test_structure_count_is_per_type() -> void:
	var state := _state()
	_add(state, 0, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(1, 1))
	_add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(2, 1))
	assert_int(BaseProduction.structure_count(state, 0, StructureTypes.DEFENSIVE_STRUCTURE)).is_equal(1)
	assert_int(BaseProduction.structure_count(state, 0, StructureTypes.RESEARCH_LAB)).is_equal(1)


func test_structure_count_is_per_player() -> void:
	var state := _state()
	_add(state, 0, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(1, 1))
	_add(state, 1, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(9, 9))
	assert_int(BaseProduction.structure_count(state, 0, StructureTypes.DEFENSIVE_STRUCTURE)).is_equal(1)
	assert_int(BaseProduction.structure_count(state, 1, StructureTypes.DEFENSIVE_STRUCTURE)).is_equal(1)


# --- The gate ------------------------------------------------------------------

func test_can_build_more_is_true_below_the_maximum() -> void:
	var state := _state()
	assert_bool(BaseProduction.can_build_more(state, 0, StructureTypes.RESEARCH_LAB)).is_true()


func test_can_build_more_is_false_at_the_maximum() -> void:
	var state := _state()
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count):
		_add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(i, 5))
	assert_bool(BaseProduction.can_build_more(state, 0, StructureTypes.RESEARCH_LAB)).is_false()


func test_a_max_count_of_zero_means_unlimited() -> void:
	# ★ The backwards-compatible default: a type that has not opted in is unbounded, so
	# adding this field changed no existing behaviour.
	var state := _state()
	var unlimited := StructureTypeDef.new()
	unlimited.max_count = 0
	unlimited.hp = 10
	for i: int in range(12):
		_add(state, 0, unlimited, Vector2i(i, 7))
	assert_bool(BaseProduction.can_build_more(state, 0, unlimited)).is_true()


# --- Enforcement through the real validate path --------------------------------

func test_build_at_the_maximum_is_rejected_naming_the_maximum() -> void:
	var state := _state()
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count):
		_add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(i, 5))
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(8, 8)
	assert_int(BaseProduction.validate_build(state, a)).is_equal(Action.Reason.STRUCTURE_MAX_REACHED)


func test_the_maximum_is_reported_even_with_ample_credits_and_ap() -> void:
	# ★ The reason must name the cap, not affordability. A player at their maximum may
	# well also be broke, but the cap is why they cannot build.
	var state := _state()
	state.per_player[0].current_credits = 999999999
	state.per_player[0].current_ap = 9999
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count):
		_add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(i, 5))
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(8, 8)
	assert_int(BaseProduction.validate_build(state, a)).is_equal(Action.Reason.STRUCTURE_MAX_REACHED)


func test_an_under_construction_instance_counts_toward_the_gate() -> void:
	var state := _state()
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count):
		_add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(i, 5), \
			StructureState.BuildStatus.UNDER_CONSTRUCTION)
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(8, 8)
	assert_int(BaseProduction.validate_build(state, a)).is_equal(Action.Reason.STRUCTURE_MAX_REACHED)


func test_the_opponents_structures_do_not_consume_your_maximum() -> void:
	var state := _state()
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count + 2):
		_add(state, 1, StructureTypes.RESEARCH_LAB, Vector2i(i, 12))
	assert_bool(BaseProduction.can_build_more(state, 0, StructureTypes.RESEARCH_LAB)).is_true()


func test_destroying_one_frees_a_slot() -> void:
	var state := _state()
	var last: StructureState = null
	for i: int in range(StructureTypes.RESEARCH_LAB.max_count):
		last = _add(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(i, 5))
	assert_bool(BaseProduction.can_build_more(state, 0, StructureTypes.RESEARCH_LAB)).is_false()
	state.destroy_entity(last.entity_id)
	assert_bool(BaseProduction.can_build_more(state, 0, StructureTypes.RESEARCH_LAB)).is_true()


# --- ★ The property the PIVOT fix actually needs --------------------------------

func test_every_buildable_structure_type_declares_a_maximum() -> void:
	# ★★ If ANY buildable structure is left unbounded, the player never runs out of
	# things to build and the whole rules-layer half of the fix leaks through that one
	# type. This is the regression that guards the property, not just the mechanism.
	for st: StructureTypeDef in [StructureTypes.HQ, StructureTypes.RESEARCH_LAB, \
			StructureTypes.DEFENSIVE_STRUCTURE, StructureTypes.BARRACKS, \
			StructureTypes.FACTORY]:
		assert_int(st.max_count).is_greater(0)


func test_a_player_at_every_maximum_has_nothing_left_to_build() -> void:
	# ★★ The end state the PIVOT fix depends on: build-out is FINITE. Once reached, AP
	# has nowhere to go but movement and combat.
	var state := _state()
	var types: Array[StructureTypeDef] = [StructureTypes.RESEARCH_LAB, \
		StructureTypes.DEFENSIVE_STRUCTURE, StructureTypes.BARRACKS, \
		StructureTypes.FACTORY]
	var x: int = 0
	for st: StructureTypeDef in types:
		for i: int in range(st.max_count):
			_add(state, 0, st, Vector2i(x % GRID_SIZE, 3 + int(x / GRID_SIZE)))
			x += 1
	for st: StructureTypeDef in types:
		assert_bool(BaseProduction.can_build_more(state, 0, st)) \
			.override_failure_message("%s still buildable at its maximum" % st.display_name) \
			.is_false()
