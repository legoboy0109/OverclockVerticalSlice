# Story 008: Integration — Real apply_action End-to-End.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-008-integration-apply-action-end-to-end.md
# (TR-combat-005 integration half, TR-combat-008 end-to-end composition):
#
#   AC-1 (atomic commit): a legal, affordable AttackAction submitted via
#     state.apply_action() -> AP pool, has_attacked, and target current_hp all
#     reflect one atomic commit.
#   AC-2 (unaffordable attack, real state untouched): an AttackAction submitted
#     with insufficient real AP -> ok == false, reason == CANT_AFFORD, and the
#     real AP pool / Grid / target hp are all unchanged.
#   AC-3 (move-then-attack AND attack-then-move, both orders): a unit with
#     enough AP for both a move and an attack this turn -> both orders succeed
#     via apply_action with identical final AP (move_cost + attack_cost).
#   AC-4 (HQ destruction -> GameOver -> lockout, real pipeline): an HQ-stand-in
#     (StructureState stub, is_hq_flag = true) at current_hp == the attacker's
#     precomputed Combat.damage() -> the killing AttackAction resolves via
#     apply_action, match_status becomes GAME_OVER with the correct winner in
#     the same call, and a SECOND apply_action (either player) is rejected
#     GAME_OVER with empty events. Mirrors
#     tests/unit/win_check_terminal_test.gd's
#     test_hq_destroyed_through_apply_action_end_to_end_... shape, but driven
#     by the REAL Combat pipeline (already registered by
#     GameState._ensure_dispatch_registered) instead of a throwaway verb.
#   AC-5 (real-Grid LoF): a real 3-tile cardinal line in a real GridState —
#     attacker at distance 0, a FRIENDLY ally at distance 1, an ENEMY at
#     distance 2 — with a Trooper (attack_range 2) as attacker: the ally
#     genuinely blocks the shot via real GridState.occupant_at/terrain_at,
#     proven both via Combat.legal_targets() (no target for the enemy) and via
#     apply_action/validate() rejecting an AttackAction at the enemy
#     (ILLEGAL_TARGET).
#   AC-6 (counter visible in authoritative state post-apply_action): reuses
#     Story 006's counter-fixture shape (a throwaway can_counterattack = true
#     UnitTypeDef) but drives it through state.apply_action(attack_action)
#     instead of a direct Combat.apply() call — both target.current_hp
#     (primary) and the original attacker's current_hp (counter) are asserted
#     directly off state.entities_by_id after apply_action returns.
#
#   Also (orchestration coverage beyond the 6 ACs, code-review follow-up):
#     apply_action's step-2 active-player gate (Action.Reason.NOT_ACTIVE_PLAYER)
#     is unique to the real apply_action pipeline — no direct-Combat.apply()
#     unit test in tests/unit/combat/ can reach it — so it is exercised here
#     with an otherwise-legal/affordable attack submitted by the non-active
#     player. AC-4's lockout test also asserts BOTH the still-active player
#     (0, the unambiguous lockout proof, since apply_action's GameOver gate
#     runs before its active-player gate) and the non-active player (1) are
#     rejected GAME_OVER post-GameOver, per AC-4's "either side" wording.
#
# This story adds no new production code (see the story's Out of Scope note)
# unless a genuine composition bug surfaces in Stories 001-007's code — none
# was found; every AC composes correctly through the real
# GameState.apply_action() -> Movement/Combat.validate()/apply() dispatch,
# already registered by GameState._ensure_dispatch_registered() (Combat
# Resolution Story 004 registered Action.Verb.ATTACK; the Movement epic
# registered Action.Verb.MOVE — no new registration is needed here).
#
# Uses GameStateFactory.make_state() for the per-player/AP skeleton, plus a
# real GridState (mirrors tests/integration/movement/movement_determinism_test.gd's
# _make_blank_grid pattern) and real UnitTypes.SCOUT/.TROOPER/.HEAVY/.SNIPER
# roster entities — the Integration gate's point: real registry-backed data,
# not injected doubles, except where the story explicitly calls for the
# StructureState test stub (AC-4) or a throwaway can_counterattack=true
# UnitTypeDef fixture (AC-6, mirroring counterattack_test.gd's
# _make_counter_type()).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders (mirrors movement_determinism_test.gd / destroy_entity_test.gd) -

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


# Builds a GameState with a real blank grid and both players' AP set.
func _make_state(current_ap: int = 10) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _attack(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


func _move(from: Vector2i, to: Vector2i, tiles_entered: int, player: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = player
	action.from = from
	action.to = to
	action.tiles_entered = tiles_entered
	return action


# A real StructureState HQ fixture claiming the real StructureTypes.HQ
# template identity (ADR-0007/Story 001: is_hq() == type == StructureTypes.HQ,
# a Resource-ref check against the real, immutable HQ const). The real HQ's
# own hp (40) comfortably exceeds every [param hp] this suite passes, so the
# inline clamp ceiling never interferes; [param hp] only sets current_hp
# (a per-instance field), never the shared template's hp.
func _make_hq(entity_id: int, owner: int, pos: Vector2i, hp: int) -> StructureState:
	var hq := StructureState.new()
	hq.entity_id = entity_id
	hq.owner = owner
	hq.position = pos
	hq.type = StructureTypes.HQ
	hq.current_hp = hp
	return hq


# A throwaway DIRECT UnitTypeDef fixture with can_counterattack = true --
# mirrors counterattack_test.gd's _make_counter_type() pattern (every real VS
# roster UnitTypeDef ships can_counterattack = false).
func _make_counter_type(hp: int = 10, attack: int = 4, attack_range: int = 1) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "CounterTestFixture"
	type.hp = hp
	type.attack = attack
	type.attack_range = attack_range
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = 0
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	type.can_counterattack = true
	return type


# --- AC-1: atomic commit via real apply_action -------------------------------

func test_legal_affordable_attack_via_apply_action_commits_atomically() -> void:
	# Arrange -- Heavy (atk 5, range 2) at (0,0) attacks a Trooper (hp 6) at
	# distance 1; both real roster types via UnitTypes. Non-lethal (6 - 5 = 1)
	# so the target survives to have its post-commit hp asserted.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var trooper := _make_unit(2, 1, UnitTypes.TROOPER, Vector2i(1, 0))
	_place(state, heavy)
	_place(state, trooper)
	var expected_dmg: int = Combat.damage(state, heavy, trooper)
	var action := _attack(heavy.position, trooper.position, 0)

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- one atomic commit: ok, AP spent, has_attacked flipped, target hp
	# reduced by exactly the expected damage, all read off the real state.
	assert_bool(result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_true()
	assert_int((state.entities_by_id[2] as UnitState).current_hp).is_equal(trooper.type.hp - expected_dmg)


# --- AC-2: unaffordable attack leaves the real state untouched ---------------

func test_unaffordable_attack_via_apply_action_rejected_state_unchanged() -> void:
	# Arrange -- attacker has less AP than CombatBalance.combat.attack_cost.
	var state := _make_state(CombatBalance.combat.attack_cost - 1)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var scout := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, scout)
	var ap_before: int = state.per_player[0].current_ap
	var scout_hp_before: int = scout.current_hp
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var action := _attack(trooper.position, scout.position, 0)

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- rejected, CANT_AFFORD, and every real sub-system is byte-for-byte
	# unchanged: AP pool, Grid occupancy, target hp, has_attacked.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_int((state.entities_by_id[2] as UnitState).current_hp).is_equal(scout_hp_before)
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_false()
	assert_array(state.grid.occupancy).is_equal(occupancy_before)


# --- AC-3: move-then-attack AND attack-then-move, both orders ----------------

# Trooper: move_cost 2, attack_cost (CombatBalance.combat.attack_cost) 2 ->
# needs exactly 4 AP for both this turn. Order: MoveAction first, then
# AttackAction — both via apply_action.
func test_move_then_attack_both_succeed_same_turn_correct_ap() -> void:
	# Arrange -- Trooper starts with exactly move_cost + attack_cost AP.
	var starting_ap: int = UnitTypes.TROOPER.move_cost + CombatBalance.combat.attack_cost
	var state := _make_state(starting_ap)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	# Scout placed on the cardinal line EAST of the post-move tile (1,0), at
	# distance 2 (within the Trooper's range-2 DIRECT profile). (2,0) is empty
	# between them, so the DIRECT walk reaches the Scout as the first blocker.
	# NOT a diagonal (which DIRECT targeting — 4 cardinals only — never hits).
	var scout := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, trooper)
	_place(state, scout)

	# Act -- move one tile (0,0)->(1,0), then attack the Scout at distance 2.
	var move_result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))
	var attack_result: ActionResult = state.apply_action(_attack(Vector2i(1, 0), Vector2i(3, 0), 0))

	# Assert -- both succeed; final AP == starting - move_cost - attack_cost == 0.
	assert_bool(move_result.ok).is_true()
	assert_bool(attack_result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(1, 0))


# Same unit/AP budget, reverse order: AttackAction first, then MoveAction — in
# a SEPARATE state, proving GDD Rule 2 ("movement is never gated by
# has_attacked, attacking never sets movement state").
func test_attack_then_move_both_succeed_same_turn_correct_ap_same_as_reverse_order() -> void:
	# Arrange -- identical Trooper/Scout setup, independent state.
	var starting_ap: int = UnitTypes.TROOPER.move_cost + CombatBalance.combat.attack_cost
	var state := _make_state(starting_ap)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var scout := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, scout)

	# Act -- attack the Scout at distance 2 first, then move one tile.
	var attack_result: ActionResult = state.apply_action(_attack(Vector2i(0, 0), Vector2i(2, 0), 0))
	var move_result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(0, 1), 1, 0))

	# Assert -- both succeed regardless of order; same final AP as the
	# move-then-attack test (0) — attacking never gated the move.
	assert_bool(attack_result.ok).is_true()
	assert_bool(move_result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(0, 1))
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_true()


# --- AC-4: HQ destruction -> GameOver -> lockout, real pipeline --------------

func test_hq_destroyed_through_real_combat_pipeline_sets_game_over_and_next_action_rejected() -> void:
	# Arrange -- a Trooper attacks an HQ-stand-in whose current_hp equals the
	# attacker's precomputed Combat.damage() -- the killing blow.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var hq := _make_hq(2, 1, Vector2i(1, 0), 1) # placeholder hp, corrected below
	var expected_dmg: int = Combat.damage(state, trooper, hq)
	# Exactly-lethal HQ: set the PER-INSTANCE current_hp only. Never write
	# hq.type.hp — hq.type is the shared, immutable StructureTypes.HQ registry
	# const (ADR-0007 / control-manifest "never mutate registry consts"), and the
	# real HQ hp (40) is only a non-interfering ceiling here since expected_dmg <= 40.
	hq.current_hp = expected_dmg
	_place(state, hq)
	var action := _attack(trooper.position, hq.position, 0)

	# Act -- the real Combat.validate/apply pipeline (already registered by
	# GameState._ensure_dispatch_registered), no throwaway verb.
	var result: ActionResult = state.apply_action(action)

	# Assert -- the killing action succeeds and GameOver is set in the SAME call.
	assert_bool(result.ok).is_true()
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0) # attacker's owner
	var saw_game_over := false
	for e: Event in result.events:
		if e is GameOverEvent:
			saw_game_over = true
			assert_int(e.winner).is_equal(0)
	assert_bool(saw_game_over).is_true()

	# Assert -- a SECOND apply_action from the STILL-ACTIVE player (0) is
	# rejected GAME_OVER. This is the unambiguous lockout proof: apply_action's
	# step 1 (GameOver gate) runs BEFORE step 2 (active-player gate), so a
	# player=0 submission can only be rejected by the lockout itself — a
	# player=1 submission alone would be ambiguous (it could be blocked by
	# either the lockout OR the ordinary NOT_ACTIVE_PLAYER gate, since
	# active_player is still 0 with no EndTurnAction submitted).
	var active_player_action := _attack(trooper.position, hq.position, 0)
	var active_player_result: ActionResult = state.apply_action(active_player_action)
	assert_bool(active_player_result.ok).is_false()
	assert_int(active_player_result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(active_player_result.events).is_empty()

	# Assert -- per AC-4's "either side" wording, the non-active player (1) is
	# also rejected GAME_OVER (the lockout gate runs before the active-player
	# gate either way, so this holds for both players).
	var other_player_action := _attack(trooper.position, hq.position, 1)
	var other_player_result: ActionResult = state.apply_action(other_player_action)
	assert_bool(other_player_result.ok).is_false()
	assert_int(other_player_result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(other_player_result.events).is_empty()


# --- AC-5: real-Grid LoF ------------------------------------------------------

# A real 3-tile cardinal line: attacker at (0,0), a FRIENDLY ally at (1,0)
# (distance 1), an ENEMY at (2,0) (distance 2), attacker a Trooper (range 2).
# The ally is the first occupied tile on the line -> BLOCKED_BY_FRIENDLY;
# the enemy beyond it is never reachable.
func test_real_grid_ally_blocks_line_of_fire_to_enemy_beyond() -> void:
	# Arrange.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var ally := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0)) # same owner (0) — friendly
	var enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0)) # owner 1 — enemy
	_place(state, trooper)
	_place(state, ally)
	_place(state, enemy)

	# Act 1 -- Combat.legal_targets() against the real grid.
	var targets: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)

	# Assert 1 -- the enemy at distance 2 is NOT a legal target (blocked by the
	# real ally's occupancy); only the enemy id would appear if LoF were
	# (wrongly) ignored, so its absence proves the real grid walk blocked it.
	var found_enemy := false
	for tr: Combat.TargetResult in targets:
		if tr.target_id == enemy.entity_id:
			found_enemy = true
	assert_bool(found_enemy).is_false()

	# Act 2 -- route the identical scenario through apply_action/validate().
	var action := _attack(trooper.position, enemy.position, 0)
	var result: ActionResult = state.apply_action(action)

	# Assert 2 -- rejected ILLEGAL_TARGET; the real grid's occupant_at/terrain_at
	# is what produced this, not a fixture stand-in.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)


# --- Orchestration coverage beyond the 6 ACs: apply_action's step-2 active- --
# --- player gate (Action.Reason.NOT_ACTIVE_PLAYER), unique to the real -------
# --- apply_action pipeline — no direct-Combat.apply() unit test can reach it -

func test_action_from_non_active_player_rejected_not_active_player() -> void:
	# Arrange -- a normal IN_PROGRESS state, active_player == 0. The attacker
	# (Trooper) is owned by player 1 -- the NON-active player -- and the attack
	# is otherwise fully legal/affordable (player 1 has AP, the Scout target
	# sits on the attacker's cardinal line at distance 1, well within the
	# Trooper's range-2 DIRECT profile) so the ONLY possible rejection reason
	# is the step-2 active-player gate, never CANT_AFFORD or ILLEGAL_TARGET
	# leaking in and giving a false pass.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 1, UnitTypes.TROOPER, Vector2i(0, 0)) # owner 1
	var scout := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0))     # owner 0 (enemy of player 1)
	_place(state, trooper)
	_place(state, scout)
	var action := _attack(trooper.position, scout.position, 1) # player = 1, non-active

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- rejected at the active-player gate, before validate() ever runs.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NOT_ACTIVE_PLAYER)
	assert_array(result.events).is_empty()


# --- AC-6: counter visible in authoritative state post-apply_action ----------

func test_counterattack_visible_in_authoritative_state_after_apply_action() -> void:
	# Arrange -- Trooper (atk 3, range 2) attacks a can_counterattack=true
	# defender (hp 10, atk 4, range 1) at distance 1 -- inside both profiles.
	# Defender survives the primary hit and counters back for free.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 4, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, defender)
	var expected_primary_dmg: int = Combat.damage(state, trooper, defender)
	var expected_counter_dmg: int = Combat.damage(state, defender, trooper)
	var action := _attack(trooper.position, defender.position, 0)

	# Act -- through the real apply_action round-trip, not a direct Combat.apply().
	var result: ActionResult = state.apply_action(action)

	# Assert -- both primary and counter hp changes are readable directly off
	# state.entities_by_id after apply_action returns (authoritative state, not
	# just result.events).
	assert_bool(result.ok).is_true()
	var target_after: UnitState = state.entities_by_id[2]
	var attacker_after: UnitState = state.entities_by_id[1]
	assert_int(target_after.current_hp).is_equal(counter_type.hp - expected_primary_dmg)
	assert_int(attacker_after.current_hp).is_equal(UnitTypes.TROOPER.hp - expected_counter_dmg)
