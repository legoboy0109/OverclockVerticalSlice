# Story 002: Y-Sort Depth Ordering & Scene-Tree Skeleton — structural coverage.
#
# Covers the two ACs of
# production/epics/board-renderer/story-002-y-sort-depth-scene-skeleton.md
# that don't need a human eye:
#   AC-1: exact node tree (FloorTileMapLayer z_index 0, OverlayTileMapLayer
#         z_index 1, MarkerLayer Node2D z_index 2, OccupantLayer Node2D
#         y_sort_enabled==true z_index 3;
#         ^ MarkerLayer added 2026-08-20 by Story 009 / S5-08 (ADR-0013 amended),
#           which pushed OccupantLayer's band from 2 to 3. The ordering
#           floor -> overlay -> markers -> occupants is what the numbers mean.
#         Floor/Overlay outside the Y-sort group).
#   AC-4: a child under OccupantLayer with no explicit z_index participates
#         in the Y-sort group (regression guard — asserts it carries no
#         conflicting z_index).
#
# AC-2 (greater-Y draws in front) and AC-3 (clean flip, no one-frame
# misorder) are VISUAL and cannot be verified headlessly — see
# production/qa/evidence/board-renderer-y-sort-evidence.md (owed).
#
# _ready() only runs once a node enters the live tree, so every test below
# must add_child() the renderer under GdUnitTestSuite (which overrides
# add_child to register orphan monitoring) before inspecting its children —
# auto_free() alone does not trigger _ready(). Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# AC-1: exact scene-tree shape and z-index bands.
func test_scene_tree_matches_floor_overlay_marker_occupant_structure() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert — node count and types
	assert_int(renderer.get_child_count()).is_equal(4)
	assert_object(renderer.floor_layer).is_not_null()
	assert_object(renderer.overlay_layer).is_not_null()
	assert_object(renderer.marker_layer).is_not_null()
	assert_object(renderer.occupant_layer).is_not_null()

	assert_bool(renderer.floor_layer is TileMapLayer).is_true()
	assert_bool(renderer.overlay_layer is TileMapLayer).is_true()
	assert_bool(renderer.marker_layer is Node2D).is_true()
	assert_bool(renderer.occupant_layer is Node2D).is_true()
	# MarkerLayer is a plain Node2D too — it holds individually placed decal
	# sprites, not tile cells, because a decal is per-ENTITY not per-tile.
	assert_bool(renderer.marker_layer is TileMapLayer).is_false()
	# OccupantLayer must be a plain Node2D, not itself a TileMapLayer.
	assert_bool(renderer.occupant_layer is TileMapLayer).is_false()

	# Assert — declared node names match the story's exact tree
	assert_str(renderer.floor_layer.name).is_equal("FloorTileMapLayer")
	assert_str(renderer.overlay_layer.name).is_equal("OverlayTileMapLayer")
	assert_str(renderer.marker_layer.name).is_equal("MarkerLayer")
	assert_str(renderer.occupant_layer.name).is_equal("OccupantLayer")

	# Assert — sibling order: Floor, Overlay, Marker, then Occupant
	assert_int(renderer.floor_layer.get_index()).is_equal(0)
	assert_int(renderer.overlay_layer.get_index()).is_equal(1)
	assert_int(renderer.marker_layer.get_index()).is_equal(2)
	assert_int(renderer.occupant_layer.get_index()).is_equal(3)


# AC-1: coarse cross-tree z_index band,
# Floor(0) -> Overlay(1) -> Marker(2) -> Occupant(3).
func test_scene_tree_z_index_bands_are_floor_overlay_marker_occupant() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert
	assert_int(renderer.floor_layer.z_index).is_equal(0)
	assert_int(renderer.overlay_layer.z_index).is_equal(1)
	assert_int(renderer.marker_layer.z_index).is_equal(2)
	assert_int(renderer.occupant_layer.z_index).is_equal(3)
	# The marker layer is deliberately NOT Y-sorted — flat decals at tile centres
	# cannot meaningfully occlude one another (see BoardRenderer.marker_layer).
	assert_bool(renderer.marker_layer.y_sort_enabled).is_false()


# AC-1: OccupantLayer carries y_sort_enabled == true; Floor/Overlay sit
# outside the Y-sort group (Node2D.y_sort_enabled defaults to false and must
# never be turned on for either TileMapLayer per ADR-0013 §2).
func test_occupant_layer_has_y_sort_enabled_true_floor_and_overlay_do_not() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert
	assert_bool(renderer.occupant_layer.y_sort_enabled).is_true()
	assert_bool(renderer.floor_layer.y_sort_enabled).is_false()
	assert_bool(renderer.overlay_layer.y_sort_enabled).is_false()


# AC-1: Floor and Overlay both use TileSet.TILE_SHAPE_ISOMETRIC, and share
# the same tile dimensions (ADR-0013 §3 — overlay must share the floor's
# exact iso config so alignment is structural, not hand-verified).
func test_floor_and_overlay_tilesets_use_isometric_shape_and_matching_dimensions() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert
	var floor_tile_set: TileSet = renderer.floor_layer.tile_set
	var overlay_tile_set: TileSet = renderer.overlay_layer.tile_set
	assert_object(floor_tile_set).is_not_null()
	assert_object(overlay_tile_set).is_not_null()
	assert_int(floor_tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)
	assert_int(overlay_tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)
	# Story 006 (AC-7): both TileSets moved to the 2x TEXTURE size, with the layer
	# nodes scaled back down — the art ships at 2x. They must still be IDENTICAL to
	# each other (ADR-0013 §3's floor/overlay alignment mechanism), and the
	# ON-SCREEN cell must still be TILE_WIDTH_PX x TILE_HEIGHT_PX.
	assert_vector(floor_tile_set.tile_size).is_equal(overlay_tile_set.tile_size)
	assert_vector(floor_tile_set.tile_size).is_equal(BoardRenderer.TILE_TEXTURE_SIZE)
	assert_vector(floor_tile_set.tile_size).is_equal(Vector2i(256, 128))
	assert_float(renderer.floor_layer.scale.x).is_equal_approx(BoardRenderer.TILE_LAYER_SCALE, 0.0001)
	assert_float(renderer.overlay_layer.scale.x).is_equal_approx(BoardRenderer.TILE_LAYER_SCALE, 0.0001)
	# The effective on-screen cell is unchanged at 128x64.
	assert_float(floor_tile_set.tile_size.x * renderer.floor_layer.scale.x).is_equal_approx(
		BoardRenderer.TILE_WIDTH_PX, 0.0001
	)
	assert_float(floor_tile_set.tile_size.y * renderer.floor_layer.scale.y).is_equal_approx(
		BoardRenderer.TILE_HEIGHT_PX, 0.0001
	)


# AC-4 (regression guard): a child under OccupantLayer that does not set its
# own z_index must not carry a conflicting z_index — it must stay at the
# engine default (0), letting it participate in the parent's Y-sort group
# rather than fighting it.
#
# Story 006 note: this used to guard Story 002's placeholder fixtures, which are
# gone. It now guards the REAL occupants — the Cover props paint_terrain() adds —
# which is a stronger guard, since those are shipping nodes rather than fixtures.
func test_occupant_layer_children_do_not_set_conflicting_z_index() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var grid := GridState.new()
	grid.width = 2
	grid.height = 1
	grid.terrain = PackedByteArray([GridState.Terrain.PLAIN, GridState.Terrain.COVER])
	grid.occupancy = PackedInt32Array([GridState.EMPTY_OCCUPANT, GridState.EMPTY_OCCUPANT])

	# Act
	renderer.paint_terrain(grid)

	# Assert — at least one real occupant exists to guard (a Y-sort group with
	# nothing in it proves nothing about this regression).
	assert_int(renderer.occupant_layer.get_child_count()).is_greater(0)
	for child in renderer.occupant_layer.get_children():
		assert_bool(child is Node2D).is_true()
		assert_int(child.z_index).is_equal(0)
