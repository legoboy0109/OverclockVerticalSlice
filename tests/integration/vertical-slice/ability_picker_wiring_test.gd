# Unit abilities: unit → Ability row → ability row → (tile) → the rules. The wiring, not the
# pieces — the S8-12 lesson: a picker whose choice is emitted into a void passes every test
# that calls the handler directly.
extends GdUnitTestSuite


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


func _place(root: VerticalSliceRoot, id: int, type: UnitTypeDef, tile: Vector2i) -> UnitState:
	var state: GameState = root.state()
	var u := UnitState.new()
	u.entity_id = id
	u.owner = 0
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[id] = u
	state.grid.place(id, tile.x, tile.y)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	return u


func _select(root: VerticalSliceRoot, tile: Vector2i) -> void:
	while root.cursor_tile() != tile:
		var d: Vector2i = tile - root.cursor_tile()
		root.move_cursor(Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y)))
	root.select_at_cursor()


func _press(root: Node, prefix: String) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).visible and not (n as Button).disabled \
				and (n as Button).text.begins_with(prefix):
			(n as Button).emit_signal("pressed")
			return true
		for c: Node in n.get_children():
			stack.append(c)
	return false


func test_fortify_from_the_menu_fortifies() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var heavy := _place(root, 91, UnitTypes.HEAVY, Vector2i(4, 2))
	_select(root, heavy.position)
	await get_tree().process_frame
	assert_bool(_press(root, "Ability")).override_failure_message("No Ability row on a Heavy.").is_true()
	await get_tree().process_frame
	assert_bool(_press(root, "Fortify")).override_failure_message("No Fortify row.").is_true()
	await get_tree().process_frame
	assert_int(heavy.fortify).override_failure_message(
		"Choosing Fortify did nothing — the choice went nowhere.").is_equal(Abilities.FORTIFY.amount)


func test_embark_from_the_menu_crews_the_tank() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var tank := _place(root, 92, UnitTypes.TANK, Vector2i(4, 2))
	var trooper := _place(root, 93, UnitTypes.TROOPER, Vector2i(4, 3))
	_select(root, trooper.position)
	await get_tree().process_frame
	assert_bool(_press(root, "Ability")).is_true()
	await get_tree().process_frame
	assert_bool(_press(root, "Embark")).override_failure_message("No Embark row beside a tank.").is_true()
	await get_tree().process_frame
	# The picker snaps the cursor onto the only legal tile — the tank — so confirming boards.
	assert_bool(root.commit_at_cursor()).is_true()
	await get_tree().process_frame
	assert_object(tank.pilot).is_same(trooper)


func test_a_unit_with_nothing_to_use_shows_no_ability_row() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var sniper := _place(root, 94, UnitTypes.SNIPER, Vector2i(4, 2))
	_select(root, sniper.position)
	await get_tree().process_frame
	assert_bool(_press(root, "Ability")).is_false()
