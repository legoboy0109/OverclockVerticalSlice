# AI cover play and vehicle saving (2026-10-01, user direction: "make the AI use cover when it has
# Ambush or Dig In, and also tune the AI to use more vehicles"). See AIConfig.cover_hold_radius,
# cover_seek_discount and vehicle_saving for the measured reasons.
extends GdUnitTestSuite

const SIZE: int = 16


func before_test() -> void:
	Balance.reset()


func after_test() -> void:
	AIBalance.ai.vehicle_saving = true


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
		p.current_ap = 30
		p.current_credits = 30000
	_structure(state, 0, Vector2i(1, 8), StructureTypes.HQ)
	_structure(state, 1, Vector2i(14, 8), StructureTypes.HQ)
	return state


func _structure(state: GameState, owner: int, pos: Vector2i, type: StructureTypeDef) -> StructureState:
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


func _grant_cover_tech(state: GameState) -> void:
	var t := TechDef.new()
	t.display_name = "Test Ambush"
	t.infantry_cover_attack = 3
	state.per_player[0].completed_techs.append(t)


## A Trooper in Cover with friends beside it (so massing never blocks the advance) and an enemy
## Trooper five tiles off — close enough to hold for, too far to shoot. The enemy HQ is well
## defended, so the group is NOT push-ready (a push overrides holding by design).
func _cover_scene() -> Array:
	var state := _state()
	state.grid.terrain[state.grid.index(6, 8)] = GridState.Terrain.COVER
	var me := _unit(state, 0, UnitTypes.TROOPER, Vector2i(6, 8))
	_unit(state, 0, UnitTypes.TROOPER, Vector2i(6, 7))
	_unit(state, 0, UnitTypes.TROOPER, Vector2i(6, 9))
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(11, 8))
	for y: int in [6, 7, 9, 10]:
		_unit(state, 1, UnitTypes.TROOPER, Vector2i(14, y))
	return [state, me]


func test_without_a_cover_tech_a_unit_in_cover_still_advances() -> void:
	var scene: Array = _cover_scene()
	var best := AI._score_positional_and_retreat_candidates(scene[0], scene[1], AI._Candidate.new())
	assert_object(best.action).is_instanceof(MoveAction)


func test_with_a_cover_tech_a_unit_in_cover_holds_while_enemies_are_close() -> void:
	var scene: Array = _cover_scene()
	_grant_cover_tech(scene[0])
	var best := AI._score_positional_and_retreat_candidates(scene[0], scene[1], AI._Candidate.new())
	assert_object(best.action).is_null()


func test_with_a_cover_tech_a_unit_in_cover_advances_when_no_enemy_is_near() -> void:
	var scene: Array = _cover_scene()
	_grant_cover_tech(scene[0])
	var state: GameState = scene[0]
	var enemy: EntityState = state.entity_at(Vector2i(11, 8))
	state.grid.remove(11, 8)
	enemy.position = Vector2i(13, 2)
	state.grid.place(enemy.entity_id, 13, 2)
	var best := AI._score_positional_and_retreat_candidates(state, scene[1], AI._Candidate.new())
	assert_object(best.action).is_instanceof(MoveAction)


# --- Saving for vehicles ------------------------------------------------------------------------

func _economy_scene(credits: int) -> Array:
	var state := _state()
	state.per_player[0].current_credits = credits
	var barracks := _structure(state, 0, Vector2i(2, 4), StructureTypes.BARRACKS)
	_structure(state, 0, Vector2i(2, 12), StructureTypes.FACTORY)
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(12, 8))
	_unit(state, 1, UnitTypes.TROOPER, Vector2i(12, 9))
	return [state, barracks]


func _cheapest_vehicle_gap() -> int:
	var cheapest: int = 1 << 30
	for t: Variant in StructureTypes.FACTORY.producible_types:
		cheapest = mini(cheapest, t.produce_cost)
	return cheapest


func test_saving_reserve_holds_back_infantry_when_a_vehicle_is_the_better_buy() -> void:
	var scene: Array = _economy_scene(_cheapest_vehicle_gap() - 100)
	var state: GameState = scene[0]
	var reserve: int = AI._vehicle_savings_reserve(state, 0)
	assert_int(reserve).override_failure_message("expected the AI to save for a vehicle").is_greater(
		state.per_player[0].current_credits)
	var best := AI._score_production_candidates(state, scene[1], 0, AI._Candidate.new())
	if best.action != null:
		assert_bool((best.action as ProduceAction).unit_type.can_build).is_true()


func test_saving_is_off_when_the_knob_is_off() -> void:
	AIBalance.ai.vehicle_saving = false
	var scene: Array = _economy_scene(_cheapest_vehicle_gap() - 100)
	assert_int(AI._vehicle_savings_reserve(scene[0], 0)).is_equal(0)


func test_no_saving_when_the_vehicle_is_out_of_reach() -> void:
	var scene: Array = _economy_scene(0)
	var state: GameState = scene[0]
	# With no income to speak of, waiting would only leave the army empty.
	for i: int in 12:
		_unit(state, 0, UnitTypes.HEAVY, Vector2i(4 + i % 4, 1 + i / 4))
	assert_int(AI._vehicle_savings_reserve(state, 0)).is_equal(0)


func test_vehicles_get_a_mix_bonus_only_while_the_army_lacks_them() -> void:
	var state := _state()
	_unit(state, 0, UnitTypes.TROOPER, Vector2i(3, 3))
	assert_float(AI._vehicle_mix_factor(state, 0, UnitTypes.TANK)).is_equal_approx(1.0 + AIBalance.ai.vehicle_mix_bonus, 0.0001)
	assert_float(AI._vehicle_mix_factor(state, 0, UnitTypes.TROOPER)).is_equal(1.0)
	_unit(state, 0, UnitTypes.TANK, Vector2i(3, 4))   # 1 of 2 fighters = 50%, over the 30% target
	assert_float(AI._vehicle_mix_factor(state, 0, UnitTypes.TANK)).is_equal(1.0)


func test_attack_preview_counts_ambush_from_the_tile_it_fires_from() -> void:
	var state := _state()
	state.grid.terrain[state.grid.index(5, 5)] = GridState.Terrain.COVER
	_grant_cover_tech(state)
	var me := _unit(state, 0, UnitTypes.TROOPER, Vector2i(4, 5))   # in the open
	var foe := _unit(state, 1, UnitTypes.HEAVY, Vector2i(7, 5))
	var from_open := AI._consider_attack(state, me, foe, Vector2i(4, 5), foe.position, 1, AI._Candidate.new())
	var from_cover := AI._consider_attack(state, me, foe, Vector2i(5, 5), foe.position, 1, AI._Candidate.new())
	assert_float(from_cover.score).is_greater(from_open.score)
	assert_object(me.position).is_equal(Vector2i(4, 5))   # the preview restores the real tile


func test_upkeep_room_is_kept_for_a_vehicle_once_the_army_is_big_enough() -> void:
	var scene: Array = _economy_scene(30000)
	var state: GameState = scene[0]
	assert_int(AI._vehicle_upkeep_room(state, 0)).override_failure_message(
		"no room with an army below vehicle_room_min_army").is_equal(0)
	for i: int in AIBalance.ai.vehicle_room_min_army:
		_unit(state, 0, UnitTypes.TROOPER, Vector2i(5, 3 + i))
	assert_int(AI._vehicle_upkeep_room(state, 0)).is_greater(0)
