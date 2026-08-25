# VSMap — the shipping battlefield's authored layout.
#
# ★ These are structural invariants, not behaviour. Every one of them encodes a rule that,
# if broken, breaks a MEASUREMENT rather than a feature — and a broken measurement is the
# failure mode this project has been bitten by repeatedly (S7-09's harness that could only
# return zero, S7-10's cover experiment that silently no-opped).
extends GdUnitTestSuite


func test_the_map_actually_carries_cover() -> void:
	# ★ The whole point of S7-11. Cover was implemented in the Foundation sprints and NO MAP
	# EVER PLACED A TILE, so every measurement up to S7-10 ran on a featureless board without
	# anyone noticing. If this ever returns to zero, that silence returns with it.
	var terrain: PackedByteArray = VSMap.terrain()
	var cover_count: int = 0
	for b: int in terrain:
		if b == GridState.Terrain.COVER:
			cover_count += 1
	assert_int(cover_count).override_failure_message(
		"The shipping map has no Cover tiles. Cover being implemented but never placed is " +
		"exactly the state S7-11 existed to fix."
	).is_equal(VSMap.COVER_TILES.size())
	assert_int(cover_count).is_greater(0)


func test_cover_layout_is_mirror_symmetric() -> void:
	# ★ Load-bearing. The batch alternates the starting player because on a symmetric board
	# that is the only asymmetry there is. An asymmetric layout hands one seat an edge, and
	# every "not seat-determined" reading downstream would then be measuring the map.
	for tile: Vector2i in VSMap.COVER_TILES:
		var mirror := Vector2i(VSMap.WIDTH - 1 - tile.x, tile.y)
		assert_bool(VSMap.is_cover_tile(mirror)).override_failure_message(
			"Cover tile %s has no mirror at %s — the layout is asymmetric, which silently " % [tile, mirror] +
			"favours one seat and corrupts every seat-split measurement."
		).is_true()


func test_no_cover_inside_either_hq_deploy_ring() -> void:
	# ★ deploy_radius is 2, and the deploy rule has already produced one game-ending defect
	# (the S6-15 spawn-ring latch, where four enemy units on a producer's neighbours ended a
	# player's game permanently). Terrain has no business interacting with it.
	for tile: Vector2i in VSMap.COVER_TILES:
		for hq: Vector2i in [VSMap.HQ_A, VSMap.HQ_B]:
			var d: int = absi(tile.x - hq.x) + absi(tile.y - hq.y)
			assert_int(d).override_failure_message(
				"Cover tile %s is %d tiles from HQ %s — inside the deploy ring." % [tile, d, hq]
			).is_greater_equal(VSMap.MIN_HQ_CLEARANCE)


func test_no_cover_sits_on_an_hq() -> void:
	assert_bool(VSMap.is_cover_tile(VSMap.HQ_A)).is_false()
	assert_bool(VSMap.is_cover_tile(VSMap.HQ_B)).is_false()


func test_every_cover_tile_is_in_bounds() -> void:
	for tile: Vector2i in VSMap.COVER_TILES:
		assert_bool(tile.x >= 0 and tile.x < VSMap.WIDTH).override_failure_message(
			"Cover tile %s is outside the map's width." % tile).is_true()
		assert_bool(tile.y >= 0 and tile.y < VSMap.HEIGHT).override_failure_message(
			"Cover tile %s is outside the map's height." % tile).is_true()


func test_cover_tiles_are_unique() -> void:
	var seen: Dictionary = {}
	for tile: Vector2i in VSMap.COVER_TILES:
		assert_bool(seen.has(tile)).override_failure_message(
			"Cover tile %s is listed twice — the count is then a lie." % tile).is_false()
		seen[tile] = true


func test_plain_override_produces_a_terrain_free_board() -> void:
	# The pre-S7-11 board, kept so a batch can be compared against everything recorded
	# before cover existed. Nothing that ships passes true.
	for b: int in VSMap.terrain(true):
		assert_int(b).is_equal(GridState.Terrain.PLAIN)


func test_build_produces_a_grid_that_reports_its_cover() -> void:
	# End to end: the authored list must survive MapDefinition -> GridState, because that is
	# the only path the runtime and the AI ever read it through.
	var state: GameState = GameState.start_match(VSMap.build(), 0)
	for tile: Vector2i in VSMap.COVER_TILES:
		assert_bool(state.grid.is_cover(tile.x, tile.y)).override_failure_message(
			"Authored cover at %s does not read back as Cover from GridState." % tile).is_true()
	# And a tile that is NOT authored as cover must not report as one.
	assert_bool(state.grid.is_cover(VSMap.HQ_A.x, VSMap.HQ_A.y)).is_false()
