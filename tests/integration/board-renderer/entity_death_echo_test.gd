# Story 008 / sprint task S5-06: the death echo — EntitySpriteFeed.power_down.
#
# GameState.destroy_entity erases an entity in the same frame its hp hits zero, so
# a destroyed actor never appears in a sync snapshot and its sprite would be freed
# by the very sync that reveals the death. §8.5 locks a 2-4 frame power-down that
# would therefore have nothing to play on. The echo is the node-lifetime mechanism
# that fixes that, and lifetime is logic, not feel — this suite covers it.
#
# It also closes Story 006 AC-10, which resolved the `destroyed` texture token
# correctly but noted that "nothing puts it on screen until S5-06 adds the
# death-echo hold" (see EntitySpriteCatalog.STATE_DESTROYED).
#
# Covers:
#   * a power_down'd id survives the sync that drops it, where an ordinary
#     departure does not (the control case is asserted in the same test).
#   * a dying actor is not a clickable occupant — it holds no tile.
#   * the destroyed ART is what fades in: a child sprite carrying the
#     *_destroyed_01 texture (Story 006 AC-10, on screen at last).
#   * the beat ends: the node and every map entry are gone afterwards, no orphan.
#   * an id recycled mid-echo rebuilds clean rather than wearing the corpse's fade.
#
# NOT covered (cannot be, headless): how the motion and the cross-fade actually
# look. That is S5-07 windowed Visual/Feel evidence.
#
# Integration-type per ADR-0013: BoardRenderer is scene-tree coupled, so every
# test add_child()s it. Fixtures mirror entity_sprite_feed_test.gd.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

# Rush/Boom indexed by player, matching the vertical slice's own assignment.
const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]

# The wreck overlay's node name, set by EntitySpriteFeed._build_wreck.
const WRECK_NODE_NAME: String = "Destroyed"


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


# Entity sprites only — excludes the Cover props BoardRenderer owns in the same
# layer.
func _entity_sprites(renderer: BoardRenderer) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in renderer.occupant_layer.get_children():
		if not child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			found.append(child)
	return found


# Waits out the whole destroyed beat with a wide margin (2x the locked duration
# plus a frame's slack), then lets the queue_free() land. A completion wait, not a
# timing assertion — nothing here asserts WHEN anything happened, only that the
# beat has finished by the time we look.
func _await_death_beat() -> void:
	await get_tree().create_timer(EntityTransforms.DEATH_ECHO_SEC * 2.0 + 0.1).timeout
	await get_tree().process_frame


# --- The node survives the sync that drops it -------------------------------

func test_power_down_keeps_the_node_alive_through_the_sync_that_drops_it() -> void:
	# Arrange — two units on the board; both will vanish from the next snapshot,
	# but only one is announced as destroyed.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var killed := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var withdrawn := _make_unit(2, 0, Vector2i(4, 2), UnitTypes.SCOUT)
	feed.sync([killed, withdrawn] as Array[EntityState])
	assert_int(_entity_sprites(renderer).size()).is_equal(2)

	# Act — the death is announced BEFORE the sync, as the slice does it.
	killed.current_hp = 0
	feed.power_down(1)
	feed.sync([] as Array[EntityState])

	# Assert — the destroyed one is held on screen for its beat; the one that
	# merely departed is gone immediately (the control case).
	assert_bool(feed.is_dying(1)).is_true()
	assert_bool(feed.is_dying(2)).is_false()
	var sprites := _entity_sprites(renderer)
	assert_int(sprites.size()).is_equal(1)
	assert_str(sprites[0].name).is_equal("Entity1")


# --- A dying actor is not a clickable occupant ------------------------------

func test_dying_entity_is_excluded_from_the_pick_regions() -> void:
	# Arrange — a live neighbour proves regions are still authored at all.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var killed := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var survivor := _make_unit(2, 0, Vector2i(4, 2), UnitTypes.SCOUT)
	feed.sync([killed, survivor] as Array[EntityState])

	# Act
	killed.current_hp = 0
	feed.power_down(1)
	feed.sync([survivor] as Array[EntityState])

	# Assert — an afterimage cannot be selected or targeted; the simulation has
	# already erased it and it holds no tile.
	var ids: Array[int] = []
	for region: BoardRenderer.OccupantPickRegion in feed.pick_regions():
		ids.append(region.entity_id)
	assert_array(ids).contains([2])
	assert_array(ids).not_contains([1])


# --- Story 006 AC-10: the destroyed art finally reaches the screen ----------

func test_power_down_adds_a_child_carrying_the_destroyed_texture() -> void:
	# Arrange — Scout ships destroyed art for every hue (assets/art/units/).
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var killed := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	feed.sync([killed] as Array[EntityState])
	var body: Sprite2D = _entity_sprites(renderer)[0] as Sprite2D
	var idle_path: String = body.texture.resource_path

	# Act
	killed.current_hp = 0
	feed.power_down(1)

	# Assert — a second sprite carrying the DESTROYED art, transparent so it can
	# fade IN over the idle art rather than replacing it with a cut.
	var wreck: Sprite2D = body.get_node_or_null(NodePath(WRECK_NODE_NAME)) as Sprite2D
	assert_object(wreck).is_not_null()
	assert_str(wreck.texture.resource_path).contains(EntitySpriteCatalog.STATE_DESTROYED)
	assert_str(wreck.texture.resource_path).is_not_equal(idle_path)
	assert_float(wreck.self_modulate.a).is_equal_approx(0.0, 0.0001)
	# Bottom-centre pivot holds for the wreck too, so it stands where the body did.
	assert_float(wreck.offset.y).is_equal_approx(-wreck.texture.get_size().y, 0.0001)


# --- The beat ends and takes everything with it -----------------------------

func test_the_beat_ends_leaving_no_node_and_no_orphan() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var killed := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	feed.sync([killed] as Array[EntityState])

	# Act
	killed.current_hp = 0
	feed.power_down(1)
	feed.sync([] as Array[EntityState])
	await _await_death_beat()

	# Assert — the deferred free landed: nothing on the layer, nothing still
	# marked dying, and no pick region left pointing at a freed node.
	assert_bool(feed.is_dying(1)).is_false()
	assert_int(_entity_sprites(renderer).size()).is_equal(0)
	assert_int(feed.pick_regions().size()).is_equal(0)


# --- A recycled id rebuilds clean -------------------------------------------

func test_an_id_reused_mid_beat_rebuilds_instead_of_wearing_the_corpse() -> void:
	# Arrange — entity 1 dies and starts its beat.
	var renderer := _make_renderer()
	var feed := _make_feed(renderer)
	var killed := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	feed.sync([killed] as Array[EntityState])
	killed.current_hp = 0
	feed.power_down(1)
	assert_bool(feed.is_dying(1)).is_true()

	# Act — a live entity arrives on the same id before the beat finishes.
	var recycled := _make_unit(1, 1, Vector2i(5, 5), UnitTypes.TROOPER)
	feed.sync([recycled] as Array[EntityState])

	# Assert — one node, not dying, and no wreck overlay inherited from the corpse.
	assert_bool(feed.is_dying(1)).is_false()
	var sprites := _entity_sprites(renderer)
	assert_int(sprites.size()).is_equal(1)
	var body: Sprite2D = sprites[0] as Sprite2D
	assert_object(body.get_node_or_null(NodePath(WRECK_NODE_NAME))).is_null()
	assert_vector(body.position).is_equal(renderer.grid_to_screen(Vector2i(5, 5)))
