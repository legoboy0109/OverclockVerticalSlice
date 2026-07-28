# Story 002: Y-Sort Depth Ordering & Scene-Tree Skeleton — structural coverage.
#
# Covers the two ACs of
# production/epics/board-renderer/story-002-y-sort-depth-scene-skeleton.md
# that don't need a human eye:
#   AC-1: exact node tree (FloorTileMapLayer z_index 0, OverlayTileMapLayer
#         z_index 1, OccupantLayer Node2D y_sort_enabled==true z_index 2;
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
func test_scene_tree_matches_floor_overlay_occupant_structure() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert — node count and types
	assert_int(renderer.get_child_count()).is_equal(3)
	assert_object(renderer.floor_layer).is_not_null()
	assert_object(renderer.overlay_layer).is_not_null()
	assert_object(renderer.occupant_layer).is_not_null()

	assert_bool(renderer.floor_layer is TileMapLayer).is_true()
	assert_bool(renderer.overlay_layer is TileMapLayer).is_true()
	assert_bool(renderer.occupant_layer is Node2D).is_true()
	# OccupantLayer must be a plain Node2D, not itself a TileMapLayer.
	assert_bool(renderer.occupant_layer is TileMapLayer).is_false()

	# Assert — declared node names match the story's exact tree
	assert_str(renderer.floor_layer.name).is_equal("FloorTileMapLayer")
	assert_str(renderer.overlay_layer.name).is_equal("OverlayTileMapLayer")
	assert_str(renderer.occupant_layer.name).is_equal("OccupantLayer")

	# Assert — sibling order: Floor, then Overlay, then Occupant
	assert_int(renderer.floor_layer.get_index()).is_equal(0)
	assert_int(renderer.overlay_layer.get_index()).is_equal(1)
	assert_int(renderer.occupant_layer.get_index()).is_equal(2)


# AC-1: coarse cross-tree z_index band, Floor(0) -> Overlay(1) -> Occupant(2).
func test_scene_tree_z_index_bands_are_floor_zero_overlay_one_occupant_two() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert
	assert_int(renderer.floor_layer.z_index).is_equal(0)
	assert_int(renderer.overlay_layer.z_index).is_equal(1)
	assert_int(renderer.occupant_layer.z_index).is_equal(2)


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
	assert_vector(floor_tile_set.tile_size).is_equal(overlay_tile_set.tile_size)
	assert_vector(floor_tile_set.tile_size).is_equal(
		Vector2i(int(BoardRenderer.TILE_WIDTH_PX), int(BoardRenderer.TILE_HEIGHT_PX))
	)


# AC-4 (regression guard): a child under OccupantLayer that does not set its
# own z_index must not carry a conflicting z_index — it must stay at the
# engine default (0), letting it participate in the parent's Y-sort group
# rather than fighting it. Story 002's own placeholder fixtures are exactly
# such children, so this also confirms _build_placeholder_occupants() (the
# temporary, story-002-only fixture builder) obeys the guardrail it exists
# to demonstrate.
func test_occupant_layer_children_do_not_set_conflicting_z_index() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert — at least one placeholder fixture exists to guard (a Y-sort
	# group with nothing in it proves nothing about this regression).
	assert_int(renderer.occupant_layer.get_child_count()).is_greater(0)
	for child in renderer.occupant_layer.get_children():
		assert_bool(child is Node2D).is_true()
		assert_int(child.z_index).is_equal(0)


# AC-4 companion: Story 002's story text calls out 2+ unit placeholders and
# 1 tall-prop placeholder specifically — confirm the fixture count/shape so
# a future refactor of _build_placeholder_occupants() can't silently drop
# the Y-sort-proving fixtures below the story's stated minimum.
func test_occupant_layer_has_at_least_two_units_and_one_tall_prop_placeholder() -> void:
	# Arrange / Act
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)

	# Assert
	var children := renderer.occupant_layer.get_children()
	assert_int(children.size()).is_greater_equal(3)

	var max_height := 0.0
	var heights: Array[float] = []
	for child: Node in children:
		assert_bool(child is Polygon2D).is_true()
		var polygon: Polygon2D = child
		var min_y := 0.0
		var max_y := 0.0
		for point: Vector2 in polygon.polygon:
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)
		var height := max_y - min_y
		heights.append(height)
		max_height = maxf(max_height, height)

	# At least one placeholder ("the tall prop") must be taller than the
	# others — a flat set of identically-sized placeholders would not
	# actually exercise vertical overhang (ADR-0013 §2/art bible §8.8).
	var tall_count := 0
	for h: float in heights:
		if h == max_height:
			tall_count += 1
	assert_int(tall_count).is_greater_equal(1)
	assert_int(heights.size() - tall_count).is_greater_equal(2)
