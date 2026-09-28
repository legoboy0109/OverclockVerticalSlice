# Unit abilities (design/gdd/unit-abilities.md) and Transport & Pilots
# (design/gdd/transport-and-pilots.md). Every ability goes through apply_action (AB-4), so
# these drive the real verb rather than calling Ability internals.
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
		state.per_player[i].current_ap = 99
		state.per_player[i].current_credits = 5000
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


func _use(state: GameState, unit: UnitState, ability: AbilityDef, tile: Vector2i, passenger: UnitState = null) -> ActionResult:
	var a := UseAbilityAction.new()
	a.player = unit.owner
	a.unit_id = unit.entity_id
	a.ability = ability
	a.target_tile = tile
	a.passenger_id = passenger.entity_id if passenger != null else -1
	return state.apply_action(a)


func _crew(state: GameState, vehicle: UnitState) -> UnitState:
	var pilot := _unit(state, vehicle.owner, UnitTypes.TROOPER, vehicle.position + Vector2i(0, 1))
	assert_bool(_use(state, pilot, Abilities.EMBARK, vehicle.position).ok).override_failure_message(
		"Fixture: could not crew the vehicle.").is_true()
	return pilot


func _reaches_anything(state: GameState, unit: UnitState) -> bool:
	return not Movement.reachable(state, unit).is_empty()


# --- Pilots (TP-5) -----------------------------------------------------------------

func test_every_ground_vehicle_needs_a_pilot() -> void:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE:
			assert_bool(t.requires_pilot).override_failure_message("%s drives itself (TP-5a)." % t.display_name).is_true()


func test_an_unpiloted_vehicle_cannot_move_or_attack() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 3))
	assert_bool(_reaches_anything(state, tank)).is_false()
	assert_array(Combat.legal_targets(state, tank)).is_empty()
	_crew(state, tank)
	assert_bool(_reaches_anything(state, tank)).is_true()
	assert_int(Combat.legal_targets(state, tank).size()).is_equal(1)


func test_a_pilot_leaves_the_board_and_still_counts_toward_the_cap() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	var pilot := _unit(state, 0, UnitTypes.TROOPER, Vector2i(3, 4))
	var pop: int = Population.current_population(state, 0)
	assert_bool(_use(state, pilot, Abilities.EMBARK, tank.position).ok).is_true()
	assert_object(tank.pilot).is_same(pilot)
	assert_bool(state.entities_by_id.has(pilot.entity_id)).is_false()
	assert_int(state.grid.occupant_at(3, 4)).is_equal(GridState.EMPTY_OCCUPANT)
	assert_int(Population.current_population(state, 0)).is_equal(pop)


func test_only_pilots_can_crew() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	var heavy := _unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 4))   # can_pilot = false
	assert_bool(_use(state, heavy, Abilities.EMBARK, tank.position).ok).is_false()


func test_a_crewed_vehicle_passenger_still_pays_upkeep() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	var before: int = Upkeep.total_upkeep(state, 0)
	_crew(state, tank)
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(before + UnitTypes.TROOPER.upkeep)


# --- Transport (TP-1..TP-4) --------------------------------------------------------

func test_a_transport_carries_infantry_up_to_capacity() -> void:
	var state := _state()
	var tr := _unit(state, 0, UnitTypes.TRANSPORT, Vector2i(5, 5))
	_crew(state, tr)
	var riders: Array[UnitState] = []
	for p: Vector2i in [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4)]:
		riders.append(_unit(state, 0, UnitTypes.SCOUT, p))
	for r: UnitState in riders:
		assert_bool(_use(state, r, Abilities.EMBARK, tr.position).ok).is_true()
	assert_int(tr.cargo.size()).is_equal(3)
	var fourth := _unit(state, 0, UnitTypes.SCOUT, Vector2i(5, 4))
	assert_int(_use(state, fourth, Abilities.EMBARK, tr.position).reason).is_equal(Action.Reason.TRANSPORT_FULL)


func test_a_transport_refuses_classes_it_does_not_carry() -> void:
	var state := _state()
	var tr := _unit(state, 0, UnitTypes.TRANSPORT, Vector2i(5, 5))
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(5, 6))
	_crew(state, tank)
	assert_int(_use(state, tank, Abilities.EMBARK, tr.position).reason).is_equal(Action.Reason.TRANSPORT_FULL)


func test_disembarking_places_the_unit_and_ends_its_turn() -> void:
	var state := _state()
	var tr := _unit(state, 0, UnitTypes.TRANSPORT, Vector2i(5, 5))
	var rider := _unit(state, 0, UnitTypes.SCOUT, Vector2i(4, 5))
	_use(state, rider, Abilities.EMBARK, tr.position)
	state.start_turn(0)   # a new turn, so it may leave (TP-3)
	assert_bool(_use(state, tr, Abilities.DISEMBARK, Vector2i(6, 5), rider).ok).is_true()
	assert_object(state.entity_at(Vector2i(6, 5))).is_same(rider)
	assert_bool(_reaches_anything(state, rider)).override_failure_message(
		"A unit that disembarked could still move (TP-3).").is_false()


func test_no_embark_and_disembark_in_the_same_turn() -> void:
	var state := _state()
	var tr := _unit(state, 0, UnitTypes.TRANSPORT, Vector2i(5, 5))
	var rider := _unit(state, 0, UnitTypes.SCOUT, Vector2i(4, 5))
	_use(state, rider, Abilities.EMBARK, tr.position)
	assert_int(_use(state, tr, Abilities.DISEMBARK, Vector2i(6, 5), rider).reason).is_equal(Action.Reason.ALREADY_ACTED)


func test_a_pilot_leaving_leaves_the_vehicle_inert() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	var pilot := _crew(state, tank)
	state.start_turn(0)
	assert_bool(_use(state, tank, Abilities.DISEMBARK, Vector2i(2, 3), pilot).ok).is_true()
	assert_object(tank.pilot).is_null()
	assert_bool(_reaches_anything(state, tank)).is_false()


func test_destroying_a_transport_kills_everyone_inside() -> void:
	var state := _state()
	var tr := _unit(state, 0, UnitTypes.TRANSPORT, Vector2i(5, 5))
	_crew(state, tr)
	var rider := _unit(state, 0, UnitTypes.SCOUT, Vector2i(4, 5))
	_use(state, rider, Abilities.EMBARK, tr.position)
	var pop: int = Population.current_population(state, 0)
	state.destroy_entity(tr.entity_id)
	assert_int(Population.current_population(state, 0)).is_equal(pop - 2)


func test_clone_carries_the_passengers() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	_crew(state, tank)
	var copy := state.clone()
	var copy_tank: UnitState = copy.entities_by_id[tank.entity_id]
	assert_object(copy_tank.pilot).is_not_null()
	assert_object(copy_tank.pilot).is_not_same(tank.pilot)


# --- Crew attacks and capture (TP-7, TP-8) ------------------------------------------

func test_a_crew_targeting_attack_kills_the_pilot_and_spares_the_vehicle() -> void:
	var state := _state()
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(4, 3))
	var pilot := _unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 4))  # 3 hp
	state.active_player = 1
	_use(state, pilot, Abilities.EMBARK, tank.position)
	state.active_player = 0
	var pirate_type: UnitTypeDef = UnitTypes.TROOPER.duplicate()
	pirate_type.targets_crew = true
	pirate_type.attack = 5
	_unit(state, 0, pirate_type, Vector2i(3, 3))
	var a := AttackAction.new()
	a.player = 0
	a.attacker_tile = Vector2i(3, 3)
	a.target_tile = tank.position
	assert_bool(state.apply_action(a).ok).is_true()
	assert_object(tank.pilot).is_null()
	assert_int(tank.current_hp).is_equal(UnitTypes.TANK.hp)


func test_capture_takes_an_empty_enemy_vehicle() -> void:
	var state := _state()
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(4, 3))
	var pirate_type: UnitTypeDef = UnitTypes.TROOPER.duplicate()
	pirate_type.abilities = [Abilities.CAPTURE_VEHICLE]
	var pirate := _unit(state, 0, pirate_type, Vector2i(3, 3))
	assert_bool(_use(state, pirate, Abilities.CAPTURE_VEHICLE, tank.position).ok).is_true()
	assert_int(tank.owner).is_equal(0)
	assert_object(tank.pilot).is_same(pirate)


func test_capture_needs_the_vehicle_empty() -> void:
	var state := _state()
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(4, 3))
	state.active_player = 1
	_crew(state, tank)
	state.active_player = 0
	var pirate_type: UnitTypeDef = UnitTypes.TROOPER.duplicate()
	pirate_type.abilities = [Abilities.CAPTURE_VEHICLE]
	var pirate := _unit(state, 0, pirate_type, Vector2i(3, 3))
	assert_bool(_use(state, pirate, Abilities.CAPTURE_VEHICLE, tank.position).ok).is_false()


# --- The catalogue --------------------------------------------------------------------

func test_every_ability_costs_ap() -> void:
	for a: AbilityDef in Abilities.ALL:
		assert_int(a.ap_cost).override_failure_message("%s is free (AB-3)." % a.display_name).is_greater_equal(1)


func test_repair_heals_capped_and_costs_credits() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(3, 3))
	var hurt := _unit(state, 0, UnitTypes.TROOPER, Vector2i(4, 3))
	hurt.current_hp = 5
	var credits: int = state.per_player[0].current_credits
	assert_bool(_use(state, builder, Abilities.REPAIR, hurt.position).ok).is_true()
	assert_int(hurt.current_hp).is_equal(UnitTypes.TROOPER.hp)   # capped, not 9
	assert_int(state.per_player[0].current_credits).is_equal(credits - Abilities.REPAIR.credit_cost)


func test_repair_refuses_a_full_unit_itself_and_an_enemy() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(3, 3))
	var full := _unit(state, 0, UnitTypes.TROOPER, Vector2i(4, 3))
	var enemy := _unit(state, 1, UnitTypes.TROOPER, Vector2i(2, 3))
	enemy.current_hp = 1
	builder.current_hp = 1
	assert_bool(_use(state, builder, Abilities.REPAIR, full.position).ok).is_false()
	assert_bool(_use(state, builder, Abilities.REPAIR, enemy.position).ok).is_false()
	assert_bool(_use(state, builder, Abilities.REPAIR, builder.position).ok).is_false()


func test_an_ability_and_an_attack_exclude_each_other() -> void:
	var state := _state()
	var heavy := _unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 3))
	assert_bool(_use(state, heavy, Abilities.FORTIFY, heavy.position).ok).is_true()
	var a := AttackAction.new()
	a.player = 0
	a.attacker_tile = heavy.position
	a.target_tile = Vector2i(4, 3)
	assert_bool(state.apply_action(a).ok).is_false()


func test_fortify_adds_defence_until_the_unit_moves() -> void:
	var state := _state()
	var heavy := _unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	var base: int = Unit.effective_defense(state, heavy)
	_use(state, heavy, Abilities.FORTIFY, heavy.position)
	assert_int(Unit.effective_defense(state, heavy)).is_equal(base + Abilities.FORTIFY.amount)
	var m := MoveAction.new()
	m.player = 0
	m.from = heavy.position
	m.to = Vector2i(3, 4)
	m.tiles_entered = 1
	assert_bool(state.apply_action(m).ok).is_true()
	assert_int(Unit.effective_defense(state, heavy)).is_equal(base)


func test_fortify_wears_off_at_its_owners_next_turn() -> void:
	var state := _state()
	var heavy := _unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	_use(state, heavy, Abilities.FORTIFY, heavy.position)
	state.start_turn(1)
	assert_int(heavy.fortify).is_equal(Abilities.FORTIFY.amount)   # holds through the enemy turn
	state.start_turn(0)
	assert_int(heavy.fortify).is_equal(0)


func test_demolish_hits_structures_only_and_harder() -> void:
	var state := _state()
	var sapper_type: UnitTypeDef = UnitTypes.TROOPER.duplicate()
	sapper_type.abilities = [Abilities.DEMOLISH]
	var sapper := _unit(state, 0, sapper_type, Vector2i(3, 3))
	var enemy := _unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 4))
	var hq := StructureState.new()
	hq.entity_id = 70
	hq.owner = 1
	hq.position = Vector2i(4, 3)
	hq.type = StructureTypes.HQ
	hq.current_hp = 40
	hq.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[70] = hq
	state.grid.place(70, 4, 3)
	assert_bool(_use(state, sapper, Abilities.DEMOLISH, enemy.position).ok).is_false()
	var plain: int = Combat.damage(state, sapper, hq)
	assert_bool(_use(state, sapper, Abilities.DEMOLISH, hq.position).ok).is_true()
	assert_int(40 - hq.current_hp).is_equal(plain + Abilities.DEMOLISH.amount)


func test_self_destruct_hits_friends_and_foes_and_is_once_only() -> void:
	var state := _state()
	var bomber_type: UnitTypeDef = UnitTypes.SCOUT.duplicate()
	bomber_type.abilities = [Abilities.SELF_DESTRUCT]
	var boom := _unit(state, 0, bomber_type, Vector2i(5, 5))
	var friend := _unit(state, 0, UnitTypes.HEAVY, Vector2i(5, 4))
	var foe := _unit(state, 1, UnitTypes.HEAVY, Vector2i(6, 5))
	assert_bool(_use(state, boom, Abilities.SELF_DESTRUCT, boom.position).ok).is_true()
	assert_bool(state.entities_by_id.has(boom.entity_id)).is_false()
	assert_int(friend.current_hp).is_less(UnitTypes.HEAVY.hp)
	assert_int(foe.current_hp).is_less(UnitTypes.HEAVY.hp)


func test_paradrop_lands_a_passenger_up_to_three_tiles_away() -> void:
	var state := _state()
	var plane_type: UnitTypeDef = UnitTypes.TRANSPORT.duplicate()
	plane_type.abilities = [Abilities.PARADROP]
	var tr := _unit(state, 0, plane_type, Vector2i(5, 5))
	_crew(state, tr)
	var jumper := _unit(state, 0, UnitTypes.SCOUT, Vector2i(4, 5))
	_use(state, jumper, Abilities.EMBARK, tr.position)
	assert_bool(_use(state, tr, Abilities.PARADROP, Vector2i(5, 8), jumper).ok).is_true()
	assert_object(state.entity_at(Vector2i(5, 8))).is_same(jumper)
	assert_bool(_use(state, tr, Abilities.PARADROP, Vector2i(5, 2), jumper).ok).is_false()


func test_a_cooldown_blocks_reuse_until_it_ticks_down() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(3, 3))
	var hurt := _unit(state, 0, UnitTypes.HEAVY, Vector2i(4, 3))
	hurt.current_hp = 1
	_use(state, builder, Abilities.REPAIR, hurt.position)
	state.start_turn(1)
	state.start_turn(0)   # cooldown 1 ticks to 0 at the owner's next turn
	assert_bool(_use(state, builder, Abilities.REPAIR, hurt.position).ok).is_true()


func test_legal_targets_agree_with_validate() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(3, 3))
	var hurt := _unit(state, 0, UnitTypes.TROOPER, Vector2i(4, 3))
	hurt.current_hp = 2
	_unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 3))   # full hp: not a target
	assert_array(Ability.legal_targets(state, builder, Abilities.REPAIR)).is_equal([Vector2i(4, 3)])


# --- AI --------------------------------------------------------------------------------

func test_the_ai_crews_its_empty_vehicle() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(3, 3))
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(3, 4))
	var best: AI._Candidate = AI._score_crewing_candidates(state, trooper, AI._Candidate.new())
	assert_bool(best.action is UseAbilityAction).is_true()
	assert_object((best.action as UseAbilityAction).ability).is_same(Abilities.EMBARK)
	assert_bool(state.apply_action(best.action).ok).is_true()
	assert_object(tank.pilot).is_same(trooper)


func test_the_ai_repairs_a_damaged_neighbour() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(3, 3))
	var hurt := _unit(state, 0, UnitTypes.HEAVY, Vector2i(4, 3))
	hurt.current_hp = 3
	var best: AI._Candidate = AI._score_ability_candidates(state, builder, AI._Candidate.new())
	assert_bool(best.action is UseAbilityAction).is_true()
	assert_object((best.action as UseAbilityAction).ability).is_same(Abilities.REPAIR)


func test_the_ai_fortifies_only_under_threat() -> void:
	var state := _state()
	var heavy := _unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	assert_object(AI._score_ability_candidates(state, heavy, AI._Candidate.new()).action).is_null()
	_unit(state, 1, UnitTypes.SNIPER, Vector2i(3, 6))
	var best: AI._Candidate = AI._score_ability_candidates(state, heavy, AI._Candidate.new())
	assert_object((best.action as UseAbilityAction).ability).is_same(Abilities.FORTIFY)
