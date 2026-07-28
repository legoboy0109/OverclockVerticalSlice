# Story 006: Detail Panel (selection/inspection seam) + Victory/Defeat one-frame
# preemption.
#
# Covers production/epics/game-hud/story-006-detail-panel-gameover-precedence.md
# (TR-hud-013/016/004/017, ADR-0016 §6/§8):
#
#   AC-13: the detail panel follows CAI's selection_changed — shows the target's
#     stats (pinned solid vs peek dimmed), empty when nothing selected, and
#     CLEARS when the shown entity is destroyed (not stale).
#   AC-17: on match_status = GameOver(winner) the victory/defeat overlay shows
#     (naming the winner) within one frame, and any in-flight turn banner is
#     preempted (not visible on the next frame). Cross-ref: the same transition
#     snaps the AP counter to its final post-spend value (Story 003/004).
#   Leaf claim: the panel SUBSCRIBES to CommandInterface.selection_changed —
#     one-way; CAI never calls into a HUD node.
#
# Integration-type: Control nodes are add_child()'d so they subscribe. The
# banner/overlay/counter all react to the SAME action_applied, so "one frame" is
# asserted after a single process_frame. Deterministic — no wall-clock waits.
extends GdUnitTestSuite


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _unit_type(hp: int = 10) -> UnitTypeDef:
	var t := UnitTypeDef.new()
	t.display_name = "TestUnit"
	t.hp = hp
	t.attack = 3
	t.attack_range = 1
	t.move_cost = 1
	t.produce_cost = 4
	return t


func _place_unit(state: GameState, entity_id: int, hp: int = 10) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = 0
	u.position = Vector2i(1, 1)
	u.type = _unit_type(hp)
	u.current_hp = hp
	state.entities_by_id[entity_id] = u
	return u


func _emit_commit(state: GameState) -> void:
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))


func _make_panel(reader: GameStateReader, cmd: CommandInterface) -> DetailPanelWidget:
	var panel: DetailPanelWidget = auto_free(DetailPanelWidget.new())
	panel.bind(reader)
	panel.attach_interface(cmd)
	add_child(panel)
	return panel


# ==============================================================================
# AC-13: detail panel follows selection_changed (pinned / peek / empty / clear).
# ==============================================================================

func test_panel_shows_pinned_selection_stats() -> void:
	var state := _make_state()
	_place_unit(state, 5, 10)
	var reader := GameStateReader.new(state)
	var cmd: CommandInterface = auto_free(CommandInterface.new())
	var panel := _make_panel(reader, cmd)

	cmd.selection_changed.emit(SelectionTarget.new(5, true)) # pinned selection.

	assert_bool(panel.is_showing()).is_true()
	assert_int(panel.shown_entity_id()).is_equal(5)
	assert_bool(panel.is_pinned()).is_true()
	assert_bool(panel.panel_info().is_empty()).is_false()
	assert_int(panel.panel_info()["current_hp"]).is_equal(10)


func test_panel_peek_then_empty() -> void:
	var state := _make_state()
	_place_unit(state, 7, 10)
	var reader := GameStateReader.new(state)
	var cmd: CommandInterface = auto_free(CommandInterface.new())
	var panel := _make_panel(reader, cmd)

	cmd.selection_changed.emit(SelectionTarget.new(7, false)) # peek (transient).
	assert_bool(panel.is_showing()).is_true()
	assert_bool(panel.is_pinned()).is_false() # peek, not pinned.

	cmd.selection_changed.emit(SelectionTarget.new(-1, false)) # nothing selected.
	assert_bool(panel.is_showing()).is_false()
	assert_bool(panel.panel_info().is_empty()).is_true()


func test_panel_clears_when_shown_entity_destroyed() -> void:
	var state := _make_state()
	_place_unit(state, 5, 10)
	var reader := GameStateReader.new(state)
	var cmd: CommandInterface = auto_free(CommandInterface.new())
	var panel := _make_panel(reader, cmd)

	cmd.selection_changed.emit(SelectionTarget.new(5, true))
	assert_bool(panel.is_showing()).is_true()

	state.entities_by_id.erase(5) # entity destroyed by a commit ...
	_emit_commit(state) # ... whose action_applied reaches the panel.
	await get_tree().process_frame

	assert_bool(panel.is_showing()).is_false() # cleared, not stale.


# ==============================================================================
# AC-17: victory/defeat overlay + one-frame banner preemption.
# ==============================================================================

func test_overlay_shows_and_names_winner_victory() -> void:
	var state := _make_state()
	var reader := GameStateReader.new(state)
	var overlay: GameOverOverlay = auto_free(GameOverOverlay.new())
	overlay.bind(reader)
	overlay.configure(0) # local player 0.
	add_child(overlay)
	assert_bool(overlay.is_showing()).is_false() # match ongoing.

	state.match_status = GameState.MatchStatus.GAME_OVER
	state.winner = 0 # local player wins.
	_emit_commit(state)
	await get_tree().process_frame

	assert_bool(overlay.is_showing()).is_true()
	assert_int(overlay.winning_player()).is_equal(0)
	assert_bool(overlay.is_local_victory()).is_true()
	assert_str(overlay.result_text()).is_equal("VICTORY")


func test_overlay_is_defeat_when_opponent_wins() -> void:
	var state := _make_state()
	var reader := GameStateReader.new(state)
	var overlay: GameOverOverlay = auto_free(GameOverOverlay.new())
	overlay.bind(reader)
	overlay.configure(0)
	add_child(overlay)

	state.match_status = GameState.MatchStatus.GAME_OVER
	state.winner = 1 # opponent wins.
	_emit_commit(state)
	await get_tree().process_frame

	assert_str(overlay.result_text()).is_equal("DEFEAT")
	assert_bool(overlay.is_local_victory()).is_false()


func test_game_over_preempts_in_flight_turn_banner_in_one_frame() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var config := HUDConfig.new()
	var banner: TurnBannerWidget = auto_free(TurnBannerWidget.new())
	banner.bind(reader)
	banner.configure(config, 0)
	add_child(banner)
	var overlay: GameOverOverlay = auto_free(GameOverOverlay.new())
	overlay.bind(reader)
	overlay.configure(0)
	add_child(overlay)

	# A turn transition raises the banner ...
	state.active_player = 1
	_emit_commit(state)
	await get_tree().process_frame
	assert_bool(banner.banner_active()).is_true()

	# ... then a GameOver-triggering commit lands: overlay shows AND the banner
	# is gone, on the same frame.
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.winner = 1
	_emit_commit(state)
	await get_tree().process_frame

	assert_bool(overlay.is_showing()).is_true()
	assert_bool(banner.banner_active()).is_false() # preempted, not persisting.


func test_game_over_snaps_ap_counter_to_final_value() -> void:
	# Cross-ref AC-17 (Story 003/004): the killing commit was mid-tick (9→3); on
	# GameOver the counter shows the final 3, not a frozen intermediate.
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var counter: ApCounterWidget = auto_free(ApCounterWidget.new())
	counter.bind(reader)
	counter.configure(HUDConfig.new(), 0)
	add_child(counter)
	assert_int(counter.committed_value()).is_equal(9)

	state.per_player[0].current_ap = 3 # spent to final ...
	state.match_status = GameState.MatchStatus.GAME_OVER # ... and the same commit ends the match.
	state.winner = 0
	_emit_commit(state)
	await get_tree().process_frame

	assert_int(counter.committed_value()).is_equal(3) # snapped to final.
	assert_int(counter.fsm_state()).is_equal(ApCounterFsm.State.COMMITTED)
