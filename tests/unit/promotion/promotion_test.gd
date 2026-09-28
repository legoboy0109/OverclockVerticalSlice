# Promotion & veterancy (design/gdd/promotion-veterancy.md). Inert for every shipped faction
# (PV-8: Empire only); these use a test faction that promotes.
extends GdUnitTestSuite

const GRID_SIZE: int = 12


func _faction(requires_support: bool = false) -> FactionDef:
	var f := FactionDef.new()
	f.display_name = "Test Empire"
	f.promotes = true
	f.rank_requires_support = requires_support
	f.rank_support_structures = [StructureTypes.RESEARCH_LAB]
	return f


func _state(f0: FactionDef) -> GameState:
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
	state.per_player[0].faction = f0
	state.per_player[1].faction = Factions.NEUTRAL
	for i: int in 2:
		state.per_player[i].current_ap = 99
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


func _attack(state: GameState, from: Vector2i, to: Vector2i) -> void:
	var a := AttackAction.new()
	a.player = state.active_player
	a.attacker_tile = from
	a.target_tile = to
	assert_bool(state.apply_action(a).ok).is_true()


func test_no_shipped_faction_promotes() -> void:
	for f: FactionDef in [Factions.NEUTRAL, Factions.RUSH, Factions.BOOM]:
		assert_bool(f.promotes).is_false()


func test_a_neutral_unit_earns_nothing() -> void:
	var state := _state(Factions.NEUTRAL)
	var sniper := _unit(state, 0, UnitTypes.SNIPER, Vector2i(2, 2))
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))
	_attack(state, sniper.position, Vector2i(3, 2))
	assert_int(sniper.merit).is_equal(0)


func test_merit_per_kill_and_per_hit() -> void:
	var state := _state(_faction())
	var sniper := _unit(state, 0, UnitTypes.SNIPER, Vector2i(2, 2))
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))    # 3 hp: a kill
	_attack(state, sniper.position, Vector2i(3, 2))
	assert_int(sniper.merit).is_equal(CombatBalance.combat.merit_per_kill)
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(6, 6))
	var heavy := _unit(state, 1, UnitTypes.HEAVY, Vector2i(7, 6))   # 10 hp: survives
	_attack(state, trooper.position, heavy.position)
	assert_int(trooper.merit).is_equal(CombatBalance.combat.merit_per_hit)


func test_two_kills_make_a_veteran_with_more_attack() -> void:
	var state := _state(_faction())
	var sniper := _unit(state, 0, UnitTypes.SNIPER, Vector2i(2, 2))
	var atk: int = Unit.effective_attack(state, sniper)
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))
	_attack(state, sniper.position, Vector2i(3, 2))
	sniper.has_attacked = false
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(2, 3))
	_attack(state, sniper.position, Vector2i(2, 3))
	assert_int(sniper.rank).is_equal(1)
	assert_int(Unit.effective_attack(state, sniper)).is_equal(atk + CombatBalance.combat.rank_attack[1])


func test_promotion_to_elite_raises_max_and_current_hp() -> void:
	var state := _state(_faction())
	var t := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	t.current_hp = 4
	t.merit = 16
	Promotion.apply_rank(state, t)
	assert_int(t.rank).is_equal(2)
	assert_int(Unit.effective_max_hp(t)).is_equal(UnitTypes.TROOPER.hp + 2)
	assert_int(t.current_hp).is_equal(6)   # PV-5: the new hp arrives at once


func test_rank_caps_at_champion() -> void:
	var state := _state(_faction())
	var t := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	t.merit = 999
	Promotion.apply_rank(state, t)
	assert_int(t.rank).is_equal(3)
	assert_int(Unit.effective_attack_range(state, t)).is_equal(UnitTypes.TROOPER.attack_range + 1)


func test_area_damage_uses_pre_promotion_stats() -> void:
	# PV-6 + DT-9: a burst that promotes its attacker damages every target at the OLD rank.
	var state := _state(_faction())
	var burst_type: UnitTypeDef = UnitTypes.SNIPER.duplicate()
	burst_type.area_shape = UnitTypeDef.AreaShape.BURST
	var gun := _unit(state, 0, burst_type, Vector2i(2, 5))
	gun.merit = 5   # one more kill crosses rank 1
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 5))
	var big := _unit(state, 1, UnitTypes.HEAVY, Vector2i(4, 6))
	_attack(state, gun.position, Vector2i(4, 5))
	assert_int(gun.rank).is_equal(1)
	assert_int(UnitTypes.HEAVY.hp - big.current_hp).is_equal(UnitTypes.SNIPER.attack)


func test_losing_support_drops_a_rank_a_turn_and_keeps_merit() -> void:
	var state := _state(_faction(true))
	var t := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	t.merit = 16
	t.rank = 2
	state.start_turn(0)
	assert_int(t.rank).is_equal(1)
	state.start_turn(0)
	assert_int(t.rank).is_equal(0)
	assert_int(t.merit).is_equal(16)
	var lab := StructureState.new()
	lab.entity_id = 80
	lab.owner = 0
	lab.position = Vector2i(6, 6)
	lab.type = StructureTypes.RESEARCH_LAB
	lab.current_hp = lab.type.hp
	lab.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[80] = lab
	state.grid.place(80, 6, 6)
	state.start_turn(0)
	assert_int(t.rank).override_failure_message("Restoring support did not restore rank.").is_equal(2)


func test_healing_respects_the_promoted_ceiling() -> void:
	var state := _state(_faction())
	var t := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	t.merit = 16
	Promotion.apply_rank(state, t)
	t.current_hp = 1
	Unit.apply_hp_delta(t, 100)
	assert_int(t.current_hp).is_equal(UnitTypes.TROOPER.hp + 2)
