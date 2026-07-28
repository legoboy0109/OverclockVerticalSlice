# Story 005: BoardCursor Input Substrate — Grid-Axis Nav, Cycle/Jump, Mouse-vs-
# Cursor Precedence.
#
# Covers production/epics/command-action-interface/story-005-board-cursor-input-substrate.md
# (TR-cmdui-018/019/020/024, ADR-0014):
#
#   step() bounds: never sets grid_pos out of [0,width)x[0,height); an out-of-
#     bounds step is a no-op returning false; repeated out-of-bounds never
#     corrupts grid_pos.
#   step() grid-axis (TR-cmdui-019): ui_up -> NORTH -> y-1 etc., mapped straight
#     onto grid (x,y) — never a screen/iso-visual axis.
#   jump_to_next() cycle: visits every candidate exactly once per full cycle in
#     ascending tile-index order, wrapping last->first; empty set is a no-op.
#   Mouse-vs-cursor precedence (TR-cmdui-020): active_locus/active_tile are
#     last-handler-wins with NO timestamp/frame-delta comparison.
#
# BoardCursor is a pure RefCounted value object (no Node, no orphans).
# The precedence check uses a CommandInterface Node fixture (auto_free()).
# Deterministic: no RNG, no time-dependent assertions, no external I/O.
extends GdUnitTestSuite


func _make_grid(w: int = 10, h: int = 10) -> GridState:
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


# ==============================================================================
# step(): bounds safety + grid-axis mapping.
# ==============================================================================

func test_step_in_bounds_moves_and_returns_true() -> void:
	var grid := _make_grid()
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(4, 4)

	assert_bool(cursor.step(Vector2i.RIGHT, grid)).is_true() # EAST -> x+1
	assert_object(cursor.grid_pos).is_equal(Vector2i(5, 4))


func test_step_out_of_bounds_is_a_noop_returning_false() -> void:
	var grid := _make_grid()
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(0, 0)

	# WEST and NORTH from the top-left corner are both out of bounds.
	assert_bool(cursor.step(Vector2i.LEFT, grid)).is_false()
	assert_object(cursor.grid_pos).is_equal(Vector2i(0, 0))
	assert_bool(cursor.step(Vector2i.UP, grid)).is_false()
	assert_object(cursor.grid_pos).is_equal(Vector2i(0, 0))

	# Repeated out-of-bounds steps never corrupt grid_pos.
	for i: int in 5:
		cursor.step(Vector2i.UP, grid)
	assert_object(cursor.grid_pos).is_equal(Vector2i(0, 0))


func test_step_ui_up_maps_to_grid_north_y_minus_one() -> void:
	# TR-cmdui-019: ui_up -> NORTH -> y-1, on the grid axis, never screen/iso.
	var grid := _make_grid()
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(4, 4)

	assert_bool(cursor.step(Vector2i.UP, grid)).is_true()
	assert_object(cursor.grid_pos).is_equal(Vector2i(4, 3))
	# And the other three axes.
	cursor.step(Vector2i.DOWN, grid)
	assert_object(cursor.grid_pos).is_equal(Vector2i(4, 4)) # SOUTH -> y+1
	cursor.step(Vector2i.LEFT, grid)
	assert_object(cursor.grid_pos).is_equal(Vector2i(3, 4)) # WEST -> x-1


# ==============================================================================
# jump_to_next(): ascending tile-index cycle, wrapping, empty no-op.
# ==============================================================================

func test_jump_to_next_visits_all_candidates_ascending_then_wraps() -> void:
	var grid := _make_grid(10, 10)
	# Deliberately unsorted input. Ascending tile-index (y*10+x) order is:
	# (1,0)=1, (3,0)=3, (0,1)=10, (5,1)=15, (2,2)=22.
	var candidates: Array[Vector2i] = [Vector2i(5, 1), Vector2i(1, 0), Vector2i(2, 2), Vector2i(0, 1), Vector2i(3, 0)]
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(9, 9) # not a candidate -> first jump goes to lowest index.

	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(5, 1), Vector2i(2, 2)]
	for e: Vector2i in expected:
		cursor.jump_to_next(candidates, grid)
		assert_object(cursor.grid_pos).is_equal(e)

	# 6th call wraps last -> first.
	cursor.jump_to_next(candidates, grid)
	assert_object(cursor.grid_pos).is_equal(Vector2i(1, 0))


func test_jump_to_next_empty_candidate_set_is_a_noop() -> void:
	var grid := _make_grid()
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(4, 4)
	var empty: Array[Vector2i] = []

	cursor.jump_to_next(empty, grid) # must not crash, must not move.
	assert_object(cursor.grid_pos).is_equal(Vector2i(4, 4))


# ==============================================================================
# Mouse-vs-cursor precedence: last-handler-wins, no timestamp comparison.
# ==============================================================================

func test_active_locus_reflects_last_input_in_dispatch_order() -> void:
	var iface: CommandInterface = auto_free(CommandInterface.new())

	# mouse -> A
	iface._on_mouse_moved_to_tile(Vector2i(2, 2))
	assert_int(iface.active_locus()).is_equal(CommandInterface.Locus.MOUSE)
	assert_object(iface.active_tile()).is_equal(Vector2i(2, 2))

	# ui_up cursor move (board cursor now holds the locus)
	var cursor := BoardCursor.new()
	cursor.grid_pos = Vector2i(2, 1)
	iface._on_board_locus_moved(cursor)
	assert_int(iface.active_locus()).is_equal(CommandInterface.Locus.BOARD_CURSOR)
	assert_object(iface.active_tile()).is_equal(Vector2i(2, 1))

	# mouse -> B (mouse reclaims the locus — no "older input" rejection)
	iface._on_mouse_moved_to_tile(Vector2i(7, 3))
	assert_int(iface.active_locus()).is_equal(CommandInterface.Locus.MOUSE)
	assert_object(iface.active_tile()).is_equal(Vector2i(7, 3))


func test_precedence_uses_no_timestamp_or_frame_comparison() -> void:
	# Structural: the cursor + precedence code resolve last-wins purely by
	# dispatch order, never by reading a clock or frame counter.
	var cursor_src := FileAccess.get_file_as_string("res://src/ui/command_action_interface/board_cursor.gd")
	var iface_src := FileAccess.get_file_as_string("res://src/ui/command_action_interface/command_interface.gd")
	for forbidden: String in ["Time.", "get_ticks", "get_frames", "Engine.get_physics_frames", "Engine.get_process_frames"]:
		assert_bool(cursor_src.contains(forbidden)).override_failure_message(
			"board_cursor.gd must not read a clock/frame counter ('%s')" % forbidden).is_false()
		assert_bool(iface_src.contains(forbidden)).override_failure_message(
			"command_interface.gd precedence must be timestamp-free ('%s')" % forbidden).is_false()
