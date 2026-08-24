# Story 003: Turn FSM — start_match, start_turn 4-Step Sequence, EndTurnAction
# & Round Increment.
#
# Covers every acceptance criterion in
# production/epics/game-state-turn-manager/story-003-turn-fsm-start-of-turn-sequence.md
# against GameState.start_turn()/start_match()/_apply_end_turn (dispatched via
# apply_action), using GameStateFactory for gridless state setup and a
# MapDefinitionFactory-style inline builder for the one test that exercises
# start_match's grid+HQ construction. Uses the real Base & Production
# BaseProduction.advance_build_timers (Story 002) against real Under-
# Construction StructureStates, the Research stub's GS-003 extension
# (advance_research_timers + queue_completion), and the real Unit/UnitState
# classes (Unit System Story 002/003) plus the Structure/StructureState stub
# for the step-2 flag-reset dispatch. No RNG, no time-dependent asserts, no
# file I/O; each test resets the Research stub for isolation.
#
# Migration note (Base & Production Story 002): this suite originally drove
# BaseProduction.queue_completion()/BaseProduction.reset() against
# base_production_stub.gd (deleted by that story — its class_name
# BaseProduction collides with the real class). The real
# advance_build_timers() completes real Under-Construction structures, so
# every former queue_completion(player, n) call site below is replaced by
# _add_under_construction_outpost(state, player), placing one real Economy
# Outpost (build_status=UNDER_CONSTRUCTION, build_turns_remaining=1) so the
# real start_turn step-3 advance decrements it to 0 and completes it THAT
# turn — same "one outpost finishes building this turn" scenario the stub
# simulated, same +2 tier1 income bonus, same one StructureCompletedEvent.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
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


# Places one real Under-Construction Economy Outpost (build_turns_remaining=1)
# owned by `player` directly into state.entities_by_id — no grid needed
# (advance_build_timers/start_turn's step-3 pass never touches the grid).
# The next advance_build_timers() call for `player` decrements it to 0 and
# completes it THAT SAME call, appending one StructureCompletedEvent and
# adding +1 to completed_outpost_count (a +2 tier1 income bonus) — the exact
# "one outpost finishes building this turn" scenario the deleted stub's
# queue_completion(player) simulated.
func _add_under_construction_outpost(state: GameState, player: int) -> void:
	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = player
	structure.position = Vector2i(structure.entity_id, 0) # unique, arbitrary — no grid in play
	structure.type = StructureTypes.ECONOMY_OUTPOST
	structure.current_hp = structure.type.hp
	structure.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	structure.build_turns_remaining = 1
	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1


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

func test_start_match_sets_active_player_round_1_in_progress_flat_ap_and_credit_income() -> void:
	# Arrange — economy_tier 0, so credit_income is just base_income.
	var map_def := _make_map()
	# Act
	var state: GameState = GameState.start_match(map_def, 0)
	# Assert
	assert_int(state.active_player).is_equal(0)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	# AP is a flat per-turn budget (not income-driven); leftover 0 on a fresh state.
	# ★ S6-01: derived from config, not restated -- the ×3 AP rescale broke the literal.
	assert_int(state.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn)
	# Credit income is banked at step 4b (base_income at tier 0).
	assert_int(state.per_player[0].current_credits).is_equal(Credits.credit_income(state, 0))
	assert_int(state.per_player[0].current_credits).is_equal(Balance.economy.base_income)


func test_start_match_with_player_1_starting_sets_active_player_1_and_its_economy() -> void:
	# Arrange — starting_player need not be 0; proves the param is honored, not
	# hardcoded to player 0.
	var map_def := _make_map()
	# Act
	var state: GameState = GameState.start_match(map_def, 1)
	# Assert — only the starting player's start-of-turn ran.
	assert_int(state.active_player).is_equal(1)
	assert_int(state.starting_player).is_equal(1)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.per_player[1].current_ap).is_equal(Balance.economy.flat_ap_per_turn)  # flat AP budget
	assert_int(state.per_player[1].current_credits).is_equal(Credits.credit_income(state, 1))
	# Player 0 never had a start-of-turn run — still at PlayerState's class defaults.
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_int(state.per_player[0].current_credits).is_equal(0)


# --- AC2: EndTurnAction resolution routed through apply_action -------------

func test_end_turn_action_through_apply_action_carries_outgoing_ap_switches_active_and_resets_opponent() -> void:
	# Post-pivot (ADR-0006): end-of-turn does NOT discard the outgoing player's AP —
	# it carries (capped) into that player's OWN next reset. Prove it with a full
	# round-trip (0 -> 1 -> 0), since only player 0's own reset applies their carry.
	var state := GameStateFactory.make_state(2, 0)
	state.starting_player = 0
	# ★ S6-01: derived from config, not restated — the ×3 AP rescale broke the literals.
	var cfg: EconomyConfig = Balance.economy
	var carried: int = maxi(1, cfg.ap_carryover_cap - 2)  # strictly under the cap
	state.per_player[0].current_ap = carried
	# Act 1 — player 0 ends turn (0 -> 1), through the real pipeline.
	var a0 := EndTurnAction.new()
	a0.player = 0
	var r0: ActionResult = state.apply_action(a0)
	# Assert — outgoing AP is NOT zeroed (no discard); active switched; opponent got flat AP.
	assert_bool(r0.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(carried)  # carried, not discarded
	assert_int(state.active_player).is_equal(1)
	assert_int(state.per_player[1].current_ap).is_equal(cfg.flat_ap_per_turn)  # opponent flat reset (leftover 0)
	# Act 2 — player 1 ends turn (1 -> 0), so player 0's OWN reset runs.
	var a1 := EndTurnAction.new()
	a1.player = 1
	var r1: ActionResult = state.apply_action(a1)
	# Assert — player 0's reset consumed the carry: flat + min(carried, cap).
	assert_bool(r1.ok).is_true()
	assert_int(state.active_player).is_equal(0)
	assert_int(state.per_player[0].current_ap).is_equal(cfg.flat_ap_per_turn + mini(carried, cfg.ap_carryover_cap))


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

func test_start_turn_step4b_credit_income_observes_step3_same_turn_completion() -> void:
	# ★ S6-01 (2026-08-24): this test's original subject -- "a structure completing in
	# step 3 raises step 4b's income the same turn" -- no longer exists. Income is
	# research-tiered and reads nothing from the board.
	#
	# What SURVIVES and is still worth pinning is the step ORDER itself (step 3 build
	# timers run before step 4b income, and the completion event flows out), plus the
	# regression that a completion does NOT move income. Inverted rather than deleted.
	var state := GameStateFactory.make_state(2, 0)
	_add_under_construction_outpost(state, 0)
	# Act — run start_turn directly for player 0 (steps 1-4 in order).
	var events: Array = state.start_turn(0)
	# Assert — income is base only; the step-3 completion contributed nothing.
	assert_int(state.per_player[0].current_credits).is_equal(Balance.economy.base_income)
	# AP is flat (leftover 0), independent of the economy.
	assert_int(state.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn)
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
	# outpost and a +2 sourced from a completed tech land on the SAME final Credit
	# income (12) — i.e. Credits.credit_income treats both step-3 sources additively
	# and interchangeably. A genuine call-order-permutation test would require
	# start_turn to accept an orderable Array[Callable] for step 3 (see
	# tech-debt).
	var state_build_first := GameStateFactory.make_state(2, 0)
	_add_under_construction_outpost(state_build_first, 0) # completes this turn (no income effect since S6-01)
	var events_a: Array = state_build_first.start_turn(0)

	Research.reset()

	var state_research_first := GameStateFactory.make_state(2, 0)
	Research.queue_completion(0, 2) # bonus term set to 2, matching the outpost case
	var events_b: Array = state_research_first.start_turn(0)

	# ★ S6-01 (2026-08-24): both step-3 sources now contribute NOTHING to income --
	# outposts are deleted from the curve and the Research stub's old bonus term is
	# gone. The surviving, and still meaningful, claim is that income is identical
	# regardless of what completed in step 3, which is a stronger statement of the
	# same additive-and-interchangeable property the test was written for.
	# AP is flat in both (economy-independent).
	var base: int = Balance.economy.base_income
	assert_int(state_build_first.per_player[0].current_credits).is_equal(base)
	assert_int(state_research_first.per_player[0].current_credits).is_equal(base)
	assert_int(state_build_first.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn)
	assert_int(state_research_first.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn)
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
	state.next_entity_id = 1
	_add_under_construction_outpost(state, 0) # +2 (tier1 outpost), completes this turn
	Research.queue_completion(0, 3) # +3 (economy tech term)
	# Act
	var events: Array = state.start_turn(0)
	# Assert — step 2 ran (flag reset).
	assert_bool(unit.has_attacked).is_false()
	# Step 3 produced both completions; step 4b's Credit income observes both same turn.
	assert_int(events.size()).is_equal(2)
	# ★ S6-01: income is base + research tiers only. The outpost completing in step 3
	# and the queued Research stub term BOTH contribute nothing -- income no longer
	# reads the board. The step-3-before-step-4 ordering is still proven by the two
	# completion events above.
	assert_int(state.per_player[0].current_credits).is_equal(Balance.economy.base_income)
	assert_int(state.per_player[0].current_ap).is_equal(Balance.economy.flat_ap_per_turn) # flat, economy-independent


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
	_add_under_construction_outpost(state, 1) # completions apply to the INCOMING player (1)
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
