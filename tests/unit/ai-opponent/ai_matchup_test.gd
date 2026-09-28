# Faction-aware AI (faction-identity.md OQ-15): the AI values a unit by what it can hit in THIS
# matchup, wants pilots when it has vehicles to crew, and plays the Pirate's steal.
extends GdUnitTestSuite

const GRID_SIZE: int = 12


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
	for i: int in 2:
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_ap = 20
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


func test_anti_armour_is_worth_little_against_infantry_and_a_lot_against_armour() -> void:
	var vs_infantry := _state()
	for x: int in 4:
		_unit(vs_infantry, 1, UnitTypes.TROOPER, Vector2i(x, 8))
	var vs_armour := _state()
	for x: int in 2:
		_unit(vs_armour, 1, UnitTypes.TANK, Vector2i(x * 2, 8))
	var lance_inf: float = AI._matchup_multiplier(vs_infantry, 0, UnitTypes.LANCE_SPECIALIST)
	var lance_arm: float = AI._matchup_multiplier(vs_armour, 0, UnitTypes.LANCE_SPECIALIST)
	var sniper_inf: float = AI._matchup_multiplier(vs_infantry, 0, UnitTypes.SNIPER)
	assert_float(lance_inf).override_failure_message("Lance vs infantry should sit at the floor.").is_equal_approx(AIBalance.ai.matchup_floor, 0.001)
	assert_float(lance_arm).is_greater(lance_inf)
	assert_float(sniper_inf).is_greater(lance_inf)


func test_an_empty_vehicle_makes_pilots_wanted() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(5, 8))
	var before: float = AI._matchup_multiplier(state, 0, UnitTypes.PILOT)
	_unit(state, 0, UnitTypes.GUN_TRUCK, Vector2i(5, 2))   # ours, nobody in it
	assert_float(AI._matchup_multiplier(state, 0, UnitTypes.PILOT)).is_equal_approx(
		before + AIBalance.ai.crew_need_bonus, 0.001)
	assert_float(AI._matchup_multiplier(state, 0, UnitTypes.CITIZEN_TROOPER)).override_failure_message(
		"A unit that cannot pilot got the crew bonus.").is_less(before + AIBalance.ai.crew_need_bonus)


func test_unarmed_units_are_not_judged_by_damage() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(5, 8))
	assert_float(AI._matchup_multiplier(state, 0, UnitTypes.BUILDER)).is_equal_approx(1.0, 0.001)


func test_a_pirate_values_killing_a_crew_as_a_steal() -> void:
	var state := _state()
	var pirate := _unit(state, 0, UnitTypes.PIRATE, Vector2i(3, 3))
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(4, 3))
	var crew := UnitState.new()
	crew.owner = 1
	crew.type = UnitTypes.SCOUT   # 3 hp: the Pirate's 3 attack kills it
	crew.current_hp = UnitTypes.SCOUT.hp
	tank.pilot = crew
	var c: AI._Candidate = AI._consider_attack(state, pirate, tank, pirate.position, tank.position,
		Combat.attack_cost_for(pirate), AI._Candidate.new())
	var plain_type: UnitTypeDef = UnitTypes.PIRATE.duplicate()
	plain_type.targets_crew = false
	pirate.type = plain_type
	var d: AI._Candidate = AI._consider_attack(state, pirate, tank, pirate.position, tank.position,
		Combat.attack_cost_for(pirate), AI._Candidate.new())
	assert_float(c.score).override_failure_message(
		"Killing the crew (and leaving a tank to steal) should beat chipping the hull.").is_greater(d.score)


func test_a_pirate_walks_toward_an_empty_enemy_vehicle() -> void:
	var state := _state()
	var pirate := _unit(state, 0, UnitTypes.PIRATE, Vector2i(2, 5))
	_unit(state, 1, UnitTypes.TANK, Vector2i(5, 5))   # empty
	var best: AI._Candidate = AI._score_crewing_candidates(state, pirate, AI._Candidate.new())
	assert_bool(best.action is MoveAction).is_true()
	assert_int(state.grid.manhattan_distance((best.action as MoveAction).to, Vector2i(5, 5))).is_equal(1)


func _crewed_transport(state: GameState, owner: int, pos: Vector2i) -> UnitState:
	var t := _unit(state, owner, UnitTypes.TRANSPORT, pos)
	var pilot := UnitState.new()
	pilot.entity_id = 800 + t.entity_id
	pilot.owner = owner
	pilot.type = UnitTypes.TROOPER
	pilot.current_hp = UnitTypes.TROOPER.hp
	t.pilot = pilot
	return t


func test_far_infantry_boards_a_transport() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(11, 11))   # enemy far away
	var tr := _crewed_transport(state, 0, Vector2i(1, 1))
	var inf := _unit(state, 0, UnitTypes.TROOPER, Vector2i(1, 2))
	var best: AI._Candidate = AI._score_transport_candidates(state, inf, AI._Candidate.new())
	assert_bool(best.action is UseAbilityAction).is_true()
	assert_object((best.action as UseAbilityAction).ability).is_same(Abilities.EMBARK)
	assert_bool(state.apply_action(best.action).ok).is_true()
	assert_bool(tr.cargo.has(inf)).is_true()


func test_infantry_near_the_fight_does_not_board() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(1, 5))
	_crewed_transport(state, 0, Vector2i(1, 1))
	var inf := _unit(state, 0, UnitTypes.TROOPER, Vector2i(1, 2))
	assert_object(AI._score_transport_candidates(state, inf, AI._Candidate.new()).action).is_null()


func test_a_loaded_transport_unloads_near_the_enemy_not_far_from_it() -> void:
	var state := _state()
	var enemy := _unit(state, 1, UnitTypes.TROOPER, Vector2i(10, 5))
	var tr := _crewed_transport(state, 0, Vector2i(2, 5))
	var rider := UnitState.new()
	rider.entity_id = 900
	rider.owner = 0
	rider.type = UnitTypes.TROOPER
	rider.current_hp = UnitTypes.TROOPER.hp
	tr.cargo.append(rider)
	assert_object(AI._score_transport_candidates(state, tr, AI._Candidate.new()).action).override_failure_message(
		"Unloaded while the enemy was 8 tiles away.").is_null()
	state.grid.remove(enemy.position.x, enemy.position.y)
	enemy.position = Vector2i(5, 5)
	state.grid.place(enemy.entity_id, 5, 5)
	var best: AI._Candidate = AI._score_transport_candidates(state, tr, AI._Candidate.new())
	assert_bool(best.action is UseAbilityAction).is_true()
	assert_object((best.action as UseAbilityAction).ability).is_same(Abilities.DISEMBARK)


func test_a_battered_army_wants_medics_more() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(10, 10))
	var a := _unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 2))
	var fresh: float = AI._matchup_multiplier(state, 0, UnitTypes.MEDIC)
	a.current_hp = 3
	assert_float(AI._matchup_multiplier(state, 0, UnitTypes.MEDIC)).is_greater(fresh)


func test_transports_are_wanted_while_infantry_is_far_from_the_fight() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(11, 11))
	var inf := _unit(state, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var far: float = AI._matchup_multiplier(state, 0, UnitTypes.TRANSPORT)
	state.grid.remove(0, 0)
	inf.position = Vector2i(10, 11)
	state.grid.place(inf.entity_id, 10, 11)
	assert_float(AI._matchup_multiplier(state, 0, UnitTypes.TRANSPORT)).is_less(far)


func test_a_lone_unit_will_not_walk_into_enemy_guns() -> void:
	var state := _state()
	var sniper := _unit(state, 1, UnitTypes.SNIPER, Vector2i(6, 5))   # reach 3 + 3
	var scout := _unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 5))
	assert_bool(AI._advance_is_premature(state, scout, Vector2i(2, 5))).override_failure_message(
		"A lone Scout was allowed to step into a Sniper's reach.").is_true()
	assert_bool(AI._advance_is_premature(state, scout, Vector2i(0, 0))).is_false()   # out of reach


func test_a_group_may_advance_together() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.SNIPER, Vector2i(6, 5))
	var scout := _unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 5))
	_unit(state, 0, UnitTypes.TROOPER, Vector2i(1, 4))
	assert_bool(AI._advance_is_premature(state, scout, Vector2i(2, 5))).is_false()
