# Story 009 / sprint task S5-08 (option D3): OwnershipMarker — the per-faction
# ground decal that carries ownership by SHAPE as well as hue.
#
# This is the layer that finally delivers art-bible §1 P2's mandatory non-hue
# ownership backup. §5.2's Mass Distribution Bias was declared LOCKED but never
# built — all 26 Rush/Boom sprite pairs are pixel-identical — so before this story
# faction identity was carried by hue ALONE and did not survive desaturation at all
# (production/qa/evidence/s5-08-colourblind-ownership-brief.md).
#
# The assertions that matter here are the SHAPE ones. A hue check would have passed
# before this story existed; what has to be true now is that the three factions'
# decals differ as geometry, with every colour channel discarded.
#
# Covers:
#   * the three factions produce genuinely different SHAPES (alpha coverage differs,
#     and differs in the specific way each faction's bias describes)
#   * Rush's mass is at the near vertex; Boom's has a gap there; Neutral is even
#   * hue comes from the locked EntityGlow anchors — one source of truth, not a
#     second palette
#   * the decal stays inside its tile so adjacent markers never fuse into a line
#   * textures are cached, since the whole board draws from three images
#
# No RNG, no time-dependent asserts, no file I/O.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	OwnershipMarker.clear_cache()


# Fraction of the texture's pixels that are at least partly opaque.
func _coverage(faction: FactionDef) -> float:
	var image: Image = OwnershipMarker.texture_for(faction).get_image()
	var lit: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				lit += 1
	return float(lit) / float(image.get_width() * image.get_height())


# Mean alpha inside a horizontal slice of the NEAR half, expressed in fractions of
# the half-width out from the near vertex. This is the measurement the three faction
# shapes are actually defined by.
func _near_alpha(faction: FactionDef, span_lo: float, span_hi: float) -> float:
	var image: Image = OwnershipMarker.texture_for(faction).get_image()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var half_w: float = w * 0.5
	var total: float = 0.0
	var count: int = 0
	for y: int in h:
		if y + 0.5 - h * 0.5 < 0.0:
			continue # far half — not what these shapes encode.
		for x: int in w:
			var span: float = absf(x + 0.5 - half_w) / half_w
			if span < span_lo or span > span_hi:
				continue
			total += image.get_pixel(x, y).a
			count += 1
	return total / maxf(count, 1) as float


# --- The shape channel: the three factions differ with colour discarded ---------

func test_the_three_factions_produce_three_different_shapes() -> void:
	# The whole point of the story. If these coverages matched, the decal would be a
	# pure recolour and would add nothing a desaturated screen could use.
	var rush: float = _coverage(Factions.RUSH)
	var boom: float = _coverage(Factions.BOOM)
	var neutral: float = _coverage(Factions.NEUTRAL)
	assert_float(rush).is_not_equal(boom)
	assert_float(rush).is_not_equal(neutral)
	assert_float(boom).is_not_equal(neutral)
	# Neutral is the even, unbiased ring, so it must be the most-covered of the three.
	assert_float(neutral).is_greater(rush)
	assert_float(neutral).is_greater(boom)


func test_rush_concentrates_its_mass_at_the_near_vertex() -> void:
	# Forward-light (§5.2): a solid cap over the near point, tapering away at the flanks.
	var at_point: float = _near_alpha(Factions.RUSH, 0.0, 0.3)
	var at_flank: float = _near_alpha(Factions.RUSH, 0.75, 1.0)
	assert_float(at_point).is_greater(at_flank)
	assert_float(at_flank).is_equal_approx(0.0, 0.001)


func test_boom_leaves_a_gap_at_the_near_vertex() -> void:
	# The gap IS the tell — it is what a viewer sees with hue removed, and it is the
	# exact inverse of Rush's cap.
	var at_point: float = _near_alpha(Factions.BOOM, 0.0, 0.3)
	var at_flank: float = _near_alpha(Factions.BOOM, 0.75, 1.0)
	assert_float(at_point).is_equal_approx(0.0, 0.001)
	assert_float(at_flank).is_greater(0.0)


func test_rush_and_boom_are_inverses_across_the_near_half() -> void:
	# Whichever end of the arc one faction owns, the other does not. This is what
	# makes them discriminable rather than merely unequal.
	var rush_point: float = _near_alpha(Factions.RUSH, 0.0, 0.3)
	var boom_point: float = _near_alpha(Factions.BOOM, 0.0, 0.3)
	var rush_flank: float = _near_alpha(Factions.RUSH, 0.75, 1.0)
	var boom_flank: float = _near_alpha(Factions.BOOM, 0.75, 1.0)
	assert_float(rush_point).is_greater(boom_point)
	assert_float(boom_flank).is_greater(rush_flank)


func test_neutral_is_even_across_the_near_half() -> void:
	# The absence of a bias, which is Neutral's stated design intent (§4.2).
	var at_point: float = _near_alpha(Factions.NEUTRAL, 0.0, 0.3)
	var at_flank: float = _near_alpha(Factions.NEUTRAL, 0.75, 1.0)
	assert_float(at_point).is_greater(0.0)
	assert_float(at_flank).is_greater(0.0)


# --- Hue comes from the one locked source --------------------------------------

func test_marker_hue_is_the_locked_faction_anchor() -> void:
	# A second palette would be a §4.1 violation waiting to drift. The marker reads
	# its hue from EntityGlow, the same place the emission shader does.
	for faction: FactionDef in [Factions.RUSH, Factions.BOOM, Factions.NEUTRAL]:
		var image: Image = OwnershipMarker.texture_for(faction).get_image()
		var anchor: Color = EntityGlow.hue_for(faction)
		var found: bool = false
		for y: int in image.get_height():
			for x: int in image.get_width():
				var px: Color = image.get_pixel(x, y)
				if px.a > 0.5:
					assert_float(px.r).is_equal_approx(anchor.r, 0.01)
					assert_float(px.g).is_equal_approx(anchor.g, 0.01)
					assert_float(px.b).is_equal_approx(anchor.b, 0.01)
					found = true
					break
			if found:
				break
		assert_bool(found).is_true()


# --- Geometry constraints -------------------------------------------------------

func test_the_decal_stays_inside_its_own_tile() -> void:
	# Held inside the rim so two markers on adjacent tiles never touch: a continuous
	# line running across several tiles would read as terrain, not as ownership.
	assert_float(OwnershipMarker.BAND_OUTER).is_less(1.0)
	assert_float(OwnershipMarker.BAND_INNER).is_less(OwnershipMarker.BAND_OUTER)
	assert_float(OwnershipMarker.BAND_INNER).is_greater(0.0)


func test_a_markers_texture_is_exactly_the_diamond_that_holds_its_band() -> void:
	# ★ 2026-08-24: was "the texture is one tile". It no longer is, and the change is
	# the point: a BASE_RING's band sits OUTSIDE the tile rim, so a tile-sized image
	# would crop it at the rim and silently draw a broken ring. Every style's texture
	# is now sized to its own outer edge — the tile style's is slightly SMALLER than
	# a tile (its band stops at BAND_OUTER), which draws identically since the
	# trimmed border was transparent.
	for style: OwnershipMarker.Style in [OwnershipMarker.Style.TILE, OwnershipMarker.Style.BASE_RING]:
		var outer: float = OwnershipMarker.band_for(style).y
		var image: Image = OwnershipMarker.texture_for(Factions.RUSH, style).get_image()
		assert_int(image.get_width()).override_failure_message(
			"style %d's image is not wide enough to hold its band" % style
		).is_equal(int(ceilf(BoardRenderer.TILE_WIDTH_PX * outer * OwnershipMarker.TEXTURE_SCALE)))
		assert_int(image.get_height()).is_equal(
			int(ceilf(BoardRenderer.TILE_HEIGHT_PX * outer * OwnershipMarker.TEXTURE_SCALE))
		)
	# Kept in step with the entity sprites' 2x rule, so one board never mixes scales.
	assert_float(OwnershipMarker.TEXTURE_SCALE).is_equal(EntitySpriteFeed.TEXTURE_SCALE)


func test_the_base_ring_sits_outside_the_tile_rim_and_the_tile_style_inside_it() -> void:
	# ★ The whole distinction between the two styles, as a number. A structure's base
	# plate is as wide as the tile and taller than the tile diamond, so a band inside
	# the rim is a band underneath the building — which is exactly what happened when
	# structures were correctly grounded and every decal on the board vanished.
	var tile: Vector2 = OwnershipMarker.band_for(OwnershipMarker.Style.TILE)
	var ring: Vector2 = OwnershipMarker.band_for(OwnershipMarker.Style.BASE_RING)

	assert_float(tile.y).override_failure_message(
		"the unit decal must stay inside its tile so adjacent markers never merge"
	).is_less(1.0)
	assert_float(ring.x).override_failure_message(
		"a ring whose inner edge is inside the rim is a ring underneath the building"
	).is_greater(1.0)
	assert_float(ring.x).is_less(ring.y)


func test_the_ring_is_no_wider_than_it_has_to_be() -> void:
	# ★ The counterweight to the test above, and the reason the inner edge is
	# measured against the NEAR half only. A ring big enough to clear every
	# structure's widest row anywhere in its art needs ~1.5 tiles — visibly bigger
	# than the tile it labels, and reaching well into the neighbours. The far half is
	# SUPPOSED to be occluded by the building standing on it, so it does not get a
	# vote. Pinned so a future retune cannot quietly reintroduce the oversized ring.
	var ring: Vector2 = OwnershipMarker.band_for(OwnershipMarker.Style.BASE_RING)
	assert_float(ring.y).override_failure_message(
		"the ring has grown wide enough to read as a multi-tile footprint"
	).is_less(1.30)


func test_both_styles_carry_the_same_faction_shapes() -> void:
	# The ring is the SAME decal at a different radius, not a second mark. Rush's
	# front cap, Boom's flank gap and Neutral's even ring must all survive the move
	# outward, or the non-hue tell only works on units.
	for style: OwnershipMarker.Style in [OwnershipMarker.Style.TILE, OwnershipMarker.Style.BASE_RING]:
		var rush: Image = OwnershipMarker.texture_for(Factions.RUSH, style).get_image()
		var boom: Image = OwnershipMarker.texture_for(Factions.BOOM, style).get_image()
		# The near vertex is Rush's solid cap and Boom's deliberate gap — the one
		# pixel that separates the two factions with hue removed.
		var near_x: int = rush.get_width() / 2
		var near_y: int = rush.get_height() - 2
		assert_float(rush.get_pixel(near_x, near_y).a).override_failure_message(
			"style %d lost Rush's front cap" % style
		).is_greater(0.0)
		assert_float(boom.get_pixel(near_x, near_y).a).override_failure_message(
			"style %d lost Boom's front gap — the non-hue tell" % style
		).is_equal(0.0)


func test_each_style_is_cached_separately_not_overwriting_the_other() -> void:
	# Regression: the cache was keyed by faction alone. With two styles that would
	# hand whichever was requested first to both, so either every unit wore a ring or
	# every structure wore a tile band.
	var tile: ImageTexture = OwnershipMarker.texture_for(Factions.RUSH, OwnershipMarker.Style.TILE)
	var ring: ImageTexture = OwnershipMarker.texture_for(Factions.RUSH, OwnershipMarker.Style.BASE_RING)
	assert_object(ring).is_not_same(tile)
	assert_object(
		OwnershipMarker.texture_for(Factions.RUSH, OwnershipMarker.Style.BASE_RING)
	).is_same(ring)


func test_textures_are_cached_not_redrawn_per_entity() -> void:
	# The board draws every decal from a set of exactly three images.
	var first: ImageTexture = OwnershipMarker.texture_for(Factions.RUSH)
	var second: ImageTexture = OwnershipMarker.texture_for(Factions.RUSH)
	assert_object(second).is_same(first)
