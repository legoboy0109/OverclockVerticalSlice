# ★ 2026-10-02 balance pass: the AI raises an anti-air producer when the enemy flies and it cannot
# answer. Before, Order and Trappist (anti-air only from their Airfield) built 0 Talons/Dominions
# facing 22 enemy aircraft in 12 games. Pins AI._anti_air_need_value's three gates.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	state.grid = grid
	_unit(state, 0, Vector2i(3, 3), UnitTypes.LEVY)   # own army: ground-only
	return state


func _unit(state: GameState, player: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = player
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _structure(state: GameState, player: int, pos: Vector2i, type: StructureTypeDef) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


# The Order's Airfield — its only source of anti-air (the Dominion).
func _empire_airfield() -> StructureTypeDef:
	return load("res://data/structures/empire_airfield.tres")


func test_enemy_aircraft_make_an_anti_air_producer_worth_building() -> void:
	var state := _state()
	_unit(state, 1, Vector2i(10, 10), UnitTypes.GUNSHIP)
	assert_float(AI._anti_air_need_value(state, 0, _empire_airfield())).is_greater(0.0)


func test_no_enemy_aircraft_means_no_anti_air_need() -> void:
	var state := _state()
	_unit(state, 1, Vector2i(10, 10), UnitTypes.TROOPER)
	assert_float(AI._anti_air_need_value(state, 0, _empire_airfield())).is_equal_approx(0.0, 0.0001)


func test_no_need_once_an_anti_air_producer_is_owned() -> void:
	var state := _state()
	_unit(state, 1, Vector2i(10, 10), UnitTypes.GUNSHIP)
	_structure(state, 0, Vector2i(2, 2), _empire_airfield())
	assert_float(AI._anti_air_need_value(state, 0, _empire_airfield())).is_equal_approx(0.0, 0.0001)


func test_a_producer_without_anti_air_units_gets_nothing() -> void:
	var state := _state()
	_unit(state, 1, Vector2i(10, 10), UnitTypes.GUNSHIP)
	assert_float(AI._anti_air_need_value(state, 0, StructureTypes.FACTORY)).is_equal_approx(0.0, 0.0001)


func test_need_shrinks_when_the_army_can_already_hit_air() -> void:
	var bare := _state()
	_unit(bare, 1, Vector2i(10, 10), UnitTypes.GUNSHIP)
	var covered := _state()
	_unit(covered, 1, Vector2i(10, 10), UnitTypes.GUNSHIP)
	_unit(covered, 0, Vector2i(4, 4), UnitTypes.DOMINION)
	assert_float(AI._anti_air_need_value(covered, 0, _empire_airfield())) \
		.is_less(AI._anti_air_need_value(bare, 0, _empire_airfield()))
