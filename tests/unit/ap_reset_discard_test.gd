# Story 003: AP reset_turn & discard — Start-of-Turn Freeze / End-of-Turn Discard.
#
# Covers the acceptance criteria in
# production/epics/ap-economy/story-003-ap-reset-discard.md against
# AP.reset_turn()/AP.discard(), using GameStateFactory for state setup and the
# BaseProduction/Research test stubs for the two forward-declared cross-system
# calls income() makes internally (ADR-0006). No RNG, no time-dependent
# asserts, no file I/O; each test resets both stubs for isolation.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	BaseProduction.reset()
	Research.reset()


# --- reset_turn(): basic frozen-snapshot write (AC1) ------------------------

func test_reset_turn_sets_income_this_turn_and_current_ap_to_income() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 0)
	# Act
	AP.reset_turn(state, 0)
	# Assert — base_income floor (n=0) is 10; both fields equal the snapshot.
	assert_int(state.per_player[0].income_this_turn).is_equal(10)
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- reset_turn(): outpost completed before reset is observed (AC2) --------

func test_reset_turn_includes_outpost_completed_before_reset() -> void:
	# Arrange — 4 completed outposts at tier1 rate: 10 + 2*4 = 18.
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)


# --- reset_turn(): outpost built (not yet completed) this turn is a no-op (AC3) --

func test_reset_turn_unaffected_by_outpost_still_under_construction() -> void:
	# Arrange — an outpost "under construction" this turn does not increment
	# the stubbed completed count (the stub IS the completed-count contract;
	# an incomplete outpost simply never calls set_completed_outpost_count).
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 0)
	# Act
	AP.reset_turn(state, 0)
	# Assert — still base_income only, no partial credit for the in-progress build.
	assert_int(state.per_player[0].income_this_turn).is_equal(10)
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- Frozen-immune-to-increase (AC4, increase direction) --------------------

func test_income_this_turn_frozen_at_18_unaffected_by_mid_turn_outpost_completion() -> void:
	# Arrange — freeze at n=4 (18), then flip the stub up to n=5 mid-turn.
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act — an outpost completes mid-turn (simulated by flipping the stub).
	BaseProduction.set_completed_outpost_count(0, 5)
	# Assert — frozen snapshot still reads 18 until the NEXT reset_turn.
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)


# --- Frozen-immune-to-decrease (AC4, decrease direction) --------------------

func test_income_this_turn_frozen_at_18_unaffected_by_mid_turn_outpost_destruction() -> void:
	# Arrange — freeze at n=4 (18), then flip the stub down to n=3 (opponent's
	# turn destroys one of this player's outposts).
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act — an outpost is destroyed during the opponent's turn.
	BaseProduction.set_completed_outpost_count(0, 3)
	# Assert — frozen snapshot still reads 18 until this player's NEXT reset_turn.
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)


# --- discard(): hard write to exactly 0 (AC5) -------------------------------

func test_discard_sets_current_ap_to_exactly_zero() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 4
	# Act
	AP.discard(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(0)


func test_discard_result_stays_zero_through_opponents_turn_until_next_reset() -> void:
	# Arrange — Player 0 ends their turn with 4 unspent AP.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 4
	# Act — discard, then simulate the opponent's turn passing (no reset for
	# player 0 in between — nothing should touch player 0's pool).
	AP.discard(state, 0)
	state.active_player = 1
	state.per_player[1].current_ap = 7  # opponent's own pool moves independently
	# Assert — player 0's pool is still exactly 0, untouched by the opponent's turn.
	assert_int(state.per_player[0].current_ap).is_equal(0)


# --- No banking: next reset starts at income, never income + leftover (AC6) ---

func test_reset_turn_after_discard_starts_at_income_never_income_plus_leftover() -> void:
	# Arrange — player ends turn with 4 unspent AP, income_this_turn was 10.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].income_this_turn = 10
	state.per_player[0].current_ap = 4
	BaseProduction.set_completed_outpost_count(0, 0)
	# Act — end-of-turn discard, then next turn's reset.
	AP.discard(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(0)
	AP.reset_turn(state, 0)
	# Assert — starts at income (10) exactly, never 10 + 4 leftover (14).
	assert_int(state.per_player[0].income_this_turn).is_equal(10)
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- Double reset_turn in the same turn: last-write-wins, no accumulation (AC7) --

func test_reset_turn_called_twice_same_turn_overwrites_last_write_wins() -> void:
	# Arrange — first freeze at n=4 (18).
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)
	# Act — an outpost completes (n=4 -> n=7), then reset_turn runs again with
	# no intervening discard.
	BaseProduction.set_completed_outpost_count(0, 7)
	AP.reset_turn(state, 0)
	# Assert — overwritten to the fresh total (10 + tier1(2*4) + tier2(1*3) = 21),
	# NOT accumulated with the first snapshot (18 + 21 = 39) and not additive.
	assert_int(state.per_player[0].income_this_turn).is_equal(21)
	assert_int(state.per_player[0].current_ap).is_equal(21)


func test_reset_turn_called_twice_same_turn_matches_story_worked_example_18_to_24() -> void:
	# Arrange — mirrors the story's own worked example: first call freezes 18
	# (n=4), several outposts then complete (n=10), second call overwrites to
	# 24 (10 + tier1(2*4) + tier2(1*6) = 24), not 42 (18+24, the accumulation
	# the AC explicitly forbids).
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act
	BaseProduction.set_completed_outpost_count(0, 10)
	AP.reset_turn(state, 0)
	# Assert — last-write-wins overwrite, not 18+24=42.
	assert_int(state.per_player[0].income_this_turn).is_equal(24)
	assert_int(state.per_player[0].current_ap).is_equal(24)


# --- discard(): idempotent no-op on a player already at 0 (coverage hardening) ---

func test_discard_on_already_zero_player_stays_exactly_zero() -> void:
	# Arrange — player already has 0 AP (e.g. discard already ran this boundary,
	# or nothing ever accrued). A second discard must be a harmless no-op.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 0
	# Act
	AP.discard(state, 0)
	# Assert — still exactly 0, no underflow, no side effect.
	assert_int(state.per_player[0].current_ap).is_equal(0)


# --- reset_turn(): a real interposed spend() does not survive the next reset (AC7 hardening) ---

func test_reset_turn_after_interposed_spend_snaps_current_ap_back_to_income() -> void:
	# Arrange — freeze at n=4 (18), then the ACTIVE player actually spends 5 AP
	# mid-turn via spend() (not just a raw field poke), leaving current_ap=13
	# while income_this_turn stays 18.
	var state := GameStateFactory.make_state(1, 0)
	BaseProduction.set_completed_outpost_count(0, 4)
	AP.reset_turn(state, 0)
	assert_bool(AP.spend(state, 0, 5)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(13)   # 18 - 5, partial-spend state
	# Act — reset_turn runs again (income unchanged) with the spend interposed.
	AP.reset_turn(state, 0)
	# Assert — current_ap snaps back UP to the full frozen income; no partial
	# spend survives the reset (proves reset_turn unconditionally overwrites
	# current_ap, not just income_this_turn).
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)
