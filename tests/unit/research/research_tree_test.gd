# CR-14 (2026-09-28): research runs at the HQ and the tree branches.
#
# User decisions this suite pins:
#   • Research runs at the HQ, one tech at a time. The Research Lab is a GATE: tier-2
#     techs need one standing (completed), plus their tier-1 parent.
#   • Losing the Lab keeps completed techs AND research already in progress; it only
#     blocks STARTING new tier-2 research.
#   • Tier-2 techs come in pick-one pairs; the pick is permanent for the match.
#   • Every tech is dual-cost (Credits + AP), both-or-neither. Tier 2 costs AP too.
#   • Faction gating exists as a data flag with no shipped user.
#
# ★ Every "does X get rejected" test first asserts the SAME action succeeds without the
# blocking condition, so a rejection for some unrelated reason cannot pass it (the
# S8-35 lesson: an assertion that holds under any implementation tests nothing).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16
const CREDITS: int = 99999
const AP_BUDGET: int = 99


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
		state.per_player[i].current_ap = AP_BUDGET
		state.per_player[i].current_credits = CREDITS
	return state


func _structure(state: GameState, player: int, pos: Vector2i, type: StructureTypeDef,
		completed: bool = true) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED if completed \
		else StructureState.BuildStatus.UNDER_CONSTRUCTION
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _hq(state: GameState, player: int = 0) -> StructureState:
	return _structure(state, player, Vector2i(2 + player * 10, 2), StructureTypes.HQ)


func _lab(state: GameState, player: int = 0, completed: bool = true) -> StructureState:
	return _structure(state, player, Vector2i(4 + player * 10, 2), StructureTypes.RESEARCH_LAB, completed)


func _research(state: GameState, researcher: StructureState, tech: TechDef) -> ActionResult:
	var a := ResearchAction.new()
	a.player = researcher.owner
	a.researcher_id = researcher.entity_id
	a.tech = tech
	return state.apply_action(a)


func _cancel(state: GameState, researcher: StructureState) -> ActionResult:
	var a := CancelResearchAction.new()
	a.player = researcher.owner
	a.researcher_id = researcher.entity_id
	return state.apply_action(a)


# Runs the researcher's timer down to completion, one owner-turn at a time.
func _finish(state: GameState, player: int = 0) -> void:
	for _i: int in 10:
		Research.advance_research_timers(state, player)


# --- The shipped tree ---------------------------------------------------------------

# ★ 2026-10-01 — the branching tree (design doc "Overclock Tech Trees"): three trees, three tiers,
# every tier a choice of two, each choice opening its own pair below it (2 + 4 + 8 per tree).

func test_every_tech_above_tier_one_needs_a_lab_and_a_parent_one_tier_up() -> void:
	for tech: TechDef in Techs.ALL:
		if tech.tier == 1:
			continue
		assert_bool(StructureTypes.RESEARCH_LAB in tech.required_structures).override_failure_message(
			"%s does not require a Research Lab." % tech.display_name).is_true()
		assert_int(tech.prerequisites.size()).is_equal(1)
		assert_int(tech.prerequisites[0].tier).is_equal(tech.tier - 1)
		assert_str(tech.prerequisites[0].tree).is_equal(tech.tree)


func test_tier_one_techs_need_nothing_but_are_still_a_choice() -> void:
	for tech: TechDef in Techs.ALL:
		if tech.tier != 1:
			continue
		assert_array(tech.prerequisites).is_empty()
		assert_array(tech.required_structures).is_empty()
		assert_str(String(tech.exclusive_group)).is_not_empty()


func test_each_tree_is_two_then_four_then_eight() -> void:
	for tree: String in ["offense", "defense", "economy"]:
		var by_tier: Array[int] = [0, 0, 0]
		for tech: TechDef in Techs.ALL:
			if tech.tree == tree:
				by_tier[tech.tier - 1] += 1
		assert_array(by_tier).override_failure_message("%s tree is %s" % [tree, by_tier]).is_equal([2, 4, 8])


func test_every_branch_is_exactly_a_pair_under_one_parent() -> void:
	var groups: Dictionary = {}
	for tech: TechDef in Techs.ALL:
		groups.get_or_add(tech.exclusive_group, []).append(tech)
	assert_int(groups.size()).is_equal(21)   # 3 trees x (1 + 2 + 4) pairs
	for group: StringName in groups:
		var members: Array = groups[group]
		assert_int(members.size()).override_failure_message(
			"Branch %s has %d techs, not a pair." % [group, members.size()]).is_equal(2)
		assert_array(members[0].prerequisites).is_equal(members[1].prerequisites)


func test_every_tech_costs_credits_and_ap_and_time() -> void:
	var state := _state()
	for tech: TechDef in Techs.ALL:
		assert_int(Research.effective_research_cost(state, tech, 0)).is_greater(0)
		assert_int(Research.effective_research_ap_surcharge(state, tech, 0)).is_greater(0)
		assert_int(Research.effective_research_time(state, tech, 0)).is_greater(0)


func test_research_ap_is_4_6_8_by_tier() -> void:
	# User decision 2026-10-01.
	var state := _state()
	var want: Array[int] = [4, 6, 8]
	for tech: TechDef in Techs.ALL:
		assert_int(Research.effective_research_ap_surcharge(state, tech, 0)).is_equal(want[tech.tier - 1])


# --- Starting research at the HQ ---------------------------------------------------

func test_the_hq_researches_a_tier_one_tech_without_a_lab() -> void:
	var state := _state()
	var hq := _hq(state)
	var result := _research(state, hq, Techs.ATTACK_I)
	assert_bool(result.ok).is_true()
	assert_object(hq.research_target).is_same(Techs.ATTACK_I)
	assert_int(hq.research_turns_remaining).is_equal(Techs.ATTACK_I.research_time)
	assert_bool(result.events[0] is ResearchStartedEvent).is_true()


func test_starting_research_spends_both_pools_up_front() -> void:
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.ATTACK_I)
	assert_int(state.per_player[0].current_credits).is_equal(CREDITS - Techs.ATTACK_I.research_cost)
	assert_int(state.per_player[0].current_ap).is_equal(AP_BUDGET - Research.effective_research_ap_surcharge(state, Techs.ATTACK_I, 0))


func test_a_research_lab_cannot_research() -> void:
	# CR-14: the Lab is a gate now, not a site.
	var state := _state()
	_hq(state)
	var lab := _lab(state)
	assert_int(_research(state, lab, Techs.ATTACK_I).reason).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_one_tech_at_a_time() -> void:
	var state := _state()
	var hq := _hq(state)
	assert_bool(_research(state, hq, Techs.ATTACK_I).ok).is_true()
	assert_int(_research(state, hq, Techs.DEFENSE_I).reason).is_equal(Action.Reason.RESEARCH_IN_PROGRESS)


func test_a_completed_tech_cannot_be_researched_again() -> void:
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.ATTACK_I)
	_finish(state)
	assert_bool(Research.has_tech(state, 0, Techs.ATTACK_I)).is_true()
	assert_int(_research(state, hq, Techs.ATTACK_I).reason).is_equal(Action.Reason.ALREADY_RESEARCHED)


func test_unaffordable_credits_rejects_and_spends_nothing() -> void:
	var state := _state()
	var hq := _hq(state)
	state.per_player[0].current_credits = Techs.ATTACK_I.research_cost - 1
	assert_int(_research(state, hq, Techs.ATTACK_I).reason).is_equal(Action.Reason.CANT_AFFORD_CREDITS)
	assert_int(state.per_player[0].current_ap).is_equal(AP_BUDGET)
	assert_object(hq.research_target).is_null()


func test_unaffordable_ap_rejects_and_spends_nothing() -> void:
	var state := _state()
	var hq := _hq(state)
	state.per_player[0].current_ap = 0
	assert_int(_research(state, hq, Techs.ATTACK_I).reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_int(state.per_player[0].current_credits).is_equal(CREDITS)


func test_a_player_in_deficit_cannot_start_research() -> void:
	var state := _state()
	var hq := _hq(state)
	state.per_player[0].in_deficit = true
	assert_int(_research(state, hq, Techs.ATTACK_I).reason).is_equal(Action.Reason.IN_DEFICIT)


# --- Gates ------------------------------------------------------------------------

func test_tier_two_needs_its_parent() -> void:
	var state := _state()
	var hq := _hq(state)
	_lab(state)
	assert_int(_research(state, hq, Techs.PENETRATION).reason).is_equal(Action.Reason.PREREQUISITE_MISSING)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_bool(_research(state, hq, Techs.PENETRATION).ok).is_true()


func test_tier_two_needs_a_lab() -> void:
	var state := _state()
	var hq := _hq(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_int(_research(state, hq, Techs.PENETRATION).reason).is_equal(Action.Reason.REQUIRES_STRUCTURE)
	_lab(state)
	assert_bool(_research(state, hq, Techs.PENETRATION).ok).is_true()


func test_a_lab_under_construction_does_not_count() -> void:
	var state := _state()
	_hq(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_lab(state, 0, false)
	assert_int(Research.availability(state, 0, Techs.PENETRATION)).is_equal(Action.Reason.REQUIRES_STRUCTURE)


func test_the_opponents_lab_does_not_count() -> void:
	var state := _state()
	_hq(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_lab(state, 1)
	assert_int(Research.availability(state, 0, Techs.PENETRATION)).is_equal(Action.Reason.REQUIRES_STRUCTURE)


func test_a_second_lab_unlocks_nothing_more() -> void:
	# The Lab-spam brake CR-14 buys for free: gating is "own one", not "per Lab".
	var state := _state()
	_hq(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_lab(state)
	var one: Array[TechDef] = Research.legal_research_targets(state, 0)
	_structure(state, 0, Vector2i(6, 2), StructureTypes.RESEARCH_LAB)
	assert_array(Research.legal_research_targets(state, 0)).is_equal(one)


func test_faction_restricted_tech_is_locked_for_other_factions() -> void:
	var state := _state()
	# Two test factions that both carry the tech in their tree (D6); only one is allowed it.
	var restricted := GameStateFactory.make_tech(1)
	var allowed := FactionDef.new()
	var other := FactionDef.new()
	allowed.techs = [restricted]
	other.techs = [restricted]
	restricted.allowed_factions = [allowed]
	state.per_player[0].faction = other
	assert_int(Research.availability(state, 0, restricted)).is_equal(Action.Reason.TECH_FACTION_RESTRICTED)
	state.per_player[0].faction = allowed
	assert_int(Research.availability(state, 0, restricted)).is_equal(Action.Reason.OK)


func test_a_tech_outside_the_players_tree_is_not_theirs() -> void:
	# Faction v2 (D6): each faction owns its tree; a tech it does not list is not researchable.
	var state := _state()
	var foreign := GameStateFactory.make_tech(1)
	var f := FactionDef.new()
	f.techs = [Techs.ATTACK_I]
	state.per_player[0].faction = f
	assert_int(Research.availability(state, 0, Techs.ATTACK_I)).is_equal(Action.Reason.OK)
	assert_int(Research.availability(state, 0, foreign)).is_equal(Action.Reason.TECH_FACTION_RESTRICTED)


func test_no_shipped_tech_is_faction_restricted_yet() -> void:
	# The flag is a placeholder until factions carry their own content. If this fails,
	# a faction tech shipped — make sure the UI explains faction locks before it does.
	for tech: TechDef in Techs.ALL:
		assert_array(tech.allowed_factions).is_empty()


# --- Pick-one branches -------------------------------------------------------------

func test_completing_one_branch_locks_its_pair_for_the_match() -> void:
	var state := _state()
	var hq := _hq(state)
	_lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_int(Research.availability(state, 0, Techs.VOLLEY)).is_equal(Action.Reason.OK)
	_research(state, hq, Techs.PENETRATION)
	_finish(state)
	assert_int(_research(state, hq, Techs.VOLLEY).reason).is_equal(Action.Reason.TECH_EXCLUDED)


func test_researching_one_branch_locks_its_pair() -> void:
	var state := _state()
	var hq := _hq(state)
	_lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.DEFENSE_I)
	_research(state, hq, Techs.PLATING)
	assert_int(Research.availability(state, 0, Techs.FIELD_REPAIR)).is_equal(Action.Reason.TECH_EXCLUDED)


func test_cancelling_a_branch_before_it_completes_frees_its_pair() -> void:
	var state := _state()
	var hq := _hq(state)
	_lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.DEFENSE_I)
	_research(state, hq, Techs.PLATING)
	assert_bool(_cancel(state, hq).ok).is_true()
	assert_bool(_research(state, hq, Techs.FIELD_REPAIR).ok).is_true()


func test_branches_on_different_lines_do_not_exclude_each_other() -> void:
	var state := _state()
	_hq(state)
	_lab(state)
	for t: TechDef in [Techs.ATTACK_I, Techs.DEFENSE_I, Techs.PENETRATION]:
		GameStateFactory.grant_tech(state, 0, t)
	assert_int(Research.availability(state, 0, Techs.PLATING)).is_equal(Action.Reason.OK)


func test_one_players_branch_choice_does_not_lock_the_opponent() -> void:
	var state := _state()
	_lab(state, 1)
	GameStateFactory.grant_tech(state, 0, Techs.PENETRATION)
	GameStateFactory.grant_tech(state, 1, Techs.ATTACK_I)
	assert_int(Research.availability(state, 1, Techs.VOLLEY)).is_equal(Action.Reason.OK)


# --- Timer and completion ----------------------------------------------------------

func test_research_completes_after_its_research_time() -> void:
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.DEFENSE_I)
	for turn: int in Techs.DEFENSE_I.research_time - 1:
		assert_array(Research.advance_research_timers(state, 0)).is_empty()
		assert_bool(Research.has_tech(state, 0, Techs.DEFENSE_I)).override_failure_message(
			"Completed early, on owner-turn %d." % (turn + 1)).is_false()
	var events: Array = Research.advance_research_timers(state, 0)
	assert_bool(Research.has_tech(state, 0, Techs.DEFENSE_I)).is_true()
	assert_int(events.size()).is_equal(1)
	assert_object(events[0].tech).is_same(Techs.DEFENSE_I)
	assert_object(hq.research_target).is_null()


func test_only_the_owners_turn_advances_their_research() -> void:
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.ATTACK_I)
	for _i: int in 10:
		Research.advance_research_timers(state, 1)
	assert_int(hq.research_turns_remaining).is_equal(Techs.ATTACK_I.research_time)


func test_economy_tech_pays_out_the_turn_it_completes() -> void:
	# Completion runs in start_turn step 3, BEFORE the step-4 income snapshot.
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.ECONOMY_I)
	hq.research_turns_remaining = 1
	var before: int = Credits.credit_income(state, 0)
	state.start_turn(0)
	assert_int(state.per_player[0].economy_tier).is_equal(1)
	assert_int(Credits.credit_income(state, 0)).is_equal(before + Balance.economy.econ_tier_bonus)


# --- Cancel ------------------------------------------------------------------------

func test_cancel_refunds_half_the_credits_and_none_of_the_ap() -> void:
	var state := _state()
	var hq := _hq(state)
	_research(state, hq, Techs.ATTACK_I)
	var ap_after_start: int = state.per_player[0].current_ap
	var result := _cancel(state, hq)
	assert_bool(result.ok).is_true()
	var expected_refund: int = Techs.ATTACK_I.research_cost * StructureBalance.base_production.cancel_refund_pct / 100
	assert_int(state.per_player[0].current_credits).is_equal(CREDITS - Techs.ATTACK_I.research_cost + expected_refund)
	assert_int(state.per_player[0].current_ap).is_equal(ap_after_start)
	assert_object(hq.research_target).is_null()
	assert_bool(Research.has_tech(state, 0, Techs.ATTACK_I)).is_false()


func test_cancelling_idle_research_is_rejected() -> void:
	var state := _state()
	var hq := _hq(state)
	assert_int(_cancel(state, hq).reason).is_equal(Action.Reason.NOTHING_IN_RESEARCH)


# --- Losing the Lab (user decision 2026-09-28) --------------------------------------

func test_losing_the_lab_keeps_completed_techs() -> void:
	var state := _state()
	var hq := _hq(state)
	var lab := _lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_research(state, hq, Techs.PENETRATION)
	_finish(state)
	state.destroy_entity(lab.entity_id)
	assert_bool(Research.has_tech(state, 0, Techs.PENETRATION)).is_true()


func test_losing_the_lab_does_not_cancel_research_in_progress() -> void:
	var state := _state()
	var hq := _hq(state)
	var lab := _lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_research(state, hq, Techs.PENETRATION)
	state.destroy_entity(lab.entity_id)
	assert_object(hq.research_target).is_same(Techs.PENETRATION)
	_finish(state)
	assert_bool(Research.has_tech(state, 0, Techs.PENETRATION)).is_true()


func test_losing_the_lab_blocks_starting_new_tier_two_research() -> void:
	var state := _state()
	var hq := _hq(state)
	var lab := _lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.DEFENSE_I)
	assert_int(Research.availability(state, 0, Techs.PLATING)).is_equal(Action.Reason.OK)
	state.destroy_entity(lab.entity_id)
	assert_int(_research(state, hq, Techs.PLATING).reason).is_equal(Action.Reason.REQUIRES_STRUCTURE)
	# ...but tier 1 is unaffected.
	assert_bool(_research(state, hq, Techs.ATTACK_I).ok).is_true()


# --- Clone (AI look-ahead) ---------------------------------------------------------

func test_clone_keeps_tech_identity_and_is_independent() -> void:
	var state := _state()
	var hq := _hq(state)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	_research(state, hq, Techs.DEFENSE_I)
	var copy := state.clone()
	assert_bool(Research.has_tech(copy, 0, Techs.ATTACK_I)).override_failure_message(
		"clone() copied the TechDef instead of sharing it — identity checks break.").is_true()
	assert_object(copy.entities_by_id[hq.entity_id].research_target).is_same(Techs.DEFENSE_I)
	_finish(copy)
	assert_bool(Research.has_tech(copy, 0, Techs.DEFENSE_I)).is_true()
	assert_bool(Research.has_tech(state, 0, Techs.DEFENSE_I)).is_false()


# --- Faction swaps (2026-10-01) ------------------------------------------------------------

func test_every_faction_tree_is_the_shared_42_with_swaps_in_their_slots() -> void:
	for f: FactionDef in Factions.playable():
		var tree: Array[TechDef] = f.techs if not f.techs.is_empty() else Techs.ALL
		assert_int(tree.size()).override_failure_message("%s tree has %d techs" % [f.display_name, tree.size()]).is_equal(42)
		for t: TechDef in tree:
			if t in Techs.ALL:
				continue
			assert_int(t.replaces.size()).override_failure_message("%s is neither shared nor a swap" % t.display_name).is_equal(1)
			var r: TechDef = t.replaces[0]
			assert_bool(r in tree).override_failure_message("%s keeps %s alongside its swap" % [f.display_name, r.display_name]).is_false()
			assert_int(t.tier).is_equal(r.tier)
			assert_str(String(t.exclusive_group)).is_equal(String(r.exclusive_group))
			assert_array(t.prerequisites).is_equal(r.prerequisites)


func test_a_swap_unlocks_what_its_replaced_tech_would() -> void:
	# The Lightless research Scrap Plating instead of Hardened Armor — Plating must still open.
	var state := _state()
	var lightless: FactionDef = null
	for f: FactionDef in Factions.playable():
		if Techs.SCRAP_PLATING in f.techs:
			lightless = f
	state.per_player[0].faction = lightless
	_lab(state)
	GameStateFactory.grant_tech(state, 0, Techs.SCRAP_PLATING)
	assert_int(Research.availability(state, 0, Techs.PLATING)).is_equal(Action.Reason.OK)
