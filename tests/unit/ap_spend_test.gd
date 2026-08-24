# Story 002: AP Spend Contract — can_afford & spend.
#
# Covers the acceptance criteria in
# production/epics/ap-economy/story-002-ap-spend-contract.md against
# AP.current_ap()/AP.can_afford()/AP.spend(), using GameStateFactory for state
# setup. No RNG, no time-dependent asserts, no file I/O; each test builds its
# own isolated state (no shared mutable fixtures).
#
# Migration note (2026-08-05 AP<->Credits pivot): AP.credit() (the cancel-build
# refund) moved to Credits.credit() — its tests moved to credits_spend_test.gd
# verbatim (same expected values, new pool). The income_this_turn invariant
# test below was rewritten: income_this_turn is retired (AP is no longer
# income-driven), replaced by the pivot's static bound
# 0 <= current_ap <= flat_ap_per_turn + ap_carryover_cap (== 15 at defaults).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- spend(): basic deduction ------------------------------------------------

func test_spend_3_from_5_returns_true_and_leaves_2() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.spend(state, 0, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(2)


func test_spend_6_from_5_returns_false_and_leaves_unchanged() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.spend(state, 0, 6)
	# Assert
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(5)


# --- spend(): zero and negative edge cases ----------------------------------

func test_spend_0_returns_true_and_is_a_noop() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.spend(state, 0, 0)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(5)


func test_spend_negative_1_returns_false_and_leaves_unchanged() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.spend(state, 0, -1)
	# Assert
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(5)


# --- spend(): exact-balance edge case (no off-by-one) -----------------------

func test_spend_5_from_5_returns_true_leaves_zero_and_then_cannot_afford_1() -> void:
	# Arrange — spend to exactly zero; assert no off-by-one leaves current_ap
	# at 1 or -1.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.spend(state, 0, 5)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_bool(AP.can_afford(state, 0, 1)).is_false()


# --- spend(): per-player pool isolation + active-player gate (Rule 7) -------

func test_spend_by_active_player_a_does_not_affect_inactive_player_b_pool() -> void:
	# Arrange — Player A (0) active with 5 AP, Player B (1) inactive with 10 AP.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 5
	state.per_player[1].current_ap = 10
	# Act
	var result := AP.spend(state, 0, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(2)
	assert_int(state.per_player[1].current_ap).is_equal(10)


func test_spend_by_inactive_player_b_returns_false_and_changes_no_pool() -> void:
	# Arrange — Player A (0) active, Player B (1) inactive with 10 AP.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 5
	state.per_player[1].current_ap = 10
	# Act — B (not active) attempts to spend.
	var result := AP.spend(state, 1, 1)
	# Assert — rejected, Rule 7 active-player gate; neither pool changes.
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(5)
	assert_int(state.per_player[1].current_ap).is_equal(10)


# --- can_afford(): pure query, no mutation -----------------------------------

func test_can_afford_3_from_5_returns_true_and_does_not_mutate() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act
	var result := AP.can_afford(state, 0, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(5)


func test_can_afford_negative_1_returns_false() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 5
	# Act / Assert
	assert_bool(AP.can_afford(state, 0, -1)).is_false()


func test_can_afford_0_returns_true_the_non_negative_boundary() -> void:
	# Arrange — amount == 0 is the boundary between the negative-rejection and
	# non-negative-acceptance branches of `amount >= 0`; a 0-cost query is
	# affordable at any pool level, including 0.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 0
	# Act / Assert — 0 is affordable even at an empty pool; pure, no mutation.
	assert_bool(AP.can_afford(state, 0, 0)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)


func test_can_afford_at_zero_ap_returns_false_for_any_positive_amount() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 0
	# Act / Assert
	assert_bool(AP.can_afford(state, 0, 1)).is_false()
	assert_bool(AP.can_afford(state, 0, 5)).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(0)


# --- can_afford(): deliberately ungated on active-player --------------------

func test_can_afford_for_inactive_player_still_returns_correct_answer() -> void:
	# Arrange — Player 0 active, Player 1 inactive. can_afford must remain
	# callable for the inactive player (AI-eval / HUD use case) and answer
	# correctly for THEIR pool, not the active player's.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 5
	state.per_player[1].current_ap = 2
	# Act / Assert — inactive player 1 can afford 2 but not 3.
	assert_bool(AP.can_afford(state, 1, 2)).is_true()
	assert_bool(AP.can_afford(state, 1, 3)).is_false()
	# Pools remain untouched — pure query.
	assert_int(state.per_player[0].current_ap).is_equal(5)
	assert_int(state.per_player[1].current_ap).is_equal(2)


# --- current_ap(): thin read facade -----------------------------------------

func test_current_ap_returns_the_players_current_ap_field() -> void:
	# Arrange
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 7
	state.per_player[1].current_ap = 3
	# Act / Assert — resolves the passed player's own field, not player 0's.
	assert_int(AP.current_ap(state, 0)).is_equal(7)
	assert_int(AP.current_ap(state, 1)).is_equal(3)


# --- Invariant: 0 <= current_ap <= flat_ap_per_turn + ap_carryover_cap -----

func test_invariant_current_ap_stays_within_bounds_across_valid_spend_sequence() -> void:
	# Arrange — the pivot's static upper bound: current_ap can never exceed
	# flat_ap_per_turn + ap_carryover_cap (== 15 at EconomyConfig defaults),
	# since reset_turn() is the only writer that can raise current_ap and it
	# always caps carryover at that sum. Drive it via a real reset_turn() from
	# a large leftover so the pool starts at the actual ceiling (15), not a
	# hand-picked number.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_ap = 999  # leftover far past the cap
	AP.reset_turn(state, 0)
	var cfg: EconomyConfig = Balance.economy
	var max_ap: int = cfg.flat_ap_per_turn + cfg.ap_carryover_cap
	assert_int(state.per_player[0].current_ap).is_equal(max_ap)  # 15 at defaults

	# Act / Assert — each valid spend keeps 0 <= current_ap <= max_ap.
	assert_bool(AP.spend(state, 0, 4)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(max_ap - 4)
	assert_bool(state.per_player[0].current_ap >= 0).is_true()
	assert_bool(state.per_player[0].current_ap <= max_ap).is_true()

	assert_bool(AP.spend(state, 0, max_ap - 4)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_bool(state.per_player[0].current_ap >= 0).is_true()
	assert_bool(state.per_player[0].current_ap <= max_ap).is_true()

	# A further spend attempt is rejected — invariant still holds, unchanged.
	assert_bool(AP.spend(state, 0, 1)).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_bool(state.per_player[0].current_ap >= 0).is_true()
	assert_bool(state.per_player[0].current_ap <= max_ap).is_true()
