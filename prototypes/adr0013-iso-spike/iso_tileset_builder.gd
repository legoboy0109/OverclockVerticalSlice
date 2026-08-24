## Builds a placeholder TileSet configured for TILE_SHAPE_ISOMETRIC at runtime, so this
## THROWAWAY spike needs zero imported binary art assets. Tiles are flat-color diamonds
## baked into an Image/ImageTexture (checkerboard so seams between tiles are visually
## obvious — validates "diamonds tile seamlessly" per the ADR's live-check goal).
##
## ADR-0013 §3: overlay TileMapLayer must share the floor's exact TileSet config (same
## TILE_WIDTH_PX/TILE_HEIGHT_PX, same TILE_SHAPE_ISOMETRIC) so alignment is guaranteed
## by construction — build_shared_tileset() is called once and handed to BOTH layers.
class_name IsoTileSetBuilder
extends RefCounted

const TILE_WIDTH_PX: int = int(BoardTransform.TILE_WIDTH_PX)
const TILE_HEIGHT_PX: int = int(BoardTransform.TILE_HEIGHT_PX)

# Atlas tile indices (single-column atlas, one iso tile-shaped cell per row).
const ATLAS_FLOOR_A := Vector2i(0, 0)
const ATLAS_FLOOR_B := Vector2i(0, 1)
const ATLAS_OVERLAY := Vector2i(0, 2)

## Draws a solid-color diamond (the iso tile shape) into an RGBA image cell.
## Pixels outside the diamond are left transparent so floor tiles don't draw as squares.
static func _paint_diamond(image: Image, cell_origin: Vector2i, fill: Color, edge: Color) -> void:
	var half_w := TILE_WIDTH_PX / 2.0
	var half_h := TILE_HEIGHT_PX / 2.0
	var center := Vector2(cell_origin.x + half_w, cell_origin.y + half_h)
	for y in range(TILE_HEIGHT_PX):
		for x in range(TILE_WIDTH_PX):
			var px := Vector2(cell_origin.x + x + 0.5, cell_origin.y + y + 0.5)
			var d := absf((px.x - center.x) / half_w) + absf((px.y - center.y) / half_h)
			if d <= 1.0:
				# thin edge ring near the diamond boundary, to make seams/overlap visible
				image.set_pixel(cell_origin.x + x, cell_origin.y + y, edge if d > 0.94 else fill)

## Builds one shared TileSet + backing atlas, returns { "tileset": TileSet, "source_id": int }.
static func build_shared_tileset() -> Dictionary:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_size = Vector2i(TILE_WIDTH_PX, TILE_HEIGHT_PX)

	var atlas_h := TILE_HEIGHT_PX * 3
	var image := Image.create(TILE_WIDTH_PX, atlas_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	_paint_diamond(image, Vector2i(0, ATLAS_FLOOR_A.y * TILE_HEIGHT_PX), Color(0.24, 0.46, 0.29), Color(0.14, 0.30, 0.18))
	_paint_diamond(image, Vector2i(0, ATLAS_FLOOR_B.y * TILE_HEIGHT_PX), Color(0.30, 0.55, 0.35), Color(0.18, 0.36, 0.22))
	_paint_diamond(image, Vector2i(0, ATLAS_OVERLAY.y * TILE_HEIGHT_PX), Color(0.95, 0.85, 0.25, 0.65), Color(1.0, 1.0, 0.4, 0.85))

	var texture := ImageTexture.create_from_image(image)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_WIDTH_PX, TILE_HEIGHT_PX)
	for row in range(3):
		var coords := Vector2i(0, row)
		atlas_source.create_tile(coords)

	var source_id := tile_set.add_source(atlas_source)
	return {"tileset": tile_set, "source_id": source_id}

## Builds a simple flat-color placeholder sprite texture: a rectangle footprint sitting
## on the ground (bottom-center pivot, per art bible's ground-contact-pivot convention
## referenced by ADR-0013 §1) with a colored body above it so tall props/units are visibly
## taller than the tile they stand on (needed to see occlusion/Y-sort behavior at all).
static func build_placeholder_sprite_texture(width: int, height: int, body: Color, outline: Color) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(height):
		for x in range(width):
			var on_edge := x == 0 or x == width - 1 or y == 0 or y == height - 1
			image.set_pixel(x, y, outline if on_edge else body)
	return ImageTexture.create_from_image(image)
