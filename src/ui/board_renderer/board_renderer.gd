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

## Tile width in pixels for the 2:1 dimetric projection. Placeholder value
## satisfying the 2:1 ratio (ADR-0013 §1) — the exact pixel value is
## technical-art's eventual call, not locked by this story.
const TILE_WIDTH_PX: float = 128.0

## Tile height in pixels for the 2:1 dimetric projection. Placeholder value —
## see [constant TILE_WIDTH_PX].
const TILE_HEIGHT_PX: float = 64.0

## Board-layout placement offset applied uniformly to every projected screen
## position. Designer/technical-art/UX-tunable; defaults to no offset.
@export var origin_offset_px: Vector2 = Vector2.ZERO


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
