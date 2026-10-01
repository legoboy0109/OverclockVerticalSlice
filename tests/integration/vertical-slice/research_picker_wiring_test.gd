# CR-14: HQ → Research → a tech row → research actually starts. The wiring, not the pieces.
#
# Same reason build_picker_wiring_test.gd exists (S8-12): a picker whose choice is emitted
# into a void passes every test that calls the handler directly. So these start from the
# ROWS a player presses and assert all the way through to the HQ's research state.
extends GdUnitTestSuite


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(
		load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


func _own_hq(root: VerticalSliceRoot) -> StructureState:
	return Research.researcher(root.state(), 0)


## Funds the player, moves the cursor onto their HQ and selects it (which opens its menu).
func _select_hq(root: VerticalSliceRoot) -> StructureState:
	var state: GameState = root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var hq: StructureState = _own_hq(root)
	while root.cursor_tile() != hq.position:
		var delta: Vector2i = hq.position - root.cursor_tile()
		if delta.x != 0:
			root.move_cursor(Vector2i(signi(delta.x), 0))
		else:
			root.move_cursor(Vector2i(0, signi(delta.y)))
	root.select_at_cursor()
	return hq


func _menu(root: VerticalSliceRoot) -> ActionMenu:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ActionMenu:
			return node as ActionMenu
		for child: Node in node.get_children():
			stack.append(child)
	return null


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


## Presses the first enabled, visible row whose text starts with [param prefix] — through
## the Button's own `pressed` signal, never by calling the slice's methods.
func _press_row(menu: ActionMenu, prefix: String) -> bool:
	for row: Button in _rows(menu):
		if row.text.begins_with(prefix) and not row.disabled and row.visible:
			row.emit_signal("pressed")
			return true
	return false


func _row_texts(menu: ActionMenu) -> Array[String]:
	var out: Array[String] = []
	for row: Button in _rows(menu):
		if row.visible:
			out.append(row.text)
	return out


func test_the_hq_menu_offers_research() -> void:
	var root: VerticalSliceRoot = await _make_root()
	_select_hq(root)
	await get_tree().process_frame
	assert_array(_row_texts(_menu(root))).contains(["Research"])


func test_choosing_a_tech_from_the_picker_starts_research_at_the_hq() -> void:
	# ★ THE REGRESSION GUARD: HQ row → Research row → tech row → research running.
	var root: VerticalSliceRoot = await _make_root()
	var hq: StructureState = _select_hq(root)
	await get_tree().process_frame
	assert_bool(_press_row(_menu(root), "Research")).override_failure_message(
		"no enabled Research row on the HQ menu").is_true()
	await get_tree().process_frame
	# ★ 2026-10-01 (branching trees): Research → a tree → the tech.
	assert_bool(_press_row(_menu(root), "Offense")).override_failure_message(
		"no Offense tree row in the research picker").is_true()
	await get_tree().process_frame
	assert_bool(_press_row(_menu(root), "Heavy Ordnance")).override_failure_message(
		"no enabled Attack Tech row in the research picker: %s" % [_row_texts(_menu(root))]).is_true()
	await get_tree().process_frame
	assert_object(hq.research_target).override_failure_message(
		"Choosing a tech must start research. The HQ is idle — the choice went nowhere."
	).is_same(Techs.ATTACK_I)


func test_a_tree_shows_only_the_current_choice() -> void:
	# ★ 2026-10-01 (branching trees): a fresh Offense tree offers its tier-1 pair and nothing deeper.
	var root: VerticalSliceRoot = await _make_root()
	_select_hq(root)
	await get_tree().process_frame
	_press_row(_menu(root), "Research")
	await get_tree().process_frame
	_press_row(_menu(root), "Offense")
	await get_tree().process_frame
	var texts: Array[String] = _row_texts(_menu(root))
	var joined: String = " | ".join(texts)
	assert_bool(joined.contains("Heavy Ordnance")).override_failure_message(joined).is_true()
	assert_bool(joined.contains("Rapid Deployment")).override_failure_message(joined).is_true()
	assert_bool(joined.contains("Penetration")).override_failure_message(
		"a tier-2 tech is shown before its parent: %s" % joined).is_false()


func test_cancel_research_takes_two_presses() -> void:
	# Destructive, no undo: it goes through the same arm-then-confirm gate as Cancel Build.
	var root: VerticalSliceRoot = await _make_root()
	var state: GameState = root.state()
	var hq: StructureState = _own_hq(root)
	hq.research_target = Techs.ATTACK_I
	hq.research_turns_remaining = 3
	_select_hq(root)
	await get_tree().process_frame
	assert_bool(_press_row(_menu(root), "Cancel Research")).override_failure_message(
		"no Cancel Research row while researching: %s" % [_row_texts(_menu(root))]).is_true()
	await get_tree().process_frame
	assert_object(hq.research_target).override_failure_message(
		"One press cancelled research — it must arm first.").is_same(Techs.ATTACK_I)
	assert_bool(_press_row(_menu(root), "Confirm cancel")).is_true()
	await get_tree().process_frame
	assert_object(hq.research_target).is_null()
	assert_int(state.per_player[0].current_credits).is_equal(
		5000 + Research.cancel_refund(state, Techs.ATTACK_I, 0))


func test_non_researchers_show_no_research_rows() -> void:
	# Structural rows are hidden, not dimmed (CR-4): no "Research — not a researcher" on
	# every unit in the game.
	var root: VerticalSliceRoot = await _make_root()
	var state: GameState = root.state()
	var unit := UnitState.new()
	unit.entity_id = 91
	unit.owner = 0
	unit.position = Vector2i(4, 5)
	unit.type = UnitTypes.SCOUT
	unit.current_hp = UnitTypes.SCOUT.hp
	state.entities_by_id[91] = unit
	state.grid.place(91, 4, 5)
	state.per_player[0].current_ap = 20
	while root.cursor_tile() != unit.position:
		var delta: Vector2i = unit.position - root.cursor_tile()
		root.move_cursor(Vector2i(signi(delta.x), 0) if delta.x != 0 else Vector2i(0, signi(delta.y)))
	root.select_at_cursor()
	await get_tree().process_frame
	var texts: Array[String] = _row_texts(_menu(root))
	assert_bool(texts.has("Research") or texts.has("Cancel Research")).override_failure_message(
		"A Scout's menu shows research rows: %s" % [texts]).is_false()
