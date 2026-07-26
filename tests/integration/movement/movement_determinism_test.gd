# Story 003: Movement Determinism & No-Stale-Cache Guarantees (Integration).
#
# The two GDD-mandated integration proofs for the reachable-search + move verb
# (production/epics/movement/story-003-determinism-no-stale-cache.md):
#
#   AC-1 (tie-break determinism, reframed): the ADR-0009 design is PATHLESS —
#     cost is a pure function of path LENGTH and move() is an atomic from->to
#     commit, so no "tile sequence" is ever walked or exposed. This test instead
#     proves determinism the way the design makes observable: in an adversarial
#     board where a destination is reachable by TWO equal-cost paths, reachable()
#     returns an identical, identically-ordered result set across repeated calls
#     AND across a clone(), and move() to that tie-destination commits identically
#     (same AP billed, same final position) from two independent identical states.
#     (The N->E->S->W fixed neighbor order makes the tie a non-issue by
#     construction — spelled out here as an integration-level guarantee.)
#
#   AC-2 (no stale cache): reachable() is recomputed fresh every call — after a
#     blocker is removed from the grid with no other change, the newly-opened
#     tiles appear, and no previously-reachable tile's cost changes.
#
# Integration-type: exercises Movement.reachable() + the full apply_action MOVE
# pipeline against directly-built GameState/GridState/UnitState fixtures. No RNG,
# no file I/O beyond preload'd registry consts, no scene tree. Each test builds
# and tears down its own state (tests/README.md isolation rule).
extends GdUnitTestSuite


const GRID_SIZE := 10


# --- Fixture builders (self-contained; not shared across files) --------------

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


# Builds a GameState with a blank grid, both players' AP set, player 0 active,
# and a mover unit (entity_id 1, owner 0) placed at pos + registered in grid
# occupancy and entities_by_id. Returns the state; the mover is entities_by_id[1].
func _make_state_with_mover(current_ap: int, pos: Vector2i, type: UnitTypeDef, \
		tiles_moved: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	state.grid = _make_blank_grid()
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	unit.tiles_moved_this_turn = tiles_moved
	state.entities_by_id[1] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = 1
	return state


func _place_enemy(state: GameState, entity_id: int, pos: Vector2i, type: UnitTypeDef) -> void:
	var e := UnitState.new()
	e.entity_id = entity_id
	e.owner = 1
	e.position = pos
	e.type = type
	e.current_hp = type.hp
	state.entities_by_id[entity_id] = e
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id


func _find(results: Array[Movement.ReachableTile], tile: Vector2i) -> Movement.ReachableTile:
	for r: Movement.ReachableTile in results:
		if r.tile == tile:
			return r
	return null


func _assert_result_sets_identical(a: Array[Movement.ReachableTile], \
		b: Array[Movement.ReachableTile]) -> void:
	assert_int(a.size()).is_equal(b.size())
	for i: int in a.size():
		assert_vector(a[i].tile).is_equal(b[i].tile)
		assert_int(a[i].min_cost).is_equal(b[i].min_cost)
		assert_bool(a[i].is_surcharged).is_equal(b[i].is_surcharged)


# --- AC-1: tie-break determinism in an adversarial two-equal-path board -------

# (6,6) is reachable from (5,5) by TWO equal-length (length-2) paths:
# (5,5)->(6,5)->(6,6) and (5,5)->(5,6)->(6,6). With cost a pure function of
# length, both cost 2 (move_cost 1). reachable() must return an identical,
# identically-ordered result set on repeated calls despite the tie.
func test_two_equal_cost_paths_reachable_set_identical_across_repeated_calls() -> void:
	# Arrange
	var type := _make_type(1, 8)
	var state := _make_state_with_mover(10, Vector2i(5, 5), type)
	# Act
	var first: Array[Movement.ReachableTile] = Movement.reachable(state, state.entities_by_id[1])
	var second: Array[Movement.ReachableTile] = Movement.reachable(state, state.entities_by_id[1])
	# Assert — the tie-destination is present exactly once at the length-2 cost,
	# and the whole result is byte-identical in order across calls.
	var tie := _find(first, Vector2i(6, 6))
	assert_object(tie).is_not_null()
	assert_int(tie.min_cost).is_equal(2)
	_assert_result_sets_identical(first, second)


# Clone parity: reachable() on a clone()'d state matches the authoritative
# state's result exactly (AI-lookahead determinism — same tie scenario).
func test_two_equal_cost_paths_reachable_set_identical_on_clone() -> void:
	# Arrange
	var type := _make_type(1, 8)
	var state := _make_state_with_mover(10, Vector2i(5, 5), type)
	var clone: GameState = state.clone()
	# Act
	var authoritative: Array[Movement.ReachableTile] = Movement.reachable(state, state.entities_by_id[1])
	var cloned: Array[Movement.ReachableTile] = Movement.reachable(clone, clone.entities_by_id[1])
	# Assert
	_assert_result_sets_identical(authoritative, cloned)


# Deterministic commit: moving to the tie-destination from two INDEPENDENT
# identical starting states bills the same AP and lands the same final position
# — the move verb resolves the tie identically every time (via apply_action).
func test_move_to_tie_destination_commits_identically_from_identical_states() -> void:
	# Arrange — two independent identical states.
	var type_a := _make_type(1, 8)
	var state_a := _make_state_with_mover(10, Vector2i(5, 5), type_a)
	var type_b := _make_type(1, 8)
	var state_b := _make_state_with_mover(10, Vector2i(5, 5), type_b)

	# Act — commit an identical MoveAction to the tie-destination (6,6) through
	# the real apply_action pipeline in each.
	var result_a: ActionResult = state_a.apply_action(_move_to(Vector2i(5, 5), Vector2i(6, 6), 2))
	var result_b: ActionResult = state_b.apply_action(_move_to(Vector2i(5, 5), Vector2i(6, 6), 2))

	# Assert — both succeed, bill the same AP, land the same tile.
	assert_bool(result_a.ok).is_true()
	assert_bool(result_b.ok).is_true()
	assert_int(state_a.per_player[0].current_ap).is_equal(state_b.per_player[0].current_ap)
	assert_int(state_a.per_player[0].current_ap).is_equal(8) # 10 - 2
	assert_vector(state_a.entities_by_id[1].position).is_equal(Vector2i(6, 6))
	assert_vector(state_b.entities_by_id[1].position).is_equal(Vector2i(6, 6))


func _move_to(from: Vector2i, to: Vector2i, tiles_entered: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = 0
	action.from = from
	action.to = to
	action.tiles_entered = tiles_entered
	return action


# --- AC-2: no stale cache — blocker removed opens tiles, others unchanged -----

# A single-gap corridor: column 6 is Impassable for every row except the gap at
# (6,5). To reach column 7+, the mover must pass through (6,5). An enemy parked
# on (6,5) blocks it; removing the enemy re-opens column 7 — proving reachable()
# recomputes fresh from current state, never a stale cache.
func test_reachable_recomputed_fresh_after_blocker_removed_opens_tiles() -> void:
	# Arrange — build the corridor.
	var type := _make_type(1, 8)
	var state := _make_state_with_mover(10, Vector2i(5, 5), type)
	for y: int in GRID_SIZE:
		if y != 5:
			state.grid.terrain[state.grid.index(6, y)] = GridState.Terrain.IMPASSABLE
	# Enemy parked on the only gap (6,5) blocks the corridor.
	_place_enemy(state, 2, Vector2i(6, 5), type)

	# Act 1 — with the blocker, (7,5) beyond the gap is unreachable.
	var blocked: Array[Movement.ReachableTile] = Movement.reachable(state, state.entities_by_id[1])
	assert_object(_find(blocked, Vector2i(7, 5))).is_null()
	# Capture a tile reachable on THIS side both before and after (a control).
	var control_before := _find(blocked, Vector2i(5, 6))
	assert_object(control_before).is_not_null()

	# Remove the blocker from the grid with no other state change.
	state.grid.remove(6, 5)
	state.entities_by_id.erase(2)

	# Act 2 — recompute on the SAME state object; (7,5) is now reachable.
	var opened: Array[Movement.ReachableTile] = Movement.reachable(state, state.entities_by_id[1])
	var newly := _find(opened, Vector2i(7, 5))
	assert_object(newly).is_not_null()

	# Assert — the control tile's cost is unchanged (only the newly-opened region
	# differs; no global recompute artifact).
	var control_after := _find(opened, Vector2i(5, 6))
	assert_object(control_after).is_not_null()
	assert_int(control_after.min_cost).is_equal(control_before.min_cost)
	assert_bool(control_after.is_surcharged).is_equal(control_before.is_surcharged)
