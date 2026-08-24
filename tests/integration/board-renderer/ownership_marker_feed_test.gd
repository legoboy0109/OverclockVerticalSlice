# Story 009 / sprint task S5-08 (option D3): the feed's ownership-decal lifecycle.
#
# OwnershipMarker owns the decal's geometry (covered by
# tests/unit/board-renderer/ownership_marker_test.gd); this suite covers
# EntitySpriteFeed placing, updating, scoping and freeing one per entity.
#
# Covers:
#   * one decal per entity on MarkerLayer, carrying its OWNER's faction texture
#   * placed at the tile centre, and it follows the entity when it moves
#   * the decal belongs to the TILE — an in-flight §8.5 motion transform must not
#     drag it along, which is why it is a sibling in another layer and not a child
#     of the body sprite
#   * no decal sets a z_index (ADR-0013 §2 — the layer carries the band)
#   * marker_policy scopes which entities get one (the S5-03 clutter knob)
#   * decals are freed with their entity, leaving no orphan
#
# Integration-type per ADR-0013: BoardRenderer is scene-tree coupled, so every test
# add_child()s it. Fixtures mirror entity_sprite_feed_test.gd.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _make_renderer() -> BoardRenderer:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	return renderer


func _make_feed(renderer: BoardRenderer) -> EntitySpriteFeed:
	return EntitySpriteFeed.new(renderer, FACTIONS)


# A feed with the board-wide policy, for the tests that assert decal MECHANICS
# (placement, texture, parenting, teardown) using units as the convenient fixture.
# The shipped default is STRUCTURES_ONLY (2026-08-21 user decision), which those
# tests would otherwise trip over — they are about how a decal behaves, not about
# which entities get one. Scope itself is covered by the policy tests below.
func _make_feed_all(renderer: BoardRenderer) -> EntitySpriteFeed:
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	feed.marker_policy = EntitySpriteFeed.MarkerPolicy.ALL
	return feed


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


func _markers(renderer: BoardRenderer) -> Array[Node]:
	return renderer.marker_layer.get_children()


# --- One decal per entity, carrying its owner's faction --------------------------

func test_sync_places_one_decal_per_entity_on_the_marker_layer() -> void:
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	feed.sync([
		_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT),
		_make_unit(2, 1, Vector2i(4, 3), UnitTypes.TROOPER),
		_make_structure(3, 0, Vector2i(0, 0), StructureTypes.HQ),
	] as Array[EntityState])

	assert_int(_markers(renderer).size()).is_equal(3)
	for marker: Node in _markers(renderer):
		assert_bool(marker is Sprite2D).is_true()


func test_decal_carries_the_owning_factions_texture() -> void:
	# The two players are Rush and Boom, so their decals must not share an image —
	# this is the ownership signal itself.
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	feed.sync([
		_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT),
		_make_unit(2, 1, Vector2i(4, 3), UnitTypes.SCOUT),
	] as Array[EntityState])

	var rush_marker: Sprite2D = renderer.marker_layer.get_node("Marker1") as Sprite2D
	var boom_marker: Sprite2D = renderer.marker_layer.get_node("Marker2") as Sprite2D
	assert_object(rush_marker.texture).is_same(OwnershipMarker.texture_for(Factions.RUSH))
	assert_object(boom_marker.texture).is_same(OwnershipMarker.texture_for(Factions.BOOM))
	assert_object(rush_marker.texture).is_not_same(boom_marker.texture)


# --- It belongs to the tile ------------------------------------------------------

func test_decal_sits_at_the_tile_centre_and_follows_a_move() -> void:
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	var unit := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	feed.sync([unit] as Array[EntityState])
	var marker: Sprite2D = renderer.marker_layer.get_node("Marker1") as Sprite2D
	assert_vector(marker.position).is_equal(renderer.grid_to_screen(Vector2i(2, 2)))

	unit.position = Vector2i(5, 6)
	feed.sync([unit] as Array[EntityState])
	assert_vector(marker.position).is_equal(renderer.grid_to_screen(Vector2i(5, 6)))


func test_decal_is_a_sibling_in_the_marker_layer_not_a_child_of_the_body() -> void:
	# A child would inherit the §8.5 motion transforms — leaning with a moving unit
	# and lunging with an attacking one — when the decal must stay flat on its tile.
	# It also has to draw UNDER its entity, which a child cannot do without a
	# z_index that ADR-0013 §2 forbids.
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	feed.sync([_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)] as Array[EntityState])

	var marker: Node = renderer.marker_layer.get_node("Marker1")
	assert_object(marker.get_parent()).is_same(renderer.marker_layer)
	for child: Node in renderer.occupant_layer.get_children():
		assert_object(child.get_node_or_null(NodePath("Marker1"))).is_null()


func test_no_decal_sets_a_conflicting_z_index() -> void:
	# The LAYER carries the band; a child setting its own would be the exact escape
	# ADR-0013 §2's guardrail forbids.
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	feed.sync([
		_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT),
		_make_structure(3, 1, Vector2i(0, 0), StructureTypes.HQ),
	] as Array[EntityState])

	for marker: Node in _markers(renderer):
		assert_int((marker as Node2D).z_index).is_equal(0)


func test_marker_layer_draws_under_occupants_and_over_overlays() -> void:
	# The ordering the whole design depends on: ownership stays legible through a
	# range highlight, but an actor standing on the tile still occludes its decal.
	var renderer := _make_renderer()
	assert_int(renderer.overlay_layer.z_index).is_less(renderer.marker_layer.z_index)
	assert_int(renderer.marker_layer.z_index).is_less(renderer.occupant_layer.z_index)


# --- Scope knob ------------------------------------------------------------------

func test_structures_only_is_the_default_and_decals_structures_not_units() -> void:
	# THE SHIPPED DEFAULT (user decision 2026-08-21). Units already carry ownership
	# strongly on their own (26-82% accent coverage, dE 60-76 deuteranopia); the
	# measured weakness was entirely structural, so the decal goes where the problem
	# is rather than under everything. Asserted WITHOUT setting the policy, so a
	# silent change to the default fails here.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	assert_int(feed.marker_policy).is_equal(EntitySpriteFeed.MarkerPolicy.STRUCTURES_ONLY)
	feed.sync([
		_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT),
		_make_structure(3, 0, Vector2i(0, 0), StructureTypes.HQ),
	] as Array[EntityState])

	var names: Array[String] = []
	for marker: Node in _markers(renderer):
		names.append(marker.name)
	assert_array(names).contains(["Marker3"])
	assert_array(names).not_contains(["Marker1"])


func test_none_policy_draws_no_decals_and_drops_existing_ones() -> void:
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)]
	feed.sync(entities)
	assert_int(_markers(renderer).size()).is_equal(1)

	feed.marker_policy = EntitySpriteFeed.MarkerPolicy.NONE
	feed.sync(entities)
	assert_int(_markers(renderer).size()).is_equal(0)


# --- Teardown --------------------------------------------------------------------

func test_departed_entity_takes_its_decal_with_it() -> void:
	var renderer := _make_renderer()
	var feed := _make_feed_all(renderer)
	var stays := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var goes := _make_unit(2, 1, Vector2i(4, 3), UnitTypes.SCOUT)
	feed.sync([stays, goes] as Array[EntityState])
	assert_int(_markers(renderer).size()).is_equal(2)

	feed.sync([stays] as Array[EntityState])
	assert_int(_markers(renderer).size()).is_equal(1)
	assert_str(_markers(renderer)[0].name).is_equal("Marker1")
