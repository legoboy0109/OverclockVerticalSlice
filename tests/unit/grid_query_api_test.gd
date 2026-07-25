# Story 001: GridState Core Data Model & Read Query API — read-query coverage.
#
# Covers every acceptance criterion in
# production/epics/grid-terrain/story-001-gridstate-core-query-api.md against
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


# AC1: in_bounds on 8x8 — corners true, one-past-edge coordinates false.
func test_in_bounds_corners_of_8x8_return_true() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.in_bounds(0, 0)).is_true()
	assert_bool(grid.in_bounds(7, 7)).is_true()


func test_in_bounds_outside_8x8_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.in_bounds(-1, 0)).is_false()
	assert_bool(grid.in_bounds(8, 0)).is_false()


# AC2: a tile authored as Cover reports Cover, identically on repeated calls.
func test_terrain_at_cover_tile_returns_cover() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(3, 3)] = GridState.Terrain.COVER
	# Act / Assert
	assert_int(grid.terrain_at(3, 3)).is_equal(GridState.Terrain.COVER)


func test_is_cover_cover_tile_returns_true_deterministically() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(3, 3)] = GridState.Terrain.COVER
	# Act / Assert — repeated calls agree (no hidden mutable state).
	assert_bool(grid.is_cover(3, 3)).is_true()
	assert_bool(grid.is_cover(3, 3)).is_true()
	assert_bool(grid.is_cover(3, 3)).is_true()


# AC3: neighbors — interior tile returns 4, corner returns 2, never OOB.
func test_neighbors_interior_tile_returns_four_orthogonal_tiles() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.neighbors(4, 4)
	# Assert
	assert_int(result.size()).is_equal(4)
	assert_array(result).contains([
		Vector2i(4, 3), Vector2i(5, 4), Vector2i(4, 5), Vector2i(3, 4),
	])


func test_neighbors_corner_tile_returns_exactly_two_in_bounds_tiles() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act
	var result := grid.neighbors(0, 0)
	# Assert
	assert_int(result.size()).is_equal(2)
	assert_array(result).contains([Vector2i(1, 0), Vector2i(0, 1)])
	for tile: Vector2i in result:
		assert_bool(grid.in_bounds(tile.x, tile.y)).is_true()


func test_neighbors_never_returns_out_of_bounds_tile() -> void:
	# Arrange — every edge and corner of a small grid.
	var grid := _make_blank_grid()
	var edge_and_corner_tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7),
		Vector2i(0, 4), Vector2i(7, 4), Vector2i(4, 0), Vector2i(4, 7),
	]
	# Act / Assert
	for tile: Vector2i in edge_and_corner_tiles:
		for neighbor: Vector2i in grid.neighbors(tile.x, tile.y):
			assert_bool(grid.in_bounds(neighbor.x, neighbor.y)).is_true()


# AC4: manhattan_distance formula + adjacency.
func test_manhattan_distance_zero_zero_to_two_three_returns_five() -> void:
	# Arrange
	var a := Vector2i(0, 0)
	var b := Vector2i(2, 3)
	# Act / Assert
	assert_int(GridState.new().manhattan_distance(a, b)).is_equal(5)


func test_manhattan_distance_adjacent_tiles_returns_one() -> void:
	# Arrange
	var a := Vector2i(3, 3)
	var b := Vector2i(4, 3)
	# Act / Assert
	assert_int(GridState.new().manhattan_distance(a, b)).is_equal(1)


# AC5: headless / render-decoupled — a directly-constructed GridState answers
# every read query correctly with no scene tree or rendering node involved.
func test_directly_constructed_grid_answers_all_read_queries_headlessly() -> void:
	# Arrange — no scene tree, no Node, no TileMapLayer; a plain Resource.
	var grid := _make_blank_grid()
	grid.terrain[grid.index(2, 2)] = GridState.Terrain.COVER
	grid.terrain[grid.index(5, 5)] = GridState.Terrain.IMPASSABLE
	grid.occupancy[grid.index(1, 1)] = 42
	# Act / Assert — every read query resolves without a running SceneTree.
	assert_bool(grid.in_bounds(1, 1)).is_true()
	assert_int(grid.terrain_at(2, 2)).is_equal(GridState.Terrain.COVER)
	assert_bool(grid.is_cover(2, 2)).is_true()
	assert_bool(grid.is_passable(5, 5)).is_false()
	assert_int(grid.occupant_at(1, 1)).is_equal(42)
	assert_bool(grid.is_passable(1, 1)).is_false() # occupied
	assert_int(grid.neighbors(0, 0).size()).is_equal(2)
	assert_int(grid.manhattan_distance(Vector2i(0, 0), Vector2i(1, 1))).is_equal(2)


# AC6: out-of-bounds query safety — sentinels, not crashes.
func test_out_of_bounds_terrain_at_returns_impassable_sentinel() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_int(grid.terrain_at(-1, 0)).is_equal(GridState.Terrain.IMPASSABLE)
	assert_int(grid.terrain_at(8, 0)).is_equal(GridState.Terrain.IMPASSABLE)


func test_out_of_bounds_occupant_at_returns_empty_sentinel() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_int(grid.occupant_at(-1, 0)).is_equal(-1)
	assert_int(grid.occupant_at(8, 8)).is_equal(-1)


func test_out_of_bounds_is_passable_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.is_passable(-1, -1)).is_false()
	assert_bool(grid.is_passable(8, 8)).is_false()


func test_out_of_bounds_in_bounds_returns_false() -> void:
	# Arrange
	var grid := _make_blank_grid()
	# Act / Assert
	assert_bool(grid.in_bounds(-5, 0)).is_false()
	assert_bool(grid.in_bounds(0, 100)).is_false()


# --- Code-review follow-ups (2026-07-25) ---

# G3: is_passable must be able to return true. Every other is_passable call in
# this suite asserts false, so a stub `return false` would pass them all — this
# pins the true branch: a Cover tile (terrain != Impassable) with no occupant is
# passable.
func test_is_passable_cover_terrain_no_occupant_returns_true() -> void:
	# Arrange
	var grid := _make_blank_grid()
	grid.terrain[grid.index(3, 3)] = GridState.Terrain.COVER
	# Act / Assert — Cover is passable; the tile is empty (occupancy filled -1).
	assert_bool(grid.is_passable(3, 3)).is_true()
	# And a plain empty tile is passable too (baseline, non-Cover true case).
	assert_bool(grid.is_passable(4, 4)).is_true()


# G1: non-square (rectangular) grid — the VS ships a 14x16 board (ADR-0005),
# but every other test uses a square grid, so a width/height transposition in
# index()/in_bounds() would be invisible. These coordinates distinguish 14x16
# from a transposed 16x14.
func test_rectangular_14x16_grid_index_inbounds_neighbors() -> void:
	# Arrange — build a 14 wide x 16 tall grid directly.
	var w := 14
	var h := 16
	var grid := GridState.new()
	grid.width = w
	grid.height = h
	grid.terrain = PackedByteArray()
	grid.terrain.resize(w * h)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(w * h)
	grid.occupancy.fill(-1)

	# Assert — index is row-major over width, not height.
	assert_int(grid.index(0, 15)).is_equal(15 * w)          # 210
	assert_int(grid.index(13, 15)).is_equal(w * h - 1)      # 223, last tile

	# in_bounds — coordinates that are valid on 14x16 but NOT on a transposed 16x14.
	assert_bool(grid.in_bounds(0, 15)).is_true()   # y=15 valid at height 16; invalid at height 14
	assert_bool(grid.in_bounds(13, 0)).is_true()   # x=13 valid at width 14
	assert_bool(grid.in_bounds(15, 0)).is_false()  # x=15 out at width 14 (would be valid if 16-wide)
	assert_bool(grid.in_bounds(0, 16)).is_false()  # y=16 out at height 16

	# neighbors at a non-corner right edge (x at max): E is OOB and filtered, so 3.
	var edge := grid.neighbors(13, 8)
	assert_int(edge.size()).is_equal(3)
	assert_array(edge).contains([Vector2i(13, 7), Vector2i(13, 9), Vector2i(12, 8)])
	for tile: Vector2i in edge:
		assert_bool(grid.in_bounds(tile.x, tile.y)).is_true()
