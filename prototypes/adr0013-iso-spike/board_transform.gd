## ADR-0013 §1 — hand-rolled iso grid<->screen transform, copied verbatim (not re-derived).
## THROWAWAY spike code. Shared by the headless round-trip check and the interactive scene
## so both exercise the exact same formula the ADR proposes for BoardRenderer.
##
## Never call TileMapLayer.local_to_map()/map_to_local() for this project's own grid math —
## ADR-0013 bans it (GH#89423, confirmed accuracy bug for isometric tile shapes).
class_name BoardTransform
extends RefCounted

const TILE_WIDTH_PX: float = 128.0
const TILE_HEIGHT_PX: float = 64.0

var origin_offset_px: Vector2 = Vector2.ZERO

func _init(p_origin_offset_px: Vector2 = Vector2.ZERO) -> void:
	origin_offset_px = p_origin_offset_px

func grid_to_screen(tile: Vector2i) -> Vector2:
	return origin_offset_px + Vector2(
		(tile.x - tile.y) * TILE_WIDTH_PX * 0.5,
		(tile.x + tile.y) * TILE_HEIGHT_PX * 0.5
	)

func screen_to_grid(px: Vector2) -> Vector2i:
	var local := px - origin_offset_px
	var u := local.x / TILE_WIDTH_PX + local.y / TILE_HEIGHT_PX
	var v := local.y / TILE_HEIGHT_PX - local.x / TILE_WIDTH_PX
	return Vector2i(floori(u), floori(v))
