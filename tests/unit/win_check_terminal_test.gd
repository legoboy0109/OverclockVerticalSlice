# Story 004: Win-Check, GameOver & MAX_ROUNDS/Tiebreak Terminal Conditions.
#
# Covers every acceptance criterion in
# production/epics/game-state-turn-manager/story-004-win-check-terminal-conditions.md
# against GameState.run_win_check(), driven either directly (hand-built events
# array — for the branch-level HQ/simultaneous-HQ/tiebreak logic) or end-to-end
# through GameState.apply_action() (for the pipeline-composition/signal cases),
# using GameStateFactory for state setup.
#
# StructureDestroyedEvent/GameOverEvent are forward-declared Foundation event
# types (see their doc comments). Real Combat (ADR-0010) exists as of Combat
# Resolution Story 004 (registers ATTACK), and Base & Production Stories 002/004/005
# now register BUILD/PRODUCE/CANCEL_BUILD for real — so the end-to-end tests here
# drive their throwaway destruction stand-in via Action.Verb.RESEARCH, the last
# verb still genuinely unregistered (Research is its own later epic). This
# migration mirrors the incremental scratch-verb re-treatment each epic performs
# (BUILD→CANCEL_BUILD by Story 002, now CANCEL_BUILD→RESEARCH by Story 005); when
# the Research epic lands and registers RESEARCH, its story must re-treat these
# fixtures again (no enum verb will remain unregistered — switch to a bare -1
# verb or a save-and-restore of a registered handler). Pattern: assert the verb
# slot is absent up front, register a stub, unregister in cleanup.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _make_state(player_count: int = 2, active_player: int = 0) -> GameState:
	return GameStateFactory.make_state(player_count, active_player)


# Builds a StructureDestroyedEvent{is_hq=true, owner=owner} — the shape
# run_win_check's HQ-destruction branch scans for.
func _hq_destroyed(owner: int) -> StructureDestroyedEvent:
	var evt := StructureDestroyedEvent.new()
	evt.is_hq = true
	evt.owner = owner
	return evt


# Adds count plain EntityState entities owned by owner to state, with unique
# ids starting from state.next_entity_id — enough for the UNIT_COUNT tiebreak
# metric (a plain count over entities_by_id, independent of entity subtype).
# Real UnitState fixtures. _add_entities creates BARE EntityState, which is neither a
# unit nor a structure — fine for tests that only need "some entities exist", but it
# counts as nothing under either tiebreak metric, both of which narrow by type.
func _add_units(state: GameState, owner: int, count: int) -> void:
	for _i: int in count:
		var u := UnitState.new()
		u.entity_id = state.next_entity_id
		u.owner = owner
		u.type = UnitTypes.TROOPER
		u.current_hp = UnitTypes.TROOPER.hp
		state.entities_by_id[u.entity_id] = u
		state.next_entity_id += 1


# An HQ with an explicit remaining hp, for the TOTAL_HQ_HP metric.
func _add_hq(state: GameState, owner: int, hp: int) -> void:
	var s := StructureState.new()
	s.entity_id = state.next_entity_id
	s.owner = owner
	s.type = StructureTypes.HQ
	s.current_hp = hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[s.entity_id] = s
	state.next_entity_id += 1


func _add_entities(state: GameState, owner: int, count: int) -> void:
	for _i: int in count:
		var e := EntityState.new()
		e.entity_id = state.next_entity_id
		e.owner = owner
		state.entities_by_id[e.entity_id] = e
		state.next_entity_id += 1


# Small counter helper used to assert action_applied's emission/payload —
# mirrors apply_action_pipeline_test.gd's _SignalSpy.
class _SignalSpy:
	var call_count: int = 0
	var last_result: ActionResult = null

	func _on_action_applied(result: ActionResult) -> void:
		call_count += 1
		last_result = result


# --- AC1: HQ reaches 0 hp -> GameOver(winner=opponent), synchronous ---------

func test_hq_destroyed_event_sets_game_over_with_opponent_as_winner() -> void:
	# Arrange — player 1's HQ destroyed; player 0 is active (the attacker).
	var state := _make_state(2, 0)
	var events: Array = [_hq_destroyed(1)]
	# Act
	state.run_win_check(events)
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)
	var saw_game_over := false
	for e: Event in events:
		if e is GameOverEvent:
			saw_game_over = true
			assert_int(e.winner).is_equal(0)
	assert_bool(saw_game_over).is_true()


# --- AC1/composition driven end-to-end through apply_action -----------------

func test_hq_destroyed_through_apply_action_end_to_end_sets_game_over_and_next_action_rejected() -> void:
	# Arrange — register a throwaway verb (Verb.ATTACK, unregistered by any
	# other story) whose apply() returns a StructureDestroyedEvent{is_hq,
	# owner=1}, standing in for Combat's not-yet-built destroy_entity() hook.
	var state := _make_state(2, 0)
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()
	GameState.register_verb(
		Action.Verb.RESEARCH,
		func(_s: GameState, _a: Action) -> int: return Action.Reason.OK,
		func(_s: GameState, _a: Action) -> Array: return [_hq_destroyed(1)]
	)
	var action := Action.new()
	action.verb = Action.Verb.RESEARCH
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — the killing action itself succeeds and reports GameOver state.
	assert_bool(result.ok).is_true()
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)
	var saw_game_over := false
	for e: Event in result.events:
		if e is GameOverEvent:
			saw_game_over = true
	assert_bool(saw_game_over).is_true()
	# Composition (GS-002 step-1 lockout + this story's step-6 setter):
	# the VERY NEXT apply_action is rejected GAME_OVER.
	var next_action := Action.new()
	next_action.verb = Action.Verb.RESEARCH
	next_action.player = 1
	var next_result: ActionResult = state.apply_action(next_action)
	assert_bool(next_result.ok).is_false()
	assert_int(next_result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(next_result.events).is_empty()
	# Cleanup.
	GameState.unregister_verb(Action.Verb.RESEARCH)
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()


# --- Mid-turn immediacy: GameOver set synchronously, before apply_action returns --

func test_win_condition_mid_turn_sets_game_over_and_leftover_ap_cannot_be_spent() -> void:
	# match_status reads GAME_OVER the instant apply_action returns (no
	# await/frame) — this catches a deferred/call_deferred win-check regression
	# (which would leave IN_PROGRESS until the next idle frame). It also covers
	# AC2's "remaining AP is ignored": the winning player still has unspent AP,
	# but the post-GameOver step-1 lockout rejects any further action regardless.
	var state := _make_state(2, 0)
	state.per_player[0].current_ap = 5 # leftover AP that must become irrelevant
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()
	GameState.register_verb(
		Action.Verb.RESEARCH,
		func(_s: GameState, _a: Action) -> int: return Action.Reason.OK,
		func(_s: GameState, _a: Action) -> Array: return [_hq_destroyed(1)]
	)
	var action := Action.new()
	action.verb = Action.Verb.RESEARCH
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — GameOver already set by the time apply_action returns.
	assert_bool(result.ok).is_true()
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	# AC2 — the winner's leftover 5 AP is now irrelevant: a further action is
	# rejected GAME_OVER even though the AP still sits unspent in the pool.
	assert_int(state.per_player[0].current_ap).is_equal(5)
	var followup := Action.new()
	followup.verb = Action.Verb.RESEARCH
	followup.player = 0
	var followup_result: ActionResult = state.apply_action(followup)
	assert_bool(followup_result.ok).is_false()
	assert_int(followup_result.reason).is_equal(Action.Reason.GAME_OVER)
	# Cleanup.
	GameState.unregister_verb(Action.Verb.RESEARCH)


# --- AC3: simultaneous double-HQ destruction -> non-active player wins ------

func test_simultaneous_double_hq_destruction_non_active_player_wins() -> void:
	# Arrange — both HQs destroyed in the same events array; player 0 is
	# active (mid-turn attacker) -> non-active player (1) wins.
	var state := _make_state(2, 0)
	var events: Array = [_hq_destroyed(0), _hq_destroyed(1)]
	# Act
	state.run_win_check(events)
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(1) # non-active (active_player == 0)


func test_simultaneous_double_hq_destruction_with_player_1_active_non_active_player_0_wins() -> void:
	# Arrange — same scenario, but player 1 is active this time, proving the
	# rule is "non-active player", not a hardcoded player index.
	var state := _make_state(2, 1)
	var events: Array = [_hq_destroyed(0), _hq_destroyed(1)]
	# Act
	state.run_win_check(events)
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0) # non-active (active_player == 1)


# --- Single-HQ winner formula is symmetric (reverse direction) --------------

func test_single_hq_destroyed_owner_0_winner_is_1_reverse_direction() -> void:
	# Every other single-HQ test destroys player 1's HQ; this destroys player
	# 0's, proving winner = 1 - owner is symmetric, not a hardcoded winner.
	# active_player = 1 so the winner (1) isn't incidentally the active player.
	var state := _make_state(2, 1)
	var events: Array = [_hq_destroyed(0)]
	# Act
	state.run_win_check(events)
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(1)


# --- A non-HQ structure destroyed must NOT end the match --------------------

func test_non_hq_structure_destroyed_does_not_trigger_game_over() -> void:
	# Guards the is_hq filter: a `is StructureDestroyedEvent` scan that forgot
	# to check `.is_hq` would wrongly end the match when a regular building falls.
	var state := _make_state(2, 0)
	var evt := StructureDestroyedEvent.new()
	evt.is_hq = false
	evt.owner = 1
	# Act
	state.run_win_check([evt])
	# Assert — a non-HQ destruction is not a terminal condition.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.winner).is_equal(-1)


# --- AC6: HQ destroyed on the same step MAX_ROUNDS is reached ---------------

func test_hq_destroyed_same_step_max_rounds_reached_hq_winner_wins_not_tiebreak() -> void:
	# Arrange — max_rounds=3, round_number=4 (cap already exceeded) so the
	# tiebreak branch WOULD fire if reached; give player 1 more units so the
	# tiebreak (if wrongly evaluated) would pick player 1 — but an HQ
	# destruction (player 1's HQ) is also present, so the decisive branch
	# must win and return before ever computing the tiebreak.
	var state := _make_state(2, 0)
	state.max_rounds = 3
	state.round_number = 4
	_add_entities(state, 1, 5) # tiebreak-metric decoy: player 1 "should" win by count
	_add_entities(state, 0, 1)
	var events: Array = [_hq_destroyed(1)]
	# Act
	state.run_win_check(events)
	# Assert — HQ-destruction opponent (player 0) wins, not the tiebreak (player 1).
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)


# --- MAX_ROUNDS reached, no HQ destroyed -> tiebreak decides ----------------

func test_max_rounds_reached_no_hq_destroyed_tiebreak_picks_higher_unit_count() -> void:
	# Arrange — max_rounds=5, round_number=6 (cap reached); player 0 has more
	# units than player 1. UNIT_COUNT is set EXPLICITLY: the default is now
	# TOTAL_HQ_HP (the metric game-state-turn-manager.md always specified), so a test
	# of unit count has to ask for it.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	state.tiebreak_metric = GameState.TiebreakMetric.UNIT_COUNT
	_add_units(state, 0, 3)
	_add_units(state, 1, 1)
	# Act
	state.run_win_check([])
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)


# --- TOTAL_HQ_HP: the spec default, corrected 2026-08-21 --------------------
#
# game-state-turn-manager.md always specified {total HQ hp, tiles controlled, unit
# count} with total HQ hp as the DEFAULT. Only UNIT_COUNT shipped, because HQ hp needed
# schema fields that did not exist at the time; ADR-0007 has since landed and they do.
# UNIT_COUNT was also implemented as a count of EVERY entity, structures and HQ
# included, which made a capped game a contest of who built more.

func test_total_hq_hp_is_the_default_metric() -> void:
	# Asserted WITHOUT setting it, so a silent change to the default fails here.
	var state := _make_state(2, 0)
	assert_int(state.tiebreak_metric).is_equal(GameState.TiebreakMetric.TOTAL_HQ_HP)


func test_default_tiebreak_picks_the_player_whose_hq_is_healthier() -> void:
	# The point of the metric: a capped game goes to whoever did more damage toward
	# the only real win condition.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	_add_hq(state, 0, 40) # untouched
	_add_hq(state, 1, 12) # battered
	state.run_win_check([])
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)


func test_default_tiebreak_cannot_be_won_by_building_or_producing() -> void:
	# ★ The regression this correction exists to prevent. Player 1 is drowning player 0
	# in units and structures but has taken real HQ damage; player 0 still wins, because
	# the metric measures progress toward victory rather than accumulated stuff.
	# Under the old entity-count implementation player 1 won this position outright.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	_add_hq(state, 0, 40)
	_add_hq(state, 1, 8)
	_add_units(state, 1, 12)
	for _i: int in 5:
		var outpost := StructureState.new()
		outpost.entity_id = state.next_entity_id
		outpost.owner = 1
		outpost.type = StructureTypes.BARRACKS
		outpost.current_hp = 10
		state.entities_by_id[outpost.entity_id] = outpost
		state.next_entity_id += 1
	state.run_win_check([])
	assert_int(state.winner).is_equal(0)


func test_unit_count_metric_ignores_structures() -> void:
	# ★ The other half of the same correction: UNIT_COUNT must count UNITS. Player 1 has
	# more entities in total but fewer units, and must lose on this metric.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	state.tiebreak_metric = GameState.TiebreakMetric.UNIT_COUNT
	_add_units(state, 0, 4)
	_add_units(state, 1, 2)
	_add_hq(state, 1, 40)
	for _i: int in 6:
		var outpost := StructureState.new()
		outpost.entity_id = state.next_entity_id
		outpost.owner = 1
		outpost.type = StructureTypes.BARRACKS
		outpost.current_hp = 10
		state.entities_by_id[outpost.entity_id] = outpost
		state.next_entity_id += 1
	state.run_win_check([])
	assert_int(state.winner).is_equal(0)


func test_equal_hq_hp_falls_through_to_the_non_active_player_rule() -> void:
	# ★ Worth knowing before relying on this: two untouched HQs are an EXACT tie, so the
	# result comes from the seat rule, not from play. That is the shipped behaviour and
	# it is what an AI-vs-AI mirror produces today, since the AI never attacks an HQ.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	_add_hq(state, 0, 40)
	_add_hq(state, 1, 40)
	state.run_win_check([])
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(1) # non-active; active_player is 0


# --- AC7: MAX_ROUNDS reached with EQUAL tiebreak metric -> non-active wins --

func test_max_rounds_reached_equal_unit_count_non_active_player_wins_no_draw() -> void:
	# Arrange — equal unit counts; player 0 is active -> non-active (1) wins.
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 6
	state.tiebreak_metric = GameState.TiebreakMetric.UNIT_COUNT
	_add_units(state, 0, 2)
	_add_units(state, 1, 2)
	# Act
	state.run_win_check([])
	# Assert — no draw; deterministic non-active-player rule.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(1)


func test_max_rounds_reached_equal_unit_count_zero_each_non_active_player_wins() -> void:
	# Arrange — boundary: both players have zero entities (still an exact tie).
	var state := _make_state(2, 1)
	state.max_rounds = 2
	state.round_number = 3
	# Act
	state.run_win_check([])
	# Assert — non-active player (0), active_player == 1.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)


# --- AC5: MAX_ROUNDS unset (0, the default) -> round-cap terminal never fires --

func test_max_rounds_unset_never_triggers_round_cap_terminal_regardless_of_round_number() -> void:
	# Arrange — max_rounds left at its class default (0); round_number driven
	# arbitrarily high; give the players an unequal unit count so a wrongly
	# firing tiebreak would be observable.
	var state := _make_state(2, 0)
	assert_int(state.max_rounds).is_equal(0) # precondition: default is unset/OFF
	state.round_number = 1000
	_add_entities(state, 0, 10)
	# Act
	state.run_win_check([])
	# Assert — no terminal condition ever fires; still IN_PROGRESS.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.winner).is_equal(-1)


func test_max_rounds_set_but_round_number_not_yet_reached_stays_in_progress() -> void:
	# Arrange — max_rounds=5, round_number=5 (all 5 rounds NOT yet fully
	# completed — the documented "reached" rule is round_number > max_rounds,
	# so round_number == max_rounds must NOT trigger yet).
	var state := _make_state(2, 0)
	state.max_rounds = 5
	state.round_number = 5
	_add_entities(state, 0, 3)
	_add_entities(state, 1, 1)
	# Act
	state.run_win_check([])
	# Assert — cap not yet reached; no terminal condition.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.winner).is_equal(-1)


# --- No terminal condition present -> stays IN_PROGRESS, idempotent no-op --

func test_no_hq_destroyed_and_no_max_rounds_leaves_match_in_progress() -> void:
	# Arrange — a completely unremarkable events array (e.g. from a routine
	# EndTurnAction) with no destruction and no round cap configured.
	var state := _make_state(2, 0)
	# Act
	state.run_win_check([])
	# Assert
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.winner).is_equal(-1)


func test_run_win_check_already_game_over_is_a_safe_no_op() -> void:
	# Arrange — idempotency/safety guard: match already GAME_OVER (as if
	# reached by a prior commit); a further call must not overwrite winner
	# or append a second GameOverEvent.
	var state := _make_state(2, 0)
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.winner = 0
	var events: Array = [_hq_destroyed(0)] # would (wrongly) flip winner if not guarded
	# Act
	state.run_win_check(events)
	# Assert — unchanged; no new GameOverEvent appended.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)
	assert_int(events.size()).is_equal(1) # array not grown — nothing appended
	for e: Event in events:
		assert_bool(e is GameOverEvent).is_false()


# --- GameOverEvent flows through action_applied -----------------------------

func test_game_over_event_flows_through_action_applied_signal() -> void:
	# Arrange — same throwaway-verb mechanism, with a connected signal spy.
	var state := _make_state(2, 0)
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()
	GameState.register_verb(
		Action.Verb.RESEARCH,
		func(_s: GameState, _a: Action) -> int: return Action.Reason.OK,
		func(_s: GameState, _a: Action) -> Array: return [_hq_destroyed(1)]
	)
	var action := Action.new()
	action.verb = Action.Verb.RESEARCH
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — signal fired once, synchronously, and its events carry the
	# GameOverEvent run_win_check appended.
	assert_bool(result.ok).is_true()
	assert_int(spy.call_count).is_equal(1)
	assert_object(spy.last_result).is_same(result)
	var saw_game_over := false
	for e: Event in spy.last_result.events:
		if e is GameOverEvent:
			saw_game_over = true
			assert_int(e.winner).is_equal(0)
	assert_bool(saw_game_over).is_true()
	# Cleanup.
	GameState.unregister_verb(Action.Verb.RESEARCH)
