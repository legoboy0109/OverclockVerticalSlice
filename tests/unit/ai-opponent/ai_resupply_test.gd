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


# --- Supply Depots (2026-10-01) ------------------------------------------------------------

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


func test_ai_depot_beside_home_is_worth_nothing() -> void:
	var state := _state()
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(1, 2))
	_vehicle(state, Vector2i(2, 1))
	var units := AI._ammo_units(state, 0)
	assert_float(AI._depot_value_at(state, Vector2i(2, 2), units, AI._supplier_tiles(state, 0))).is_equal(0.0)


func test_ai_depot_near_a_distant_army_is_valued_and_built_forward() -> void:
	var state := _state()
	state.per_player[0].current_credits = 99999
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(10, 10))
	_vehicle(state, Vector2i(11, 10))
	var b := _builder(state, Vector2i(9, 10))
	var best := AI._score_depot_build(state, 0, StructureTypes.SUPPLY_DEPOT, AI._Candidate.new())
	assert_bool(best.action is BuildAction).is_true()
	var act: BuildAction = best.action
	assert_object(act.structure_type).is_equal(StructureTypes.SUPPLY_DEPOT)
	assert_int(act.builder_id).is_equal(b.entity_id)
	assert_float(best.score).is_greater(AIBalance.ai.pass_threshold)


func test_ai_depot_respects_the_owned_limit() -> void:
	var state := _state()
	state.per_player[0].current_credits = 99999
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(10, 10))
	_vehicle(state, Vector2i(11, 10))
	_builder(state, Vector2i(9, 10))
	for i: int in AIBalance.ai.depot_max_owned:
		var st := StructureState.new()
		st.entity_id = state.next_entity_id
		st.owner = 0
		st.position = Vector2i(3 + i, 7)
		st.type = StructureTypes.SUPPLY_DEPOT
		st.current_hp = st.type.hp
		st.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
		state.entities_by_id[st.entity_id] = st
		state.grid.place(st.entity_id, st.position.x, st.position.y)
		state.next_entity_id += 1
	var best := AI._score_depot_build(state, 0, StructureTypes.SUPPLY_DEPOT, AI._Candidate.new())
	assert_object(best.action).is_null()


func test_ai_builder_walks_toward_a_far_army_but_not_into_enemy_reach() -> void:
	var state := _state()
	state.per_player[0].current_credits = 99999
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(11, 11))
	_vehicle(state, Vector2i(12, 11))
	var b := _builder(state, Vector2i(2, 2))
	var best := AI._score_depot_escort_candidates(state, b, AI._Candidate.new())
	assert_bool(best.action is MoveAction).is_true()
	var to: Vector2i = (best.action as MoveAction).to
	assert_int(state.grid.manhattan_distance(to, Vector2i(11, 11))).is_less(state.grid.manhattan_distance(b.position, Vector2i(11, 11)))
	assert_bool(AI._tile_in_enemy_reach(state, to, 0)).is_false()


func test_ai_builder_stays_home_when_the_army_is_near_supply() -> void:
	var state := _state()
	state.per_player[0].current_credits = 99999
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(2, 1))
	_vehicle(state, Vector2i(1, 2))
	var b := _builder(state, Vector2i(3, 3))
	assert_object(AI._score_depot_escort_candidates(state, b, AI._Candidate.new()).action).is_null()


func test_ai_builder_never_steps_into_an_enemys_reach() -> void:
	var state := _state()
	state.per_player[0].current_credits = 99999
	_factory(state, Vector2i(1, 1))
	_vehicle(state, Vector2i(11, 11))
	_vehicle(state, Vector2i(12, 11))
	var b := _builder(state, Vector2i(2, 2))
	var enemy := UnitState.new()
	enemy.entity_id = state.next_entity_id
	enemy.owner = 1
	enemy.position = Vector2i(5, 4)
	enemy.type = UnitTypes.TROOPER
	enemy.current_hp = enemy.type.hp
	state.entities_by_id[enemy.entity_id] = enemy
	state.grid.place(enemy.entity_id, 5, 4)
	state.next_entity_id += 1
	var best := AI._score_depot_escort_candidates(state, b, AI._Candidate.new())
	if best.action != null:
		var to: Vector2i = (best.action as MoveAction).to
		assert_int(state.grid.manhattan_distance(to, enemy.position)).is_greater(AI._threat_reach_of(state, enemy))
	# Control: the enemy really does cover some of the tiles the Builder could reach.
	var covered: int = 0
	for r: Movement.ReachableTile in Movement.reachable(state, b):
		if AI._tile_in_enemy_reach(state, r.tile, 0):
			covered += 1
	assert_int(covered).is_greater(0)
