# Story 008: Lifecycle States + Edge-Case Guards (Summoning Sickness,
# Destroy-on-0, AP Gating).
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-008-lifecycle-edge-cases.md
# (TR-unit-012 — Instance lifecycle Produced->Active->Destroyed, Produced
# presentation-only, no summoning sickness):
#
#   AC-1 (destroy-on-0, integration): a UnitState at current_hp == 0, placed
#     on a real minimal GridState/GameState -- calling GameState.destroy_entity()
#     directly (NOT through Combat.apply(); this story tests the shared hook's
#     general contract for a Unit-System-owned fixture, independent of
#     Combat's pipeline) removes it from entities_by_id and clears its grid
#     tile, synchronously (same call, no deferred removal).
#   AC-2 (no summoning sickness, end-to-end): a unit "produced this turn"
#     (fresh UnitState, has_attacked=false, tiles_moved_this_turn=0 -- Story
#     002's birth defaults) with sufficient AP -- a real MoveAction then a
#     real AttackAction via apply_action() both succeed the same turn; the
#     reverse order (attack then move), in a separate state, also succeeds.
#   AC-3 (attack flag doesn't gate movement): a unit with has_attacked = true
#     and sufficient AP -- a MoveAction via apply_action() succeeds, position
#     changes. Edge: a SECOND attack from that same unit is separately
#     rejected by Combat.validate (already-attacked-this-turn) -- proving the
#     two flags are independent (has_attacked gates attacking, never moving).
#   AC-4 (AP-gated rejection, no credit): an owner with AP strictly less than
#     a candidate move's surcharged total AP cost -- the move is rejected via
#     apply_action(), no AP spent, position unchanged. Boundary: AP == exact
#     cost succeeds; AP == cost - 1 fails.
#
# This story is test authorship over already-shipped mechanics (Unit System
# Stories 002/003, the Combat epic's GameState.destroy_entity(), and the
# already-registered apply_action Move/Attack verb handlers) -- no new
# production code is expected (see the story's Out of Scope section).
#
# Fixture style mirrors tests/integration/combat/combat_apply_action_integration_test.gd
# and tests/integration/movement/movement_determinism_test.gd (_make_grid/
# _make_state/_make_unit/_place/_move/_attack), plus destroy_entity_test.gd's
# assertion style for AC-1. Real UnitTypes.SCOUT/.TROOPER roster entries are
# used throughout -- no fakes/stubs needed since GridState/GameState are
# lightweight concrete Resources built directly in tests project-wide.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders (mirrors combat_apply_action_integration_test.gd /
# --- movement_determinism_test.gd) -------------------------------------------

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


# A fresh "produced this turn" unit -- Story 002's documented birth defaults
# (has_attacked = false, tiles_moved_this_turn = 0), the no-summoning-sickness
# fixture shape.
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


func _move(from: Vector2i, to: Vector2i, tiles_entered: int, player: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = player
	action.from = from
	action.to = to
	action.tiles_entered = tiles_entered
	return action


func _attack(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


# --- AC-1: destroy-on-0, integration -----------------------------------------

func test_destroy_entity_on_zero_hp_unit_removes_from_entities_and_clears_grid_tile() -> void:
	# Arrange -- a UnitState at current_hp == 0 on a real minimal GridState/
	# GameState, placed in both entities_by_id and grid occupancy.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(2, 2))
	unit.current_hp = 0
	_place(state, unit)
	# Sanity precondition -- present before the call.
	assert_bool(state.entities_by_id.has(unit.entity_id)).is_true()
	assert_int(state.grid.occupant_at(unit.position.x, unit.position.y)).is_equal(unit.entity_id)

	# Act -- call GameState.destroy_entity() directly, NOT through Combat.apply().
	var events: Array[Event] = state.destroy_entity(unit.entity_id)

	# Assert -- removed from entities_by_id, tile reads EMPTY_OCCUPANT, all
	# synchronous within this one call (no deferred removal).
	assert_bool(state.entities_by_id.has(unit.entity_id)).is_false()
	assert_int(state.grid.occupant_at(unit.position.x, unit.position.y)).is_equal(GridState.EMPTY_OCCUPANT)
	# The shared hook's UnitDestroyedEvent contract holds for a Unit-System fixture too.
	var found: UnitDestroyedEvent = null
	for e: Event in events:
		if e is UnitDestroyedEvent:
			found = e
	assert_object(found).is_not_null()
	assert_int(found.entity_id).is_equal(unit.entity_id)


func test_destroy_entity_does_not_affect_other_entities_or_tiles() -> void:
	# Arrange -- edge case: destroying one entity must not disturb a second,
	# unrelated live entity elsewhere on the board.
	var state := _make_state()
	var dying := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(2, 2))
	dying.current_hp = 0
	var bystander := _make_unit(2, 1, UnitTypes.TROOPER, Vector2i(5, 5))
	_place(state, dying)
	_place(state, bystander)

	# Act
	state.destroy_entity(dying.entity_id)

	# Assert -- bystander untouched.
	assert_bool(state.entities_by_id.has(bystander.entity_id)).is_true()
	assert_int(state.grid.occupant_at(bystander.position.x, bystander.position.y)).is_equal(bystander.entity_id)


# --- AC-2: no summoning sickness, end-to-end ---------------------------------

func test_fresh_unit_move_then_attack_both_succeed_same_turn() -> void:
	# Arrange -- a Trooper "produced this turn" (birth defaults) with exactly
	# enough AP for a move (cost 2) plus an attack (CombatBalance.combat.attack_cost, 2).
	var starting_ap: int = UnitTypes.TROOPER.move_cost + CombatBalance.combat.attack_cost
	var state := _make_state(starting_ap)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	assert_bool(trooper.has_attacked).is_false()
	assert_int(trooper.tiles_moved_this_turn).is_equal(0)
	# Enemy placed on the cardinal line EAST of the post-move tile (1,0), at
	# distance 2 -- within the Trooper's range-2 DIRECT profile.
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, trooper)
	_place(state, enemy)

	# Act -- move one tile, then attack, same turn, no prior actions.
	var move_result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))
	var attack_result: ActionResult = state.apply_action(_attack(Vector2i(1, 0), Vector2i(3, 0), 0))

	# Assert -- both succeed (no summoning sickness).
	assert_bool(move_result.ok).is_true()
	assert_bool(attack_result.ok).is_true()
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(1, 0))
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_true()


func test_fresh_unit_attack_then_move_both_succeed_same_turn_reversed_order() -> void:
	# Arrange -- SEPARATE state, same fresh-unit AP budget, reversed order:
	# attack first, then move.
	var starting_ap: int = UnitTypes.TROOPER.move_cost + CombatBalance.combat.attack_cost
	var state := _make_state(starting_ap)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	assert_bool(trooper.has_attacked).is_false()
	assert_int(trooper.tiles_moved_this_turn).is_equal(0)
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, enemy)

	# Act -- attack the Scout at distance 2 first, then move one tile.
	var attack_result: ActionResult = state.apply_action(_attack(Vector2i(0, 0), Vector2i(2, 0), 0))
	var move_result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(0, 1), 1, 0))

	# Assert -- both succeed regardless of order (no summoning sickness, either order).
	assert_bool(attack_result.ok).is_true()
	assert_bool(move_result.ok).is_true()
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(0, 1))
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_true()


# --- AC-3: attack flag doesn't gate movement ---------------------------------

func test_unit_with_has_attacked_true_can_still_move_position_changes() -> void:
	# Arrange -- a unit that has already attacked this turn, sufficient AP for
	# a move only (attack is not attempted again in this test's Act step).
	var state := _make_state(UnitTypes.SCOUT.move_cost)
	var scout := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	scout.has_attacked = true
	_place(state, scout)

	# Act -- issue a MoveAction via apply_action().
	var result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))

	# Assert -- succeeds, position changes; has_attacked never gated movement.
	assert_bool(result.ok).is_true()
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(1, 0))
	assert_bool((state.entities_by_id[1] as UnitState).has_attacked).is_true()


func test_unit_with_has_attacked_true_second_attack_rejected_by_can_attack() -> void:
	# Arrange -- edge case named by the story: a second attack from a unit
	# that already attacked this turn is separately rejected by
	# Unit.can_attack/Combat.validate -- the two flags (has_attacked gates
	# attacking, never moving) are independent.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	trooper.has_attacked = true
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)

	# Act -- attempt an AttackAction via apply_action().
	var result: ActionResult = state.apply_action(_attack(Vector2i(0, 0), Vector2i(1, 0), 0))

	# Assert -- rejected (already attacked this turn), enemy hp unchanged.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int((state.entities_by_id[2] as UnitState).current_hp).is_equal(enemy.type.hp)


# --- AC-4: AP-gated rejection, no credit -------------------------------------

# Trooper: move_cost 2, soft_move_cap 3 -- a single-tile move stays well
# inside the soft cap, so its exact AP cost is exactly move_cost (2), giving a
# clean boundary fixture with no surcharge to reason about. move_cost > 1 is
# deliberate here (unlike Scout's move_cost 1): it gives the "strictly less
# than cost" and "cost - 1" boundary cases genuinely distinct AP values (0 vs
# 1) instead of both collapsing to AP 0.

func test_move_rejected_when_ap_strictly_less_than_cost_no_spend_no_move() -> void:
	# Arrange -- AP strictly less than the candidate move's cost (0 AP, cost 2)
	# -- well below the cost, distinct from the cost-1 boundary's AP=1 below.
	var state := _make_state(0)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var ap_before: int = state.per_player[0].current_ap
	var pos_before: Vector2i = trooper.position

	# Act
	var result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))

	# Assert -- rejected, no AP spent (no credit), position unchanged. Reason is
	# ILLEGAL_TARGET rather than CANT_AFFORD here: Movement.validate() checks
	# reachable()-membership first, and reachable()'s BFS early-break (cost >
	# current_ap) means an unaffordable single-tile destination is never even
	# generated into the reachable set -- so Movement.validate()'s later explicit
	# can_afford() check is unreachable for this from->to shape, regardless of
	# the specific move_cost. This story's AC only requires "rejected, no AP
	# spent, position unchanged" -- not a specific Reason code -- so this
	# reflects real (already-shipped) Movement behavior, not a story-008
	# production change.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(pos_before)


func test_move_succeeds_when_ap_exactly_equals_cost_boundary() -> void:
	# Arrange -- AP == exact cost (2).
	var state := _make_state(UnitTypes.TROOPER.move_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)

	# Act
	var result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))

	# Assert -- succeeds, AP fully spent, position changes.
	assert_bool(result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(1, 0))


func test_move_rejected_when_ap_is_cost_minus_one_boundary() -> void:
	# Arrange -- AP == cost - 1 (1, cost is 2) -- the boundary failure case,
	# distinct from the strictly-less-than test's AP=0 above.
	var state := _make_state(UnitTypes.TROOPER.move_cost - 1)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var ap_before: int = state.per_player[0].current_ap
	var pos_before: Vector2i = trooper.position

	# Act
	var result: ActionResult = state.apply_action(_move(Vector2i(0, 0), Vector2i(1, 0), 1, 0))

	# Assert -- rejected, no AP spent, position unchanged. Reason is
	# ILLEGAL_TARGET, not CANT_AFFORD -- see the identical note in
	# test_move_rejected_when_ap_strictly_less_than_cost_no_spend_no_move
	# (reachable()'s BFS early-break means an unaffordable single-tile
	# destination is never generated, so the explicit can_afford() check in
	# Movement.validate() is unreachable for this from->to shape).
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(pos_before)
