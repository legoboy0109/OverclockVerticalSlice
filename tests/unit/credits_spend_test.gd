# Credits Spend/Afford/Credit/Bank Contract (2026-08-05 AP<->Credits pivot).
#
# Covers Credits.current_credits()/Credits.can_afford()/Credits.spend()/
# Credits.credit()/Credits.add_income(), using GameStateFactory for state
# setup. No RNG, no time-dependent asserts, no file I/O; each test builds its
# own isolated state (no shared mutable fixtures).
#
# Migration note (2026-08-05 AP<->Credits pivot): Credits.spend/can_afford/
# current_credits are a line-for-line mirror of AP.spend/can_afford/current_ap
# (ap_spend_test.gd) re-targeted at PlayerState.current_credits — this suite
# mirrors that file's spend/afford test shapes. Credits.credit() is the pivot's
# MOVE of the pre-pivot AP.credit() cancel-build-refund tests (originally in
# ap_spend_test.gd's test_credit_* funcs) onto the Credits pool — expected
# values are unchanged, only the pool. Credits.add_income() is wholly new
# banking behavior with no pre-pivot analog: it ADDS credit_income() to the
# running current_credits balance every start-of-turn, with no cap and no
# reset (contrast AP.reset_turn(), which overwrites the flat AP pool).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

# ★ S7-06: local stand-in for the retired BaseProduction.completed_outpost_count(). The
# accessor was dead product code — nothing in src/ called it once S6-01 re-based income on
# research tiers — but the BEHAVIOUR these tests observe through it (a structure only counts
# once its build_status reaches COMPLETED) is real and still worth pinning. So the accessor
# goes and the observable stays, defined here rather than shipped.
func _completed_factory_count(state: GameState, player: int) -> int:
	var count: int = 0
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var s: StructureState = e
		if s.type == StructureTypes.FACTORY and s.build_status == StructureState.BuildStatus.COMPLETED:
			count += 1
	return count



func before_test() -> void:
	Research.reset()


# Places n alive, owned, Completed Economy Outpost StructureStates directly
# into state.entities_by_id at unique, deterministic tiles (no grid in play —
# Credits.credit_income()/_completed_factory_count() never touch
# the grid). Copied from credit_income_test.gd's fixture helper.
func _add_completed_outposts(state: GameState, player: int, n: int) -> void:
	for _i: int in n:
		var structure := StructureState.new()
		structure.entity_id = state.next_entity_id
		structure.owner = player
		structure.position = Vector2i(structure.entity_id, 0) # unique, arbitrary
		structure.type = StructureTypes.FACTORY
		structure.current_hp = structure.type.hp
		structure.build_status = StructureState.BuildStatus.COMPLETED
		structure.build_turns_remaining = 0
		state.entities_by_id[structure.entity_id] = structure
		state.next_entity_id += 1


# --- spend(): basic deduction ------------------------------------------------

func test_spend_3_from_5_returns_true_and_leaves_2() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.spend(state, 0, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(2)


func test_spend_6_from_5_returns_false_and_leaves_unchanged() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.spend(state, 0, 6)
	# Assert
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(5)


# --- spend(): zero and negative edge cases ----------------------------------

func test_spend_0_returns_true_and_is_a_noop() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.spend(state, 0, 0)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(5)


func test_spend_negative_1_returns_false_and_leaves_unchanged() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.spend(state, 0, -1)
	# Assert
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(5)


# --- spend(): per-player pool isolation + active-player gate ---------------

func test_spend_by_inactive_player_returns_false_and_changes_no_pool() -> void:
	# Arrange — Player 0 active, Player 1 inactive with its own pool.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_credits = 5
	state.per_player[1].current_credits = 10
	# Act — Player 1 (not active) attempts to spend.
	var result := Credits.spend(state, 1, 1)
	# Assert — rejected, active-player gate; neither pool changes.
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(5)
	assert_int(state.per_player[1].current_credits).is_equal(10)


# --- can_afford(): pure query, no mutation -----------------------------------

func test_can_afford_3_from_5_returns_true_and_does_not_mutate() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.can_afford(state, 0, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(5)


func test_can_afford_negative_1_returns_false() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act / Assert
	assert_bool(Credits.can_afford(state, 0, -1)).is_false()


func test_can_afford_0_returns_true_the_non_negative_boundary() -> void:
	# Arrange — amount == 0 is the boundary between the negative-rejection and
	# non-negative-acceptance branches of `amount >= 0`; a 0-cost query is
	# affordable at any pool level, including 0.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 0
	# Act / Assert — 0 is affordable even at an empty pool; pure, no mutation.
	assert_bool(Credits.can_afford(state, 0, 0)).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(0)


func test_can_afford_at_zero_credits_returns_false_for_any_positive_amount() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 0
	# Act / Assert
	assert_bool(Credits.can_afford(state, 0, 1)).is_false()
	assert_bool(Credits.can_afford(state, 0, 5)).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(0)


func test_can_afford_for_inactive_player_still_returns_correct_answer() -> void:
	# Arrange — Player 0 active, Player 1 inactive. can_afford must remain
	# callable for the inactive player (AI-eval / HUD use case) and answer
	# correctly for THEIR pool, not the active player's.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_credits = 5
	state.per_player[1].current_credits = 2
	# Act / Assert — inactive player 1 can afford 2 but not 3.
	assert_bool(Credits.can_afford(state, 1, 2)).is_true()
	assert_bool(Credits.can_afford(state, 1, 3)).is_false()
	# Pools remain untouched — pure query.
	assert_int(state.per_player[0].current_credits).is_equal(5)
	assert_int(state.per_player[1].current_credits).is_equal(2)


# --- current_credits(): thin read facade -------------------------------------

func test_current_credits_returns_the_players_current_credits_field() -> void:
	# Arrange
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_credits = 7
	state.per_player[1].current_credits = 3
	# Act / Assert — resolves the passed player's own field, not player 0's.
	assert_int(Credits.current_credits(state, 0)).is_equal(7)
	assert_int(Credits.current_credits(state, 1)).is_equal(3)


# --- credit(): additive refund path (moved from AP.credit — cancel-build refund) --

func test_credit_2_to_5_returns_true_and_leaves_7() -> void:
	# Arrange — the active player's pool at 5.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.credit(state, 0, 2)
	# Assert — additive, not overwrite.
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(7)


func test_credit_0_returns_true_and_is_a_noop() -> void:
	# Arrange — a 0-cost structure refunds nothing but the cancel still succeeds.
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.credit(state, 0, 0)
	# Assert
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(5)


func test_credit_negative_1_returns_false_and_leaves_unchanged() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 5
	# Act
	var result := Credits.credit(state, 0, -1)
	# Assert — a negative credit is rejected (no covert spend via credit).
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(5)


func test_credit_by_inactive_player_returns_false_and_changes_no_pool() -> void:
	# Arrange — Player 0 active, Player 1 inactive. credit is active-player-gated
	# like spend — this directly exercises that gate (the cancel-build call
	# site can't reach it because validate_cancel rejects non-owners first, so
	# this is the gate's only direct coverage).
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_credits = 5
	state.per_player[1].current_credits = 10
	# Act — inactive player 1 attempts to be credited.
	var result := Credits.credit(state, 1, 3)
	# Assert — rejected; neither pool changes.
	assert_bool(result).is_false()
	assert_int(state.per_player[0].current_credits).is_equal(5)
	assert_int(state.per_player[1].current_credits).is_equal(10)


func test_credit_can_raise_current_credits_above_any_prior_value() -> void:
	# Arrange — a refund is a mid-turn credit with NO upper cap: the refunded
	# Credits are spendable again this same turn, so current_credits may
	# legitimately exceed any value it held before (no snapshot ceiling exists
	# for the banked pool at all — contrast AP's carryover cap).
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].current_credits = 10
	# Act
	var result := Credits.credit(state, 0, 4)
	# Assert — 14 > the prior 10; no clamp.
	assert_bool(result).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(14)


# --- add_income(): banking — additive, no cap, no reset ---------------------

func test_add_income_adds_credit_income_to_existing_balance() -> void:
	# Arrange — a nonzero starting balance and one economy tier researched, giving
	# income above the base floor.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_credits = 6
	state.per_player[0].economy_tier = 1
	var income := Credits.credit_income(state, 0)
	# Act
	Credits.add_income(state, 0)
	# Assert — banked ADDITIVELY onto the existing balance, never a reset-to-income.
	assert_int(state.per_player[0].current_credits).is_equal(6 + income)


func test_add_income_at_tier_zero_adds_base_income() -> void:
	# ★ S6-01: income is research-tiered, not outpost-driven. At tier 0 a player
	# banks exactly base_income.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_credits = 0
	state.per_player[0].economy_tier = 0
	Credits.add_income(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(Balance.economy.base_income)


func test_add_income_called_twice_accumulates_no_reset_between_calls() -> void:
	# Arrange — two economy tiers researched.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_credits = 0
	state.per_player[0].economy_tier = 2
	var income := Credits.credit_income(state, 0)
	# Act — bank income twice in a row (simulating no discard/reset between banking).
	Credits.add_income(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(income)
	Credits.add_income(state, 0)
	# Assert — accumulates additively (2x income), never overwritten back to 1x.
	assert_int(state.per_player[0].current_credits).is_equal(income * 2)


func test_add_income_reads_correct_player_index_for_two_players_independently() -> void:
	# Guards against a parameter-threading / hardcoded-index bug: add_income
	# must bank the passed player's own income onto their own balance only.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_credits = 100
	state.per_player[1].current_credits = 0
	state.per_player[0].economy_tier = 1
	state.per_player[1].economy_tier = 3
	var income_0: int = Credits.credit_income(state, 0)
	var income_1: int = Credits.credit_income(state, 1)
	assert_int(income_0).is_not_equal(income_1)  # the two players must genuinely differ
	# Act
	Credits.add_income(state, 0)
	Credits.add_income(state, 1)
	# Assert — each player's balance reflects only their own banked income.
	assert_int(state.per_player[0].current_credits).is_equal(100 + income_0)
	assert_int(state.per_player[1].current_credits).is_equal(income_1)
