# Vertical slice boot — VerticalSliceRoot assembles the whole stack and runs the
# turn loop.
#
# Covers src/game/vertical_slice_root.gd — the bootable main scene. Proves the
# full stack (match → board → camera → CommandInterface → GameHud → AITurnDriver)
# boots without error and the human↔AI turn loop cycles a full round. Drives the
# loop through the root's own try_end_human_turn() entry point (no synthesised
# InputEvent). Deterministic: the AI turn is synchronous; we await idle frames
# only to let the deferred hand-off run.
extends GdUnitTestSuite

# run_ai_turn paces its commits via AIBalance.ai.commit_pacing_sec (a coroutine);
# shrink it to a tiny yield for these tests so the paced AI turn resolves fast and
# deterministically. Saved/restored per test (mirrors ai_turn_driver_loop_test) so
# no fast pacing leaks into an unrelated suite.
var _saved_commit_pacing_sec: float


func before_test() -> void:
	_saved_commit_pacing_sec = AIBalance.ai.commit_pacing_sec
	AIBalance.ai.commit_pacing_sec = 0.01


func after_test() -> void:
	AIBalance.ai.commit_pacing_sec = _saved_commit_pacing_sec


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(VerticalSliceRoot.new())
	add_child(root) # _ready() builds the whole slice.
	return root


# ==============================================================================
# Boot: a live match with a rendered board, an assembled HUD, and an AI opponent.
# ==============================================================================

func test_boots_a_live_match_with_board_hud_and_ai() -> void:
	var root := _make_root()
	var state := root.state()

	# Match is live.
	assert_object(state).is_not_null()
	assert_object(state.grid).is_not_null()
	assert_int(state.active_player).is_equal(0) # the human starts.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_bool(state.per_player[1].is_ai_controlled).is_true()
	assert_object(state.per_player[0].faction).is_not_null() # NEUTRAL pinned.

	# Two HQs placed, nothing else yet (the human hasn't acted, no AI turn ran).
	assert_int(state.entities().size()).is_equal(2)

	# Board + command interface + HUD all assembled and wired.
	assert_object(root.board()).is_not_null()
	assert_object(root.command_interface()).is_not_null()
	assert_object(root.hud().ap_counter()).is_not_null()
	assert_object(root.hud().glyph_layer()).is_not_null() # on-board layer on the board.
	assert_object(root.hud().audio()).is_not_null()


# ==============================================================================
# Turn loop: a human End-Turn drives the AI's turn and hands control back.
# ==============================================================================

func test_human_end_turn_drives_ai_then_returns_control() -> void:
	var root := _make_root()
	var state := root.state()
	assert_int(state.active_player).is_equal(0)
	var round_before: int = state.round_number

	# Human ends turn (synchronous route) → the AI turn plays out paced across
	# frames (fire-and-forget) → control returns to the human.
	assert_bool(root.try_end_human_turn()).is_true()

	# Await the paced AI turn to fully complete (each commit yields a frame).
	var frames: int = 0
	while root.is_ai_turn_running() and frames < 1500:
		await get_tree().process_frame
		frames += 1

	assert_bool(root.is_ai_turn_running()).is_false()          # AI turn fully finished.
	assert_int(state.active_player).is_equal(0)                # back to the human.
	assert_int(state.round_number).is_equal(round_before + 1)  # a full round elapsed.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)


# ==============================================================================
# End-Turn is turn-scoped: it never acts on the AI's turn (the loop owns it).
# ==============================================================================

func test_end_turn_is_a_noop_out_of_the_human_turn() -> void:
	var root := _make_root()
	var state := root.state()

	# Force the AI's turn context (as if mid-loop) and confirm the human entry
	# point refuses to act — control belongs to the driver, not the player.
	state.active_player = 1
	assert_bool(root.try_end_human_turn()).is_false()
	assert_int(state.active_player).is_equal(1) # unchanged.


func _place_unit(state: GameState, id: int, owner: int, tile: Vector2i, \
		type: UnitTypeDef = UnitTypes.SCOUT) -> void:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[id] = u
	state.grid.place(id, tile.x, tile.y)


# ==============================================================================
# Keyboard board cursor — moves, peeks the entity under it, selects own units
# (the work-around for the blocked click-pick seam).
# ==============================================================================

func test_cursor_starts_on_local_hq_and_peeks_it() -> void:
	var root := _make_root()
	# The cursor opens on the local player's HQ and peeks it into the detail panel.
	assert_vector(root.cursor_tile()).is_equal(Vector2i(2, 5))
	assert_int(root.hud().detail_panel().shown_entity_id()).is_equal(0) # HQ entity id 0.


func test_cursor_moves_and_clears_peek_over_empty_tiles() -> void:
	var root := _make_root()
	assert_bool(root.move_cursor(Vector2i.RIGHT)).is_true()
	assert_vector(root.cursor_tile()).is_equal(Vector2i(3, 5))     # moved off the HQ ...
	assert_bool(root.hud().detail_panel().is_showing()).is_false()  # ... onto an empty tile.


func test_cursor_selects_own_unit_but_not_structures_or_enemies() -> void:
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 10, 0, Vector2i(4, 5)) # friendly
	_place_unit(state, 11, 1, Vector2i(6, 5)) # enemy

	root.move_cursor(Vector2i.RIGHT) # (3,5)
	root.move_cursor(Vector2i.RIGHT) # (4,5) — the friendly unit
	assert_bool(root.select_at_cursor()).is_true()
	assert_int(root.command_interface().selected_id()).is_equal(10)

	root.move_cursor(Vector2i.RIGHT) # (5,5)
	root.move_cursor(Vector2i.RIGHT) # (6,5) — the enemy unit
	assert_bool(root.select_at_cursor()).is_false() # opponent unit — refused.


func test_cursor_stops_at_the_board_edge() -> void:
	var root := _make_root()
	for _i: int in 5:
		root.move_cursor(Vector2i.LEFT)
	assert_vector(root.cursor_tile()).is_equal(Vector2i(0, 5)) # clamped at the west edge.
	assert_bool(root.move_cursor(Vector2i.LEFT)).is_false()     # can't step past it.
	assert_vector(root.cursor_tile()).is_equal(Vector2i(0, 5))


func _move_cursor_to(root: VerticalSliceRoot, target: Vector2i) -> void:
	var guard: int = 200
	while root.cursor_tile() != target and guard > 0:
		var cur: Vector2i = root.cursor_tile()
		var dir: Vector2i
		if cur.x != target.x:
			dir = Vector2i(signi(target.x - cur.x), 0)
		else:
			dir = Vector2i(0, signi(target.y - cur.y))
		root.move_cursor(dir)
		guard -= 1


# ==============================================================================
# Build — KEY_B places the selected structure at a legal cursor tile.
# ==============================================================================

func test_cycle_buildable_changes_the_selected_type() -> void:
	var root := _make_root()
	assert_object(root.selected_buildable()).is_equal(StructureTypes.ECONOMY_OUTPOST)
	root.cycle_buildable()
	assert_object(root.selected_buildable()).is_equal(StructureTypes.PRODUCTION_OUTPOST)


func test_build_places_a_structure_at_a_legal_cursor_tile() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20 # ensure the outpost is affordable.
	var type: StructureTypeDef = root.selected_buildable() # ECONOMY_OUTPOST (index 0).

	var legal: Array[Vector2i] = GameStateReader.new(state).legal_build_tiles(0, type)
	assert_bool(legal.is_empty()).is_false()          # there is a legal build tile.
	var target: Vector2i = legal[0]
	_move_cursor_to(root, target)
	assert_vector(root.cursor_tile()).is_equal(target)

	var entities_before: int = state.entities().size()
	var ap_before: int = state.per_player[0].current_ap
	assert_bool(root.request_build_at_cursor()).is_true()

	assert_int(state.entities().size()).is_equal(entities_before + 1) # a structure was placed ...
	assert_int(state.per_player[0].current_ap).is_less(ap_before)      # ... and AP was spent ...
	assert_object(state.entity_at(target)).is_not_null()               # ... on the target tile.


func test_build_refused_on_an_illegal_tile() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	# The cursor opens on the local HQ tile — occupied, so not a legal build tile.
	assert_vector(root.cursor_tile()).is_equal(Vector2i(2, 5))
	var entities_before: int = state.entities().size()
	assert_bool(root.request_build_at_cursor()).is_false()
	assert_int(state.entities().size()).is_equal(entities_before) # nothing was built.


# ==============================================================================
# Produce / Move / Attack — the selected-unit + HQ-production gameplay verbs.
# ==============================================================================

func test_produce_deploys_a_unit_from_the_hq() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	var hq: StructureState = state.entities_by_id[0] as StructureState # local HQ, id 0.
	var utype: UnitTypeDef = hq.type.producible_types[0]
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(0, utype)
	assert_bool(deploy.is_empty()).is_false()
	var target: Vector2i = deploy[0]
	_move_cursor_to(root, target)

	var before: int = state.entities().size()
	assert_bool(root.request_produce_at_cursor()).is_true()
	assert_int(state.entities().size()).is_equal(before + 1)   # a unit was deployed ...
	assert_bool(state.entity_at(target) is UnitState).is_true() # ... on the target tile.


func test_move_relocates_the_selected_unit() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 20, 0, Vector2i(4, 5))
	_move_cursor_to(root, Vector2i(4, 5))
	assert_bool(root.select_at_cursor()).is_true()

	# Pick a reachable tile other than the unit's own.
	var dest := Vector2i(-1, -1)
	for r in Movement.reachable(state, state.entities_by_id[20]):
		if r.tile != Vector2i(4, 5):
			dest = r.tile
			break
	assert_bool(dest != Vector2i(-1, -1)).is_true()

	_move_cursor_to(root, dest)
	assert_bool(root.act_at_cursor()).is_true()
	assert_vector((state.entities_by_id[20] as UnitState).position).is_equal(dest)


func test_attack_damages_an_adjacent_enemy() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 20, 0, Vector2i(4, 5), UnitTypes.TROOPER) # friendly attacker
	_place_unit(state, 21, 1, Vector2i(5, 5), UnitTypes.TROOPER) # enemy, adjacent
	_move_cursor_to(root, Vector2i(4, 5))
	assert_bool(root.select_at_cursor()).is_true()

	# (5,5) must be a legal target of the selected attacker for the act to attack.
	var is_target := false
	for t in Combat.legal_targets(state, state.entities_by_id[20]):
		if t.tile == Vector2i(5, 5):
			is_target = true
	assert_bool(is_target).is_true()

	var hp_before: int = (state.entities_by_id[21] as UnitState).current_hp
	_move_cursor_to(root, Vector2i(5, 5))
	assert_bool(root.act_at_cursor()).is_true()

	# The enemy took damage (or was destroyed → removed from the entity set).
	var enemy: Variant = state.entities_by_id.get(21)
	var damaged: bool = enemy == null or (enemy as UnitState).current_hp < hp_before
	assert_bool(damaged).is_true()


func _place_structure(state: GameState, id: int, owner: int, tile: Vector2i, \
		type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = id
	s.owner = owner
	s.position = tile
	s.type = type
	s.current_hp = type.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[id] = s
	state.grid.place(id, tile.x, tile.y)
	return s


func test_produce_uses_a_second_producer_when_the_hq_is_at_cap() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	# Max out the HQ's production this turn, so the producer scan must skip it.
	var hq: StructureState = state.entities_by_id[0] as StructureState
	hq.units_produced_this_turn = hq.type.production_cap
	# The player also owns a completed Production Outpost with capacity.
	var outpost: StructureState = _place_structure(state, 30, 0, Vector2i(3, 5), StructureTypes.PRODUCTION_OUTPOST)
	var utype: UnitTypeDef = outpost.type.producible_types[0]
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(30, utype)
	assert_bool(deploy.is_empty()).is_false()
	var target: Vector2i = deploy[0]
	_move_cursor_to(root, target)

	var before: int = state.entities().size()
	assert_bool(root.request_produce_at_cursor()).is_true() # produced from the outpost, HQ skipped.
	assert_int(state.entities().size()).is_equal(before + 1)
	assert_bool(state.entity_at(target) is UnitState).is_true()


func test_status_overlay_surfaces_selected_build_type_legend_and_updates_on_cycle() -> void:
	var root := _make_root()

	# The overlay surfaces info the committed HUD widgets don't: the currently
	# selected Build type, its cycle key, the produce readout, and the controls legend.
	var first: StructureTypeDef = root.selected_buildable()
	assert_str(root.status_text()).contains(first.display_name) # e.g. "Economy Outpost"
	assert_str(root.status_text()).contains("[C] cycle")
	assert_str(root.status_text()).contains("Produce [P]:")
	assert_str(root.status_text()).contains("[Tab] end turn")

	# Cycling the build type updates the overlay to the next type in one keypress.
	root.cycle_buildable()
	var second: StructureTypeDef = root.selected_buildable()
	assert_bool(second.display_name != first.display_name).is_true()
	assert_str(root.status_text()).contains(second.display_name) # e.g. "Production Outpost"


func test_camera_frames_the_whole_board_within_the_view() -> void:
	# The fit-to-board camera must show every board tile at boot (regression for the
	# "board off-screen / window too small" report — old fixed zoom 2.0 clipped it).
	# Pin a realistic window size — the headless default viewport is 64x64, which
	# degenerates any framing check.
	var prev_size: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	var root := _make_root()
	var cam: Camera2D = root.camera()
	var board: BoardRenderer = root.board()
	var half_view: Vector2 = root.get_viewport_rect().size * 0.5 / cam.zoom
	var view_min: Vector2 = cam.position - half_view
	var view_max: Vector2 = cam.position + half_view

	# All four corner tiles fall inside the visible world rect.
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(11, 0), Vector2i(0, 9), Vector2i(11, 9)]:
		var p: Vector2 = board.grid_to_screen(tile)
		assert_bool(p.x >= view_min.x and p.x <= view_max.x).is_true()
		assert_bool(p.y >= view_min.y and p.y <= view_max.y).is_true()

	# And the camera is zoomed to fit (never the old clipped 2.0, never degenerate).
	assert_float(cam.zoom.x).is_between(0.3, 1.5)

	get_window().size = prev_size
