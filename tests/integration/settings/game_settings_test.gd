# GameSettings — the project's first settings store.
#
# Nothing a player chose survived closing the game before 2026-08-24: `user://`
# was unused everywhere. These tests pin the properties that make the store
# trustworthy rather than merely present — that a rebind actually reaches the live
# InputMap, that conflicts are DETECTED but not refused, that only overrides are
# stored (so a player inherits future default changes), and that a settings file
# outliving its build degrades cleanly.
extends GdUnitTestSuite


func _fresh() -> GameSettings:
	var s := GameSettings.new()
	s.reset_to_defaults()
	return s


func after_test() -> void:
	# Rebinding mutates the global InputMap; restore it so tests stay isolated.
	_fresh().apply_bindings()


# ==============================================================================
# Bindings reach the live InputMap.
# ==============================================================================

func test_a_rebind_actually_changes_what_the_engine_listens_for() -> void:
	# ★ The property that matters. A settings screen that records a preference the
	# InputMap never hears is a screen that lies to the player.
	var s := _fresh()
	s.set_binding(&"board_end_turn", GameSettings.Device.KEYBOARD, KEY_F5)
	s.apply_bindings()

	var probe := InputEventKey.new()
	probe.physical_keycode = KEY_F5
	assert_bool(InputMap.event_is_action(probe, &"board_end_turn")).is_true()


func test_rebinding_replaces_rather_than_accumulates() -> void:
	# Rebuilding each action from scratch is why: appending would leave the old key
	# working too, so a player who rebinds away from a key still triggers on it.
	var s := _fresh()
	var original: int = s.binding(&"board_pause", GameSettings.Device.KEYBOARD)
	s.set_binding(&"board_pause", GameSettings.Device.KEYBOARD, KEY_F6)
	s.apply_bindings()

	var old_probe := InputEventKey.new()
	old_probe.physical_keycode = original
	assert_bool(InputMap.event_is_action(old_probe, &"board_pause")) \
		.override_failure_message("the previous key must stop working after a rebind") \
		.is_false()


func test_keyboard_and_gamepad_rebind_independently() -> void:
	# accessibility-requirements.md: "rebindable INDEPENDENTLY across keyboard,
	# mouse and gamepad".
	var s := _fresh()
	var pad_before: int = s.binding(&"board_build", GameSettings.Device.GAMEPAD)
	s.set_binding(&"board_build", GameSettings.Device.KEYBOARD, KEY_F7)
	assert_int(s.binding(&"board_build", GameSettings.Device.GAMEPAD)).is_equal(pad_before)


# ==============================================================================
# Conflicts: detected, reported, NOT refused.
# ==============================================================================

func test_conflicts_are_detected_across_actions_on_the_same_device() -> void:
	var s := _fresh()
	var end_turn_key: int = s.binding(&"board_end_turn", GameSettings.Device.KEYBOARD)
	var clashes: Array[StringName] = s.conflicts(
		end_turn_key, GameSettings.Device.KEYBOARD, &"board_pause")
	assert_array(clashes).contains([&"board_end_turn"])


func test_a_conflicting_bind_is_allowed_so_a_swap_is_possible() -> void:
	# ★ Refusing duplicates outright would make swapping two bindings impossible —
	# every swap passes through a state where both actions want the same input. The
	# screen warns; the player decides.
	var s := _fresh()
	var end_turn_key: int = s.binding(&"board_end_turn", GameSettings.Device.KEYBOARD)
	s.set_binding(&"board_pause", GameSettings.Device.KEYBOARD, end_turn_key)
	assert_int(s.binding(&"board_pause", GameSettings.Device.KEYBOARD)).is_equal(end_turn_key)


func test_a_binding_does_not_conflict_with_itself() -> void:
	var s := _fresh()
	var key: int = s.binding(&"board_act", GameSettings.Device.KEYBOARD)
	assert_array(s.conflicts(key, GameSettings.Device.KEYBOARD, &"board_act")).is_empty()


# ==============================================================================
# Only overrides are stored.
# ==============================================================================

func test_an_untouched_binding_is_not_an_override() -> void:
	# ★ So a player who never rebinds inherits future changes to project.godot.
	# Storing every binding would freeze today's defaults into their settings file
	# forever, and they would never see a rebalanced control scheme.
	var s := _fresh()
	assert_bool(s.has_overrides()).is_false()
	s.set_binding(&"board_act", GameSettings.Device.KEYBOARD, KEY_F8)
	assert_bool(s.has_overrides()).is_true()


func test_reset_restores_the_shipped_bindings() -> void:
	var s := _fresh()
	var shipped: int = s.binding(&"board_act", GameSettings.Device.KEYBOARD)
	s.set_binding(&"board_act", GameSettings.Device.KEYBOARD, KEY_F9)
	assert_int(s.binding(&"board_act", GameSettings.Device.KEYBOARD)).is_equal(KEY_F9)

	s.reset_to_defaults()
	assert_int(s.binding(&"board_act", GameSettings.Device.KEYBOARD)).is_equal(shipped)
	assert_bool(s.has_overrides()).is_false()


# ==============================================================================
# Display values, and their committed range.
# ==============================================================================

func test_ui_scale_range_matches_the_committed_accessibility_range() -> void:
	# accessibility-requirements.md: "Range 75%-150%, default 100%".
	assert_float(GameSettings.UI_SCALE_MIN).is_equal_approx(0.75, 0.001)
	assert_float(GameSettings.UI_SCALE_MAX).is_equal_approx(1.50, 0.001)
	assert_float(GameSettings.UI_SCALE_DEFAULT).is_equal_approx(1.0, 0.001)


# ==============================================================================
# Persistence, including a settings file that outlives its build.
# ==============================================================================

func test_settings_survive_a_save_and_load_round_trip() -> void:
	var s := _fresh()
	s.ui_scale = 1.25
	s.reduced_motion = true
	s.set_binding(&"board_pause", GameSettings.Device.KEYBOARD, KEY_F10)
	assert_int(s.save()).is_equal(OK)

	var loaded := GameSettings.new()
	loaded.load_saved()
	assert_float(loaded.ui_scale).is_equal_approx(1.25, 0.001)
	assert_bool(loaded.reduced_motion).is_true()
	assert_int(loaded.binding(&"board_pause", GameSettings.Device.KEYBOARD)).is_equal(KEY_F10)

	_fresh().save() # leave no state behind for the next test


func test_a_saved_scale_outside_the_range_is_clamped_on_load() -> void:
	# A settings file is user-editable and outlives its build; a hand-typed 900%
	# must not make the UI unusable with no way back to the menu that fixes it.
	var cfg := ConfigFile.new()
	cfg.set_value("display", "ui_scale", 9.0)
	cfg.save(GameSettings.PATH)

	var loaded := GameSettings.new()
	loaded.load_saved()
	assert_float(loaded.ui_scale).is_less_equal(GameSettings.UI_SCALE_MAX)

	_fresh().save()


func test_a_binding_for_an_action_that_no_longer_exists_is_dropped() -> void:
	# ★ A settings file outlives the build that wrote it. A renamed or removed
	# action would otherwise resurrect as a dead row the player cannot clear.
	var cfg := ConfigFile.new()
	cfg.set_value("bindings", "board_action_that_was_deleted.0", KEY_F11)
	cfg.save(GameSettings.PATH)

	var loaded := GameSettings.new()
	loaded.load_saved()
	assert_bool(loaded.has_overrides()).override_failure_message(
		"a binding for a nonexistent action must not survive load"
	).is_false()

	_fresh().save()


func test_a_missing_settings_file_is_a_first_run_not_an_error() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	var loaded := GameSettings.new()
	loaded.load_saved()
	assert_float(loaded.ui_scale).is_equal_approx(GameSettings.UI_SCALE_DEFAULT, 0.001)
	assert_bool(loaded.reduced_motion).is_false()


# ==============================================================================
# Guard: every shipped binding is a REAL input.
# ==============================================================================

func test_every_shipped_keyboard_binding_resolves_to_a_named_key() -> void:
	# ★ This exists because End Turn shipped bound to keycode 16777218 — Godot 3's
	# KEY_TAB. Godot 4's is 4194306. The binding was not Tab, it was not anything,
	# and nothing noticed: the InputMap accepted it, the tests asserted the LEGEND
	# TEXT rather than the binding, and it took rendering the settings screen to see
	# "Ctrl+" where "Tab" belonged.
	#
	# A keycode that names no key is unpressable, so this asserts every shipped
	# binding round-trips through OS.get_keycode_string() to a real name.
	var s := _fresh()
	for action: StringName in GameSettings.REBINDABLE:
		var code: int = s.binding(action, GameSettings.Device.KEYBOARD)
		if code < 0:
			continue # legitimately unbound on this device
		var name: String = OS.get_keycode_string(code)
		assert_str(name).override_failure_message(
			"%s is bound to keycode %d, which names no key — it cannot be pressed"
				% [action, code]
		).is_not_empty()
		# A bare modifier name means the code carried modifier bits instead of being
		# a key — the exact shape of the Godot 3 keycode bug.
		assert_bool(name in ["Ctrl+", "Shift+", "Alt+", "Meta+"]).override_failure_message(
			"%s resolves to %s — the keycode is carrying modifier bits, not a key"
				% [action, name]
		).is_false()


func test_every_rebindable_action_actually_exists_in_the_input_map() -> void:
	# A typo in REBINDABLE would render a settings row that binds nothing.
	for action: StringName in GameSettings.REBINDABLE:
		assert_bool(InputMap.has_action(action)).override_failure_message(
			"%s is listed as rebindable but is not in the InputMap" % action
		).is_true()
		assert_bool(GameSettings.ACTION_LABELS.has(action)).override_failure_message(
			"%s has no player-facing label — the settings row would show its code name" % action
		).is_true()


# ==============================================================================
# A failed save is reported, not swallowed (review finding B-1).
# ==============================================================================

func test_save_returns_an_error_the_caller_can_act_on() -> void:
	# ★ `/ux-review` flagged this as blocking: all four call sites in the settings
	# screen discarded save()'s Error, so a read-only or full user:// lost the
	# player's settings SILENTLY — they would rebind a control, watch the table
	# update, and find it reverted next launch with nothing having said why.
	# Persistence is the screen's whole purpose; failing at it quietly is the worst
	# available failure. This pins the contract the screen now depends on.
	var s := _fresh()
	assert_int(s.save()).is_equal(OK)

	# A path that cannot be written must report it rather than returning OK.
	var original: String = GameSettings.PATH
	var bad := ConfigFile.new()
	bad.set_value("display", "ui_scale", 1.0)
	var err: Error = bad.save("user://a/deliberately/missing/dir/settings.cfg")
	assert_int(err).override_failure_message(
		"ConfigFile.save must report failure for an unwritable path — the screen's " +
		"error surfacing depends on a non-OK return"
	).is_not_equal(OK)
	assert_str(original).is_equal(GameSettings.PATH) # unchanged by this test


# ==============================================================================
# Per-binding reset (settings.md OQ-2).
# ==============================================================================

func test_clearing_one_binding_leaves_every_other_customisation_alone() -> void:
	# ★ The whole point. Reset to Defaults was the only revert, so a player who
	# mis-bound ONE control had to discard every other change they had made to fix
	# it — an all-or-nothing undo for a per-row mistake.
	var s := _fresh()
	var act_default: int = s.binding(&"board_act", GameSettings.Device.KEYBOARD)
	s.set_binding(&"board_act", GameSettings.Device.KEYBOARD, KEY_F1)
	s.set_binding(&"board_build", GameSettings.Device.KEYBOARD, KEY_F2)
	s.set_binding(&"board_pause", GameSettings.Device.GAMEPAD, 11)

	s.clear_binding(&"board_act", GameSettings.Device.KEYBOARD)

	assert_int(s.binding(&"board_act", GameSettings.Device.KEYBOARD)).is_equal(act_default)
	assert_int(s.binding(&"board_build", GameSettings.Device.KEYBOARD)).override_failure_message(
		"clearing one binding must not disturb another"
	).is_equal(KEY_F2)
	assert_int(s.binding(&"board_pause", GameSettings.Device.GAMEPAD)).is_equal(11)


func test_clearing_one_device_leaves_the_other_device_alone() -> void:
	# Per-CELL, not per-row: a player who mis-binds their gamepad must not lose the
	# keyboard binding for the same action, or it is the same bug at smaller scale.
	var s := _fresh()
	s.set_binding(&"board_build", GameSettings.Device.KEYBOARD, KEY_F3)
	s.set_binding(&"board_build", GameSettings.Device.GAMEPAD, 11)

	s.clear_binding(&"board_build", GameSettings.Device.GAMEPAD)

	assert_int(s.binding(&"board_build", GameSettings.Device.KEYBOARD)).is_equal(KEY_F3)
	assert_bool(s.is_overridden(&"board_build", GameSettings.Device.GAMEPAD)).is_false()


func test_is_overridden_tracks_a_binding_through_change_and_reset() -> void:
	var s := _fresh()
	assert_bool(s.is_overridden(&"board_pause", GameSettings.Device.KEYBOARD)).is_false()
	s.set_binding(&"board_pause", GameSettings.Device.KEYBOARD, KEY_F4)
	assert_bool(s.is_overridden(&"board_pause", GameSettings.Device.KEYBOARD)).is_true()
	s.clear_binding(&"board_pause", GameSettings.Device.KEYBOARD)
	assert_bool(s.is_overridden(&"board_pause", GameSettings.Device.KEYBOARD)).is_false()


func test_clearing_the_last_override_leaves_no_trace_in_the_saved_file() -> void:
	# ★ Otherwise a player who changes a binding and changes it back still has a
	# settings file pinning that action to today's default forever, and would never
	# receive a future change to the shipped control scheme.
	var s := _fresh()
	s.set_binding(&"board_act", GameSettings.Device.KEYBOARD, KEY_F5)
	assert_bool(s.has_overrides()).is_true()
	s.clear_binding(&"board_act", GameSettings.Device.KEYBOARD)
	assert_bool(s.has_overrides()).override_failure_message(
		"clearing the last override must leave the settings file mentioning nothing"
	).is_false()

	assert_int(s.save()).is_equal(OK)
	var loaded := GameSettings.new()
	loaded.load_saved()
	assert_bool(loaded.has_overrides()).is_false()
	_fresh().save()


func test_clearing_an_unmodified_binding_is_a_harmless_no_op() -> void:
	# So the caller never has to check first, and a stray Delete does nothing.
	var s := _fresh()
	var before: int = s.binding(&"board_produce", GameSettings.Device.KEYBOARD)
	s.clear_binding(&"board_produce", GameSettings.Device.KEYBOARD)
	assert_int(s.binding(&"board_produce", GameSettings.Device.KEYBOARD)).is_equal(before)
	assert_bool(s.has_overrides()).is_false()
