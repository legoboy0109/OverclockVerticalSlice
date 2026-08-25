# InputGlyphs — labels follow the device the player is actually holding (S8-06).
#
# ★★ WHY THIS EXISTS. Every binding in the game has carried a gamepad event since S6-17/S6-20,
# and nothing ever displayed one. The slice's control legend was a hardcoded keyboard string, and
# ActionMenu._shortcut_for matched InputEventKey only — returning an EMPTY hint on a pad. A player
# on a controller was being told to press keys they do not have, while the correct binding sat in
# the InputMap unused.
#
# ⚠ This is a Steam Deck Verified criterion, and the Deck is the project's hardware floor (S7-08).
extends GdUnitTestSuite


func after() -> void:
	# Leave the singleton as we found it — it is an autoload shared by every other suite.
	InputGlyphs.set_device_for_test(InputGlyphs.Device.KEYBOARD)


func test_keyboard_labels_name_the_key() -> void:
	# Arrange
	InputGlyphs.set_device_for_test(InputGlyphs.Device.KEYBOARD)
	# Act / Assert — board_build is bound to B and to the left shoulder.
	assert_str(InputGlyphs.label_for(&"board_build")).is_equal("[B]")


func test_gamepad_labels_name_the_pad_button_for_the_same_action() -> void:
	# ★ The assertion the old code could not have passed: same action, different device, and the
	# label must change. board_build carries JOY_BUTTON_LEFT_SHOULDER alongside its B key.
	InputGlyphs.set_device_for_test(InputGlyphs.Device.GAMEPAD)
	assert_str(InputGlyphs.label_for(&"board_build")).override_failure_message(
		"On a gamepad, board_build must read as its pad button, not its key. Before S8-06 this " +
		"returned an empty string and the control was undiscoverable on a controller."
	).is_equal("[LB]")


func test_every_shipped_board_action_has_a_label_on_both_devices() -> void:
	# ★ The regression that matters most: a verb added later without a pad event would silently
	# become keyboard-only, which is exactly how this defect class arises. Named actions only —
	# the ui_* engine defaults are covered separately below.
	var actions: Array[StringName] = [
		&"board_act", &"board_attack", &"board_build", &"board_produce",
		&"board_end_turn", &"board_pause", &"board_menu_focus", &"board_cursor_cycle",
	]
	for action: StringName in actions:
		assert_bool(InputMap.has_action(action)).override_failure_message(
			"Action %s is missing from the InputMap entirely." % action).is_true()
		for device: int in [InputGlyphs.Device.KEYBOARD, InputGlyphs.Device.GAMEPAD]:
			var name: String = InputGlyphs.name_for(action, device)
			assert_str(name).override_failure_message(
				("%s has no label on device %d — it is bound on one device only. " % [action, device]) +
				"Every board verb must be reachable from both, or a player on that device " +
				"cannot discover or perform it."
			).is_not_empty()


func test_the_engine_default_navigation_actions_resolve_on_both_devices() -> void:
	# ui_accept / ui_cancel / ui_up are engine-provided and carry pad events by default. The
	# legend asks for them BY NAME rather than spelling them out, so that a rebind moves them —
	# which only works if they actually resolve.
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_up"]:
		for device: int in [InputGlyphs.Device.KEYBOARD, InputGlyphs.Device.GAMEPAD]:
			assert_str(InputGlyphs.name_for(action, device)).override_failure_message(
				"%s does not resolve on device %d — the legend would silently drop it." % [action, device]
			).is_not_empty()


func test_an_unknown_action_yields_an_empty_label_rather_than_erroring() -> void:
	# This runs inside label-building loops; it must never throw mid-render.
	InputGlyphs.set_device_for_test(InputGlyphs.Device.KEYBOARD)
	assert_str(InputGlyphs.label_for(&"no_such_action_exists")).is_empty()


func test_a_device_with_no_binding_falls_back_rather_than_showing_nothing() -> void:
	# ★ Deliberate: a label naming the wrong device is a smaller failure than a control the
	# player cannot discover at all. An empty string reads as "this verb has no shortcut", which
	# is a lie; the fallback is at least visible and correctable.
	var action := &"_test_keyboard_only_action"
	InputMap.add_action(action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	InputMap.action_add_event(action, key)
	InputGlyphs.set_device_for_test(InputGlyphs.Device.GAMEPAD)
	assert_str(InputGlyphs.label_for(action)).override_failure_message(
		"A gamepad player looking at a keyboard-only action should still see SOMETHING."
	).is_equal("[J]")
	InputMap.erase_action(action)


func test_device_changed_fires_only_on_an_actual_change() -> void:
	# Subscribers redraw on this signal, so firing per-event would make it a per-frame cost.
	InputGlyphs.set_device_for_test(InputGlyphs.Device.KEYBOARD)
	var spy := _Spy.new()
	InputGlyphs.device_changed.connect(spy.on_changed)
	InputGlyphs.set_device_for_test(InputGlyphs.Device.KEYBOARD) # same device — no emit
	assert_int(spy.count).is_equal(0)
	InputGlyphs.set_device_for_test(InputGlyphs.Device.GAMEPAD)  # changed — one emit
	assert_int(spy.count).is_equal(1)
	InputGlyphs.set_device_for_test(InputGlyphs.Device.GAMEPAD)  # same again — still one
	assert_int(spy.count).is_equal(1)
	InputGlyphs.device_changed.disconnect(spy.on_changed)


func test_pad_button_names_match_the_shipped_bindings() -> void:
	# ★ Pins the mapping against project.godot's actual `[input]` block rather than against the
	# enum, so a re-binding that moves a verb to a different button shows up here as a diff.
	InputGlyphs.set_device_for_test(InputGlyphs.Device.GAMEPAD)
	var expected: Dictionary = {
		&"board_act": "[X]",            # JOY_BUTTON_X
		&"board_attack": "[Y]",         # JOY_BUTTON_Y
		&"board_build": "[LB]",         # JOY_BUTTON_LEFT_SHOULDER
		&"board_produce": "[RB]",       # JOY_BUTTON_RIGHT_SHOULDER
		&"board_end_turn": "[Back]",    # JOY_BUTTON_BACK
		&"board_pause": "[Start]",      # JOY_BUTTON_START
		&"board_menu_focus": "[R3]",    # JOY_BUTTON_RIGHT_STICK
		&"board_cursor_cycle": "[L3]",  # JOY_BUTTON_LEFT_STICK — the mnemonic from S6-25
	}
	for action: StringName in expected:
		assert_str(InputGlyphs.label_for(action)).override_failure_message(
			"%s should read %s on a pad." % [action, expected[action]]
		).is_equal(expected[action])


class _Spy extends RefCounted:
	var count: int = 0
	func on_changed(_device: int) -> void:
		count += 1
