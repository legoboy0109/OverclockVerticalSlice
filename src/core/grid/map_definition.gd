## MapDefinition — the standalone-loadable map-authoring format.
##
## Foundation-layer data model per ADR-0005. A `.tres` [Resource] describing
## either an Authored (hand-placed terrain) or Procedural (seeded generation)
## map. [method build_grid] is the sole [GridState] constructor: it consumes
## a [MapDefinition] and runs the fixed validate -> lay-terrain -> validate-
## reachability -> init-occupancy pipeline, returning a ready-to-play
## [GridState] or [code]null[/code] on rejection.
##
## Story 003 implements the AUTHORED branch of [method build_grid] only. The
## [code]proc_*[/code] fields below are declared now so the `.tres` schema is
## complete and stable, but they are inert until Story 004 implements
## [code]Mode.PROCEDURAL[/code] generation — building a [code]PROCEDURAL[/code]
## [MapDefinition] today always fails with a logged "not yet implemented"
## error and returns [code]null[/code].
##
## Usage:
## [codeblock]
## var map_def := MapDefinition.new()
## map_def.width = 10
## map_def.height = 8
## map_def.mode = MapDefinition.Mode.AUTHORED
## map_def.authored_terrain = PackedByteArray()
## map_def.authored_terrain.resize(10 * 8)
## map_def.authored_terrain.fill(GridState.Terrain.PLAIN)
## map_def.hq_tiles = [Vector2i(1, 1), Vector2i(8, 6)]
## map_def.deploy_tiles = []
##
## var grid: GridState = MapDefinition.build_grid(map_def)
## if grid == null:
##     print("map rejected — see push_error output for the reason")
## [/codeblock]
class_name MapDefinition
extends Resource

## Authoring mode. AUTHORED consumes [member authored_terrain] directly;
## PROCEDURAL generates terrain from the `proc_*` params (Story 004).
enum Mode { AUTHORED, PROCEDURAL }

## Minimum/maximum board dimension, inclusive, per TR-grid-001/-012. Both
## [member width] and [member height] must fall in this range or
## [method build_grid] rejects the map.
const MIN_DIM: int = 8
const MAX_DIM: int = 24

## Board width in tiles. Must be in [code][MIN_DIM, MAX_DIM][/code].
@export var width: int

## Board height in tiles. Must be in [code][MIN_DIM, MAX_DIM][/code].
@export var height: int

## Which branch [method build_grid] runs. One of [enum Mode].
@export var mode: int

## One byte per tile, value = [enum GridState.Terrain]. Used iff
## [member mode] is [constant Mode.AUTHORED]; must have exactly
## [code]width * height[/code] entries or the map is rejected.
@export var authored_terrain: PackedByteArray

## Seed for procedural generation. Story-004-only; inert in this story.
@export var proc_seed: int

## Width (in tiles) of the central feature band, perpendicular to the
## HQ-to-HQ axis. Story-004-only; inert in this story.
@export var proc_band_width: int

## Feature density as a scaled integer (30 = 0.30), per ADR-0003 Rule 2.
## Story-004-only; inert in this story.
@export var proc_density_x100: int

## Cover-vs-Impassable feature split as a scaled integer (70 = 0.70 Cover
## share), per ADR-0003 Rule 2. Story-004-only; inert in this story.
@export var proc_feature_mix_x100: int

## Whether procedural features mirror across the board center.
## Story-004-only; inert in this story.
@export var proc_symmetric: bool = true

## The two HQ tile coordinates (exactly 2, one per player, VS 1v1 scope).
## Both must be in-bounds and on non-Impassable terrain, and mutually
## reachable, or [method build_grid] rejects the map.
@export var hq_tiles: Array[Vector2i]

## Starting deploy tile coordinates for non-HQ starting entities. Not yet
## consumed by [method build_grid]'s entity-placement step beyond HQs
## themselves; reserved for a future story that seeds full starting rosters.
@export var deploy_tiles: Array[Vector2i]


## The sole [GridState] constructor (ADR-0005). Runs, in order: (1) validate
## [member width]/[member height] both lie in
## [code][MIN_DIM, MAX_DIM][/code]; (2) for [constant Mode.AUTHORED], validate
## [member authored_terrain].size() == width*height; (3) lay terrain —
## AUTHORED copies [member authored_terrain] verbatim, PROCEDURAL is Story
## 004 and currently always rejects; (4) validate [member hq_tiles] has
## exactly 2 distinct in-bounds, non-Impassable entries that are mutually
## reachable via [method _hqs_mutually_reachable]; (5) initialize occupancy to all-empty
## and place both HQs via [method GridState.place]; (6) return the built
## [GridState].
##
## On any rejection, logs a specific reason via [method @GlobalScope.push_error]
## and returns [code]null[/code] — this codebase has no [code]ActionResult[/code]-
## style failure type yet, so [code]null[/code] + a logged reason is the
## established convention until one exists. Never raises, never asserts.
##
## Deterministic: building the same [MapDefinition] twice yields
## byte-identical [member GridState.terrain] and [member GridState.occupancy]
## — no RNG runs anywhere in the AUTHORED branch. O(width*height).
## [codeblock]
## var grid_a := MapDefinition.build_grid(map_def)
## var grid_b := MapDefinition.build_grid(map_def)
## # grid_a.terrain == grid_b.terrain, grid_a.occupancy == grid_b.occupancy
## [/codeblock]
static func build_grid(map_def: MapDefinition) -> GridState:
	# 1. Validate dims.
	if map_def.width < MIN_DIM or map_def.width > MAX_DIM:
		push_error("MapDefinition.build_grid: width %d out of range [%d, %d]" % [map_def.width, MIN_DIM, MAX_DIM])
		return null
	if map_def.height < MIN_DIM or map_def.height > MAX_DIM:
		push_error("MapDefinition.build_grid: height %d out of range [%d, %d]" % [map_def.height, MIN_DIM, MAX_DIM])
		return null

	if map_def.mode == Mode.PROCEDURAL:
		push_error("MapDefinition.build_grid: Mode.PROCEDURAL is not yet implemented (Story 004)")
		return null

	if map_def.mode != Mode.AUTHORED:
		push_error("MapDefinition.build_grid: unrecognized mode %d" % map_def.mode)
		return null

	# 2. Validate authored_terrain size (AUTHORED branch, TR-grid-012).
	var tile_count: int = map_def.width * map_def.height
	if map_def.authored_terrain.size() != tile_count:
		push_error("MapDefinition.build_grid: authored_terrain.size() %d != width*height %d" % [map_def.authored_terrain.size(), tile_count])
		return null

	# 3. Lay terrain — AUTHORED copies verbatim.
	var terrain := PackedByteArray()
	terrain.resize(tile_count)
	for i: int in tile_count:
		terrain[i] = map_def.authored_terrain[i]

	# 4. Validate HQ tiles, then HQ-to-HQ reachability.
	if map_def.hq_tiles.size() != 2:
		push_error("MapDefinition.build_grid: hq_tiles must have exactly 2 entries, got %d" % map_def.hq_tiles.size())
		return null

	var hq_a: Vector2i = map_def.hq_tiles[0]
	var hq_b: Vector2i = map_def.hq_tiles[1]

	if hq_a == hq_b:
		push_error("MapDefinition.build_grid: hq_tiles must be two distinct tiles, both are %s" % [hq_a])
		return null

	for hq: Vector2i in [hq_a, hq_b]:
		if not _in_bounds(hq.x, hq.y, map_def.width, map_def.height):
			push_error("MapDefinition.build_grid: hq_tile %s is out of bounds for %dx%d board" % [hq, map_def.width, map_def.height])
			return null
		if terrain[_index(hq.x, hq.y, map_def.width)] == GridState.Terrain.IMPASSABLE:
			push_error("MapDefinition.build_grid: hq_tile %s sits on Impassable terrain" % [hq])
			return null

	if not _hqs_mutually_reachable(map_def.width, map_def.height, terrain, hq_a, hq_b):
		push_error("MapDefinition.build_grid: HQs %s and %s are not mutually reachable" % [hq_a, hq_b])
		return null

	# 5. Init occupancy, place HQs.
	var grid := GridState.new()
	grid.width = map_def.width
	grid.height = map_def.height
	grid.terrain = terrain
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(tile_count)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)

	# HQ entity ids: placeholder scheme (0, 1) until GameState-driven entity
	# allocation exists. Story 003 scope is grid construction only — a later
	# story wires real entity ids from GameState.next_entity_id.
	if not grid.place(0, hq_a.x, hq_a.y):
		push_error("MapDefinition.build_grid: failed to place HQ 0 at %s" % [hq_a])
		return null
	if not grid.place(1, hq_b.x, hq_b.y):
		push_error("MapDefinition.build_grid: failed to place HQ 1 at %s" % [hq_b])
		return null

	# 6. Return.
	return grid


## Pure, standalone BFS reachability validator (ADR-0005): floods from
## [param hq_a] over tiles whose terrain is not
## [constant GridState.Terrain.IMPASSABLE], 4-directionally (N/E/S/W), and
## reports whether [param hq_b] is visited. Operates on raw
## [param width]/[param height]/[param terrain] rather than a [GridState]
## instance so it has zero [GridState]/[MapDefinition] coupling and Story 004
## can reuse it unchanged for the Procedural self-correction loop. Pure,
## headless, deterministic, O(width*height) — no RNG, no engine dependency
## beyond [Vector2i] value math.
## [codeblock]
## var reachable := MapDefinition._hqs_mutually_reachable(
##         10, 8, terrain, Vector2i(1, 1), Vector2i(8, 6))
## [/codeblock]
static func _hqs_mutually_reachable(width: int, height: int, terrain: PackedByteArray, hq_a: Vector2i, hq_b: Vector2i) -> bool:
	if not _in_bounds(hq_a.x, hq_a.y, width, height) or not _in_bounds(hq_b.x, hq_b.y, width, height):
		return false
	if terrain[_index(hq_a.x, hq_a.y, width)] == GridState.Terrain.IMPASSABLE:
		return false
	if terrain[_index(hq_b.x, hq_b.y, width)] == GridState.Terrain.IMPASSABLE:
		return false
	if hq_a == hq_b:
		return true

	var visited := PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)

	var frontier: Array[Vector2i] = [hq_a]
	visited[_index(hq_a.x, hq_a.y, width)] = 1

	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for tile: Vector2i in frontier:
			var candidates: Array[Vector2i] = [
				Vector2i(tile.x, tile.y - 1), # N
				Vector2i(tile.x + 1, tile.y), # E
				Vector2i(tile.x, tile.y + 1), # S
				Vector2i(tile.x - 1, tile.y), # W
			]
			for candidate: Vector2i in candidates:
				if not _in_bounds(candidate.x, candidate.y, width, height):
					continue
				var idx: int = _index(candidate.x, candidate.y, width)
				if visited[idx] == 1:
					continue
				if terrain[idx] == GridState.Terrain.IMPASSABLE:
					continue
				visited[idx] = 1
				if candidate == hq_b:
					return true
				next_frontier.append(candidate)
		frontier = next_frontier

	return false


## Flat-array index helper mirroring [method GridState.index] — duplicated
## here (rather than depending on a [GridState] instance) because this
## function runs during grid *construction*, before a [GridState] exists.
static func _index(x: int, y: int, width: int) -> int:
	return y * width + x


## Bounds check mirroring [method GridState.in_bounds] — duplicated here for
## the same reason as [method _index]: no [GridState] instance exists yet
## during [method build_grid]'s validation steps.
static func _in_bounds(x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height
