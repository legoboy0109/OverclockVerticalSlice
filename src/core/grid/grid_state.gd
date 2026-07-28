## GridState — the authoritative logical board.
##
## Foundation-layer data model per ADR-0005. Stores the board as two flat
## packed arrays ([member terrain], [member occupancy]) plus [member width]/
## [member height], indexed [code]y * width + x[/code]. Extends [Resource]
## (never [Node]) so it is render-decoupled, headless-testable, and clones
## cleanly via [code]duplicate_deep()[/code] once nested inside
## [code]GameState[/code] (ADR-0001). Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001/ADR-0007).
##
## Story 001 shipped the read-only query API. Story 002 adds
## [method place]/[method remove]/[method move] — the grid's only mutators
## (ADR-0005). [member terrain] stays static after load; [member occupancy] is
## the only field these methods ever write. All three are called only from
## inside [code]apply_action[/code] handlers by architectural convention, but
## that call-context rule is enforced by code review, not by a runtime guard
## in this class.
##
## Usage:
## [codeblock]
## var grid := GridState.new()
## grid.width = 8
## grid.height = 8
## grid.terrain = PackedByteArray()
## grid.terrain.resize(8 * 8)
## grid.terrain.fill(GridState.Terrain.PLAIN)
## grid.occupancy = PackedInt32Array()
## grid.occupancy.resize(8 * 8)
## grid.occupancy.fill(-1)
##
## if grid.is_passable(3, 4):
##     print("tile (3,4) is free")
## [/codeblock]
class_name GridState
extends Resource

## One terrain type per tile. Values are stored as bytes in [member terrain].
## PLAIN and COVER are passable; IMPASSABLE blocks movement and line-of-fire.
enum Terrain { PLAIN = 0, COVER = 1, IMPASSABLE = 2 }

## Sentinel value used by [method occupant_at] for "no occupant" and for
## out-of-bounds occupant queries.
const EMPTY_OCCUPANT: int = -1

## Board width in tiles. Set once at construction; static after load.
@export var width: int

## Board height in tiles. Set once at construction; static after load.
@export var height: int

## One byte per tile, value = [enum Terrain]. Static after load. Indexed via
## [method index]. Never mutate directly — this story exposes no mutators;
## Story 003's [code]build_grid[/code] is the sole writer at construction time.
@export var terrain: PackedByteArray

## One int per tile, value = an entity id, or -1 for empty. The only mutable
## grid field. Never mutate directly outside [code]place[/code]/[code]move[/code]/
## [code]remove[/code] (Story 002) — those are the grid's only sanctioned
## mutators (ADR-0005).
@export var occupancy: PackedInt32Array


## Returns the flat array index for tile [param x], [param y]:
## [code]y * width + x[/code]. Does not bounds-check — callers that may be
## out-of-bounds must call [method in_bounds] first. O(1) integer arithmetic.
func index(x: int, y: int) -> int:
	return y * width + x


## Returns true if [param x], [param y] lies within
## [code][0, width) x [0, height)[/code]. O(1).
func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


## Returns the [enum Terrain] value at [param x], [param y]. Returns
## [constant Terrain.IMPASSABLE] as the out-of-bounds sentinel — an OOB tile
## behaves like a wall to every caller, never a crash. O(1).
func terrain_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Terrain.IMPASSABLE
	return terrain[index(x, y)]


## Returns true if the tile at [param x], [param y] is
## [constant Terrain.COVER]. Out-of-bounds tiles are never Cover (they report
## IMPASSABLE via [method terrain_at]). O(1).
func is_cover(x: int, y: int) -> bool:
	return terrain_at(x, y) == Terrain.COVER


## Returns true if the tile at [param x], [param y] can be entered: terrain is
## not Impassable AND no occupant is present. Out-of-bounds tiles are always
## not passable. O(1).
func is_passable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	return terrain_at(x, y) != Terrain.IMPASSABLE and occupant_at(x, y) == EMPTY_OCCUPANT


## Returns the entity id occupying [param x], [param y], or
## [constant EMPTY_OCCUPANT] (-1) if the tile is empty or out-of-bounds.
## Resolve the id to an [code]EntityState[/code] via
## [code]GameState.entity_at[/code] — this class never holds entity references
## (ADR-0005). O(1).
func occupant_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return EMPTY_OCCUPANT
	return occupancy[index(x, y)]


## Returns the orthogonal (4-directional: N/E/S/W) in-bounds neighbors of
## [param x], [param y]. Diagonals are never neighbors (GDD Detailed Rules
## #3). Out-of-bounds neighbors are filtered out — the result never contains
## an OOB tile. Fixed N, E, S, W enumeration order. O(4).
func neighbors(x: int, y: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [
		Vector2i(x, y - 1), # N
		Vector2i(x + 1, y), # E
		Vector2i(x, y + 1), # S
		Vector2i(x - 1, y), # W
	]
	for candidate: Vector2i in candidates:
		if in_bounds(candidate.x, candidate.y):
			result.append(candidate)
	return result


## Returns the Manhattan (taxicab) distance between tiles [param a] and
## [param b]: [code]abs(a.x - b.x) + abs(a.y - b.y)[/code]. Pure integer
## arithmetic, O(1).
func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Places [param entity_id] at [param x], [param y], enforcing the
## single-occupant invariant (ADR-0005, TR-grid-003). Re-validates
## internally — never trust a caller's prior [method is_passable] check.
## Fails (returns [code]false[/code], state left completely unchanged) if:
## the tile is out-of-bounds, its terrain is [constant Terrain.IMPASSABLE],
## the tile already holds an occupant, or [param entity_id] is
## [constant EMPTY_OCCUPANT] (-1) — that value is the empty sentinel and
## cannot be distinguished from "no occupant" once stored, so placing it is
## rejected as a no-op rather than silently corrupting [method occupant_at].
## On success, writes [param entity_id] into [member occupancy] and returns
## [code]true[/code]. O(1).
## [codeblock]
## if grid.place(42, 3, 4):
##     print("unit 42 now occupies (3,4)")
## [/codeblock]
func place(entity_id: int, x: int, y: int) -> bool:
	if entity_id == EMPTY_OCCUPANT:
		return false
	if not in_bounds(x, y):
		return false
	if terrain_at(x, y) == Terrain.IMPASSABLE:
		return false
	if occupant_at(x, y) != EMPTY_OCCUPANT:
		return false
	occupancy[index(x, y)] = entity_id
	return true


## Clears any occupant at [param x], [param y]. Idempotent and never throws:
## returns [code]false[/code] as a no-op (no mutation) if the tile is
## out-of-bounds, its terrain is [constant Terrain.IMPASSABLE], or it is
## already empty. On a genuinely occupied, in-bounds, passable-terrain tile,
## sets its occupancy to [constant EMPTY_OCCUPANT] and returns
## [code]true[/code]. O(1).
## [codeblock]
## grid.remove(3, 4) # safe to call even if (3,4) was already empty
## [/codeblock]
func remove(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	if terrain_at(x, y) == Terrain.IMPASSABLE:
		return false
	if occupant_at(x, y) == EMPTY_OCCUPANT:
		return false
	occupancy[index(x, y)] = EMPTY_OCCUPANT
	return true


## Atomically relocates whatever occupies [param from] to [param to].
## Validate-before-mutate: every failure condition is checked before either
## array write happens, so a rejected call leaves [member occupancy]
## completely untouched, and an accepted call never passes through an
## observable intermediate state where both tiles hold the occupant. Fails
## (returns [code]false[/code]) if [param from] is out-of-bounds or empty, or
## if [param to] is out-of-bounds, [constant Terrain.IMPASSABLE], or already
## occupied.
## [b]`from == to`[/b]: treated as a successful no-op-equivalent — if
## [param from] is a valid, occupied, in-bounds tile, [code]move[/code]
## returns [code]true[/code] and leaves the occupant in place (checking "is
## [param to] occupied" against a tile's own current occupant would otherwise
## always fail a same-tile move, even though nothing is actually contested).
## O(1).
## [codeblock]
## if grid.move(Vector2i(3, 4), Vector2i(3, 5)):
##     print("occupant relocated")
## [/codeblock]
func move(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(from.x, from.y):
		return false
	var entity_id: int = occupant_at(from.x, from.y)
	if entity_id == EMPTY_OCCUPANT:
		return false
	if from == to:
		return true
	if not in_bounds(to.x, to.y):
		return false
	if terrain_at(to.x, to.y) == Terrain.IMPASSABLE:
		return false
	if occupant_at(to.x, to.y) != EMPTY_OCCUPANT:
		return false
	occupancy[index(from.x, from.y)] = EMPTY_OCCUPANT
	occupancy[index(to.x, to.y)] = entity_id
	return true
