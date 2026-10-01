# Main menu — against design/ux/main-menu.md's Acceptance Criteria (Approved,
# /ux-review 2026-07-27) and its Standard-tier accessibility floors.
#
# The menu is the application's boot destination, so several of these assert
# properties that are invisible until someone launches the game with a pad in
# their hands: that focus starts somewhere, that traversal reaches every entry in
# the stated order, and that a keyboard-focus treatment exists and is DISTINCT
# from mouse hover.
extends GdUnitTestSuite


## Every test starts from an empty save folder (the test one — see SaveGame.dir()), so whether
## Continue/Load are live never depends on what another test left behind.
func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func _clear_saves() -> void:
	SaveGame.delete(SaveGame.AUTOSAVE)
	for slot: String in SaveGame.MANUAL_SLOTS:
		SaveGame.delete(slot)


func _write_autosave() -> void:
	var map: MapDefinition = load("res://data/maps/vertical_slice.tres")
	VSMap.select(map)
	SaveGame.write(SaveGame.AUTOSAVE, MatchSetup.build(map,
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80, [1]))


func _make_menu() -> MainMenu:
	var menu: MainMenu = auto_free(load("res://scenes/main_menu.tscn").instantiate())
	add_child(menu)
	await get_tree().process_frame
	return menu


func _entries(menu: MainMenu) -> Array[Button]:
	var out: Array[Button] = []
	for n: Node in menu.get_children():
		_collect_buttons(n, out)
	return out


func _collect_buttons(n: Node, out: Array[Button]) -> void:
	if n is Button:
		out.append(n as Button)
	for c: Node in n.get_children():
		_collect_buttons(c, out)


# ==============================================================================
# AC: the entries, in order. ★ Continue and Load Game arrived with save/load (2026-09-29);
# Campaign is still omitted rather than greyed — it was never built.
# ==============================================================================

func test_menu_offers_the_specified_entries_in_order() -> void:
	var menu: MainMenu = await _make_menu()
	assert_array(menu.entry_labels()).is_equal(["CONTINUE", "NEW SKIRMISH", "LOAD GAME", "SETTINGS", "QUIT"])


func test_no_campaign_entry() -> void:
	var menu: MainMenu = await _make_menu()
	assert_str("|".join(menu.entry_labels())).not_contains("CAMPAIGN")


func test_continue_and_load_are_inert_but_shown_with_no_saves() -> void:
	var menu: MainMenu = await _make_menu()
	assert_bool(menu.entry_interactive(MainMenu.Entry.CONTINUE)).is_false()
	assert_bool(menu.entry_interactive(MainMenu.Entry.LOAD)).is_false()


func test_an_autosave_makes_continue_live_and_focused() -> void:
	_write_autosave()
	var menu: MainMenu = await _make_menu()
	assert_bool(menu.entry_interactive(MainMenu.Entry.CONTINUE)).is_true()
	assert_bool(menu.entry_interactive(MainMenu.Entry.LOAD)).is_true()
	assert_int(menu.focused_entry()).override_failure_message(
		"A returning player with a match in progress should land on Continue").is_equal(MainMenu.Entry.CONTINUE)


func test_a_save_that_cannot_be_read_says_so_and_stays_on_the_menu() -> void:
	DirAccess.make_dir_recursive_absolute(SaveGame.dir())
	var f := FileAccess.open(SaveGame.path_for(SaveGame.AUTOSAVE), FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var menu: MainMenu = await _make_menu()
	assert_bool(menu.load_and_play(SaveGame.AUTOSAVE)).is_false()
	assert_str(menu.notice_text()).contains("could not be loaded")
	assert_object(SaveGame.pending).is_null()


# ==============================================================================
# AC: keyboard/gamepad navigation reaches every entry, starting on New Skirmish.
# ==============================================================================

func test_new_skirmish_holds_focus_on_load() -> void:
	# ★ Without this a gamepad boots into a menu it cannot move within — focus
	# traversal has nowhere to start, so no direction press does anything.
	var menu: MainMenu = await _make_menu()
	assert_int(menu.focused_entry()).override_failure_message(
		"New Skirmish must hold focus on load, or a pad cannot enter the menu at all"
	).is_equal(MainMenu.Entry.NEW_SKIRMISH)


func test_every_entry_is_interactive_now_that_settings_exists() -> void:
	# ★ Settings shipped INERT for one day, while the screen it links to did not
	# exist. SettingsScreen landed 2026-08-24, so all three entries are live and
	# main-menu.md's Settings acceptance criterion can finally pass.
	var menu: MainMenu = await _make_menu()
	# (Continue and Load depend on saves — see the tests above.)
	assert_bool(menu.entry_interactive(MainMenu.Entry.NEW_SKIRMISH)).is_true()
	assert_bool(menu.entry_interactive(MainMenu.Entry.SETTINGS)).is_true()
	assert_bool(menu.entry_interactive(MainMenu.Entry.QUIT)).is_true()


func test_keyboard_focus_is_styled_distinctly_from_mouse_hover() -> void:
	# The Three-State Focus Indicator convention. A single shared highlight would
	# tell a pad user nothing about where focus is while a mouse rests elsewhere.
	var menu: MainMenu = await _make_menu()
	var buttons: Array[Button] = _entries(menu)
	assert_int(buttons.size()).is_greater(0)
	for b: Button in buttons:
		var focus: StyleBox = b.get_theme_stylebox("focus")
		var hover: StyleBox = b.get_theme_stylebox("hover")
		assert_object(focus).is_not_null()
		assert_object(hover).is_not_null()
		# ★ 2026-10-01 (holo glass): glass boxes carry their fill/edge as metadata.
		assert_bool(focus.has_meta(&"edge") and hover.has_meta(&"edge")).is_true()
		assert_bool(focus.get_meta(&"fill") != hover.get_meta(&"fill") \
				or focus.get_meta(&"edge") != hover.get_meta(&"edge")) \
			.override_failure_message(
				"the keyboard-focus treatment must differ from mouse hover") \
			.is_true()


# ==============================================================================
# Standard-tier accessibility floors, stated numerically in the spec.
# ==============================================================================

func test_entries_meet_the_font_size_and_hit_target_floors() -> void:
	var menu: MainMenu = await _make_menu()
	for b: Button in _entries(menu):
		assert_int(b.get_theme_font_size("font_size")).override_failure_message(
			"menu text is 'critical' copy — the spec floor is 20px"
		).is_greater_equal(20)
		assert_float(b.custom_minimum_size.y).override_failure_message(
			"hit-target floor is 44x44 at 1080p"
		).is_greater_equal(44.0)


func test_entries_are_sized_for_translated_text_not_english_width() -> void:
	# The localization pass calls out ~40% expansion on "NEW SKIRMISH" as HIGH
	# PRIORITY. A button fitted to the English string clips in German.
	var menu: MainMenu = await _make_menu()
	var buttons: Array[Button] = _entries(menu)
	var font: Font = buttons[0].get_theme_font("font")
	var english: float = font.get_string_size("NEW SKIRMISH", HORIZONTAL_ALIGNMENT_LEFT,
		-1, buttons[0].get_theme_font_size("font_size")).x
	assert_float(buttons[0].custom_minimum_size.x).override_failure_message(
		"entry width must accommodate ~40%% text expansion, not the English width"
	).is_greater_equal(english * 1.4)


# ==============================================================================
# AC: Quit shows a confirm; confirming exits, cancelling returns to the menu.
# ==============================================================================

func test_quit_opens_a_confirm_prompt_rather_than_exiting_immediately() -> void:
	var menu: MainMenu = await _make_menu()
	assert_bool(menu.is_quit_confirm_open()).is_false()
	menu.open_quit_confirm()
	await get_tree().process_frame
	assert_bool(menu.is_quit_confirm_open()).is_true()


func test_cancelling_the_prompt_returns_focus_to_the_quit_entry() -> void:
	# Not to the top of the menu — silently moving the player's focus after a
	# cancel is its own small betrayal.
	var menu: MainMenu = await _make_menu()
	menu.open_quit_confirm()
	await get_tree().process_frame
	menu.close_quit_confirm()
	await get_tree().process_frame

	assert_bool(menu.is_quit_confirm_open()).is_false()
	assert_int(menu.focused_entry()).is_equal(MainMenu.Entry.QUIT)


# ==============================================================================
# Footer: the build stamp the spec keeps for playtest bug reports.
# ==============================================================================

func test_version_stamp_names_a_real_build() -> void:
	var menu: MainMenu = await _make_menu()
	assert_str(menu.version_text()).contains("build " + str(ProjectSettings.get_setting("application/config/version")))
	assert_str(menu.version_text()).not_contains("unversioned")
