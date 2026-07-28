# Story 001: GameStateReader Facade + Event-Driven Read Binding + Dirty-Flag
# Coalescing.
#
# Covers production/epics/game-hud/story-001-game-state-reader-facade.md
# (TR-hud-001/002/003/020/023, ADR-0016 §1/§8):
#
#   AC-3 (facade lint): a GameStateReader instance exposes no method that
#     mutates GameState — reflection over the facade's own declared method set
#     (get_script().get_script_method_list(), NOT get_method_list() which would
#     also scan inherited Object/RefCounted set_* methods) finds zero
#     mutation-shaped method name (apply_action/spend/set_*/mutate*).
#   AC-21 (verbatim pass-through): each new getter returns a known GameState's
#     values verbatim — zero recompute.
#   AC-2 (read-only invariance): HUD-only reads (including driving
#     HudReactiveControl's redraw handler) never perturb current_ap/
#     active_player/round_number or a queried entity's position/hp — read
#     values are bit-identical before vs after, and no commit/apply_action path
#     exists on the facade.
#   AC-1a (coalescing count): N action_applied emissions within one frame
#     coalesce to exactly 1 HudReactiveControl redraw; 0 events -> 0 redraws.
#
# AC-1b (DEFERRED, blocked-on-infra): a frame-stepped render-latency
# integration test (measuring the redraw actually lands within <=1 frame of the
# triggering commit, not merely that repeated triggers coalesce) needs a
# frame-stepped test harness that does not exist in this project yet. Per the
# story brief this is recorded here as a documented skip, not implemented —
# AC-1a (this file) is the coalescing-COUNT contract, testable today with the
# existing await get_tree().process_frame idiom; AC-1b is a latency-bound
# contract that needs stepped-frame control the harness doesn't offer yet.
#
# Deterministic: no random seeds, no wall-clock reads/tolerances — a single
# process_frame await, not a timing window.
extends GdUnitTestSuite


# --- Fixture helpers ---------------------------------------------------------

func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.round_number = 3
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	# entity_at() reads grid.occupant_at(), so a state that will be queried
	# through the facade needs a (blank) grid — make_state() is gridless.
	state.grid = _make_blank_grid(12, 12)
	return state


func _make_blank_grid(w: int, h: int) -> GridState:
	var grid := GridState.new()
	grid.width = w
	grid.height = h
	grid.terrain = PackedByteArray()
	grid.terrain.resize(w * h)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(w * h)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_unit_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestUnit"
	type.hp = 10
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 1
	type.produce_cost = 4
	return type


func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	state.entities_by_id[entity_id] = unit
	return unit


# ==============================================================================
# AC-3: facade lint — zero mutation-shaped method on the facade's own surface.
# ==============================================================================

func test_game_state_reader_exposes_no_mutation_shaped_method() -> void:
	# Arrange
	var state := _make_state()
	var reader := GameStateReader.new(state)
	var forbidden_prefixes: Array[String] = ["set_", "mutate"]
	var forbidden_substrings: Array[String] = ["apply_action", "spend"]

	# Act — scan ONLY the facade's own declared methods (not inherited Object/
	# RefCounted set_* like set_meta/set_script/set_block_signals).
	var offending: Array[String] = []
	for method: Dictionary in reader.get_script().get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("_"):
			continue # engine-internal / private-by-convention, not public surface.
		for prefix: String in forbidden_prefixes:
			if method_name.begins_with(prefix):
				offending.append(method_name)
		for substr: String in forbidden_substrings:
			if method_name.contains(substr):
				offending.append(method_name)

	# Assert
	assert_array(offending).override_failure_message(
		"GameStateReader exposes mutation-shaped method(s): %s" % [offending]
	).is_empty()


func test_game_state_reader_broker_methods_are_not_mutation_shaped() -> void:
	# The signal-subscription broker methods this story adds must themselves
	# pass the AC-3 lint — proven directly by name, not just implicitly above.
	var state := _make_state()
	var reader := GameStateReader.new(state)

	var names: Array[String] = []
	for method: Dictionary in reader.get_script().get_script_method_list():
		names.append(method["name"])

	assert_array(names).contains(["subscribe_action_applied", "unsubscribe_action_applied"])
	assert_bool("subscribe_action_applied".begins_with("set_")).is_false()
	assert_bool("unsubscribe_action_applied".begins_with("set_")).is_false()
	assert_bool("subscribe_action_applied".contains("apply_action")).is_false()
	assert_bool("subscribe_action_applied".contains("spend")).is_false()


# ==============================================================================
# AC-21: verbatim pass-through — getters return the known state's exact values.
# ==============================================================================

func test_game_state_reader_getters_return_verbatim_values() -> void:
	# Arrange
	var state := _make_state(1)
	state.round_number = 7
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	state.per_player[0].current_ap = 12

	# Act
	var reader := GameStateReader.new(state)

	# Assert — each getter returns the state's value verbatim, no recompute.
	assert_int(reader.active_player()).is_equal(1)
	assert_int(reader.round_number()).is_equal(7)
	assert_int(reader.match_status()).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(reader.current_ap(0)).is_equal(12)
	assert_bool(reader.can_afford(0, 12)).is_true()
	assert_bool(reader.can_afford(0, 13)).is_false()


func test_game_state_reader_income_breakdown_matches_ap_call_verbatim() -> void:
	# Proves income_breakdown() is a real pass-through (not a stub): it returns
	# the exact Dictionary AP.ap_income_breakdown() itself returns for the same
	# state/player — zero local re-derivation. (Comparing to the owning query's
	# own result IS the pass-through contract; a hardcoded literal would instead
	# re-test AP's arithmetic, which AP's own tests own.)
	var state := _make_state(0)
	var reader := GameStateReader.new(state)

	var expected: Dictionary = AP.ap_income_breakdown(state, 0)
	var actual: Dictionary = reader.income_breakdown(0)

	assert_int(actual["base"]).is_equal(expected["base"])
	assert_int(actual["outpost"]).is_equal(expected["outpost"])
	assert_int(actual["econ_tech"]).is_equal(expected["econ_tech"])


func test_game_state_reader_entities_and_entity_at_match_game_state_verbatim() -> void:
	# Arrange
	var state := _make_state(0)
	var unit := _place_unit(state, 5, 0, Vector2i(2, 3), _make_unit_type())

	var grid := _make_blank_grid(4, 4)
	grid.occupancy[grid.index(2, 3)] = 5
	state.grid = grid

	# Act
	var reader := GameStateReader.new(state)

	# Assert
	assert_int(reader.entities().size()).is_equal(1)
	assert_int(reader.entities()[0].entity_id).is_equal(5)
	assert_object(reader.entity_at(Vector2i(2, 3))).is_same(unit)
	assert_object(reader.entity_at(Vector2i(0, 0))).is_null()


# ==============================================================================
# AC-2: read-only invariance — HUD-only reads never perturb read values.
# ==============================================================================

func test_hud_only_reads_never_perturb_state_values() -> void:
	# Arrange
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(2, 2), _make_unit_type())
	state.per_player[0].current_ap = 8
	var reader := GameStateReader.new(state)

	var ap_before: int = reader.current_ap(0)
	var active_before: int = reader.active_player()
	var round_before: int = reader.round_number()
	var pos_before: Vector2i = unit.position
	var hp_before: int = unit.current_hp

	# Act — a burst of HUD-only reads, including driving the reactive control's
	# redraw handler (which only calls queue_redraw(), no state access).
	var control: HudReactiveControl = auto_free(HudReactiveControl.new())
	control.bind(reader)
	add_child(control)
	control._on_action_applied(ActionResult.new(true, Action.Reason.OK, []))
	reader.current_ap(0)
	reader.active_player()
	reader.round_number()
	reader.entities()
	reader.entity_at(Vector2i(9, 9))
	reader.income_breakdown(0)
	reader.can_afford(0, 100)

	# Assert — nothing moved.
	assert_int(reader.current_ap(0)).is_equal(ap_before)
	assert_int(reader.active_player()).is_equal(active_before)
	assert_int(reader.round_number()).is_equal(round_before)
	assert_vector(unit.position).is_equal(pos_before)
	assert_int(unit.current_hp).is_equal(hp_before)


func test_game_state_reader_has_no_apply_action_path() -> void:
	# Structural companion to AC-3, phrased as AC-2's own claim: there is no
	# commit entry point declared on the reader at all.
	var state := _make_state()
	var reader := GameStateReader.new(state)
	for method: Dictionary in reader.get_script().get_script_method_list():
		var method_name: String = method["name"]
		assert_bool(method_name == "apply_action").is_false()


# ==============================================================================
# AC-1a: coalescing count — N emissions within one frame -> exactly 1 redraw.
# ==============================================================================

func test_hud_reactive_control_coalesces_five_commits_into_one_redraw_per_frame() -> void:
	# Arrange
	var state := _make_state(0)
	_place_unit(state, 1, 0, Vector2i(0, 0), _make_unit_type())
	var reader := GameStateReader.new(state)
	var control: HudReactiveControl = auto_free(HudReactiveControl.new())
	control.bind(reader)
	add_child(control)
	# Let the Control's mandatory initial _draw() (on tree entry) settle first,
	# so the count below isolates ONLY event-driven redraws.
	await get_tree().process_frame
	# Box the counter in an Array: GDScript lambdas capture locals BY VALUE, so
	# a plain int would never see the increment — an Array is a reference type.
	var redraw_count: Array[int] = [0]
	control.draw.connect(func() -> void: redraw_count[0] += 1)

	# Act — 5 synchronous emissions within one frame.
	var result := ActionResult.new(true, Action.Reason.OK, [])
	for _i in 5:
		state.action_applied.emit(result)
	await get_tree().process_frame

	# Assert — native queue_redraw() coalesced 5 -> 1.
	assert_int(redraw_count[0]).is_equal(1)


func test_hud_reactive_control_zero_events_yields_zero_redraws() -> void:
	# Arrange
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var control: HudReactiveControl = auto_free(HudReactiveControl.new())
	control.bind(reader)
	add_child(control)
	# Let the mandatory initial _draw() settle, THEN start counting — proving
	# the event-driven layer does not redraw on a frame with no commit (no
	# per-_process polling redraw).
	await get_tree().process_frame
	var redraw_count: Array[int] = [0]
	control.draw.connect(func() -> void: redraw_count[0] += 1)

	# Act — no events.
	await get_tree().process_frame

	# Assert
	assert_int(redraw_count[0]).is_equal(0)


func test_hud_reactive_control_bind_before_and_after_tree_entry_both_subscribe() -> void:
	# Hardening property: bind() is safe either before or after tree entry, and
	# never double-subscribes (the reader broker's is_connected guard makes
	# double-calling idempotent). Both controls must redraw on a commit.
	var state := _make_state(0)
	var reader := GameStateReader.new(state)

	# Flow 1: bind() BEFORE add_child() -> _ready() subscribes.
	var early: HudReactiveControl = auto_free(HudReactiveControl.new())
	early.bind(reader)
	add_child(early)

	# Flow 2: add_child() BEFORE bind() -> bind()'s is_inside_tree() subscribes.
	var late: HudReactiveControl = auto_free(HudReactiveControl.new())
	add_child(late)
	late.bind(reader)

	# Settle both controls' mandatory initial draw before counting.
	await get_tree().process_frame

	var early_redraws: Array[int] = [0]
	var late_redraws: Array[int] = [0]
	early.draw.connect(func() -> void: early_redraws[0] += 1)
	late.draw.connect(func() -> void: late_redraws[0] += 1)

	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(early_redraws[0]).is_equal(1)
	assert_int(late_redraws[0]).is_equal(1)
