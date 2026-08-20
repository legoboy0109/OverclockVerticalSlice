# Story 006 / sprint task S5-01: entity sprite renderer + live GameState.entities()
# -> board feed (production/epics/board-renderer/story-006-entity-sprite-feed.md).
#
# Covers the ACs assertable headless via scene-tree and node-property queries —
# node identity/lifetime, texture path resolution, facing, pivot, Y-sort ordering,
# and the 2x tile sizing. Actual pixel output is NOT covered here (the headless
# dummy rasteriser cannot render); that is S5-07's windowed evidence pass.
#
# Integration-type per ADR-0013's classification: BoardRenderer is scene-tree
# coupled, so every test add_child()s it — auto_free() alone does not run _ready().
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

# Rush/Boom indexed by player, matching the vertical slice's own assignment.
const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _make_renderer() -> BoardRenderer:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	return renderer


func _make_feed(renderer: BoardRenderer) -> EntitySpriteFeed:
	return EntitySpriteFeed.new(renderer, FACTIONS)


func _make_unit(id: int, owner: int, tile: Vector2i, type: UnitTypeDef, hp: int = 10) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = id
	unit.owner = owner
	unit.position = tile
	unit.type = type
	unit.current_hp = hp
	return unit


func _make_structure(id: int, owner: int, tile: Vector2i, type: StructureTypeDef, hp: int = 20) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = id
	structure.owner = owner
	structure.position = tile
	structure.type = type
	structure.current_hp = hp
	return structure


func _make_grid(width: int, height: int, cover_tiles: Array[Vector2i] = []) -> GridState:
	var grid := GridState.new()
	grid.width = width
	grid.height = height
	grid.terrain = PackedByteArray()
	grid.terrain.resize(width * height)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(width * height)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	for tile: Vector2i in cover_tiles:
		grid.terrain[grid.index(tile.x, tile.y)] = GridState.Terrain.COVER
	return grid


# Entity sprites only — excludes the Cover props BoardRenderer owns in the same
# layer (see BoardRenderer.COVER_PROP_NAME_PREFIX).
func _entity_sprites(renderer: BoardRenderer) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in renderer.occupant_layer.get_children():
		if not child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			found.append(child)
	return found


# --- AC-1: one node per entity, freed on departure ---------------------------

func test_sync_creates_one_sprite_node_per_live_entity() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [
		_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT),
		_make_unit(2, 1, Vector2i(4, 3), UnitTypes.TROOPER),
		_make_structure(3, 0, Vector2i(0, 0), StructureTypes.HQ),
	]

	# Act
	feed.sync(entities)

	# Assert
	var sprites := _entity_sprites(renderer)
	assert_int(sprites.size()).is_equal(3)
	for sprite: Node in sprites:
		assert_bool(sprite is Sprite2D).is_true()


func test_sync_is_idempotent_and_does_not_duplicate_nodes() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)]

	# Act — same snapshot three times.
	feed.sync(entities)
	feed.sync(entities)
	feed.sync(entities)

	# Assert
	assert_int(_entity_sprites(renderer).size()).is_equal(1)


func test_removed_entity_frees_its_node_leaving_no_orphan() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var kept := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var departing := _make_unit(2, 1, Vector2i(4, 3), UnitTypes.TROOPER)
	var both: Array[EntityState] = [kept, departing]
	feed.sync(both)
	assert_int(_entity_sprites(renderer).size()).is_equal(2)

	# Act — entity 2 leaves the feed (destroyed: GameState erases it same-frame).
	var one: Array[EntityState] = [kept]
	feed.sync(one)

	# Assert — gone from the tree immediately, not merely queued.
	var sprites := _entity_sprites(renderer)
	assert_int(sprites.size()).is_equal(1)
	assert_str(sprites[0].name).is_equal("Entity1")


func test_zero_entities_produces_no_sprite_nodes_and_does_not_crash() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var empty: Array[EntityState] = []

	# Act
	feed.sync(empty)

	# Assert
	assert_int(_entity_sprites(renderer).size()).is_equal(0)


# --- AC-2: §8.2 naming convention -------------------------------------------

func test_unit_texture_path_follows_the_naming_convention() -> void:
	# Arrange
	var scout := _make_unit(1, 0, Vector2i.ZERO, UnitTypes.SCOUT)

	# Act
	var path := EntitySpriteCatalog.texture_path(scout, Factions.RUSH, "e")

	# Assert
	assert_str(path).is_equal("res://assets/art/units/unit_scout_rush_e_idle_01.png")
	assert_bool(ResourceLoader.exists(path)).is_true()


func test_structure_texture_path_follows_the_naming_convention() -> void:
	# Arrange — the multi-word display name must snake_case into the art token.
	var outpost := _make_structure(1, 1, Vector2i.ZERO, StructureTypes.PRODUCTION_OUTPOST)

	# Act
	var path := EntitySpriteCatalog.texture_path(outpost, Factions.BOOM, "e")

	# Assert
	assert_str(path).is_equal("res://assets/art/structures/struct_production_outpost_boom_idle.png")
	assert_bool(ResourceLoader.exists(path)).is_true()


func test_neutral_faction_resolves_neutral_textures() -> void:
	# Arrange
	var scout := _make_unit(1, 0, Vector2i.ZERO, UnitTypes.SCOUT)

	# Act
	var path := EntitySpriteCatalog.texture_path(scout, Factions.NEUTRAL, "w")

	# Assert
	assert_str(path).is_equal("res://assets/art/units/unit_scout_neutral_w_idle_01.png")
	assert_bool(ResourceLoader.exists(path)).is_true()


# --- AC-3: the facing map (only e and w are authored) ------------------------

func test_facing_map_sends_north_and_east_to_east() -> void:
	# Assert — n (0,-1) and e (1,0) both travel screen-RIGHT.
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i(0, -1), "w")).is_equal("e")
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i(1, 0), "w")).is_equal("e")


func test_facing_map_sends_south_and_west_to_west() -> void:
	# Assert — s (0,1) and w (-1,0) both travel screen-LEFT.
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i(0, 1), "e")).is_equal("w")
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i(-1, 0), "e")).is_equal("w")


func test_facing_is_kept_when_travel_has_no_screen_x_component() -> void:
	# Arrange/Assert — a pure-diagonal move carries no left/right information, so
	# facing must not flip arbitrarily.
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i(1, 1), "w")).is_equal("w")
	assert_str(EntitySpriteCatalog.facing_for_delta(Vector2i.ZERO, "e")).is_equal("e")


func test_moving_west_swaps_the_sprite_to_the_west_texture() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var scout := _make_unit(1, 0, Vector2i(4, 4), UnitTypes.SCOUT)
	var snapshot: Array[EntityState] = [scout]
	feed.sync(snapshot)
	var sprite: Sprite2D = _entity_sprites(renderer)[0]
	var before: String = sprite.texture.resource_path

	# Act — travel south (0,+1) == screen-left == west facing.
	scout.position = Vector2i(4, 5)
	feed.sync(snapshot)

	# Assert
	assert_str(before).contains("_e_idle_01.png")
	assert_str(sprite.texture.resource_path).contains("_w_idle_01.png")


# --- AC-4/AC-5: Y-sort group integrity ---------------------------------------

func test_occupants_on_adjacent_rows_sort_by_ground_contact_row() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var near := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var far := _make_unit(2, 1, Vector2i(2, 3), UnitTypes.TROOPER)
	var entities: Array[EntityState] = [near, far]

	# Act
	feed.sync(entities)

	# Assert — the (2,3) occupant is one row further "down" the screen, so its
	# ground-contact y must be greater; the parent's native y_sort_enabled draws
	# it in front. Depth is that y ordering, never a z_index.
	var near_y: float = renderer.grid_to_screen(Vector2i(2, 2)).y
	var far_y: float = renderer.grid_to_screen(Vector2i(2, 3)).y
	assert_float(far_y).is_greater(near_y)
	assert_bool(renderer.occupant_layer.y_sort_enabled).is_true()


func test_no_entity_sprite_sets_a_conflicting_z_index() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [
		_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT),
		_make_structure(2, 1, Vector2i(3, 3), StructureTypes.HQ),
	]

	# Act
	feed.sync(entities)

	# Assert — a child z_index would fight the parent's Y-sort (ADR-0013 §2).
	for sprite: Node in _entity_sprites(renderer):
		assert_int((sprite as Node2D).z_index).is_equal(0)


func test_floor_and_overlay_layers_stay_outside_the_y_sort_group() -> void:
	# Arrange / Act
	var renderer := _make_renderer()

	# Assert — regression against scene_structure_test: the tile layers are
	# siblings of the occupant layer in their own coarse z bands, never inside it.
	assert_bool(renderer.floor_layer.y_sort_enabled).is_false()
	assert_bool(renderer.overlay_layer.y_sort_enabled).is_false()
	assert_int(renderer.floor_layer.z_index).is_equal(BoardRenderer.FLOOR_Z_INDEX)
	assert_int(renderer.overlay_layer.z_index).is_equal(BoardRenderer.OVERLAY_Z_INDEX)
	assert_int(renderer.occupant_layer.z_index).is_equal(BoardRenderer.OCCUPANT_Z_INDEX)


# --- AC-6: cover is TWO nodes, not one cell ----------------------------------

func test_cover_paints_a_floor_cell_and_a_distinct_y_sorted_prop() -> void:
	# Arrange
	var renderer := _make_renderer()
	var cover_tile := Vector2i(1, 1)
	var grid := _make_grid(3, 3, [cover_tile])

	# Act
	renderer.paint_terrain(grid)

	# Assert — a floor cell IS painted under cover (cover's floor is the plain
	# floor; there is no separate cover floor art) ...
	assert_int(renderer.floor_layer.get_cell_source_id(renderer.cell_for(cover_tile))).is_equal(
		BoardRenderer.FLOOR_SOURCE_ID
	)
	# ... AND a separate prop node exists in the Y-sort group. "One PNG = one
	# TileMapLayer cell" is exactly what breaks for cover: a cell cannot
	# participate in the occupant Y-sort at all.
	var props: Array[Node] = []
	for child: Node in renderer.occupant_layer.get_children():
		if child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			props.append(child)
	assert_int(props.size()).is_equal(1)
	assert_bool(props[0] is Sprite2D).is_true()
	assert_vector((props[0] as Sprite2D).position).is_equal(renderer.grid_to_screen(cover_tile))


func test_impassable_tiles_are_left_unpainted_so_the_void_shows_through() -> void:
	# Arrange
	var renderer := _make_renderer()
	var grid := _make_grid(2, 1)
	grid.terrain[grid.index(1, 0)] = GridState.Terrain.IMPASSABLE

	# Act
	renderer.paint_terrain(grid)

	# Assert — the void gap IS the art (assets/art/README.md §6.4).
	assert_int(renderer.floor_layer.get_cell_source_id(renderer.cell_for(Vector2i(0, 0)))).is_equal(
		BoardRenderer.FLOOR_SOURCE_ID
	)
	assert_int(renderer.floor_layer.get_cell_source_id(renderer.cell_for(Vector2i(1, 0)))).is_equal(-1)


func test_repainting_terrain_does_not_accumulate_cover_props() -> void:
	# Arrange
	var renderer := _make_renderer()
	var grid := _make_grid(3, 3, [Vector2i(1, 1), Vector2i(2, 2)])

	# Act — paint twice; paint_terrain is documented idempotent.
	renderer.paint_terrain(grid)
	renderer.paint_terrain(grid)

	# Assert
	var props := 0
	for child: Node in renderer.occupant_layer.get_children():
		if child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			props += 1
	assert_int(props).is_equal(2)


func test_repainting_terrain_leaves_entity_sprites_untouched() -> void:
	# Arrange — the two owners of OccupantLayer must not clobber each other.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var grid := _make_grid(3, 3, [Vector2i(1, 1)])
	renderer.paint_terrain(grid)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(0, 0), UnitTypes.SCOUT)]
	feed.sync(entities)

	# Act
	renderer.paint_terrain(grid)

	# Assert
	assert_int(_entity_sprites(renderer).size()).is_equal(1)


# --- AC-7/AC-8: 2x textures without moving the on-screen cell ----------------

func test_floor_tileset_is_two_times_the_on_screen_cell_with_a_half_layer_scale() -> void:
	# Arrange / Act
	var renderer := _make_renderer()

	# Assert
	assert_vector(renderer.floor_layer.tile_set.tile_size).is_equal(Vector2i(256, 128))
	assert_float(renderer.floor_layer.scale.x).is_equal_approx(0.5, 0.0001)
	assert_float(renderer.floor_layer.scale.y).is_equal_approx(0.5, 0.0001)
	# The ON-SCREEN cell is unchanged — TILE_WIDTH_PX/TILE_HEIGHT_PX are that size.
	assert_float(BoardRenderer.TILE_WIDTH_PX).is_equal_approx(128.0, 0.0001)
	assert_float(BoardRenderer.TILE_HEIGHT_PX).is_equal_approx(64.0, 0.0001)
	assert_float(renderer.floor_layer.tile_set.tile_size.x * renderer.floor_layer.scale.x).is_equal_approx(
		BoardRenderer.TILE_WIDTH_PX, 0.0001
	)


func test_grid_to_screen_round_trip_is_unchanged_by_the_tile_size_change() -> void:
	# Arrange
	var renderer := _make_renderer()
	var tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(7, 3), Vector2i(11, 9),
	]

	# Assert — regression against transform_round_trip_test: the doubled tile_size
	# is absorbed entirely by the layer scale and never reaches the transform pair.
	for tile: Vector2i in tiles:
		assert_vector(renderer.screen_to_grid(renderer.grid_to_screen(tile))).is_equal(tile)


# --- AC-9: bottom-centre ground-contact pivot --------------------------------

func test_sprite_bottom_centre_lands_on_grid_to_screen_with_no_extra_offset() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var tile := Vector2i(3, 4)
	var entities: Array[EntityState] = [_make_unit(1, 0, tile, UnitTypes.HEAVY)]

	# Act
	feed.sync(entities)

	# Assert — the drawn rect's bottom-centre must BE the anchor point. Sprites are
	# trimmed to their opaque bounds so sizes differ per asset; this is computed
	# from the texture, never from an assumed common frame.
	var sprite: Sprite2D = _entity_sprites(renderer)[0]
	var drawn_top_left: Vector2 = sprite.position + sprite.offset * sprite.scale
	var drawn_size: Vector2 = sprite.texture.get_size() * sprite.scale
	var bottom_centre := Vector2(
		drawn_top_left.x + drawn_size.x * 0.5,
		drawn_top_left.y + drawn_size.y
	)
	assert_vector(bottom_centre).is_equal_approx(renderer.grid_to_screen(tile), Vector2(0.001, 0.001))


func test_sprites_are_drawn_at_half_scale_because_art_ships_at_two_times() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]

	# Act
	feed.sync(entities)

	# Assert — never blit 1:1 (art-bible §8.3).
	var sprite: Sprite2D = _entity_sprites(renderer)[0]
	assert_float(sprite.scale.x).is_equal_approx(0.5, 0.0001)
	assert_bool(sprite.centered).is_false()


# --- AC-10: destroyed state --------------------------------------------------

func test_destroyed_entity_resolves_the_destroyed_texture() -> void:
	# Arrange — hp at zero. NOTE: GameState.destroy_entity() erases the entity in
	# the same frame, so this state does not reach a live feed until S5-06 adds the
	# death-echo hold; the resolver is correct either way.
	var dead_unit := _make_unit(1, 0, Vector2i.ZERO, UnitTypes.SCOUT, 0)
	var dead_structure := _make_structure(2, 1, Vector2i.ZERO, StructureTypes.HQ, 0)

	# Act
	var unit_path := EntitySpriteCatalog.texture_path(dead_unit, Factions.RUSH, "e")
	var structure_path := EntitySpriteCatalog.texture_path(dead_structure, Factions.BOOM, "e")

	# Assert
	assert_str(unit_path).is_equal("res://assets/art/units/unit_scout_rush_e_destroyed_01.png")
	assert_str(structure_path).is_equal("res://assets/art/structures/struct_hq_boom_destroyed.png")
	assert_bool(ResourceLoader.exists(unit_path)).is_true()
	assert_bool(ResourceLoader.exists(structure_path)).is_true()


# --- Edge cases --------------------------------------------------------------

func test_entities_at_grid_extremes_place_without_error() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var origin := Vector2i(0, 0)
	var far := Vector2i(11, 9)
	var entities: Array[EntityState] = [
		_make_unit(1, 0, origin, UnitTypes.SCOUT),
		_make_unit(2, 1, far, UnitTypes.TROOPER),
	]

	# Act
	feed.sync(entities)

	# Assert
	var sprites := _entity_sprites(renderer)
	assert_int(sprites.size()).is_equal(2)
	assert_vector((sprites[0] as Sprite2D).position).is_equal(renderer.grid_to_screen(origin))
	assert_vector((sprites[1] as Sprite2D).position).is_equal(renderer.grid_to_screen(far))


func test_unshipped_type_resolves_a_path_that_does_not_exist_rather_than_blank() -> void:
	# Arrange — Sniper, Defensive Structure, Economy Outpost and Research Lab have
	# NO shipped art as of 2026-08-19. The contract is that this is an explicit,
	# detectable miss, never a silently blank sprite.
	var sniper := _make_unit(1, 0, Vector2i.ZERO, UnitTypes.SNIPER)

	# Act
	var path := EntitySpriteCatalog.texture_path(sniper, Factions.RUSH, "e")

	# Assert — a well-formed path that simply has no file behind it, which is what
	# EntitySpriteFeed._texture_for turns into a push_error + magenta placeholder.
	assert_str(path).is_equal("res://assets/art/units/unit_sniper_rush_e_idle_01.png")
	assert_bool(ResourceLoader.exists(path)).is_false()


func test_pick_regions_are_authored_from_sprite_bounds_back_to_front() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var near := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var far := _make_unit(2, 1, Vector2i(2, 4), UnitTypes.TROOPER)
	var entities: Array[EntityState] = [far, near]
	feed.sync(entities)

	# Act
	var regions := feed.pick_regions()

	# Assert — back-to-front (ascending screen y), and each rect is the sprite's
	# real drawn extent, not a tile diamond.
	assert_int(regions.size()).is_equal(2)
	assert_int(regions[0].entity_id).is_equal(1)
	assert_int(regions[1].entity_id).is_equal(2)
	assert_vector(regions[0].tile).is_equal(Vector2i(2, 2))
	# The region must cover BOTH the tile the unit stands on and its body — child
	# order is feed-insertion order, so look the sprite up by name, not by index.
	var anchor: Vector2 = renderer.grid_to_screen(Vector2i(2, 2))
	assert_bool(regions[0].rect.has_point(anchor)).is_true()
	assert_bool(regions[0].rect.has_point(anchor - Vector2(0.0, 8.0))).is_true()
	assert_bool(regions[0].rect.size.x >= BoardRenderer.TILE_WIDTH_PX).is_true()


# --- Floor/sprite alignment (the bug this story surfaced) --------------------

func test_painted_floor_cells_draw_exactly_where_grid_to_screen_says() -> void:
	# Arrange — this is the regression for the engine-iso cell-basis mismatch.
	# Painting raw grid coords via set_cell() put the board up to 1408px away from
	# the sprites, because Redot lays isometric cells out in a stacked basis whose
	# axes are not this project's (x-y, x+y) dimetric pair (ADR-0013 §1, GH#89423).
	var renderer := _make_renderer()
	var layer := renderer.floor_layer

	# Assert — every tile's cell must draw at that tile's sprite anchor.
	for y in 10:
		for x in 12:
			var tile := Vector2i(x, y)
			var drawn: Vector2 = layer.map_to_local(renderer.cell_for(tile)) * layer.scale + layer.position
			assert_vector(drawn).is_equal_approx(renderer.grid_to_screen(tile), Vector2(0.01, 0.01))


func test_cell_for_is_injective_across_the_board() -> void:
	# Arrange — two grid tiles collapsing onto one cell would silently drop a tile.
	var renderer := _make_renderer()
	var seen := {}

	# Act / Assert
	for y in 10:
		for x in 12:
			var cell: Vector2i = renderer.cell_for(Vector2i(x, y))
			assert_bool(seen.has(cell)).is_false()
			seen[cell] = true
	assert_int(seen.size()).is_equal(120)


func test_overlay_cells_land_on_the_same_anchors_as_floor_cells() -> void:
	# Arrange — ADR-0013 §3's floor/overlay alignment guarantee, now actually
	# asserted rather than assumed (its evidence doc was owed and never filed).
	var renderer := _make_renderer()
	var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 3), Vector2i(11, 9)]

	# Act
	renderer.set_overlay(tiles, BoardRenderer.OverlayClass.MOVE_IN_CAP)

	# Assert
	for tile: Vector2i in tiles:
		var cell: Vector2i = renderer.cell_for(tile)
		var floor_pos: Vector2 = renderer.floor_layer.map_to_local(cell) * renderer.floor_layer.scale
		var overlay_pos: Vector2 = renderer.overlay_layer.map_to_local(cell) * renderer.overlay_layer.scale
		assert_vector(overlay_pos).is_equal_approx(floor_pos, Vector2(0.01, 0.01))
		assert_int(renderer.overlay_layer.get_cell_source_id(cell)).is_equal(
			BoardRenderer.OverlayClass.MOVE_IN_CAP
		)


# --- Structure footprint (user decision 2026-08-19) --------------------------

func test_structures_are_fitted_to_their_one_tile_footprint() -> void:
	# Arrange — the asset spec authored HQ/Outpost to a "multi-tile footprint" the
	# simulation never gave them: a structure occupies exactly one tile. Drawn at the
	# unit scale the HQ landed two tiles wide, and a silhouette covering tiles it does
	# not occupy misleads about blocking and range.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [
		_make_structure(1, 0, Vector2i(2, 2), StructureTypes.HQ),
		_make_structure(2, 1, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST),
	]

	# Act
	feed.sync(entities)

	# Assert — both land at exactly one tile wide, despite shipping at different
	# source sizes (512 vs 384).
	for sprite: Node in _entity_sprites(renderer):
		var drawn_width: float = (sprite as Sprite2D).texture.get_size().x * (sprite as Sprite2D).scale.x
		assert_float(drawn_width).is_equal_approx(BoardRenderer.TILE_WIDTH_PX, 0.01)
		# Uniform scale — a non-uniform fit would distort the art.
		assert_float((sprite as Sprite2D).scale.x).is_equal_approx((sprite as Sprite2D).scale.y, 0.0001)


func test_units_keep_the_flat_two_times_art_scale() -> void:
	# Arrange — only structures are footprint-fitted; units ship authored to their
	# on-screen size already (art-bible §8.3).
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]

	# Act
	feed.sync(entities)

	# Assert
	assert_float((_entity_sprites(renderer)[0] as Sprite2D).scale.x).is_equal_approx(0.5, 0.0001)


func test_structure_pivot_stays_at_ground_contact_after_the_footprint_fit() -> void:
	# Arrange — the fit changes scale, and offset is applied pre-scale, so this is the
	# regression that would catch the two going out of step.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var tile := Vector2i(4, 6)
	var entities: Array[EntityState] = [_make_structure(1, 0, tile, StructureTypes.HQ)]

	# Act
	feed.sync(entities)

	# Assert
	var sprite: Sprite2D = _entity_sprites(renderer)[0]
	var top_left: Vector2 = sprite.position + sprite.offset * sprite.scale
	var drawn: Vector2 = sprite.texture.get_size() * sprite.scale
	var bottom_centre := Vector2(top_left.x + drawn.x * 0.5, top_left.y + drawn.y)
	assert_vector(bottom_centre).is_equal_approx(renderer.grid_to_screen(tile), Vector2(0.01, 0.01))
