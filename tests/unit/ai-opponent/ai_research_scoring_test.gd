# CR-14 (2026-09-28): the AI researches.
#
# Before CR-14, _score_research_candidates was a stub and the AI valued a Research Lab
# at 0, so it could never research and never reach tier 2. These pin the behaviour that
# replaced it, including the two failure modes that have bitten this AI before:
#   • a candidate apply_action would reject → the driver's reject loop stalls the turn;
#   • a cancel-for-refund loop (S8-17: the AI once demolished everything it built).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_ap = 20
		state.per_player[i].current_credits = 5000
	# The AI researches only once it fields an army (AIConfig.research_min_army), so every
	# fixture starts with one Trooper well away from the base.
	_unit(state, 0, Vector2i(12, 12), UnitTypes.TROOPER)
	return state


func test_no_research_before_the_ai_fields_an_army() -> void:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].faction = Factions.NEUTRAL
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	assert_object(_score(state, hq).action).is_null()


func _structure(state: GameState, player: int, pos: Vector2i, type: StructureTypeDef) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _unit(state: GameState, player: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = player
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _score(state: GameState, hq: StructureState, committed: int = 0) -> AI._Candidate:
	return AI._score_research_candidates(state, hq, committed, AI._Candidate.new())


# --- Proposes research, and only legal research ----------------------------------

func test_an_idle_hq_with_funds_proposes_a_research_action() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	var best := _score(state, hq)
	assert_bool(best.action is ResearchAction).is_true()
	var action: ResearchAction = best.action
	assert_int(Research.validate_research(state, action)).is_equal(Action.Reason.OK)


func test_every_tech_the_ai_values_is_positive() -> void:
	# A tech scored at 0 is a tech the AI will never research. With a ranged unit and a
	# producer on the board, every shipped effect has something to act on.
	var state := _state()
	_structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	_structure(state, 0, Vector2i(4, 2), StructureTypes.BARRACKS)
	_unit(state, 0, Vector2i(6, 6), UnitTypes.TROOPER)
	for tech: TechDef in Techs.ALL:
		assert_float(AI._tech_research_value(state, 0, tech)).override_failure_message(
			"The AI values %s at 0 — it will never research it." % tech.display_name
		).is_greater(0.0)


func test_no_candidate_when_nothing_is_affordable() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	assert_object(_score(state, hq).action).override_failure_message(
		"Fixture: nothing proposed even with funds.").is_not_null()
	state.per_player[0].current_credits = 0
	assert_object(_score(state, hq).action).is_null()


func test_no_candidate_while_research_is_in_progress() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	assert_object(_score(state, hq).action).is_not_null()
	hq.research_target = Techs.ATTACK_I
	hq.research_turns_remaining = 2
	assert_object(_score(state, hq).action).is_null()


func test_research_shares_the_economy_cadence_cap() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	assert_object(_score(state, hq).action).is_not_null()
	assert_object(_score(state, hq, AIBalance.ai.max_economy_investments_per_turn).action).is_null()


func test_never_proposes_the_other_half_of_a_chosen_branch() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	_structure(state, 0, Vector2i(4, 2), StructureTypes.RESEARCH_LAB)
	for t: TechDef in [Techs.ATTACK_I, Techs.DEFENSE_I, Techs.ECONOMY_I, Techs.PENETRATION, Techs.PLATING]:
		GameStateFactory.grant_tech(state, 0, t)
	# Only Logistics / Foundry remain legal; Volley and Field Repair are locked out.
	var best := _score(state, hq)
	assert_bool(best.action is ResearchAction).is_true()
	var tech: TechDef = (best.action as ResearchAction).tech
	assert_bool(tech == Techs.LOGISTICS or tech == Techs.FOUNDRY).override_failure_message(
		"AI proposed %s." % tech.display_name).is_true()


func test_choose_action_never_cancels_research() -> void:
	# S8-17: never give the AI a cancel-for-refund loop. Research in progress, plenty
	# of money: whatever it picks, it is not a CancelResearchAction.
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	_structure(state, 1, Vector2i(13, 13), StructureTypes.HQ)
	hq.research_target = Techs.ATTACK_I
	hq.research_turns_remaining = 3
	var action: Action = AI.choose_action(state, 0)
	assert_bool(action is CancelResearchAction).is_false()


# --- The Lab --------------------------------------------------------------------

func test_a_lab_is_worthless_before_it_would_unlock_anything() -> void:
	var state := _state()
	_structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	assert_float(AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)).is_equal_approx(0.0, 0.0001)


func test_a_lab_is_worth_something_once_a_tier_one_parent_is_held() -> void:
	var state := _state()
	_structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_float(AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)).is_greater(0.0)


func test_a_lab_counts_a_parent_that_is_still_being_researched() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	hq.research_target = Techs.DEFENSE_I
	hq.research_turns_remaining = 2
	assert_float(AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)).is_greater(0.0)


func test_a_second_lab_is_worthless() -> void:
	var state := _state()
	_structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	_structure(state, 0, Vector2i(4, 2), StructureTypes.RESEARCH_LAB)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_float(AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)).is_equal_approx(0.0, 0.0001)


func test_lab_valuation_does_not_touch_the_real_state() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	hq.research_target = Techs.DEFENSE_I
	hq.research_turns_remaining = 2
	var entity_count: int = state.entities_by_id.size()
	AI._economy_value(state, 0, StructureTypes.RESEARCH_LAB)
	assert_int(state.entities_by_id.size()).is_equal(entity_count)
	assert_array(state.per_player[0].completed_techs).is_empty()


# --- Determinism (ADR-0003) -------------------------------------------------------

func test_same_state_same_choice_and_on_a_clone() -> void:
	var state := _state()
	var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
	_unit(state, 0, Vector2i(6, 6), UnitTypes.TROOPER)
	var a: ResearchAction = _score(state, hq).action
	var b: ResearchAction = _score(state, hq).action
	var copy := state.clone()
	var c: ResearchAction = AI._score_research_candidates(copy, copy.entities_by_id[hq.entity_id], 0, AI._Candidate.new()).action
	assert_object(b.tech).is_same(a.tech)
	assert_object(c.tech).is_same(a.tech)


# --- Per-match research lean (2026-10-01) -----------------------------------------------------

func test_research_lean_is_neutral_without_a_match_seed() -> void:
	var state := _state()
	for t: TechDef in Techs.ALL:
		assert_float(AI._research_lean(state, 0, t)).is_equal(1.0)


func test_research_lean_is_fixed_within_a_match_and_bounded() -> void:
	var state := _state()
	state.match_seed = 12345
	var v: float = AIBalance.ai.research_variety
	for t: TechDef in Techs.ALL:
		var lean: float = AI._research_lean(state, 0, t)
		assert_float(AI._research_lean(state, 0, t)).is_equal(lean)
		assert_float(lean).is_between(1.0 - v, 1.0 + v)


func test_different_matches_open_research_differently() -> void:
	var first_picks: Dictionary = {}
	for seed: int in range(1, 41):
		var state := _state()
		state.match_seed = seed
		var hq := _structure(state, 0, Vector2i(2, 2), StructureTypes.HQ)
		var best := _score(state, hq)
		if best.action is ResearchAction:
			first_picks[(best.action as ResearchAction).tech.display_name] = true
	assert_int(first_picks.size()).override_failure_message(
		"40 different match seeds all opened with the same tech: %s" % str(first_picks.keys())
	).is_greater(1)


# ★ 2026-10-02 balance pass: every TechDef effect field must carry a price ON ITS OWN. A whole-tech
# check passes as long as one field is priced, which is how Hardpoints' hq_range went unpriced
# beside its priced hq_hp_bonus/hq_attack. Walks the "Effects" export group so a field added later
# fails here until the AI values it. Arrays are skipped: they qualify other fields (bonus_unit_types,
# aura_structures) or are faction plumbing (replaces); frees_pilots is priced separately.
func test_every_effect_field_is_priced_on_its_own() -> void:
	var state := _state()
	# Cost-discount fields are priced off the cheapest unit the player can produce, so give it a
	# producer; without one they are legitimately worth 0.
	_structure(state, 0, Vector2i(4, 4), StructureTypes.BARRACKS)
	var in_effects := false
	for prop: Dictionary in TechDef.new().get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			in_effects = prop.name == "Effects"
			continue
		if not in_effects or not (prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		if prop.type != TYPE_INT and prop.type != TYPE_BOOL:
			continue
		var t := TechDef.new()
		t.display_name = "probe_%s" % prop.name
		t.research_time = 3
		t.set(prop.name, true if prop.type == TYPE_BOOL else 1)
		assert_float(AI._tech_research_value(state, 0, t, false)).override_failure_message(
			"AI gives TechDef.%s no value on its own" % prop.name).is_greater(0.0)
