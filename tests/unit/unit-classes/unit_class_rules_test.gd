# Unit Classes (design/gdd/unit-classes.md) — infantry, ground vehicles and air.
#
# One test per acceptance criterion where it is a rule, named for the AC it pins. Each
# "cannot" test first shows the same thing working for a class that CAN, so a failure for
# an unrelated reason cannot pass it.
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
		state.per_player[i].current_credits = 99999
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


func _terrain(state: GameState, tile: Vector2i, terrain: int) -> void:
	state.grid.terrain[state.grid.index(tile.x, tile.y)] = terrain


func _reaches(state: GameState, unit: UnitState, tile: Vector2i) -> bool:
	for r: Movement.ReachableTile in Movement.reachable(state, unit):
		if r.tile == tile:
			return true
	return false


func _targets(state: GameState, attacker: EntityState, target: EntityState) -> bool:
	for tr: Combat.TargetResult in Combat.legal_targets(state, attacker):
		if tr.target_id == target.entity_id:
			return true
	return false


# --- Config (AC-12, UC-5) -----------------------------------------------------------

func test_ac12_every_unit_has_a_class_and_a_positive_move_cost() -> void:
	for type: UnitTypeDef in UnitTypes.ALL:
		assert_int(type.unit_class).is_between(0, 2)
		assert_int(type.move_cost).is_greater_equal(1)


func test_uc5_the_roster_can_answer_air() -> void:
	var has_air: bool = UnitTypes.ALL.any(func(t: UnitTypeDef) -> bool: return t.unit_class == UnitTypeDef.UnitClass.AIR)
	var anti_air: bool = UnitTypes.ALL.any(func(t: UnitTypeDef) -> bool: return UnitTypeDef.UnitClass.AIR in t.can_target)
	assert_bool(not has_air or anti_air).override_failure_message(
		"Air units exist but nothing can shoot them — unplayable against air (UC-5).").is_true()


func test_uc7_vehicles_and_aircraft_do_not_count_toward_the_cap() -> void:
	for type: UnitTypeDef in UnitTypes.ALL:
		if type.unit_class != UnitTypeDef.UnitClass.INFANTRY:
			assert_bool(type.counts_toward_cap).override_failure_message(
				"%s counts toward the infantry cap." % type.display_name).is_false()


func test_producers_only_make_their_own_class() -> void:
	for t: Variant in StructureTypes.FACTORY.producible_types: # untyped: GDScript mis-resolves this typed array via the autoload
		assert_int(t.unit_class).is_equal(UnitTypeDef.UnitClass.GROUND_VEHICLE)
	for t: Variant in StructureTypes.AIRFIELD.producible_types: # untyped: GDScript mis-resolves this typed array via the autoload
		assert_int(t.unit_class).is_equal(UnitTypeDef.UnitClass.AIR)
	for t: Variant in StructureTypes.BARRACKS.producible_types: # untyped: GDScript mis-resolves this typed array via the autoload
		assert_int(t.unit_class).is_equal(UnitTypeDef.UnitClass.INFANTRY)


# --- Terrain (AC-1, AC-2, AC-3, AC-10) ---------------------------------------------

func test_ac1_ac2_rough_ground_stops_vehicles_not_infantry() -> void:
	var state := _state()
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(2, 6))
	_terrain(state, Vector2i(3, 2), GridState.Terrain.ROUGH)
	_terrain(state, Vector2i(3, 6), GridState.Terrain.ROUGH)
	assert_bool(_reaches(state, trooper, Vector2i(3, 2))).is_true()
	assert_bool(_reaches(state, tank, Vector2i(3, 6))).override_failure_message(
		"A tank drove onto rough ground.").is_false()


func test_ac1_a_vehicle_cannot_path_through_rough_ground() -> void:
	var state := _state()
	var tank := _unit(state, 0, UnitTypes.TANK, Vector2i(0, 5))
	for y: int in GRID_SIZE:
		_terrain(state, Vector2i(1, y), GridState.Terrain.ROUGH) # a wall of rough
	assert_bool(_reaches(state, tank, Vector2i(2, 5))).is_false()


func test_ac3_aircraft_fly_over_blocked_ground_and_units() -> void:
	var state := _state()
	var fighter := _unit(state, 0, UnitTypes.FIGHTER, Vector2i(0, 5))
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(0, 7))
	for y: int in GRID_SIZE:
		_terrain(state, Vector2i(1, y), GridState.Terrain.IMPASSABLE)
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(2, 5)) # an enemy in the way, too
	assert_bool(_reaches(state, trooper, Vector2i(3, 5))).override_failure_message(
		"Fixture: infantry got past an impassable wall.").is_false()
	assert_bool(_reaches(state, fighter, Vector2i(3, 5))).is_true()


func test_aircraft_still_cannot_land_on_an_occupied_or_blocked_tile() -> void:
	var state := _state()
	var fighter := _unit(state, 0, UnitTypes.FIGHTER, Vector2i(0, 5))
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(2, 5))
	_terrain(state, Vector2i(3, 5), GridState.Terrain.IMPASSABLE)
	assert_bool(_reaches(state, fighter, Vector2i(2, 5))).is_false()
	assert_bool(_reaches(state, fighter, Vector2i(3, 5))).is_false()


func test_ac10_a_vehicle_is_never_deployed_onto_rough_ground() -> void:
	var state := _state()
	var factory := StructureState.new()
	factory.entity_id = 50
	factory.owner = 0
	factory.position = Vector2i(5, 5)
	factory.type = StructureTypes.FACTORY
	factory.current_hp = factory.type.hp
	factory.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[50] = factory
	state.grid.place(50, 5, 5)
	_terrain(state, Vector2i(6, 5), GridState.Terrain.ROUGH)
	assert_bool(BaseProduction.legal_deploy_tiles(state, factory, UnitTypes.TROOPER).has(Vector2i(6, 5))).is_true()
	assert_bool(BaseProduction.legal_deploy_tiles(state, factory, UnitTypes.TANK).has(Vector2i(6, 5))).is_false()


# --- Cover (AC-4, AC-5) ------------------------------------------------------------

func test_ac4_ac5_cover_protects_infantry_but_not_vehicles() -> void:
	var state := _state()
	var shooter := _unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 2))
	var trooper := _unit(state, 1, UnitTypes.TROOPER, Vector2i(3, 2))
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(2, 3))
	var t_open: int = Combat.damage(state, shooter, trooper)
	var v_open: int = Combat.damage(state, shooter, tank)
	_terrain(state, trooper.position, GridState.Terrain.COVER)
	_terrain(state, tank.position, GridState.Terrain.COVER)
	assert_int(Combat.damage(state, shooter, trooper)).is_less(t_open)
	assert_int(Combat.damage(state, shooter, tank)).is_equal(v_open)


# --- Targeting (AC-6, AC-7, UC-4) ----------------------------------------------------

func test_ac6_ground_units_cannot_target_aircraft() -> void:
	var state := _state()
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var bomber := _unit(state, 1, UnitTypes.BOMBER, Vector2i(3, 2))
	var scout := _unit(state, 1, UnitTypes.SCOUT, Vector2i(2, 3))
	assert_bool(_targets(state, trooper, scout)).is_true()
	assert_bool(_targets(state, trooper, bomber)).is_false()


func test_ac7_ac8_a_fighter_hits_only_aircraft() -> void:
	var state := _state()
	var fighter := _unit(state, 0, UnitTypes.FIGHTER, Vector2i(2, 2))
	var scout := _unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))
	var bomber := _unit(state, 1, UnitTypes.BOMBER, Vector2i(2, 3))
	var hq := StructureState.new()
	hq.entity_id = 60
	hq.owner = 1
	hq.position = Vector2i(1, 2)
	hq.type = StructureTypes.HQ
	hq.current_hp = 40
	hq.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[60] = hq
	state.grid.place(60, 1, 2)
	assert_bool(_targets(state, fighter, bomber)).is_true()
	assert_bool(_targets(state, fighter, scout)).is_false()
	assert_bool(_targets(state, fighter, hq)).override_failure_message(
		"A Fighter (air-only) must not attack structures.").is_false()


func test_the_helicopter_hits_everything() -> void:
	var state := _state()
	var heli := _unit(state, 0, UnitTypes.HELICOPTER, Vector2i(2, 2))
	var scout := _unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))
	var fighter := _unit(state, 1, UnitTypes.FIGHTER, Vector2i(2, 3))
	var tank := _unit(state, 1, UnitTypes.TANK, Vector2i(1, 2))
	for t: UnitState in [scout, fighter, tank]:
		assert_bool(_targets(state, heli, t)).is_true()


func test_something_you_cannot_target_does_not_block_your_line_of_fire() -> void:
	# A Trooper (range 2) fires past an enemy aircraft at the Scout behind it.
	var state := _state()
	var trooper := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	_unit(state, 1, UnitTypes.FIGHTER, Vector2i(3, 2))
	var scout := _unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 2))
	assert_bool(_targets(state, trooper, scout)).is_true()


func test_a_unit_cannot_counterattack_what_it_cannot_target() -> void:
	# A counter uses the same legal-target list, so a ground unit never answers an aircraft.
	var state := _state()
	var counter_type: UnitTypeDef = UnitTypes.TROOPER.duplicate()
	counter_type.can_counterattack = true
	var bomber := _unit(state, 0, UnitTypes.BOMBER, Vector2i(2, 2))
	var defender := _unit(state, 1, counter_type, Vector2i(3, 2))
	var a := AttackAction.new()
	a.player = 0
	a.attacker_tile = bomber.position
	a.target_tile = defender.position
	assert_bool(state.apply_action(a).ok).is_true()
	assert_int(bomber.current_hp).override_failure_message(
		"A ground unit counterattacked an aircraft.").is_equal(UnitTypes.BOMBER.hp)


func test_artillery_cannot_fire_at_point_blank() -> void:
	var state := _state()
	var arty := _unit(state, 0, UnitTypes.ARTILLERY, Vector2i(2, 2))
	var near := _unit(state, 1, UnitTypes.SCOUT, Vector2i(3, 2))
	var far := _unit(state, 1, UnitTypes.SCOUT, Vector2i(5, 2))
	assert_bool(_targets(state, arty, far)).is_true()
	assert_bool(_targets(state, arty, near)).is_false()


# --- AI ------------------------------------------------------------------------------

func test_the_ai_does_not_fear_an_enemy_that_cannot_shoot_it() -> void:
	var state := _state()
	_unit(state, 1, UnitTypes.FIGHTER, Vector2i(5, 5)) # air-only: no threat to ground units
	assert_bool(AI._deploy_tile_is_lethal(state, 0, Vector2i(5, 6), UnitTypes.SCOUT)).is_false()
	_unit(state, 1, UnitTypes.HEAVY, Vector2i(5, 8))
	assert_bool(AI._deploy_tile_is_lethal(state, 0, Vector2i(5, 7), UnitTypes.SCOUT)).override_failure_message(
		"Fixture: a Heavy two tiles away should be lethal to a 3-hp Scout.").is_true()
