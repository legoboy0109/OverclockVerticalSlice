# Story 004: Occupant-Priority Picking — pick_at()/PickResult coverage
# (production/epics/board-renderer/story-004-pick-at-occupant-priority.md).
#
# Covers all 4 QA Test Cases against BoardRenderer.pick_at() using the
# injectable member occupant_pick_regions seam (ADR-0013 §4) — no live
# rendered scene, no real occupant sprites, no S3-05 region-authoring
# convention invented here (see board_renderer.gd's doc comment on that
# member and on pick_at() for the ownership gap this test deliberately does
# not resolve).
#
# Logic-typed per the story (pick_at() needs no scene-tree/_ready() state —
# unlike Story 002/003's Integration-typed tests, auto_free() alone is
# sufficient here; add_child() is not required to exercise this method).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _make_region(rect: Rect2, entity_id: int, tile: Vector2i) -> BoardRenderer.OccupantPickRegion:
	var region := BoardRenderer.OccupantPickRegion.new()
	region.rect = rect
	region.entity_id = entity_id
	region.tile = tile
	return region


# AC (fallback): zero occupant regions -> plain screen_to_grid fallback,
# occupant_entity_id == -1.
func test_pick_at_zero_regions_falls_back_to_screen_to_grid() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var screen_pos := Vector2(500.0, 300.0)

	# Act
	var result := renderer.pick_at(screen_pos)

	# Assert
	assert_vector(result.tile).is_equal(renderer.screen_to_grid(screen_pos))
	assert_int(result.occupant_entity_id).is_equal(-1)


# AC (fallback) edge case: origin point still degrades cleanly with zero
# regions (regression guard against an off-by-one on an empty array).
func test_pick_at_zero_regions_at_origin_falls_back_to_screen_to_grid() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var screen_pos := Vector2.ZERO

	# Act
	var result := renderer.pick_at(screen_pos)

	# Assert
	assert_vector(result.tile).is_equal(renderer.screen_to_grid(screen_pos))
	assert_int(result.occupant_entity_id).is_equal(-1)


# AC (occupant priority): one mock occupant's Rect2 overlaps an adjacent
# tile's diamond area — a click geometrically over that adjacent tile must
# still resolve to the occupant's own tile/id, not screen_to_grid's answer.
func test_pick_at_occupant_region_wins_over_geometrically_underlying_tile() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var click_pos := Vector2(500.0, 300.0)
	var adjacent_tile := renderer.screen_to_grid(click_pos)
	var occupant_tile := adjacent_tile + Vector2i(0, -1)
	var region := _make_region(
		Rect2(click_pos - Vector2(20.0, 20.0), Vector2(40.0, 40.0)), 7, occupant_tile
	)
	renderer.occupant_pick_regions = [region]

	# Act
	var result := renderer.pick_at(click_pos)

	# Assert — occupant's own tile/id, NOT screen_to_grid(click_pos)'s tile.
	assert_vector(result.tile).is_equal(occupant_tile)
	assert_vector(result.tile).is_not_equal(adjacent_tile)
	assert_int(result.occupant_entity_id).is_equal(7)


# AC (front-most): two overlapping mock regions, defined front/back Y-sort
# order (array stored back-to-front) — the front (last-in-array) region wins.
func test_pick_at_front_region_wins_when_regions_overlap() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var overlap_pos := Vector2(100.0, 100.0)
	var back_region := _make_region(
		Rect2(Vector2(60.0, 60.0), Vector2(80.0, 80.0)), 1, Vector2i(1, 1)
	)
	var front_region := _make_region(
		Rect2(Vector2(80.0, 80.0), Vector2(80.0, 80.0)), 2, Vector2i(2, 2)
	)
	# Stored back-to-front: back_region first, front_region last.
	renderer.occupant_pick_regions = [back_region, front_region]

	# Act
	var result := renderer.pick_at(overlap_pos)

	# Assert — the front (last-in-array) region wins.
	assert_int(result.occupant_entity_id).is_equal(2)
	assert_vector(result.tile).is_equal(Vector2i(2, 2))


# AC (front-most) edge case: swap which region is "front" (last-in-array)
# and confirm the result flips — proves order is actually respected by the
# algorithm, not incidentally hardcoded to "second entry" or "higher id".
func test_pick_at_front_region_result_flips_when_front_back_order_is_swapped() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var overlap_pos := Vector2(100.0, 100.0)
	var region_a := _make_region(
		Rect2(Vector2(60.0, 60.0), Vector2(80.0, 80.0)), 1, Vector2i(1, 1)
	)
	var region_b := _make_region(
		Rect2(Vector2(80.0, 80.0), Vector2(80.0, 80.0)), 2, Vector2i(2, 2)
	)
	# Now region_a is front (last-in-array) — the reverse of the previous test.
	renderer.occupant_pick_regions = [region_b, region_a]

	# Act
	var result := renderer.pick_at(overlap_pos)

	# Assert — region_a (now front) wins; the winner flipped vs. the
	# previous test purely because array order changed, not because of any
	# hardcoded id/index preference.
	assert_int(result.occupant_entity_id).is_equal(1)
	assert_vector(result.tile).is_equal(Vector2i(1, 1))


# AC (OOB): a point outside every occupant region AND outside the grid's own
# in-bounds range degrades gracefully to screen_to_grid's OOB behavior — no
# crash, and the sentinel/negative tile matches screen_to_grid's own
# (undefined-only-by-being-outside-GridState, computed the same way) result.
func test_pick_at_out_of_bounds_point_outside_all_regions_falls_back_cleanly() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var region := _make_region(
		Rect2(Vector2(500.0, 500.0), Vector2(40.0, 40.0)), 3, Vector2i(3, 3)
	)
	renderer.occupant_pick_regions = [region]
	var oob_pos := Vector2(-5000.0, -5000.0)

	# Act
	var result := renderer.pick_at(oob_pos)

	# Assert — no crash; degrades to screen_to_grid's own answer for the
	# same point, occupant_entity_id == -1 (no region contains this point).
	assert_vector(result.tile).is_equal(renderer.screen_to_grid(oob_pos))
	assert_int(result.occupant_entity_id).is_equal(-1)


# AC (OOB) companion: confirm a point that is merely near-but-not-inside a
# real region (adjacent, non-overlapping rects) does not accidentally match —
# Rect2.has_point()'s half-open convention must exclude the far edge.
func test_pick_at_point_just_outside_a_regions_rect_does_not_match_it() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var region := _make_region(
		Rect2(Vector2(100.0, 100.0), Vector2(50.0, 50.0)), 9, Vector2i(4, 4)
	)
	renderer.occupant_pick_regions = [region]
	var just_outside := Vector2(151.0, 101.0) # 1px right of the rect's right edge.

	# Act
	var result := renderer.pick_at(just_outside)

	# Assert
	assert_int(result.occupant_entity_id).is_equal(-1)
	assert_vector(result.tile).is_equal(renderer.screen_to_grid(just_outside))
