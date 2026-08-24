# Story S6-06: the AI's capacity-value term.
#
# ★★ WHY THIS EXISTS: the S6-06 regression batch FAILED -- 0/21 games resolved, zero HQ
# damage in 1,260 turn-rows. tools/DiagnoseAI.tscn found `best_build` was 0.000 in EVERY
# traced turn: the AI never built anything, so its population cap never rose above the base
# 4, so its army never grew, so both sides ground mid-map with three units forever.
#
# The cause was S6-01's reasoning -- right about INCOME, wrong about VALUE: "no structure
# raises Credit income, so building is not an economic investment." Since S6-04 a Barracks
# raises the POPULATION CAP, and the AI had no term for capacity.
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
	# Unit.effective_produce_cost folds in the acting player's faction delta, so a state
	# without factions assigned crashes rather than defaulting. The simulator and the slice
	# both assign them at setup; the bare factory does not.
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _add_hq(state: GameState, player: int, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = StructureTypes.HQ
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _fill_to(state: GameState, player: int, count: int) -> void:
	for i: int in range(count):
		var u := UnitState.new()
		u.entity_id = state.next_entity_id
		u.owner = player
		u.position = Vector2i(i, 10)
		u.type = UnitTypes.SCOUT
		u.current_hp = u.type.hp
		state.entities_by_id[u.entity_id] = u
		state.grid.place(u.entity_id, i, 10)
		state.next_entity_id += 1


# --- The defect the batch exposed --------------------------------------------

func test_a_barracks_is_worth_something_when_the_army_is_constrained() -> void:
	# ★★ THE REGRESSION. Before S6-06 this was 0.0 and the AI never built one.
	var state := _state()
	_add_hq(state, 0, Vector2i(5, 5))
	_fill_to(state, 0, Population.effective_cap(state, 0))  # at cap
	assert_float(AI._economy_value(state, 0, StructureTypes.BARRACKS)).is_greater(0.0)


func test_a_constrained_barracks_clears_the_pass_threshold() -> void:
	# ★ Being non-zero is not enough -- it must beat pass_threshold or the AI still
	# never builds it. This is the assertion that actually guards the behaviour.
	var state := _state()
	_add_hq(state, 0, Vector2i(5, 5))
	_fill_to(state, 0, Population.effective_cap(state, 0))
	var value: float = AI._economy_value(state, 0, StructureTypes.BARRACKS)
	var denom: float = AI.ap_equivalent_cost(StructureTypes.BARRACKS.build_cost, \
		Balance.economy.build_ap_cost)
	assert_float(value / denom).is_greater(AIBalance.ai.pass_threshold)


# --- The utilisation factor, which is what keeps the term sane ---------------

func test_an_empty_army_values_a_barracks_at_zero() -> void:
	# ★ Without the utilisation factor the AI would build infrastructure it cannot use
	# while it has nothing on the board. This is the guard against that.
	var state := _state()
	_add_hq(state, 0, Vector2i(5, 5))
	assert_float(AI._economy_value(state, 0, StructureTypes.BARRACKS)).is_equal_approx(0.0, 0.0001)


func test_capacity_value_rises_with_pressure() -> void:
	var state_low := _state()
	_add_hq(state_low, 0, Vector2i(5, 5))
	_fill_to(state_low, 0, 1)

	var state_high := _state()
	_add_hq(state_high, 0, Vector2i(5, 5))
	_fill_to(state_high, 0, Population.effective_cap(state_high, 0))

	assert_float(AI._economy_value(state_high, 0, StructureTypes.BARRACKS)) \
		.is_greater(AI._economy_value(state_low, 0, StructureTypes.BARRACKS))


# --- Correct zeros ------------------------------------------------------------

func test_structures_granting_no_cap_are_still_worth_zero() -> void:
	# ★ Correct today, not a gap: the Factory produces ground vehicles (none exist until
	# wave 2) and research is not implemented. Both gain value through this same function
	# when they gain something to be worth.
	var state := _state()
	_add_hq(state, 0, Vector2i(5, 5))
	_fill_to(state, 0, Population.effective_cap(state, 0))
	assert_float(AI._economy_value(state, 0, StructureTypes.FACTORY)).is_equal_approx(0.0, 0.0001)
	assert_float(AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)).is_equal_approx(0.0, 0.0001)


func test_no_producer_means_no_capacity_value() -> void:
	# A cap slot is worth what you can put in it. With no completed producer, nothing.
	var state := _state()
	_fill_to(state, 0, 2)
	assert_float(AI._economy_value(state, 0, StructureTypes.BARRACKS)).is_equal_approx(0.0, 0.0001)


func test_capacity_value_uses_the_cheapest_producible_unit() -> void:
	var state := _state()
	_add_hq(state, 0, Vector2i(5, 5))
	_fill_to(state, 0, Population.effective_cap(state, 0))
	var cheapest: float = AI._cheapest_producible_cost(state, 0)
	assert_float(cheapest).is_greater(0.0)
	# The HQ produces Scout only, so the cheapest producible IS the Scout.
	assert_float(cheapest).is_equal_approx(float(UnitTypes.SCOUT.produce_cost), 0.0001)
