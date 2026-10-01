# Rush (user decision 2026-09-30): spend AP to take one turn off a construction site or a
# vehicle/aircraft in production — never infantry or builders, and never below "ready at the
# start of the next turn", so a rushed thing is still not usable the turn it was rushed.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


func before_test() -> void:
	Balance.reset()


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
	state.active_player = 0
	state.per_player[0].current_ap = 20
	for p: PlayerState in state.per_player:
		p.faction = Factions.NEUTRAL
	return state


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


func _type_of_class(cls: int, builder: bool = false) -> UnitTypeDef:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == cls and t.can_build == builder:
			return t
	return null


func _producing(state: GameState, type: UnitTypeDef, turns: int) -> StructureState:
	var st := _structure(state, 0, StructureTypes.FACTORY, Vector2i(4, 4))
	st.producing_type = type
	st.production_turns_remaining = turns
	st.production_tile = Vector2i(5, 4)
	return st


func _site(state: GameState, turns: int) -> StructureState:
	var st := _structure(state, 0, StructureTypes.BARRACKS, Vector2i(8, 8))
	st.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	st.build_turns_remaining = turns
	return st


func _rush(state: GameState, st: StructureState) -> ActionResult:
	var a := RushAction.new()
	a.player = 0
	a.structure_id = st.entity_id
	return state.apply_action(a)


func _cost() -> int:
	return Balance.economy.rush_ap_cost


# --- What can be rushed ----------------------------------------------------------------

func test_rush_vehicle_in_production_cuts_one_turn_and_spends_ap() -> void:
	var state := _state()
	var st := _producing(state, _type_of_class(UnitTypeDef.UnitClass.GROUND_VEHICLE), 3)
	var result := _rush(state, st)
	assert_bool(result.ok).is_true()
	assert_int(st.production_turns_remaining).is_equal(2)
	assert_int(state.per_player[0].current_ap).is_equal(20 - _cost())
	assert_bool(result.events[0] is RushedEvent).is_true()


func test_rush_aircraft_in_production_is_allowed() -> void:
	var state := _state()
	var st := _producing(state, _type_of_class(UnitTypeDef.UnitClass.AIR), 2)
	assert_bool(_rush(state, st).ok).is_true()
	assert_int(st.production_turns_remaining).is_equal(1)


func test_rush_construction_site_cuts_one_turn() -> void:
	var state := _state()
	var st := _site(state, 3)
	assert_bool(_rush(state, st).ok).is_true()
	assert_int(st.build_turns_remaining).is_equal(2)


func test_rush_infantry_in_production_is_refused() -> void:
	var state := _state()
	var st := _producing(state, _type_of_class(UnitTypeDef.UnitClass.INFANTRY), 2)
	var result := _rush(state, st)
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NOT_RUSHABLE)
	assert_int(st.production_turns_remaining).is_equal(2)
	assert_int(state.per_player[0].current_ap).is_equal(20)


func test_rush_builder_in_production_is_refused() -> void:
	var state := _state()
	var st := _producing(state, UnitTypes.BUILDER, 2)
	assert_int(_rush(state, st).reason).is_equal(Action.Reason.NOT_RUSHABLE)


func test_rush_idle_structure_has_nothing_to_rush() -> void:
	var state := _state()
	var st := _structure(state, 0, StructureTypes.FACTORY, Vector2i(4, 4))
	assert_int(_rush(state, st).reason).is_equal(Action.Reason.NOTHING_TO_RUSH)


func test_rush_opponents_structure_is_refused() -> void:
	var state := _state()
	var st := _site(state, 3)
	st.owner = 1
	assert_int(_rush(state, st).reason).is_equal(Action.Reason.ILLEGAL_TARGET)


# --- The floor: never usable this turn ---------------------------------------------------

func test_rush_at_one_turn_remaining_is_refused() -> void:
	# 1 = ready at the start of the next turn. Going to 0 would mean same-turn completion.
	var state := _state()
	var st := _producing(state, _type_of_class(UnitTypeDef.UnitClass.GROUND_VEHICLE), 1)
	var result := _rush(state, st)
	assert_int(result.reason).is_equal(Action.Reason.RUSH_AT_MINIMUM)
	assert_int(st.production_turns_remaining).is_equal(1)


func test_rush_repeatedly_stops_at_one_turn() -> void:
	var state := _state()
	var st := _site(state, 3)
	assert_bool(_rush(state, st).ok).is_true()
	assert_bool(_rush(state, st).ok).is_true()
	assert_bool(_rush(state, st).ok).is_false()
	assert_int(st.build_turns_remaining).is_equal(1)
	assert_int(state.per_player[0].current_ap).is_equal(20 - 2 * _cost())


func test_rushed_vehicle_does_not_appear_until_the_next_turn_tick() -> void:
	var state := _state()
	var type := _type_of_class(UnitTypeDef.UnitClass.GROUND_VEHICLE)
	var st := _producing(state, type, 2)
	assert_bool(_rush(state, st).ok).is_true()
	# Still this turn: no unit on the tile.
	assert_int(state.grid.occupant_at(5, 4)).is_equal(GridState.EMPTY_OCCUPANT)
	# The owner's next start of turn delivers it.
	BaseProduction.advance_build_timers(state, 0)
	assert_object(st.producing_type).is_null()
	assert_int(state.grid.occupant_at(5, 4)).is_not_equal(GridState.EMPTY_OCCUPANT)


func test_rushed_site_completes_on_the_next_turn_tick() -> void:
	var state := _state()
	var st := _site(state, 2)
	assert_bool(_rush(state, st).ok).is_true()
	assert_int(st.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	BaseProduction.advance_build_timers(state, 0)
	assert_int(st.build_status).is_equal(StructureState.BuildStatus.COMPLETED)


# --- Cost --------------------------------------------------------------------------------

func test_rush_without_enough_ap_is_refused() -> void:
	var state := _state()
	state.per_player[0].current_ap = _cost() - 1
	var st := _site(state, 3)
	assert_int(_rush(state, st).reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_int(st.build_turns_remaining).is_equal(3)


func test_rush_cost_reads_the_economy_config() -> void:
	var state := _state()
	Balance.economy = Balance.base_economy.duplicate()
	Balance.economy.rush_ap_cost = 7
	var st := _site(state, 3)
	assert_bool(_rush(state, st).ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(13)
	Balance.reset()


# --- Menu ----------------------------------------------------------------------------------

func _rush_entry(state: GameState, st: StructureState) -> CommandFSM.VerbEntry:
	for e: CommandFSM.VerbEntry in CommandFSM.menu_model(state, st):
		if e.verb == CommandFSM.Verb.RUSH:
			return e
	return null


func test_menu_rush_row_enabled_with_price_for_a_rushable_site() -> void:
	var state := _state()
	var st := _site(state, 3)
	var e := _rush_entry(state, st)
	assert_bool(e.enabled).is_true()
	assert_int(e.ap_cost).is_equal(_cost())
	assert_str(CommandFSM.rush_preview_text(st)).is_equal("3 > 2 turns")


func test_menu_rush_row_explains_infantry_and_the_floor() -> void:
	var state := _state()
	var inf := _producing(state, _type_of_class(UnitTypeDef.UnitClass.INFANTRY), 2)
	assert_int(_rush_entry(state, inf).reason).is_equal(CommandFSM.Reason.NOT_RUSHABLE)
	var state2 := _state()
	var veh := _producing(state2, _type_of_class(UnitTypeDef.UnitClass.GROUND_VEHICLE), 1)
	assert_int(_rush_entry(state2, veh).reason).is_equal(CommandFSM.Reason.RUSH_AT_MINIMUM)


func test_menu_rush_row_hidden_on_idle_structures_and_units() -> void:
	var state := _state()
	var idle := _structure(state, 0, StructureTypes.FACTORY, Vector2i(4, 4))
	var e := _rush_entry(state, idle)
	assert_bool(e.enabled).is_false()
	assert_bool(ActionMenu._is_inapplicable(e)).is_true()


func test_menu_rush_row_hidden_on_the_hq_and_infantry_only_producers() -> void:
	# ★ 2026-10-01 (user decision): never offered where it could never apply.
	var state := _state()
	var hq := _structure(state, 0, StructureTypes.HQ, Vector2i(2, 2))
	var e := _rush_entry(state, hq)
	assert_bool(e.enabled).is_false()
	assert_bool(ActionMenu._is_inapplicable(e)).is_true()
	var barracks := _structure(state, 0, StructureTypes.BARRACKS, Vector2i(6, 6))
	assert_bool(ActionMenu._is_inapplicable(_rush_entry(state, barracks))).is_true()
	# A factory (vehicles) still shows it, even idle-but-producing-infantry would be shown.
	var factory := _producing(state, _type_of_class(UnitTypeDef.UnitClass.GROUND_VEHICLE), 2)
	assert_bool(_rush_entry(state, factory).enabled).is_true()
