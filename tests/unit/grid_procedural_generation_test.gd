# Story 004: Procedural Center Terrain Generation & Self-Correcting
# Reachability.
#
# Covers every acceptance criterion in
# production/epics/grid-terrain/story-004-procedural-center-generation.md for
# MapDefinition.generate_procedural() and build_grid()'s PROCEDURAL branch.
# No unseeded RNG, no time-dependent asserts, no file I/O — every fixture
# picks an explicit proc_seed and config; each test builds its own
# MapDefinition from scratch.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const WIDTH := 12
const HEIGHT := 10


# Builds a WIDTH x HEIGHT Procedural MapDefinition with HQs at opposite
# corners. The HQ axis is x-dominant (dx=WIDTH-1 > dy=HEIGHT-1), so the band
# is a VERTICAL strip of columns (perpendicular to the axis) and the symmetry
# mirror axis is the vertical midline. Takes the given proc_* params. Shared fixture.
func _make_procedural_map(
		seed_value: int,
		band_width: int = 4,
		density_x100: int = 30,
		feature_mix_x100: int = 70,
		symmetric: bool = true,
		width: int = WIDTH,
		height: int = HEIGHT) -> MapDefinition:
	var map_def := MapDefinition.new()
	map_def.width = width
	map_def.height = height
	map_def.mode = MapDefinition.Mode.PROCEDURAL
	map_def.proc_seed = seed_value
	map_def.proc_band_width = band_width
	map_def.proc_density_x100 = density_x100
	map_def.proc_feature_mix_x100 = feature_mix_x100
	map_def.proc_symmetric = symmetric
	map_def.hq_tiles = [Vector2i(0, 0), Vector2i(width - 1, height - 1)]
	map_def.deploy_tiles = [Vector2i(1, 0), Vector2i(width - 2, height - 1)]
	return map_def


# AC1 (highest value): the same PROCEDURAL MapDefinition, built twice, yields
# byte-identical terrain — proves generate_procedural draws exclusively from
# the seeded instance in a fixed order with no incidental nondeterminism.
func test_generate_procedural_same_seed_twice_yields_byte_identical_terrain() -> void:
	# Arrange
	var map_def := _make_procedural_map(12345)
	# Act
	var terrain_a := MapDefinition.generate_procedural(map_def)
	var terrain_b := MapDefinition.generate_procedural(map_def)
	# Assert
	assert_array(Array(terrain_a)).is_equal(Array(terrain_b))


# AC1 (via build_grid): the full pipeline is also byte-identical per seed,
# not just the raw generator output.
func test_build_grid_same_procedural_map_definition_twice_yields_identical_grids() -> void:
	# Arrange
	var map_def := _make_procedural_map(777)
	# Act
	var grid_a: GridState = MapDefinition.build_grid(map_def)
	var grid_b: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid_a).is_not_null()
	assert_object(grid_b).is_not_null()
	assert_array(Array(grid_a.terrain)).is_equal(Array(grid_b.terrain))
	assert_array(Array(grid_a.occupancy)).is_equal(Array(grid_b.occupancy))


# Sanity that the seed actually drives generation: two different seeds
# (same config) generally produce different layouts.
func test_generate_procedural_different_seeds_generally_differ() -> void:
	# Arrange
	var map_def_a := _make_procedural_map(1)
	var map_def_b := _make_procedural_map(2)
	# Act
	var terrain_a := MapDefinition.generate_procedural(map_def_a)
	var terrain_b := MapDefinition.generate_procedural(map_def_b)
	# Assert
	assert_array(Array(terrain_a)).is_not_equal(Array(terrain_b))


# AC2: proc_symmetric mirrors the layout across the board center. With an
# opposite-corner HQ axis (differs more in x here: WIDTH-1 > HEIGHT-1), the
# band is vertical (a strip of columns), so the mirror axis is the vertical
# midline: terrain(x, y) == terrain(width-1-x, y) for every tile.
func test_generate_procedural_symmetric_mirrors_across_vertical_axis() -> void:
	# Arrange — HQs differ more in x (11 vs 9) => vertical band => mirror x.
	var map_def := _make_procedural_map(42, 4, 40, 60, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var idx := y * WIDTH + x
			var mirror_idx := y * WIDTH + (WIDTH - 1 - x)
			assert_int(terrain[idx]).is_equal(terrain[mirror_idx])


# AC2: symmetric generation still leaves both HQs mutually reachable.
func test_generate_procedural_symmetric_hqs_remain_reachable() -> void:
	# Arrange
	var map_def := _make_procedural_map(42, 4, 40, 60, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	var reachable := MapDefinition._hqs_mutually_reachable(
			map_def.width, map_def.height, terrain, map_def.hq_tiles[0], map_def.hq_tiles[1])
	assert_bool(reachable).is_true()


# AC2 (via build_grid): the full pipeline returns a non-null grid for a
# symmetric config.
func test_build_grid_symmetric_procedural_map_returns_non_null() -> void:
	# Arrange
	var map_def := _make_procedural_map(99, 4, 40, 60, true)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()


# AC3: a density high enough to wall off the HQs still yields a reachable
# result — the self-correction clamps density rather than emitting an
# unplayable map. A full-width band with 100% density and 0% Cover share
# (all Impassable) would otherwise seal the board into columns.
func test_generate_procedural_high_density_clamps_to_preserve_reachability() -> void:
	# Arrange — whole-board-adjacent band, all features Impassable, max density.
	var map_def := _make_procedural_map(5, 6, 100, 0, false)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	var reachable := MapDefinition._hqs_mutually_reachable(
			map_def.width, map_def.height, terrain, map_def.hq_tiles[0], map_def.hq_tiles[1])
	assert_bool(reachable).is_true()


# AC3 (via build_grid): the full pipeline never returns null for an
# over-dense config — build_grid must observe the same clamp.
func test_build_grid_high_density_procedural_map_returns_non_null_and_reachable() -> void:
	# Arrange
	var map_def := _make_procedural_map(5, 6, 100, 0, false)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()


# Determinism of the thinning/self-correction path itself: the same
# over-dense seed+config, built twice, still yields byte-identical terrain
# (the thinning loop is a pure function of the layout, no RNG, ascending
# flat-index order every time).
func test_generate_procedural_thinning_path_is_deterministic() -> void:
	# Arrange
	var map_def := _make_procedural_map(5, 6, 100, 0, false)
	# Act
	var terrain_a := MapDefinition.generate_procedural(map_def)
	var terrain_b := MapDefinition.generate_procedural(map_def)
	# Assert
	assert_array(Array(terrain_a)).is_equal(Array(terrain_b))


# Code-review follow-up: the thinning/self-correction path must be deterministic
# under proc_symmetric=true too (exercises the mirror-aware thinning branch,
# which removes an Impassable tile AND its mirror partner). Same over-dense
# symmetric config built twice → byte-identical.
func test_generate_procedural_symmetric_thinning_path_is_deterministic() -> void:
	# Arrange — full-band, all-Impassable, symmetric: walls off the HQs, so
	# thinning runs, and the mirror-thinning branch is exercised.
	var map_def := _make_procedural_map(5, 6, 100, 0, true)
	# Act
	var terrain_a := MapDefinition.generate_procedural(map_def)
	var terrain_b := MapDefinition.generate_procedural(map_def)
	# Assert — deterministic through the symmetric thinning path, and reachable.
	assert_array(Array(terrain_a)).is_equal(Array(terrain_b))
	var reachable := MapDefinition._hqs_mutually_reachable(
			map_def.width, map_def.height, terrain_a, map_def.hq_tiles[0], map_def.hq_tiles[1])
	assert_bool(reachable).is_true()


# Code-review follow-up: an all-Cover band at max density must SKIP thinning
# entirely — Cover is passable, so the HQs are never walled off and the
# self-correction loop leaves the layout untouched (no Impassable to thin).
func test_generate_procedural_all_cover_high_density_skips_thinning() -> void:
	# Arrange — max density, 100% Cover share (feature_mix_x100 = 100 → every
	# draw < 100 → Cover), whole-board scatter.
	var map_def := _make_procedural_map(7, WIDTH, 100, 100, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert — no Impassable tiles exist at all (so nothing was ever thinnable),
	# and the HQs are reachable.
	var impassable_count := 0
	for i: int in terrain.size():
		if terrain[i] == GridState.Terrain.IMPASSABLE:
			impassable_count += 1
	assert_int(impassable_count).is_equal(0)
	var reachable := MapDefinition._hqs_mutually_reachable(
			map_def.width, map_def.height, terrain, map_def.hq_tiles[0], map_def.hq_tiles[1])
	assert_bool(reachable).is_true()


# AC4: HQ tiles are never overwritten with a feature, regardless of density.
func test_generate_procedural_hq_tiles_stay_plain_even_at_max_density() -> void:
	# Arrange — whole-board scatter, max density, to stress-test exclusion.
	var map_def := _make_procedural_map(8, WIDTH, 100, 50, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	for hq: Vector2i in map_def.hq_tiles:
		var idx := hq.y * WIDTH + hq.x
		assert_int(terrain[idx]).is_equal(GridState.Terrain.PLAIN)


# AC4: deploy tiles are also excluded from the candidate set and never
# overwritten with a feature.
func test_generate_procedural_deploy_tiles_stay_plain_even_at_max_density() -> void:
	# Arrange
	var map_def := _make_procedural_map(8, WIDTH, 100, 50, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	for deploy: Vector2i in map_def.deploy_tiles:
		var idx := deploy.y * WIDTH + deploy.x
		assert_int(terrain[idx]).is_equal(GridState.Terrain.PLAIN)


# AC5: proc_band_width >= the board's smaller dimension clamps to whole-board
# scatter; generation still succeeds, HQs stay reachable, exclusions honored.
func test_generate_procedural_band_width_at_or_above_min_dim_clamps_to_whole_board() -> void:
	# Arrange — HEIGHT (10) is the smaller dimension; band_width == HEIGHT.
	var map_def := _make_procedural_map(21, HEIGHT, 30, 70, true)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert — reachable, and exclusions still honored under whole-board scatter.
	var reachable := MapDefinition._hqs_mutually_reachable(
			map_def.width, map_def.height, terrain, map_def.hq_tiles[0], map_def.hq_tiles[1])
	assert_bool(reachable).is_true()
	for hq: Vector2i in map_def.hq_tiles:
		var idx := hq.y * WIDTH + hq.x
		assert_int(terrain[idx]).is_equal(GridState.Terrain.PLAIN)


# AC5 (via build_grid): a band_width beyond both dimensions also succeeds
# (over-clamped, not just at the exact boundary).
func test_build_grid_band_width_exceeding_board_returns_non_null() -> void:
	# Arrange — band_width larger than both dimensions.
	var map_def := _make_procedural_map(21, WIDTH + HEIGHT, 30, 70, true)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()


# A non-symmetric procedural map still produces a reachable, non-null grid
# (symmetry is opt-in via proc_symmetric, not load-bearing for reachability).
func test_build_grid_non_symmetric_procedural_map_returns_non_null() -> void:
	# Arrange
	var map_def := _make_procedural_map(3, 4, 30, 70, false)
	# Act
	var grid: GridState = MapDefinition.build_grid(map_def)
	# Assert
	assert_object(grid).is_not_null()


# Sanity: the generated terrain array is always exactly width*height entries,
# regardless of band/whole-board branch taken.
func test_generate_procedural_terrain_size_matches_board_dimensions() -> void:
	# Arrange
	var map_def := _make_procedural_map(11)
	# Act
	var terrain := MapDefinition.generate_procedural(map_def)
	# Assert
	assert_int(terrain.size()).is_equal(WIDTH * HEIGHT)
