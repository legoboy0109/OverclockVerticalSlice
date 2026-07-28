## BoardCursor — headless grid-space navigation cursor for keyboard/gamepad
## board control (ADR-0014 §Input & Focus; Story 005, TR-cmdui-018/019/020/024).
##
## A pure [RefCounted] value object holding only [member grid_pos]. It has NO
## scene-tree reference, NO input polling of its own, and NO game rules — the
## owning [code]CommandInterface[/code] [Node] reads the input actions in
## [code]_unhandled_input[/code] and drives this cursor; the cursor merely
## answers "where does grid-axis motion / a cycle-jump land." This split (pure
## value object + driving Node) mirrors the [code]CommandFSM[/code]/[AI] pattern
## and keeps board navigation unit-testable with zero mocks.
##
## [b]Grid-axis, never screen/iso-axis (TR-cmdui-019):[/b] [method step] maps a
## direction straight onto grid [code](x, y)[/code] — [code]ui_up[/code] →
## NORTH → [code]y - 1[/code] — independent of camera or isometric visual
## orientation. The caller passes the grid-axis [Vector2i] (e.g.
## [constant Vector2i.UP] for NORTH); this class never reinterprets it against a
## screen basis.
##
## Usage:
## [codeblock]
## var cursor := BoardCursor.new()
## cursor.grid_pos = Vector2i(4, 4)
## cursor.step(Vector2i.UP, grid)          # NORTH → (4, 3) if in bounds
## cursor.jump_to_next(reachable_tiles, grid)  # next candidate, ascending index
## [/codeblock]
class_name BoardCursor
extends RefCounted

## The cursor's current grid tile. The sole state this object carries.
var grid_pos: Vector2i = Vector2i.ZERO


## Moves the cursor one tile along [param direction] (a grid-axis [Vector2i]:
## [constant Vector2i.UP]=NORTH/y-1, [constant Vector2i.DOWN]=SOUTH/y+1,
## [constant Vector2i.RIGHT]=EAST/x+1, [constant Vector2i.LEFT]=WEST/x-1).
## Returns [code]true[/code] and updates [member grid_pos] iff the target tile
## is in bounds of [param grid]; otherwise returns [code]false[/code] and leaves
## [member grid_pos] unchanged — so repeated out-of-bounds steps at a boundary
## can never corrupt the position (AC bounds). Never consults terrain/occupancy
## (that is legality, a game rule the cursor does not own — a cursor may rest on
## any in-bounds tile). O(1).
func step(direction: Vector2i, grid: GridState) -> bool:
	var target: Vector2i = grid_pos + direction
	if not grid.in_bounds(target.x, target.y):
		return false
	grid_pos = target
	return true


## Advances [member grid_pos] to the next tile in [param candidates], cycling in
## deterministic ascending tile-index order ([code]y * grid.width + x[/code],
## ADR-0003's iteration convention) and wrapping last→first (AC cycle). If
## [member grid_pos] is not currently one of the candidates, jumps to the
## lowest-index candidate. A [b]no-op[/b] when [param candidates] is empty (no
## crash). The candidate set is caller-supplied per preview mode (the
## [code]reachable()[/code] frontier in Move, [code]legal_targets[/code] in
## Attack, legal tiles in Build/Deploy) — this method owns only the cycling
## mechanism, not which tiles are candidates. O(n log n) in the candidate count
## (one sort); candidate sets are small preview frontiers.
func jump_to_next(candidates: Array[Vector2i], grid: GridState) -> void:
	if candidates.is_empty():
		return
	var w: int = grid.width
	var ordered: Array[Vector2i] = candidates.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * w + a.x < b.y * w + b.x)
	# find() returns -1 when grid_pos is not a candidate; (-1 + 1) % n == 0 then
	# selects the lowest-index candidate for the first jump.
	var current: int = ordered.find(grid_pos)
	grid_pos = ordered[(current + 1) % ordered.size()]
