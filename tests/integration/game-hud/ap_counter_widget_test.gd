# Story 004: AP Counter Widget + Opponent Muting + Preview Echo + Turn/Round Banner.
#
# Covers production/epics/game-hud/story-004-ap-counter-widget.md
# (TR-hud-005/006/007/009, ADR-0016 §2/§8) — the BLOCKING Integration value
# assertions (the advisory Visual/Feel motion quality AC-3b/5b/9b is signed off
# separately in production/qa/evidence/ap-counter-widget-evidence.md):
#
#   AC-6:  an affordable preview shows committed → CAI's projected_remaining_ap
#          (verbatim); cancel reverts to the committed value with no state change.
#   AC-7:  an unaffordable preview shows "insufficient AP", never a negative or
#          `→ negative`.
#   AC-19/28: an opponent-context counter shows the opponent's live current_ap
#          under a persistent OPPONENT label + muted treatment, at turn-start AND
#          mid-turn; it can never reach PREVIEW_ECHO.
#   AC-9a: on a turn transition the indicator reflects active_player + round, and
#          the banner's hold value == HUDConfig.turn_banner_duration_ms.
#
# Integration-type: the widgets are Control nodes, so every test add_child()s
# them (so _ready() runs + they subscribe to action_applied). Deterministic:
# no RNG, no wall-clock assertions (banner/settle timers are never awaited — the
# value is asserted immediately after the triggering event).
extends GdUnitTestSuite


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_ap_widget(reader: GameStateReader, player: int, is_opponent: bool = false, \
		config: HUDConfig = null) -> ApCounterWidget:
	var w: ApCounterWidget = auto_free(ApCounterWidget.new())
	w.bind(reader)
	w.configure(config if config != null else HUDConfig.new(), player, is_opponent)
	add_child(w)
	return w


# ==============================================================================
# AC-6: affordable preview echo shows CAI's projected_remaining_ap verbatim.
# ==============================================================================

func test_affordable_preview_shows_projected_remaining_ap_verbatim() -> void:
	# Arrange
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 0)
	assert_int(w.committed_value()).is_equal(9)

	# Act — CAI derives the projection; the widget displays it verbatim.
	var projected: int = CommandFSM.projected_remaining_ap(state, 0, 6)
	assert_int(projected).is_equal(3) # 9 - 6
	w.open_preview(projected, true)

	# Assert — echo shows 9 → 3, committed frozen.
	assert_bool(w.showing_echo()).is_true()
	assert_int(w.projected_value()).is_equal(3)
	assert_int(w.committed_value()).is_equal(9)

	# Cancel reverts to 9 with NO state change.
	w.close_preview()
	assert_bool(w.showing_echo()).is_false()
	assert_int(w.committed_value()).is_equal(9)
	assert_int(state.per_player[0].current_ap).is_equal(9) # widget never mutated state.


# ==============================================================================
# AC-7: unaffordable preview shows "insufficient AP", never a negative.
# ==============================================================================

func test_unaffordable_preview_shows_insufficient_never_negative() -> void:
	var state := _make_state(0)
	state.per_player[0].current_ap = 2
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 0)

	# Cost 6 > 2 AP — CAI's raw projection would be negative (-4); the widget
	# must NOT display it.
	var projected: int = CommandFSM.projected_remaining_ap(state, 0, 6)
	assert_int(projected).is_equal(-4)
	w.open_preview(projected, false) # affordable = false

	assert_bool(w.insufficient_ap()).is_true()
	assert_bool(w.showing_echo()).is_false() # no arrow.
	assert_int(w.committed_value()).is_equal(2) # current value still shown.
	assert_int(w.projected_value()).is_equal(-1) # sentinel — never the -4.


# ==============================================================================
# AC-19/28: opponent counter — muted, OPPONENT-labelled, live at start + mid-turn.
# ==============================================================================

func test_opponent_counter_muted_and_live_at_turn_start_and_mid_turn() -> void:
	var state := _make_state(1) # player 1 (opponent of local 0) is active.
	state.per_player[1].current_ap = 7
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 1, true) # opponent-context counter.

	# Turn-start
	assert_bool(w.opponent_label_shown()).is_true()
	assert_bool(w.is_muted()).is_true()
	assert_int(w.committed_value()).is_equal(7)

	# Mid-turn: the opponent spends 4 (7 → 3); a commit fires action_applied.
	state.per_player[1].current_ap = 3
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(3) # live mid-turn read.
	assert_bool(w.opponent_label_shown()).is_true() # persists (not only during the banner).
	assert_bool(w.is_muted()).is_true()


func test_opponent_counter_never_reaches_preview_echo() -> void:
	var state := _make_state(1)
	state.per_player[1].current_ap = 7
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 1, true)

	w.open_preview(3, true) # previews are local-only — refused over opponent AP.

	assert_bool(w.showing_echo()).is_false()
	assert_int(w.fsm_state()).is_not_equal(ApCounterFsm.State.PREVIEW_ECHO)


# ==============================================================================
# AC-9a: turn indicator + banner hold on a PlayerTurn transition.
# ==============================================================================

func test_banner_and_indicator_on_turn_transition() -> void:
	var state := _make_state(0) # local player 0 active initially.
	var reader := GameStateReader.new(state)
	var config := HUDConfig.new()
	var b: TurnBannerWidget = auto_free(TurnBannerWidget.new())
	b.bind(reader)
	b.configure(config, 0) # baseline: active 0 (bind-first sync).
	add_child(b)

	# Transition to the opponent's turn.
	state.active_player = 1
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_bool(b.banner_active()).is_true()
	assert_str(b.banner_text()).is_equal("ENEMY TURN")
	assert_int(b.banner_hold_ms()).is_equal(config.turn_banner_duration_ms) # 1000.
	assert_int(b.indicator_active_player()).is_equal(1)
	assert_int(b.indicator_round()).is_equal(1)
	assert_str(b.indicator_text()).contains("ENEMY TURN")


func test_no_banner_when_no_transition() -> void:
	# A commit that does NOT change active_player/round must not raise the banner.
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var b: TurnBannerWidget = auto_free(TurnBannerWidget.new())
	b.bind(reader)
	b.configure(HUDConfig.new(), 0)
	add_child(b)

	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, [])) # same turn.
	await get_tree().process_frame

	assert_bool(b.banner_active()).is_false()


# ==============================================================================
# TR-hud-006 / §2: turn-boundary sequencing — the fill fires ONLY at a real
# transition, routed through TURN_TRANSITION; a mid-turn AP rise does not.
# ==============================================================================

func test_local_turn_start_income_rise_flourishes() -> void:
	# During the opponent's turn the local counter sits at leftover AP; on the
	# transition BACK to the local player, income raises AP → a start fill.
	var state := _make_state(1) # opponent (1) active; local player 0 has leftovers.
	state.per_player[0].current_ap = 2
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 0)

	state.active_player = 0 # transition to the local player's turn ...
	state.per_player[0].current_ap = 8 # ... with start-of-turn income.
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(8)
	assert_int(w.fsm_state()).is_equal(ApCounterFsm.State.FILL_FLOURISH)


func test_mid_turn_ap_increase_does_not_flourish() -> void:
	# A same-turn AP rise (e.g. a Cancel-Build refund credit) must NOT be treated
	# as a start-of-turn fill — no active_player/round change, so no flourish.
	var state := _make_state(0)
	state.per_player[0].current_ap = 3
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 0)

	state.per_player[0].current_ap = 5 # refund credit, SAME turn.
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(5)
	assert_int(w.fsm_state()).is_not_equal(ApCounterFsm.State.FILL_FLOURISH)


func test_turn_transition_force_clears_open_echo_via_transition_trigger() -> void:
	# TR-hud-006: an open echo is force-cleared through TURN_TRANSITION on a turn
	# boundary — the FSM lands on COMMITTED, never a straight jump to a fill.
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var w := _make_ap_widget(reader, 0)
	w.open_preview(3, true)
	assert_int(w.fsm_state()).is_equal(ApCounterFsm.State.PREVIEW_ECHO)

	state.active_player = 1 # a transition (local AP unchanged at 9).
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_bool(w.showing_echo()).is_false()
	assert_int(w.fsm_state()).is_equal(ApCounterFsm.State.COMMITTED)


# ==============================================================================
# §2: opponent FILL_FLOURISH is gated by show_opponent_fill_flourish.
# ==============================================================================

func test_opponent_fill_flourish_gated_by_config() -> void:
	# Default (show_opponent_fill_flourish = false): the opponent's turn-start
	# income rise must NOT flourish.
	var state := _make_state(0) # local (0) active; opponent 1 has leftovers.
	state.per_player[1].current_ap = 2
	var reader := GameStateReader.new(state)
	var default_cfg := HUDConfig.new()
	assert_bool(default_cfg.show_opponent_fill_flourish).is_false()
	var muted := _make_ap_widget(reader, 1, true, default_cfg)

	state.active_player = 1
	state.per_player[1].current_ap = 8
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame
	assert_int(muted.committed_value()).is_equal(8)
	assert_int(muted.fsm_state()).is_not_equal(ApCounterFsm.State.FILL_FLOURISH)

	# With the knob on, the opponent's turn-start income DOES flourish.
	var state2 := _make_state(0)
	state2.per_player[1].current_ap = 2
	var reader2 := GameStateReader.new(state2)
	var on_cfg := HUDConfig.new()
	on_cfg.show_opponent_fill_flourish = true
	var lively := _make_ap_widget(reader2, 1, true, on_cfg)

	state2.active_player = 1
	state2.per_player[1].current_ap = 8
	state2.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame
	assert_int(lively.fsm_state()).is_equal(ApCounterFsm.State.FILL_FLOURISH)
