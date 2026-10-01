# Crew Shot (2026-10-01, user direction): the Lightless Marksman shoots a vehicle's PILOT from
# range, killing most pilots outright and leaving the vehicle empty for a Pirate to capture.
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
		p.current_ap = 99
		p.current_credits = 99999
	return state


func _unit(state: GameState, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


## An enemy Tank at (8, 5) crewed by an off-board Pilot.
func _crewed_tank(state: GameState) -> UnitState:
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(8, 5))
	var pilot := UnitState.new()
	pilot.entity_id = 900
	pilot.owner = 1
	pilot.type = UnitTypes.PILOT
	pilot.current_hp = UnitTypes.PILOT.hp
	tank.pilot = pilot
	return tank


func _shot(unit: UnitState, tile: Vector2i) -> UseAbilityAction:
	var a := UseAbilityAction.new()
	a.player = unit.owner
	a.unit_id = unit.entity_id
	a.ability = Abilities.CREW_SHOT
	a.target_tile = tile
	return a


func test_the_marksman_carries_crew_shot() -> void:
	assert_bool(Abilities.CREW_SHOT in UnitTypes.MARKSMAN.abilities).is_true()


func test_crew_shot_kills_a_pilot_from_range_and_leaves_the_vehicle_whole() -> void:
	var state := _state()
	var marksman := _unit(state, 0, UnitTypes.MARKSMAN, Vector2i(4, 5))   # 4 tiles away
	var tank := _crewed_tank(state)
	var hp_before: int = tank.current_hp
	assert_bool(state.apply_action(_shot(marksman, tank.position)).ok).is_true()
	assert_object(tank.pilot).is_null()
	assert_int(tank.current_hp).is_equal(hp_before)


func test_crew_shot_needs_an_enemy_vehicle_with_a_pilot() -> void:
	var state := _state()
	var marksman := _unit(state, 0, UnitTypes.MARKSMAN, Vector2i(4, 5))
	var empty_tank := _unit(state, 1, UnitTypes.TANK, Vector2i(6, 5))
	var trooper := _unit(state, 1, UnitTypes.TROOPER, Vector2i(5, 6))
	assert_int(Ability.validate(state, _shot(marksman, empty_tank.position))).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int(Ability.validate(state, _shot(marksman, trooper.position))).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_crew_shot_is_out_of_range_beyond_four_tiles() -> void:
	var state := _state()
	var marksman := _unit(state, 0, UnitTypes.MARKSMAN, Vector2i(3, 5))   # 5 tiles away
	var tank := _crewed_tank(state)
	assert_int(Ability.validate(state, _shot(marksman, tank.position))).is_equal(Action.Reason.OUT_OF_RANGE)


func test_a_pirate_can_take_the_vehicle_crew_shot_emptied() -> void:
	var state := _state()
	var marksman := _unit(state, 0, UnitTypes.MARKSMAN, Vector2i(4, 5))
	var pirate := _unit(state, 0, UnitTypes.PIRATE, Vector2i(7, 5))
	var tank := _crewed_tank(state)
	state.apply_action(_shot(marksman, tank.position))
	var capture := UseAbilityAction.new()
	capture.player = 0
	capture.unit_id = pirate.entity_id
	capture.ability = Abilities.CAPTURE_VEHICLE
	capture.target_tile = tank.position
	assert_bool(state.apply_action(capture).ok).is_true()
	assert_int(tank.owner).is_equal(0)
