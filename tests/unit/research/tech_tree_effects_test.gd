# Tech-tree effects (2026-10-01, user-approved draft "Overclock Tech Trees"). Each test builds a
# throwaway TechDef carrying ONE effect, marks it researched, and checks the rule it changes —
# so every effect is proven independently of the authored tree data.
extends GdUnitTestSuite

const SIZE: int = 12


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


func _tech(field: StringName, value: Variant) -> TechDef:
	var t := TechDef.new()
	t.display_name = "Test %s" % field
	t.set(field, value)
	return t


func _grant(state: GameState, t: TechDef, player: int = 0) -> void:
	state.per_player[player].completed_techs.append(t)
	Research.refresh_bonuses(state, player)


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


func _structure(state: GameState, owner: int, type: StructureTypeDef, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = owner
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


# --- Movement --------------------------------------------------------------------------------

func test_effect_move_cap_bonus_raises_the_surcharge_threshold() -> void:
	var s := _state()
	var u := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Unit.soft_move_cap(u)
	_grant(s, _tech(&"move_cap_bonus", 1))
	assert_int(Unit.soft_move_cap(u)).is_equal(before + 1)


func test_effect_vehicle_move_cap_bonus_skips_infantry() -> void:
	var s := _state()
	var inf := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(4, 4))
	var i0: int = Unit.soft_move_cap(inf)
	var t0: int = Unit.soft_move_cap(tank)
	_grant(s, _tech(&"vehicle_move_cap_bonus", 2))
	assert_int(Unit.soft_move_cap(inf)).is_equal(i0)
	assert_int(Unit.soft_move_cap(tank)).is_equal(t0 + 2)


func test_effect_infantry_move_cost_discount_floors_at_one() -> void:
	var s := _state()
	_grant(s, _tech(&"infantry_move_cost_discount", 9))
	assert_int(Unit.effective_move_cost(s, UnitTypes.TROOPER, 0)).is_equal(Unit.MIN_MOVE_COST)


# Regression (2026-10-01 sims): Infiltrators once changed only effective_move_cost, which Movement
# never calls, so the tech did nothing in play. Check the cost Movement actually bills.
func test_effect_infantry_move_cost_discount_reduces_billed_move_cost() -> void:
	var s := _state()
	var inf := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(4, 4))
	var i0: int = Movement.move_path_cost(inf, 1)
	var t0: int = Movement.move_path_cost(tank, 1)
	_grant(s, _tech(&"infantry_move_cost_discount", 1))
	assert_int(Movement.move_path_cost(inf, 1)).is_equal(i0 - 1)
	assert_int(Movement.move_path_cost(tank, 1)).is_equal(t0)


# --- Attack ----------------------------------------------------------------------------------

func test_effect_infantry_attack_bonus_reaches_infantry_only() -> void:
	var s := _state()
	var inf := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(4, 4))
	var i0: int = Unit.effective_attack(s, inf)
	var t0: int = Unit.effective_attack(s, tank)
	_grant(s, _tech(&"infantry_attack_bonus", 1))
	assert_int(Unit.effective_attack(s, inf)).is_equal(i0 + 1)
	assert_int(Unit.effective_attack(s, tank)).is_equal(t0)


func test_effect_attack_vs_armor_and_vs_infantry_pick_the_target_class() -> void:
	var s := _state()
	var a := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(s, 1, UnitTypes.TANK, Vector2i(3, 2))
	var inf := _unit(s, 1, UnitTypes.TROOPER, Vector2i(2, 3))
	var vs_tank: int = Combat.damage(s, a, tank)
	var vs_inf: int = Combat.damage(s, a, inf)
	_grant(s, _tech(&"attack_vs_armor", 2))
	assert_int(Combat.damage(s, a, tank)).is_equal(vs_tank + 2)
	assert_int(Combat.damage(s, a, inf)).is_equal(vs_inf)
	_grant(s, _tech(&"attack_vs_infantry", 2))
	assert_int(Combat.damage(s, a, inf)).is_equal(vs_inf + 2)


func test_effect_infantry_attack_vs_structures() -> void:
	var s := _state()
	var a := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var hq := _structure(s, 1, StructureTypes.FACTORY, Vector2i(3, 2))
	var before: int = Combat.damage(s, a, hq)
	_grant(s, _tech(&"infantry_attack_vs_structures", 3))
	assert_int(Combat.damage(s, a, hq)).is_equal(before + 3)


func test_effect_vehicle_range_bonus_is_ground_vehicles_only() -> void:
	var s := _state()
	var r_tank: int = Unit.effective_type_attack_range(s, UnitTypes.TANK, 0)
	var r_inf: int = Unit.effective_type_attack_range(s, UnitTypes.TROOPER, 0)
	_grant(s, _tech(&"vehicle_range_bonus", 1))
	assert_int(Unit.effective_type_attack_range(s, UnitTypes.TANK, 0)).is_equal(r_tank + 1)
	assert_int(Unit.effective_type_attack_range(s, UnitTypes.TROOPER, 0)).is_equal(r_inf)


func test_effect_attack_ap_discount_floors_at_one() -> void:
	var s := _state()
	var u := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Combat.attack_cost_for(u)
	_grant(s, _tech(&"attack_ap_discount", 1))
	assert_int(Combat.attack_cost_for(u)).is_equal(maxi(1, before - 1))


func test_effect_aircraft_attack_bonus() -> void:
	var s := _state()
	var heli := _unit(s, 0, UnitTypes.HELICOPTER, Vector2i(2, 2))
	var before: int = Unit.effective_attack(s, heli)
	_grant(s, _tech(&"aircraft_attack_bonus", 1))
	assert_int(Unit.effective_attack(s, heli)).is_equal(before + 1)


# --- Cover -----------------------------------------------------------------------------------

func _cover_state() -> GameState:
	var s := _state()
	s.grid.terrain[s.grid.index(3, 2)] = GridState.Terrain.COVER
	return s


func test_effect_cover_heal_heals_only_units_in_cover() -> void:
	var s := _cover_state()
	var covered := _unit(s, 0, UnitTypes.TROOPER, Vector2i(3, 2))
	var open := _unit(s, 0, UnitTypes.TROOPER, Vector2i(5, 5))
	covered.current_hp = 2
	open.current_hp = 2
	covered.tiles_moved_this_turn = 1   # moved: Field Repair would not apply, Dig In still does
	open.tiles_moved_this_turn = 1
	_grant(s, _tech(&"cover_heal", 1))
	Research.apply_idle_healing(s, 0)
	assert_int(covered.current_hp).is_equal(3)
	assert_int(open.current_hp).is_equal(2)


func test_effect_infantry_cover_attack() -> void:
	var s := _cover_state()
	var a := _unit(s, 1, UnitTypes.TROOPER, Vector2i(2, 2))
	var d := _unit(s, 0, UnitTypes.TROOPER, Vector2i(3, 2))
	# The covered unit attacking out of Cover gets Ambush.
	var out_before: int = Combat.damage(s, d, a)
	_grant(s, _tech(&"infantry_cover_attack", 2))
	assert_int(Combat.damage(s, d, a)).is_equal(out_before + 2)


# --- HP ----------------------------------------------------------------------------------------

func test_effect_hp_bonuses_raise_max_and_current_hp_by_class() -> void:
	var s := _state()
	var inf := _unit(s, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(4, 4))
	_grant(s, _tech(&"infantry_hp_bonus", 2))
	assert_int(Unit.effective_max_hp(inf)).is_equal(UnitTypes.TROOPER.hp + 2)
	assert_int(inf.current_hp).is_equal(UnitTypes.TROOPER.hp + 2)
	assert_int(Unit.effective_max_hp(tank)).is_equal(UnitTypes.TANK.hp)
	_grant(s, _tech(&"vehicle_hp_bonus", 2))
	assert_int(Unit.effective_max_hp(tank)).is_equal(UnitTypes.TANK.hp + 2)


func test_effect_vehicle_self_repair_heals_after_acting() -> void:
	var s := _state()
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(4, 4))
	tank.current_hp -= 3
	tank.has_attacked = true
	_grant(s, _tech(&"vehicle_self_repair", 1))
	Research.apply_idle_healing(s, 0)
	assert_int(tank.current_hp).is_equal(UnitTypes.TANK.hp - 2)


# --- Structures --------------------------------------------------------------------------------

func test_effect_structure_hp_pct_and_hq_hp_bonus() -> void:
	var s := _state()
	var f := _structure(s, 0, StructureTypes.FACTORY, Vector2i(2, 2))
	var hq := _structure(s, 0, StructureTypes.HQ, Vector2i(6, 6))
	_grant(s, _tech(&"structure_hp_pct", 25))
	assert_int(Structure.effective_max_hp(f)).is_equal(StructureTypes.FACTORY.hp + StructureTypes.FACTORY.hp * 25 / 100)
	assert_int(f.current_hp).is_equal(Structure.effective_max_hp(f))
	_grant(s, _tech(&"hq_hp_bonus", 20))
	assert_int(Structure.effective_max_hp(hq)).is_equal(StructureTypes.HQ.hp + StructureTypes.HQ.hp * 25 / 100 + 20)


func test_effect_structure_defense_and_aura() -> void:
	var s := _state()
	var a := _unit(s, 1, UnitTypes.TROOPER, Vector2i(2, 2))
	var f := _structure(s, 0, StructureTypes.FACTORY, Vector2i(3, 2))
	_structure(s, 0, StructureTypes.RESEARCH_LAB, Vector2i(4, 2))
	var before: int = Combat.damage(s, a, f)
	_grant(s, _tech(&"structure_defense_bonus", 1))
	assert_int(Combat.damage(s, a, f)).is_equal(maxi(CombatBalance.combat.min_damage, before - 1))
	var aura := _tech(&"aura_defense_bonus", 2)
	aura.aura_structures = [StructureTypes.RESEARCH_LAB]
	_grant(s, aura)
	assert_int(Combat.damage(s, a, f)).is_equal(maxi(CombatBalance.combat.min_damage, before - 3))


func test_effect_defensive_structure_attack_range_and_counter() -> void:
	var s := _state()
	# A test copy that does not counter by type, so Overwatch Grid is what turns it on.
	var dt: StructureTypeDef = StructureTypes.DEFENSIVE_STRUCTURE.duplicate()
	dt.can_counterattack = false
	var d := _structure(s, 0, dt, Vector2i(3, 3))
	var r0: int = Unit.effective_attack_range(s, d)
	var a0: int = Combat._effective_attack_for(s, d)
	_grant(s, _tech(&"defensive_attack_bonus", 1))
	_grant(s, _tech(&"defensive_range_bonus", 1))
	assert_int(Combat._effective_attack_for(s, d)).is_equal(a0 + 1)
	assert_int(Unit.effective_attack_range(s, d)).is_equal(r0 + 1)
	assert_bool(Combat._can_counter(s, d)).is_false()
	_grant(s, _tech(&"defensive_counterattack", true))
	assert_bool(Combat._can_counter(s, d)).is_true()


func test_effect_anti_air_lets_structures_target_aircraft() -> void:
	var s := _state()
	var d := _structure(s, 0, StructureTypes.DEFENSIVE_STRUCTURE, Vector2i(3, 3))
	var heli := _unit(s, 1, UnitTypes.HELICOPTER, Vector2i(3, 4))
	assert_bool(Combat.can_target(d, heli, s)).is_false()
	_grant(s, _tech(&"defensive_anti_air", 2))
	assert_bool(Combat.can_target(d, heli, s)).is_true()


func test_effect_hardpoints_arm_the_hq() -> void:
	var s := _state()
	var hq := _structure(s, 0, StructureTypes.HQ, Vector2i(3, 3))
	assert_bool(CommandFSM.has_weapon(hq, s)).is_false()
	var t := _tech(&"hq_attack", 3)
	t.hq_range = 2
	_grant(s, t)
	assert_int(Combat._effective_attack_for(s, hq)).is_equal(3)
	assert_int(Unit.effective_attack_range(s, hq)).is_equal(2)
	assert_bool(CommandFSM.has_weapon(hq, s)).is_true()


func test_effect_build_time_discount_floors_at_one() -> void:
	var s := _state()
	_grant(s, _tech(&"build_time_discount", 9))
	assert_int(BaseProduction.effective_build_time(s, StructureTypes.FACTORY, 0)).is_equal(1)


# --- Logistics ---------------------------------------------------------------------------------

func test_effect_ammo_bonus_only_for_ammo_users() -> void:
	var s := _state()
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(2, 2))
	var inf := _unit(s, 0, UnitTypes.TROOPER, Vector2i(4, 4))
	var m0: int = Ammo.unit_max(tank)
	_grant(s, _tech(&"ammo_bonus", 2))
	assert_int(Ammo.unit_max(tank)).is_equal(m0 + 2)
	assert_int(Ammo.unit_max(inf)).is_equal(0)


func test_effect_resupply_range_and_supply_heal() -> void:
	var s := _state()
	_structure(s, 0, StructureTypes.SUPPLY_DEPOT, Vector2i(5, 5))
	var tank := _unit(s, 0, UnitTypes.TANK, Vector2i(7, 5))   # 2 tiles away
	tank.ammo_spent = 2
	tank.current_hp -= 4
	Ammo.resupply_turn(s, 0)
	assert_int(tank.ammo_spent).is_equal(2)                    # out of reach
	_grant(s, _tech(&"resupply_range", 2))
	_grant(s, _tech(&"supply_heal", 2))
	Ammo.resupply_turn(s, 0)
	assert_int(tank.ammo_spent).is_equal(0)
	assert_int(tank.current_hp).is_equal(UnitTypes.TANK.hp - 2)


func test_effect_depot_and_structure_cost_discounts() -> void:
	var s := _state()
	_grant(s, _tech(&"depot_cost_discount_pct", 50))
	assert_int(BaseProduction.effective_build_cost(s, StructureTypes.SUPPLY_DEPOT, 0)).is_equal(StructureTypes.SUPPLY_DEPOT.build_cost / 2)
	assert_int(BaseProduction.effective_build_cost(s, StructureTypes.FACTORY, 0)).is_equal(StructureTypes.FACTORY.build_cost)
	_grant(s, _tech(&"structure_cost_discount_pct", 25))
	assert_int(BaseProduction.effective_build_cost(s, StructureTypes.FACTORY, 0)).is_equal(StructureTypes.FACTORY.build_cost * 75 / 100)


func test_effect_rush_discount_and_vehicle_half() -> void:
	var s := _state()
	var f := _structure(s, 0, StructureTypes.FACTORY, Vector2i(3, 3))
	f.producing_type = UnitTypes.TANK
	f.production_turns_remaining = 3
	var base: int = Balance.economy.rush_ap_cost
	_grant(s, _tech(&"vehicle_rush_half", true))
	assert_int(BaseProduction.rush_ap_cost(s, f)).is_equal(int(ceil(base / 2.0)))
	_grant(s, _tech(&"rush_ap_discount", 2))
	assert_int(BaseProduction.rush_ap_cost(s, f)).is_equal(maxi(1, int(ceil((base - 2) / 2.0))))


func test_effect_vehicle_production_turn_discount() -> void:
	var s := _state()
	_grant(s, _tech(&"vehicle_production_turn_discount", 1))
	assert_int(BaseProduction.effective_production_turns(s, UnitTypes.TANK, 0)).is_equal(maxi(1, UnitTypes.TANK.production_turns - 1))
	assert_int(BaseProduction.effective_production_turns(s, UnitTypes.TROOPER, 0)).is_equal(UnitTypes.TROOPER.production_turns)


# --- Economy -----------------------------------------------------------------------------------

func test_effect_kill_refund_pays_the_killer() -> void:
	var s := _state()
	var a := _unit(s, 0, UnitTypes.TANK, Vector2i(2, 2))
	if a.type.requires_pilot:
		var pilot := UnitState.new()
		pilot.type = UnitTypes.TROOPER
		pilot.owner = 0
		pilot.current_hp = 5
		a.pilot = pilot
	var victim := _unit(s, 1, UnitTypes.TROOPER, Vector2i(3, 2))
	victim.current_hp = 1
	_grant(s, _tech(&"kill_refund_pct", 20))
	var before: int = s.per_player[0].current_credits
	var act := AttackAction.new()
	act.player = 0
	act.attacker_tile = a.position
	act.target_tile = victim.position
	assert_bool(s.apply_action(act).ok).is_true()
	assert_int(s.per_player[0].current_credits - before).is_equal(
		Unit.effective_produce_cost(s, UnitTypes.TROOPER, 1) * 20 / 100)


func test_effect_ap_per_turn_bonus() -> void:
	var s := _state()
	s.per_player[0].current_ap = 0
	_grant(s, _tech(&"ap_per_turn_bonus", 2))
	AP.reset_turn(s, 0)
	assert_int(s.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn + 2)


func test_effect_upkeep_discount() -> void:
	var s := _state()
	_unit(s, 0, UnitTypes.TANK, Vector2i(2, 2))
	var before: int = Upkeep.total_upkeep(s, 0)
	_grant(s, _tech(&"upkeep_discount_pct", 25))
	assert_int(Upkeep.total_upkeep(s, 0)).is_equal(before * 75 / 100)


func test_effect_pop_cap_and_infantry_cost() -> void:
	var s := _state()
	var cap: int = Population.effective_cap(s, 0)
	var cost: int = Unit.effective_produce_cost(s, UnitTypes.TROOPER, 0)
	_grant(s, _tech(&"pop_cap_bonus", 2))
	assert_int(Population.effective_cap(s, 0)).is_equal(cap + 2)
	_grant(s, _tech(&"infantry_cost_discount_pct", 10))
	assert_int(Unit.effective_produce_cost(s, UnitTypes.TROOPER, 0)).is_equal(maxi(1, cost * 90 / 100))


func test_effect_production_cap_bonus() -> void:
	var s := _state()
	var f := _structure(s, 0, StructureTypes.FACTORY, Vector2i(3, 3))
	var c: int = BaseProduction.effective_production_cap(s, f, 0)
	_grant(s, _tech(&"production_cap_bonus", 1))
	assert_int(BaseProduction.effective_production_cap(s, f, 0)).is_equal(c + 1)


func test_effect_unit_type_bonuses() -> void:
	var s := _state()
	var u := _unit(s, 0, UnitTypes.SCOUT, Vector2i(2, 2))
	var other := _unit(s, 0, UnitTypes.TROOPER, Vector2i(4, 4))
	var t := _tech(&"bonus_unit_attack", 1)
	t.bonus_unit_move_cap = 1
	t.bonus_unit_types = [UnitTypes.SCOUT]
	var a0: int = Unit.effective_attack(s, u)
	var m0: int = Unit.soft_move_cap(u)
	var o0: int = Unit.effective_attack(s, other)
	_grant(s, t)
	assert_int(Unit.effective_attack(s, u)).is_equal(a0 + 1)
	assert_int(Unit.soft_move_cap(u)).is_equal(m0 + 1)
	assert_int(Unit.effective_attack(s, other)).is_equal(o0)
