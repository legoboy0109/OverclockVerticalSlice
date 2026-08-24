# Cursor jump — the salient-tile shortcut (ADR-0014, board_cursor_cycle).
#
# WHY THIS SUITE EXISTS: BoardCursor.jump_to_next() has been implemented and
# unit-tested since ADR-0014, the `board_cursor_cycle` action has been declared in
# project.godot since the same spike, and NOTHING CALLED IT. The feature existed in
# every layer except the one that runs. That is the second dead hook found this way
# (CommandInterface.notify_action_applied was the first), and both were invisible
# for the same reason: a unit test proves a function works, not that anything
# invokes it.
#
# These tests are written against the SLICE, not against BoardCursor, precisely so
# they fail if the wiring is ever removed again.
extends GdUnitTestSuite


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(
		load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


func _own_unit(root: VerticalSliceRoot) -> UnitState:
	for e: EntityState in root.state().entities():
		if e is UnitState and e.owner == 0:
			return e as UnitState
	return null


func _produce_a_unit(root: VerticalSliceRoot) -> UnitState:
	# Step one tile off the HQ first: the cursor starts ON it, and the HQ's own tile
	# is occupied, so producing there fails silently and the test then asserts
	# against a null unit rather than against the feature.
	root.move_cursor(Vector2i(1, 0))
	await get_tree().process_frame
	root.request_produce_at_cursor()
	await get_tree().process_frame
	return _own_unit(root)


# ==============================================================================
# The action is wired at all.
# ==============================================================================

func test_the_action_exists_and_carries_both_a_key_and_a_pad_binding() -> void:
	# ★ The pad binding was missing entirely until 2026-08-24 — the action shipped
	# keyboard-only, so the one shortcut that most helps a gamepad player navigate
	# was the one thing a gamepad could not do.
	assert_bool(InputMap.has_action(&"board_cursor_cycle")).is_true()
	var has_key: bool = false
	var has_pad: bool = false
	for e: InputEvent in InputMap.action_get_events(&"board_cursor_cycle"):
		has_key = has_key or e is InputEventKey
		has_pad = has_pad or e is InputEventJoypadButton
	assert_bool(has_key).is_true()
	assert_bool(has_pad).override_failure_message(
		"board_cursor_cycle needs a gamepad binding — it is a navigation shortcut, " +
		"and stepping tile-by-tile is slowest on a pad"
	).is_true()


func test_the_slice_exposes_a_jump_entry_point() -> void:
	var root: VerticalSliceRoot = await _make_root()
	assert_bool(root.has_method("jump_cursor")).override_failure_message(
		"the action is declared and bound; something must handle it"
	).is_true()


# ==============================================================================
# Behaviour: jumps only between highlighted tiles, and only during a preview.
# ==============================================================================

func test_jump_is_a_no_op_with_nothing_selected() -> void:
	# Nothing is highlighted outside a preview, so there is nothing to jump between.
	# A no-op, never an error (BoardCursor's empty-candidates contract).
	var root: VerticalSliceRoot = await _make_root()
	var before: Vector2i = root.cursor_tile()
	assert_bool(root.jump_cursor()).is_false()
	assert_vector(root.cursor_tile()).is_equal(before)


func test_jump_moves_the_cursor_onto_a_highlighted_tile() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var unit: UnitState = await _produce_a_unit(root)
	assert_object(unit).is_not_null()

	# Walk onto the unit and select it — selection opens the move preview, which is
	# what populates the salient set.
	while root.cursor_tile() != unit.position:
		var c: Vector2i = root.cursor_tile()
		var step := Vector2i(signi(unit.position.x - c.x), 0) if c.x != unit.position.x \
			else Vector2i(0, signi(unit.position.y - c.y))
		if step == Vector2i.ZERO:
			break
		root.move_cursor(step)
	root.select_at_cursor()
	await get_tree().process_frame

	var salient: Array[Vector2i] = root.command_interface().salient_tiles()
	assert_array(salient).override_failure_message(
		"selecting a unit must populate the salient set, or jump has nothing to do"
	).is_not_empty()

	assert_bool(root.jump_cursor()).is_true()
	assert_array(salient).override_failure_message(
		"a jump must land on a HIGHLIGHTED tile — landing anywhere else reads as a bug"
	).contains([root.cursor_tile()])


func test_repeated_jumps_stay_within_the_highlighted_set() -> void:
	# ★ The property that makes the shortcut trustworthy: cycling can never wander
	# off the highlighted frontier, however many times it is pressed.
	var root: VerticalSliceRoot = await _make_root()
	var unit: UnitState = await _produce_a_unit(root)
	while root.cursor_tile() != unit.position:
		var c: Vector2i = root.cursor_tile()
		var step := Vector2i(signi(unit.position.x - c.x), 0) if c.x != unit.position.x \
			else Vector2i(0, signi(unit.position.y - c.y))
		if step == Vector2i.ZERO:
			break
		root.move_cursor(step)
	root.select_at_cursor()
	await get_tree().process_frame

	var salient: Array[Vector2i] = root.command_interface().salient_tiles()
	for i: int in 8:
		root.jump_cursor()
		assert_array(salient).contains([root.cursor_tile()])
