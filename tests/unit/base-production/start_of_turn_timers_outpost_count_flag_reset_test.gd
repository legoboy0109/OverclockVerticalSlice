# Base & Production Story 002: advance_build_timers, completed_outpost_count,
# Structure.reset_turn_flags.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-002-build-verb-legal-build-tiles-occupancy.md:
#   Completion advance (Rule 6, pure slice): 2-remaining -> decrements to 1,
#     stays Under-Construction; 1-remaining -> Completed + one
#     StructureCompletedEvent, reads no income state; two structures both
#     reaching 0 in one call -> both Complete, each with its own event (batch).
#   completed_outpost_count (Rule 11): {2 Completed Econ, 1 U/C Econ, 1
#     Completed Prod, 1 HQ} all one player's -> exactly 2; opponent-owned
#     Completed Econ excluded; destroyed (erased) Completed Econ excluded,
#     none-qualify -> 0 not null; Completed Research Lab + Completed
#     Defensive Structure both excluded.
#   Start-of-turn flag reset (Rules 7, 8): units_produced_this_turn -> 0;
#     has_attacked -> false.
#
# Injected fixtures (no grid needed -- advance_build_timers/
# completed_outpost_count/reset_turn_flags never touch the grid), mirroring
# tests/unit/ap_reset_discard_test.gd's real-structure fixture style
# (Base & Production Story 002's migration).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Fixture builders --------------------------------------------------------

func _make_state(player_count: int = 2, active_player: int = 0) -> GameState:
	return GameStateFactory.make_state(player_count, active_player)


func _make_structure(state: GameState, owner: int, type: StructureTypeDef, status: int, build_turns_remaining: int = 0) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = owner
	structure.position = Vector2i(structure.entity_id, 0) # unique, arbitrary -- no grid in play
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = status
	structure.build_turns_remaining = build_turns_remaining
	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1
	return structure


# --- advance_build_timers: decrement (Rule 6) --------------------------------

func test_advance_decrements_two_remaining_to_one_stays_under_construction() -> void:
	# Arrange
	var state := _make_state()
	var structure := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 2)
	# Act
	var events: Array[Event] = BaseProduction.advance_build_timers(state, 0)
	# Assert
	assert_int(structure.build_turns_remaining).is_equal(1)
	assert_int(structure.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_array(events).is_empty()


# --- advance_build_timers: complete at 0 (Rule 6) ----------------------------

func test_advance_completes_one_remaining_appends_one_completed_event() -> void:
	# Arrange
	var state := _make_state()
	var structure := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	# Act
	var events: Array[Event] = BaseProduction.advance_build_timers(state, 0)
	# Assert
	assert_int(structure.build_turns_remaining).is_equal(0)
	assert_int(structure.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructureCompletedEvent).is_true()


func test_advance_reads_no_income_state_pure_transition_only() -> void:
	# Arrange -- advance_build_timers must not touch AP/income fields at all;
	# it is a pure transition, commutative with advance_research_timers.
	var state := _make_state()
	_make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	var ap_before: int = state.per_player[0].current_ap
	var income_before: int = state.per_player[0].income_this_turn
	# Act
	BaseProduction.advance_build_timers(state, 0)
	# Assert -- untouched.
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_int(state.per_player[0].income_this_turn).is_equal(income_before)


# --- advance_build_timers: batch completion (Rule 6) -------------------------

func test_advance_batch_completes_two_structures_reaching_zero_same_call() -> void:
	# Arrange -- two Under-Construction structures both at 1 remaining.
	var state := _make_state()
	var a := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	var b := _make_structure(state, 0, StructureTypes.PRODUCTION_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	# Act
	var events: Array[Event] = BaseProduction.advance_build_timers(state, 0)
	# Assert -- both complete in this one call, each with its own event.
	assert_int(a.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(b.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(events.size()).is_equal(2)
	for e: Event in events:
		assert_bool(e is StructureCompletedEvent).is_true()


func test_advance_only_touches_player_owned_under_construction_structures() -> void:
	# Arrange -- an opponent's Under-Construction structure and this player's
	# already-Completed structure must both be left untouched.
	var state := _make_state()
	var mine := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	var opponents := _make_structure(state, 1, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	var already_done := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED, 0)
	# Act
	var events: Array[Event] = BaseProduction.advance_build_timers(state, 0)
	# Assert -- only "mine" completes; opponent's untouched; already-Completed untouched.
	assert_int(mine.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(opponents.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(opponents.build_turns_remaining).is_equal(1)
	assert_int(already_done.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(events.size()).is_equal(1)


# --- completed_outpost_count (Rule 11) ---------------------------------------

func test_completed_outpost_count_basic_fixture_returns_exactly_two() -> void:
	# Arrange -- {2 Completed Econ, 1 U/C Econ, 1 Completed Prod, 1 HQ}, all
	# one player's.
	var state := _make_state()
	_make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	_make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	_make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	_make_structure(state, 0, StructureTypes.PRODUCTION_OUTPOST, StructureState.BuildStatus.COMPLETED)
	_make_structure(state, 0, StructureTypes.HQ, StructureState.BuildStatus.COMPLETED)
	# Act / Assert
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(2)


func test_completed_outpost_count_excludes_opponent_owned() -> void:
	# Arrange
	var state := _make_state()
	_make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	_make_structure(state, 1, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	# Act / Assert -- player 0 sees only their own.
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(1)
	assert_int(BaseProduction.completed_outpost_count(state, 1)).is_equal(1)


func test_completed_outpost_count_excludes_destroyed_alive_only() -> void:
	# Arrange -- a Completed Economy Outpost destroyed this step (erased from
	# entities_by_id, per ADR-0017 D1's alive == present invariant).
	var state := _make_state()
	var structure := _make_structure(state, 0, StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	state.entities_by_id.erase(structure.entity_id)
	# Act / Assert
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(0)


func test_completed_outpost_count_returns_zero_not_null_when_none_qualify() -> void:
	# Arrange -- an empty state, no structures at all.
	var state := _make_state()
	# Act
	var result: int = BaseProduction.completed_outpost_count(state, 0)
	# Assert -- 0, never null (statically typed int return already guarantees
	# this, but pin the value explicitly).
	assert_int(result).is_equal(0)


func test_completed_outpost_count_excludes_research_lab_and_defensive_structure() -> void:
	# Arrange -- a Completed Research Lab and a Completed Defensive Structure,
	# both owned by the player -- only Economy Outposts count.
	var state := _make_state()
	_make_structure(state, 0, StructureTypes.RESEARCH_LAB, StructureState.BuildStatus.COMPLETED)
	_make_structure(state, 0, StructureTypes.DEFENSIVE_STRUCTURE, StructureState.BuildStatus.COMPLETED)
	# Act / Assert
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(0)


# --- Start-of-turn flag reset (Rules 7, 8) -----------------------------------

func test_reset_turn_flags_resets_units_produced_this_turn_to_zero() -> void:
	# Arrange
	var structure := StructureState.new()
	structure.owner = 0
	structure.type = StructureTypes.PRODUCTION_OUTPOST
	structure.units_produced_this_turn = 3
	# Act
	Structure.reset_turn_flags(structure)
	# Assert
	assert_int(structure.units_produced_this_turn).is_equal(0)


func test_reset_turn_flags_resets_has_attacked_to_false() -> void:
	# Arrange
	var structure := StructureState.new()
	structure.owner = 0
	structure.type = StructureTypes.DEFENSIVE_STRUCTURE
	structure.has_attacked = true
	# Act
	Structure.reset_turn_flags(structure)
	# Assert
	assert_bool(structure.has_attacked).is_false()


func test_reset_turn_flags_resets_both_flags_together_on_the_same_structure() -> void:
	# Arrange -- a single call must reset both fields, regardless of which the
	# structure type actually uses (harmless no-op write on the unused one).
	var structure := StructureState.new()
	structure.owner = 0
	structure.type = StructureTypes.ECONOMY_OUTPOST
	structure.units_produced_this_turn = 2
	structure.has_attacked = true
	# Act
	Structure.reset_turn_flags(structure)
	# Assert
	assert_int(structure.units_produced_this_turn).is_equal(0)
	assert_bool(structure.has_attacked).is_false()


# --- defensive_attack_cost() reads config (regression guard for Combat) -----

func test_defensive_attack_cost_reads_structure_balance_config() -> void:
	# Act / Assert -- reads StructureBalance.base_production.defensive_attack_cost
	# (Story 001's config), never a hardcoded literal.
	assert_int(BaseProduction.defensive_attack_cost()).is_equal(StructureBalance.base_production.defensive_attack_cost)
