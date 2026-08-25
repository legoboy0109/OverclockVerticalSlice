# ActionMenu — the contextual action menu widget (design/ux/action-menu.md).
#
# The rendering half of CR-4. The model half (which verbs, enabled or not, and why)
# is CommandFSM's and is tested in command_fsm_test.gd / menu_option_models_test.gd;
# what is asserted HERE is that the model reaches the screen intact and that the
# surface behaves the way the spec's acceptance criteria say.
#
#   AC-1/AC-2: an owned entity's menu opens with a row per verb, enabled rows
#     matching the model.
#   AC-4:  a disabled row renders its reason.
#   AC-5:  a disabled row is not focusable.
#   AC-6:  the plate clears the entity's anchor by at least one tile width.
#   AC-7:  it flips side rather than overflowing the viewport.
#   AC-8:  it clamps vertically but never horizontally.
#   AC-9:  the first ENABLED row takes keyboard focus on open.
#   AC-10: back-out steps submenu -> menu -> dismissed, one level per press.
#   AC-15: shortcut hints render the live binding, not a hardcoded letter.
#
# Deterministic: no RNG, no time-dependent assertions. Fades are disabled via
# configure(reduced_motion = true) so a shot of the tree is never sampled mid-tween.
extends GdUnitTestSuite

const VIEW := Vector2(1600, 900)

## Saved so the suite restores whatever the runner had.
var _prev_window_size: Vector2i = Vector2i.ZERO


## Placement is measured against the VIEWPORT, not against this suite's host
## Control — which is correct in production (the menu must stay inside the window)
## and means the headless default viewport, a few dozen pixels square, would flip
## and clamp every plate before any real rule could apply. Pin a realistic window
## for the placement assertions to mean anything.
func before() -> void:
	_prev_window_size = get_window().size
	get_window().size = Vector2i(int(VIEW.x), int(VIEW.y))


func after() -> void:
	get_window().size = _prev_window_size


# --- Fixture helpers ---------------------------------------------------------

func _make_blank_grid(size: int = 12) -> GridState:
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


func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_blank_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500
	return state


func _make_unit_type(name: String = "Scout") -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = name
	type.hp = 10
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 8
	type.produce_cost = 4
	return type


func _place_unit(state: GameState, id: int, owner: int, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = id
	unit.owner = owner
	unit.position = pos
	unit.type = _make_unit_type()
	unit.current_hp = unit.type.hp
	state.entities_by_id[id] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = id
	return unit


func _place_producer(state: GameState, id: int, owner: int, pos: Vector2i, \
		producible: Array[UnitTypeDef]) -> StructureState:
	var type := StructureTypeDef.new()
	type.display_name = "TestProducer"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 2
	type.production_cap = 2
	type.producible_types = producible
	var structure := StructureState.new()
	structure.entity_id = id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[id] = structure
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = id
	return structure


## Builds a menu inside a sized host Control, so viewport-relative placement has a
## real rect to work against rather than the headless default 64x64.
func _make_menu() -> ActionMenu:
	var host := Control.new()
	host.size = VIEW
	add_child(host)
	auto_free(host)
	var menu := ActionMenu.new()
	menu.configure(true) # reduced motion: no fades to race.
	host.add_child(menu)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	return menu


## Every Button in the menu's first (verb) plate, in visual order.
func _rows(menu: ActionMenu) -> Array[Button]:
	var found: Array[Button] = []
	var plate: Node = menu.get_node_or_null(^"MenuPlate")
	if plate == null:
		return found
	for child: Node in plate.get_child(0).get_children():
		if child is Button:
			found.append(child)
	return found


## Every Button in the second plate — the Produce submenu or the Build picker.
func _option_rows(menu: ActionMenu) -> Array[Button]:
	var found: Array[Button] = []
	var plate: Node = menu.get_node_or_null(^"OptionPlate")
	if plate == null:
		return found
	for child: Node in plate.get_child(0).get_children():
		if child is Button:
			found.append(child)
	return found


## The right-hand hint/reason text of [param row], or "" when it has none.
func _hint_of(row: Button) -> String:
	for child: Node in row.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func _row_named(menu: ActionMenu, label: String) -> Button:
	for row: Button in _rows(menu):
		if row.text == label:
			return row
	return null


# ==============================================================================
# Content — the model reaches the screen intact
# ==============================================================================

func test_a_units_menu_shows_a_row_per_verb_with_move_and_wait_live() -> void:
	# Arrange
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	# Act
	menu.open(state, unit, Vector2(400, 400), 128.0)

	# Assert — Move and Wait are live for a fresh unit with AP; the rest are not,
	# and are still PRESENT, which is the whole of CR-4.
	assert_bool(menu.is_open()).is_true()
	assert_object(_row_named(menu, "Move")).is_not_null()
	assert_object(_row_named(menu, "Wait")).is_not_null()
	assert_bool(_row_named(menu, "Move").disabled).is_false()
	assert_bool(_row_named(menu, "Wait").disabled).is_false()


func test_an_unavailable_verb_is_shown_disabled_with_its_reason_never_hidden() -> void:
	# ★ AC-4, and the single behaviour the old per-command-key scheme could not
	# express at all: a key that does nothing is indistinguishable from a key that
	# does not exist.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5)) # nothing to attack.
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	var attack: Button = _row_named(menu, "Attack")
	assert_object(attack).override_failure_message(
		"Attack must still have a ROW when it is unavailable — hiding it is the bug"
	).is_not_null()
	assert_bool(attack.disabled).is_true()
	assert_str(_hint_of(attack)).override_failure_message(
		"a disabled row without a reason teaches the player nothing"
	).is_not_empty()


func test_a_disabled_row_is_not_focusable_so_traversal_only_stops_where_it_can_act() -> void:
	# AC-5. Visible-but-inert, the same treatment the Settings screen's per-binding
	# reset buttons use.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	for row: Button in _rows(menu):
		if row.disabled:
			assert_int(row.focus_mode).override_failure_message(
				"disabled row '%s' must not take keyboard focus" % row.text
			).is_equal(Control.FOCUS_NONE)
		else:
			assert_int(row.focus_mode).is_equal(Control.FOCUS_ALL)


func test_an_enabled_verb_shows_the_players_live_binding_not_a_hardcoded_letter() -> void:
	# AC-15. The hint is read from the InputMap on every open, so a rebind is
	# reflected without this widget knowing the Settings screen exists.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	var expected: String = ""
	for event: InputEvent in InputMap.action_get_events(&"board_act"):
		if event is InputEventKey:
			var key: InputEventKey = event
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			expected = "[%s]" % OS.get_keycode_string(code)
			break
	assert_str(_hint_of(_row_named(menu, "Move"))).is_equal(expected)


func test_the_first_enabled_row_takes_keyboard_focus_on_open() -> void:
	# AC-9. Without this a gamepad player opens a menu with nothing focused and the
	# next direction press goes to the board instead of the menu.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)
	await get_tree().process_frame

	var focused: Control = menu.get_viewport().gui_get_focus_owner()
	assert_object(focused).is_not_null()
	assert_bool((focused as Button).disabled).is_false()


func test_cancel_build_is_dropped_when_it_does_not_apply_to_this_kind_of_entity() -> void:
	# The one documented exception to "never hide a verb": Cancel Build is disabled
	# for every unit and every completed structure, so a permanent
	# "Cancel Build - nothing to cancel" row would appear on essentially every menu
	# in the game. Disabled-because-of-the-SITUATION is informative; disabled-
	# because-it-does-not-apply-to-this-KIND-of-thing is noise.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	assert_object(_row_named(menu, "Cancel Build")).is_null()


func test_the_attack_row_shows_what_attacking_costs() -> void:
	# ★ 2026-08-25 (action-menu.md OQ-2). Attack's price is a single number known
	# the moment the menu opens, and it is what the player weighs when choosing
	# between hitting something and moving. Showing it on the row means that choice
	# no longer requires entering a preview to price it.
	var state := _make_state()
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5))
	_place_unit(state, 2, 1, Vector2i(5, 6)) # adjacent enemy = a legal target
	var menu := _make_menu()

	menu.open(state, attacker, Vector2(400, 400), 128.0)

	var row: Button = _row_named(menu, "Attack")
	assert_bool(row.disabled).is_false()
	assert_str(_hint_of(row)).override_failure_message(
		"an enabled Attack row must name its AP price"
	).contains("%d AP" % Combat.attack_cost_for(attacker))


func test_a_priced_row_keeps_its_shortcut_alongside_the_price() -> void:
	# The price is added to the right-hand column, not swapped in for what was
	# there — a player learning the keyboard must not lose the hint by gaining a
	# number.
	var state := _make_state()
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5))
	_place_unit(state, 2, 1, Vector2i(5, 6))
	var menu := _make_menu()

	menu.open(state, attacker, Vector2(400, 400), 128.0)

	var hint: String = _hint_of(_row_named(menu, "Attack"))
	assert_str(hint).contains("AP")
	assert_str(hint).override_failure_message(
		"the shortcut hint was displaced by the price instead of joining it"
	).contains("[")


func test_a_disabled_attack_row_shows_price_AND_reason() -> void:
	# ★ "needs AP" says you are short; "2 AP · needs AP" says by how much. The
	# separator is a middle dot, not a comma, so the price does not read as one more
	# item in the reason list.
	var state := _make_state()
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5))
	_place_unit(state, 2, 1, Vector2i(5, 6))
	state.per_player[0].current_ap = 0
	var menu := _make_menu()

	menu.open(state, attacker, Vector2(400, 400), 128.0)

	var hint: String = _hint_of(_row_named(menu, "Attack"))
	assert_str(hint).contains("%d AP" % Combat.attack_cost_for(attacker))
	assert_str(hint).contains("needs AP")
	assert_str(hint).contains("·")


func test_unpriced_verbs_show_no_ap_figure_at_all() -> void:
	# Move is per-tile and Wait is free; a "0 AP" or an invented figure on either
	# would be worse than the blank they get.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	assert_str(_hint_of(_row_named(menu, "Move"))).not_contains("AP")
	assert_str(_hint_of(_row_named(menu, "Wait"))).not_contains("AP")


# ==============================================================================
# Placement — AC-6 / AC-7 / AC-8
# ==============================================================================

func test_the_plate_clears_the_entity_by_at_least_one_tile_width() -> void:
	# AC-6. One tile is what keeps the plate off the entity's own sprite AND off the
	# eight tiles around it — the tiles a Move or Attack preview is most likely to
	# highlight.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()
	var anchor := Vector2(400, 400)
	var tile_width: float = 128.0

	menu.open(state, unit, anchor, tile_width)

	var rect: Rect2 = menu.plate_rect()
	assert_float(rect.position.x - anchor.x).override_failure_message(
		"the plate opened on top of the entity it belongs to"
	).is_greater_equal(tile_width)


func test_the_plate_flips_to_the_other_side_rather_than_running_off_screen() -> void:
	# AC-7. At the board's right edge there is no room on the right, so it mirrors.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()
	var anchor := Vector2(VIEW.x - 40.0, 400.0)

	menu.open(state, unit, anchor, 128.0)

	var rect: Rect2 = menu.plate_rect()
	assert_float(rect.position.x + rect.size.x).override_failure_message(
		"the plate ran off the right edge instead of flipping"
	).is_less_equal(VIEW.x)
	assert_float(rect.position.x + rect.size.x).override_failure_message(
		"a flipped plate must still clear the entity"
	).is_less_equal(anchor.x - 128.0 + 0.01)


func test_the_plate_clamps_vertically_at_the_top_and_bottom_edges() -> void:
	# AC-8, vertical half.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400.0, 0.0), 128.0) # anchor above the screen top
	var top: Rect2 = menu.plate_rect()
	assert_float(top.position.y).is_greater_equal(0.0)

	menu.open(state, unit, Vector2(400.0, VIEW.y), 128.0) # ...and below the bottom
	var bottom: Rect2 = menu.plate_rect()
	assert_float(bottom.position.y + bottom.size.y).is_less_equal(VIEW.y)


func test_the_plate_is_never_clamped_horizontally_over_the_entity() -> void:
	# ★ AC-8, horizontal half — and the subtle one. Sliding the plate vertically
	# keeps it beside the entity; sliding it HORIZONTALLY would push it over the
	# entity, quietly undoing the one-tile clearance at exactly the board edges
	# where the flip already has a better answer.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()
	var anchor := Vector2(VIEW.x - 8.0, 400.0)

	menu.open(state, unit, anchor, 128.0)

	var rect: Rect2 = menu.plate_rect()
	assert_bool(rect.has_point(anchor)).override_failure_message(
		"the plate was clamped onto the entity's own anchor"
	).is_false()


# ==============================================================================
# Submenu + back-out — AC-10 / AC-13
# ==============================================================================

func test_the_produce_row_opens_a_submenu_listing_every_type_with_its_cost() -> void:
	# AC-13.
	var state := _make_state()
	var scout := _make_unit_type("Scout")
	var heavy := _make_unit_type("Heavy")
	var producer := _place_producer(state, 2, 0, Vector2i(4, 4), [scout, heavy] as Array[UnitTypeDef])
	var menu := _make_menu()

	menu.open(state, producer, Vector2(400, 400), 128.0)
	menu.open_produce_submenu(CommandFSM.produce_options(state, producer))

	var rows: Array[Button] = _option_rows(menu)
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0].text).is_equal("Scout")
	assert_str(_hint_of(rows[0])).override_failure_message(
		"a produce row without its cost gives the player nothing to decide on"
	).contains("CR")
	assert_str(_hint_of(rows[0])).contains("AP")


func test_back_out_steps_one_level_at_a_time_submenu_then_menu_then_dismissed() -> void:
	# ★ AC-10. Each press must undo exactly one thing. A back-out that closed the
	# whole surface from inside the submenu would make the submenu a trap you can
	# only leave by abandoning the selection.
	var state := _make_state()
	var scout := _make_unit_type("Scout")
	var producer := _place_producer(state, 2, 0, Vector2i(4, 4), [scout] as Array[UnitTypeDef])
	var menu := _make_menu()
	var dismissals: Array[int] = []
	menu.dismissed.connect(func() -> void: dismissals.append(1))

	menu.open(state, producer, Vector2(400, 400), 128.0)
	menu.open_produce_submenu(CommandFSM.produce_options(state, producer))
	assert_bool(menu.is_submenu_open()).is_true()

	# First press: the submenu closes, the menu stays, nothing is dismissed.
	assert_bool(menu.back_out()).is_true()
	assert_bool(menu.is_submenu_open()).is_false()
	assert_bool(menu.is_open()).is_true()
	assert_int(dismissals.size()).is_equal(0)

	# Second press: the menu closes and the caller is told to deselect.
	assert_bool(menu.back_out()).is_true()
	assert_int(dismissals.size()).is_equal(1)


func test_back_out_reports_false_when_there_was_nothing_to_back_out_of() -> void:
	# ★ The return value is what lets one key mean both "cancel" and "pause" without
	# either meaning guessing (action-menu.md decision 1). A closed menu MUST say
	# false, or Esc could never reach the pause overlay.
	var menu := _make_menu()
	assert_bool(menu.back_out()).is_false()


func test_choosing_a_produce_type_emits_the_type_and_closes_the_surface() -> void:
	var state := _make_state()
	var scout := _make_unit_type("Scout")
	var producer := _place_producer(state, 2, 0, Vector2i(4, 4), [scout] as Array[UnitTypeDef])
	var menu := _make_menu()
	var chosen: Array[UnitTypeDef] = []
	menu.produce_type_chosen.connect(func(t: UnitTypeDef) -> void: chosen.append(t))

	menu.open(state, producer, Vector2(400, 400), 128.0)
	menu.open_produce_submenu(CommandFSM.produce_options(state, producer))
	_option_rows(menu)[0].emit_signal("pressed")

	assert_int(chosen.size()).is_equal(1)
	assert_object(chosen[0]).is_same(scout)
	assert_bool(menu.is_open()).override_failure_message(
		"the menu must get out of the way of the preview it just opened"
	).is_false()


func test_wait_and_dismissal_stay_distinct_signals() -> void:
	# They do the same thing today, and are still separate — see action-menu.md
	# OQ-1. Collapsing them would erase the distinction the open question needs in
	# order to be answerable.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()
	var waits: Array[int] = []
	var dismissals: Array[int] = []
	menu.waited.connect(func() -> void: waits.append(1))
	menu.dismissed.connect(func() -> void: dismissals.append(1))

	menu.open(state, unit, Vector2(400, 400), 128.0)
	_row_named(menu, "Wait").emit_signal("pressed")

	assert_int(waits.size()).is_equal(1)
	assert_int(dismissals.size()).is_equal(0)


# ==============================================================================
# Cancel Build's two-press gate — interaction-patterns.md Hold-to-Confirm Refund,
# and accessibility-requirements.md's Standard-tier hold-alternative commitment
# ==============================================================================

func _place_under_construction(state: GameState, id: int, owner: int, pos: Vector2i) -> StructureState:
	var type := StructureTypeDef.new()
	type.display_name = "Site"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 3
	var structure := StructureState.new()
	structure.entity_id = id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	structure.build_turns_remaining = 2
	state.entities_by_id[id] = structure
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = id
	return structure


func test_cancel_build_arms_on_the_first_press_and_commits_on_the_second() -> void:
	# ★ The pattern library reserves destructive refund actions for a stronger gate
	# than Standard Cancel — a single-activation row is precisely the mis-click
	# Hold-to-Confirm Refund exists to prevent. The gate here is arm-then-confirm
	# rather than press-and-hold because accessibility-requirements.md commits, at
	# Standard tier, to a toggle alternative to that hold for players who cannot
	# sustain a press.
	var state := _make_state()
	var site := _place_under_construction(state, 5, 0, Vector2i(4, 4))
	var menu := _make_menu()
	var chosen: Array[int] = []
	menu.verb_chosen.connect(func(v: int) -> void: chosen.append(v))

	menu.open(state, site, Vector2(400, 400), 128.0)
	var row: Button = _row_named(menu, "Cancel Build")
	assert_object(row).override_failure_message(
		"an owned under-construction structure must offer Cancel Build"
	).is_not_null()

	# First press ARMS. Nothing is destroyed.
	row.emit_signal("pressed")
	assert_bool(menu.is_armed(CommandFSM.Verb.CANCEL_BUILD)).is_true()
	assert_int(chosen.size()).override_failure_message(
		"the first press must not commit — that is the whole gate"
	).is_equal(0)
	assert_bool(menu.is_open()).is_true()

	# Second press COMMITS.
	_row_named(menu, ActionMenu.CONFIRM_LABEL).emit_signal("pressed")
	assert_int(chosen.size()).is_equal(1)
	assert_int(chosen[0]).is_equal(CommandFSM.Verb.CANCEL_BUILD)


func test_the_armed_row_relabels_so_a_double_click_lands_on_a_changed_button() -> void:
	# How this stays double-click-proof without a hold: the second click of a
	# double-click arrives at a button that no longer says "Cancel Build". The
	# player sees what they are about to do even if they cannot stop in time.
	var state := _make_state()
	var site := _place_under_construction(state, 5, 0, Vector2i(4, 4))
	var menu := _make_menu()

	menu.open(state, site, Vector2(400, 400), 128.0)
	_row_named(menu, "Cancel Build").emit_signal("pressed")

	assert_object(_row_named(menu, "Cancel Build")).override_failure_message(
		"the armed row must stop reading as its own verb name"
	).is_null()
	assert_object(_row_named(menu, ActionMenu.CONFIRM_LABEL)).is_not_null()


func test_backing_out_of_an_armed_row_means_no_and_consumes_the_press() -> void:
	# ★ Backing out of "are you sure" must mean "no" — not "no, and also close the
	# menu", which would leave the player unsure whether they had just destroyed
	# something.
	var state := _make_state()
	var site := _place_under_construction(state, 5, 0, Vector2i(4, 4))
	var menu := _make_menu()
	var chosen: Array[int] = []
	var dismissals: Array[int] = []
	menu.verb_chosen.connect(func(v: int) -> void: chosen.append(v))
	menu.dismissed.connect(func() -> void: dismissals.append(1))

	menu.open(state, site, Vector2(400, 400), 128.0)
	_row_named(menu, "Cancel Build").emit_signal("pressed")

	assert_bool(menu.back_out()).is_true()
	assert_bool(menu.is_armed(CommandFSM.Verb.CANCEL_BUILD)).is_false()
	assert_int(chosen.size()).is_equal(0)
	assert_int(dismissals.size()).override_failure_message(
		"disarming must not also dismiss the menu — that is two undos for one press"
	).is_equal(0)
	assert_bool(menu.is_open()).is_true()
	assert_object(_row_named(menu, "Cancel Build")).override_failure_message(
		"the row must go back to reading as itself once disarmed"
	).is_not_null()


func test_the_refund_is_shown_before_either_press_not_after() -> void:
	# The pattern's "see the cost before you commit" promise, applied to a
	# negative-outcome action: the player must know what they get back while
	# deciding, not once the structure is already gone.
	var state := _make_state()
	var site := _place_under_construction(state, 5, 0, Vector2i(4, 4))
	var menu := _make_menu()

	menu.open(state, site, Vector2(400, 400), 128.0)

	var refund: int = CommandFSM.cancel_build_preview(state, site)
	assert_str(_hint_of(_row_named(menu, "Cancel Build"))).override_failure_message(
		"the Cancel Build row must state the refund up front"
	).contains(str(refund))


func test_choosing_a_different_verb_abandons_an_armed_cancel() -> void:
	# A half-made destructive decision must not survive the player moving on.
	var state := _make_state()
	var site := _place_under_construction(state, 5, 0, Vector2i(4, 4))
	var menu := _make_menu()
	var chosen: Array[int] = []
	menu.verb_chosen.connect(func(v: int) -> void: chosen.append(v))

	menu.open(state, site, Vector2(400, 400), 128.0)
	_row_named(menu, "Cancel Build").emit_signal("pressed")
	_row_named(menu, "Wait").emit_signal("pressed")

	assert_bool(menu.is_armed(CommandFSM.Verb.CANCEL_BUILD)).is_false()
	assert_bool(chosen.has(CommandFSM.Verb.CANCEL_BUILD)).is_false()


# ==============================================================================
# Disband — the second destructive verb (action-menu.md OQ-3)
# ==============================================================================

func test_a_unit_offers_disband_with_its_price_and_its_payout() -> void:
	# ★ Disband is the only verb that both SPENDS and PAYS OUT, and a player
	# weighing it against simply holding the unit needs both halves of that trade
	# in front of them before committing to anything.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)

	var row: Button = _row_named(menu, "Disband")
	assert_object(row).override_failure_message(
		"a unit must offer Disband — before 2026-08-25 the action existed and was "
		+ "reachable from nothing at all"
	).is_not_null()
	assert_bool(row.disabled).is_false()
	var hint: String = _hint_of(row)
	assert_str(hint).contains("AP")
	assert_str(hint).override_failure_message(
		"the Disband row must state the refund before either press"
	).contains(str(CommandFSM.disband_preview(unit)))


func test_a_structure_is_never_offered_disband() -> void:
	# UR-7: structures are not disbanded. The row is DROPPED rather than shown
	# greyed out, because "Disband — not a unit" on every structure teaches nothing
	# and costs a row on every base menu in the game.
	var state := _make_state()
	var producer := _place_producer(
		state, 2, 0, Vector2i(4, 4), [_make_unit_type("Scout")] as Array[UnitTypeDef]
	)
	var menu := _make_menu()

	menu.open(state, producer, Vector2(400, 400), 128.0)

	assert_object(_row_named(menu, "Disband")).is_null()


func test_disband_takes_two_presses_like_every_destructive_verb() -> void:
	# ★★ The safety property that matters most about this row. Disband destroys a
	# unit outright for a partial refund — the textbook case for the pattern
	# library's Hold-to-Confirm Refund — and unlike Cancel Build it is available on
	# EVERY unit, every turn. A single-press Disband would put an irreversible
	# action one careless click away on almost every menu in the game.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()
	var chosen: Array[int] = []
	menu.verb_chosen.connect(func(v: int) -> void: chosen.append(v))

	menu.open(state, unit, Vector2(400, 400), 128.0)
	_row_named(menu, "Disband").emit_signal("pressed")

	assert_bool(menu.is_armed(CommandFSM.Verb.DISBAND)).is_true()
	assert_int(chosen.size()).is_equal(0)

	_row_named(menu, ActionMenu.CONFIRM_LABELS[CommandFSM.Verb.DISBAND]).emit_signal("pressed")
	assert_int(chosen.size()).is_equal(1)
	assert_int(chosen[0]).is_equal(CommandFSM.Verb.DISBAND)


func test_an_armed_disband_names_disbanding_not_cancelling() -> void:
	# Per-verb confirm labels: "Confirm cancel" on a Disband row would name the
	# wrong act at the exact moment the player is being asked to be sure about it.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0)
	_row_named(menu, "Disband").emit_signal("pressed")

	assert_object(_row_named(menu, "Confirm disband")).is_not_null()
	assert_object(_row_named(menu, "Confirm cancel")).is_null()


func test_every_destructive_verb_is_registered_as_one() -> void:
	# ★ The list IS the safety rule. A destructive verb missing from
	# DESTRUCTIVE_VERBS commits on one press with no gate and nothing else would
	# catch it — so this asserts the two known ones are on it, and that anything on
	# it is a verb the menu actually knows how to label.
	assert_array(ActionMenu.DESTRUCTIVE_VERBS).contains(
		[CommandFSM.Verb.CANCEL_BUILD, CommandFSM.Verb.DISBAND]
	)
	for verb: int in ActionMenu.DESTRUCTIVE_VERBS:
		assert_bool(ActionMenu.CONFIRM_LABELS.has(verb)).override_failure_message(
			"destructive verb %d has no armed-state label — its row would arm and "
			% verb + "look completely unchanged"
		).is_true()
		assert_bool(ActionMenu.VERB_LABELS.has(verb)).is_true()


# ==============================================================================
# The player-level Build picker (CR-5)
# ==============================================================================

func test_the_build_picker_grows_inward_from_its_hud_corner() -> void:
	# ★ A different placement rule from the verb menu's, on purpose: a picker hangs
	# off a HUD control in a screen CORNER, where "flip to the other side" is
	# meaningless and growing up-and-left out of the button is the only placement
	# that reads as belonging to it.
	var state := _make_state()
	var type := StructureTypeDef.new()
	type.display_name = "Barracks"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 2
	var menu := _make_menu()
	var corner := Vector2(VIEW.x - 16.0, VIEW.y - 90.0)

	menu.open_build_options(
		CommandFSM.build_options(state, 0, [type] as Array[StructureTypeDef]), corner, 128.0
	)

	var plate: Control = menu.get_node_or_null(^"OptionPlate")
	assert_object(plate).is_not_null()
	var size: Vector2 = plate.get_combined_minimum_size()
	assert_float(plate.position.x + size.x).override_failure_message(
		"the picker must not spill past the corner it hangs off"
	).is_less_equal(corner.x + 0.01)
	assert_float(plate.position.y + size.y).override_failure_message(
		"the picker must rise ABOVE its button, not sink past the screen bottom"
	).is_less_equal(corner.y + 0.01)
	assert_float(plate.position.y).is_greater_equal(0.0)


func test_the_build_picker_leaves_no_empty_verb_plate_behind_it() -> void:
	# Regression: the picker reuses the widget that normally carries a verb menu.
	# A first cut left that verb plate visible and empty, drawing a bare bordered
	# rectangle beside the picker.
	var state := _make_state()
	var type := StructureTypeDef.new()
	type.display_name = "Barracks"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 2
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5))
	var menu := _make_menu()

	menu.open(state, unit, Vector2(400, 400), 128.0) # a verb menu exists first...
	menu.open_build_options(
		CommandFSM.build_options(state, 0, [type] as Array[StructureTypeDef]),
		Vector2(VIEW.x - 16.0, VIEW.y - 90.0), 128.0
	)

	var verb_plate: Control = menu.get_node_or_null(^"MenuPlate")
	if verb_plate != null:
		assert_bool(verb_plate.visible).override_failure_message(
			"the empty verb plate must not stay on screen behind the Build picker"
		).is_false()
