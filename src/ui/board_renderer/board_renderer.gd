## BoardRenderer — the isometric grid<->screen projection, Presentation layer.
##
## Owns the one shared, hand-rolled, closed-form 2:1 dimetric transform pair
## (ADR-0013 §1) that every board-space consumer (Command & Action Interface,
## Game HUD) reads through — [method grid_to_screen]/[method screen_to_grid]
## are never re-derived elsewhere. Extends [Node2D] (not a headless utility)
## because later stories attach [code]TileMapLayer[/code]/[code]Node2D[/code]
## children under it (Story 002/003); this story adds only the transform pair
## and its consts/export.
##
## Story 001 scope: the transform pair only. Never call engine
## [code]TileMapLayer.local_to_map()[/code]/[code]map_to_local()[/code] for
## this math — confirmed inaccurate for isometric tile shapes
## ([url=https://github.com/godotengine/godot/issues/89423]GH#89423[/url]);
## this closed-form pair sidesteps that bug entirely rather than working
## around it (ADR-0013 §1).
##
## [b]Sprite placement anchor convention:[/b] [method grid_to_screen] is also
## the sprite-placement anchor — [code]sprite.position = grid_to_screen(tile)[/code]
## places a unit/structure/prop sprite correctly with no extra offset, because
## every such sprite is authored with its pivot at its ground-contact point
## (art bible §8.4). Story 002 depends on this exact contract; do not change
## [method grid_to_screen]'s return convention without updating that story.
##
## [b]Out of scope for Story 001[/b] (see neighbouring Board Renderer
## stories, since landed): [code]TileMapLayer[/code] nodes/scene-tree
## structure (002/003), [method pick_at] (004 — now implemented; see its own
## doc comment), glyph offsets (005 — now implemented; see [method glyph_anchor]'s
## own doc comment), any [code]GridState[/code] reads.
##
## Usage:
## [codeblock]
## var renderer := BoardRenderer.new()
## var screen_pos := renderer.grid_to_screen(Vector2i(3, 4))
## var tile := renderer.screen_to_grid(screen_pos)
## assert(tile == Vector2i(3, 4))  # exact round-trip, ADR-0013 §1
## [/codeblock]
class_name BoardRenderer
extends Node2D

## [b]Scene tree (ADR-0013 §2, Story 002):[/b] built programmatically in
## [method _ready] rather than authored as a [code].tscn[/code] file — this
## class has always been instantiated directly
## ([code]BoardRenderer.new()[/code], per Story 001's own tests), and no
## child here needs editor-authored content yet (no imported art, no placed
## instances), so a scene file would only fix property values that are just
## as clearly asserted in code:
## [codeblock]
## BoardRenderer (Node2D)
##  |-- FloorTileMapLayer   (TileSet.TILE_SHAPE_ISOMETRIC; z_index 0)
##  |-- OverlayTileMapLayer (TileSet.TILE_SHAPE_ISOMETRIC; z_index 1)
##  `-- OccupantLayer       (Node2D, y_sort_enabled = true; z_index 2)
##       |-- CoverProp_<x>_<y> (Sprite2D, this class; see paint_terrain)
##       `-- Entity<id>        (Sprite2D, owned by EntitySpriteFeed)
## [/codeblock]
## [code]z_index[/code] is the coarse cross-tree band (Floor 0 -> Overlay 1
## -> Occupant 2); [member Node2D.y_sort_enabled] on [code]OccupantLayer[/code]
## re-sorts only children within that layer — the two mechanisms are never
## conflated (ADR-0013 §2, Control Manifest). Children added under
## [code]OccupantLayer[/code] must never set their own conflicting
## [code]z_index[/code] — that would fight the Y-sort.
##
## [b]Occupant-layer ownership is SPLIT (Story 006).[/b] This class owns the
## static board — the floor cells and the Cover props ([method paint_terrain]) —
## while [EntitySpriteFeed] owns one [Sprite2D] per live entity in the same layer.
## They coexist safely because each only ever touches its own nodes: cover props
## are identified by [constant COVER_PROP_NAME_PREFIX], entity sprites by the
## feed's own id map. Story 002's placeholder fixtures that used to live here are
## gone — the live [method GameState.entities] feed replaced them.

## Tile width in pixels for the 2:1 dimetric projection. Placeholder value
## satisfying the 2:1 ratio (ADR-0013 §1) — the exact pixel value is
## technical-art's eventual call, not locked by this story.
const TILE_WIDTH_PX: float = 128.0

## Tile height in pixels for the 2:1 dimetric projection. Placeholder value —
## see [constant TILE_WIDTH_PX].
const TILE_HEIGHT_PX: float = 64.0

## Factor by which shipped art exceeds its on-screen size (art-bible §8.3,
## assets/art/README.md): one asset serves both 1080p and 1440p, and the §2 glow
## keeps its falloff. Every texture in [code]assets/art/[/code] is authored at this
## multiple of the size it is drawn at — the floor/overlay layers absorb it with a
## layer [member Node2D.scale], individual sprites with their own
## ([constant EntitySpriteFeed.TEXTURE_SCALE], which must stay in step with this).
##
## [b]This is NOT a change to the on-screen cell.[/b]
## [constant TILE_WIDTH_PX]/[constant TILE_HEIGHT_PX] remain 128x64 on screen and
## the transform pair is untouched — only the source texture is bigger (Story 006
## AC-7/AC-8).
const TEXTURE_SCALE: float = 2.0

## The [member TileSet.tile_size] both tile layers use: the on-screen cell scaled
## up by [constant TEXTURE_SCALE], because the floor texture ships at 2x. Paired
## with [constant TILE_LAYER_SCALE] on the layer node, the effective on-screen cell
## is exactly [constant TILE_WIDTH_PX] x [constant TILE_HEIGHT_PX] again.
const TILE_TEXTURE_SIZE: Vector2i = Vector2i(
	int(TILE_WIDTH_PX * TEXTURE_SCALE), int(TILE_HEIGHT_PX * TEXTURE_SCALE)
)

## The [member Node2D.scale] applied to both tile layers to bring
## [constant TILE_TEXTURE_SIZE] back down to the on-screen cell.
##
## [b]Why this leaves [method grid_to_screen] alone (AC-8):[/b] the engine places
## cell [code](x,y)[/code] at [code]((x-y) * tile_size.x/2, (x+y) * tile_size.y/2)[/code]
## in LAYER-local space; multiplying by 0.5 with a doubled tile_size lands on
## [code]((x-y) * TILE_WIDTH_PX/2, (x+y) * TILE_HEIGHT_PX/2)[/code] — which is
## [method _project] exactly. The two doublings cancel, so occupant sprites (drawn
## in unscaled BoardRenderer space at [method grid_to_screen]) stay registered with
## the floor cells.
const TILE_LAYER_SCALE: float = 1.0 / TEXTURE_SCALE

## [member TileSet] source id for the one floor atlas source
## ([method _build_floor_tile_source]). Distinct from the overlay's ids, which are
## [enum OverlayClass] values on the OVERLAY layer's own TileSet — the two TileSets
## are separate objects, so the id spaces never collide.
const FLOOR_SOURCE_ID: int = 0

## The plain-floor texture, reused as the floor cell under Cover tiles too
## (assets/art/README.md §8.8: cover's floor IS the plain floor; there is no
## separate cover floor art).
const FLOOR_TEXTURE_PATH: String = "res://assets/art/terrain/tile_plain_clean.png"

## The cover-mass prop texture — a Y-sorted occupant, NOT a tile cell. See
## [method _add_cover_prop].
const COVER_PROP_TEXTURE_PATH: String = "res://assets/art/terrain/tile_cover_clean.png"

## Node-name prefix marking a cover prop under [member occupant_layer], so
## [method _clear_cover_props] can repaint terrain without disturbing the entity
## sprites [EntitySpriteFeed] owns in the same layer.
const COVER_PROP_NAME_PREFIX: String = "CoverProp_"

## Coarse cross-tree z-index band for [member floor_layer] (ADR-0013 §2).
## Sits outside the Y-sort group — never compared against occupant Y.
const FLOOR_Z_INDEX: int = 0

## Coarse cross-tree z-index band for [member overlay_layer] (ADR-0013 §2).
const OVERLAY_Z_INDEX: int = 1

## Coarse cross-tree z-index band for [member marker_layer] (ADR-0013 §2,
## amended 2026-08-20 for Story 009 / S5-08).
##
## [b]Above the overlay, below the occupants.[/b] Above, because ownership must stay
## legible through a range or target highlight — an overlay tint washing the marker
## out would break it in exactly the moment a player is deciding what to attack.
## Below, because it is a decal on the floor and an actor standing on the tile must
## occlude it.
const MARKER_Z_INDEX: int = 2

## Coarse cross-tree z-index band for [member occupant_layer] (ADR-0013 §2).
## Depth-sort within this band is native [member Node2D.y_sort_enabled],
## never this constant nor any custom depth math.
##
## [b]Was 2 until 2026-08-20[/b], when [constant MARKER_Z_INDEX] took that band
## (ADR-0013 amendment). The ordering floor -> overlay -> markers -> occupants is
## what the numbers mean; the absolute values carry no other meaning.
const OCCUPANT_Z_INDEX: int = 3

## The 9-class overlay taxonomy (ADR-0013 §3; taxonomy source:
## [code]command-action-interface.md[/code] Visual/Audio §B). Each value
## doubles as [member overlay_layer]'s [TileMapLayer] atlas [code]source_id[/code]
## for that class (see [method _build_overlay_tile_source]) — passed to
## [method set_overlay] as a plain [code]int[/code] per the story's exact
## signature, with these names as the sanctioned way to spell that int.
## Placeholder art only (flat-tinted solid diamonds, [constant OVERLAY_TINTS]);
## the real hatch/pattern/glyph treatment §B specifies is technical-art's
## later pass, not this story's scope.
enum OverlayClass {
	MOVE_IN_CAP, ## §B.1 — in-cap (base-cost) move fill.
	MOVE_OVER_CAP, ## §B.1 — over-cap (surcharged) move hatch.
	ATTACK_TARGET, ## §B.3 — valid attack target-lock ring.
	BLOCKED_BY_FRIENDLY, ## §B.2/§B.3 — blocked-by-friendly stop-glyph.
	OUT_OF_RANGE, ## §B.3 — out-of-range fade-to-nothing.
	AREA_DEAD_ZONE, ## §B.3 — AREA targeting dead-zone.
	BUILD_DEPLOY_GO_TILE, ## §B.4/§B.5 — legal build tile + deploy tile
	## ("go-tile" — shared bright cool-white language).
	CANCEL_REFUND, ## §B — Cancel Build's distinct-gesture refund affordance tile.
	AFTER_MOVE_ECHO, ## §B.7 — D-3 after-move attack marker (shrunk/dimmed
	## target-lock echo).
}

## Flat placeholder tint per [enum OverlayClass], used to bake each class's
## atlas entry (see [method _build_overlay_tile_source]). One distinct color
## per class is sufficient for this story's mechanism proof — real
## hatch/pattern/outline/glyph authoring per command-action-interface.md §B
## is technical-art's later pass, not re-derived here.
const OVERLAY_TINTS: Dictionary = {
	OverlayClass.MOVE_IN_CAP: Color(0.75, 0.9, 1.0, 0.85),
	OverlayClass.MOVE_OVER_CAP: Color(0.85, 0.65, 0.35, 0.85),
	OverlayClass.ATTACK_TARGET: Color(1.0, 0.25, 0.25, 0.9),
	OverlayClass.BLOCKED_BY_FRIENDLY: Color(0.4, 0.4, 0.4, 0.85),
	OverlayClass.OUT_OF_RANGE: Color(0.3, 0.3, 0.35, 0.4),
	OverlayClass.AREA_DEAD_ZONE: Color(0.5, 0.2, 0.5, 0.6),
	OverlayClass.BUILD_DEPLOY_GO_TILE: Color(0.75, 0.9, 1.0, 0.85),
	OverlayClass.CANCEL_REFUND: Color(0.9, 0.3, 0.2, 0.75),
	OverlayClass.AFTER_MOVE_ECHO: Color(1.0, 0.25, 0.25, 0.4),
}

## The 12 on-board glyph classes (ADR-0013 §5, Story 005; taxonomy source:
## AC-4 / game-hud.md TR-hud-010/011 + command-action-interface.md
## TR-cmdui-017's D-3 echo). Each value doubles as the [code]glyph_class[/code]
## [code]int[/code] passed to [method glyph_anchor] and to
## [method GlyphOffsets.offset_for] — these names are the sanctioned way to
## spell that int (never a bare numeric literal at a call site). Lives here
## (not on [GlyphOffsets]) so HUD/CAI consumers, which already hold a
## [BoardRenderer] reference and call [code]board_renderer.glyph_anchor(...)[/code]
## the same way they call [method set_overlay] with [enum OverlayClass], get
## one consistent import surface for both on-board enums.
enum GlyphClass {
	HP_PIP, ## Unit hp pips — first claim on non-overlapping screen space
	## (hp-pip-never-occluded, game-hud.md CR-5/TR-hud-011); see
	## [GlyphOffsets]'s class doc comment for the authoring-discipline note.
	HAS_ACTED, ## Has-acted marker.
	TECH_MARKER, ## Tech (Attack/Defense) marker.
	STRUCTURE_HP, ## Structure hp glyph (distinct from unit [constant HP_PIP]).
	BUILD_TIMER_BADGE, ## Build-timer badge.
	RESEARCH_MARKER, ## Research-in-progress marker.
	AP_COST_BADGE, ## AP-cost badge (preview/hover).
	DAMAGE_NUMBER, ## Floating damage number.
	COVER_GLYPH, ## Cover-tile glyph.
	TURNS_NUMERAL, ## Turns-remaining numeral.
	TARGET_BRACKET, ## Target-lock bracket.
	D3_ECHO, ## D-3 after-move attack echo (TR-cmdui-017,
	## command-action-interface.md §B.7) — shares this exact anchor mechanism
	## with the six Game HUD glyph classes above.
}

## Default on-disk location of the [GlyphOffsets] data resource (ADR-0013
## §5) — art/UX-authored external data, never hardcoded literals in this
## file. Loaded lazily by [method glyph_anchor] on first use, not in
## [method _ready], so [method glyph_anchor] works the same way
## [method pick_at] already does: on a bare [code]BoardRenderer.new()[/code]
## instance with no [code]add_child()[/code]/[code]_ready()[/code] required
## (Story 004 precedent, [member occupant_pick_regions]).
const DEFAULT_GLYPH_OFFSETS_PATH: String = "res://data/ui/glyph_offsets.tres"


## Result of [method pick_at] (ADR-0013 §4, Story 004) — occupant-priority
## click resolution. [member tile] is always populated (either the hit
## occupant's own tracked tile, or the plain diamond under the click via
## [method screen_to_grid]); [member occupant_entity_id] is [code]-1[/code]
## when no occupant region was hit, matching the grid's own
## [code]-1[/code]-for-empty convention. Shape is exact per ADR-0013 §4 —
## do not add fields without updating that ADR.
class PickResult extends RefCounted:
	var tile: Vector2i
	var occupant_entity_id: int # -1 if none.


## One entry of the [member occupant_pick_regions] injectable seam (Story
## 004) — see that member's doc comment for the full ownership-gap context.
## [member rect] is an authored per-occupant clickable region in screen
## space (never derived from [method grid_to_screen] alone — see
## [method pick_at]); [member tile]/[member entity_id] are that occupant's
## own state-tracked identity, returned as-is by [method pick_at] rather
## than re-derived geometrically from the click.
class OccupantPickRegion extends RefCounted:
	var rect: Rect2
	var entity_id: int
	var tile: Vector2i


## Board-layout placement offset applied uniformly to every projected screen
## position. Designer/technical-art/UX-tunable; defaults to no offset.
@export var origin_offset_px: Vector2 = Vector2.ZERO

## Static terrain art layer (ADR-0013 §2). Iso-shaped [TileSet]; sits outside
## the Y-sort group. Built in [method _ready]; empty (no painted cells) is a
## valid, Story-002-complete state — floor art content is not this story's
## scope.
var floor_layer: TileMapLayer

## Reachable/target/build overlay layer (ADR-0013 §2/§3). Shares the floor's
## iso shape config; populated exclusively through [method set_overlay]/
## [method clear_overlay] (Story 003) — no other code may call
## [code]overlay_layer.set_cell[/code]/[code]overlay_layer.clear[/code]
## directly, so this class stays the single choke point for overlay writes.
var overlay_layer: TileMapLayer

## Y-sorted occupant group (ADR-0013 §2). [member Node2D.y_sort_enabled] is
## the sole depth-sort mechanism for children of this node — never a custom
## sort. See the class doc comment's scene-tree section for the
## z-index/y-sort division of labor this node anchors.
var occupant_layer: Node2D

## The [code]MarkerLayer[/code] holding one faction ownership decal per entity
## (Story 009 / S5-08), populated by [EntitySpriteFeed].
##
## [b]Deliberately NOT Y-sorted[/b], unlike [member occupant_layer]. Markers are
## flat on the floor at tile centres and one can never meaningfully occlude another;
## sorting them would only add cost and a second depth rule to keep in step. Their
## own band ([constant MARKER_Z_INDEX]) puts the whole layer under every occupant,
## which is the only depth relationship that matters here.
var marker_layer: Node2D

## [b]Injectable occupant-pick-region seam (ADR-0013 §4, Story 004).[/b]
## Ordered back-to-front matching [member occupant_layer]'s Y-sort paint
## order (i.e. the same order real occupant children would visually draw
## in); [method pick_at] tests it in [i]reverse[/i] so the front-most
## (closest-to-camera) region wins ties, per ADR-0013 §4 step 1. Defaults to
## empty, which makes [method pick_at] degrade to plain
## [method screen_to_grid] for every click — the correct, harmless default
## until real regions are wired in.
##
## [b]✅ Ownership gap CLOSED by Story 006[/b] (was ADR-0013
## Consequences/Risks, vertical-slice build-seam S3-05,
## `production/vertical-slice/scope.md` §8(b)): the real
## "derive [Rect2] from a sprite" convention now lives in
## [method EntitySpriteFeed.pick_regions], which authors this array from the
## actual drawn sprite bounds in Y-sort order. This member stays a settable
## seam — that is what keeps [method pick_at]'s priority logic unit-testable
## with injected [OccupantPickRegion] mocks — but it is no longer unwired:
## the vertical slice assigns [method EntitySpriteFeed.pick_regions] to it
## after every feed sync.
var occupant_pick_regions: Array[OccupantPickRegion] = []

## [b]Injectable glyph-offset data seam (ADR-0013 §5, Story 005).[/b] The
## art/UX-authored [code]GLYPH_OFFSETS[/code] table [method glyph_anchor]
## reads. Defaults to [code]null[/code] and is lazy-loaded from
## [constant DEFAULT_GLYPH_OFFSETS_PATH] by [method glyph_anchor] itself on
## first use — never in [method _ready] — so [method glyph_anchor] works on a
## bare [code]BoardRenderer.new()[/code] instance with no
## [code]add_child()[/code]/[code]_ready()[/code], matching
## [member occupant_pick_regions]'s injectable-seam precedent. Tests (and any
## future caller) may set this directly to a custom [GlyphOffsets] instance
## before the first [method glyph_anchor] call to override every offset with
## zero code change (AC-2) — once set (by injection or by the lazy load),
## [method glyph_anchor] never reloads it.
var glyph_offsets: GlyphOffsets = null


## Builds the Story 002 scene-tree skeleton (ADR-0013 §2) and populates
## [member occupant_layer] with placeholder fixtures. Runs on every
## instantiation, whether via [code]BoardRenderer.new()[/code] (as Story
## 001's tests already do) or future scene instancing — see the class doc
## comment for why this is programmatic rather than a [code].tscn[/code].
func _ready() -> void:
	floor_layer = _build_iso_tilemap_layer("FloorTileMapLayer", FLOOR_Z_INDEX)
	overlay_layer = _build_iso_tilemap_layer("OverlayTileMapLayer", OVERLAY_Z_INDEX)
	_build_overlay_tile_source()
	marker_layer = _build_marker_layer()
	occupant_layer = _build_occupant_layer()
	_build_floor_tile_source()


## Constructs one iso-shaped, empty [TileMapLayer] at [param z_index], added
## as a direct child of this node under [param node_name]. Both
## [member floor_layer] and [member overlay_layer] are built through this
## one shared helper so their [TileSet] configuration (dimensions +
## [constant TileSet.TILE_SHAPE_ISOMETRIC]) can never independently drift —
## ADR-0013 §3 requires the overlay layer share the floor's exact config.
## No cells are painted here; floor/overlay art content is out of this
## story's scope.
func _build_iso_tilemap_layer(node_name: String, z_index_value: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.z_index = z_index_value
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_size = TILE_TEXTURE_SIZE
	layer.tile_set = tile_set
	# Both layers take the 2x-art scale together. ADR-0013 §3 guarantees
	# floor/overlay alignment by the two sharing an IDENTICAL TileSet config, so
	# scaling only the floor would break that mechanism even though the two would
	# still happen to line up numerically (Story 006 AC-7).
	layer.scale = Vector2.ONE * TILE_LAYER_SCALE
	# Sprites bake [member origin_offset_px] into their position via
	# grid_to_screen(); tile cells cannot, so the layer node carries it instead.
	# Read once here — change origin_offset_px after _ready() and you must repaint.
	layer.position = origin_offset_px
	add_child(layer)
	return layer


## Adds one dedicated [TileSetAtlasSource] per [enum OverlayClass] to
## [member overlay_layer]'s [TileSet] (ADR-0013 §3). Each source is a single
## 1x1-cell atlas wrapping a runtime-baked flat-tinted diamond
## [ImageTexture] ([constant OVERLAY_TINTS]) sized to the shared
## [constant TILE_WIDTH_PX]/[constant TILE_HEIGHT_PX], and is registered
## under [code]source_id == int(class_id)[/code] — this is what lets
## [method set_overlay]/[method clear_overlay] and this story's tests
## identify a populated cell's class via
## [method TileMapLayer.get_cell_source_id] alone. Only adds sources to
## [member overlay_layer]'s own [TileSet] instance; never touches
## [member floor_layer]'s [TileSet] or its shared
## [member TileSet.tile_shape]/[member TileSet.tile_size] config (ADR-0013 §3
## — the floor/overlay alignment guarantee comes from
## [method _build_iso_tilemap_layer] configuring both identically, not from
## this method).
func _build_overlay_tile_source() -> void:
	# Baked at TILE_TEXTURE_SIZE, not the on-screen cell: the overlay layer carries
	# the same TILE_LAYER_SCALE as the floor, so a 1x diamond would draw at half a
	# cell. Matching the floor's 2x also keeps overlay edges as crisp as the art.
	var tile_size := TILE_TEXTURE_SIZE
	for class_id in OverlayClass.values():
		var source := TileSetAtlasSource.new()
		source.texture = _build_diamond_texture(tile_size, OVERLAY_TINTS[class_id])
		source.texture_region_size = tile_size
		source.create_tile(Vector2i.ZERO)
		overlay_layer.tile_set.add_source(source, class_id)


## Bakes a flat-tinted 2:1 iso diamond [ImageTexture] at [param tile_size],
## filled with [param tint] inside the diamond and transparent outside it —
## the placeholder atlas art for one [enum OverlayClass] entry (see
## [method _build_overlay_tile_source]). Deliberately the simplest possible
## per-class visual (solid tint, no hatch/pattern/glyph); real art is
## technical-art's later pass per command-action-interface.md §B.
func _build_diamond_texture(tile_size: Vector2i, tint: Color) -> ImageTexture:
	var image := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	var half_width := tile_size.x * 0.5
	var half_height := tile_size.y * 0.5
	for y in tile_size.y:
		for x in tile_size.x:
			# Point-in-diamond test: |dx|/half_width + |dy|/half_height <= 1.
			var dx := absf(x + 0.5 - half_width)
			var dy := absf(y + 0.5 - half_height)
			if dx / half_width + dy / half_height <= 1.0:
				image.set_pixel(x, y, tint)
			else:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


## Constructs the flat [code]MarkerLayer[/code] (ADR-0013 §2 as amended): a plain
## [Node2D] in the [constant MARKER_Z_INDEX] band, holding the per-entity ownership
## decals. See [member marker_layer] for why it is not Y-sorted.
func _build_marker_layer() -> Node2D:
	var layer := Node2D.new()
	layer.name = "MarkerLayer"
	layer.z_index = MARKER_Z_INDEX
	add_child(layer)
	return layer


## Constructs the Y-sorted [code]OccupantLayer[/code] (ADR-0013 §2): a plain
## [Node2D] with [member Node2D.y_sort_enabled] on and the coarse
## [constant OCCUPANT_Z_INDEX] band. Depth-sort among its children is
## entirely native — no custom sort is ever added here.
func _build_occupant_layer() -> Node2D:
	var layer := Node2D.new()
	layer.name = "OccupantLayer"
	layer.y_sort_enabled = true
	layer.z_index = OCCUPANT_Z_INDEX
	add_child(layer)
	return layer


## Registers the floor [TileSetAtlasSource] on [member floor_layer] (Story 006).
## One source, id [constant FLOOR_SOURCE_ID], wrapping the plain-floor texture —
## [b]cover reuses this same floor cell[/b] (there is no separate cover floor art;
## assets/art/README.md §8.8), so one source covers every painted tile.
##
## Silently skips if the texture is absent so a stripped art tree still boots with
## an unpainted board rather than failing to construct; [method paint_terrain] is
## the loud path for a real missing-art problem.
func _build_floor_tile_source() -> void:
	if not ResourceLoader.exists(FLOOR_TEXTURE_PATH):
		push_error("BoardRenderer: missing floor texture '%s' — board will render unpainted" % FLOOR_TEXTURE_PATH)
		return
	var source := TileSetAtlasSource.new()
	source.texture = load(FLOOR_TEXTURE_PATH)
	source.texture_region_size = TILE_TEXTURE_SIZE
	source.create_tile(Vector2i.ZERO)
	floor_layer.tile_set.add_source(source, FLOOR_SOURCE_ID)


## Paints the static board for [param grid] (Story 006): a floor cell for every
## passable tile, plus one Y-sorted prop per Cover tile. Idempotent — clears both
## before repainting, so it can be re-run on a map change.
##
## [b]Cover is TWO nodes, never one cell[/b] (art-bible §8.8, AC-6): a floor cell
## on [member floor_layer] PLUS a separate prop in the Y-sort group, so the mass
## occludes and is occluded by units on adjacent rows. "One PNG = one TileMapLayer
## cell" is exactly what breaks for cover — a cell cannot participate in the
## occupant Y-sort at all.
##
## [b]Impassable tiles are deliberately left UNPAINTED[/b] — the void showing
## through IS the art (assets/art/README.md: a void gap reads as a full
## tile-shaped diamond, much darker than any wear variant, which is what keeps it
## distinguishable from scorch).
##
## O(width * height).
func paint_terrain(grid: GridState) -> void:
	floor_layer.clear()
	_clear_cover_props()
	for y in grid.height:
		for x in grid.width:
			var terrain: int = grid.terrain_at(x, y)
			if terrain == GridState.Terrain.IMPASSABLE:
				continue
			floor_layer.set_cell(cell_for(Vector2i(x, y)), FLOOR_SOURCE_ID, Vector2i.ZERO)
			if terrain == GridState.Terrain.COVER:
				_add_cover_prop(Vector2i(x, y))


## Adds one Y-sorted cover-mass prop at [param tile]. Anchored bottom-centre and
## drawn at [constant TILE_LAYER_SCALE] exactly like an entity sprite: the prop's
## canvas is the full tile diamond plus headroom (256x184 at 2x, footprint the
## bottom 256x128), so bottom-centre of the canvas is the ground-contact point and
## [method grid_to_screen] places it with no extra offset.
##
## Sets no [code]z_index[/code] — depth against units is the parent layer's native
## Y-sort (ADR-0013 §2).
func _add_cover_prop(tile: Vector2i) -> void:
	if not ResourceLoader.exists(COVER_PROP_TEXTURE_PATH):
		push_error("BoardRenderer: missing cover texture '%s'" % COVER_PROP_TEXTURE_PATH)
		return
	var texture: Texture2D = load(COVER_PROP_TEXTURE_PATH)
	var prop := Sprite2D.new()
	prop.name = "%s%d_%d" % [COVER_PROP_NAME_PREFIX, tile.x, tile.y]
	prop.texture = texture
	prop.centered = false
	prop.scale = Vector2.ONE * TILE_LAYER_SCALE
	var size: Vector2 = texture.get_size()
	prop.offset = Vector2(-size.x * 0.5, -size.y)
	prop.position = grid_to_screen(tile)
	occupant_layer.add_child(prop)


## Frees every cover prop currently under [member occupant_layer], identified by
## the [constant COVER_PROP_NAME_PREFIX] naming convention so entity sprites (which
## [EntitySpriteFeed] owns and tracks separately) are never touched.
func _clear_cover_props() -> void:
	for child: Node in occupant_layer.get_children():
		if child.name.begins_with(COVER_PROP_NAME_PREFIX):
			occupant_layer.remove_child(child)
			child.queue_free()


## Maps a logical grid tile to the [TileMapLayer] CELL coordinate that draws at
## [method grid_to_screen]'s position for that tile.
##
## [b]⚠ A grid tile is NOT a tile-map cell — never call [code]set_cell(tile)[/code]
## directly.[/b] Redot/Godot lay isometric cells out in a stacked basis whose
## origin and axes differ from this project's hand-rolled 2:1 dimetric transform
## (the same engine-iso mismatch ADR-0013 §1 cites GH#89423 for). Painting raw grid
## coordinates puts the board in the wrong place entirely — measured at up to
## 1408px of drift across a 12x10 board.
##
## Rather than re-derive the engine's layout (undocumented, fork-specific, and the
## thing ADR-0013 already distrusts), this asks the engine its OWN inverse: which
## cell covers the point we want to draw at. [method TileMapLayer.local_to_map] and
## [method TileMapLayer.map_to_local] are exactly self-consistent even where the
## layout differs from ours — verified over the full 12x10 board at 0.0px error
## with 120 distinct, collision-free cells — so the result is exact, not
## approximate.
##
## The projection is taken with a ZERO origin offset because the layer node itself
## carries [member origin_offset_px] as its position (see
## [method _build_iso_tilemap_layer]); folding the offset in here as well would
## apply it twice, once scaled. O(1).
func cell_for(tile: Vector2i) -> Vector2i:
	var unoffset: Vector2 = _project(tile, TILE_WIDTH_PX, TILE_HEIGHT_PX, Vector2.ZERO)
	return floor_layer.local_to_map(unoffset / TILE_LAYER_SCALE)


## Projects a logical grid tile to its screen-space position under the 2:1
## dimetric transform (ADR-0013 §1). This is also the sprite-placement
## anchor convention — see the class doc comment. Exact inverse of
## [method screen_to_grid]. O(1).
func grid_to_screen(tile: Vector2i) -> Vector2:
	return _project(tile, TILE_WIDTH_PX, TILE_HEIGHT_PX, origin_offset_px)


## Recovers the logical grid tile containing screen-space position [param px]
## under the 2:1 dimetric transform (ADR-0013 §1). Uses [method @GlobalScope.floori]
## on the exact algebraic inverse so a point exactly on a shared tile boundary
## resolves deterministically toward the lower-index tile on every call — never
## alternates, never NaNs. Exact inverse of [method grid_to_screen]. O(1).
func screen_to_grid(px: Vector2) -> Vector2i:
	return _unproject(px, TILE_WIDTH_PX, TILE_HEIGHT_PX, origin_offset_px)


## Resolves a screen-space click to [PickResult] via occupant-priority
## picking, then diamond fallback (ADR-0013 §4, Story 004):
## [codeblock]
## 1. Test member occupant_pick_regions front-to-back in Y-sort draw order —
##    i.e. iterate the array in REVERSE, since it is stored back-to-front —
##    so a later-drawn/"in front" occupant wins the click over one behind it.
## 2. Each region's rect is an authored per-occupant clickable Rect2 (the
##    injectable seam — see member occupant_pick_regions; NEVER derived from
##    grid_to_screen).
## 3. The first region whose rect contains screen_pos wins: return its own
##    OccupantPickRegion.tile/entity_id as-is (state-tracked identity, not
##    re-derived geometrically from the click).
## 4. No region hit -> plain screen_to_grid(screen_pos) fallback, an
##    empty-tile click; occupant_entity_id = -1.
## [/codeblock]
## Exact inverse is never assumed here — an occupant's [member
## OccupantPickRegion.tile] may legitimately differ from
## [code]screen_to_grid(screen_pos)[/code] (a tall sprite's clickable region
## can overlap an adjacent tile's diamond; ADR-0013 §4, art bible §8.8).
##
## [b]⚠ See [member occupant_pick_regions] for the unresolved
## occupant-clickable-region-authoring ownership gap[/b] (S3-05,
## `production/vertical-slice/scope.md` §8(b)) — this method only consumes
## whatever that array currently holds; it does not define how real occupant
## scenes populate it.
##
## [b]CAI boundary (ADR-0013 §4, Control Manifest):[/b] Command & Action
## Interface must consume [method pick_at] as its [i]one[/i] click-routing
## entry point — it must [b]never[/b] call [method screen_to_grid] directly
## for routing decisions. [method screen_to_grid]/[method grid_to_screen]
## remain fair game for CAI's own overlay/preview positioning, just not for
## resolving what a click actually hit. O(occupant_pick_regions.size()).
func pick_at(screen_pos: Vector2) -> PickResult:
	var result := PickResult.new()
	var region_count := occupant_pick_regions.size()
	for i in range(region_count - 1, -1, -1):
		var region: OccupantPickRegion = occupant_pick_regions[i]
		if region.rect.has_point(screen_pos):
			result.tile = region.tile
			result.occupant_entity_id = region.entity_id
			return result
	result.tile = screen_to_grid(screen_pos)
	result.occupant_entity_id = -1
	return result


## Computes the on-board anchor point for [param glyph_class] at [param tile]
## (ADR-0013 §5, Story 005): exactly
## [code]grid_to_screen(tile) + glyph_offsets.offset_for(glyph_class)[/code] —
## no other computation path exists (AC-1). [param glyph_class] is a plain
## [code]int[/code] per this story's exact signature; pass one of
## [enum GlyphClass]'s named values, which are the sanctioned way to spell it
## (never a bare numeric literal at the call site).
##
## [b]The ONE anchor path for every on-board glyph[/b] (Control Manifest,
## ADR-0013 §5): both Game HUD's on-board glyph layer (TR-hud-010/011) and
## Command & Action Interface's D-3 echo (TR-cmdui-017) must call this method
## rather than re-deriving [code]grid_to_screen(tile) + <own offset>[/code]
## themselves — keeping every glyph on one shared formula is what makes
## [member glyph_offsets] a single retunable source of truth (AC-2).
##
## [b]hp-pip-never-occluded is NOT enforced here[/b] (game-hud.md CR-5/
## TR-hud-011): this method does zero overlap detection or runtime
## arbitration between simultaneously-placed glyphs on one tile — that
## guarantee comes entirely from how [member glyph_offsets]' values are
## [i]authored[/i] (see [GlyphOffsets]'s class doc comment). Building any such
## arbitration here would contradict ADR-0013 §5's explicit decision.
##
## Lazy-loads [member glyph_offsets] from [constant DEFAULT_GLYPH_OFFSETS_PATH]
## on first call if it is still [code]null[/code] — see that member's doc
## comment for why this happens here and not in [method _ready]. Camera model
## (OQ-8) is intentionally not decided by this method; the formula is
## camera-model-agnostic by construction (ADR-0013 §5). O(1).
func glyph_anchor(tile: Vector2i, glyph_class: int) -> Vector2:
	if glyph_offsets == null:
		glyph_offsets = load(DEFAULT_GLYPH_OFFSETS_PATH)
	return grid_to_screen(tile) + glyph_offsets.offset_for(glyph_class)


## Populates [member overlay_layer] with exactly [param tiles], all tagged
## [param class_id] (ADR-0013 §3, story-003). Always clears any prior overlay
## first (equivalent to [method clear_overlay]), so a second call
## [b]replaces[/b] the previous overlay rather than accumulating on top of
## it — this holds even for an empty [param tiles], which is therefore
## equivalent to a bare [method clear_overlay] call. [param class_id] is a
## plain [code]int[/code] per this story's exact signature; pass one of
## [enum OverlayClass]'s named values, which are the sanctioned way to spell
## it (never a bare numeric literal at the call site).
##
## [b]Structural boundary (ADR-0013 §3, Control Manifest):[/b] this is the
## [i]only[/i] sanctioned way to place an overlay tile. Consumers (Command &
## Action Interface, any future system) must call this — and
## [method clear_overlay] — and must never touch [method grid_to_screen]/
## [method screen_to_grid] or call [code]overlay_layer.set_cell[/code]
## directly for overlay placement; floor/overlay screen alignment is
## guaranteed by [member overlay_layer] sharing the floor's exact [TileSet]
## config (see [method _build_iso_tilemap_layer]), which only holds if this
## method stays the single write path.
func set_overlay(tiles: Array[Vector2i], class_id: int) -> void:
	clear_overlay()
	for tile in tiles:
		overlay_layer.set_cell(cell_for(tile), class_id, Vector2i.ZERO)


## Multi-class overlay write (ADR-0013 §3; Command & Action Interface Story 006).
## Clears the overlay ONCE, then paints every [param class_tiles] entry — an
## [int] [enum OverlayClass] id keyed to its [code]Array[Vector2i][/code] of
## tiles — so several classes coexist in a single preview (e.g. a Move preview's
## [constant OverlayClass.MOVE_IN_CAP] + [constant OverlayClass.MOVE_OVER_CAP] +
## [constant OverlayClass.AFTER_MOVE_ECHO] rendered together, which the
## single-class [method set_overlay] cannot express because it clears on every
## call). Same [member overlay_layer]/[TileSet] write path as [method set_overlay]
## — screen alignment is guaranteed by construction identically (this stays a
## sanctioned overlay write path; consumers still never touch
## [member overlay_layer] or [method grid_to_screen] directly). A later-listed
## class wins a tile shared with an earlier one (last write per cell); callers
## partition tiles across classes so overlap does not arise. O(total tiles).
func set_overlays(class_tiles: Dictionary) -> void:
	clear_overlay()
	for class_id: int in class_tiles:
		for tile: Vector2i in class_tiles[class_id]:
			overlay_layer.set_cell(cell_for(tile), class_id, Vector2i.ZERO)


## Empties [member overlay_layer] of every populated cell (ADR-0013 §3,
## story-003). A no-op, never an error, when the overlay is already empty —
## see the class-level boundary note on [method set_overlay] for why this is
## the only sanctioned way to clear overlay tiles.
func clear_overlay() -> void:
	overlay_layer.clear()


## Pure closed-form forward projection, parameterized on tile dimensions and
## offset. [method grid_to_screen] calls this with the instance's
## [constant TILE_WIDTH_PX]/[constant TILE_HEIGHT_PX]/[member origin_offset_px];
## this is the one shared formula both the instance API and dimension-
## independence tests (ADR-0013 §1 validation) exercise directly — never a
## second, independently-written copy. O(1).
static func _project(tile: Vector2i, tile_width_px: float, tile_height_px: float, offset: Vector2) -> Vector2:
	return offset + Vector2(
		(tile.x - tile.y) * tile_width_px * 0.5,
		(tile.x + tile.y) * tile_height_px * 0.5
	)


## Pure closed-form inverse projection, exact algebraic inverse of
## [method _project] for the same [param tile_width_px]/[param tile_height_px]/
## [param offset]. See [method screen_to_grid] for the boundary tie-break
## contract. O(1).
static func _unproject(px: Vector2, tile_width_px: float, tile_height_px: float, offset: Vector2) -> Vector2i:
	var local: Vector2 = px - offset
	var u: float = local.x / tile_width_px + local.y / tile_height_px
	var v: float = local.y / tile_height_px - local.x / tile_width_px
	return Vector2i(floori(u), floori(v))
