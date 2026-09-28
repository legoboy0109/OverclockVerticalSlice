# Damage Types (design/gdd/damage-types.md): one added resistance term, incendiary ignores
# Cover, and area shapes that hit friend and foe alike.
#
# Fixture units are duplicates of real types with only the field under test changed, so each
# test measures exactly one rule against the shipped formula.
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


# A 6-attack, 0-defence gunner of the given damage type.
func _gun(dtype: int, shape: int = UnitTypeDef.AreaShape.SINGLE) -> UnitTypeDef:
	var t: UnitTypeDef = UnitTypes.SNIPER.duplicate()
	t.damage_type = dtype
	t.area_shape = shape
	return t


# A tough 0-defence target with the given resistances.
func _target(emf: int = 0, incendiary: int = 0) -> UnitTypeDef:
	var t: UnitTypeDef = UnitTypes.HEAVY.duplicate()
	t.hp = 20
	t.defense = 0
	t.resist_kinetic = 0
	t.resist_emf = emf
	t.resist_incendiary = incendiary
	return t


func _attack(state: GameState, from: Vector2i, to: Vector2i) -> ActionResult:
	var a := AttackAction.new()
	a.player = 0
	a.attacker_tile = from
	a.target_tile = to
	return state.apply_action(a)


# --- The formula (AC-1..AC-7) ------------------------------------------------------

func test_ac1_every_shipped_unit_deals_kinetic_so_no_matchup_changed() -> void:
	# ⚠ Narrowed 2026-09-28 to the BASELINE faction's roster: faction waves add EMF/incendiary
	# units on purpose (Solar's Lance Team). The guarantee DT-1 makes is that the pre-damage-type
	# game — the Alliance — is unchanged.
	for t: UnitTypeDef in Faction.units(Factions.DEMOCRATIC_ALLIANCE):
		assert_int(t.damage_type).override_failure_message(
			"%s is not KINETIC — shipped matchups would change." % t.display_name
		).is_equal(UnitTypeDef.DamageType.KINETIC)
		assert_int(t.resist_kinetic).is_equal(0)


func test_ac2_ac3_resistance_is_one_flat_term_either_way() -> void:
	var state := _state()
	var gun := _unit(state, 0, _gun(UnitTypeDef.DamageType.EMF), Vector2i(2, 2))
	var tough := _unit(state, 1, _target(2), Vector2i(3, 2))
	var weak := _unit(state, 1, _target(-2), Vector2i(2, 3))
	assert_int(Combat.damage(state, gun, tough)).is_equal(4)
	assert_int(Combat.damage(state, gun, weak)).is_equal(8)


func test_ac4_resistance_never_removes_a_hit() -> void:
	var state := _state()
	var weak_gun_type := _gun(UnitTypeDef.DamageType.EMF)
	weak_gun_type.attack = 1
	var gun := _unit(state, 0, weak_gun_type, Vector2i(2, 2))
	var armoured := _unit(state, 1, _target(3), Vector2i(3, 2))
	assert_int(Combat.damage(state, gun, armoured)).is_equal(CombatBalance.combat.min_damage)


func test_ac5_ac6_incendiary_ignores_cover_and_kinetic_does_not() -> void:
	var state := _state()
	var fire := _unit(state, 0, _gun(UnitTypeDef.DamageType.INCENDIARY), Vector2i(2, 2))
	var rifle := _unit(state, 0, _gun(UnitTypeDef.DamageType.KINETIC), Vector2i(2, 4))
	var trooper := _unit(state, 1, UnitTypes.TROOPER, Vector2i(3, 3))
	var open_fire: int = Combat.damage(state, fire, trooper)
	var open_rifle: int = Combat.damage(state, rifle, trooper)
	state.grid.terrain[state.grid.index(3, 3)] = GridState.Terrain.COVER
	assert_int(Combat.damage(state, fire, trooper)).is_equal(open_fire)
	assert_int(Combat.damage(state, rifle, trooper)).is_equal(open_rifle - CombatBalance.combat.cover_dr)


func test_dt9b_machines_are_weak_to_emf_and_infantry_resist_it() -> void:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == UnitTypeDef.UnitClass.INFANTRY:
			assert_int(t.resist_emf).is_equal(2)
		else:
			assert_int(t.resist_emf).override_failure_message(
				"%s is a machine but not EMF-vulnerable." % t.display_name).is_less(0)


func test_ac14_every_resistance_is_inside_the_band() -> void:
	for t: UnitTypeDef in UnitTypes.ALL:
		for r: int in [t.resist_kinetic, t.resist_emf, t.resist_incendiary]:
			assert_int(r).is_between(-3, 3)


# --- Area (AC-8..AC-12) ------------------------------------------------------------

func test_ac8_ac9_a_burst_hits_the_target_its_neighbours_and_friendlies() -> void:
	var state := _state()
	_unit(state, 0, _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.BURST), Vector2i(2, 5))
	var primary := _unit(state, 1, _target(), Vector2i(4, 5))
	var enemy_beside := _unit(state, 1, _target(), Vector2i(4, 6))
	var friend_beside := _unit(state, 0, _target(), Vector2i(4, 4))
	var outside := _unit(state, 1, _target(), Vector2i(6, 5))
	assert_bool(_attack(state, Vector2i(2, 5), Vector2i(4, 5)).ok).is_true()
	assert_int(primary.current_hp).is_less(20)
	assert_int(enemy_beside.current_hp).is_less(20)
	assert_int(friend_beside.current_hp).override_failure_message("No friendly fire in a burst.").is_less(20)
	assert_int(outside.current_hp).is_equal(20)


func test_a_burst_costs_more_ap_than_a_single_shot() -> void:
	var state := _state()
	var single := _unit(state, 0, _gun(UnitTypeDef.DamageType.KINETIC), Vector2i(1, 1))
	var burst := _unit(state, 0, _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.BURST), Vector2i(1, 3))
	assert_int(Combat.attack_cost_for(burst)).is_equal(
		Combat.attack_cost_for(single) + CombatBalance.combat.area_ap_surcharge)


func test_ac10_all_damage_lands_before_any_death() -> void:
	# Two kills in one burst: both take full damage and both die — a death mid-resolution
	# never shields a later target.
	var state := _state()
	_unit(state, 0, _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.BURST), Vector2i(2, 5))
	var a := _unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 5))
	var b := _unit(state, 1, UnitTypes.SCOUT, Vector2i(5, 5))
	var result := _attack(state, Vector2i(2, 5), Vector2i(4, 5))
	assert_bool(state.entities_by_id.has(a.entity_id)).is_false()
	assert_bool(state.entities_by_id.has(b.entity_id)).is_false()
	var damage_events: int = 0
	for e: Variant in result.events:
		if e is DamageEvent:
			damage_events += 1
	assert_int(damage_events).is_equal(2)


func test_ac10_the_same_attack_resolves_the_same_way_twice() -> void:
	var s1 := _state()
	_unit(s1, 0, _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.BURST), Vector2i(2, 5))
	for p: Vector2i in [Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 5), Vector2i(4, 6)]:
		_unit(s1, 1, UnitTypes.TROOPER, p)
	var s2 := s1.clone()
	var r1 := _attack(s1, Vector2i(2, 5), Vector2i(4, 5))
	var r2 := _attack(s2, Vector2i(2, 5), Vector2i(4, 5))
	assert_int(r1.events.size()).is_equal(r2.events.size())
	for i: int in r1.events.size():
		if r1.events[i] is DamageEvent:
			assert_int(r1.events[i].target_id).is_equal(r2.events[i].target_id)


func test_ac11_a_line_truncates_at_the_board_edge() -> void:
	var state := _state()
	var line_type := _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.LINE)
	line_type.area_length = 8
	var gun := _unit(state, 0, line_type, Vector2i(GRID_SIZE - 3, 5))
	var tiles: Array[Vector2i] = Combat.area_tiles(state, gun, gun.position, Vector2i(GRID_SIZE - 1, 5))
	for t: Vector2i in tiles:
		assert_bool(state.grid.in_bounds(t.x, t.y)).is_true()
	assert_int(tiles.size()).is_equal(2)


func test_ac12_only_the_primary_target_counterattacks() -> void:
	var state := _state()
	var counter_type: UnitTypeDef = _target()
	counter_type.can_counterattack = true
	counter_type.attack = 3
	counter_type.attack_range = 3
	var gun_type := _gun(UnitTypeDef.DamageType.KINETIC, UnitTypeDef.AreaShape.BURST)
	gun_type.hp = 30
	var gun := _unit(state, 0, gun_type, Vector2i(2, 5))
	_unit(state, 1, counter_type, Vector2i(4, 5))  # primary
	_unit(state, 1, counter_type, Vector2i(4, 4))  # splashed, also counter-capable
	_unit(state, 1, counter_type, Vector2i(4, 6))
	_attack(state, Vector2i(2, 5), Vector2i(4, 5))
	assert_int(gun.current_hp).override_failure_message(
		"Splashed units counterattacked too.").is_equal(30 - 3)


func test_splash_never_hits_a_class_the_attacker_cannot_target() -> void:
	var state := _state()
	_unit(state, 0, UnitTypes.BOMBER, Vector2i(2, 5))
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(3, 5))
	var jet := _unit(state, 1, UnitTypes.FIGHTER, Vector2i(3, 4))
	assert_bool(_attack(state, Vector2i(2, 5), Vector2i(3, 5)).ok).is_true()
	assert_int(jet.current_hp).is_equal(UnitTypes.FIGHTER.hp)


func test_ac15_preview_matches_the_damage_applied_to_the_primary() -> void:
	var state := _state()
	var gun := _unit(state, 0, _gun(UnitTypeDef.DamageType.EMF), Vector2i(2, 2))
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(3, 2))
	var predicted: int = Combat.preview_damage(state, gun, tank)
	_attack(state, gun.position, tank.position)
	assert_int(UnitTypes.TANK.hp - tank.current_hp).is_equal(predicted)


# --- AI ------------------------------------------------------------------------------

func test_the_ai_counts_splash_on_its_own_units_against_an_attack() -> void:
	var state := _state()
	var bomber := _unit(state, 0, UnitTypes.BOMBER, Vector2i(2, 5))
	var target := _unit(state, 1, UnitTypes.TROOPER, Vector2i(3, 5))
	var clean: AI._Candidate = AI._consider_attack(state, bomber, target, bomber.position, target.position,
		Combat.attack_cost_for(bomber), AI._Candidate.new())
	_unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 4))
	_unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 6))
	var costly: AI._Candidate = AI._consider_attack(state, bomber, target, bomber.position, target.position,
		Combat.attack_cost_for(bomber), AI._Candidate.new())
	assert_float(costly.score).is_less(clean.score)
