# Story 002: Action Command Model, apply_action Pipeline & Event Signal.
#
# Covers every acceptance criterion in
# production/epics/game-state-turn-manager/story-002-apply-action-pipeline.md
# against GameState.apply_action()/EndTurnAction, using GameStateFactory for
# state setup. No RNG, no time-dependent asserts, no file I/O; each test
# builds its own isolated state.
#
# Static-table isolation note (per coordinator direction): GameState's
# _validators/_appliers dispatch tables are class-level statics shared across
# every test in the whole suite run (they represent code-behavior, not
# per-instance data, per ADR-0002). Production code now registers END_TURN
# (GS-003), MOVE (ADR-0009), ATTACK (ADR-0010), and BUILD/PRODUCE/CANCEL_BUILD
# (Base & Production Stories 002/004/005) in _ensure_dispatch_registered — so
# Action.Verb.RESEARCH is the ONLY enum verb still unregistered (Research is its
# own later epic). Both throwaway-handler tests here therefore share RESEARCH:
# one registers a CANT_AFFORD stub on it to exercise pipeline-generic
# affordability atomicity (asserting RESEARCH absent up front and unregistering
# in cleanup so nothing leaks under any load order — GdUnit4 runs cases
# sequentially, so the register/unregister lifecycle keeps them isolated), and a
# separate test dispatches bare RESEARCH to check the unknown-verb rejection
# path. When the Research epic lands and registers RESEARCH, its story must
# re-treat these (no enum verb will remain free — switch to a bare -1 verb or a
# save-and-restore of a registered handler). The "dispatch via enum, not
# get_class()" regression test routes a real EndTurnAction rather than a stub.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# Builds a minimal populated GameState: 2 players, an empty entities map, no
# grid (not needed for these pipeline-level tests — no verb handler under
# test here touches the grid). Player 0 is active, round 1, IN_PROGRESS.
func _make_state(player_count: int = 2, active_player: int = 0) -> GameState:
	return GameStateFactory.make_state(player_count, active_player)


# Small counter helper used to assert action_applied's emission count/payload
# without depending on GdUnit4's signal-arg matching against a Resource
# payload (ActionResult identity varies per call, so a manual connected
# counter is the most direct, unambiguous evidence here).
class _SignalSpy:
	var call_count: int = 0
	var last_result: ActionResult = null

	func _on_action_applied(result: ActionResult) -> void:
		call_count += 1
		last_result = result


# --- AC1: insufficient-AP action -> rejected, zero state change -------------
# EndTurnAction has no affordability check (it is exempt, AC-scoped to other
# verbs) — insufficient-AP atomicity for a concrete affordability-gated verb
# is out of this story's scope (no concrete MOVE/ATTACK/etc. handler exists
# yet). This test exercises the equivalent atomicity guarantee at the
# pipeline level using a manually-registered stub verb that fails on
# affordability, proving step 3/4 leaves AP untouched — the same mechanism a
# real verb's validate() will rely on.
func test_insufficient_ap_action_rejected_with_zero_state_change() -> void:
	# Arrange — register a throwaway verb whose validate() always reports
	# CANT_AFFORD, and whose apply() would mutate AP if ever (wrongly)
	# reached — proving the pipeline never calls apply() after a rejection.
	# Uses Verb.RESEARCH: the only enum verb still unregistered (Research is a
	# later epic), borrowed as a scratch handler. The unknown-verb-rejection
	# test below also reads RESEARCH (unregistered), but this test fully
	# unregisters it in cleanup, so the two never observe each other's state —
	# GdUnit4 runs cases sequentially.
	var state := _make_state(2, 0)
	state.per_player[0].current_ap = 2
	# Precondition — Verb.RESEARCH must start unregistered (no leak from any prior
	# test); this test owns its lifecycle and cleans up via unregister_verb.
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()
	GameState.register_verb(
		Action.Verb.RESEARCH,
		func(_s: GameState, _a: Action) -> int: return Action.Reason.CANT_AFFORD,
		func(s: GameState, _a: Action) -> Array:
			s.per_player[0].current_ap = 0  # would prove atomicity broken if ever called
			return []
	)
	var action := Action.new()
	action.verb = Action.Verb.RESEARCH
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_array(result.events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(2)
	assert_int(state.entities_by_id.size()).is_equal(0)
	# Cleanup — fully remove the throwaway RESEARCH handler so it cannot leak
	# into any later test in the process (incl. the unknown-verb test above/below).
	GameState.unregister_verb(Action.Verb.RESEARCH)
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()


# --- Dispatch-safety: unregistered verb / bare Action -> clean UNKNOWN_VERB reject --
# Guards the step-3 dispatch lookup: 6 of 7 verbs are unregistered until their
# own Core epic lands, and a bare Action.new() defaults verb to -1. Both must
# fail loud-but-safe with a clean ActionResult, never crash the caller.

func test_action_with_unregistered_verb_rejected_with_unknown_verb() -> void:
	# Arrange — Verb.RESEARCH is never registered (Research's own verb handler
	# is a separate, later epic); Verb.ATTACK is no longer usable for this
	# fixture as of Combat Resolution Story 004, which registers it for real.
	var state := _make_state(2, 0)
	assert_bool(GameState._validators.has(Action.Verb.RESEARCH)).is_false()
	var action := Action.new()
	action.verb = Action.Verb.RESEARCH
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — clean rejection, no crash, no state change.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.UNKNOWN_VERB)
	assert_array(result.events).is_empty()


func test_bare_action_with_default_verb_rejected_with_unknown_verb() -> void:
	# Arrange — a bare Action.new() has verb == -1 (never a registered key),
	# the exact shape of a fat-fingered call site that forgot a concrete subclass.
	var state := _make_state(2, 0)
	var action := Action.new()
	action.player = 0
	assert_int(action.verb).is_equal(-1)
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — clean rejection rather than a dispatch-lookup crash.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.UNKNOWN_VERB)


# --- AC2: illegal action (wrong active player) -> rejected, zero state change --

func test_wrong_active_player_action_rejected_with_zero_state_change() -> void:
	# Arrange
	var state := _make_state(2, 0)
	state.per_player[0].current_ap = 5
	state.per_player[1].current_ap = 5
	var action := EndTurnAction.new()
	action.player = 1  # not the active player (0)
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NOT_ACTIVE_PLAYER)
	assert_array(result.events).is_empty()
	assert_int(state.active_player).is_equal(0)
	assert_int(state.per_player[0].current_ap).is_equal(5)
	assert_int(state.per_player[1].current_ap).is_equal(5)


# --- AC3: determinism — same state + same ordered actions, two runs -> identical --

func test_determinism_same_state_and_actions_two_runs_produce_identical_results() -> void:
	# Arrange — two independently-built, field-wise-identical initial states.
	var state_a := _make_state(2, 0)
	var state_b := _make_state(2, 0)
	state_a.per_player[0].current_ap = 7
	state_b.per_player[0].current_ap = 7
	# Act — apply the identical ordered action sequence (here: a single
	# EndTurnAction, the only concrete verb in scope) to each independently.
	var action_a := EndTurnAction.new()
	action_a.player = 0
	var action_b := EndTurnAction.new()
	action_b.player = 0
	var result_a: ActionResult = state_a.apply_action(action_a)
	var result_b: ActionResult = state_b.apply_action(action_b)
	# Assert — field-wise-identical resulting states and results.
	assert_bool(result_a.ok).is_equal(result_b.ok)
	assert_int(result_a.reason).is_equal(result_b.reason)
	assert_int(result_a.events.size()).is_equal(result_b.events.size())
	assert_int(state_a.active_player).is_equal(state_b.active_player)
	assert_int(state_a.round_number).is_equal(state_b.round_number)
	assert_int(state_a.match_status).is_equal(state_b.match_status)
	assert_int(state_a.per_player[0].current_ap).is_equal(state_b.per_player[0].current_ap)


# --- AC4: idempotency-by-revalidation — resubmit an applied action -> rejected --

func test_resubmitting_already_applied_end_turn_action_object_is_rejected_no_double_apply() -> void:
	# Arrange
	var state := _make_state(2, 0)
	var action := EndTurnAction.new()
	action.player = 0
	# Act — apply once (succeeds), then resubmit the SAME Action object.
	var first: ActionResult = state.apply_action(action)
	assert_bool(first.ok).is_true()
	# active_player is unchanged by Story 002's stub apply() (Story 003 owns
	# the real switch), so resubmitting the identical action against
	# now-current state re-validates as active-player == 0 still and would
	# normally re-succeed for an idempotent no-op verb like this story's
	# EndTurnAction stub. To prove the re-validation gate itself (not this
	# particular verb's idempotence), resubmit against a state that has since
	# moved on: advance active_player out from under the stale action.
	state.active_player = 1
	var second: ActionResult = state.apply_action(action)
	# Assert — re-validated against CURRENT state and rejected; no double-apply.
	assert_bool(second.ok).is_false()
	assert_int(second.reason).is_equal(Action.Reason.NOT_ACTIVE_PLAYER)


# --- AC5: action_applied emitted exactly once, synchronously, on success ----

func test_action_applied_emitted_exactly_once_synchronously_on_success_with_events() -> void:
	# Arrange
	var state := _make_state(2, 0)
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — emitted exactly once, synchronously (spy already updated by the
	# time apply_action returns — no await/frame needed), carrying the events.
	assert_bool(result.ok).is_true()
	assert_int(spy.call_count).is_equal(1)
	assert_object(spy.last_result).is_same(result)
	assert_array(spy.last_result.events).is_equal(result.events)


func test_action_applied_not_emitted_on_rejection() -> void:
	# Arrange
	var state := _make_state(2, 0)
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	var action := EndTurnAction.new()
	action.player = 1  # wrong active player -> rejected
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_false()
	assert_int(spy.call_count).is_equal(0)
	assert_object(spy.last_result).is_null()


# --- AC6: verb dispatch via enum table, never get_class() -------------------

func test_end_turn_action_get_class_returns_refcounted_but_dispatch_still_routes_correctly() -> void:
	# Arrange — regression guard: an EndTurnAction's engine get_class() is
	# "RefCounted" (its GDScript class_name is invisible to get_class()), so
	# any dispatch relying on match action.get_class() would silently never
	# match. apply_action must still route correctly via the verb enum.
	var state := _make_state(2, 0)
	var action := EndTurnAction.new()
	action.player = 0
	# Assert — the engine-gotcha premise itself.
	assert_str(action.get_class()).is_equal("RefCounted")
	assert_int(action.verb).is_equal(Action.Verb.END_TURN)
	# Act — dispatch must still succeed (looked up via action.verb, not type).
	var result: ActionResult = state.apply_action(action)
	# Assert — correctly routed to EndTurnAction's handlers (unconditionally OK).
	assert_bool(result.ok).is_true()
	assert_int(result.reason).is_equal(Action.Reason.OK)


# --- AC7: faction lock — guard seam (Story 003 hands off the real transition) --

func test_faction_reassignment_guard_rejects_with_faction_locked() -> void:
	# NOTE: this tests the GUARD SEAM ONLY, not a full Setup->PlayerTurn
	# transition flow. There is no concrete faction-assignment Action verb in
	# this story's scope (ADR-0012 places the real Setup FSM/transition with
	# start_match(), which is Story 003's territory) and MatchStatus has no
	# SETUP value. GameState.check_faction_reassignment()/is_faction_locked()
	# are the enforceable seam a future faction-assignment verb's validate()
	# will call; today every constructible GameState is already "past Setup"
	# by construction, so the guard unconditionally reports FACTION_LOCKED.
	# This is flagged as a cross-story seam handoff to GS-003 (see the doc
	# comments on GameState.is_faction_locked()).
	var state := _make_state(2, 0)
	# Act / Assert
	assert_bool(state.is_faction_locked()).is_true()
	assert_int(state.check_faction_reassignment(0)).is_equal(Action.Reason.FACTION_LOCKED)
	assert_int(state.check_faction_reassignment(1)).is_equal(Action.Reason.FACTION_LOCKED)


# --- AC: EndTurnAction unconditionally legal for the active player ----------

func test_end_turn_action_unconditionally_legal_for_active_player_even_with_zero_ap() -> void:
	# Arrange — active player can afford nothing (proves no softlock,
	# TR-gamestate-017): EndTurnAction has no affordability/legality gate.
	var state := _make_state(2, 0)
	state.per_player[0].current_ap = 0
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(result.reason).is_equal(Action.Reason.OK)


# --- Full 7-step pipeline order test ----------------------------------------

func test_full_seven_step_pipeline_order_gameover_then_active_player_then_validate_then_apply_then_winblcheck_then_emit() -> void:
	# Arrange — a state that is NOT GameOver and IS the active player, so all
	# 7 steps execute; verify each step's effect landed in the right order by
	# checking the observable outcomes each step is responsible for.
	var state := _make_state(2, 0)
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert — step 1 (GameOver gate) passed: match_status still IN_PROGRESS.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	# Step 2 (active-player gate) passed: action.player matched active_player.
	# Step 3+4 (validate + reject-if-not-OK): reason is OK, not a rejection.
	assert_int(result.reason).is_equal(Action.Reason.OK)
	# Step 5 (apply): ok flag reflects a successful apply(), events present
	# (empty array is still "present" — this stub returns no events).
	assert_bool(result.ok).is_true()
	assert_array(result.events).is_empty()
	# Step 6 (run_win_check): no-op stub — match_status unchanged by it.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	# Step 7 (emit + return): signal fired exactly once, synchronously, with
	# the same ActionResult identity as the return value.
	assert_int(spy.call_count).is_equal(1)
	assert_object(spy.last_result).is_same(result)


# --- Edge case: action after GAME_OVER -> GAME_OVER reject (step 1 gate) ----

func test_action_after_game_over_rejected_with_game_over_reason() -> void:
	# Arrange — manually-constructed GameOver state (full GameOver-SETTING
	# logic is Story 004; this story only tests step 1's gate given a state
	# already in that terminal status).
	var state := _make_state(2, 0)
	state.match_status = GameState.MatchStatus.GAME_OVER
	var spy := _SignalSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(result.events).is_empty()
	assert_int(spy.call_count).is_equal(0)


# --- Edge case: EndTurnAction with zero other legal actions available ------

func test_end_turn_action_legal_even_when_no_other_actions_are_available() -> void:
	# Arrange — a state with zero AP, zero entities, nothing else the active
	# player could legally do this turn; EndTurnAction must still succeed
	# (the whole point of its unconditional-legality exemption).
	var state := _make_state(2, 0)
	state.per_player[0].current_ap = 0
	state.entities_by_id = {}
	var action := EndTurnAction.new()
	action.player = 0
	# Act
	var result: ActionResult = state.apply_action(action)
	# Assert
	assert_bool(result.ok).is_true()
	assert_int(result.reason).is_equal(Action.Reason.OK)
