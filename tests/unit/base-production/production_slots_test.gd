# Production slots (2026-10-01, user decision): Ross Foundry's Barracks hold 2 units in production
# at once, and Assembly Lines gives a vehicle producer a 2nd slot. The primary slot
# (producing_type) is always filled first; extras are promoted into it as it frees.
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
		p.faction = Factions.NEUTRAL
		p.current_ap = 999
		p.current_credits = 999999
	return state


func _structure(state: GameState, type: StructureTypeDef, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _produce(state: GameState, producer: StructureState, type: UnitTypeDef, tile: Vector2i) -> ActionResult:
	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = producer.entity_id
	a.unit_type = type
	a.tile = tile
	return state.apply_action(a)


func _units_of(state: GameState, type: UnitTypeDef) -> int:
	var n: int = 0
	for e: EntityState in state.entities():
		if e is UnitState and e.owner == 0 and (e as UnitState).type == type:
			n += 1
	return n


func test_ross_barracks_have_two_slots_and_others_one() -> void:
	var state := _state()
	assert_int(BaseProduction.production_slots(state, _structure(state, StructureTypes.UNION_BARRACKS, Vector2i(4, 4)))).is_equal(2)
	assert_int(BaseProduction.production_slots(state, _structure(state, StructureTypes.BARRACKS, Vector2i(8, 8)))).is_equal(1)


func test_ross_barracks_build_two_infantry_at_once_and_both_deploy() -> void:
	var state := _state()
	var b := _structure(state, StructureTypes.UNION_BARRACKS, Vector2i(4, 4))
	assert_bool(_produce(state, b, UnitTypes.GUARD, Vector2i(5, 4)).ok).is_true()
	assert_bool(_produce(state, b, UnitTypes.GUARD, Vector2i(3, 4)).ok).is_true()
	assert_int(BaseProduction.units_in_production(b)).is_equal(2)
	# A third is refused: both slots are busy.
	assert_bool(_produce(state, b, UnitTypes.GUARD, Vector2i(4, 5)).ok).is_false()
	for i: int in UnitTypes.GUARD.production_turns:
		BaseProduction.advance_build_timers(state, 0)
	assert_int(_units_of(state, UnitTypes.GUARD)).is_equal(2)
	assert_int(BaseProduction.units_in_production(b)).is_equal(0)


func test_a_one_slot_barracks_still_refuses_a_second_unit() -> void:
	var state := _state()
	var b := _structure(state, StructureTypes.BARRACKS, Vector2i(4, 4))
	assert_bool(_produce(state, b, UnitTypes.TROOPER, Vector2i(5, 4)).ok).is_true()
	assert_bool(_produce(state, b, UnitTypes.TROOPER, Vector2i(3, 4)).ok).is_false()


func test_both_slots_count_against_the_population_cap() -> void:
	var state := _state()
	var b := _structure(state, StructureTypes.UNION_BARRACKS, Vector2i(4, 4))
	var before: int = Population.current_population(state, 0)
	_produce(state, b, UnitTypes.GUARD, Vector2i(5, 4))
	_produce(state, b, UnitTypes.GUARD, Vector2i(3, 4))
	assert_int(Population.current_population(state, 0)).is_equal(before + 2)


func test_cancelling_the_first_unit_promotes_the_second() -> void:
	var state := _state()
	var b := _structure(state, StructureTypes.UNION_BARRACKS, Vector2i(4, 4))
	_produce(state, b, UnitTypes.GUARD, Vector2i(5, 4))
	_produce(state, b, UnitTypes.FOREMAN, Vector2i(3, 4))
	var c := CancelProductionAction.new()
	c.player = 0
	c.producer_id = b.entity_id
	assert_bool(state.apply_action(c).ok).is_true()
	assert_object(b.producing_type).is_same(UnitTypes.FOREMAN)
	assert_int(b.extra_types.size()).is_equal(0)
	assert_object(b.production_tile).is_equal(Vector2i(3, 4))


func test_assembly_lines_gives_a_vehicle_producer_a_second_slot() -> void:
	var state := _state()
	var f := _structure(state, StructureTypes.UNION_FACTORY, Vector2i(4, 4))
	assert_int(BaseProduction.production_slots(state, f)).is_equal(1)
	var t := TechDef.new()
	t.display_name = "Test Assembly Lines"
	t.factory_slot_bonus = 1
	state.per_player[0].completed_techs.append(t)
	assert_int(BaseProduction.production_slots(state, f)).is_equal(2)
	# ...and it does not touch infantry producers.
	assert_int(BaseProduction.production_slots(state, _structure(state, StructureTypes.BARRACKS, Vector2i(9, 9)))).is_equal(1)


func test_extra_slots_survive_a_save_round_trip() -> void:
	var state := _state()
	var b := _structure(state, StructureTypes.UNION_BARRACKS, Vector2i(4, 4))
	_produce(state, b, UnitTypes.GUARD, Vector2i(5, 4))
	_produce(state, b, UnitTypes.FOREMAN, Vector2i(3, 4))
	var loaded: SaveGame.Loaded = SaveGame.from_dict(JSON.parse_string(JSON.stringify(
		SaveGame.to_dict(state, 20, VSMap.data()))))
	var lb: StructureState = loaded.state.entities_by_id[b.entity_id]
	assert_int(lb.extra_types.size()).is_equal(1)
	assert_object(lb.extra_types[0]).is_same(UnitTypes.FOREMAN)
	assert_int(lb.extra_turns[0]).is_equal(b.extra_turns[0])
	assert_int(lb.extra_tiles[0]).is_equal(3)
	assert_int(lb.extra_tiles[1]).is_equal(4)
