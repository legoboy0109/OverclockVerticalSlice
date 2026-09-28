# CR-14: the research menu model — which rows a HQ shows, and what each tech row says.
#
# Pure model tests (CommandFSM + ActionMenu's static text); the press-through-to-the-board
# path is pinned separately by tests/integration/vertical-slice/research_picker_wiring_test.gd.
extends GdUnitTestSuite

const GRID_SIZE: int = 16


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
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_ap = 20
		state.per_player[i].current_credits = 5000
	return state


func _structure(state: GameState, type: StructureTypeDef, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _entry(state: GameState, entity: EntityState, verb: int) -> CommandFSM.VerbEntry:
	for e: CommandFSM.VerbEntry in CommandFSM.menu_model(state, entity):
		if e.verb == verb:
			return e
	return null


func _option(state: GameState, hq: StructureState, tech: TechDef) -> CommandFSM.ResearchOption:
	for o: CommandFSM.ResearchOption in CommandFSM.research_options(state, hq):
		if o.tech == tech:
			return o
	return null


# --- The Research row -------------------------------------------------------------

func test_an_idle_funded_hq_has_an_enabled_research_row() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	assert_bool(_entry(state, hq, CommandFSM.Verb.RESEARCH).enabled).is_true()


func test_a_busy_hq_dims_the_research_row() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	hq.research_target = Techs.ATTACK_I
	hq.research_turns_remaining = 2
	var e := _entry(state, hq, CommandFSM.Verb.RESEARCH)
	assert_bool(e.enabled).is_false()
	assert_int(e.reason & CommandFSM.Reason.RESEARCH_BUSY).is_not_equal(0)
	assert_str(CommandFSM.research_status_text(hq)).is_equal("Researching Attack Tech - 2 turns")


func test_a_broke_hq_dims_the_research_row() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	state.per_player[0].current_credits = 0
	assert_bool(_entry(state, hq, CommandFSM.Verb.RESEARCH).enabled).is_false()


func test_a_research_lab_is_not_a_researcher() -> void:
	var state := _state()
	var lab := _structure(state, StructureTypes.RESEARCH_LAB, Vector2i(4, 2))
	var e := _entry(state, lab, CommandFSM.Verb.RESEARCH)
	assert_bool(e.enabled).is_false()
	assert_bool(ActionMenu._is_inapplicable(e)).override_failure_message(
		"A Lab would show a dead 'Research' row — it is a gate, not a researcher.").is_true()


func test_cancel_research_row_only_while_researching() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	var idle := _entry(state, hq, CommandFSM.Verb.CANCEL_RESEARCH)
	assert_bool(ActionMenu._is_inapplicable(idle)).is_true()
	hq.research_target = Techs.ATTACK_I
	hq.research_turns_remaining = 2
	assert_bool(_entry(state, hq, CommandFSM.Verb.CANCEL_RESEARCH).enabled).is_true()
	assert_int(CommandFSM.cancel_research_preview(state, hq)).is_equal(
		Research.cancel_refund(state, Techs.ATTACK_I, 0))


# --- The picker rows --------------------------------------------------------------

func test_the_picker_lists_every_tech_in_tree_order() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	var techs: Array[TechDef] = []
	for o: CommandFSM.ResearchOption in CommandFSM.research_options(state, hq):
		techs.append(o.tech)
	assert_array(techs).is_equal(Techs.ALL)


func test_a_startable_tech_shows_its_price() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	var o := _option(state, hq, Techs.ATTACK_I)
	assert_bool(o.enabled).is_true()
	assert_str(ActionMenu.research_option_text(o)).is_equal("1000 CR + 1 AP · 3 turns")


func test_a_tier_two_tech_names_its_missing_parent_first() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	var o := _option(state, hq, Techs.PENETRATION)
	assert_bool(o.enabled).is_false()
	assert_str(ActionMenu.research_option_text(o)).is_equal("Needs Attack Tech")


func test_a_tier_two_tech_names_the_missing_lab() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_str(ActionMenu.research_option_text(_option(state, hq, Techs.PENETRATION))).is_equal(
		"Needs a Research Lab")


func test_a_closed_branch_names_the_choice_that_closed_it() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	_structure(state, StructureTypes.RESEARCH_LAB, Vector2i(4, 2))
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	GameStateFactory.grant_tech(state, 0, Techs.PENETRATION)
	assert_str(ActionMenu.research_option_text(_option(state, hq, Techs.VOLLEY))).is_equal(
		"Locked - you chose Penetration")
	assert_str(ActionMenu.research_option_text(_option(state, hq, Techs.PENETRATION))).is_equal(
		"Researched")


func test_an_unaffordable_tech_names_the_short_pool() -> void:
	var state := _state()
	var hq := _structure(state, StructureTypes.HQ, Vector2i(2, 2))
	state.per_player[0].current_credits = 0
	assert_str(ActionMenu.research_option_text(_option(state, hq, Techs.ATTACK_I))).ends_with("needs Credits")
	state.per_player[0].current_credits = 5000
	state.per_player[0].current_ap = 0
	assert_str(ActionMenu.research_option_text(_option(state, hq, Techs.ATTACK_I))).ends_with("needs AP")
