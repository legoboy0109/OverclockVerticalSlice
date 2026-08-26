# Story 002: Committed Move (Movement.move() / MoveAction) — full AC coverage.
#
# Covers every acceptance criterion in
# production/epics/movement/story-002-committed-move.md against directly
# constructed GameState/GridState/UnitState fixtures, driven through
# GameState.apply_action(MoveAction) (the real pipeline, exercising dispatch
# registration too) as well as Movement.validate()/apply() directly for finer
# assertions. No RNG, no file I/O beyond preload'd registry consts.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

## Starting AP for the over-cap surcharge cases, seeded directly into the fixture.
##
## ⚠ A FIXTURE VALUE, deliberately NOT `Balance.economy.flat_ap_per_turn`. These tests
## assert that AP spent equals the reported `min_cost`; the starting budget is only an
## input large enough not to interfere. Binding it to the live balance config would make
## a movement suite fail whenever the economy is retuned — and it nearly did, when
## S8-23 took the budget 30 -> 20. Kept here as one named constant so the fixture and its
## assertions cannot drift apart, which is what the bare literal 30 allowed.
const _SURCHARGE_START_AP: int = 30


const GRID_SIZE := 10


# --- Fixture builders (mirrors reachable_search_test.gd) --------------------

func _make_blank_grid(size: int = GRID_SIZE) -> GridState:
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


# In-memory UnitTypeDef with explicit stats (never a preload'd .tres) — needed
# for the boundary ACs that require specific move_cost/soft_move_cap combos.
func _make_type(move_cost: int, soft_move_cap: int) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestType"
	type.hp = 10
	type.attack = 1
	type.attack_range = 1
	type.move_cost = move_cost
	type.soft_move_cap = soft_move_cap
	type.produce_cost = 1
	return type


# Places a UnitState occupant at pos, registers it in state.entities_by_id,
# and writes it into grid occupancy. Returns the created UnitState.
func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: UnitTypeDef, tiles_moved_this_turn: int = 0) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	u.tiles_moved_this_turn = tiles_moved_this_turn
	state.entities_by_id[entity_id] = u
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return u


# Builds a gridded GameState with the given player's current_ap set, both
# players present, and active_player set to owner (so apply_action's step-2
# active-player gate passes for that owner's moves).
func _make_state(owner: int, current_ap: int, grid_size: int = GRID_SIZE) -> GameState:
	var state := GameStateFactory.make_state(2, owner)
	state.per_player[owner].current_ap = current_ap
	state.grid = _make_blank_grid(grid_size)
	return state


func _find(results: Array[Movement.ReachableTile], tile: Vector2i) -> Movement.ReachableTile:
	for r: Movement.ReachableTile in results:
		if r.tile == tile:
			return r
	return null


func _make_move_action(unit: UnitState, to: Vector2i, tiles_entered: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = unit.owner
	action.from = unit.position
	action.to = to
	action.tiles_entered = tiles_entered
	return action


# --- AC-1: in-cap billing (fresh Trooper, move_cost 2, 5 AP, 2-tile move) ---

func test_fresh_trooper_two_tile_move_spends_exactly_four_ap() -> void:
	# Arrange — Trooper: move_cost 2, generous cap so the whole path is in-cap.
	var type := _make_type(2, 10)
	var state := _make_state(0, 5)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Act — commit a 2-tile move via the real pipeline.
	var action := _make_move_action(unit, Vector2i(7, 5), 2)
	var result: ActionResult = state.apply_action(action)

	# Assert — exactly 4 AP spent (1 remains), read via AP.current_ap.
	assert_bool(result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(1)
	assert_int(unit.position.x).is_equal(7)
	assert_int(unit.tiles_moved_this_turn).is_equal(2)


# --- AC-2: unaffordable path rejected ----------------------------------------

func test_unaffordable_three_tile_path_rejected_no_ap_spent_no_position_change() -> void:
	# Arrange — fresh Trooper, soft_move_cap 3, 5 AP; a 3-tile path costs 6 AP
	# (all in-cap: 3 * move_cost 2 = 6), unaffordable with 5 AP.
	var type := _make_type(2, 3)
	var state := _make_state(0, 5)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Cross-check: the destination is absent from reachable() at cost 6.
	var reachable_results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	assert_object(_find(reachable_results, Vector2i(8, 5))).is_null()

	# Act — attempt the 3-tile move via the real pipeline.
	var action := _make_move_action(unit, Vector2i(8, 5), 3)
	var result: ActionResult = state.apply_action(action)

	# Assert — rejected (fails can_afford / illegal target), zero state change.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int(AP.current_ap(state, 0)).is_equal(5)
	assert_vector(unit.position).is_equal(Vector2i(5, 5))
	assert_int(unit.tiles_moved_this_turn).is_equal(0)


# --- AC-3: repeat move allowed, billed off updated tiles_moved_this_turn ----

func test_second_move_after_first_succeeds_and_bills_continuing_from_updated_counter() -> void:
	# Arrange — Trooper move_cost 1, cap 10 (irrelevant to this AC's in-cap
	# focus), 10 AP, fresh.
	var type := _make_type(1, 10)
	var state := _make_state(0, 10)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Act — first move: 2 tiles east.
	var first_action := _make_move_action(unit, Vector2i(7, 5), 2)
	var first_result: ActionResult = state.apply_action(first_action)
	assert_bool(first_result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(8)
	assert_int(unit.tiles_moved_this_turn).is_equal(2)

	# Act — second move: 2 more tiles east, from the new position.
	var second_action := _make_move_action(unit, Vector2i(9, 5), 2)
	var second_result: ActionResult = state.apply_action(second_action)

	# Assert — second move succeeds, billed normally (2 more AP), counter continues.
	assert_bool(second_result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(6)
	assert_vector(unit.position).is_equal(Vector2i(9, 5))
	assert_int(unit.tiles_moved_this_turn).is_equal(4)


# --- AC-4: Heavy over-cap billing --------------------------------------------

func test_heavy_three_tile_move_spends_exactly_twelve_ap_two_in_cap_one_surcharged() -> void:
	# Arrange — Heavy: move_cost 3, soft_move_cap 2, fresh, plenty of AP.
	# Expected: 2 in-cap tiles * 3 = 6, 1 over-cap tile * ceil(3*2.0)=6 -> 12 total.
	var type := _make_type(3, 2)
	var state := _make_state(0, 20)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Sanity: reachable() reports the same 12 AP cost for the 3-tile destination.
	var reachable_results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var destination := _find(reachable_results, Vector2i(8, 5))
	assert_object(destination).is_not_null()
	assert_int(destination.min_cost).is_equal(12)

	# Act
	var action := _make_move_action(unit, Vector2i(8, 5), 3)
	var result: ActionResult = state.apply_action(action)

	# Assert — exactly 12 AP spent (8 remain of 20).
	assert_bool(result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(8)


# --- AC-5: Scout split-move cumulative counter -------------------------------

func test_scout_six_tiles_one_call_spends_exactly_eight_ap() -> void:
	# Arrange — Scout: move_cost 1, soft_move_cap 4, fresh, plenty of AP.
	# Expected: 4 in-cap * 1 = 4, 2 over-cap * ceil(1*2.0)=2 -> 4 + 4 = 8 total.
	# Grid widened to 20 so a 6-tile eastward path from x=5 (to x=11) stays in bounds.
	var type := _make_type(1, 4)
	var state := _make_state(0, 20, 20)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Act — one move() call of 6 tiles.
	var action := _make_move_action(unit, Vector2i(11, 5), 6)
	var result: ActionResult = state.apply_action(action)

	# Assert
	assert_bool(result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(12) # 20 - 8


func test_scout_two_split_calls_three_plus_three_spends_exactly_eight_ap_total() -> void:
	# Arrange — same Scout stats, fresh, plenty of AP; split as 3+3 across the cap.
	# Grid widened to 20 so the combined 6-tile eastward path (x=5 -> x=11) stays in bounds.
	var type := _make_type(1, 4)
	var state := _make_state(0, 20, 20)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	# Act — first call: 3 tiles (all in-cap: cost 3).
	var first_action := _make_move_action(unit, Vector2i(8, 5), 3)
	var first_result: ActionResult = state.apply_action(first_action)
	assert_bool(first_result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(17) # 20 - 3
	# Cumulative counter carries over rather than resetting.
	assert_int(unit.tiles_moved_this_turn).is_equal(3)

	# Act — second call: 3 more tiles (1 in-cap @1 + 2 over-cap @2 = 1+4=5).
	var second_action := _make_move_action(unit, Vector2i(11, 5), 3)
	var second_result: ActionResult = state.apply_action(second_action)

	# Assert — total across both calls is exactly 8 AP (3 + 5).
	assert_bool(second_result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(12) # 20 - 8 total


# --- AC-6: reachable-vs-billed agreement, including an over-cap case, and on a clone --

func test_move_to_reachable_destination_spends_exactly_its_reported_min_cost() -> void:
	# Arrange — Heavy: move_cost 3, soft_move_cap 1 (so a 2-tile path is
	# guaranteed to include an over-cap tile), fresh, plenty of AP.
	var type := _make_type(3, 1)
	var state := _make_state(0, _SURCHARGE_START_AP)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	var reachable_results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var destination := _find(reachable_results, Vector2i(7, 5)) # 2 tiles east
	assert_object(destination).is_not_null()
	assert_bool(destination.is_surcharged).is_true() # confirms an over-cap case
	var expected_cost: int = destination.min_cost

	# Act — commit the move to T.
	var action := _make_move_action(unit, destination.tile, 2)
	var result: ActionResult = state.apply_action(action)

	# Assert — AP spent equals the reported min_cost exactly.
	assert_bool(result.ok).is_true()
	assert_int(AP.current_ap(state, 0)).is_equal(_SURCHARGE_START_AP - expected_cost)


func test_move_to_reachable_destination_on_clone_spends_exactly_its_reported_min_cost() -> void:
	# Arrange — same setup, but executed against a clone() of the authoritative
	# state (AC-6's "must hold on any clone()" requirement).
	var type := _make_type(3, 1)
	var authoritative := _make_state(0, _SURCHARGE_START_AP)
	_place_unit(authoritative, 1, 0, Vector2i(5, 5), type)

	var clone: GameState = authoritative.clone()
	var cloned_unit: UnitState = clone.entities_by_id[1]

	var reachable_results: Array[Movement.ReachableTile] = Movement.reachable(clone, cloned_unit)
	var destination := _find(reachable_results, Vector2i(7, 5))
	assert_object(destination).is_not_null()
	assert_bool(destination.is_surcharged).is_true()
	var expected_cost: int = destination.min_cost

	# Act — commit the move to T on the clone.
	var action := _make_move_action(cloned_unit, destination.tile, 2)
	var result: ActionResult = clone.apply_action(action)

	# Assert — AP spent equals the reported min_cost exactly, on the clone only.
	assert_bool(result.ok).is_true()
	assert_int(AP.current_ap(clone, 0)).is_equal(_SURCHARGE_START_AP - expected_cost)
	# Authoritative state untouched by the clone's commit.
	assert_int(AP.current_ap(authoritative, 0)).is_equal(_SURCHARGE_START_AP)


# --- Direct Movement.validate()/apply() coverage (finer assertions) ---------

func test_validate_returns_no_such_entity_when_from_tile_empty() -> void:
	var state := _make_state(0, 5)
	var action := MoveAction.new()
	action.player = 0
	action.from = Vector2i(5, 5) # nothing there
	action.to = Vector2i(6, 5)
	action.tiles_entered = 1

	var reason: int = Movement.validate(state, action)
	assert_int(reason).is_equal(Action.Reason.NO_SUCH_ENTITY)


func test_validate_returns_illegal_target_when_destination_unaffordable_via_reachable_bound() -> void:
	# Arrange — a destination whose cost exceeds current_ap. Because
	# Movement.reachable()'s own BFS expansion already stops the instant a
	# layer's cost exceeds current_ap (ADR-0009), an unaffordable destination
	# is never present in reachable()'s result set at all — so validate()'s
	# "destination in reachable()" check (ILLEGAL_TARGET) is what actually
	# fires for this case, not the separate can_afford check (CANT_AFFORD is
	# validate()'s defensive belt-and-suspenders branch, reachable only if a
	# destination were somehow present in reachable() yet still unaffordable —
	# not constructible through this public entry point under the current
	# reachable()/AP contract). This matches AC-2/QA's "fails can_afford" framing
	# at the behavioral level: the same unaffordable path is rejected either way.
	var type := _make_type(2, 10)
	var state := _make_state(0, 1) # only 1 AP; move_cost 2 tile costs 2
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	var action := _make_move_action(unit, Vector2i(6, 5), 1)
	var reason: int = Movement.validate(state, action)
	assert_int(reason).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_apply_returns_unit_moved_event_with_correct_fields() -> void:
	var type := _make_type(2, 10)
	var state := _make_state(0, 5)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)

	var action := _make_move_action(unit, Vector2i(7, 5), 2)
	var events: Array[Event] = Movement.apply(state, action)

	assert_int(events.size()).is_equal(1)
	var evt := events[0] as UnitMovedEvent
	assert_object(evt).is_not_null()
	assert_int(evt.entity_id).is_equal(1)
	assert_vector(evt.from).is_equal(Vector2i(5, 5))
	assert_vector(evt.to).is_equal(Vector2i(7, 5))
	assert_int(evt.cost).is_equal(4)
