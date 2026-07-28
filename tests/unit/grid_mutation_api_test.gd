# Story 002: Grid Mutation API — place/remove/move & Single-Occupant Invariant.
#
# Covers every acceptance criterion in
# production/epics/grid-terrain/story-002-grid-mutation-api.md against
# directly-constructed GridState instances (no MapDefinition/build_grid yet —
# that lands in Story 003). No RNG, no time-dependent asserts, no file I/O;
# each test builds and tears down its own GridState.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const GRID_SIZE := 8


# Builds an 8x8 all-Plain grid with empty occupancy — the shared baseline
# fixture for tests that don't care about specific terrain layout.
func _make_blank_grid(size: int = GRID_SIZE) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(-1)
	return grid


# AC1: place on an empty passable tile — occupant_at reflects it and the
# tile stops being passable.
func test_place_on_empty_passable_tile_succeeds_and_occupies() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.place(42, 3, 4)
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(3, 4)).is_equal(42)
	assert_bool(grid.is_passable(3, 4)).is_false()


# AC2: a second place on an already-occupied tile is rejected; original
# occupant is unchanged.
func test_place_on_occupied_tile_is_rejected_and_occupant_unchanged() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	# Act
	var result := grid.place(99, 3, 4)
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(3, 4)).is_equal(42)


# AC3a: place on an Impassable tile is rejected.
func test_place_on_impassable_tile_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(5, 5)] = GridState.Terrain.IMPASSABLE
	# Act
	var result := grid.place(1, 5, 5)
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(5, 5)).is_equal(-1)


# AC3b: a move destination that is Impassable is rejected.
func test_move_to_impassable_destination_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 2, 2)
	grid.terrain[grid.index(2, 3)] = GridState.Terrain.IMPASSABLE
	# Act
	var result := grid.move(Vector2i(2, 2), Vector2i(2, 3))
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(2, 2)).is_equal(42)
	assert_int(grid.occupant_at(2, 3)).is_equal(-1)


# AC4a: remove on an already-empty tile is a no-op returning false.
func test_remove_on_empty_tile_returns_false_and_is_noop() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.remove(3, 3)
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(3, 3)).is_equal(-1)


# AC4b: remove on an Impassable tile is a no-op returning false.
func test_remove_on_impassable_tile_returns_false_and_is_noop() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(5, 5)] = GridState.Terrain.IMPASSABLE
	# Act
	var result := grid.remove(5, 5)
	# Assert
	assert_bool(result).is_false()


# AC4c: remove on a genuinely occupied tile succeeds and empties it.
func test_remove_on_occupied_tile_returns_true_and_empties_tile() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	# Act
	var result := grid.remove(3, 4)
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(3, 4)).is_equal(-1)
	assert_bool(grid.is_passable(3, 4)).is_true()


# AC5: move A->B is atomic — A becomes empty, B holds the occupant.
func test_move_occupied_tile_to_empty_tile_relocates_occupant_atomically() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	# Act
	var result := grid.move(Vector2i(3, 4), Vector2i(3, 5))
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(3, 4)).is_equal(-1)
	assert_int(grid.occupant_at(3, 5)).is_equal(42)


func test_move_to_occupied_destination_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	grid.place(99, 3, 5)
	# Act
	var result := grid.move(Vector2i(3, 4), Vector2i(3, 5))
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(3, 4)).is_equal(42)
	assert_int(grid.occupant_at(3, 5)).is_equal(99)


func test_move_from_empty_tile_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.move(Vector2i(1, 1), Vector2i(2, 2))
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(2, 2)).is_equal(-1)


func test_move_from_out_of_bounds_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.move(Vector2i(-1, 0), Vector2i(2, 2))
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(2, 2)).is_equal(-1)


func test_move_to_out_of_bounds_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	# Act
	var result := grid.move(Vector2i(3, 4), Vector2i(8, 8))
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(3, 4)).is_equal(42)


# AC6: two placements targeting the same empty tile, in call order — the
# first succeeds, the second is rejected; no co-occupancy.
func test_two_placements_on_same_tile_first_wins_second_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var first := grid.place(1, 4, 4)
	var second := grid.place(2, 4, 4)
	# Assert
	assert_bool(first).is_true()
	assert_bool(second).is_false()
	assert_int(grid.occupant_at(4, 4)).is_equal(1)


# Out-of-bounds safety: place/remove/move never crash on OOB coordinates.
func test_place_with_out_of_bounds_coordinates_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.place(1, -1, 0)).is_false()
	assert_bool(grid.place(1, 8, 8)).is_false()


func test_remove_with_out_of_bounds_coordinates_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.remove(-1, 0)).is_false()
	assert_bool(grid.remove(8, 8)).is_false()


func test_move_with_out_of_bounds_endpoints_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.move(Vector2i(-1, -1), Vector2i(8, 8))).is_false()


# Sentinel rejection: placing the EMPTY_OCCUPANT sentinel (-1) as an
# entity_id is rejected — it can't be distinguished from "empty" once stored.
func test_place_with_empty_occupant_sentinel_id_is_rejected() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.place(GridState.EMPTY_OCCUPANT, 2, 2)
	# Assert
	assert_bool(result).is_false()
	assert_int(grid.occupant_at(2, 2)).is_equal(-1)


# Judgment call (documented in grid_state.gd's move() doc comment): a
# from == to move on a valid occupied tile is a successful no-op-equivalent,
# not a rejection — nothing is actually contested.
func test_move_from_equal_to_on_occupied_tile_returns_true_and_is_noop() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 3, 4)
	# Act
	var result := grid.move(Vector2i(3, 4), Vector2i(3, 4))
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(3, 4)).is_equal(42)


func test_move_from_equal_to_on_empty_tile_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.move(Vector2i(3, 4), Vector2i(3, 4))
	# Assert
	assert_bool(result).is_false()


# --- Code-review follow-ups (2026-07-25) ---

# Cover is passable per ADR-0005 (only IMPASSABLE blocks placement). Guards
# against a regression that checks `!= PLAIN` instead of `!= IMPASSABLE`.
func test_place_on_cover_tile_succeeds() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(3, 3)] = GridState.Terrain.COVER
	# Act
	var result := grid.place(42, 3, 3)
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(3, 3)).is_equal(42)


# A move whose destination is Cover terrain must succeed (Cover is passable).
func test_move_to_cover_destination_succeeds() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.place(42, 2, 2)
	grid.terrain[grid.index(2, 3)] = GridState.Terrain.COVER
	# Act
	var result := grid.move(Vector2i(2, 2), Vector2i(2, 3))
	# Assert
	assert_bool(result).is_true()
	assert_int(grid.occupant_at(2, 2)).is_equal(-1)
	assert_int(grid.occupant_at(2, 3)).is_equal(42)


# Non-square grid: index()=y*width+x is invisible to a width/height transposition
# on a square grid. A 10-wide x 6-tall board places near the non-square boundary
# and confirms the correct cell is written (and only that cell).
func test_rectangular_grid_place_occupant_roundtrip() -> void:
	# Arrange — 10 wide x 6 tall (width != height).
	var w := 10
	var h := 6
	var grid := GridState.new()
	grid.width = w
	grid.height = h
	grid.terrain = PackedByteArray()
	grid.terrain.resize(w * h)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(w * h)
	grid.occupancy.fill(-1)
	# Act — place at the right edge (x=9, valid at width 10) and bottom (y=5).
	var right_edge := grid.place(7, 9, 0)
	var bottom_edge := grid.place(8, 0, 5)
	# Assert — both writes land on the correct cell.
	assert_bool(right_edge).is_true()
	assert_bool(bottom_edge).is_true()
	assert_int(grid.occupant_at(9, 0)).is_equal(7)
	assert_int(grid.occupant_at(0, 5)).is_equal(8)
	# And the transposed coordinates are NOT occupied (would be, if width/height swapped).
	assert_int(grid.occupant_at(0, 9)).is_equal(-1)  # (0,9) is OOB on a 6-tall board → sentinel
	assert_bool(grid.in_bounds(9, 0)).is_true()
	assert_bool(grid.in_bounds(0, 5)).is_true()
	assert_bool(grid.in_bounds(9, 5)).is_true()      # true corner on 10x6
	assert_bool(grid.in_bounds(6, 9)).is_false()     # would be in-bounds only if 10-tall
