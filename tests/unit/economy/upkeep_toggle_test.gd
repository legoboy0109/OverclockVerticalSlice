# Upkeep on/off match rule (user decision 2026-09-30: "a toggle for the upkeep mechanic so I can
# test with it on and off").
#
# The rule lives on the per-match EconomyConfig copy (Balance.apply_match), so these tests cover:
# the drain really stops (units AND structures), the deficit lock can't fire from upkeep, the AI's
# unit pricing follows the rule, and the choice survives the setup screen and a save/load.
extends GdUnitTestSuite


func before_test() -> void:
	Balance.reset()


func after_test() -> void:
	Balance.reset()


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	var grid := GridState.new()
	grid.width = 8
	grid.height = 8
	grid.terrain = PackedByteArray()
	grid.terrain.resize(64)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(64)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	state.grid = grid
	return state


func _add_unit(state: GameState, type: UnitTypeDef, pos: Vector2i) -> void:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = 0
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1


func _add_factory(state: GameState, pos: Vector2i) -> void:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = pos
	st.type = StructureTypes.FACTORY
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1


func _army() -> GameState:
	var state := _state()
	_add_unit(state, UnitTypes.HEAVY, Vector2i(1, 1))
	_add_unit(state, UnitTypes.TROOPER, Vector2i(2, 1))
	_add_factory(state, Vector2i(3, 3))
	return state


func test_upkeep_on_by_default_charges_the_army() -> void:
	# Control: without this the "off" assertions below could pass on a broken fixture.
	assert_bool(Balance.economy.upkeep_enabled).is_true()
	assert_int(Upkeep.total_upkeep(_army(), 0)).is_greater(0)


func test_upkeep_off_charges_nothing_for_units_or_structures() -> void:
	Balance.apply_match(20, false)
	var state := _army()
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(0)
	assert_int(Upkeep.unit_upkeep(state, 0, UnitTypes.HEAVY)).is_equal(0)


func test_upkeep_off_banks_gross_income_and_never_sets_deficit() -> void:
	Balance.apply_match(20, false)
	var state := _army()
	state.per_player[0].current_credits = 0
	var gross: int = Credits.credit_income(state, 0)
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(gross)
	assert_bool(state.per_player[0].in_deficit).is_false()


func test_ai_prices_units_without_upkeep_when_off() -> void:
	Balance.apply_match(20, false)
	assert_float(AI.lifetime_credit_cost(UnitTypes.HEAVY)).is_equal(float(UnitTypes.HEAVY.produce_cost))
	assert_float(AI.lifetime_credit_cost(UnitTypes.HEAVY, _army(), 0)).is_equal(float(UnitTypes.HEAVY.produce_cost))


func test_apply_match_never_touches_the_shipped_config() -> void:
	Balance.apply_match(20, false)
	assert_bool(Balance.base_economy.upkeep_enabled).is_true()


func test_save_round_trip_keeps_the_rule() -> void:
	var map: MapDefinition = VSMap.data()
	var state := MatchSetup.build(VSMap.build(), [Factions.playable()[0], Factions.playable()[0]], 0, 80, [1])
	var d: Variant = JSON.parse_string(JSON.stringify(SaveGame.to_dict(state, 20, map, false)))
	var loaded := SaveGame.from_dict(d)
	assert_bool(loaded.upkeep_enabled).is_false()
	assert_bool(MatchSettings.from_loaded(loaded).upkeep_enabled).is_false()


func test_saves_from_before_the_rule_load_with_upkeep_on() -> void:
	var map: MapDefinition = VSMap.data()
	var state := MatchSetup.build(VSMap.build(), [Factions.playable()[0], Factions.playable()[0]], 0, 80, [1])
	var d: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.to_dict(state, 20, map, false)))
	d.erase("upkeep_enabled")
	assert_bool(SaveGame.from_dict(d).upkeep_enabled).is_true()


func test_setup_screen_row_toggles_upkeep() -> void:
	var screen: SkirmishSetup = auto_free(SkirmishSetup.new())
	add_child(screen)
	assert_bool(screen.settings().upkeep_enabled).is_true()
	screen._step(6, 1)
	assert_bool(screen.settings().upkeep_enabled).is_false()
	assert_str(screen._rows[6].text).contains("Off")
	screen._step(6, -1)
	assert_bool(screen.settings().upkeep_enabled).is_true()
