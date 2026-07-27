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
## [b]Out of scope for this story[/b] (see neighbouring Board Renderer
## stories): [code]TileMapLayer[/code] nodes/scene-tree structure (002/003),
## [method pick_at] (004), glyph offsets (005), any [code]GridState[/code] reads.
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

## Board-layout placement offset applied uniformly to every projected screen
## position. Designer/technical-art/UX-tunable; defaults to no offset.
@export var origin_offset_px: Vector2 = Vector2.ZERO

## Static terrain art layer (ADR-0013 §2). Iso-shaped [TileSet]; sits outside
## the Y-sort group. Built in [method _ready]; empty (no painted cells) is a
## valid, Story-002-complete state — floor art content is not this story's
## scope.
var floor_layer: TileMapLayer

## Reachable/target/build overlay layer (ADR-0013 §2/§3). Shares the floor's
## iso shape config; [method set_overlay]/[method clear_overlay] land in
## Story 003 — this story only creates the empty layer at the correct
## z-index band.
var overlay_layer: TileMapLayer

## Y-sorted occupant group (ADR-0013 §2). [member Node2D.y_sort_enabled] is
## the sole depth-sort mechanism for children of this node — never a custom
## sort. See the class doc comment's scene-tree section for the
## z-index/y-sort division of labor this node anchors.
var occupant_layer: Node2D


## Builds the Story 002 scene-tree skeleton (ADR-0013 §2) and populates
## [member occupant_layer] with placeholder fixtures. Runs on every
## instantiation, whether via [code]BoardRenderer.new()[/code] (as Story
## 001's tests already do) or future scene instancing — see the class doc
## comment for why this is programmatic rather than a [code].tscn[/code].
func _ready() -> void:
	floor_layer = _build_iso_tilemap_layer("FloorTileMapLayer", FLOOR_Z_INDEX)
	overlay_layer = _build_iso_tilemap_layer("OverlayTileMapLayer", OVERLAY_Z_INDEX)
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
