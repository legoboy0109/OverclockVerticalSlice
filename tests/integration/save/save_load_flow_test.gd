# Save/load end to end through the real match scene, and the Save/Load slot screen.
# Runs against the test save folder (SaveGame.dir()), never the player's saves.
extends GdUnitTestSuite


func before_test() -> void:
	_clear()


func after_test() -> void:
	_clear()
	SaveGame.pending = null
	get_tree().paused = false


func _clear() -> void:
	SaveGame.delete(SaveGame.AUTOSAVE)
	for slot: String in SaveGame.MANUAL_SLOTS:
		SaveGame.delete(slot)


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


func _differences(a: GameState, b: GameState) -> bool:
	return JSON.stringify(SaveGame._encode_object(a)) != JSON.stringify(SaveGame._encode_object(b))


# --- The match scene ---------------------------------------------------------------------------

func test_a_new_match_autosaves_on_the_players_first_turn() -> void:
	var root: VerticalSliceRoot = await _make_root()
	for i: int in 30:   # an AI-first opening hands back after its (paced) turn
		if not root.state().per_player[root.state().active_player].is_ai_controlled:
			break
		await get_tree().create_timer(0.2).timeout
	assert_bool(SaveGame.exists(SaveGame.AUTOSAVE)).override_failure_message(
		"The player's turn began but no autosave was written.").is_true()


func test_a_pending_save_is_resumed_instead_of_a_new_match() -> void:
	# Arrange: a match that has moved on from the opening, saved to a slot.
	var map: MapDefinition = load("res://data/maps/crossroads.tres")
	VSMap.select(map)
	var saved: GameState = MatchSetup.build(map,
		[Factions.HOLY_COSMIC_EMPIRE, Factions.SOLAR_FEDERATION] as Array[FactionDef], 0, 120, [1])
	saved.per_player[0].current_credits = 4321
	saved.round_number = 7
	Balance.apply_match(30)
	SaveGame.write("slot1", saved)
	Balance.reset()
	# Act: the menu's path — read, hand over, open the match scene.
	SaveGame.pending = SaveGame.read("slot1")
	var root: VerticalSliceRoot = await _make_root()
	# Assert: it is THAT match, on THAT map, with THAT AP budget — and the hand-over was consumed.
	assert_int(root.state().per_player[0].current_credits).is_equal(4321)
	assert_int(root.state().round_number).is_equal(7)
	assert_object(root.state().per_player[0].faction).is_same(Factions.HOLY_COSMIC_EMPIRE)
	assert_object(VSMap.data()).is_same(map)
	assert_int(Balance.economy.flat_ap_per_turn).is_equal(30)
	assert_object(SaveGame.pending).is_null()
	# And Restart would replay this matchup, not the setup screen's last choice.
	assert_object(MatchSettings.current.map).is_same(map)
	assert_object(MatchSettings.current.factions[1]).is_same(Factions.SOLAR_FEDERATION)


func test_save_to_slot_writes_the_live_match() -> void:
	var root: VerticalSliceRoot = await _make_root()
	root.save_to_slot("slot3")
	var loaded := SaveGame.read("slot3")
	assert_object(loaded).is_not_null()
	assert_bool(_differences(loaded.state, root.state())).is_false()


func test_a_finished_match_leaves_no_autosave_to_continue() -> void:
	var root: VerticalSliceRoot = await _make_root()
	SaveGame.write(SaveGame.AUTOSAVE, root.state())
	root.state().match_status = GameState.MatchStatus.GAME_OVER
	root._autosave()
	assert_bool(SaveGame.exists(SaveGame.AUTOSAVE)).is_false()


# --- The slot screen ---------------------------------------------------------------------------

func _panel(mode: int) -> SaveSlotsPanel:
	var p: SaveSlotsPanel = auto_free(SaveSlotsPanel.create(mode))
	add_child(p)
	await get_tree().process_frame
	return p


func test_the_load_screen_lists_the_autosave_and_every_slot() -> void:
	var p: SaveSlotsPanel = await _panel(SaveSlotsPanel.Mode.LOAD)
	assert_int(p.row_labels().size()).is_equal(1 + SaveGame.MANUAL_SLOTS.size())
	assert_str(p.row_labels()[0]).starts_with("Autosave")
	assert_array(p.row_enabled()).override_failure_message("Empty slots cannot be loaded") \
		.is_equal([false, false, false, false])


func test_the_save_screen_offers_only_manual_slots() -> void:
	var p: SaveSlotsPanel = await _panel(SaveSlotsPanel.Mode.SAVE)
	assert_int(p.row_labels().size()).is_equal(SaveGame.MANUAL_SLOTS.size())
	assert_str("|".join(p.row_labels())).not_contains("Autosave")


func test_saving_over_a_used_slot_needs_a_second_press() -> void:
	var map: MapDefinition = load("res://data/maps/vertical_slice.tres")
	VSMap.select(map)
	SaveGame.write("slot1", MatchSetup.build(map,
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80, [1]))
	var p: SaveSlotsPanel = await _panel(SaveSlotsPanel.Mode.SAVE)
	var chosen: Array[String] = []
	p.slot_chosen.connect(func(slot: String) -> void: chosen.append(slot))
	p.press("slot1")
	assert_array(chosen).override_failure_message("One press must not overwrite a save").is_empty()
	assert_str(p.row_labels()[0]).contains("Press again")
	p.press("slot1")
	assert_array(chosen).is_equal(["slot1"])


func test_a_used_slot_shows_what_is_in_it() -> void:
	var map: MapDefinition = load("res://data/maps/highlands.tres")
	VSMap.select(map)
	SaveGame.write("slot2", MatchSetup.build(map,
		[Factions.INDEPENDENTS, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 160, [1]))
	var p: SaveSlotsPanel = await _panel(SaveSlotsPanel.Mode.LOAD)
	var row: String = p.row_labels()[2]
	assert_str(row).starts_with("Slot 2")
	assert_str(row).contains("Highlands")
	assert_str(row).contains("Independents")
	assert_bool(p.row_enabled()[2]).is_true()
