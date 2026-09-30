# HD-2D lighting pass (2026-09-30) — baked glow halo, floor light pools, edge blur.
#
# What these guard, all of which a real render showed can silently go wrong:
#  • the HUD must stay ABOVE the edge-blur layer (text legibility);
#  • light pools must light the floor and NEVER a unit (a neighbour's light tinting a
#    unit would muddy the ownership hue, art bible §4.2);
#  • pools are sized in screen pixels, not in each sprite's own scale;
#  • HDR 2D stays OFF — it re-blended every translucent overlay in linear space (ADR-0020);
#  • the halo pads the mask without moving the rim off the armour.
# Visual quality itself is judged from real GPU renders (tools/CaptureRoster.tscn under
# gamescope), not here — headless runs do not rasterise.
extends GdUnitTestSuite

const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _unit(id: int, owner: int, tile: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	return u


func _structure(id: int, owner: int, tile: Vector2i, type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = id
	s.owner = owner
	s.position = tile
	s.type = type
	s.current_hp = 20
	return s


func _sprites(renderer: BoardRenderer) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in renderer.occupant_layer.get_children():
		if child is Sprite2D and not child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			out.append(child)
	return out


func test_canvas_layer_order_is_board_then_blur_then_hud() -> void:
	assert_int(Hd2dLighting.WORLD_CANVAS_LAYER).is_less(Hd2dLighting.BLUR_CANVAS_LAYER)
	assert_int(Hd2dLighting.BLUR_CANVAS_LAYER).is_less(Hd2dLighting.HUD_CANVAS_LAYER)


func test_the_real_hud_draws_above_the_blur_layer() -> void:
	var root: Node = preload("res://scenes/vertical_slice.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	var layers: Array[CanvasLayer] = []
	for child: Node in root.get_children():
		if child is CanvasLayer:
			layers.append(child)
	var blur := root.find_child("Hd2dEdgeBlur", true, false) as CanvasLayer
	assert_object(blur).is_not_null()
	for layer: CanvasLayer in layers:
		if layer.name == "Hd2dEdgeBlur":
			continue
		assert_int(layer.layer).override_failure_message(
			"screen layer '%s' (layer %d) would be blurred" % [layer.name, layer.layer]
		).is_greater(blur.layer)
	root.queue_free()
	await get_tree().process_frame


func test_every_actor_gets_one_floor_light_pool_in_its_owners_hue() -> void:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [
		_unit(1, 0, Vector2i(1, 1), UnitTypes.TROOPER),
		_unit(2, 1, Vector2i(3, 3), UnitTypes.TANK),
	]
	feed.sync(entities)
	feed.sync(entities)   # a second sync must not stack a second pool
	for sprite: Sprite2D in _sprites(renderer):
		var pools: Array[Node] = sprite.find_children(EntityLightPools.NODE_NAME, "PointLight2D", false, false)
		assert_int(pools.size()).is_equal(1)
	var p0 := _sprites(renderer)[0].get_node(EntityLightPools.NODE_NAME) as PointLight2D
	var p1 := _sprites(renderer)[1].get_node(EntityLightPools.NODE_NAME) as PointLight2D
	assert_that(p0.color).is_equal(EntityGlow.hue_for(Factions.RUSH))
	assert_that(p1.color).is_equal(EntityGlow.hue_for(Factions.BOOM))


func test_pools_light_the_floor_and_never_a_sprite() -> void:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]
	feed.sync(entities)
	var sprite: Sprite2D = _sprites(renderer)[0]
	var pool := sprite.get_node(EntityLightPools.NODE_NAME) as PointLight2D
	# The pool only reaches canvas items carrying the floor bit...
	assert_int(pool.range_item_cull_mask).is_equal(EntityLightPools.FLOOR_LIGHT_MASK)
	# ...the floor carries it...
	assert_int(renderer.floor_layer.light_mask & EntityLightPools.FLOOR_LIGHT_MASK).is_not_equal(0)
	# ...and the actor does not.
	assert_int(sprite.light_mask & EntityLightPools.FLOOR_LIGHT_MASK).is_equal(0)


func test_pools_are_the_same_screen_size_for_units_and_fitted_structures() -> void:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [
		_unit(1, 0, Vector2i(1, 1), UnitTypes.TROOPER),
		_structure(2, 0, Vector2i(5, 5), StructureTypes.HQ),
	]
	feed.sync(entities)
	var widths: Array[float] = []
	for sprite: Sprite2D in _sprites(renderer):
		var pool := sprite.get_node(EntityLightPools.NODE_NAME) as PointLight2D
		widths.append(EntityLightPools.TEXTURE_SIZE.x * pool.scale.x * sprite.scale.x)
	assert_float(widths[0]).is_equal_approx(EntityLightPools.POOL_WIDTH_PX, 0.01)
	assert_float(widths[1]).is_equal_approx(EntityLightPools.POOL_WIDTH_PX, 0.01)


func test_hdr_2d_stays_off() -> void:
	# ADR-0020: HDR 2D blends translucency in linear space and made the move-range overlay
	# near-solid. Turning it back on silently re-tunes every overlay, tint and fade.
	assert_bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)).is_false()


func test_halo_pads_the_mask_evenly_and_keeps_the_rim() -> void:
	var path := "res://assets/art/units/unit_trooper_e_idle_01_glow.png"
	var mask: Image = (load(path) as Texture2D).get_image()
	mask.convert(Image.FORMAT_L8)
	var halo: Image = EntityGlow.halo_texture(path).get_image()
	var pad: int = EntityGlow.HALO_PAD_PX
	assert_vector(Vector2(halo.get_size())).is_equal(Vector2(mask.get_size() + Vector2i(pad * 2, pad * 2)))
	# The rim is never dimmed by the halo pass: every mask pixel survives at >= itself.
	var worst: int = 0
	for y: int in range(0, mask.get_height(), 3):
		for x: int in range(0, mask.get_width(), 3):
			var m: int = mask.get_pixel(x, y).r8
			var hv: int = halo.get_pixel(x + pad, y + pad).r8
			worst = maxi(worst, m - hv)
	assert_int(worst).is_less_equal(1)
	# And light actually spills past the sprite's own bounds (the point of a halo).
	var spill: bool = false
	for x: int in halo.get_width():
		if halo.get_pixel(x, pad - 3).r8 > 0 or halo.get_pixel(x, halo.get_height() - pad + 2).r8 > 0:
			spill = true
			break
	assert_bool(spill).is_true()


func test_halo_texture_is_built_once_per_mask() -> void:
	var path := "res://assets/art/units/unit_scout_e_idle_01_glow.png"
	assert_object(EntityGlow.halo_texture(path)).is_same(EntityGlow.halo_texture(path))


func test_glow_off_gives_the_plain_trim_and_hides_the_pools() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_unit(1, 0, Vector2i(1, 1), UnitTypes.TROOPER)]
	feed.sync(entities)
	# Act
	feed.glow_enabled = false
	feed.sync(entities)
	# Assert — the pre-lighting look: mask drawn at the body's own frame, no pool.
	var body: Sprite2D = _sprites(renderer)[0]
	var glow := body.get_node(^"Glow") as Sprite2D
	assert_vector(glow.offset).is_equal(body.offset)
	assert_vector(glow.texture.get_size()).is_equal(body.texture.get_size())
	assert_bool((body.get_node(EntityLightPools.NODE_NAME) as PointLight2D).visible).is_false()
	# And back on restores the halo and the pool.
	feed.glow_enabled = true
	feed.sync(entities)
	assert_vector(glow.offset).is_equal(EntityGlow.halo_offset(body.offset))
	assert_bool((body.get_node(EntityLightPools.NODE_NAME) as PointLight2D).visible).is_true()


func _pools_visible(root: Node) -> bool:
	var any: bool = false
	for node: Node in root.find_children(EntityLightPools.NODE_NAME, "PointLight2D", true, false):
		any = any or (node as PointLight2D).visible
	return any


func test_blur_and_glow_toggles_apply_live_and_independently_while_paused() -> void:
	# Arrange — Settings is opened from the PAUSE menu, where the slice's own _process is
	# frozen; each toggle must still reach the board behind the menu, and only its own
	# effect may change.
	var root: Node = preload("res://scenes/vertical_slice.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	var blur := root.find_child("Hd2dEdgeBlur", true, false) as CanvasLayer
	var screen := SettingsScreen.new()
	add_child(screen)
	await get_tree().process_frame
	get_tree().paused = true

	# Act 1 — blur off only
	screen.toggle_blur(false)
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert 1
	assert_bool(blur.visible).is_false()
	assert_bool(_pools_visible(root)).is_true()

	# Act 2 — blur back on, glow off
	screen.toggle_blur(true)
	screen.toggle_glow(false)
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert 2
	assert_bool(blur.visible).is_true()
	assert_bool(_pools_visible(root)).is_false()

	# Cleanup — restore the shipped defaults for every later test (the screen saved them).
	screen.toggle_glow(true)
	get_tree().paused = false
	await get_tree().process_frame
	screen.queue_free()
	root.queue_free()
	await get_tree().process_frame
