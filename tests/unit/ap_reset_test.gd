# Story 003: AP reset_turn — flat budget + capped carryover (2026-08-05 pivot).
#
# Covers AP.reset_turn() under the AP<->Credits pivot (ADR-0006): AP is no
# longer income-driven and no longer discarded at end of turn. reset_turn()
# now reads the leftover unspent AP still sitting in current_ap (never
# discarded) and overwrites it with
# flat_ap_per_turn + min(leftover, ap_carryover_cap) — 10 + min(leftover, 5)
# at EconomyConfig defaults, so start-of-turn AP is bounded by
# [0, flat_ap_per_turn + ap_carryover_cap] == [0, 15]. No RNG, no
# time-dependent asserts, no file I/O; each test builds its own isolated
# state via GameStateFactory (no shared mutable fixtures).
#
# Migration note (2026-08-05 AP<->Credits pivot): this suite replaces
# ap_reset_discard_test.gd (deleted by the pivot — AP.discard() no longer
# exists, AP carries instead of discarding, and reset_turn() is no longer an
# income snapshot). Every test in the old suite either covered discard()
# (deleted outright — carryover replaces discard-then-reset-to-income) or
# covered the income-snapshot behavior of the old reset_turn() (income_this_turn
# field retired; reset_turn() is now independent of the economy entirely — see
# test_reset_turn_ignores_outpost_count_pure_flat_plus_carry below). This file
# is a ground-up rewrite for the new flat+carry contract; it shares no
# fixtures or assertions with the deleted suite.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- reset_turn(): leftover -> flat + min(leftover, cap) worked examples ----

func test_reset_turn_leftover_0_returns_flat_10() -> void:
	# Arrange — no unspent AP carried in: 10 + min(0, 5) = 10.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 0
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(10)


func test_reset_turn_leftover_3_returns_13() -> void:
	# Arrange — under the cap: 10 + min(3, 5) = 13.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 3
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(13)


func test_reset_turn_leftover_5_returns_15_at_cap_boundary() -> void:
	# Arrange — leftover == ap_carryover_cap (5), the boundary value: 10 + min(5, 5) = 15.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 5
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(15)


func test_reset_turn_leftover_9_clamps_to_15_one_past_cap() -> void:
	# Arrange — one past the cap: 10 + min(9, 5) = 15, not 19.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 9
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(15)


func test_reset_turn_leftover_12_clamps_to_15_well_past_cap() -> void:
	# Arrange — well past the cap: 10 + min(12, 5) = 15, excess leftover lost.
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 12
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(15)


# --- reset_turn(): independent of the economy (no income-driven behavior) --

func test_reset_turn_ignores_outpost_count_pure_flat_plus_carry() -> void:
	# Arrange — several completed outposts (would have driven the pre-pivot
	# income snapshot to well above 10), but reset_turn() no longer reads the
	# economy at all: leftover 0 -> flat 10 regardless of outpost count.
	var state := GameStateFactory.make_state()
	for i: int in 6:
		var structure := StructureState.new()
		structure.entity_id = state.next_entity_id
		structure.owner = 0
		structure.position = Vector2i(i, 0) # unique, arbitrary — no grid in play
		structure.type = StructureTypes.ECONOMY_OUTPOST
		structure.current_hp = structure.type.hp
		structure.build_status = StructureState.BuildStatus.COMPLETED
		structure.build_turns_remaining = 0
		state.entities_by_id[structure.entity_id] = structure
		state.next_entity_id += 1
	state.per_player[0].current_ap = 0
	# Act
	AP.reset_turn(state, 0)
	# Assert — flat 10, not an income total (would be 22 at n=6 under the old formula).
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- reset_turn(): called twice in the same turn (2nd reads the 1st's result) --

func test_reset_turn_called_twice_same_turn_second_reads_first_result_as_leftover() -> void:
	# Arrange — leftover 3 -> first reset writes 13 (10 + min(3,5)).
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 3
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(13)
	# Act — second reset in the same turn reads 13 as ITS leftover:
	# 10 + min(13, 5) = 15 (capped), not a fresh flat-only 10 and not additive.
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(15)


func test_reset_turn_called_twice_same_turn_second_reset_below_cap_stays_uncapped() -> void:
	# Arrange — leftover 1 -> first reset writes 11 (10 + min(1,5)).
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 1
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(11)
	# Act — second reset reads 11 as leftover: 10 + min(11, 5) = 15 (capped,
	# since 11 > 5) — pins that the SECOND call's leftover is genuinely the
	# first call's full output, not silently reset to 0 in between.
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(15)


# --- reset_turn(): a real interposed spend() feeds the next reset's leftover --

func test_reset_turn_after_interposed_spend_uses_post_spend_balance_as_leftover() -> void:
	# Arrange — leftover 0 -> reset writes 10. The active player spends 6,
	# leaving 4 unspent (a real spend() call, not a raw field poke).
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 0
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(10)
	assert_bool(AP.spend(state, 0, 6)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(4)
	# Act — next turn's reset carries the 4 unspent AP: 10 + min(4, 5) = 14.
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(14)


# --- Per-player isolation ----------------------------------------------------

func test_reset_turn_resets_only_the_named_players_pool() -> void:
	# Arrange — two players with different leftovers.
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = 3
	state.per_player[1].current_ap = 20
	# Act — reset only player 0.
	AP.reset_turn(state, 0)
	# Assert — player 0 updated (10 + min(3,5) = 13); player 1 untouched.
	assert_int(state.per_player[0].current_ap).is_equal(13)
	assert_int(state.per_player[1].current_ap).is_equal(20)
