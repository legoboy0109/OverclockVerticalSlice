# Build picker → placement preview — the wiring, not the pieces.
#
# WHY THIS SUITE EXISTS: Build had NEVER worked from the UI. `ActionMenu` emitted
# `build_type_chosen` and NOTHING was connected to it, so choosing a structure from
# the Build picker closed the list and did nothing at all. `begin_build_preview()`
# — the method that would have opened the placement preview — had no production
# caller.
#
# The existing coverage could not see it, because it called `begin_build_preview()`
# DIRECTLY. That proves the method works; it says nothing about whether any player
# input reaches it. This is the third dead hook found in this project for exactly
# that reason (`board_cursor_cycle` and `notify_action_applied` were the first two),
# so these tests deliberately start from the PICKER ROW a player presses and assert
# all the way through to a structure existing on the board.
extends GdUnitTestSuite


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(
		load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


## Fields a Builder beside the player's HQ and selects it.
##
## ⚠ Required since 2026-08-25 (user decision): Build belongs to a Builder and is
## placed on a tile beside it, so the picker refuses to open without one. The match
## starts with two HQs and no units at all.
func _select_a_builder(root: VerticalSliceRoot) -> UnitState:
	var state: GameState = root.state()
	var unit := UnitState.new()
	unit.entity_id = 90
	unit.owner = 0
	unit.position = Vector2i(4, 5)
	unit.type = UnitTypes.BUILDER
	unit.current_hp = UnitTypes.BUILDER.hp
	state.entities_by_id[90] = unit
	state.grid.place(90, 4, 5)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	while root.cursor_tile() != unit.position:
		var delta: Vector2i = unit.position - root.cursor_tile()
		if delta.x != 0:
			root.move_cursor(Vector2i(signi(delta.x), 0))
		else:
			root.move_cursor(Vector2i(0, signi(delta.y)))
	root.select_at_cursor()
	return unit


func _menu(root: VerticalSliceRoot) -> ActionMenu:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ActionMenu:
			return node as ActionMenu
		for child: Node in node.get_children():
			stack.append(child)
	return null


## Every Button anywhere under the open menu — both plates, in tree order.
func _rows(menu: ActionMenu) -> Array[Button]:
	var out: Array[Button] = []
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			out.append(node as Button)
		for child: Node in node.get_children():
			stack.append(child)
	return out


## Presses the picker row labelled [param label] the way a click does — through the
## Button's own `pressed` signal, never by calling the slice's methods.
func _press_row(menu: ActionMenu, label: String) -> bool:
	for row: Button in _rows(menu):
		if row.text == label and not row.disabled and row.visible:
			row.emit_signal("pressed")
			return true
	return false


# ==============================================================================
# The picker offers something, and choosing it actually starts a build.
# ==============================================================================

func test_build_picker_lists_the_buildable_roster() -> void:
	# Arrange
	var root: VerticalSliceRoot = await _make_root()
	_select_a_builder(root)

	# Act
	root.open_build_picker()
	await get_tree().process_frame

	# Assert
	var labels: Array[String] = []
	for row: Button in _rows(_menu(root)):
		if row.visible:
			labels.append(row.text)
	assert_array(labels).override_failure_message(
		"the Build picker opened empty — a player has nothing to choose"
	).contains(["Barracks"])


func test_choosing_a_structure_enters_the_build_placement_preview() -> void:
	# ★ THE REGRESSION. This is the assertion the old, direct-call coverage could
	# not make: that pressing the row a player presses reaches the preview at all.
	# Arrange
	var root: VerticalSliceRoot = await _make_root()
	_select_a_builder(root)
	root.open_build_picker()
	await get_tree().process_frame

	# Act
	assert_bool(_press_row(_menu(root), "Barracks")).override_failure_message(
		"the Barracks row was missing or disabled, so nothing could be pressed"
	).is_true()
	await get_tree().process_frame

	# Assert
	assert_int(root.command_interface().fsm_state()).override_failure_message(
		"picking a structure from the Build picker must open the placement " +
		"preview. The interface stayed in state %d — which is what a player sees " +
		"as 'the Build button does nothing'." % root.command_interface().fsm_state()
	).is_equal(CommandFSM.State.PREVIEW_BUILD)


func test_a_structure_can_be_placed_from_the_picker_through_to_the_board() -> void:
	# Arrange
	var root: VerticalSliceRoot = await _make_root()
	_select_a_builder(root)
	var before: int = root.state().entities().size()
	root.open_build_picker()
	await get_tree().process_frame
	assert_bool(_press_row(_menu(root), "Barracks")).is_true()
	await get_tree().process_frame

	# Act — the preview snaps the cursor onto a legal tile, so confirming places.
	var placed: bool = root.commit_at_cursor()
	await get_tree().process_frame

	# Assert
	assert_bool(placed).override_failure_message(
		"confirming on a highlighted build tile must place the structure"
	).is_true()
	# The Builder is spent BY the structure, so the count holds: one unit out, one
	# building in. Checked as an identity swap rather than a bare increment,
	# because "+1 entity" would also pass if the Builder were left standing.
	assert_int(root.state().entities().size()).is_equal(before)
	assert_object(root.state().entities_by_id.get(90)).override_failure_message(
		"the Builder must be consumed by the structure it raises"
	).is_null()
