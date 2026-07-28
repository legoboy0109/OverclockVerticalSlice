# Story 010: Integration — apply_action End-to-End (Real Grid + AP + Turn
# Manager + Unit + Combat).
#
# Covers every acceptance criterion in
# production/epics/base-production/story-010-integration-apply-action-end-to-end.md
# (TR-baseprod-004, the real apply_action commit, exercised end-to-end):
#
#   AC-1 (build atomicity): a BuildAction(Economy Outpost) submitted via the
#     real state.apply_action() with exactly effective_build_cost AP -> AP
#     spent + the structure placed Under-Construction on the real Grid +
#     entities_by_id, one atomic commit. A second, independent state submits
#     an unaffordable build (AP one short of cost) -> ok == false,
#     CANT_AFFORD, and the real AP pool + Grid occupancy are byte-for-byte
#     unchanged.
#   AC-2 (Rule-6 income ordering, the headline proof): a player owns two
#     already-COMPLETED Economy Outposts (income this reflects == the tier1
#     formula for n=2) plus a third Economy Outpost with
#     build_turns_remaining == 1. The REAL state.start_turn(owner) is called
#     (start_turn's own step 3 -- BaseProduction.advance_build_timers -- runs
#     strictly before its step 4 -- AP.reset_turn's income snapshot); the
#     SAME call's post-snapshot income/breakdown already reflects n=3, i.e.
#     the tier1-formula delta for the just-completed 3rd outpost, never
#     requiring a second start_turn to see it. A second, independent test
#     proves the batch case: two Economy Outposts both reaching
#     build_turns_remaining == 1 the same start_turn both complete and both
#     count in that same call's income. Every expected value is derived from
#     Balance.economy's real fields (base_income, outpost_bonus_tier1,
#     outpost_bonus_tier2, tier_threshold) via AP.income/ap_income_breakdown
#     -- never a bare literal.
#   AC-3 (real production): a real COMPLETED Production Outpost ->
#     ProduceAction(Trooper, adjacent tile) via apply_action -> a real
#     UnitState entity exists on the tile, immediately Active: has_attacked
#     == false and Unit.can_attack() == true (selectable this same turn, no
#     summoning sickness, Unit Rule 2).
#   AC-4 (real structure fire): a real COMPLETED Defensive Structure (attack
#     4, attack_range 2) fires via the real Combat.attack() pipeline
#     (structure-as-attacker, ADR-0010/0017) at a real enemy Scout at
#     distance 2 on a real DIRECT cardinal line, through apply_action -> the
#     target's hp drops by exactly Combat.damage(...) computed with the
#     structure's own effective_attack == type.attack == 4 (never the flat
#     unit attack_cost/value).
#   AC-5 (real counter): a real Trooper (atk 3, range 2) attacks a real
#     COMPLETED Defensive Structure (can_counterattack == true per the VS
#     roster .tres) at distance 1, non-lethal -> the free uncosted counter
#     fires through Combat's real counter step in the same apply_action
#     commit; both the target's post-primary-hit hp and the original
#     attacker's post-counter hp are asserted directly off
#     state.entities_by_id.
#   AC-6 (real HQ win): a real HQ (_make_hq, StructureTypes.HQ identity) at
#     current_hp == the attacker's precomputed Combat.damage() -> the killing
#     AttackAction resolves via apply_action, match_status flips to GAME_OVER
#     with the correct winner and a GameOverEvent in the SAME call; a SECOND
#     apply_action is rejected Action.Reason.GAME_OVER with empty events for
#     BOTH the still-active player and the other player (mirrors the combat
#     epic's AC-4 sibling exactly).
#   AC-7 (Under-Construction destroyed, no refund): a real Under-Construction
#     structure is force-destroyed via the real state.destroy_entity(id) (the
#     combat/forced-destruction terminal exit, ADR-0010/0017 D1) -> removed
#     from the real Grid + entities_by_id that same step, and the owner's AP
#     is completely UNCHANGED -- the explicit contrast with Story 005's
#     voluntary CancelBuildAction refund, which this story never calls here.
#   AC-8 (live re-legalization): an enemy structure enforcing the D3 standoff
#     (strict manhattan > 2 from every enemy structure, ADR-0017 D3) excludes
#     specific nearby tiles from legal_build_tiles; state.destroy_entity()
#     removes that enemy structure; a later, independent legal_build_tiles
#     call sees the previously-excluded tiles as legal again -- proving the
#     query is live/never cached, not merely re-derived from a stored set.
#
# Pattern mirrored from
# tests/integration/combat/combat_apply_action_integration_test.gd: its
# fixture-builder style (_make_grid/_make_state via
# GameStateFactory.make_state(2, 0)/_make_unit/_place/_make_hq using
# StructureTypes.HQ), its real-registry-types discipline (StructureTypes.*/
# UnitTypes.* from the live .tres roster, never injected doubles except the
# one real-registry-mandated StructureState HQ stand-in), and its "assert off
# the real state.entities_by_id/per_player after apply_action returns"
# convention. No pure-verb-handler call is ever made directly here (Out of
# Scope: Stories 002-007's pure-slice logic) -- every mutation in this suite
# drives through the real state.apply_action()/state.start_turn()/
# state.destroy_entity() orchestrator entry points.
#
# This story adds no new production code (see the story's Out of Scope
# note) unless a genuine composition bug surfaces in Stories 001-007's real
# stack -- none was found; every AC composes correctly through the real
# GameState.apply_action() -> BaseProduction/Combat validate()/apply()
# dispatch, already registered by GameState._ensure_dispatch_registered()
# (Base & Production Stories 002/004/005 registered
# Action.Verb.BUILD/PRODUCE/CANCEL_BUILD; the Combat Resolution epic
# registered Action.Verb.ATTACK -- no new registration is needed here).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state; Research.reset() runs before/after every test so no
# leaked stubbed tech term crosses into another suite sharing the same
# process (mirrors tests/unit/base-production/*_test.gd's isolation
# convention), even though this suite never itself sets a Research stub
# value. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


func before_test() -> void:
	Research.reset()


func after_test() -> void:
	Research.reset()


# --- Fixture builders (mirrors combat_apply_action_integration_test.gd) ------

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


# Builds a GameState with a real blank grid, both players' AP set, and both
# players pinned to Factions.NEUTRAL (make_state otherwise leaves faction
# null, which Unit.effective_produce_cost/BaseProduction's effective_* folds
# would dereference) -- mirrors produce_legal_deploy_tiles_test.gd's
# _make_state idiom.
func _make_state(current_ap: int = 10) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, status: int, build_turns_remaining: int = 0) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = status
	structure.build_turns_remaining = build_turns_remaining
	return structure


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _attack(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


func _build(structure_type: StructureTypeDef, tile: Vector2i, player: int) -> BuildAction:
	var action := BuildAction.new()
	action.player = player
	action.structure_type = structure_type
	action.tile = tile
	return action


func _produce(producer_id: int, unit_type: UnitTypeDef, tile: Vector2i, player: int) -> ProduceAction:
	var action := ProduceAction.new()
	action.player = player
	action.producer_id = producer_id
	action.unit_type = unit_type
	action.tile = tile
	return action


# A real StructureState HQ fixture claiming the real StructureTypes.HQ
# template identity (ADR-0007/Story 001: is_hq() == type == StructureTypes.HQ,
# a Resource-ref check against the real, immutable HQ const) -- mirrors
# combat_apply_action_integration_test.gd's _make_hq exactly. The real HQ's
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
	hq.build_status = StructureState.BuildStatus.COMPLETED
	return hq


# --- AC-1: build atomicity via real apply_action -----------------------------

func test_build_with_exact_ap_via_apply_action_commits_atomically() -> void:
	# Arrange -- exactly effective_build_cost AP for an Economy Outpost, one
	# friendly unit adjacent to the target tile so it is in legal_build_tiles.
	var state := _make_state(0)
	var anchor := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	_place(state, anchor)
	var cost: int = BaseProduction.effective_build_cost(state, StructureTypes.ECONOMY_OUTPOST, 0)
	state.per_player[0].current_ap = cost
	var target_tile := Vector2i(1, 0) # manhattan==1 from the anchor.
	# Non-vacuous precondition: the tile is actually legal before we act.
	assert_bool(target_tile in BaseProduction.legal_build_tiles(state, 0, StructureTypes.ECONOMY_OUTPOST)).is_true()
	var action := _build(StructureTypes.ECONOMY_OUTPOST, target_tile, 0)

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- one atomic commit: ok, AP fully spent, a real StructureState
	# placed Under-Construction, visible both on the real Grid and in
	# entities_by_id.
	assert_bool(result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	var placed_id: int = state.grid.occupant_at(target_tile.x, target_tile.y)
	assert_int(placed_id).is_not_equal(GridState.EMPTY_OCCUPANT)
	var placed: StructureState = state.entities_by_id[placed_id]
	assert_object(placed.type).is_same(StructureTypes.ECONOMY_OUTPOST)
	assert_int(placed.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	# ... and the commit emitted a StructurePlacedEvent for the new structure
	# (event-stream symmetry with AC-7's StructureDestroyedEvent check).
	var saw_placed := false
	for e: Event in result.events:
		if e is StructurePlacedEvent and e.entity_id == placed_id:
			saw_placed = true
			assert_object(e.structure_type).is_same(StructureTypes.ECONOMY_OUTPOST)
			assert_int(e.owner).is_equal(0)
	assert_bool(saw_placed).is_true()


func test_unaffordable_build_via_apply_action_rejected_state_unchanged() -> void:
	# Arrange -- one AP short of effective_build_cost.
	var state := _make_state(0)
	var anchor := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	_place(state, anchor)
	var cost: int = BaseProduction.effective_build_cost(state, StructureTypes.ECONOMY_OUTPOST, 0)
	state.per_player[0].current_ap = cost - 1
	var target_tile := Vector2i(1, 0)
	var ap_before: int = state.per_player[0].current_ap
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var entity_count_before: int = state.entities_by_id.size()
	var action := _build(StructureTypes.ECONOMY_OUTPOST, target_tile, 0)

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- rejected, CANT_AFFORD, real AP + real Grid occupancy
	# byte-for-byte unchanged, no new entity registered.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_array(state.grid.occupancy).is_equal(occupancy_before)
	assert_int(state.entities_by_id.size()).is_equal(entity_count_before)


# --- AC-2: Rule-6 income ordering (the headline proof) -----------------------

func test_outpost_completing_at_real_start_turn_counts_same_turn_income() -> void:
	# Arrange -- player 0 owns two already-COMPLETED Economy Outposts (n=2
	# going in) plus a third Economy Outpost one owner-turn from completion
	# (build_turns_remaining == 1). No grid adjacency matters here -- these
	# structures are placed directly via fixtures, not built through
	# apply_action, since this AC is about start_turn's internal ordering,
	# not the build verb.
	var state := _make_state(0)
	var completed_a := _make_structure(1, 0, Vector2i(0, 0), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	var completed_b := _make_structure(2, 0, Vector2i(1, 0), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.COMPLETED)
	var completing := _make_structure(3, 0, Vector2i(2, 0), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	_place(state, completed_a)
	_place(state, completed_b)
	_place(state, completing)
	state.active_player = 1 # so start_turn(0) below is a genuine active-player switch.

	# Non-vacuous precondition: exactly 2 completed outposts count BEFORE
	# start_turn runs -- proves the pre-turn baseline is real, not zero.
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(2)
	var cfg: EconomyConfig = Balance.economy
	var income_at_n2: int = cfg.base_income \
		+ cfg.outpost_bonus_tier1 * min(2, cfg.tier_threshold) \
		+ cfg.outpost_bonus_tier2 * max(0, 2 - cfg.tier_threshold)
	assert_int(AP.income(state, 0)).is_equal(income_at_n2)

	# Act -- the REAL start-of-turn sequence: step 3 (advance_build_timers)
	# strictly before step 4 (AP.reset_turn's income snapshot), same call.
	var turn_events: Array = state.start_turn(0)

	# Assert -- the 3rd outpost is now COMPLETED (step 3 ran) ...
	assert_int(completing.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(3)
	# ... and step 3 emitted a StructureCompletedEvent for the just-finished
	# outpost (event-stream symmetry; proves the completion is observable on the
	# turn's event array, not only via the derived count).
	var saw_completed := false
	for e: Event in turn_events:
		if e is StructureCompletedEvent and e.entity_id == completing.entity_id:
			saw_completed = true
			assert_object(e.structure_type).is_same(StructureTypes.ECONOMY_OUTPOST)
	assert_bool(saw_completed).is_true()
	# ... and THIS SAME start_turn call's frozen income snapshot already
	# reflects n=3 -- the Rule-6 ordering proof. Derived from Balance.economy's
	# real fields, never a bare literal; tier1 covers n=3 since tier_threshold
	# is 4 in the shipped config (asserted below so this test would fail loud,
	# not silently mis-tier, if that config value ever changes).
	assert_int(cfg.tier_threshold).is_greater_equal(3)
	var income_at_n3: int = cfg.base_income \
		+ cfg.outpost_bonus_tier1 * min(3, cfg.tier_threshold) \
		+ cfg.outpost_bonus_tier2 * max(0, 3 - cfg.tier_threshold)
	assert_int(income_at_n3).is_equal(income_at_n2 + cfg.outpost_bonus_tier1) # the "X + OUTPOST_BONUS_TIER1 this turn" AC wording.
	assert_int(AP.ap_income_breakdown(state, 0)["outpost"]).is_equal(cfg.outpost_bonus_tier1 * min(3, cfg.tier_threshold) + cfg.outpost_bonus_tier2 * max(0, 3 - cfg.tier_threshold))
	assert_int(AP.income(state, 0)).is_equal(income_at_n3)
	assert_int(state.per_player[0].income_this_turn).is_equal(income_at_n3)
	assert_int(state.per_player[0].current_ap).is_equal(income_at_n3)


func test_two_outposts_completing_same_start_turn_both_count() -> void:
	# Arrange -- player 0 owns zero completed outposts going in; two separate
	# Economy Outposts both reach build_turns_remaining == 1 the same turn.
	var state := _make_state(0)
	var completing_a := _make_structure(1, 0, Vector2i(0, 0), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	var completing_b := _make_structure(2, 0, Vector2i(1, 0), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1)
	_place(state, completing_a)
	_place(state, completing_b)
	state.active_player = 1

	# Non-vacuous precondition: zero completed before start_turn.
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(0)

	# Act -- the real start-of-turn sequence, one call.
	state.start_turn(0)

	# Assert -- BOTH completed the same call, both counted the same call's
	# income snapshot (batch-complete, ADR-0017 D1/ADR-0008).
	assert_int(completing_a.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(completing_b.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(BaseProduction.completed_outpost_count(state, 0)).is_equal(2)
	var cfg: EconomyConfig = Balance.economy
	var expected_income: int = cfg.base_income \
		+ cfg.outpost_bonus_tier1 * min(2, cfg.tier_threshold) \
		+ cfg.outpost_bonus_tier2 * max(0, 2 - cfg.tier_threshold)
	assert_int(state.per_player[0].income_this_turn).is_equal(expected_income)


# --- AC-3: real production ----------------------------------------------------

func test_produce_via_apply_action_creates_real_active_selectable_unit() -> void:
	# Arrange -- a real COMPLETED Production Outpost with ample AP.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(0, 0), StructureTypes.PRODUCTION_OUTPOST, StructureState.BuildStatus.COMPLETED)
	_place(state, producer)
	var deploy_tile := Vector2i(1, 0) # manhattan==1 from the producer, empty.
	assert_bool(deploy_tile in BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)).is_true()
	var action := _produce(producer.entity_id, UnitTypes.TROOPER, deploy_tile, 0)

	# Act
	var result: ActionResult = state.apply_action(action)

	# Assert -- a real UnitState entity exists on the tile ...
	assert_bool(result.ok).is_true()
	var unit_id: int = state.grid.occupant_at(deploy_tile.x, deploy_tile.y)
	assert_int(unit_id).is_not_equal(GridState.EMPTY_OCCUPANT)
	var unit: UnitState = state.entities_by_id[unit_id]
	assert_object(unit.type).is_same(UnitTypes.TROOPER)
	assert_int(unit.owner).is_equal(0)
	# ... immediately Active and selectable THIS turn (no summoning sickness,
	# Unit Rule 2): has_attacked is false and Unit.can_attack() reports true.
	assert_bool(unit.has_attacked).is_false()
	assert_bool(Unit.can_attack(unit)).is_true()


# --- AC-4: real structure fire ------------------------------------------------

func test_defensive_structure_fires_via_apply_action_real_damage_formula() -> void:
	# Arrange -- a real COMPLETED Defensive Structure (attack 4, range 2) at
	# (0,0); an enemy Heavy at (2,0) -- distance 2, on the real cardinal DIRECT
	# line, within range and not lethal (Heavy hp 10 comfortably exceeds the
	# structure's damage so the post-hit hp assertion is meaningful).
	var state := _make_state(10)
	var structure := _make_structure(1, 0, Vector2i(0, 0), StructureTypes.DEFENSIVE_STRUCTURE, StructureState.BuildStatus.COMPLETED)
	var enemy := _make_unit(2, 1, UnitTypes.HEAVY, Vector2i(2, 0))
	_place(state, structure)
	_place(state, enemy)
	# Non-vacuous precondition: the structure's own effective_attack really is
	# its type.attack (4) -- the AC's explicit claim, not assumed.
	assert_int(structure.type.attack).is_equal(4)
	var expected_dmg: int = Combat.damage(state, structure, enemy)
	var action := _attack(structure.position, enemy.position, 0)

	# Act -- through the real Combat pipeline via apply_action (structure as
	# attacker, ADR-0010/0017), no throwaway verb.
	var result: ActionResult = state.apply_action(action)

	# Assert -- fired, has_attacked flipped, target hp dropped by exactly the
	# real formula's output computed with the structure's own attack (4).
	assert_bool(result.ok).is_true()
	assert_bool(structure.has_attacked).is_true()
	assert_int((state.entities_by_id[2] as UnitState).current_hp).is_equal(enemy.type.hp - expected_dmg)


# --- AC-5: real counter --------------------------------------------------------

func test_defensive_structure_counters_real_attacker_visible_post_apply_action() -> void:
	# Arrange -- a real Trooper (atk 3, range 2) attacks a real COMPLETED
	# Defensive Structure (can_counterattack == true per the shipped .tres) at
	# distance 1 -- inside both the Trooper's and the structure's own DIRECT
	# range-2 profile. Neither hit is lethal (Trooper hp 6, structure hp 10
	# comfortably absorb one hit each) so both post-hit hps are meaningful.
	var state := _make_state(10)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var structure := _make_structure(2, 1, Vector2i(1, 0), StructureTypes.DEFENSIVE_STRUCTURE, StructureState.BuildStatus.COMPLETED)
	_place(state, trooper)
	_place(state, structure)
	assert_bool(structure.type.can_counterattack).is_true() # non-vacuous: the real roster type really opts in.
	var expected_primary_dmg: int = Combat.damage(state, trooper, structure)
	var expected_counter_dmg: int = Combat.damage(state, structure, trooper)
	var action := _attack(trooper.position, structure.position, 0)

	# Act -- through the real apply_action round-trip, not a direct
	# Combat.apply() call.
	var result: ActionResult = state.apply_action(action)

	# Assert -- both primary and counter hp changes readable directly off
	# state.entities_by_id after apply_action returns (authoritative state).
	assert_bool(result.ok).is_true()
	var structure_after: StructureState = state.entities_by_id[2]
	var trooper_after: UnitState = state.entities_by_id[1]
	assert_int(structure_after.current_hp).is_equal(structure.type.hp - expected_primary_dmg)
	assert_int(trooper_after.current_hp).is_equal(UnitTypes.TROOPER.hp - expected_counter_dmg)


# --- AC-6: real HQ win ---------------------------------------------------------

func test_hq_destroyed_through_real_apply_action_sets_game_over_and_locks_out() -> void:
	# Arrange -- a Trooper attacks a real HQ whose current_hp equals the
	# attacker's precomputed Combat.damage() -- the killing blow.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var hq := _make_hq(2, 1, Vector2i(1, 0), 1) # placeholder hp, corrected below.
	var expected_dmg: int = Combat.damage(state, trooper, hq)
	# Exactly-lethal HQ: set the PER-INSTANCE current_hp only. Never write
	# hq.type.hp -- hq.type is the shared, immutable StructureTypes.HQ registry
	# const (control-manifest "never mutate registry consts"), and the real HQ
	# hp (40) is only a non-interfering ceiling here since expected_dmg <= 40.
	hq.current_hp = expected_dmg
	_place(state, hq)
	var action := _attack(trooper.position, hq.position, 0)

	# Act -- the real BaseProduction/Combat-composed pipeline (structure
	# defender, HQ identity) already registered by
	# GameState._ensure_dispatch_registered.
	var result: ActionResult = state.apply_action(action)

	# Assert -- the killing action succeeds and GameOver is set in the SAME
	# call.
	assert_bool(result.ok).is_true()
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0) # attacker's owner.
	var saw_game_over := false
	for e: Event in result.events:
		if e is GameOverEvent:
			saw_game_over = true
			assert_int(e.winner).is_equal(0)
	assert_bool(saw_game_over).is_true()

	# Assert -- a SECOND apply_action from the STILL-ACTIVE player (0) is
	# rejected GAME_OVER (the unambiguous lockout proof: apply_action's step 1
	# GameOver gate runs before step 2's active-player gate).
	var active_player_result: ActionResult = state.apply_action(_attack(trooper.position, hq.position, 0))
	assert_bool(active_player_result.ok).is_false()
	assert_int(active_player_result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(active_player_result.events).is_empty()

	# Assert -- the non-active player (1) is also rejected GAME_OVER, per the
	# AC's "either side" wording.
	var other_player_result: ActionResult = state.apply_action(_attack(trooper.position, hq.position, 1))
	assert_bool(other_player_result.ok).is_false()
	assert_int(other_player_result.reason).is_equal(Action.Reason.GAME_OVER)
	assert_array(other_player_result.events).is_empty()


# --- AC-7: Under-Construction destroyed, no refund ----------------------------

func test_under_construction_structure_force_destroyed_no_refund() -> void:
	# Arrange -- a real Under-Construction Economy Outpost; the owner holds a
	# known AP balance unrelated to the structure's build_cost, so any
	# (incorrect) refund would visibly change it.
	var state := _make_state(7)
	var structure := _make_structure(1, 0, Vector2i(3, 3), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 2)
	_place(state, structure)
	var ap_before: int = state.per_player[0].current_ap
	# Non-vacuous precondition: the structure genuinely occupies the grid and
	# entities_by_id before destruction.
	assert_int(state.grid.occupant_at(3, 3)).is_equal(structure.entity_id)
	assert_bool(state.entities_by_id.has(structure.entity_id)).is_true()

	# Act -- the real forced-destruction terminal exit (combat-style, never
	# the voluntary CancelBuildAction refund path).
	var events: Array[Event] = state.destroy_entity(structure.entity_id)

	# Assert -- removed from the real Grid + entities_by_id this step ...
	assert_int(state.grid.occupant_at(3, 3)).is_equal(GridState.EMPTY_OCCUPANT)
	assert_bool(state.entities_by_id.has(structure.entity_id)).is_false()
	var saw_destroyed := false
	for e: Event in events:
		if e is StructureDestroyedEvent:
			saw_destroyed = true
			assert_bool(e.is_hq).is_false()
	assert_bool(saw_destroyed).is_true()
	# ... and the owner's AP is completely UNCHANGED -- no refund (the
	# explicit contrast with Story 005's voluntary-cancel refund path, which
	# credits floor(build_cost * cancel_refund_pct / 100) and is never called
	# here).
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)


# --- AC-8: live re-legalization ------------------------------------------------

func test_legal_build_tiles_relegalizes_live_after_enemy_structure_destroyed() -> void:
	# Arrange -- player 0 has a friendly anchor unit at (5,5) so its
	# neighbours are the candidate frontier. An enemy Defensive Structure at
	# (2,5) sits exactly manhattan==2 from the friendly-adjacent candidate tile
	# (4,5), so (4,5) is strictly excluded by the D3 standoff rule (manhattan
	# <= 2 from any enemy structure, ADR-0017 D3) until that structure dies.
	var state := _make_state(0)
	var anchor := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, anchor)
	var enemy_structure := _make_structure(2, 1, Vector2i(2, 5), StructureTypes.DEFENSIVE_STRUCTURE, StructureState.BuildStatus.COMPLETED)
	_place(state, enemy_structure)
	var excluded_tile := Vector2i(4, 5) # manhattan(4,5 -> 2,5) == 2, friendly-adjacent to (5,5).

	# Non-vacuous precondition: the candidate tile is friendly-adjacent (would
	# otherwise be legal) but is excluded BEFORE destruction, proving the
	# standoff rule is actually active, not vacuously passing.
	assert_int(state.grid.manhattan_distance(excluded_tile, enemy_structure.position)).is_equal(2)
	var before: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.ECONOMY_OUTPOST)
	assert_bool(excluded_tile in before).is_false()

	# Act -- destroy the enforcing enemy structure via the real terminal exit.
	state.destroy_entity(enemy_structure.entity_id)

	# Assert -- a fresh, independent legal_build_tiles call now includes the
	# previously-excluded tile -- live re-derivation, never a cached result
	# from the pre-destruction call.
	var after: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.ECONOMY_OUTPOST)
	assert_bool(excluded_tile in after).is_true()
