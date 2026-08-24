# Economy pivot (ADR-0006): AP + Credits two-pool turn loop — Integration.
#
# The unit suites each isolate one pool or one turn: turn_sequencing proves a
# single AP carryover round-trip (10 + min(4,5) = 14) and single-turn Credit
# income; credits_spend proves add_income accumulates when called twice DIRECTLY;
# the base-production end-to-end proves a single dual-cost commit. What no suite
# yet proves is the pivot's SYSTEM behaviour: driving the REAL orchestrator
# (state.start_turn / state.apply_action(EndTurn)) across MULTIPLE of the same
# player's turns so the two pools' divergent turn-over-turn semantics are asserted
# SIDE BY SIDE — the mechanical backbone of the S4-05 "investment costs tempo"
# tempo playtest:
#
#   - AP is a BOUNDED tactical budget: it refreshes to flat_ap_per_turn each of
#     the player's turns, with unspent AP carrying only up to ap_carryover_cap.
#   - Credits are an UNBOUNDED banked war chest: income ADDS to the running pile
#     every turn and never resets/discards, so the pile compounds turn over turn.
#
# Both are exercised through the real GameState loop (no direct pool mutation
# except modelling "how much AP the player left unspent this turn", which existing
# turn_sequencing tests also do). Every expected value is derived from
# Balance.economy's live fields, never a bare literal. Deterministic: no RNG, no
# wall-clock, no file I/O; Research is reset each test so the econ_tech income term
# is a clean 0 and the banked totals are exact multiples of the outpost income.
#
# Gridless: completed_outpost_count / credit_income read entities_by_id, not the
# grid (mirrors turn_sequencing_test's fixture discipline), so no GridState is
# built — this suite is about the turn/economy loop, not build legality (which the
# base-production end-to-end suite already covers).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	Research.reset()


func after_test() -> void:
	Research.reset()


# A gridless 2-player state, both pinned to Factions.NEUTRAL (credit_income's
# folds dereference faction), AP + Credits at a known 0 baseline so the first
# start_turn's post-values are exactly flat_ap_per_turn / credit_income.
func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = 0
		state.per_player[i].current_credits = 0
		state.per_player[i].faction = Factions.NEUTRAL
	return state


# Places one already-COMPLETED Economy Outpost owned by `player` directly into
# entities_by_id (no grid needed — completed_outpost_count/credit_income read
# entities_by_id). COMPLETED + build_turns_remaining 0 means advance_build_timers
# skips it, so it never re-completes and the owner's income stays constant across
# every turn of this loop.
func _add_completed_outpost(state: GameState, player: int) -> void:
	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = player
	structure.position = Vector2i(structure.entity_id, 0) # unique, arbitrary — gridless
	structure.type = StructureTypes.FACTORY
	structure.current_hp = structure.type.hp
	structure.build_status = StructureState.BuildStatus.COMPLETED
	structure.build_turns_remaining = 0
	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1


# Drives the real turn loop from the active player 0 back to player 0: p0 ends
# (0 -> 1, runs p1's start_turn), then p1 ends (1 -> 0, runs p0's NEXT start_turn
# and increments the round on the loop-back to starting_player). After this, it is
# player 0's next turn, established entirely through the real apply_action path.
func _round_trip_back_to_p0(state: GameState) -> void:
	var end_p0 := EndTurnAction.new()
	end_p0.player = 0
	state.apply_action(end_p0)
	assert_int(state.active_player).is_equal(1) # sanity: control actually moved.
	var end_p1 := EndTurnAction.new()
	end_p1.player = 1
	state.apply_action(end_p1)
	assert_int(state.active_player).is_equal(0) # sanity: back to player 0.


# ==============================================================================
# Credits bank additively every turn (compounding, not one-shot) while AP is a
# bounded flat refresh — driven across THREE of player 0's turns via the real loop.
# ==============================================================================

func test_credits_bank_additively_over_three_turns_while_ap_refreshes_flat() -> void:
	# Arrange — player 0 owns two completed Economy Outposts, so income is a fixed
	# I > base every turn (no completions occur during the loop).
	var state := _make_state()
	_add_completed_outpost(state, 0)
	_add_completed_outpost(state, 0)
	var cfg: EconomyConfig = Balance.economy
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(2)

	# --- Turn 1: the first start_turn establishes the baseline. ---
	state.start_turn(0)
	# ★ S6-02: the per-turn figure that actually banks is NET (gross - upkeep). This
	# fixture owns two completed outposts, which now cost upkeep, so the whole
	# compounding assertion below is against net rather than gross.
	var income: int = Upkeep.net_credit_income(state, 0) # the fixed per-turn NET income I.
	assert_int(Credits.credit_income_breakdown(state, 0)["tiers"]).is_equal(0) # ★ S6-01: tier 0 -> no tier income.
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn) # flat, leftover 0.
	assert_int(state.per_player[0].current_credits).is_equal(income)           # banked 1x from 0.

	# Model "player 0 spent all its AP this turn" so the flat-refresh is clean (no
	# carryover), isolating banking from carryover in THIS test.
	state.per_player[0].current_ap = 0

	# --- Turn 2 (via the real loop). ---
	_round_trip_back_to_p0(state)
	assert_int(state.round_number).is_equal(2)
	# ★ S6-02: compare NET against NET. Gross income is constant, but `income` above is
	# the net figure that actually banks, so asserting gross here would compare two
	# different quantities and pass or fail for the wrong reason.
	assert_int(Upkeep.net_credit_income(state, 0)).is_equal(income)
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn) # refreshed flat again.
	assert_int(state.per_player[0].current_credits).is_equal(2 * income)       # war chest COMPOUNDED to 2I.

	state.per_player[0].current_ap = 0 # spent all AP again.

	# --- Turn 3 (via the real loop). ---
	_round_trip_back_to_p0(state)
	assert_int(state.round_number).is_equal(3)
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn) # still flat.
	assert_int(state.per_player[0].current_credits).is_equal(3 * income)       # 3I — banking is not one-shot.


# ==============================================================================
# The two pools' END-OF-TURN semantics differ, simultaneously: unspent AP carries
# but is CAPPED, while Credits keep banking UNCAPPED — across one real round-trip.
# ==============================================================================

func test_unspent_ap_carries_capped_while_credits_keep_banking() -> void:
	# Arrange — two completed outposts (fixed income I); a leftover AP amount
	# deliberately ABOVE the carryover cap so the cap is the thing under test.
	var state := _make_state()
	_add_completed_outpost(state, 0)
	_add_completed_outpost(state, 0)
	var cfg: EconomyConfig = Balance.economy
	var leftover: int = cfg.ap_carryover_cap + 2 # strictly above the cap.

	# --- Turn 1 baseline. ---
	state.start_turn(0)
	# ★ S6-02: NET is what banks (this fixture owns outposts that now pay upkeep).
	var income: int = Upkeep.net_credit_income(state, 0)
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn)
	assert_int(state.per_player[0].current_credits).is_equal(income)

	# Model an under-spent turn: `leftover` AP remains (above the cap).
	state.per_player[0].current_ap = leftover

	# --- Turn 2 (via the real loop). ---
	_round_trip_back_to_p0(state)
	# AP: flat refresh PLUS carried leftover, but the carry is capped at
	# ap_carryover_cap (leftover > cap, so exactly the cap is added — never `leftover`).
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn + cfg.ap_carryover_cap)
	assert_int(state.per_player[0].current_ap).is_not_equal(cfg.flat_ap_per_turn + leftover) # cap really bit.
	# Credits: banked a second time, UNCAPPED — the war chest simply grew to 2I,
	# with no carryover-style ceiling of its own.
	assert_int(state.per_player[0].current_credits).is_equal(2 * income)
