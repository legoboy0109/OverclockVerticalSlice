# Story 003: AP reset_turn & discard — Start-of-Turn Freeze / End-of-Turn Discard.
#
# Covers the acceptance criteria in
# production/epics/ap-economy/story-003-ap-reset-discard.md against
# AP.reset_turn()/AP.discard(), using GameStateFactory for state setup and
# real Completed Economy Outposts (Base & Production Story 002's real
# BaseProduction.completed_outpost_count) + the Research test stub for the
# two forward-declared cross-system calls income() makes internally
# (ADR-0006). No RNG, no time-dependent asserts, no file I/O; each test
# resets the Research stub for isolation and builds its own outposts.
#
# Migration note (Base & Production Story 002): this suite originally drove
# BaseProduction.set_completed_outpost_count()/BaseProduction.reset() against
# base_production_stub.gd (deleted by that story — its class_name BaseProduction
# collides with the real class). completed_outpost_count() now derives from
# actual StructureState entities, so every former stub call site below is
# replaced by placing/removing real Completed Economy Outposts in
# state.entities_by_id via _set_completed_outposts()/_add_completed_outpost()/
# _remove_one_completed_outpost() — every income-tier assertion (n=0 -> 10,
# n=4 -> 18, n=7 -> 21, n=10 -> 24) is preserved exactly.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	Research.reset()


# --- Real-structure outpost fixture helpers ---------------------------------

# Builds one alive, owned, Completed Economy Outpost StructureState and
# registers it directly into state.entities_by_id (no grid needed — AP income
# never touches the grid) at a unique, deterministic tile so repeated calls
# never collide. Returns the new entity_id.
func _add_completed_outpost(state: GameState, player: int) -> int:
	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = player
	structure.position = Vector2i(structure.entity_id, 0) # unique, arbitrary — no grid in play
	structure.type = StructureTypes.ECONOMY_OUTPOST
	structure.current_hp = structure.type.hp
	structure.build_status = StructureState.BuildStatus.COMPLETED
	structure.build_turns_remaining = 0
	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1
	return structure.entity_id


# Ensures exactly `count` alive, owned, Completed Economy Outposts exist for
# `player` in `state` — adds more via _add_completed_outpost() if under count;
# this suite never needs to shrink via this helper (mid-turn decreases use
# _remove_one_completed_outpost() explicitly, mirroring "an outpost is
# destroyed" rather than "fewer were ever built").
func _set_completed_outposts(state: GameState, player: int, count: int) -> void:
	for _i: int in count:
		_add_completed_outpost(state, player)


# Removes exactly one alive Completed Economy Outpost owned by `player` from
# `state.entities_by_id` — simulates "an outpost is destroyed" (alive-only
# exclusion), the real-structure equivalent of the old stub's
# set_completed_outpost_count(player, n - 1) mid-turn-decrease usage.
func _remove_one_completed_outpost(state: GameState, player: int) -> void:
	for id: int in state.entities_by_id.keys():
		var e: EntityState = state.entities_by_id[id]
		if e is StructureState and e.owner == player and e.type == StructureTypes.ECONOMY_OUTPOST \
				and e.build_status == StructureState.BuildStatus.COMPLETED:
			state.entities_by_id.erase(id)
			return


# --- reset_turn(): basic frozen-snapshot write (AC1) ------------------------

func test_reset_turn_sets_income_this_turn_and_current_ap_to_income() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	_set_completed_outposts(state, 0, 0)
	# Act
	AP.reset_turn(state, 0)
	# Assert — base_income floor (n=0) is 10; both fields equal the snapshot.
	assert_int(state.per_player[0].income_this_turn).is_equal(10)
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- reset_turn(): outpost completed before reset is observed (AC2) --------

func test_reset_turn_includes_outpost_completed_before_reset() -> void:
	# Arrange — 4 completed outposts at tier1 rate: 10 + 2*4 = 18.
	var state := GameStateFactory.make_state(1, 0)
	_set_completed_outposts(state, 0, 4)
	# Act
	AP.reset_turn(state, 0)
	# Assert
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)


# --- reset_turn(): outpost built (not yet completed) this turn is a no-op (AC3) --

func test_reset_turn_unaffected_by_outpost_still_under_construction() -> void:
	# Arrange — an Under-Construction outpost must NOT count toward the
	# completed total (the real completed_outpost_count's build_status
	# filter IS the contract here — an incomplete outpost is a real structure
	# but never a Completed one).
	var state := GameStateFactory.make_state(1, 0)
	var under_construction := StructureState.new()
	under_construction.entity_id = state.next_entity_id
	under_construction.owner = 0
	under_construction.position = Vector2i(99, 0)
	under_construction.type = StructureTypes.ECONOMY_OUTPOST
	under_construction.current_hp = under_construction.type.hp
	under_construction.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	under_construction.build_turns_remaining = 1
	state.entities_by_id[under_construction.entity_id] = under_construction
	state.next_entity_id += 1
	# Act
	AP.reset_turn(state, 0)
	# Assert — still base_income only, no partial credit for the in-progress build.
	assert_int(state.per_player[0].income_this_turn).is_equal(10)
	assert_int(state.per_player[0].current_ap).is_equal(10)


# --- Frozen-immune-to-increase (AC4, increase direction) --------------------

func test_income_this_turn_frozen_at_18_unaffected_by_mid_turn_outpost_completion() -> void:
	# Arrange — freeze at n=4 (18), then a 5th outpost completes mid-turn.
	var state := GameStateFactory.make_state(1, 0)
	_set_completed_outposts(state, 0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act — a 5th outpost completes mid-turn (a real 5th Completed structure).
	_add_completed_outpost(state, 0)
	# Assert — frozen snapshot still reads 18 until the NEXT reset_turn.
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)


# --- Frozen-immune-to-decrease (AC4, decrease direction) --------------------

func test_income_this_turn_frozen_at_18_unaffected_by_mid_turn_outpost_destruction() -> void:
	# Arrange — freeze at n=4 (18), then one outpost is destroyed mid-turn
	# (opponent's turn destroys one of this player's outposts).
	var state := GameStateFactory.make_state(1, 0)
	_set_completed_outposts(state, 0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act — an outpost is destroyed during the opponent's turn (erased — alive-only).
	_remove_one_completed_outpost(state, 0)
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
	_set_completed_outposts(state, 0, 0)
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
	_set_completed_outposts(state, 0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	assert_int(state.per_player[0].current_ap).is_equal(18)
	# Act — 3 more outposts complete (n=4 -> n=7), then reset_turn runs again
	# with no intervening discard.
	_set_completed_outposts(state, 0, 3)
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
	_set_completed_outposts(state, 0, 4)
	AP.reset_turn(state, 0)
	assert_int(state.per_player[0].income_this_turn).is_equal(18)
	# Act
	_set_completed_outposts(state, 0, 6) # 4 -> 10 total
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
	_set_completed_outposts(state, 0, 4)
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
