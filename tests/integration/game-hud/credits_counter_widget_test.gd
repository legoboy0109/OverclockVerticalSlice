# Phase 5 (economy pivot): Credits Counter Widget — the AP counter's co-equal,
# the banked economic war chest (CR-3d, ADR-0016 §2/§8, TR-hud-005/019).
#
# Covers the BLOCKING Logic/Integration value assertions for the Credits counter
# (the advisory Visual/Feel motion quality is signed off separately):
#
#   AC-29: a start-of-turn credit rise at a turn boundary is the income flourish
#          (FILL_FLOURISH) and reflects the ACCUMULATED pile (never a reset-to-
#          income); a mid-turn credit rise (Cancel-Build refund) does NOT flourish.
#   AC-30: an economic spend steps the committed value down (TICK_DOWN).
#   AC-31: an affordable preview shows committed -> A−C (verbatim); cancel reverts
#          to the committed value with no state change. An unaffordable preview
#          shows "insufficient credits", never a negative or `-> negative`.
#   AC-19/28: an opponent-context counter shows the opponent's live current_credits
#          under a persistent OPPONENT label + muted treatment, at turn-start AND
#          mid-turn; it can never reach PREVIEW_ECHO.
#   Pass-Through: the counter reads current_credits, NOT current_ap.
#
# Integration-type: the widget is a Control, so every test add_child()s it (so
# _ready() runs + it subscribes to action_applied). Deterministic: no RNG, no
# wall-clock assertions (settle timers are never awaited — the value is asserted
# immediately after the triggering event).
extends GdUnitTestSuite


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_credits_widget(reader: GameStateReader, player: int, is_opponent: bool = false, \
		config: HUDConfig = null) -> CreditsCounterWidget:
	var w: CreditsCounterWidget = auto_free(CreditsCounterWidget.new())
	w.bind(reader)
	w.configure(config if config != null else HUDConfig.new(), player, is_opponent)
	add_child(w)
	return w


# ==============================================================================
# Pass-Through: the Credits counter reads current_credits, never current_ap.
# ==============================================================================

func test_reads_credits_pool_not_ap() -> void:
	var state := _make_state(0)
	state.per_player[0].current_ap = 3       # tactical pool ...
	state.per_player[0].current_credits = 21 # ... distinct from the war chest.
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)

	assert_int(w.committed_value()).is_equal(21) # shows Credits, not the AP 3.


# ==============================================================================
# AC-31: affordable preview echo shows A -> A−C for an economic action.
# ==============================================================================

func test_affordable_preview_shows_projected_credits_verbatim() -> void:
	var state := _make_state(0)
	state.per_player[0].current_credits = 21
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)
	assert_int(w.committed_value()).is_equal(21)

	# CAI derives the projection (21 − 8 = 13); the widget displays it verbatim.
	w.open_preview(13, true)

	assert_bool(w.showing_echo()).is_true()
	assert_int(w.projected_value()).is_equal(13)
	assert_int(w.committed_value()).is_equal(21) # committed frozen during preview.

	# Cancel reverts to 21 with NO state change.
	w.close_preview()
	assert_bool(w.showing_echo()).is_false()
	assert_int(w.committed_value()).is_equal(21)
	assert_int(state.per_player[0].current_credits).is_equal(21) # never mutated state.


# ==============================================================================
# AC-31 (cont.): unaffordable preview shows "insufficient credits", never negative.
# ==============================================================================

func test_unaffordable_preview_shows_insufficient_never_negative() -> void:
	var state := _make_state(0)
	state.per_player[0].current_credits = 2
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)

	# Cost 8 > 2 Credits — CAI's raw projection would be negative (−6); the widget
	# must NOT display it.
	w.open_preview(-6, false) # affordable = false

	assert_bool(w.insufficient_credits()).is_true()
	assert_bool(w.showing_echo()).is_false()          # no arrow.
	assert_int(w.committed_value()).is_equal(2)        # current value still shown.
	assert_int(w.projected_value()).is_equal(-1)       # sentinel — never the −6.


# ==============================================================================
# AC-29: start-of-turn income ADDS to the pile (FILL_FLOURISH); the counter
# tracks the accumulating war chest, never resetting to income-only.
# ==============================================================================

func test_turn_start_income_rise_flourishes_and_accumulates() -> void:
	# Opponent (1) active; local player 0 has a banked pile of 21.
	var state := _make_state(1)
	state.per_player[0].current_credits = 21
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)
	assert_int(w.committed_value()).is_equal(21)

	# Transition BACK to the local player, income of 10 ADDED onto the pile -> 31.
	state.active_player = 0
	state.per_player[0].current_credits = 31 # engine banked 21 + 10 (never reset to 10).
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(31) # accumulated pile, not income-only.
	assert_int(w.fsm_state()).is_equal(ApCounterFsm.State.FILL_FLOURISH)


func test_mid_turn_credit_increase_does_not_flourish() -> void:
	# A same-turn credit rise (e.g. a Cancel-Build refund) must NOT be treated as a
	# start-of-turn income fill — no active_player/round change, so no flourish.
	var state := _make_state(0)
	state.per_player[0].current_credits = 5
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)

	state.per_player[0].current_credits = 13 # refund credit, SAME turn.
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(13)
	assert_int(w.fsm_state()).is_not_equal(ApCounterFsm.State.FILL_FLOURISH)


# ==============================================================================
# AC-30: an economic spend steps the committed value down (TICK_DOWN).
# ==============================================================================

func test_economic_spend_ticks_down() -> void:
	var state := _make_state(0)
	state.per_player[0].current_credits = 21
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 0)

	state.per_player[0].current_credits = 13 # spent 8 Credits on an economic action.
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(13)
	assert_int(w.fsm_state()).is_equal(ApCounterFsm.State.TICK_DOWN)


# ==============================================================================
# AC-19/28: opponent counter — muted, OPPONENT-labelled, live at start + mid-turn.
# ==============================================================================

func test_opponent_counter_muted_and_live_at_turn_start_and_mid_turn() -> void:
	var state := _make_state(1) # player 1 (opponent of local 0) is active.
	state.per_player[1].current_credits = 18
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 1, true) # opponent-context counter.

	# Turn-start
	assert_bool(w.opponent_label_shown()).is_true()
	assert_bool(w.is_muted()).is_true()
	assert_int(w.committed_value()).is_equal(18)

	# Mid-turn: the opponent spends 8 Credits (18 -> 10); a commit fires.
	state.per_player[1].current_credits = 10
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))
	await get_tree().process_frame

	assert_int(w.committed_value()).is_equal(10) # live mid-turn read.
	assert_bool(w.opponent_label_shown()).is_true() # persists (not only during the banner).
	assert_bool(w.is_muted()).is_true()


func test_opponent_counter_never_reaches_preview_echo() -> void:
	var state := _make_state(1)
	state.per_player[1].current_credits = 18
	var reader := GameStateReader.new(state)
	var w := _make_credits_widget(reader, 1, true)

	w.open_preview(10, true) # previews are local-only — refused over opponent Credits.

	assert_bool(w.showing_echo()).is_false()
	assert_int(w.fsm_state()).is_not_equal(ApCounterFsm.State.PREVIEW_ECHO)
