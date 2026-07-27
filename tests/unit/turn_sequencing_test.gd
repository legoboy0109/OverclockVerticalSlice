# Story 003: Turn FSM — start_match, start_turn 4-Step Sequence, EndTurnAction
# & Round Increment.
#
# Covers every acceptance criterion in
# production/epics/game-state-turn-manager/story-003-turn-fsm-start-of-turn-sequence.md
# against GameState.start_turn()/start_match()/_apply_end_turn (dispatched via
# apply_action), using GameStateFactory for gridless state setup and a
# MapDefinitionFactory-style inline builder for the one test that exercises
# start_match's grid+HQ construction. Uses the shared BaseProduction/Research
# stubs' GS-003 extensions (advance_build_timers/advance_research_timers +
# queue_completion) and the real Unit/UnitState classes (Unit System Story
# 002/003) plus the Structure/StructureState stubs for the step-2 flag-reset
# dispatch. No RNG, no time-dependent asserts, no file I/O; each test resets
# every shared stub for isolation.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	BaseProduction.reset()
	Research.reset()


# Small counter helper used to assert action_applied's emission/payload
# without depending on GdUnit4's signal-arg matching against a Resource
# payload — mirrors apply_action_pipeline_test.gd's _SignalSpy.
class _SignalSpy:
	var call_count: int = 0
	var last_result: ActionResult = null

	func _on_action_applied(result: ActionResult) -> void:
		call_count += 1
		last_result = result


# Builds a minimal 8x8 all-Plain AUTHORED MapDefinition with two HQs, suitable
# for GameState.start_match(). Kept local to this file (no other suite needs
# a buildable MapDefinition yet) rather than added to GameStateFactory.
func _make_map(hq_a: Vector2i = Vector2i(1, 1), hq_b: Vector2i = Vector2i(6, 6)) -> MapDefinition:
	var map_def := MapDefinition.new()
	map_def.width = 8
	map_def.height = 8
	map_def.mode = MapDefinition.Mode.AUTHORED
	map_def.authored_terrain = PackedByteArray()
	map_def.authored_terrain.resize(8 * 8)
	map_def.authored_terrain.fill(GridState.Terrain.PLAIN)
	map_def.hq_tiles = [hq_a, hq_b]
	map_def.deploy_tiles = []
	return map_def


# --- AC1: start_match sets active/round=1/in-progress/AP=income, one start-of-turn --

func test_start_match_sets_active_player_round_1_in_progress_and_income_ap() -> void:
	# Arrange — no outposts/tech, so income is just base_income (10).
	var map_def := _make_map()
	# Act
	var state: GameState = GameState.start_match(map_def, 0)
	# Assert
	assert_int(state.active_player).is_equal(0)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.per_player[0].current_ap).is_equal(AP.income(state, 0))
	assert_int(state.per_player[0].current_ap).is_equal(10)


func test_start_match_with_player_1_starting_sets_active_player_1_and_its_income() -> void:
	# Arrange — starting_player need not be 0; proves the param is honored, not
	# hardcoded to player 0.
	var map_def := _make_map()
	# Act
	var state: GameState = GameState.start_match(map_def, 1)
	# Assert — only the starting player's start-of-turn ran.
	assert_int(state.active_player).is_equal(1)
	assert_int(state.starting_player).is_equal(1)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.per_player[1].current_ap).is_equal(AP.income(state, 1))
	# Player 0 never had a start-of-turn run — still at PlayerState's class default.
	assert_int(state.per_player[0].current_ap).is_equal(0)


# --- AC2: EndTurnAction resolution routed through apply_action -------------

func test_end_turn_action_through_apply_action_discards_outgoing_ap_switches_active_and_resets_opponent_ap() -> void:
	# Arrange — player 0 active with leftover unspent AP; player 1 starts at 0.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	state.per_player[0].current_ap = 4
	var action := EndTurnAction.new()
	action.player = 0
	# Act — through the real pipeline (validate -> apply -> emit), not a direct call.
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0) # discarded, no banking
	assert_int(state.active_player).is_equal(1) # switched
	assert_int(state.per_player[1].current_ap).is_equal(AP.income(state, 1)) # opponent income


# --- AC3: round increment fires only on loop-back to starting_player --------

func test_first_movers_end_turn_does_not_increment_round() -> void:
	# Arrange — player 0 is starting_player and currently active; ending their
	# turn hands control to player 1 (NOT the starting player) -> no increment.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(state.round_number).is_equal(1)
	assert_int(state.active_player).is_equal(1)


func test_second_movers_end_turn_increments_round_exactly_once() -> void:
	# Arrange — player 0 is starting_player; player 1 (the second mover) is
	# currently active. Ending player 1's turn returns control to player 0
	# (== starting_player) -> round increments by exactly 1.
	var state := GameStateFactory.make_state(2, 1)
	state.starting_player = 0
	var action := EndTurnAction.new()
	action.player = 1
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(state.round_number).is_equal(2)
	assert_int(state.active_player).is_equal(0)


func test_full_round_trip_both_ends_increments_round_exactly_once_not_twice() -> void:
	# Arrange — starting_player = 0, active = 0. Drive both EndTurns in sequence.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	var end_p0 := EndTurnAction.new()
	end_p0.player = 0
	# Act — player 0 ends (no increment expected).
	state.apply_action(end_p0)
	assert_int(state.round_number).is_equal(1)
	var end_p1 := EndTurnAction.new()
	end_p1.player = 1
	# Act — player 1 ends (control returns to starting_player 0 -> +1, once).
	state.apply_action(end_p1)
	# Assert
	assert_int(state.round_number).is_equal(2)
	assert_int(state.active_player).is_equal(0)


func test_third_end_turn_wraps_round_to_3_on_second_loop_back() -> void:
	# Arrange — starting_player = 0, active = 0. Drive THREE EndTurns to prove
	# the loop-back increment keeps firing on each subsequent round boundary,
	# not just the first (guards against a one-shot / latched increment bug).
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	# Round 1: p0 ends (no increment), p1 ends (-> round 2).
	var e0 := EndTurnAction.new()
	e0.player = 0
	state.apply_action(e0)
	var e1 := EndTurnAction.new()
	e1.player = 1
	state.apply_action(e1)
	assert_int(state.round_number).is_equal(2)
	assert_int(state.active_player).is_equal(0)
	# Round 2: p0 ends again (control -> p1, NOT starting_player -> no increment).
	var e0b := EndTurnAction.new()
	e0b.player = 0
	# Act
	state.apply_action(e0b)
	# Assert — third EndTurn hands control to p1; round stays 2 until p1 ends.
	assert_int(state.round_number).is_equal(2)
	assert_int(state.active_player).is_equal(1)
	# And a fourth (p1 ends) wraps to round 3 — the second loop-back.
	var e1b := EndTurnAction.new()
	e1b.player = 1
	state.apply_action(e1b)
	assert_int(state.round_number).is_equal(3)
	assert_int(state.active_player).is_equal(0)


# --- AC4: step order 1->2->3->4, step-4 income observes step-3 completion ---

func test_start_turn_step4_income_snapshot_observes_step3_same_turn_completion() -> void:
	# Arrange — queue a build completion for player 0; base_income=10,
	# tier1 bonus=2/outpost, so one completed outpost -> income 12.
	var state := GameStateFactory.make_state(2, 0)
	BaseProduction.queue_completion(0)
	# Act — run start_turn directly for player 0 (steps 1-4 in order).
	var events: Array = state.start_turn(0)
	# Assert — step 4's snapshot already reflects the step-3 completion.
	assert_int(state.per_player[0].current_ap).is_equal(12)
	assert_int(state.per_player[0].income_this_turn).is_equal(12)
	# The completion event flowed out of start_turn.
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructureCompletedEvent).is_true()


# --- Steps 2 & 3 commutative internally, but both finish before step 4 -----

func test_income_total_same_regardless_of_which_system_supplies_the_completion() -> void:
	# NOTE — scope of this test (renamed from a misleading "commutative" name,
	# GS-003 code review): start_turn's step 3 hardcodes the call order
	# (build then research) with no seam to permute it, so the manifest's
	# "the two timer-advance calls must stay commutative" contract is a
	# DESIGN-TIME invariant enforced by ADR-0008 + code review, NOT by this
	# test. What this test actually proves: a +2 bonus sourced from a completed
	# outpost and a +2 sourced from a completed tech land on the SAME final
	# income (12) — i.e. AP.income treats both step-3 sources additively and
	# interchangeably. A genuine call-order-permutation test would require
	# start_turn to accept an orderable Array[Callable] for step 3 (see
	# tech-debt).
	var state_build_first := GameStateFactory.make_state(2, 0)
	BaseProduction.queue_completion(0) # +2 tier1 outpost bonus -> 12
	var events_a: Array = state_build_first.start_turn(0)

	BaseProduction.reset()
	Research.reset()

	var state_research_first := GameStateFactory.make_state(2, 0)
	Research.queue_completion(0, 2) # bonus term set to 2, matching the outpost case
	var events_b: Array = state_research_first.start_turn(0)

	# Assert — both orderings/sources land on the same total AP (base 10 + 2).
	assert_int(state_build_first.per_player[0].current_ap).is_equal(12)
	assert_int(state_research_first.per_player[0].current_ap).is_equal(12)
	assert_int(events_a.size()).is_equal(1)
	assert_int(events_b.size()).is_equal(1)


func test_step2_flag_reset_and_step3_timers_both_complete_before_step4_when_both_fire_same_turn() -> void:
	# Arrange — both a build AND a research completion queued the same turn,
	# plus an active-player unit whose flag must be reset (step 2) — proves
	# steps 2 and 3 both run, and step 4's snapshot reflects BOTH step-3 terms.
	var state := GameStateFactory.make_state(2, 0)
	var unit := UnitState.new()
	unit.entity_id = 0
	unit.owner = 0
	unit.has_attacked = true
	state.entities_by_id[unit.entity_id] = unit
	BaseProduction.queue_completion(0) # +2 (tier1 outpost)
	Research.queue_completion(0, 3) # +3 (economy tech term)
	# Act
	var events: Array = state.start_turn(0)
	# Assert — step 2 ran (flag reset).
	assert_bool(unit.has_attacked).is_false()
	# Step 3 produced both completions; step 4 observes both same turn.
	assert_int(events.size()).is_equal(2)
	assert_int(state.per_player[0].current_ap).is_equal(15) # 10 base + 2 + 3


# --- Step 2 dispatch: active player's entities reset, opponent's untouched --

func test_start_turn_step2_resets_only_active_players_entities() -> void:
	# Arrange — one unit per player, both starting has_attacked = true.
	var state := GameStateFactory.make_state(2, 0)
	var unit_p0 := UnitState.new()
	unit_p0.entity_id = 0
	unit_p0.owner = 0
	unit_p0.has_attacked = true
	var unit_p1 := UnitState.new()
	unit_p1.entity_id = 1
	unit_p1.owner = 1
	unit_p1.has_attacked = true
	state.entities_by_id[0] = unit_p0
	state.entities_by_id[1] = unit_p1
	var structure_p0 := StructureState.new()
	structure_p0.entity_id = 2
	structure_p0.owner = 0
	structure_p0.has_attacked = true
	state.entities_by_id[2] = structure_p0
	# Act — start_turn for player 0 only.
	state.start_turn(0)
	# Assert — player 0's entities reset, player 1's untouched.
	assert_bool(unit_p0.has_attacked).is_false()
	assert_bool(structure_p0.has_attacked).is_false()
	assert_bool(unit_p1.has_attacked).is_true()


func test_start_turn_step2_safely_skips_plain_entity_state_neither_unit_nor_structure() -> void:
	# Arrange — a plain EntityState (the shape start_match uses for HQs today,
	# since ADR-0007's UnitState/StructureState schema hasn't landed) matches
	# neither the `is UnitState` nor `is StructureState` step-2 branch. It must
	# be silently skipped — no crash, no reset handler invoked — alongside a
	# real UnitState that DOES get reset, proving the dispatch chain handles a
	# mixed bag correctly.
	var state := GameStateFactory.make_state(2, 0)
	var hq := EntityState.new() # plain base type — neither Unit nor Structure
	hq.entity_id = 0
	hq.owner = 0
	state.entities_by_id[0] = hq
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.has_attacked = true
	state.entities_by_id[1] = unit
	# Act — must not crash on the plain EntityState.
	state.start_turn(0)
	# Assert — the real unit was reset; the plain HQ was left untouched (it has
	# no per-turn flag and hit neither dispatch branch).
	assert_bool(unit.has_attacked).is_false()


# --- AC5: zero-legal-actions player can still end_turn (no softlock) -------

func test_zero_legal_actions_player_can_still_end_turn_no_softlock() -> void:
	# Arrange — active player has 0 AP, no entities, nothing else legal.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	state.per_player[0].current_ap = 0
	state.entities_by_id = {}
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — unconditionally legal; turn still advances.
	assert_bool(result.ok).is_true()
	assert_int(result.reason).is_equal(Action.Reason.OK)
	assert_int(state.active_player).is_equal(1)


# --- W2 regression: HQ ids allocated from next_entity_id, no collision -----

func test_start_match_hq_ids_allocated_from_next_entity_id_no_collision_with_later_entities() -> void:
	# Arrange
	var map_def := _make_map(Vector2i(1, 1), Vector2i(6, 6))
	# Act
	var state: GameState = GameState.start_match(map_def, 0)
	# Assert — two HQ entities exist, ids 0 and 1, matching the grid's already-
	# placed occupancy (build_grid's own placeholder placement).
	assert_int(state.entities_by_id.size()).is_equal(2)
	assert_bool(state.entities_by_id.has(0)).is_true()
	assert_bool(state.entities_by_id.has(1)).is_true()
	assert_int(state.entities_by_id[0].owner).is_equal(0)
	assert_int(state.entities_by_id[1].owner).is_equal(1)
	assert_vector(state.entities_by_id[0].position).is_equal(map_def.hq_tiles[0])
	assert_vector(state.entities_by_id[1].position).is_equal(map_def.hq_tiles[1])
	assert_int(state.grid.occupant_at(1, 1)).is_equal(0)
	assert_int(state.grid.occupant_at(6, 6)).is_equal(1)
	# next_entity_id has advanced past both HQs — a later-created entity never collides.
	assert_int(state.next_entity_id).is_equal(2)
	var new_entity := EntityState.new()
	new_entity.entity_id = state.next_entity_id
	state.entities_by_id[new_entity.entity_id] = new_entity
	state.next_entity_id += 1
	assert_int(new_entity.entity_id).is_equal(2)
	assert_bool(state.entities_by_id.has(2)).is_true()
	assert_int(state.entities_by_id.size()).is_equal(3)


# --- Edge case: starting_player set once, never mutated afterward ----------

func test_starting_player_set_once_by_start_match_never_mutated_by_subsequent_turns() -> void:
	# Arrange
	var map_def := _make_map()
	var state: GameState = GameState.start_match(map_def, 1)
	assert_int(state.starting_player).is_equal(1)
	# Act — drive several EndTurns; starting_player must never change.
	var end_1 := EndTurnAction.new()
	end_1.player = 1
	state.apply_action(end_1)
	assert_int(state.starting_player).is_equal(1)
	var end_0 := EndTurnAction.new()
	end_0.player = 0
	state.apply_action(end_0)
	# Assert
	assert_int(state.starting_player).is_equal(1)
	assert_int(state.round_number).is_equal(2) # looped back to player 1


# --- Completion events flow through the existing action_applied signal -----

func test_structure_and_tech_completed_events_flow_through_action_applied_signal() -> void:
	# Arrange — queue both a build and a research completion so the next
	# EndTurnAction's start_turn (for the incoming player) emits both event
	# types, then assert they arrive on action_applied via a connected spy.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	BaseProduction.queue_completion(1) # completions apply to the INCOMING player (1)
	Research.queue_completion(1, 1)
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(spy.call_count).is_equal(1)
	assert_array(spy.last_result.events).is_equal(result.events)
	assert_int(result.events.size()).is_equal(2)
	var saw_structure_completed := false
	var saw_tech_completed := false
	for e: Event in result.events:
		if e is StructureCompletedEvent:
			saw_structure_completed = true
		elif e is TechCompletedEvent:
			saw_tech_completed = true
	assert_bool(saw_structure_completed).is_true()
	assert_bool(saw_tech_completed).is_true()


# --- Strengthened GS-002 determinism check (optional hardening) ------------

func test_determinism_two_independently_built_states_driven_by_two_end_turns_match_fully() -> void:
	# Arrange — two independently-built, field-wise-identical states.
	var state_a := GameStateFactory.make_state(2, 0)
	state_a.starting_player = 0
	var state_b := GameStateFactory.make_state(2, 0)
	state_b.starting_player = 0
	# Act — apply the identical two-EndTurn sequence to each independently.
	var end_a1 := EndTurnAction.new()
	end_a1.player = 0
	var end_b1 := EndTurnAction.new()
	end_b1.player = 0
	state_a.apply_action(end_a1)
	state_b.apply_action(end_b1)
	var end_a2 := EndTurnAction.new()
	end_a2.player = 1
	var end_b2 := EndTurnAction.new()
	end_b2.player = 1
	state_a.apply_action(end_a2)
	state_b.apply_action(end_b2)
	# Assert — full state match at every observable field after both turns.
	assert_int(state_a.active_player).is_equal(state_b.active_player)
	assert_int(state_a.round_number).is_equal(state_b.round_number)
	assert_int(state_a.match_status).is_equal(state_b.match_status)
	assert_int(state_a.starting_player).is_equal(state_b.starting_player)
	assert_int(state_a.per_player[0].current_ap).is_equal(state_b.per_player[0].current_ap)
	assert_int(state_a.per_player[1].current_ap).is_equal(state_b.per_player[1].current_ap)
	assert_int(state_a.round_number).is_equal(2)
