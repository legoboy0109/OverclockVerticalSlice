# Build prerequisites (2026-10-01, user decision): a Factory needs a COMPLETED Barracks, an
# Airfield a completed Factory — for every faction's own versions of those buildings.
extends GdUnitTestSuite

const SIZE: int = 16


func before_test() -> void:
	Balance.reset()


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	var grid := GridState.new()
	grid.width = SIZE
	grid.height = SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(SIZE * SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(SIZE * SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	state.grid = grid
	state.active_player = 0
	for p: PlayerState in state.per_player:
		p.faction = Factions.DEMOCRATIC_ALLIANCE
		p.current_ap = 999
		p.current_credits = 999999
	return state


func _structure(state: GameState, type: StructureTypeDef, pos: Vector2i, done: bool = true) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED if done else StructureState.BuildStatus.UNDER_CONSTRUCTION
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _builder(state: GameState, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = 0
	u.position = pos
	u.type = UnitTypes.BUILDER
	u.current_hp = u.type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func test_factory_needs_a_completed_barracks() -> void:
	var state := _state()
	assert_object(BaseProduction.missing_prerequisite(state, 0, StructureTypes.FACTORY)).is_same(StructureTypes.BARRACKS)
	var b := _structure(state, StructureTypes.BARRACKS, Vector2i(2, 2), false)
	assert_object(BaseProduction.missing_prerequisite(state, 0, StructureTypes.FACTORY)) \
		.override_failure_message("a Barracks still under construction must not unlock the Factory").is_same(StructureTypes.BARRACKS)
	b.build_status = StructureState.BuildStatus.COMPLETED
	assert_object(BaseProduction.missing_prerequisite(state, 0, StructureTypes.FACTORY)).is_null()


func test_airfield_needs_a_completed_factory_and_barracks_needs_nothing() -> void:
	var state := _state()
	_structure(state, StructureTypes.BARRACKS, Vector2i(2, 2))
	assert_object(BaseProduction.missing_prerequisite(state, 0, StructureTypes.AIRFIELD)).is_same(StructureTypes.FACTORY)
	assert_object(BaseProduction.missing_prerequisite(state, 0, StructureTypes.BARRACKS)).is_null()


func test_every_faction_gates_its_own_factory_and_airfield() -> void:
	for st: StructureTypeDef in StructureTypes.ALL:
		var n: String = st.display_name
		if n.ends_with("Factory"):
			assert_int(st.requires_structures.size()).override_failure_message("%s has no prerequisite" % n).is_equal(1)
			assert_str(st.requires_structures[0].display_name).ends_with("Barracks")
		elif n.ends_with("Airfield"):
			assert_int(st.requires_structures.size()).override_failure_message("%s has no prerequisite" % n).is_equal(1)
			assert_str(st.requires_structures[0].display_name).ends_with("Factory")


func test_building_a_factory_without_a_barracks_is_refused() -> void:
	var state := _state()
	var bld := _builder(state, Vector2i(6, 6))
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.FACTORY
	a.builder_id = bld.entity_id
	a.tile = Vector2i(7, 6)
	assert_int(BaseProduction.validate_build(state, a)).is_equal(Action.Reason.PREREQUISITE_MISSING)


func test_the_build_menu_names_the_missing_building() -> void:
	var state := _state()
	var bld := _builder(state, Vector2i(6, 6))
	var options := CommandFSM.build_options(state, bld, [StructureTypes.BARRACKS, StructureTypes.FACTORY] as Array[StructureTypeDef])
	assert_bool(options[0].enabled).is_true()
	assert_bool(options[1].enabled).is_false()
	assert_int(options[1].reason & CommandFSM.Reason.NEEDS_STRUCTURE).is_not_equal(0)
	assert_object(options[1].blocking_structure).is_same(StructureTypes.BARRACKS)
