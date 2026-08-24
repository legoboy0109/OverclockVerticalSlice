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


# --- Config-derived expectations (S6-01) -------------------------------------
#
# ★ Every expectation below DERIVES from EconomyConfig rather than restating it.
# The ×3 AP rescale (10 -> 30, 2026-08-24) broke this suite's hardcoded 10/5/15,
# and that is the THIRD hardcoded constant in one change to silently outlive a
# rescale (see also CREDIT_TO_AP_RATE and UPKEEP_DIVISOR). A test that restates a
# constant tests the constant; these test the FORMULA, and survive re-tuning.

func _flat() -> int:
	return Balance.economy.flat_ap_per_turn


func _cap() -> int:
	return Balance.economy.ap_carryover_cap


## The contract under test, expressed once: flat + min(leftover, cap).
func _expected(leftover: int) -> int:
	return _flat() + mini(leftover, _cap())


# --- reset_turn(): leftover -> flat + min(leftover, cap) worked examples ----

func test_reset_turn_leftover_0_returns_flat_only() -> void:
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 0
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat())


func test_reset_turn_leftover_below_cap_carries_in_full() -> void:
	var leftover: int = maxi(1, _cap() - 2)  # strictly under the cap
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = leftover
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + leftover)


func test_reset_turn_leftover_exactly_at_cap_boundary() -> void:
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = _cap()
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + _cap())


func test_reset_turn_leftover_one_past_cap_clamps() -> void:
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = _cap() + 1
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + _cap())


func test_reset_turn_leftover_well_past_cap_clamps() -> void:
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = _cap() * 3
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + _cap())


func test_reset_turn_max_start_of_turn_ap_is_flat_plus_cap() -> void:
	# The stated invariant: start-of-turn AP is bounded by [0, flat + cap].
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 9999
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + _cap())


# --- reset_turn() is independent of the economy ------------------------------

func test_reset_turn_ignores_owned_structures_pure_flat_plus_carry() -> void:
	# AP has not been income-driven since the 2026-08-05 pivot, and since S6-01
	# no structure raises Credit income either. reset_turn() must read neither.
	var state := GameStateFactory.make_state()
	for i: int in 6:
		var structure := StructureState.new()
		structure.entity_id = state.next_entity_id
		structure.owner = 0
		structure.position = Vector2i(i, 0) # unique, arbitrary — no grid in play
		structure.type = StructureTypes.RESEARCH_LAB
		structure.current_hp = structure.type.hp
		structure.build_status = StructureState.BuildStatus.COMPLETED
		structure.build_turns_remaining = 0
		state.entities_by_id[structure.entity_id] = structure
		state.next_entity_id += 1
	state.per_player[0].current_ap = 0
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat())


# --- reset_turn(): called twice in the same turn (2nd reads the 1st's result) --

func test_reset_turn_called_twice_second_reads_first_result_as_leftover() -> void:
	var leftover: int = maxi(1, _cap() - 2)
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = leftover
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_expected(leftover))
	# The second reset reads the first's full output as ITS leftover — not a fresh
	# flat-only value, and not additive. That output exceeds the cap, so it clamps.
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat() + _cap())


# --- reset_turn(): a real interposed spend() feeds the next reset's leftover --

func test_reset_turn_after_interposed_spend_uses_post_spend_balance() -> void:
	var state := GameStateFactory.make_state()
	state.per_player[0].current_ap = 0
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_flat())
	# Spend most of it via a real spend() call, not a raw field poke.
	var spend_amount: int = _flat() - 4
	assert_bool(AP.spend(state, 0, spend_amount)).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_expected(4))


# --- Per-player isolation ----------------------------------------------------

func test_reset_turn_resets_only_the_named_players_pool() -> void:
	var leftover: int = maxi(1, _cap() - 2)
	var untouched: int = 9999
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = leftover
	state.per_player[1].current_ap = untouched
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(_expected(leftover))
	assert_int(state.per_player[1].current_ap).is_equal(untouched)
