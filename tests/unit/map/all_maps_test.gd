# Every playable map obeys the layout rules the vertical slice was measured under (VSMap header,
# the map notes' design sections). Driven by Maps.all(), so a map drawn in the vault is held to
# them the moment it is registered.
extends GdUnitTestSuite

const MIN_HQ_CLEARANCE: int = 3


func test_every_map_builds_a_board_with_reachable_hqs() -> void:
	for m: MapDefinition in Maps.all():
		assert_object(MapDefinition.build_grid(m)).override_failure_message(
			"%s does not build (bad size, HQ on blocked ground, or HQs cut off)." % m.display_name).is_not_null()


func test_every_map_is_mirror_symmetric() -> void:
	# The batches alternate who moves first because on a symmetric board that is the only asymmetry.
	for m: MapDefinition in Maps.all():
		for y: int in m.height:
			for x: int in m.width:
				var a: int = m.authored_terrain[y * m.width + x]
				var b: int = m.authored_terrain[y * m.width + (m.width - 1 - x)]
				assert_int(a).override_failure_message(
					"%s is not mirror-symmetric at (%d,%d)." % [m.display_name, x, y]).is_equal(b)
		assert_int(m.hq_tiles[0].x).is_equal(m.width - 1 - m.hq_tiles[1].x)


func test_nothing_crowds_an_hq() -> void:
	# Units deploy up to 2 tiles from their producer; terrain inside that ring caused S6-15.
	for m: MapDefinition in Maps.all():
		for y: int in m.height:
			for x: int in m.width:
				if m.authored_terrain[y * m.width + x] == GridState.Terrain.PLAIN:
					continue
				for hq: Vector2i in m.hq_tiles:
					assert_int(absi(hq.x - x) + absi(hq.y - y)).override_failure_message(
						"%s has terrain at (%d,%d), too close to an HQ." % [m.display_name, x, y]
					).is_greater_equal(MIN_HQ_CLEARANCE)


func test_the_hq_to_hq_row_is_open() -> void:
	# The measured lesson: cover in the lane both sides must cross turns close games into draws.
	for m: MapDefinition in Maps.all():
		var y: int = m.hq_tiles[0].y
		for x: int in range(m.hq_tiles[0].x, m.hq_tiles[1].x + 1):
			assert_int(m.authored_terrain[y * m.width + x]).override_failure_message(
				"%s's HQ-to-HQ row is not open at x=%d." % [m.display_name, x]).is_equal(GridState.Terrain.PLAIN)


func test_every_map_seats_both_starting_builders() -> void:
	for m: MapDefinition in Maps.all():
		VSMap.select(m)
		var state := MatchSetup.build(VSMap.build(),
			[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
		var builders: int = 0
		for e: EntityState in state.entities():
			if e is UnitState:
				builders += 1
		assert_int(builders).override_failure_message("%s: a starting Builder had no tile." % m.display_name).is_equal(2)
	VSMap.select(null)   # back to the default for every other test


func test_every_map_is_in_the_vault() -> void:
	for m: MapDefinition in Maps.all():
		assert_str(FileAccess.get_file_as_string(m.resource_path)).contains("; GENERATED from game-data/Maps/")


func test_every_map_has_a_round_limit_the_setup_screen_accepts() -> void:
	for m: MapDefinition in Maps.all():
		assert_int(m.default_round_limit).override_failure_message(
			"%s's round_limit is outside what the setup screen allows." % m.display_name) \
			.is_between(MatchSettings.ROUNDS_MIN, MatchSettings.ROUNDS_MAX)


func test_a_bigger_board_never_gets_a_shorter_game() -> void:
	for a: MapDefinition in Maps.all():
		for b: MapDefinition in Maps.all():
			if a.width * a.height > b.width * b.height:
				assert_int(a.default_round_limit).override_failure_message(
					"%s is bigger than %s but has a shorter round limit." % [a.display_name, b.display_name]) \
					.is_greater_equal(b.default_round_limit)
