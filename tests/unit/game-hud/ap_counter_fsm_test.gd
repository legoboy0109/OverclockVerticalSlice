# Story 003: ApCounterFsm — 4-State AP Counter Animation Core (Headless).
#
# Covers production/epics/game-hud/story-003-ap-counter-fsm.md
# (TR-hud-005/006/007/008-consumption, ADR-0016 §2/§3):
#
#   AC-3a: TURN_START_FILL -> FILL_FLOURISH (the start-of-turn fill trigger).
#   AC-4:  a preview open/close (hover/cancel/select with no commit) never
#          animates the committed value (never TICK_DOWN / FILL_FLOURISH).
#   AC-5a: COMMIT_SPEND -> TICK_DOWN (the committed value steps down).
#   AC-25: no active preview -> plain COMMITTED, no leftover PREVIEW_ECHO.
#   TR-hud-006: TURN_TRANSITION force-clears PREVIEW_ECHO to COMMITTED BEFORE any
#          fill — a transition alone never yields FILL_FLOURISH (that is a
#          separate TURN_START_FILL call).
#   TR-hud-007: GAME_OVER -> COMMITTED with snaps_to_final == true (an in-flight
#          TICK_DOWN snaps to final); opponent AP never reaches PREVIEW_ECHO.
#   AC (totality): the full State x Trigger cross-product returns the ADR-0016 §2
#          target, for both local and opponent contexts.
#
# Deterministic pure-function tests: no scene tree, no RNG, no time, no I/O.
extends GdUnitTestSuite


const _ALL_STATES: Array[ApCounterFsm.State] = [
	ApCounterFsm.State.COMMITTED,
	ApCounterFsm.State.FILL_FLOURISH,
	ApCounterFsm.State.TICK_DOWN,
	ApCounterFsm.State.PREVIEW_ECHO,
]


# ==============================================================================
# AC (totality): exhaustive State x Trigger table, local player.
# ==============================================================================

func test_next_state_full_table_local_player() -> void:
	# Every trigger maps to a fixed target regardless of `current` (the counter
	# animates on the EVENT, not on where it was) — ADR-0016 §2.
	var expected := {
		ApCounterFsm.Trigger.TURN_START_FILL: ApCounterFsm.State.FILL_FLOURISH,
		ApCounterFsm.Trigger.COMMIT_SPEND: ApCounterFsm.State.TICK_DOWN,
		ApCounterFsm.Trigger.PREVIEW_OPEN: ApCounterFsm.State.PREVIEW_ECHO,
		ApCounterFsm.Trigger.PREVIEW_CLOSE: ApCounterFsm.State.COMMITTED,
		ApCounterFsm.Trigger.TURN_TRANSITION: ApCounterFsm.State.COMMITTED,
		ApCounterFsm.Trigger.GAME_OVER: ApCounterFsm.State.COMMITTED,
	}
	for current: int in _ALL_STATES:
		for trigger: int in expected.keys():
			assert_int(ApCounterFsm.next_state(current, trigger)).override_failure_message(
				"next_state(state=%d, trigger=%d) mismatch" % [current, trigger]
			).is_equal(expected[trigger])


# ==============================================================================
# AC (totality): opponent context — PREVIEW triggers refused, echo unreachable.
# ==============================================================================

func test_next_state_full_table_opponent_context() -> void:
	for current: int in _ALL_STATES:
		# PREVIEW_OPEN / PREVIEW_CLOSE are no-ops over opponent AP: stay in current.
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.PREVIEW_OPEN, true)).is_equal(current)
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.PREVIEW_CLOSE, true)).is_equal(current)
		# Non-preview triggers behave identically to the local table.
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.TURN_START_FILL, true)).is_equal(ApCounterFsm.State.FILL_FLOURISH)
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.COMMIT_SPEND, true)).is_equal(ApCounterFsm.State.TICK_DOWN)
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.TURN_TRANSITION, true)).is_equal(ApCounterFsm.State.COMMITTED)
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.GAME_OVER, true)).is_equal(ApCounterFsm.State.COMMITTED)


func test_opponent_context_never_reaches_preview_echo() -> void:
	# AC-6: PREVIEW_ECHO is structurally unreachable over opponent AP — no
	# (state, trigger) pair with is_opponent=true ever produces it.
	var all_triggers: Array = [
		ApCounterFsm.Trigger.TURN_START_FILL, ApCounterFsm.Trigger.COMMIT_SPEND,
		ApCounterFsm.Trigger.PREVIEW_OPEN, ApCounterFsm.Trigger.PREVIEW_CLOSE,
		ApCounterFsm.Trigger.TURN_TRANSITION, ApCounterFsm.Trigger.GAME_OVER,
	]
	for current: int in _ALL_STATES:
		if current == ApCounterFsm.State.PREVIEW_ECHO:
			continue # an opponent counter can never START in PREVIEW_ECHO (unreachable).
		for trigger: int in all_triggers:
			assert_int(ApCounterFsm.next_state(current, trigger, true)).override_failure_message(
				"opponent next_state(state=%d, trigger=%d) reached PREVIEW_ECHO" % [current, trigger]
			).is_not_equal(ApCounterFsm.State.PREVIEW_ECHO)


func test_is_reachable_for_opponent() -> void:
	assert_bool(ApCounterFsm.is_reachable_for_opponent(ApCounterFsm.State.COMMITTED)).is_true()
	assert_bool(ApCounterFsm.is_reachable_for_opponent(ApCounterFsm.State.FILL_FLOURISH)).is_true()
	assert_bool(ApCounterFsm.is_reachable_for_opponent(ApCounterFsm.State.TICK_DOWN)).is_true()
	assert_bool(ApCounterFsm.is_reachable_for_opponent(ApCounterFsm.State.PREVIEW_ECHO)).is_false()


# ==============================================================================
# AC-3a: fill-flourish trigger.
# ==============================================================================

func test_turn_start_fill_enters_fill_flourish() -> void:
	assert_int(ApCounterFsm.next_state(ApCounterFsm.State.COMMITTED, ApCounterFsm.Trigger.TURN_START_FILL)) \
		.is_equal(ApCounterFsm.State.FILL_FLOURISH)


# ==============================================================================
# AC-4: the committed value does not animate on preview (no-commit) events.
# ==============================================================================

func test_preview_events_never_animate_the_committed_value() -> void:
	# A preview open/close reflects a projection change (the → echo), never a
	# committed-value animation. So no PREVIEW trigger may yield TICK_DOWN
	# (commit step) or FILL_FLOURISH (turn fill) — the two committed-animating
	# states.
	for current: int in _ALL_STATES:
		var opened: ApCounterFsm.State = ApCounterFsm.next_state(current, ApCounterFsm.Trigger.PREVIEW_OPEN)
		var closed: ApCounterFsm.State = ApCounterFsm.next_state(current, ApCounterFsm.Trigger.PREVIEW_CLOSE)
		assert_bool(opened == ApCounterFsm.State.TICK_DOWN or opened == ApCounterFsm.State.FILL_FLOURISH).is_false()
		assert_bool(closed == ApCounterFsm.State.TICK_DOWN or closed == ApCounterFsm.State.FILL_FLOURISH).is_false()


# ==============================================================================
# AC-5a: a real commit steps the committed value down (TICK_DOWN).
# ==============================================================================

func test_commit_spend_enters_tick_down() -> void:
	assert_int(ApCounterFsm.next_state(ApCounterFsm.State.COMMITTED, ApCounterFsm.Trigger.COMMIT_SPEND)) \
		.is_equal(ApCounterFsm.State.TICK_DOWN)
	# Serialization invariant (TR-hud-008): a second COMMIT_SPEND cannot arrive
	# mid-TICK_DOWN — the upstream input_lock (input_lock_ms >= ap_tick_duration_ms,
	# HudBalance/Story 002) guarantees the tick fully resolves first. This FSM
	# documents that invariant rather than defending against it; there is no
	# tick queue here by design.


# ==============================================================================
# AC-25: no active preview -> plain COMMITTED, no leftover echo.
# ==============================================================================

func test_closing_a_preview_leaves_plain_committed() -> void:
	# From an open echo, closing the preview returns to COMMITTED (no leftover →).
	assert_int(ApCounterFsm.next_state(ApCounterFsm.State.PREVIEW_ECHO, ApCounterFsm.Trigger.PREVIEW_CLOSE)) \
		.is_equal(ApCounterFsm.State.COMMITTED)
	# And with no preview open, a close is a harmless no-op that stays COMMITTED.
	assert_int(ApCounterFsm.next_state(ApCounterFsm.State.COMMITTED, ApCounterFsm.Trigger.PREVIEW_CLOSE)) \
		.is_equal(ApCounterFsm.State.COMMITTED)


# ==============================================================================
# TR-hud-006: turn transition force-clears the echo BEFORE any fill.
# ==============================================================================

func test_turn_transition_clears_echo_before_fill() -> void:
	# Step 1: a transition from an open echo lands on COMMITTED — NOT
	# FILL_FLOURISH. A single TURN_TRANSITION can never jump straight to a fill,
	# so the echo is always torn down first.
	var after_transition: ApCounterFsm.State = ApCounterFsm.next_state(
		ApCounterFsm.State.PREVIEW_ECHO, ApCounterFsm.Trigger.TURN_TRANSITION)
	assert_int(after_transition).is_equal(ApCounterFsm.State.COMMITTED)
	assert_int(after_transition).is_not_equal(ApCounterFsm.State.FILL_FLOURISH)

	# Step 2: the fill is a SEPARATE, subsequent trigger — evaluated only after
	# the echo is already cleared to COMMITTED.
	assert_int(ApCounterFsm.next_state(after_transition, ApCounterFsm.Trigger.TURN_START_FILL)) \
		.is_equal(ApCounterFsm.State.FILL_FLOURISH)


# ==============================================================================
# TR-hud-007: GameOver snaps an in-flight tick to final.
# ==============================================================================

func test_game_over_from_any_state_settles_committed_with_snap() -> void:
	for current: int in _ALL_STATES:
		assert_int(ApCounterFsm.next_state(current, ApCounterFsm.Trigger.GAME_OVER)) \
			.override_failure_message("GAME_OVER from state %d must settle to COMMITTED" % current) \
			.is_equal(ApCounterFsm.State.COMMITTED)
		assert_bool(ApCounterFsm.snaps_to_final(current, ApCounterFsm.Trigger.GAME_OVER)) \
			.override_failure_message("GAME_OVER must snap to final from state %d" % current) \
			.is_true()


func test_game_over_snaps_an_in_flight_tick_down() -> void:
	# The load-bearing case: a commit that also triggers GameOver truncates an
	# in-flight TICK_DOWN, snapping the committed value to its final post-spend
	# value within the transition.
	assert_int(ApCounterFsm.next_state(ApCounterFsm.State.TICK_DOWN, ApCounterFsm.Trigger.GAME_OVER)) \
		.is_equal(ApCounterFsm.State.COMMITTED)
	assert_bool(ApCounterFsm.snaps_to_final(ApCounterFsm.State.TICK_DOWN, ApCounterFsm.Trigger.GAME_OVER)).is_true()


func test_snaps_to_final_only_for_game_over() -> void:
	var non_game_over: Array = [
		ApCounterFsm.Trigger.TURN_START_FILL, ApCounterFsm.Trigger.COMMIT_SPEND,
		ApCounterFsm.Trigger.PREVIEW_OPEN, ApCounterFsm.Trigger.PREVIEW_CLOSE,
		ApCounterFsm.Trigger.TURN_TRANSITION,
	]
	for current: int in _ALL_STATES:
		for trigger: int in non_game_over:
			assert_bool(ApCounterFsm.snaps_to_final(current, trigger)) \
				.override_failure_message("snaps_to_final must be false for non-GAME_OVER trigger %d" % trigger) \
				.is_false()
