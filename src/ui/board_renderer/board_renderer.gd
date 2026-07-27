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
## doc comment), glyph offsets (005, still pending), any
## [code]GridState[/code] reads.
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
##       `-- placeholder occupant/prop sprites (Story 002 fixtures only)
## [/codeblock]
## [code]z_index[/code] is the coarse cross-tree band (Floor 0 -> Overlay 1
## -> Occupant 2); [member Node2D.y_sort_enabled] on [code]OccupantLayer[/code]
## re-sorts only children within that layer — the two mechanisms are never
## conflated (ADR-0013 §2, Control Manifest). Children added under
## [code]OccupantLayer[/code] must never set their own conflicting
## [code]z_index[/code] — that would fight the Y-sort.
##
## [b]Story 002 placeholder occupants:[/b] [method _ready] also populates
## [code]OccupantLayer[/code] with runtime-generated placeholder sprites (2
## units at different rows + 1 tall prop) purely to give the Y-sort mechanism
## something to sort — there is no live [code]GameState.entities()[/code]
## feed yet. [b]Open item (unassigned, per epic/story Out of Scope):[/b]
## whichever story first wires [code]BoardRenderer[/code] to real match
## state owns replacing [method _build_placeholder_occupants] outright.

## Tile width in pixels for the 2:1 dimetric projection. Placeholder value
## satisfying the 2:1 ratio (ADR-0013 §1) — the exact pixel value is
## technical-art's eventual call, not locked by this story.
const TILE_WIDTH_PX: float = 128.0

## Tile height in pixels for the 2:1 dimetric projection. Placeholder value —
## see [constant TILE_WIDTH_PX].
const TILE_HEIGHT_PX: float = 64.0

## Coarse cross-tree z-index band for [member floor_layer] (ADR-0013 §2).
## Sits outside the Y-sort group — never compared against occupant Y.
const FLOOR_Z_INDEX: int = 0

## Coarse cross-tree z-index band for [member overlay_layer] (ADR-0013 §2).
const OVERLAY_Z_INDEX: int = 1

## Coarse cross-tree z-index band for [member occupant_layer] (ADR-0013 §2).
## Depth-sort within this band is native [member Node2D.y_sort_enabled],
## never this constant nor any custom depth math.
const OCCUPANT_Z_INDEX: int = 2

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

## [b]Injectable occupant-pick-region seam (ADR-0013 §4, Story 004).[/b]
## Ordered back-to-front matching [member occupant_layer]'s Y-sort paint
## order (i.e. the same order real occupant children would visually draw
## in); [method pick_at] tests it in [i]reverse[/i] so the front-most
## (closest-to-camera) region wins ties, per ADR-0013 §4 step 1. Defaults to
## empty, which makes [method pick_at] degrade to plain
## [method screen_to_grid] for every click — the correct, harmless default
## until real regions are wired in.
##
## [b]⚠ Ownership gap — do not treat this as the real convention:[/b] the
## per-sprite [Rect2]/mask "occupant clickable-region authoring" that would
## populate this array from live occupant sprites has [b]no confirmed
## owning epic yet[/b] (ADR-0013 Consequences/Risks; tracked as vertical-
## slice build-seam S3-05, `production/vertical-slice/scope.md` §8(b)).
## This member exists purely as a settable seam so [method pick_at]'s
## priority logic is unit-testable now via injected
## [OccupantPickRegion] mocks (this story's tests) — it is deliberately
## [i]not[/i] wired to [member occupant_layer]'s placeholder occupants, and
## nothing here invents a real "derive [Rect2] from a sprite" convention.
## The real live wiring (populating this array from actual occupant scenes)
## is that unassigned owner's job, not this story's.
var occupant_pick_regions: Array[OccupantPickRegion] = []


## Builds the Story 002 scene-tree skeleton (ADR-0013 §2) and populates
## [member occupant_layer] with placeholder fixtures. Runs on every
## instantiation, whether via [code]BoardRenderer.new()[/code] (as Story
## 001's tests already do) or future scene instancing — see the class doc
## comment for why this is programmatic rather than a [code].tscn[/code].
func _ready() -> void:
	floor_layer = _build_iso_tilemap_layer("FloorTileMapLayer", FLOOR_Z_INDEX)
	overlay_layer = _build_iso_tilemap_layer("OverlayTileMapLayer", OVERLAY_Z_INDEX)
	_build_overlay_tile_source()
	occupant_layer = _build_occupant_layer()
	_build_placeholder_occupants()


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
	tile_set.tile_size = Vector2i(int(TILE_WIDTH_PX), int(TILE_HEIGHT_PX))
	layer.tile_set = tile_set
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
	var tile_size := Vector2i(int(TILE_WIDTH_PX), int(TILE_HEIGHT_PX))
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


## [b]Story 002 placeholder fixtures — temporary.[/b] Populates
## [member occupant_layer] with 2 unit placeholders at different grid rows
## plus 1 tall-prop placeholder, purely so the Y-sort mechanism has something
## to sort (QA Test Cases, story-002). Every placeholder is a runtime-built
## [Polygon2D] — deliberately [Node2D]-based (never a [Control]-based node
## like [ColorRect]: [member Node2D.y_sort_enabled] on [member occupant_layer]
## only ever compares [member Node2D.position].y among [Node2D] children, so
## a [Control] child would silently never participate in the sort) — with a
## manually-set ground-contact (bottom-center) pivot: the polygon's local
## points extend upward from the node's own origin, so
## [code]position = grid_to_screen(tile)[/code] directly IS the
## ground-contact point, the same sprite-placement anchor contract every
## future real occupant (e.g. [Sprite2D]) will use (class doc comment,
## Story 001). None of these placeholders set their own [code]z_index[/code],
## which is itself the regression guard for AC-4 (a child that does not set
## [code]z_index[/code] must still participate correctly in the Y-sort
## group).
##
## [b]Open item (unassigned):[/b] this method — not just its call site — is
## meant to be replaced wholesale once a story wires
## [member occupant_layer] to a live [code]GameState.entities()[/code] feed
## (see the class doc comment and story-002's Out of Scope).
func _build_placeholder_occupants() -> void:
	_add_placeholder_occupant("PlaceholderUnitA", Vector2i(3, 2), Vector2(40.0, 64.0), Color(0.2, 0.4, 0.85))
	_add_placeholder_occupant("PlaceholderUnitB", Vector2i(3, 5), Vector2(40.0, 64.0), Color(0.85, 0.3, 0.25))
	_add_placeholder_occupant("PlaceholderTallProp", Vector2i(4, 3), Vector2(64.0, 140.0), Color(0.55, 0.35, 0.15))


## Adds one placeholder occupant [Polygon2D] under [member occupant_layer] at
## [param tile], sized [param footprint_size], tinted [param color]. Node2D-
## based by design (see [method _build_placeholder_occupants]'s doc comment
## for why this must never be a [Control]-based node). Ground-contact
## bottom-center pivot is achieved by authoring the polygon's local point
## rectangle entirely above y=0 — [code]position = grid_to_screen(tile)[/code]
## is then directly the ground-contact point, no separate pivot offset
## needed. [param footprint_size].y taller placeholders (the "tall prop"
## case) visibly overhang above their own tile exactly as ADR-0013 §2/art
## bible §8.8 describe. Deliberately sets no [code]z_index[/code] on the
## returned node — see [method _build_placeholder_occupants].
func _add_placeholder_occupant(node_name: String, tile: Vector2i, footprint_size: Vector2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.color = color
	var half_width := footprint_size.x * 0.5
	polygon.polygon = PackedVector2Array([
		Vector2(-half_width, -footprint_size.y),
		Vector2(half_width, -footprint_size.y),
		Vector2(half_width, 0.0),
		Vector2(-half_width, 0.0),
	])
	polygon.position = grid_to_screen(tile)
	occupant_layer.add_child(polygon)


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
		overlay_layer.set_cell(tile, class_id, Vector2i.ZERO)


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
