class_name BoardCursor extends RefCounted
## Verbatim port of ADR-0014 §1's BoardCursor for the pre-Accepted engine
## spike. Headless, no scene-tree dependency, no input-polling of its own —
## identical shape/semantics to the ADR's pseudocode (grid-axis stepping,
## deterministic tile-index jump_to_next). Once ADR-0015 lands this class
## should be authored for real in src/ against the real GridState; this copy
## is throwaway spike code (prototype-code rule) and must not be imported by
## production code.

var grid_pos: Vector2i = Vector2i.ZERO

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)


## Steps one tile in a grid-axis direction (never a screen-axis direction).
## Returns false and leaves grid_pos unchanged if the target tile is out of bounds.
func step(direction: Vector2i, grid: GridStub) -> bool:
	var target := grid_pos + direction
	if not grid.in_bounds(target):
		return false
	grid_pos = target
	return true


## Jumps to the next tile in `candidates`, deterministic ascending tile-index
## order (y*width+x), wrapping from last back to first. No-op if empty.
func jump_to_next(candidates: Array[Vector2i], grid: GridStub) -> void:
	if candidates.is_empty():
		return
	var sorted_tiles := candidates.duplicate()
	sorted_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _tile_index(a, grid) < _tile_index(b, grid))
	var current_index := sorted_tiles.find(grid_pos)
	grid_pos = sorted_tiles[(current_index + 1) % sorted_tiles.size()] if current_index != -1 else sorted_tiles[0]


static func _tile_index(tile: Vector2i, grid: GridStub) -> int:
	return tile.y * grid.width + tile.x
