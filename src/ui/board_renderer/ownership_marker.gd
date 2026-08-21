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

## Marker textures are drawn at twice their on-screen size and scaled down, exactly
## as the entity art is (art-bible §8.3). Kept in step with
## [constant EntitySpriteFeed.TEXTURE_SCALE] so one board never mixes two scales.
const TEXTURE_SCALE: float = 2.0

## The drawn texture's size in pixels — one tile diamond at [constant TEXTURE_SCALE].
const TEXTURE_SIZE: Vector2i = Vector2i(
	int(BoardRenderer.TILE_WIDTH_PX * TEXTURE_SCALE),
	int(BoardRenderer.TILE_HEIGHT_PX * TEXTURE_SCALE)
)

## Outer edge of the band, as a fraction of the way from the tile centre to its rim.
## Held below 1.0 so two markers on adjacent tiles never touch — a continuous line
## across several tiles would read as terrain, not as ownership.
const BAND_OUTER: float = 0.92

## Inner edge of the band. The gap to [constant BAND_OUTER] is the band's thickness;
## at the shipping camera this lands around 4 on-screen pixels, which is thick enough
## to hold its shape and thin enough to stay under §4.6's neon budget.
const BAND_INNER: float = 0.74

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
static func texture_for(faction: FactionDef) -> ImageTexture:
	var token: String = EntitySpriteCatalog.faction_token(faction)
	if _cache.has(token):
		return _cache[token]
	var texture: ImageTexture = _build(token, EntityGlow.hue_for(faction))
	_cache[token] = texture
	return texture


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
static func _build(token: String, hue: Color) -> ImageTexture:
	var size: Vector2i = TEXTURE_SIZE
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half_w: float = size.x * 0.5
	var half_h: float = size.y * 0.5
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for y: int in size.y:
		for x: int in size.x:
			var dx: float = x + 0.5 - half_w
			var dy: float = y + 0.5 - half_h
			var d: float = absf(dx) / half_w + absf(dy) / half_h
			if d < BAND_INNER or d > BAND_OUTER:
				image.set_pixel(x, y, clear)
				continue
			# `span` is 0 at the near vertex and 1 at a side vertex — the
			# parameter the three faction shapes are cut from.
			var span: float = absf(dx) / half_w
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
