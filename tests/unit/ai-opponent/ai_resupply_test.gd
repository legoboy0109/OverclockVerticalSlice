# AI resupply drive (2026-10-01): an empty vehicle/aircraft heads for the nearest own resupplying
# structure instead of advancing, and stays put once beside one.
extends GdUnitTestSuite

const SIZE: int = 14


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
		p.faction = Factions.NEUTRAL
		p.current_ap = 20
	return state


func _vehicle(state: GameState, pos: Vector2i) -> UnitState:
	var type: UnitTypeDef = null
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE and t.attack_range >= 1:
			type = t
			break
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = 0
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	if type.requires_pilot:
		for p: UnitTypeDef in UnitTypes.ALL:
			if p.can_pilot:
				var pilot := UnitState.new()
				pilot.entity_id = 500
				pilot.owner = 0
				pilot.type = p
				pilot.current_hp = p.hp
				u.pilot = pilot
				break
	u.ammo_spent = Ammo.max_ammo(type)
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _factory(state: GameState, pos: Vector2i) -> void:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = pos
	st.type = StructureTypes.FACTORY
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1


func test_ai_empty_vehicle_moves_toward_its_factory() -> void:
	var state := _state()
	_factory(state, Vector2i(11, 11))
	var u := _vehicle(state, Vector2i(2, 2))
	var best := AI._score_resupply_candidates(state, u, AI._Candidate.new())
	assert_object(best.action).is_not_null()
	var mv: MoveAction = best.action
	var before: int = state.grid.manhattan_distance(u.position, Vector2i(11, 11))
	var after: int = state.grid.manhattan_distance(mv.to, Vector2i(11, 11))
	assert_int(after).is_less(before)
	assert_float(best.score).is_greater(AIBalance.ai.pass_threshold)


func test_ai_empty_vehicle_beside_a_supplier_stays() -> void:
	var state := _state()
	_factory(state, Vector2i(5, 5))
	var u := _vehicle(state, Vector2i(5, 6))
	var best := AI._score_resupply_candidates(state, u, AI._Candidate.new())
	assert_object(best.action).is_null()
