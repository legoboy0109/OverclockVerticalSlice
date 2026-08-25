# Story 001: Reachable-Tile Search (Movement.reachable()) — full AC coverage.
#
# Covers every acceptance criterion in
# production/epics/movement/story-001-reachable-tile-search.md against
# directly-constructed GameState/GridState/UnitState fixtures. No RNG, no
# file I/O beyond preload'd registry consts (UnitTypes), no scene tree.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const GRID_SIZE := 10


# --- Fixture builders --------------------------------------------------------

# Builds a size x size all-Plain grid with empty occupancy.
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


# An in-memory UnitTypeDef with explicit stats (never a preload'd .tres) —
# needed for the boundary ACs that require specific move_cost/soft_move_cap
# combinations not necessarily matching the shipped roster.
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


func _make_unit(owner: int, pos: Vector2i, type: UnitTypeDef, tiles_moved_this_turn: int = 0) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	unit.tiles_moved_this_turn = tiles_moved_this_turn
	return unit


# Places a UnitState occupant at tile, registers it in state.entities_by_id,
# and writes it into grid occupancy. Returns the created UnitState (with the
# given entity_id) for further mutation by the caller if needed.
func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[entity_id] = u
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return u


# Places a StructureState occupant (the ADR-0007 forward-declared test stub —
# see tests/helpers/stubs/structure_state_stub.gd) at tile.
func _place_structure(state: GameState, entity_id: int, owner: int, pos: Vector2i) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	state.entities_by_id[entity_id] = s
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return s


# Builds a gridless-then-gridded GameState with the given player's current_ap
# set, an assigned blank grid, and player 0 active (unless overridden).
func _make_state(current_ap: int, grid_size: int = GRID_SIZE, active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.per_player[0].current_ap = current_ap if active_player == 0 else state.per_player[0].current_ap
	state.per_player[1].current_ap = current_ap if active_player == 1 else state.per_player[1].current_ap
	state.grid = _make_blank_grid(grid_size)
	return state


# Convenience: current_ap for BOTH players (movement's owner-driven AP check
# doesn't care about active_player at all — reachable() is a pure query).
func _make_state_both(current_ap: int, grid_size: int = GRID_SIZE) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	state.grid = _make_blank_grid(grid_size)
	return state


func _tiles(results: Array[Movement.ReachableTile]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Movement.ReachableTile in results:
		out.append(r.tile)
	return out


func _find(results: Array[Movement.ReachableTile], tile: Vector2i) -> Movement.ReachableTile:
	for r: Movement.ReachableTile in results:
		if r.tile == tile:
			return r
	return null


# --- AC-1: Scout soft-cap boundary (move_cost 1, cap 4, penalty 2.0, 5 AP) ---

func test_scout_five_ap_reaches_exactly_four_step_tiles_no_fifth() -> void:
	# Arrange — Scout: move_cost 1, soft_move_cap 4; 5 AP; open board.
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	var unit := _make_unit(0, Vector2i(5, 5), type)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — the 4 tiles straight east (in-cap, 1 AP each) are reachable.
	assert_array(tiles).contains([
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5),
	])
	# A 5-step-only tile (5th tile east) costs ceil(1*2.0)=2 AP > 1 remaining —
	# must be absent even though its base cost (1) alone would "fit".
	assert_array(tiles).not_contains([Vector2i(10, 5)])

	# Edge case: the 4th tile's cost is exactly 4 (not yet surcharged).
	var fourth := _find(results, Vector2i(9, 5))
	assert_object(fourth).is_not_null()
	assert_int(fourth.min_cost).is_equal(4)
	assert_bool(fourth.is_surcharged).is_false()


# --- AC-2: friendly pass-through ---------------------------------------------

func test_friendly_unit_between_mover_and_tile_does_not_block() -> void:
	# Arrange — friendly unit directly between mover and an empty tile 2 away.
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 0, Vector2i(6, 5), type) # friendly, same owner

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — tile beyond the friendly is reachable, cost reflects 2 tiles entered.
	assert_array(tiles).contains([Vector2i(7, 5)])
	var beyond := _find(results, Vector2i(7, 5))
	assert_int(beyond.min_cost).is_equal(2)
	# The friendly-occupied tile itself must never be a destination (AC-5 too).
	assert_array(tiles).not_contains([Vector2i(6, 5)])


# --- AC-3: enemy blocks -------------------------------------------------------

func test_enemy_unit_in_only_path_blocks_tiles_beyond() -> void:
	# Arrange — enemy unit in the only path to a tile (corridor of Impassable
	# on both flanks so there is exactly one route).
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	# Wall off the row above/below at x=6 to force a single-file corridor.
	state.grid.terrain[state.grid.index(6, 4)] = GridState.Terrain.IMPASSABLE
	state.grid.terrain[state.grid.index(6, 6)] = GridState.Terrain.IMPASSABLE
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 1, Vector2i(6, 5), type) # enemy (owner 1)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — the enemy tile and everything reachable only through it absent.
	assert_array(tiles).not_contains([Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)])


# --- AC-4: friendly structure blocks (regression pair with AC-2) ------------

func test_friendly_structure_in_only_path_blocks_identically_to_enemy() -> void:
	# Arrange — friendly-owned STRUCTURE (not a unit) in the only path.
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	state.grid.terrain[state.grid.index(6, 4)] = GridState.Terrain.IMPASSABLE
	state.grid.terrain[state.grid.index(6, 6)] = GridState.Terrain.IMPASSABLE
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_structure(state, 2, 0, Vector2i(6, 5)) # friendly-owned structure

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — blocks identically to AC-3's enemy case (pass-through is unit-only).
	assert_array(tiles).not_contains([Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)])


func test_friendly_unit_in_identical_position_does_not_block_regression_pair() -> void:
	# Arrange — same corridor/position as the structure case above, but a
	# friendly UNIT instead — must NOT block (regression pair with AC-2/AC-4).
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	state.grid.terrain[state.grid.index(6, 4)] = GridState.Terrain.IMPASSABLE
	state.grid.terrain[state.grid.index(6, 6)] = GridState.Terrain.IMPASSABLE
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 0, Vector2i(6, 5), type) # friendly unit, same tile

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — path continues past the friendly unit.
	assert_array(tiles).contains([Vector2i(7, 5), Vector2i(8, 5)])


# --- AC-5: invalid destinations ----------------------------------------------

func test_friendly_occupied_and_impassable_tiles_never_valid_destinations() -> void:
	# Arrange — a friendly-occupied tile and an Impassable tile both within range.
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 0, Vector2i(6, 5), type) # friendly, traversable-through
	state.grid.terrain[state.grid.index(5, 3)] = GridState.Terrain.IMPASSABLE

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — neither appears in the returned set.
	assert_array(tiles).not_contains([Vector2i(6, 5), Vector2i(5, 3)])


# --- AC-6: no zone of control -------------------------------------------------

func test_moving_past_adjacent_enemy_is_not_stopped_or_slowed() -> void:
	# Arrange — unit adjacent to an enemy, open tile past it via a different
	# route (no corridor walls here — mere adjacency must not cost/blocking).
	var type := _make_type(1, 4)
	var state := _make_state_both(5)
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 1, Vector2i(6, 5), type) # enemy, adjacent to mover

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var tiles := _tiles(results)

	# Assert — path around the enemy (e.g. via (5,4)->(6,4)->(7,4)) unaffected;
	# no cost penalty from mere adjacency to the enemy at (6,5).
	assert_array(tiles).contains([Vector2i(7, 4)])
	var around := _find(results, Vector2i(7, 4))
	assert_int(around.min_cost).is_equal(3) # 3 steps, no ZoC surcharge


# --- AC-7: unaffordable base cost --------------------------------------------

func test_move_cost_exceeds_current_ap_returns_empty_set() -> void:
	# Arrange — move_cost 3, current_ap 2 (move_cost - 1 exactly).
	var type := _make_type(3, 4)
	var state := _make_state_both(2)
	var unit := _make_unit(0, Vector2i(5, 5), type)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)

	# Assert
	assert_array(results).is_empty()


# --- AC-8: surcharge-driven empty set (Heavy at/past cap) --------------------

func test_heavy_at_cap_with_four_ap_returns_empty_set_despite_affordable_base_cost() -> void:
	# Arrange — Heavy: move_cost 3, soft_move_cap 2, already at cap
	# (tiles_moved_this_turn == 2), current_ap 4. Base move_cost 3 alone would
	# be affordable, but the next tile is over-cap: ceil(3*2.0)=6 AP > 4.
	var type := _make_type(3, 2)
	var state := _make_state_both(4)
	var unit := _make_unit(0, Vector2i(5, 5), type, 2)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)

	# Assert — distinguishes this from AC-7's base-cost-only rejection.
	assert_array(results).is_empty()


# --- AC-9: fixed-point rounding ----------------------------------------------

func test_scout_at_cap_with_penalty_one_point_five_charges_ceil_two_not_float() -> void:
	# Arrange — Scout move_cost 1, at/past cap, SOFT_MOVE_PENALTY 1.5 (x10=15,
	# not the VS default 2.0). Injected via UnitBalance.units (the live Autoload
	# UnitConfig.surcharge_for() reads), restored after the test.
	var original_penalty: int = UnitBalance.units.soft_move_penalty_x10
	UnitBalance.units.soft_move_penalty_x10 = 15
	var type := _make_type(1, 0) # cap 0 -> immediately at/past cap
	var state := _make_state_both(5)
	var unit := _make_unit(0, Vector2i(5, 5), type, 0)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	UnitBalance.units.soft_move_penalty_x10 = original_penalty # restore before asserts

	# Assert — the single reachable tile (1 step) costs ceil(1*1.5)=2, an int.
	var one_step := _find(results, Vector2i(6, 5))
	assert_object(one_step).is_not_null()
	assert_int(one_step.min_cost).is_equal(2)
	assert_bool(typeof(one_step.min_cost) == TYPE_INT).is_true()


# --- AC-10: is_surcharged accuracy -------------------------------------------

func test_is_surcharged_true_only_once_path_crosses_soft_cap() -> void:
	# Arrange — Scout move_cost 1, soft_move_cap 2, fresh (tiles_moved_this_turn 0),
	# plenty of AP. Straight-line path: depths 1,2 in-cap; depth 3+ surcharged.
	var type := _make_type(1, 2)
	var state := _make_state_both(20)
	var unit := _make_unit(0, Vector2i(5, 5), type, 0)

	# Act
	var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)

	# Assert — depth 2 (the boundary tile itself, not yet over) reads false.
	var at_cap := _find(results, Vector2i(7, 5)) # 2 steps east
	assert_object(at_cap).is_not_null()
	assert_bool(at_cap.is_surcharged).is_false()

	# A tile 1 step further (depth 3, over cap) reads true.
	var over_cap := _find(results, Vector2i(8, 5)) # 3 steps east
	assert_object(over_cap).is_not_null()
	assert_bool(over_cap.is_surcharged).is_true()

	# A wholly in-cap path (depth 1) reads false.
	var in_cap := _find(results, Vector2i(6, 5)) # 1 step east
	assert_object(in_cap).is_not_null()
	assert_bool(in_cap.is_surcharged).is_false()


# --- AC-11: determinism -------------------------------------------------------

func test_repeated_reachable_calls_return_identical_result_sets() -> void:
	# Arrange — a board with mixed occupants/terrain, fresh unit.
	var type := _make_type(1, 4)
	var state := _make_state_both(6)
	var unit := _make_unit(0, Vector2i(5, 5), type)
	_place_unit(state, 2, 0, Vector2i(6, 5), type)
	_place_structure(state, 3, 1, Vector2i(5, 3))
	state.grid.terrain[state.grid.index(4, 4)] = GridState.Terrain.IMPASSABLE

	# Act — call twice.
	var first: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var second: Array[Movement.ReachableTile] = Movement.reachable(state, unit)

	# Assert — identical (tile, min_cost, is_surcharged) for every entry, same order.
	assert_int(first.size()).is_equal(second.size())
	for i: int in first.size():
		assert_vector(first[i].tile).is_equal(second[i].tile)
		assert_int(first[i].min_cost).is_equal(second[i].min_cost)
		assert_bool(first[i].is_surcharged).is_equal(second[i].is_surcharged)


func test_repeated_reachable_calls_identical_on_mid_turn_clone_with_tiles_moved() -> void:
	# Arrange — a mid-turn clone where tiles_moved_this_turn > 0 (per AC-11's
	# explicit mid-turn-clone scenario).
	var type := _make_type(1, 4)
	var state := _make_state_both(6)
	var unit := _make_unit(0, Vector2i(5, 5), type, 3) # already moved 3 tiles
	state.entities_by_id[unit.entity_id] = unit
	state.grid.occupancy[state.grid.index(5, 5)] = unit.entity_id

	var clone: GameState = state.clone()
	var cloned_unit: UnitState = clone.entities_by_id[unit.entity_id]

	# Act — call twice against the clone.
	var first: Array[Movement.ReachableTile] = Movement.reachable(clone, cloned_unit)
	var second: Array[Movement.ReachableTile] = Movement.reachable(clone, cloned_unit)

	# Assert — identical result sets.
	assert_int(first.size()).is_equal(second.size())
	for i: int in first.size():
		assert_vector(first[i].tile).is_equal(second[i].tile)
		assert_int(first[i].min_cost).is_equal(second[i].min_cost)
		assert_bool(first[i].is_surcharged).is_equal(second[i].is_surcharged)


# ==============================================================================
# reachable_ignoring_ap — telling "boxed in" apart from "broke"
# (added 2026-08-24 for design/ux/action-menu.md OQ-5)
# ==============================================================================

func test_reachable_is_empty_at_zero_ap_even_in_wide_open_ground() -> void:
	# ★ The behaviour the whole fix turns on, pinned explicitly because it is
	# surprising: the affordability cut lives INSIDE the BFS, so a unit standing in
	# the middle of an empty board with no AP gets back exactly what a unit walled
	# in on four sides gets — nothing. Every consumer reading "empty means nowhere
	# to go" was therefore reporting the wrong problem.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4), _make_type(1, 8))

	assert_array(Movement.reachable(state, unit)).is_empty()


func test_reachable_ignoring_ap_finds_the_tiles_that_ap_was_hiding() -> void:
	# ...and the AP-free question separates the two cases: the same open-ground unit
	# has plenty of somewhere to go, it just cannot pay for any of it right now.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4), _make_type(1, 8))

	assert_array(Movement.reachable_ignoring_ap(state, unit)).override_failure_message(
		"a unit in open ground has somewhere to go at SOME price, whatever its AP"
	).is_not_empty()


func test_reachable_ignoring_ap_still_respects_traversal_rules() -> void:
	# It drops the affordability cut and NOTHING else. A genuinely boxed-in unit is
	# still boxed in no matter how much AP it is imagined to have — otherwise the
	# query would report a route through an enemy body and the menu would say
	# "needs AP" about a move that can never be made.
	var state := _make_state_both(99)
	var type := _make_type(1, 8)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	# Enemy units are hard blockers (ADR-0009) — seal all four orthogonals.
	_place_unit(state, 2, 1, Vector2i(5, 4), type)
	_place_unit(state, 3, 1, Vector2i(5, 6), type)
	_place_unit(state, 4, 1, Vector2i(4, 5), type)
	_place_unit(state, 5, 1, Vector2i(6, 5), type)

	assert_array(Movement.reachable_ignoring_ap(state, unit)).override_failure_message(
		"the AP-free query must not walk through blockers"
	).is_empty()


func test_the_two_queries_agree_whenever_ap_is_not_the_constraint() -> void:
	# With AP far above anything the board can cost, the affordability cut never
	# fires and the two must return the identical set — which is what makes the
	# extracted BFS worth having instead of a second hand-written copy that could
	# drift on traversal, destination validity, neighbour order or surcharge depth.
	var state := _make_state(999)
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4), _make_type(1, 8))

	var budgeted: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var unbounded: Array[Movement.ReachableTile] = Movement.reachable_ignoring_ap(state, unit)

	assert_int(budgeted.size()).is_equal(unbounded.size())
	for i: int in budgeted.size():
		assert_vector(budgeted[i].tile).is_equal(unbounded[i].tile)
		assert_int(budgeted[i].min_cost).is_equal(unbounded[i].min_cost)
		assert_bool(budgeted[i].is_surcharged).is_equal(unbounded[i].is_surcharged)
