# Ammo + resupply (user decision 2026-10-01): vehicles and aircraft carry limited attacks; at 0
# they can't attack (or counter) until refilled at the start of their owner's turn beside an own
# HQ, factory, airfield or Supply Depot. Infantry never use ammo.
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
	return state


## A ground vehicle that fires directly at range 1 or more (crewed by [method _unit] if it
## needs a pilot — every shipped one does).
func _gunner() -> UnitTypeDef:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE \
				and t.attack_range >= 1 and t.min_range <= 1 \
				and t.targeting_mode == UnitTypeDef.TargetingMode.DIRECT \
				and t.can_target.has(UnitTypeDef.UnitClass.GROUND_VEHICLE):
			return t
	return null


func _unit(state: GameState, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = 999   # never dies in these tests — ammo, not damage, is under test
	if type.requires_pilot:
		var pilot := UnitState.new()
		pilot.entity_id = state.next_entity_id + 1000
		pilot.owner = owner
		pilot.type = _pilot_type()
		pilot.current_hp = 999
		u.pilot = pilot
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _pilot_type() -> UnitTypeDef:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.can_pilot:
			return t
	return null


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


func _attack(state: GameState, a: UnitState, t: EntityState) -> ActionResult:
	var act := AttackAction.new()
	act.player = a.owner
	act.attacker_tile = a.position
	act.target_tile = t.position
	return state.apply_action(act)


# --- Who carries ammo ----------------------------------------------------------------------

func test_ammo_class_defaults_vehicles_aircraft_and_unlimited_infantry() -> void:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.max_ammo != -1:
			continue
		if t.attack_range <= 0 or t.can_target.is_empty():
			assert_bool(Ammo.uses_ammo(t)).override_failure_message("unarmed %s" % t.display_name).is_false()
			continue
		match t.unit_class:
			UnitTypeDef.UnitClass.GROUND_VEHICLE:
				assert_int(Ammo.max_ammo(t)).is_equal(CombatBalance.combat.vehicle_ammo)
			UnitTypeDef.UnitClass.AIR:
				assert_int(Ammo.max_ammo(t)).is_equal(CombatBalance.combat.air_ammo)
			_:
				assert_bool(Ammo.uses_ammo(t)).is_false()


# --- Spending ------------------------------------------------------------------------------

func test_ammo_attack_spends_one() -> void:
	var state := _state()
	var a := _unit(state, 0, _gunner(), Vector2i(2, 2))
	var t := _unit(state, 1, _gunner(), Vector2i(3, 2))
	assert_bool(_attack(state, a, t).ok).is_true()
	assert_int(Ammo.remaining(a)).is_equal(Ammo.max_ammo(a.type) - 1)


func test_ammo_empty_unit_cannot_attack_and_says_why() -> void:
	var state := _state()
	var a := _unit(state, 0, _gunner(), Vector2i(2, 2))
	var t := _unit(state, 1, _gunner(), Vector2i(3, 2))
	a.ammo_spent = Ammo.max_ammo(a.type)
	assert_bool(Combat.legal_targets(state, a).is_empty()).is_true()
	var r := _attack(state, a, t)
	assert_bool(r.ok).is_false()
	assert_int(r.reason).is_equal(Action.Reason.OUT_OF_AMMO)


func test_ammo_empty_unit_can_still_move() -> void:
	var state := _state()
	var a := _unit(state, 0, _gunner(), Vector2i(2, 2))
	a.ammo_spent = Ammo.max_ammo(a.type)
	assert_bool(Movement.reachable(state, a).is_empty()).is_false()


func test_ammo_counterattack_spends_and_empty_defender_does_not_counter() -> void:
	# No shipped vehicle counterattacks today, so a test-only copy of one that does stands in:
	# the rule must hold the day one is authored.
	var counter_type: UnitTypeDef = _gunner().duplicate()
	counter_type.can_counterattack = true
	var state := _state()
	var a := _unit(state, 0, _gunner(), Vector2i(2, 2))
	var d := _unit(state, 1, counter_type, Vector2i(3, 2))
	_attack(state, a, d)
	assert_int(d.ammo_spent).is_equal(1)
	assert_int(a.current_hp).is_less(999)   # control: the counter really fired
	# Empty defender: no counter, so the attacker takes no counter damage.
	var state2 := _state()
	var a2 := _unit(state2, 0, _gunner(), Vector2i(2, 2))
	var d2 := _unit(state2, 1, counter_type, Vector2i(3, 2))
	d2.ammo_spent = Ammo.max_ammo(counter_type)
	_attack(state2, a2, d2)
	assert_int(a2.current_hp).is_equal(999)


func test_ammo_infantry_never_spend() -> void:
	var inf: UnitTypeDef = UnitTypes.TROOPER
	var state := _state()
	var a := _unit(state, 0, inf, Vector2i(2, 2))
	Ammo.spend(a)
	assert_int(a.ammo_spent).is_equal(0)
	assert_int(Ammo.remaining(a)).is_equal(-1)


# --- Resupply ------------------------------------------------------------------------------

func test_resupply_refills_units_next_to_an_own_factory_at_turn_start() -> void:
	var state := _state()
	_structure(state, 0, StructureTypes.FACTORY, Vector2i(5, 5))
	var beside := _unit(state, 0, _gunner(), Vector2i(6, 5))
	var far := _unit(state, 0, _gunner(), Vector2i(8, 5))
	beside.ammo_spent = 3
	far.ammo_spent = 3
	var events := Ammo.resupply_turn(state, 0)
	assert_int(beside.ammo_spent).is_equal(0)
	assert_int(far.ammo_spent).is_equal(3)
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is UnitResuppliedEvent).is_true()


func test_resupply_every_adjacent_unit_and_diagonals_do_not_count() -> void:
	var state := _state()
	_structure(state, 0, StructureTypes.SUPPLY_DEPOT, Vector2i(5, 5))
	var units: Array[UnitState] = []
	for p: Vector2i in [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4), Vector2i(5, 6)]:
		var u := _unit(state, 0, _gunner(), p)
		u.ammo_spent = 2
		units.append(u)
	var diag := _unit(state, 0, _gunner(), Vector2i(6, 6))
	diag.ammo_spent = 2
	Ammo.resupply_turn(state, 0)
	for u: UnitState in units:
		assert_int(u.ammo_spent).is_equal(0)
	assert_int(diag.ammo_spent).is_equal(2)


func test_resupply_ignores_enemy_structures_and_construction_sites() -> void:
	var state := _state()
	_structure(state, 1, StructureTypes.FACTORY, Vector2i(5, 5))
	var site := _structure(state, 0, StructureTypes.SUPPLY_DEPOT, Vector2i(9, 9))
	site.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	var a := _unit(state, 0, _gunner(), Vector2i(6, 5))
	var b := _unit(state, 0, _gunner(), Vector2i(9, 8))
	a.ammo_spent = 2
	b.ammo_spent = 2
	Ammo.resupply_turn(state, 0)
	assert_int(a.ammo_spent).is_equal(2)
	assert_int(b.ammo_spent).is_equal(2)


func test_resupply_runs_in_start_turn() -> void:
	var state := _state()
	_structure(state, 0, StructureTypes.HQ, Vector2i(5, 5))
	var a := _unit(state, 0, _gunner(), Vector2i(5, 6))
	a.ammo_spent = 4
	state.start_turn(0)
	assert_int(a.ammo_spent).is_equal(0)


func test_resupply_structures_are_hq_factories_airfields_and_depot() -> void:
	for t: StructureTypeDef in [StructureTypes.HQ, StructureTypes.FACTORY, StructureTypes.AIRFIELD,
			StructureTypes.SUPPLY_DEPOT, StructureTypes.EMPIRE_FACTORY, StructureTypes.UNION_AIRFIELD]:
		assert_bool(t.resupplies).override_failure_message(t.display_name).is_true()
	for t: StructureTypeDef in [StructureTypes.BARRACKS, StructureTypes.RESEARCH_LAB]:
		assert_bool(t.resupplies).is_false()


func test_supply_depot_is_buildable_by_every_playable_faction() -> void:
	for f: FactionDef in Factions.playable():
		var roster: Array = f.structures if not f.structures.is_empty() else StructureTypes.BUILDABLE
		assert_bool(roster.has(StructureTypes.SUPPLY_DEPOT)).override_failure_message(f.display_name).is_true()


func test_ammo_survives_clone() -> void:
	var state := _state()
	var a := _unit(state, 0, _gunner(), Vector2i(2, 2))
	a.ammo_spent = 2
	var c := state.clone()
	assert_int((c.entities_by_id[a.entity_id] as UnitState).ammo_spent).is_equal(2)
