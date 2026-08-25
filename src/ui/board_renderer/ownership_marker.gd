## OwnershipMarker — the per-faction ground decal that carries ownership by SHAPE
## as well as hue, Presentation layer (Story 009 / sprint task S5-08 option D3).
##
## [b]The single source of truth for the marker's geometry and numbers[/b], the way
## [EntityGlow] is for the glow and [EntityTransforms] is for the motion. Textures
## are drawn procedurally here — there is no marker art, and there should not be:
## the shapes are three flat geometric primitives that a generator would only make
## less exact.
##
## [b]Why this exists.[/b] The S5-08 measurement pass found faction ownership on the
## shipped art carried by hue ALONE — all 26 Rush/Boom sprite pairs are
## pixel-identical in silhouette, so art-bible §5.2's Mass Distribution Bias, the
## "mandatory non-hue backup" §1 P2 requires, was never built. Two consequences the
## brief measured: structures declare their owner very weakly (the Defensive
## Structure sits at ΔE 2.3 across its whole silhouette [i]with normal colour
## vision[/i] — a Rush and a Boom one look near-identical to everyone), and nothing
## on the board survives full desaturation at all.
##
## Putting the marker on the TILE rather than in the sprite fixes both at once and
## costs no art regeneration: the decal is the same size for every entity, so a
## structure that carries faction colour on 5% of its body still gets a full-strength
## ownership tell, and because the three factions differ in SHAPE the signal survives
## with no colour information whatsoever.
##
## [b]Deviation from §5.2, recorded.[/b] §5.2 frames the bias as forward-light
## (Rush) vs rear-loaded (Boom) vs neutral-even (Neutral). A ground decal cannot use
## the rear of the tile: the entity stands at the tile's centre and its body occludes
## the whole upper (far) half. The bias is therefore expressed within the visible
## near half — front-concentrated vs flank-split vs even — which keeps the
## asymmetry-of-mass principle while staying visible. The silhouette test that
## matters is unchanged: the three read apart with hue removed.
##
## Usage:
## [codeblock]
## var tex := OwnershipMarker.texture_for(Factions.RUSH)
## sprite.texture = tex
## sprite.scale = Vector2.ONE / OwnershipMarker.TEXTURE_SCALE
## [/codeblock]
class_name OwnershipMarker
extends RefCounted

## Which decal a wearer gets. Both carry the same faction shapes and the same
## meaning; they differ only in how far out the band sits.
##
## [b]Why two.[/b] [constant Style.TILE] tucks the band inside the tile rim, which
## works for a unit — a unit's body is narrow and the band shows all around it. A
## STRUCTURE's base plate is drawn as wide as the tile and TALLER than the tile
## diamond, so it covers that band completely: after structures were correctly
## grounded on their own tile (2026-08-24), the decal vanished under every building
## on the board and the non-hue ownership tell went with it.
## [constant Style.BASE_RING] moves the band outside that base plate, so it reads as
## a ring around the building's feet.
enum Style {
	TILE,      ## Band inside the tile rim. Units.
	BASE_RING, ## Band outside the structure's base plate. Structures.
}

## Marker textures are drawn at twice their on-screen size and scaled down, exactly
## as the entity art is (art-bible §8.3). Kept in step with
## [constant EntitySpriteFeed.TEXTURE_SCALE] so one board never mixes two scales.
const TEXTURE_SCALE: float = 2.0

## Outer edge of the band, as a fraction of the way from the tile centre to its rim.
## Held below 1.0 so two markers on adjacent tiles never touch — a continuous line
## across several tiles would read as terrain, not as ownership.
const BAND_OUTER: float = 0.92

## Inner edge of the band. The gap to [constant BAND_OUTER] is the band's thickness;
## at the shipping camera this lands around 4 on-screen pixels, which is thick enough
## to hold its shape and thin enough to stay under §4.6's neon budget.
const BAND_INNER: float = 0.74

## [constant Style.BASE_RING]'s inner edge, in the same tile-diamond metric — so
## values above 1.0 sit OUTSIDE the tile rim.
##
## [b]Measured against the NEAR half only, which is the whole trick.[/b] A first cut
## used each structure's widest row anywhere in its art and landed at 1.24, which
## drew a ring nearly 1.5 tiles across — visibly bigger than the tile it was
## labelling. But the widest row of a building like the HQ sits ~9px ABOVE the tile
## centre, in the FAR half, which the building is supposed to occlude: a ring hidden
## behind the thing it belongs to is correct depth, not a defect. Sizing to the near
## half instead — the half a player actually looks at — the shipped roster needs:
## Barracks 1.00, Defensive Structure 1.00, HQ 1.04, Economy Outpost/Factory 1.12,
## Research Lab 1.44 (the outlier, a tall narrow tower on a wide flared foot).
##
## 1.08 clears every shipping structure's near half except the Research Lab's
## widest flare, which it passes behind. Chasing that one outlier would cost every
## other building on the board a ring half a tile too wide.
const BASE_RING_INNER: float = 1.08

## [constant Style.BASE_RING]'s outer edge. Keeps the band close to the thickness
## the tile style uses, so the two decals read as one visual language at different
## sizes rather than as two different marks.
const BASE_RING_OUTER: float = 1.24

## How far around the near half the mass extends, measured from the near vertex
## (0.0) out to the side vertices (1.0).
##
## Rush is [b]front-concentrated[/b]: a solid arc capping the near vertex.
const RUSH_SPAN: float = 0.55

## Boom is [b]flank-split[/b]: two arcs on the side edges with a clear gap at the
## near vertex. The gap is the tell — it is what a viewer sees with hue removed.
const BOOM_GAP: float = 0.45

## Peak opacity of the band. Ownership must read without competing with the actors
## for attention (§3.5 hierarchy) — the marker is a label on the floor, not a light.
const MARKER_ALPHA: float = 0.85

## Opacity multiplier applied to the far (occluded) half, which is drawn only as a
## faint closing arc so the decal reads as a ring rather than a broken fragment when
## a small unit does not fully cover it.
const FAR_HALF_ALPHA: float = 0.25

## Width in band-fractions of the soft edge at each end of an arc. A hard-cut arc
## end aliases badly at this size; a short ramp reads as an intentional taper.
const FEATHER: float = 0.12

## Cache of built textures, keyed by faction token. The board draws one marker per
## entity from a set of exactly three images, so they are built once and shared.
static var _cache: Dictionary = {}


## The marker texture for [param faction] — Rush's front cap, Boom's flank split, or
## Neutral's even ring. Built on first request and cached thereafter.
static func texture_for(faction: FactionDef, style: Style = Style.TILE) -> ImageTexture:
	var key: String = "%s:%d" % [EntitySpriteCatalog.faction_token(faction), style]
	if _cache.has(key):
		return _cache[key]
	var texture: ImageTexture = _build(
		EntitySpriteCatalog.faction_token(faction), EntityGlow.hue_for(faction), style
	)
	_cache[key] = texture
	return texture


## The band's [inner, outer] edges for [param style], in the tile-diamond metric
## (0 at the tile centre, 1.0 on its rim — so a BASE_RING's values exceed 1.0).
static func band_for(style: Style) -> Vector2:
	if style == Style.BASE_RING:
		return Vector2(BASE_RING_INNER, BASE_RING_OUTER)
	return Vector2(BAND_INNER, BAND_OUTER)


## The pixel size of [param style]'s texture — exactly the diamond that contains its
## band, at [constant TEXTURE_SCALE]. Sized to the BAND rather than to the tile, so a
## ring that reaches past the rim gets an image big enough to hold it instead of
## being silently cropped at the tile edge.
static func texture_size_for(style: Style) -> Vector2i:
	var outer: float = band_for(style).y
	return Vector2i(
		int(ceilf(BoardRenderer.TILE_WIDTH_PX * outer * TEXTURE_SCALE)),
		int(ceilf(BoardRenderer.TILE_HEIGHT_PX * outer * TEXTURE_SCALE))
	)


## Drops the texture cache. For tests that need a clean build; never needed at
## runtime, since the three markers are immutable once drawn.
static func clear_cache() -> void:
	_cache.clear()


## Draws one marker: a band around the tile diamond, masked to the arc span this
## faction owns.
##
## Geometry is the same point-in-diamond metric [method BoardRenderer._build_diamond_texture]
## uses — [code]d = |dx|/half_w + |dy|/half_h[/code], which is 0 at the tile centre and
## 1.0 on its rim — so the marker is guaranteed to sit on the tile the renderer
## thinks it does, rather than on a second, independently-derived diamond.
static func _build(token: String, hue: Color, style: Style) -> ImageTexture:
	var size: Vector2i = texture_size_for(style)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	# ★ The metric stays anchored to the TILE's half-extents even when the image is
	# bigger than a tile. Measuring `d` against the image instead would make every
	# style a differently-proportioned diamond, and the faction shapes are cut from
	# `d` — they would stop matching each other.
	var tile_half := Vector2(BoardRenderer.TILE_WIDTH_PX * 0.5, BoardRenderer.TILE_HEIGHT_PX * 0.5)
	var image_half := Vector2(size.x, size.y) * 0.5
	var band: Vector2 = band_for(style)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for y: int in size.y:
		for x: int in size.x:
			# Image pixels -> tile pixels from the image centre (which IS the tile
			# centre: the marker sprite is centred on grid_to_screen).
			var dx: float = (x + 0.5 - image_half.x) / TEXTURE_SCALE
			var dy: float = (y + 0.5 - image_half.y) / TEXTURE_SCALE
			var d: float = absf(dx) / tile_half.x + absf(dy) / tile_half.y
			if d < band.x or d > band.y:
				image.set_pixel(x, y, clear)
				continue
			# `span` is 0 at the near vertex and 1 at a side vertex — the
			# parameter the three faction shapes are cut from. Normalised by the
			# band's own outer edge so a BASE_RING's shapes span the same
			# proportion of their ring that a TILE marker's span of theirs.
			var span: float = absf(dx) / (tile_half.x * band.y)
			var near: bool = dy >= 0.0   # screen y grows toward the camera.
			var strength: float = _strength(token, span, near)
			if strength <= 0.0:
				image.set_pixel(x, y, clear)
				continue
			image.set_pixel(x, y, Color(hue.r, hue.g, hue.b, MARKER_ALPHA * strength))
	return ImageTexture.create_from_image(image)


## How strongly [param token]'s shape claims the point at [param span] along the
## near ([param near] true) or far half. 0 leaves the pixel empty.
##
## The far half is always the faint closing arc ([constant FAR_HALF_ALPHA]) whatever
## the faction, because it is mostly hidden behind the entity — putting shape
## information there would hide the very thing that has to survive desaturation.
static func _strength(token: String, span: float, near: bool) -> float:
	if not near:
		return FAR_HALF_ALPHA
	match token:
		"rush":
			# Solid cap over the near vertex, tapering out at RUSH_SPAN.
			return _ramp(RUSH_SPAN - span)
		"boom":
			# Two flank arcs; the gap over the near vertex is the non-hue tell.
			return _ramp(span - BOOM_GAP)
		_:
			# Neutral is even the whole way round — the absence of a bias, which is
			# exactly its design intent (§4.2: the value-neutral default).
			return 1.0


## Feathered step: 0 below the edge, 1 above it, ramping over [constant FEATHER].
static func _ramp(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	if distance >= FEATHER:
		return 1.0
	return distance / FEATHER
