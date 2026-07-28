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


func _place_unit(state: GameState, id: int, owner: int, tile: Vector2i) -> void:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = UnitTypes.SCOUT
	u.current_hp = UnitTypes.SCOUT.hp
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
