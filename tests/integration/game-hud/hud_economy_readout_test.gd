# S6-07: the HUD economy readout — gross / upkeep / net, and current/max population.
#
# Covers design/gdd/unit-upkeep.md UR-8 / AC-19 / AC-20 and
# design/gdd/population-cap.md AC-12 against IncomeBreakdownWidget and
# PopulationWidget.
#
# WHY this story exists: the cross-review's blocker B-3. The income popover was
# still RENDERING `base + outpost + econ_tech` after S6-01 deleted the Economy
# Outpost, so a player saw two permanently-zero terms for mechanics that no longer
# exist -- and could not see upkeep or net at all, which are the figures that now
# decide whether their army is affordable. The widget's data model was repointed in
# S6-01; its _draw() was not. This suite covers the whole readout so the two cannot
# drift apart again.
#
# Deterministic: no RNG, no time, no rendering asserted (the display model is).
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
	return state


func _add_unit(state: GameState, player: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
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


func _add_structure(state: GameState, player: int, type: StructureTypeDef,
		pos: Vector2i) -> StructureState:
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


func _income(state: GameState, player: int = 0) -> IncomeBreakdownWidget:
	var w: IncomeBreakdownWidget = auto_free(IncomeBreakdownWidget.new())
	w.bind(GameStateReader.new(state))
	var cfg := HUDConfig.new()
	cfg.income_breakdown_default_expanded = true
	w.configure(cfg, player)
	add_child(w)
	return w


func _pop(state: GameState, player: int = 0) -> PopulationWidget:
	var w: PopulationWidget = auto_free(PopulationWidget.new())
	w.bind(GameStateReader.new(state))
	w.configure(player)
	add_child(w)
	return w


func _commit(state: GameState, events: Array = []) -> void:
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))


# ==============================================================================
# AC-19: gross, upkeep and net are three distinct readable figures.
# ==============================================================================

func test_the_three_figures_are_read_verbatim_from_the_economy() -> void:
	var state := _state()
	_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(3, 2))
	var w := _income(state)

	var expected: Dictionary = Credits.credit_income_breakdown(state, 0)
	assert_int(w.gross_value()).is_equal(expected["base"] + expected["tiers"])
	assert_int(w.upkeep_value()).is_equal(Upkeep.total_upkeep(state, 0))
	assert_int(w.net_value()).is_equal(Upkeep.net_credit_income(state, 0))


func test_net_is_read_from_the_economy_not_recomputed_by_the_hud() -> void:
	# ★ The Pass-Through Invariant, stated as a property rather than trusted. If
	# net_value() were ever changed to compute gross - upkeep locally, this still
	# passes -- so it is NOT the guard. The guard is that all three agree with the
	# economy's own numbers, which the assertion above covers. What THIS test pins
	# is the arithmetic relationship itself: if the economy ever stops satisfying
	# gross - upkeep == net (a rounding change, a new term), the HUD must surface
	# the economy's answer, and this test will fail loudly at the seam rather than
	# the discrepancy reaching a player as two figures that do not subtract.
	var state := _state()
	_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(4, 4))
	var w := _income(state)
	assert_int(w.net_value()).override_failure_message(
		"gross %d - upkeep %d should equal net %d; if the economy grew a term the HUD does not show, UR-8 is broken"
			% [w.gross_value(), w.upkeep_value(), w.net_value()]
	).is_equal(w.gross_value() - w.upkeep_value())


func test_an_army_with_no_units_has_zero_upkeep_and_net_equals_gross() -> void:
	var state := _state()
	var w := _income(state)
	assert_int(w.upkeep_value()).is_equal(0)
	assert_int(w.net_value()).is_equal(w.gross_value())
	assert_bool(w.is_deficit()).is_false()


func test_enough_units_drive_net_negative_and_the_widget_reports_a_deficit() -> void:
	# The equilibrium UR-8 says a player must see coming. Add Heavies until upkeep
	# outruns gross income -- the readout must flip to a deficit exactly when the
	# economy does, not a turn late.
	var state := _state()
	var gross: int = Credits.credit_income_breakdown(state, 0)["base"]
	var per_unit: int = UnitTypes.HEAVY.upkeep
	assert_int(per_unit).is_greater(0)
	var needed: int = int(gross / per_unit) + 1
	for i: int in needed:
		_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(2 + i, 5))

	var w := _income(state)
	assert_bool(w.is_deficit()).is_true()
	assert_int(w.net_value()).is_less(0)
	assert_int(w.net_value()).is_equal(Upkeep.net_credit_income(state, 0))


func test_losing_a_unit_lowers_upkeep_and_lifts_net_on_the_next_commit() -> void:
	var state := _state()
	var doomed := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 2))
	var w := _income(state)
	var upkeep_before: int = w.upkeep_value()
	var net_before: int = w.net_value()

	state.entities_by_id.erase(doomed.entity_id)
	_commit(state)

	assert_int(w.upkeep_value()).is_less(upkeep_before)
	assert_int(w.net_value()).is_greater(net_before)


# ==============================================================================
# AC-20: a prospective purchase's effect on net is previewable before commit.
# ==============================================================================

func test_preview_projects_net_after_the_purchase_without_touching_live_net() -> void:
	var state := _state()
	var w := _income(state)
	var live_net: int = w.net_value()
	var delta: int = Upkeep.default_upkeep(UnitTypes.HEAVY.produce_cost)

	assert_bool(w.is_previewing()).is_false()
	assert_int(w.previewed_net_value()).is_equal(live_net)

	w.open_preview(delta)
	assert_bool(w.is_previewing()).is_true()
	assert_int(w.previewed_net_value()).is_equal(live_net - delta)
	# The live figure must be untouched -- a projection is not state.
	assert_int(w.net_value()).is_equal(live_net)

	w.close_preview()
	assert_bool(w.is_previewing()).is_false()
	assert_int(w.previewed_net_value()).is_equal(live_net)


func test_a_preview_can_show_the_purchase_that_would_tip_the_player_into_deficit() -> void:
	# The point of AC-20: the player finds out BEFORE committing, not after.
	var state := _state()
	var gross: int = Credits.credit_income_breakdown(state, 0)["base"]
	var per_unit: int = UnitTypes.HEAVY.upkeep
	var affordable: int = int(gross / per_unit)
	for i: int in affordable:
		_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(2 + i, 5))

	var w := _income(state)
	assert_bool(w.is_deficit()).is_false() # still solvent...
	w.open_preview(per_unit)
	assert_int(w.previewed_net_value()).override_failure_message(
		"the purchase that breaks the economy must read as negative BEFORE it is committed"
	).is_less(0)


func test_a_commit_clears_an_open_preview() -> void:
	# The previewed purchase has now either happened or been overtaken; leaving the
	# projection up would show a number derived from a stale baseline.
	var state := _state()
	var w := _income(state)
	w.open_preview(500)
	assert_bool(w.is_previewing()).is_true()
	_commit(state)
	assert_bool(w.is_previewing()).is_false()


func test_a_zero_upkeep_preview_is_distinguishable_from_no_preview() -> void:
	# _preview_upkeep_delta uses -1 as "closed" precisely so 0 stays a real value.
	var state := _state()
	var w := _income(state)
	w.open_preview(0)
	assert_bool(w.is_previewing()).is_true()
	assert_int(w.previewed_net_value()).is_equal(w.net_value())


# ==============================================================================
# population-cap AC-12: current/max population and a stated reason at the cap.
# ==============================================================================

func test_population_reads_current_and_cap_verbatim() -> void:
	var state := _state()
	_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(3, 2))
	var w := _pop(state)
	assert_int(w.population_value()).is_equal(Population.current_population(state, 0))
	assert_int(w.cap_value()).is_equal(Population.effective_cap(state, 0))


func test_a_barracks_raises_the_cap_the_widget_reports() -> void:
	var state := _state()
	var w := _pop(state)
	var cap_before: int = w.cap_value()
	_add_structure(state, 0, StructureTypes.BARRACKS, Vector2i(6, 6))
	_commit(state)
	assert_int(w.cap_value()).is_greater(cap_before)


func test_at_cap_reports_a_reason_naming_the_barracks_remedy() -> void:
	var state := _state()
	var w := _pop(state)
	var cap: int = w.cap_value()
	for i: int in cap:
		_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(1 + i, 8))
	_commit(state)

	assert_bool(w.is_at_cap()).is_true()
	assert_str(w.cap_reason()).contains("Barracks")
	assert_str(w.cap_reason()).contains("%d/%d" % [w.population_value(), w.cap_value()])


func test_below_cap_states_no_reason() -> void:
	var state := _state()
	var w := _pop(state)
	assert_bool(w.is_at_cap()).is_false()
	assert_str(w.cap_reason()).is_empty()


func test_over_cap_after_losing_a_barracks_is_reported_as_at_cap_with_its_own_reason() -> void:
	# ★ population-cap.md AC-11: the cap can FALL beneath a standing army, so a
	# player can sit above their cap without ever having produced past it. An
	# equality test would call that state "has headroom" and offer production the
	# rules forbid. The wording differs too -- "build a Barracks to raise it" is
	# wrong advice for a player who just LOST one.
	var state := _state()
	var barracks := _add_structure(state, 0, StructureTypes.BARRACKS, Vector2i(6, 6))
	var w := _pop(state)
	var raised_cap: int = w.cap_value()
	for i: int in raised_cap:
		_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(1 + i, 8))
	_commit(state)
	assert_bool(w.is_at_cap()).is_true()

	state.entities_by_id.erase(barracks.entity_id)
	_commit(state)

	assert_int(w.population_value()).override_failure_message(
		"losing a Barracks must lower the cap without destroying units"
	).is_greater(w.cap_value())
	assert_bool(w.is_at_cap()).is_true()
	assert_str(w.cap_reason()).contains("Barracks was lost")


func test_near_cap_warns_before_the_cap_binds() -> void:
	var state := _state()
	var w := _pop(state)
	var cap: int = w.cap_value()
	for i: int in cap - PopulationWidget.NEAR_CAP_SLACK:
		_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(1 + i, 8))
	_commit(state)
	assert_bool(w.is_at_cap()).is_false()
	assert_bool(w.is_near_cap()).is_true()
