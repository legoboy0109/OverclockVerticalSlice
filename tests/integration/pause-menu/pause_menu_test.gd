# Pause overlay — against design/ux/pause.md's Acceptance Criteria (Approved,
# /ux-review 2026-07-27).
#
# Several of these pin properties that only bite a player holding a controller or
# a player who mis-clicks: that Resume holds focus on open, that Esc backs out one
# step rather than two, and that Restart cannot fire without a confirm — it discards the
# match. ★ Since save/load (2026-09-29) Quit is "Save & Quit to Menu": the match is kept in
# the autosave, so it fires at once; gating it would only slow the player down.
extends GdUnitTestSuite


func _make_pause() -> PauseMenu:
	var p: PauseMenu = auto_free(PauseMenu.new())
	add_child(p)
	await get_tree().process_frame
	return p


# ==============================================================================
# AC: the four entries, in order, Resume focused on open.
# ==============================================================================

func test_offers_the_specified_entries_in_focus_order() -> void:
	var p: PauseMenu = await _make_pause()
	assert_array(p.entry_labels()).is_equal(
		["RESUME", "SAVE GAME", "RESTART SKIRMISH", "SETTINGS", "SAVE & QUIT TO MENU"])


func test_starts_closed_and_opens_with_resume_focused() -> void:
	# ★ Resume is the default action — the spec's hierarchy puts it first because
	# most players pause and then resume. It also gives a gamepad somewhere to
	# start; without focus, no direction press does anything.
	var p: PauseMenu = await _make_pause()
	assert_bool(p.is_open()).is_false()
	p.open()
	await get_tree().process_frame
	assert_bool(p.is_open()).is_true()
	assert_int(p.focused_entry()).is_equal(PauseMenu.Entry.RESUME)


func test_all_four_entries_are_interactive_now_that_settings_exists() -> void:
	# ★ Settings was inert only while SettingsScreen did not exist. It landed
	# 2026-08-24, so pause.md's Settings acceptance criterion can pass.
	var p: PauseMenu = await _make_pause()
	assert_bool(p.entry_interactive(PauseMenu.Entry.RESUME)).is_true()
	assert_bool(p.entry_interactive(PauseMenu.Entry.SAVE)).is_true()
	assert_bool(p.entry_interactive(PauseMenu.Entry.RESTART)).is_true()
	assert_bool(p.entry_interactive(PauseMenu.Entry.SETTINGS)).is_true()
	assert_bool(p.entry_interactive(PauseMenu.Entry.QUIT_TO_MENU)).is_true()


# ==============================================================================
# AC: destructive actions cannot fire without a confirm step.
# ==============================================================================

func test_restart_opens_a_confirm_and_does_not_fire_immediately() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	var fired: Array[String] = []
	p.restart_requested.connect(func() -> void: fired.append("restart"))

	p._open_confirm(PauseMenu.Confirm.RESTART)
	await get_tree().process_frame

	assert_int(p.open_confirm_kind()).is_equal(PauseMenu.Confirm.RESTART)
	assert_str(p.confirm_text()).contains("Restart")
	assert_array(fired).override_failure_message(
		"Restart must not fire on the entry press — the match is unrecoverable"
	).is_empty()


func test_restart_confirm_names_the_consequence() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	p._open_confirm(PauseMenu.Confirm.RESTART)
	await get_tree().process_frame
	# The wording has to say what is lost, not just ask twice.
	assert_str(p.confirm_text()).contains("discarded")


func test_save_and_quit_fires_at_once_because_nothing_is_lost() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	var fired: Array[String] = []
	p.quit_to_menu_requested.connect(func() -> void: fired.append("quit"))
	p.request_save_and_quit()
	await get_tree().process_frame
	assert_array(fired).is_equal(["quit"])
	assert_int(p.open_confirm_kind()).is_equal(PauseMenu.Confirm.NONE)
	assert_bool(p.is_open()).is_false()


func test_save_game_opens_the_slots_and_reports_the_choice() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	var saved: Array[String] = []
	p.save_requested.connect(func(slot: String) -> void: saved.append(slot))
	for slot: String in SaveGame.MANUAL_SLOTS:
		SaveGame.delete(slot)   # the test save folder: empty slots save on the first press
	p._open_save_slots()
	await get_tree().process_frame
	var panel: SaveSlotsPanel = null
	for c: Node in p.get_children():
		if c is SaveSlotsPanel:
			panel = c
	assert_object(panel).is_not_null()
	panel.press("slot2")
	await get_tree().process_frame
	assert_array(saved).is_equal(["slot2"])
	assert_bool(p.is_open()).override_failure_message("Saving returns to the pause menu").is_true()


func test_confirming_fires_exactly_the_matching_signal() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	var fired: Array[String] = []
	p.restart_requested.connect(func() -> void: fired.append("restart"))
	p.quit_to_menu_requested.connect(func() -> void: fired.append("quit"))

	p._open_confirm(PauseMenu.Confirm.RESTART)
	p.confirm_now()
	await get_tree().process_frame

	assert_array(fired).is_equal(["restart"])
	assert_bool(p.is_open()).is_false()


func test_cancelling_a_confirm_returns_to_the_entry_it_came_from() -> void:
	# Not to the top of the list: silently moving focus after a cancel makes the
	# next press land somewhere the player did not choose.
	var p: PauseMenu = await _make_pause()
	p.open()
	p._open_confirm(PauseMenu.Confirm.RESTART)
	await get_tree().process_frame
	p.close_confirm()
	await get_tree().process_frame

	assert_int(p.open_confirm_kind()).is_equal(PauseMenu.Confirm.NONE)
	assert_bool(p.is_open()).is_true() # back on the pause menu, not in the match
	assert_int(p.focused_entry()).is_equal(PauseMenu.Entry.RESTART)


# ==============================================================================
# AC: Resume returns to the match; Esc is symmetric and backs out ONE step.
# ==============================================================================

func test_resume_closes_the_overlay_and_reports_it() -> void:
	var p: PauseMenu = await _make_pause()
	p.open()
	var resumed: Array[String] = []
	p.resume_requested.connect(func() -> void: resumed.append("resume"))

	p.request_resume()
	await get_tree().process_frame

	assert_bool(p.is_open()).is_false()
	assert_array(resumed).is_equal(["resume"])


func test_escape_from_a_confirm_returns_to_pause_not_to_the_match() -> void:
	# ★ Esc backs out one step. Dropping straight into the match from a half-made
	# destructive decision would be the wrong kind of shortcut — the player pressed
	# Esc to retreat from the prompt, not to dismiss everything.
	var p: PauseMenu = await _make_pause()
	p.open()
	p._open_confirm(PauseMenu.Confirm.RESTART)
	await get_tree().process_frame

	var resumed: Array[String] = []
	p.resume_requested.connect(func() -> void: resumed.append("resume"))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	p._unhandled_input(esc)
	await get_tree().process_frame

	assert_int(p.open_confirm_kind()).is_equal(PauseMenu.Confirm.NONE)
	assert_bool(p.is_open()).override_failure_message(
		"Esc from a confirm must return to the pause menu, not resume the match"
	).is_true()
	assert_array(resumed).is_empty()


# ==============================================================================
# Accessibility floors and the shared look.
# ==============================================================================

func test_entries_meet_the_font_and_hit_target_floors() -> void:
	var p: PauseMenu = await _make_pause()
	var found: int = 0
	for b: Button in _all_buttons(p):
		found += 1
		assert_int(b.get_theme_font_size("font_size")).is_greater_equal(20)
		assert_float(b.custom_minimum_size.y).is_greater_equal(MenuStyle.MIN_HIT_TARGET)
	assert_int(found).is_greater(0)


func test_keyboard_focus_is_distinct_from_mouse_hover() -> void:
	var p: PauseMenu = await _make_pause()
	for b: Button in _all_buttons(p):
		var f: StyleBoxFlat = b.get_theme_stylebox("focus")
		var h: StyleBoxFlat = b.get_theme_stylebox("hover")
		assert_bool(f.bg_color != h.bg_color).is_true()
		assert_bool(f.border_width_top != h.border_width_top).override_failure_message(
			"focus and hover must differ by more than hue — 'no info by colour alone'"
		).is_true()


func _all_buttons(n: Node, out: Array[Button] = []) -> Array[Button]:
	if n is Button:
		out.append(n as Button)
	for c: Node in n.get_children():
		_all_buttons(c, out)
	return out
