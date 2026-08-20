# Story 003: Overlay TileMapLayer set_overlay()/clear_overlay() API — cell-data
# coverage (production/epics/board-renderer/story-003-overlay-tilemaplayer-api.md).
#
# Covers the ACs assertable headless via TileMapLayer cell-data queries (no
# rendering needed):
#   AC-1 (set_overlay): exactly the given tiles are populated with the class's
#     atlas source id, and no others.
#   AC-2 (clear_overlay): zero populated cells after clear.
#   AC-3 (replace): a second set_overlay() call fully replaces the first —
#     no stale leftover cells from the earlier tile set/class.
#   AC-3 edge case: set_overlay() with an empty Array[Vector2i] clears
#     everything, equivalent to clear_overlay().
#   AC (clear no-op): clear_overlay() with no prior set_overlay() is a
#     no-op, no error.
#
# The Visual/Feel ACs (floor<->overlay diamond alignment; <=10 draw-call
# budget) are NOT covered here — see
# production/qa/evidence/board-renderer-overlay-alignment-evidence.md (owed).
#
# Integration-type per ADR-0013's own classification (BoardRenderer is
# Node2D/scene-tree-coupled, never a headless static utility) — _ready() only
# runs once a node enters the live tree, so every test add_child()s the
# renderer (auto_free() alone does not trigger _ready()). Naming follows
# tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _make_renderer() -> BoardRenderer:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	return renderer


# AC-1: set_overlay populates exactly the given tiles with the class's atlas
# source id, and no others.
func test_set_overlay_populates_exactly_given_tiles_with_class_source_id() -> void:
	# Arrange
	var renderer := _make_renderer()
	var tiles: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(1, 3),
	]

	# Act
	renderer.set_overlay(tiles, BoardRenderer.OverlayClass.ATTACK_TARGET)

	# Assert — exactly those 5 cells are populated, all with ATTACK_TARGET's
	# source id, and get_used_cells() reports no others.
	var used_cells := renderer.overlay_layer.get_used_cells()
	assert_int(used_cells.size()).is_equal(tiles.size())
	for tile in tiles:
		assert_array(used_cells).contains([renderer.cell_for(tile)])
		assert_int(renderer.overlay_layer.get_cell_source_id(renderer.cell_for(tile))).is_equal(
			BoardRenderer.OverlayClass.ATTACK_TARGET
		)
		assert_vector(renderer.overlay_layer.get_cell_atlas_coords(renderer.cell_for(tile))).is_equal(Vector2i.ZERO)

	# A tile outside the set was never touched.
	assert_int(renderer.overlay_layer.get_cell_source_id(renderer.cell_for(Vector2i(10, 10)))).is_equal(-1)


# AC-2: clear_overlay empties the overlay layer entirely.
func test_clear_overlay_after_set_overlay_leaves_zero_populated_cells() -> void:
	# Arrange
	var renderer := _make_renderer()
	var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	renderer.set_overlay(tiles, BoardRenderer.OverlayClass.MOVE_IN_CAP)

	# Act
	renderer.clear_overlay()

	# Assert
	assert_array(renderer.overlay_layer.get_used_cells()).is_empty()


# AC-3: a second set_overlay() call fully replaces the first — no stale
# leftover cells from the earlier tile set or class.
func test_second_set_overlay_replaces_first_no_stale_cells() -> void:
	# Arrange
	var renderer := _make_renderer()
	var first_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var second_tiles: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	renderer.set_overlay(first_tiles, BoardRenderer.OverlayClass.MOVE_IN_CAP)

	# Act
	renderer.set_overlay(second_tiles, BoardRenderer.OverlayClass.MOVE_OVER_CAP)

	# Assert — only the second tile set is populated, with the second class.
	var used_cells := renderer.overlay_layer.get_used_cells()
	assert_int(used_cells.size()).is_equal(second_tiles.size())
	for tile in second_tiles:
		assert_array(used_cells).contains([renderer.cell_for(tile)])
		assert_int(renderer.overlay_layer.get_cell_source_id(renderer.cell_for(tile))).is_equal(
			BoardRenderer.OverlayClass.MOVE_OVER_CAP
		)

	# None of the first call's tiles remain populated.
	for tile in first_tiles:
		assert_int(renderer.overlay_layer.get_cell_source_id(renderer.cell_for(tile))).is_equal(-1)


# AC-3 edge case: set_overlay() with an empty Array[Vector2i] clears
# everything, equivalent to clear_overlay().
func test_set_overlay_with_empty_array_clears_everything() -> void:
	# Arrange
	var renderer := _make_renderer()
	var tiles: Array[Vector2i] = [Vector2i(4, 4), Vector2i(4, 5)]
	renderer.set_overlay(tiles, BoardRenderer.OverlayClass.BLOCKED_BY_FRIENDLY)
	var empty_tiles: Array[Vector2i] = []

	# Act
	renderer.set_overlay(empty_tiles, BoardRenderer.OverlayClass.BLOCKED_BY_FRIENDLY)

	# Assert
	assert_array(renderer.overlay_layer.get_used_cells()).is_empty()


# AC (clear no-op): clear_overlay() with no prior set_overlay() is a no-op,
# no error.
func test_clear_overlay_with_no_prior_set_is_safe_no_op() -> void:
	# Arrange
	var renderer := _make_renderer()

	# Act / Assert — must not error, and the layer stays empty.
	renderer.clear_overlay()
	assert_array(renderer.overlay_layer.get_used_cells()).is_empty()


# Regression guard: all 9 taxonomy classes are registered as distinct atlas
# sources on overlay_layer's TileSet (ADR-0013 §3) — a future refactor that
# drops a class from _build_overlay_tile_source would be silently invisible
# to the ACs above (which each only exercise one or two classes at a time).
func test_all_nine_overlay_classes_have_distinct_registered_atlas_sources() -> void:
	# Arrange
	var renderer := _make_renderer()
	var tile_set := renderer.overlay_layer.tile_set

	# Assert
	var class_count := BoardRenderer.OverlayClass.size()
	assert_int(class_count).is_equal(9)
	assert_int(tile_set.get_source_count()).is_equal(class_count)
	for class_id in BoardRenderer.OverlayClass.values():
		assert_bool(tile_set.has_source(class_id)).is_true()


# Regression guard: overlay_layer's TileSet still shares the floor's exact
# iso config after this story's additions (ADR-0013 §3) — Story 002 already
# pins this, but re-asserting here catches a regression introduced by this
# story's own _build_overlay_tile_source() touching overlay_layer.tile_set.
func test_overlay_tileset_still_shares_floor_iso_config_after_overlay_sources_added() -> void:
	# Arrange / Act
	var renderer := _make_renderer()

	# Assert
	var floor_tile_set: TileSet = renderer.floor_layer.tile_set
	var overlay_tile_set: TileSet = renderer.overlay_layer.tile_set
	assert_int(overlay_tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)
	assert_vector(overlay_tile_set.tile_size).is_equal(floor_tile_set.tile_size)
