# Menu reachability by keyboard and gamepad (ADR-0014 §2/§6).
#
# WHY THIS SUITE EXISTS: until 2026-08-24 the HUD's "Build" and "End Turn"
# controls were `draw_string` calls. The words were painted on screen and NOTHING
# could activate them -- not a mouse click, not a key, not a pad button.
# `request_build()` had no caller anywhere outside the test suite, and
# `controls_focus_mode()` computed FOCUS_ALL vs FOCUS_NONE for a value that was
# returned to tests and then dropped on the floor.
#
# `technical-preferences.md` forbids hover-only interactions: every interaction
# reachable by mouse must also be reachable by keyboard/gamepad (TR-cmdui-024).
# These controls were reachable by NOTHING, which passed that bar on a technicality
# and failed the intent completely.
#
# The tests here pin the properties that make them reachable, because every one of
# them is invisible to a test that only checks the display model.
extends GdUnitTestSuite


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_controls(reader: GameStateReader, local_player: int) -> HudControlsWidget:
	var controls: HudControlsWidget = auto_free(HudControlsWidget.new())
	controls.bind(reader)
	controls.configure(HUDConfig.new(), local_player)
	add_child(controls)
	return controls


func _buttons(controls: HudControlsWidget) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in controls.get_children():
		if child is Button:
			out.append(child as Button)
	return out


# ==============================================================================
# The controls are real, focusable Controls -- not painted text.
# ==============================================================================

func test_controls_are_real_buttons_not_drawn_text() -> void:
	# ⚠ ONE control now, not two. The Build button was removed on 2026-08-25 (user
	# decision): Build belongs to a selected Builder and consumes it, and a HUD
	# button has no way to say WHICH Builder it means. End Turn is the only
	# player-level control left. The claim under test is unchanged — whatever
	# controls this group holds must be real, focusable Buttons rather than painted
	# text, which is the defect this suite was written for.
	var state := _make_state(0)
	var controls := _make_controls(GameStateReader.new(state), 0)
	var buttons: Array[Button] = _buttons(controls)

	assert_int(buttons.size()).override_failure_message(
		"End Turn must be a real Button — drawn text cannot take focus, " +
		"cannot be clicked, and cannot carry the theme's focus StyleBox"
	).is_equal(1)
	for b: Button in buttons:
		assert_int(b.focus_mode).is_equal(Control.FOCUS_ALL)


func test_the_single_control_needs_no_traversal_wiring() -> void:
	# ⚠ REPLACED the two-control traversal test on 2026-08-25. That test asserted
	# `focus_neighbor_right`/`_left` linked Build and End Turn (ADR-0014 §6:
	# traversal via focus_neighbor_*, never hand-rolled arbitration). With the Build
	# button gone there is nothing to traverse BETWEEN, so the old assertion has no
	# subject.
	#
	# ★ Kept as its inverse rather than deleted, because the thing worth protecting
	# is unchanged: if a second player-level control is ever added here, it must be
	# reachable. A bare group with a dangling neighbour path pointing at a button
	# that no longer exists would resolve to null and strand a gamepad silently.
	var state := _make_state(0)
	var controls := _make_controls(GameStateReader.new(state), 0)
	var buttons: Array[Button] = _buttons(controls)

	assert_int(buttons.size()).is_equal(1)
	var end_turn: Button = buttons[0]
	for path: NodePath in [end_turn.focus_neighbor_left, end_turn.focus_neighbor_right,
			end_turn.focus_next, end_turn.focus_previous]:
		assert_bool(path.is_empty() or end_turn.get_node_or_null(path) != null) \
			.override_failure_message(
				"a focus path pointing at a removed control resolves to null and " +
				"strands a gamepad with nowhere to go"
			).is_true()


# ==============================================================================
# Focus entry and exit -- the part a gamepad cannot do without help.
# ==============================================================================

func test_focus_first_grabs_focus_and_reports_it() -> void:
	var state := _make_state(0)
	var controls := _make_controls(GameStateReader.new(state), 0)

	assert_bool(controls.has_menu_focus()).is_false() # board is driving
	assert_bool(controls.focus_first()).is_true()
	await get_tree().process_frame
	assert_bool(controls.has_menu_focus()).is_true()


func test_focus_can_always_be_released_back_to_the_board() -> void:
	# ★ The property that keeps a controller player from getting stuck. With focus
	# held by a Control, every direction press is consumed by focus traversal and
	# never reaches the board cursor (ADR-0014 §2) — so if focus could not be
	# released, a pad would be trapped in a two-button panel.
	var state := _make_state(0)
	var controls := _make_controls(GameStateReader.new(state), 0)
	controls.focus_first()
	await get_tree().process_frame
	assert_bool(controls.has_menu_focus()).is_true()

	controls.release_menu_focus()
	await get_tree().process_frame
	assert_bool(controls.has_menu_focus()).override_failure_message(
		"menu focus must be releasable — a pad that cannot leave the menu cannot play"
	).is_false()


# ==============================================================================
# Inert controls are genuinely unfocusable, not merely dimmed.
# ==============================================================================

func test_opponent_turn_makes_the_controls_unfocusable() -> void:
	# ADR-0014 §6 requires present-but-inert controls to set FOCUS_NONE rather than
	# suppressing a focus ring per frame. Dimming alone would leave a pad able to
	# focus End Turn during the opponent's turn and press it.
	var state := _make_state(1) # opponent active
	var controls := _make_controls(GameStateReader.new(state), 0)
	controls._sync_button_state()

	assert_bool(controls.controls_live()).is_false()
	assert_int(controls.controls_focus_mode()).is_equal(Control.FOCUS_NONE)
	for b: Button in _buttons(controls):
		assert_int(b.focus_mode).override_failure_message(
			"an inert control must be unfocusable, not just dim"
		).is_equal(Control.FOCUS_NONE)
		assert_bool(b.disabled).is_true()


func test_focus_first_refuses_while_inert() -> void:
	var state := _make_state(1) # opponent active
	var controls := _make_controls(GameStateReader.new(state), 0)
	assert_bool(controls.focus_first()).is_false()
	assert_bool(controls.has_menu_focus()).is_false()


# ==============================================================================
# Activation routes through the same gate as every other input path.
# ==============================================================================

func test_pressing_a_live_button_emits_its_request_signal() -> void:
	var state := _make_state(0)
	var controls := _make_controls(GameStateReader.new(state), 0)
	controls._sync_button_state()
	var buttons: Array[Button] = _buttons(controls)

	# ⚠ End Turn only — the Build button was removed 2026-08-25 (Build is the
	# selected Builder's verb now), so `build_requested` has no emitter here.
	var seen: Array[String] = []
	controls.end_turn_requested.connect(func() -> void: seen.append("end_turn"))

	buttons[0].pressed.emit()
	assert_array(seen).contains(["end_turn"])


func test_an_inert_button_press_emits_nothing() -> void:
	# The signal is gated on the same request_*() live check the keyboard path uses,
	# so a click and a keypress cannot disagree about whether an action is allowed.
	var state := _make_state(1) # opponent active
	var controls := _make_controls(GameStateReader.new(state), 0)
	controls._sync_button_state()
	var buttons: Array[Button] = _buttons(controls)

	var seen: Array[String] = []
	controls.end_turn_requested.connect(func() -> void: seen.append("end_turn"))

	buttons[0].pressed.emit()
	assert_array(seen).is_empty()
