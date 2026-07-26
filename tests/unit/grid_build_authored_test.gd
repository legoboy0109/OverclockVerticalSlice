# Story 003: MapDefinition & Authored Build Pipeline.
#
# Covers every acceptance criterion in
# production/epics/grid-terrain/story-003-mapdefinition-authored-build.md for
# the AUTHORED branch of MapDefinition.build_grid(). No RNG, no time-dependent
# asserts, no file I/O; each test builds its own MapDefinition from scratch.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const WIDTH := 10
const HEIGHT := 8


# Builds a WIDTH x HEIGHT authored MapDefinition: all-Plain terrain, two HQ
# tiles at opposite corners, no obstacles. Shared happy-path fixture.
func _make_open_map(width: int = WIDTH, height: int = HEIGHT) -> MapDefinition:
	var map_def := MapDefinition.new()
	map_def.width = width
	map_def.height = height
	map_def.mode = MapDefinition.Mode.AUTHORED
	map_def.authored_terrain = PackedByteArray()
	map_def.authored_terrain.resize(width * height)
	map_def.authored_terrain.fill(GridState.Terrain.PLAIN)
	map_def.hq_tiles = [Vector2i(0, 0), Vector2i(width - 1, height - 1)]
	map_def.deploy_tiles = []
	return map_def


# Builds a WIDTH x HEIGHT authored MapDefinition where a full-height column of
# Impassable tiles separates the left HQ from the right HQ — no path exists.
func _make_walled_off_map() -> MapDefinition:
	var map_def := _make_open_map()
	var wall_x := WIDTH / 2
	for y: int in HEIGHT:
		map_def.authored_terrain[y * WIDTH + wall_x] = GridState.Terrain.IMPASSABLE
	return map_def


# AC1: building the same MapDefinition twice yields byte-identical terrain
# and occupancy.
func test_build_grid_same_map_definition_twice_yields_identical_grids() -> void:
	# Arrange
	var map_def := _make_open_map()
	# Act
	var grid_a: GridState = MapDefinition.build_grid(map_def)
	var grid_b: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid_a).is_not_null()
	assert_object(grid_b).is_not_null()
	assert_array(Array(grid_a.terrain)).is_equal(Array(grid_b.terrain))
	assert_array(Array(grid_a.occupancy)).is_equal(Array(grid_b.occupancy))


# AC2: an authored map that walls off one HQ from the other is rejected.
func test_build_grid_hqs_walled_off_returns_null() -> void:
	# Arrange
	var map_def := _make_walled_off_map()
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# AC3a: width below MIN_DIM is rejected.
func test_build_grid_width_too_small_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map(7, HEIGHT)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# AC3b: width above MAX_DIM is rejected.
func test_build_grid_width_too_large_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map(25, HEIGHT)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# AC3c: height below MIN_DIM is rejected.
func test_build_grid_height_too_small_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map(WIDTH, 7)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# AC3d: height above MAX_DIM is rejected.
func test_build_grid_height_too_large_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map(WIDTH, 25)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# AC4: a valid authored map builds headlessly and answers Story 001/002
# queries correctly, with HQs placed as occupants.
func test_build_grid_valid_authored_map_succeeds_headless() -> void:
	# Arrange
	var map_def := _make_open_map()
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()
	assert_int(grid.width).is_equal(WIDTH)
	assert_int(grid.height).is_equal(HEIGHT)
	assert_int(grid.terrain_at(3, 3)).is_equal(GridState.Terrain.PLAIN)
	assert_bool(grid.is_passable(3, 3)).is_true()
	assert_int(grid.occupant_at(0, 0)).is_not_equal(GridState.EMPTY_OCCUPANT)
	assert_int(grid.occupant_at(WIDTH - 1, HEIGHT - 1)).is_not_equal(GridState.EMPTY_OCCUPANT)


# Terrain-size mismatch (malformed map) is rejected.
func test_build_grid_authored_terrain_size_mismatch_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	map_def.authored_terrain.resize(map_def.authored_terrain.size() - 1)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# A happy-path reachable map (open board, no obstacles) returns non-null.
func test_build_grid_reachable_open_map_returns_non_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()


# HQ tiles are actually occupied in the returned grid (both HQs, distinct ids).
func test_build_grid_hq_tiles_are_occupied_with_distinct_ids() -> void:
	# Arrange
	var map_def := _make_open_map()
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()
	var occupant_a: int = grid.occupant_at(0, 0)
	var occupant_b: int = grid.occupant_at(WIDTH - 1, HEIGHT - 1)
	assert_int(occupant_a).is_not_equal(GridState.EMPTY_OCCUPANT)
	assert_int(occupant_b).is_not_equal(GridState.EMPTY_OCCUPANT)
	assert_int(occupant_a).is_not_equal(occupant_b)


# Wrong HQ count (this codebase requires exactly 2, VS 1v1 scope) is rejected.
func test_build_grid_wrong_hq_count_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	map_def.hq_tiles = [Vector2i(0, 0)]
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# An HQ tile placed out-of-bounds is rejected before reachability is checked.
func test_build_grid_hq_tile_out_of_bounds_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	map_def.hq_tiles = [Vector2i(0, 0), Vector2i(WIDTH, HEIGHT)]
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# An HQ tile placed on Impassable terrain is rejected.
func test_build_grid_hq_tile_on_impassable_terrain_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	map_def.authored_terrain[map_def.width * 0 + 0] = GridState.Terrain.IMPASSABLE
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# NOTE: the former `test_build_grid_procedural_mode_returns_null_stub` (a Story
# 003 regression-guard asserting PROCEDURAL rejected until implemented) was
# removed when Story 004 landed the PROCEDURAL branch. Procedural-mode build
# behavior is now covered by tests/unit/grid_procedural_generation_test.gd.


# --- Code-review follow-ups (2026-07-25) ---

# G4: two identical HQ tiles are rejected intentionally (distinctness guard),
# not merely via the place()-collision side-channel. hq_tiles.size()==2 passes,
# so this exercises the explicit hq_a == hq_b check.
func test_build_grid_identical_hq_tiles_returns_null() -> void:
	# Arrange
	var map_def := _make_open_map()
	map_def.hq_tiles = [Vector2i(0, 0), Vector2i(0, 0)]
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_null()


# BFS must treat Cover as passable: a full Impassable wall with a single COVER
# gap is the ONLY route between HQs. If the validator ever narrowed passability
# to Plain-only, this would (wrongly) reject the map.
func test_build_grid_reachable_only_through_cover() -> void:
	# Arrange — wall column x=5 fully Impassable except a Cover tile at (5,3).
	var map_def := _make_open_map()
	var wall_x := WIDTH / 2
	for y: int in HEIGHT:
		map_def.authored_terrain[y * WIDTH + wall_x] = GridState.Terrain.IMPASSABLE
	map_def.authored_terrain[3 * WIDTH + wall_x] = GridState.Terrain.COVER
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert — reachable only via the Cover tile, so build must succeed.
	assert_object(grid).is_not_null()
	assert_int(grid.terrain_at(wall_x, 3)).is_equal(GridState.Terrain.COVER)


# BFS must actually traverse around obstacles: a wall with a single Plain gap
# leaves a narrow corridor between the HQs (not a wide-open board).
func test_build_grid_reachable_via_narrow_gap() -> void:
	# Arrange — wall column x=5 fully Impassable except one Plain gap at (5,3).
	var map_def := _make_open_map()
	var wall_x := WIDTH / 2
	for y: int in HEIGHT:
		map_def.authored_terrain[y * WIDTH + wall_x] = GridState.Terrain.IMPASSABLE
	map_def.authored_terrain[3 * WIDTH + wall_x] = GridState.Terrain.PLAIN
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert — a path exists through the gap, so build must succeed.
	assert_object(grid).is_not_null()


# Inclusive dimension boundaries (8 and 24) must SUCCEED — the reject tests only
# cover 7/25, where off-by-ones on the passing side would go unnoticed.
func test_build_grid_dims_at_inclusive_boundaries_succeed() -> void:
	# Arrange / Act — minimum (8x8) and maximum (24x24) both valid.
	var grid_min: GridState = MapDefinition.build_grid(_make_open_map(8, 8))
	var grid_max: GridState = MapDefinition.build_grid(_make_open_map(24, 24))
	# Assert
	assert_object(grid_min).is_not_null()
	assert_object(grid_max).is_not_null()
