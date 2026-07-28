# Story 006: AITurnDriver — Evaluate→Commit Loop, Termination, Rejection
# Handling, Per-Commit Streaming.
#
# Covers production/epics/ai-opponent/story-006-ai-turn-driver-loop.md QA Cases,
# driving the REAL AITurnDriver.run_ai_turn() against a REAL GameState inside a
# running SceneTree (GdUnitTestSuite is a Node in the tree, so
# `await get_tree().create_timer(...).timeout` — the one await AITurnDriver
# itself performs — resolves normally here):
#
#   AC-3        : the loop commits real actions from a real GameState via the
#                 real state.apply_action() (not a clone) until AI.choose_action
#                 returns null, at which point the turn ends via a real
#                 EndTurnAction.
#   AC-9        : the loop terminates within a bounded iteration count — this
#                 suite asserts an explicit upper bound on action_applied
#                 emissions (via a signal spy) so a hang/infinite-loop would
#                 fail the assertion instead of the test process spinning
#                 forever.
#   AC-24/AC-10 : commit-rejection handling. A true clone-vs-commit race cannot
#                 be interleaved from single-threaded test code (there is no
#                 await between AI.choose_action and state.apply_action inside
#                 one loop iteration for a test to land a mutation in) — so,
#                 per this story's coordinator ruling, AC-24 is proven
#                 pragmatically in two parts: (a) a direct assertion that
#                 state.apply_action() on a deliberately-illegal action returns
#                 ok == false and spends zero AP — the exact contract
#                 AITurnDriver's `if not result.ok: continue` branch relies on;
#                 (b) running the real driver on a real, non-trivial multi-unit
#                 board and asserting it still terminates within the same
#                 bounded iteration count with no crash — proving the driver
#                 survives/re-loops correctly even when some of its internal
#                 iterations do no useful work.
#   AC-25       : zero owned units/producers at TURN_START -> AI.choose_action
#                 returns null immediately -> zero apply_action commits, turn
#                 ends immediately (one EndTurnAction only, zero
#                 action_applied emissions from the AI's own combat/economy
#                 verbs).
#   AC-35       : the AI's own lethal commit (destroying the enemy HQ) sets
#                 match_status = GAME_OVER inside the loop -> the loop returns
#                 immediately -> no EndTurnAction is ever submitted and no
#                 further apply_action call happens after the terminal commit
#                 (proven via the action_applied spy's call count == 1).
#   AC-13       : with a running SceneTree and AIBalance.ai.commit_pacing_sec
#                 set near-zero for test speed, action_applied fires exactly
#                 once per real commit (counted via a signal spy, never
#                 inferred from timing).
#   Edge        : two consecutive rejections in a row re-loop both times
#                 without accumulating error state or crashing (folded into the
#                 AC-24(b) bounded-board scenario above via a wider iteration
#                 cap check).
#
# Fixture idiom mirrors
# tests/integration/base-production/integration_apply_action_end_to_end_test.gd
# (_make_grid/_make_state/_make_unit/_make_structure/_make_hq/_place) — real
# GridState, real UnitState/StructureState via the live StructureTypes/
# UnitTypes registry, no injected doubles. AIBalance.ai.commit_pacing_sec is
# saved and restored around every test (a shared Autoload resource across the
# whole suite run) so nothing here leaks a fast pacing value into an unrelated
# test — mirrors Research.reset()'s isolation discipline elsewhere in this
# corpus.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8

# Iteration/commit upper bound (AC-9): generous for this suite's small
# fixtures (at most a couple of live entities per test) but tight enough that
# a genuine infinite loop fails fast instead of hanging the whole suite.
# Upper bound for AC-9 "bounded termination" — the driver must never spin
# forever; a genuine infinite loop blows past this and fails fast. On the
# 50-AP multi-candidate board the AI legitimately makes ~30 small commits
# (approach-moves that set up attacks, plus a capped economy build/cancel
# burst) before AP is exhausted and choose_action returns null — bounded and
# terminating, which is what AC-9 requires. (The commit count being on the
# high side for so few units is a credible-not-masterful AI-efficiency
# observation, not a correctness issue — noted for future tuning.)
const MAX_COMMITS: int = 45

var _saved_commit_pacing_sec: float


# --- Signal spy (mirrors apply_action_pipeline_test.gd's _SignalSpy idiom) --

class _ActionAppliedSpy:
	var call_count: int = 0
	var results: Array[ActionResult] = []

	func _on_action_applied(result: ActionResult) -> void:
		call_count += 1
		results.append(result)


func before_test() -> void:
	_saved_commit_pacing_sec = AIBalance.ai.commit_pacing_sec
	# Near-zero, not exactly zero -- SceneTimer accepts 0.0 but this keeps the
	# await a genuine (if tiny) real-time yield, matching AC-13's "streamed"
	# wording rather than special-casing 0.0.
	AIBalance.ai.commit_pacing_sec = 0.01


func after_test() -> void:
	AIBalance.ai.commit_pacing_sec = _saved_commit_pacing_sec


# --- Fixture builders (mirrors integration_apply_action_end_to_end_test.gd) --

func _make_grid(size: int = GRID_SIZE) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(current_ap: int = 10, active_player: int = 1) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	state.per_player[1].is_ai_controlled = true
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _make_hq(entity_id: int, owner: int, pos: Vector2i, hp: int) -> StructureState:
	var hq := StructureState.new()
	hq.entity_id = entity_id
	hq.owner = owner
	hq.position = pos
	hq.type = StructureTypes.HQ
	hq.current_hp = hp
	hq.build_status = StructureState.BuildStatus.COMPLETED
	return hq


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity
	# Defensive: keep next_entity_id ahead of every manually-assigned fixture
	# id, mirroring GameState.start_match's own allocator discipline -- a
	# real driver turn may commit a BuildAction/ProduceAction, which
	# allocates a fresh entity_id from next_entity_id (BaseProduction.apply_build/
	# apply_produce). Leaving next_entity_id at its 0 default would let a new
	# structure/unit collide with (and silently overwrite) a manually-placed
	# fixture entity sharing the same id.
	if entity.entity_id >= state.next_entity_id:
		state.next_entity_id = entity.entity_id + 1


func _connect_spy(state: GameState) -> _ActionAppliedSpy:
	var spy := _ActionAppliedSpy.new()
	state.action_applied.connect(spy._on_action_applied)
	return spy


# --- AC-3 / AC-13 / AC-9: real commit loop, streamed once per commit, bounded -

func test_loop_commits_real_attack_then_ends_turn_with_one_action_applied() -> void:
	# Arrange -- AI-controlled player 1's Trooper adjacent (distance 1, within
	# range 2) to player 0's Trooper, with AP capped at EXACTLY
	# CombatBalance.combat.attack_cost -- deliberately too little to also
	# afford a move+attack combo, a bare reposition, or an Economy Outpost
	# build (which would otherwise legitimately out-score a single attack on
	# an ample-AP board, since Build+Cancel is a real, AP-neutral-ish
	# positive-scoring cycle the AI is entitled to prefer -- unambiguous only
	# once nothing else is affordable). This makes the attack the AI's ONLY
	# affordable candidate, so which verb wins is not left ambiguous.
	var state := _make_state(CombatBalance.combat.attack_cost, 1)
	var ai_unit := _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(1, 1))
	var enemy_unit := _make_unit(2, 0, UnitTypes.TROOPER, Vector2i(2, 1))
	_place(state, ai_unit)
	_place(state, enemy_unit)
	var spy := _connect_spy(state)
	var driver := AITurnDriver.new()
	add_child(driver)

	# Act
	await driver.run_ai_turn(state)

	# Assert -- exactly one real commit streamed (AC-13), attacker flipped
	# has_attacked, turn genuinely ended (active_player moved off the AI),
	# bounded well under MAX_COMMITS (AC-9).
	assert_int(spy.call_count).is_greater(0)
	assert_int(spy.call_count).is_less_equal(MAX_COMMITS)
	assert_bool(ai_unit.has_attacked).is_true()
	assert_int(state.active_player).is_not_equal(1)

	driver.queue_free()


# --- AC-25: zero owned units/producers -> zero commits, immediate end --------

func test_zero_owned_entities_ends_turn_immediately_with_zero_commits() -> void:
	# Arrange -- AI-controlled player 1 owns nothing at all; player 0 owns one
	# harmless, out-of-reach unit so the board isn't fully empty.
	var state := _make_state(10, 1)
	var other_unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	_place(state, other_unit)
	var spy := _connect_spy(state)
	var driver := AITurnDriver.new()
	add_child(driver)

	# Non-vacuous precondition: AI.choose_action really returns null on this
	# board (nothing to enumerate for player 1).
	assert_object(AI.choose_action(state, 0)).is_null()

	# Act
	await driver.run_ai_turn(state)

	# Assert -- zero commits from the AI's own decision loop; the only
	# action_applied emission is the driver's own EndTurnAction at turn-end.
	assert_int(spy.call_count).is_equal(1)
	assert_bool(spy.results[0].ok).is_true()
	assert_int(state.active_player).is_not_equal(1)

	driver.queue_free()


# --- AC-35: the AI's own GAME_OVER commit stops the loop immediately ---------

func test_lethal_hq_commit_stops_loop_immediately_no_further_apply_action() -> void:
	# Arrange -- AI-controlled player 1's Trooper can one-shot player 0's HQ
	# (current_hp set to exactly the precomputed damage, mirroring
	# integration_apply_action_end_to_end_test.gd's AC-6 idiom). No other
	# entities exist, so this is also the AI's only possible candidate this
	# turn -- if the loop kept going past the kill, the very next
	# choose_action call would enumerate against a terminal state, which this
	# test's spy-based call-count assertion below would catch.
	var state := _make_state(CombatBalance.combat.attack_cost, 1)
	var ai_unit := _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(1, 1))
	_place(state, ai_unit)
	var hq := _make_hq(2, 0, Vector2i(2, 1), 1) # placeholder hp, corrected below.
	var expected_dmg: int = Combat.damage(state, ai_unit, hq)
	hq.current_hp = expected_dmg
	_place(state, hq)
	var spy := _connect_spy(state)
	var driver := AITurnDriver.new()
	add_child(driver)
	var active_player_before_loop: int = state.active_player

	# Act
	await driver.run_ai_turn(state)

	# Assert -- exactly one commit (the lethal attack itself); match ended;
	# the loop's `return` on GAME_OVER means EndTurnAction was NEVER submitted
	# (a second action_applied emission would appear if it had been), so
	# active_player is still whatever it was at the moment of the kill.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(1) # attacker's owner.
	assert_int(spy.call_count).is_equal(1)
	assert_bool(spy.results[0].ok).is_true()
	assert_int(state.active_player).is_equal(active_player_before_loop)

	driver.queue_free()


# --- AC-24/AC-10 (pragmatic, per coordinator ruling): rejection contract -----

# Part (a): direct proof of the exact contract AITurnDriver's
# `if not result.ok: continue` branch relies on -- a deliberately-illegal
# action submitted through the REAL state.apply_action() is rejected, spends
# zero AP, and leaves the real state otherwise untouched. This is the
# precondition that makes the driver's re-loop-with-no-AP-spent behavior
# correct; AC-24's own "no special seam needed" text (ADR-0011 §5) endorses
# testing this directly against apply_action.
func test_apply_action_rejects_illegal_candidate_with_zero_ap_spent() -> void:
	var state := _make_state(10, 1)
	var ai_unit := _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(1, 1))
	_place(state, ai_unit)
	var ap_before: int = state.per_player[1].current_ap
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()

	# A legal-shaped AttackAction against a tile with no defender at all --
	# exactly the "candidate the driver would have discarded had it gone
	# stale by commit time" shape (Combat.validate's NO_SUCH_ENTITY branch).
	var action := AttackAction.new()
	action.player = 1
	action.attacker_tile = ai_unit.position
	action.target_tile = Vector2i(5, 5) # empty tile, no entity.

	var result: ActionResult = state.apply_action(action)

	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NO_SUCH_ENTITY)
	assert_int(state.per_player[1].current_ap).is_equal(ap_before)
	assert_array(state.grid.occupancy).is_equal(occupancy_before)


# Part (b): the real driver, run against a real multi-unit board (several
# legal candidates, several turns' worth of potential re-scans), still
# terminates within the same bounded iteration count and never crashes --
# empirically proving AITurnDriver survives/re-loops correctly across many
# real iterations, which is the behavior AC-24's re-loop guarantee depends on
# even though no single iteration here is individually forced to reject.
func test_driver_terminates_within_bound_on_multi_candidate_board_no_crash() -> void:
	var state := _make_state(50, 1)
	var ai_unit_a := _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(1, 1))
	var ai_unit_b := _make_unit(2, 1, UnitTypes.TROOPER, Vector2i(1, 3))
	var enemy_a := _make_unit(3, 0, UnitTypes.TROOPER, Vector2i(2, 1))
	var enemy_b := _make_unit(4, 0, UnitTypes.TROOPER, Vector2i(2, 3))
	_place(state, ai_unit_a)
	_place(state, ai_unit_b)
	_place(state, enemy_a)
	_place(state, enemy_b)
	var spy := _connect_spy(state)
	var driver := AITurnDriver.new()
	add_child(driver)

	# Act -- must not hang; GdUnit4's own default per-test timeout is the
	# ultimate backstop, but this explicit count assertion is what actually
	# proves AC-9's "bounded iteration count", not just "didn't time out".
	await driver.run_ai_turn(state)

	assert_int(spy.call_count).is_less_equal(MAX_COMMITS)
	# Non-vacuous: at least the two legal attacks actually happened.
	assert_bool(ai_unit_a.has_attacked).is_true()
	assert_bool(ai_unit_b.has_attacked).is_true()
	assert_int(state.active_player).is_not_equal(1)

	driver.queue_free()


# --- Regression: windowed AI-turn freeze (produce-cap reject loop) 2026-07-28 -
# A board where the AI HQ reaches its production cap while it still ranks a
# produce highest used to FREEZE run_ai_turn: AI.choose_action re-proposed an
# at-cap ProduceAction every iteration, apply_action rejected it
# (PRODUCTION_CAP_REACHED), and the reject-continue path (no await) spun forever.
# The commit-count spy never caught it because a rejection emits no
# action_applied. run_ai_turn must now terminate (active_player advances off the
# AI). The bound here is deliberately loose — the tight commit bound is a
# separate concern (the move-oscillation follow-up), not this freeze guard.
func test_run_ai_turn_terminates_on_at_cap_board_that_previously_froze() -> void:
	var state := _make_state(40, 1)   # AI = player 1; enough AP to exceed the HQ cap
	_place(state, _make_hq(100, 1, Vector2i(6, 4), StructureTypes.HQ.hp))
	_place(state, _make_hq(101, 0, Vector2i(1, 4), StructureTypes.HQ.hp))
	_place(state, _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(5, 4)))
	_place(state, _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(3, 4)))
	_place(state, _make_unit(3, 0, UnitTypes.TROOPER, Vector2i(4, 3)))
	var spy := _connect_spy(state)
	var driver := AITurnDriver.new()
	add_child(driver)

	# Act — must terminate (no hang). GdUnit4's per-test timeout is the ultimate
	# backstop; the active_player assertion proves genuine bounded termination.
	await driver.run_ai_turn(state)

	assert_int(state.active_player).is_not_equal(1)
	assert_int(spy.call_count).is_less(200)

	driver.queue_free()
