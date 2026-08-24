class_name GridStub extends RefCounted
## Minimal bounds-only stand-in for ADR-0005's GridState, scoped down to what
## BoardCursor.step()'s bounds check needs. Same "stub, not the real thing"
## convention as qq05/qq06's GridStub/BenchState — real GridState.in_bounds()
## does not exist in src/ yet. Throwaway spike code only.

var width: int
var height: int


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < width and tile.y >= 0 and tile.y < height
