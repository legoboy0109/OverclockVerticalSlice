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
	assert_int(root.state().entities().size()).override_failure_message(
		"the board gained no entity, so nothing was actually built"
	).is_equal(before + 1)
