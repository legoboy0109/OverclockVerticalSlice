# Story 004: Cancel-Build Destructive Gesture (Hold-to-Confirm).
#
# Covers production/epics/command-action-interface/story-004-cancel-build-gesture.md
# (TR-cmdui-002, ADR-0015 §2):
#
#   Menu: an under-construction structure the active player owns offers Cancel
#     Build (enabled); a Completed structure — or any other entity — never does
#     (disabled, Reason.NOT_UNDER_CONSTRUCTION). The refund shown equals
#     BaseProduction.cancel_refund(effective_build_cost) exactly (Pass-Through).
#   Gesture (AC-18): holding to >= cancel_build_hold_ms commits a
#     CancelBuildAction (current_ap increases by exactly the previewed refund);
#     a bare click / release-before-threshold aborts with no refund, no state
#     change; a rapid double-click can never sustain a hold.
#   Structural (TR-cmdui-002): no new CommandFSM.State — the hold is a
#     sub-condition of ENTITY_SELECTED; the State enum stays at 7 values.
#
# Logic story: the hold accumulator (tick_cancel_hold) is driven DIRECTLY with
# synthetic delta_ms/is_pressed values — no real _process, Input, or InputMap.
# The commit goes through the real GameState.apply_action pipeline (no stub).
# Fixtures pin both players to Factions.NEUTRAL so effective_build_cost == the
# base build_cost (mirrors the cai-001/002/003 fixture convention);
# auto_free() every CommandInterface Node fixture (recompute_tiers_test.gd's
# precedent — Node fixtures leak orphans otherwise). Deterministic: no RNG, no
# time-dependent assertions, no external I/O.
extends GdUnitTestSuite


# --- Fixture helpers ----------------------------------------------------------

func _make_blank_grid(size: int = 10) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.grid = _make_blank_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_structure_type(build_cost: int = 6) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestBuildable"
	type.hp = 20
	type.build_cost = build_cost
	type.build_time = 2
	type.production_cap = 0
	return type


func _place_structure(state: GameState, entity_id: int, owner: int, pos: Vector2i, \
		type: StructureTypeDef, build_status: int = StructureState.BuildStatus.UNDER_CONSTRUCTION) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = build_status
	state.entities_by_id[entity_id] = structure
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return structure


func _config(hold_ms: int) -> InputConfig:
	var c := InputConfig.new()
	c.cancel_build_hold_ms = hold_ms
	return c


func _cancel_entry(state: GameState, entity: EntityState) -> CommandFSM.VerbEntry:
	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, entity)
	return menu[CommandFSM.Verb.CANCEL_BUILD]


# ==============================================================================
# Menu: Cancel-Build offered only for an under-construction owned structure.
# ==============================================================================

func test_menu_offers_cancel_build_for_under_construction_owned_structure() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type)

	var entry: CommandFSM.VerbEntry = _cancel_entry(state, structure)

	assert_bool(entry.enabled).is_true()
	assert_int(entry.reason).is_equal(CommandFSM.Reason.NONE)


func test_menu_never_offers_cancel_build_for_completed_structure() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type, \
		StructureState.BuildStatus.COMPLETED)

	var entry: CommandFSM.VerbEntry = _cancel_entry(state, structure)

	assert_bool(entry.enabled).is_false()
	assert_int(entry.reason).is_equal(CommandFSM.Reason.NOT_UNDER_CONSTRUCTION)


func test_menu_never_offers_cancel_build_for_enemy_under_construction_structure() -> void:
	# Owned by player 1 while player 0 is active — you cannot cancel an enemy's build.
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 2, 1, Vector2i(5, 5), type)

	var entry: CommandFSM.VerbEntry = _cancel_entry(state, structure)

	assert_bool(entry.enabled).is_false()
	assert_int(entry.reason).is_equal(CommandFSM.Reason.NOT_UNDER_CONSTRUCTION)


func test_cancel_build_preview_equals_base_production_query() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type)

	var previewed: int = CommandFSM.cancel_build_preview(state, structure)
	var expected: int = BaseProduction.cancel_refund(BaseProduction.effective_build_cost(state, type, 0))

	assert_int(previewed).is_equal(expected)
	assert_int(previewed).is_greater(0) # a non-trivial refund, so AP-delta assertions below are meaningful.


# ==============================================================================
# Gesture (AC-18): hold to threshold commits + refunds; sub-threshold aborts.
# ==============================================================================

func test_hold_reaching_threshold_commits_and_refunds_exactly_the_previewed_amount() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 3

	var refund: int = CommandFSM.cancel_build_preview(state, structure)
	var credits_before: int = Credits.current_credits(state, 0)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface.set_input_config(_config(100))

	# Two 60ms ticks while held cross the 100ms threshold on the second.
	var first: int = iface.tick_cancel_hold(60.0, true, state, structure)
	assert_int(first).is_equal(CommandInterface.CancelHoldResult.CONTINUE)
	var second: int = iface.tick_cancel_hold(60.0, true, state, structure)
	assert_int(second).is_equal(CommandInterface.CancelHoldResult.COMMITTED)

	# current_credits increased by EXACTLY the previewed refund (Credits refund,
	# ADR-0006 pivot: cancel-build refunds Credits, not AP — real apply_cancel).
	assert_int(Credits.current_credits(state, 0) - credits_before).is_equal(refund)


func test_bare_click_never_triggers_cancel_build() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 3
	var ap_before: int = AP.current_ap(state, 0)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface.set_input_config(_config(500))

	# A press for one short frame, then release — a bare click cannot sustain a hold.
	assert_int(iface.tick_cancel_hold(16.0, true, state, structure)).is_equal(CommandInterface.CancelHoldResult.CONTINUE)
	assert_int(iface.tick_cancel_hold(16.0, false, state, structure)).is_equal(CommandInterface.CancelHoldResult.ABORTED)

	# No commit — AP unchanged, structure still under construction.
	assert_int(AP.current_ap(state, 0)).is_equal(ap_before)
	assert_bool(state.entities_by_id.has(1)).is_true()
	assert_int((state.entities_by_id[1] as StructureState).build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)


func test_release_one_ms_before_threshold_aborts_no_refund_no_state_change() -> void:
	var state := _make_state(0)
	var type := _make_structure_type(6)
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 3
	var ap_before: int = AP.current_ap(state, 0)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface.set_input_config(_config(100))

	# Accumulate to exactly threshold - 1, then release.
	assert_int(iface.tick_cancel_hold(99.0, true, state, structure)).is_equal(CommandInterface.CancelHoldResult.CONTINUE)
	assert_int(iface.tick_cancel_hold(1.0, false, state, structure)).is_equal(CommandInterface.CancelHoldResult.ABORTED)

	assert_int(AP.current_ap(state, 0)).is_equal(ap_before)
	assert_bool(state.entities_by_id.has(1)).is_true()

	# Accumulator was reset by the abort: a fresh short press does NOT immediately
	# cross the threshold as if the prior 99ms had persisted.
	assert_int(iface.tick_cancel_hold(50.0, true, state, structure)).is_equal(CommandInterface.CancelHoldResult.CONTINUE)


# ==============================================================================
# Structural (TR-cmdui-002): no new top-level FSM state.
# ==============================================================================

func test_no_new_fsm_state_added_for_cancel_build() -> void:
	# The 7 states IDLE, ENTITY_SELECTED, PREVIEW_MOVE/ATTACK/PRODUCE/BUILD,
	# GAME_OVER — Cancel-Build is a hold sub-condition INSIDE ENTITY_SELECTED,
	# never a new top state.
	assert_int(CommandFSM.State.keys().size()).is_equal(7)
