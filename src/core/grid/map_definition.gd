## MapDefinition — the standalone-loadable map-authoring format.
##
## Foundation-layer data model per ADR-0005. A `.tres` [Resource] describing
## either an Authored (hand-placed terrain) or Procedural (seeded generation)
## map. [method build_grid] is the sole [GridState] constructor: it consumes
## a [MapDefinition] and runs the fixed validate -> lay-terrain -> validate-
## reachability -> init-occupancy pipeline, returning a ready-to-play
## [GridState] or [code]null[/code] on rejection.
##
## Story 003 implemented the AUTHORED branch of [method build_grid]. Story 004
## implements [code]Mode.PROCEDURAL[/code] via [method generate_procedural]:
## a dedicated seeded [RandomNumberGenerator] ([member proc_seed]) places
## Cover/Impassable features in a central band, mirrors them if
## [member proc_symmetric], and self-corrects HQ-to-HQ reachability by
## thinning Impassable features in a fixed, seed-stable order — never by
## re-rolling. See [method generate_procedural] for the full contract.
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

## Seed for procedural generation, consumed by [method generate_procedural]
## via a dedicated [RandomNumberGenerator] instance — never the engine's
## global RNG (ADR-0003 Rule 1).
@export var proc_seed: int

## Width (in tiles) of the central feature band, perpendicular to the
## HQ-to-HQ axis. [code]>= min(width, height)[/code] clamps to whole-board
## scatter. See [method generate_procedural].
@export var proc_band_width: int

## Feature density as a scaled integer (30 = 0.30), per ADR-0003 Rule 2. See
## [method generate_procedural].
@export var proc_density_x100: int

## Cover-vs-Impassable feature split as a scaled integer (70 = 0.70 Cover
## share), per ADR-0003 Rule 2. See [method generate_procedural].
@export var proc_feature_mix_x100: int

## Whether procedural features mirror across the board center. See
## [method generate_procedural].
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
## AUTHORED copies [member authored_terrain] verbatim, PROCEDURAL delegates to
## [method generate_procedural]; (4) validate [member hq_tiles] has
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
## — the AUTHORED branch runs no RNG at all, and the PROCEDURAL branch's
## [method generate_procedural] draws exclusively from a dedicated seeded
## [RandomNumberGenerator] ([member proc_seed]), never the engine's global RNG
## (ADR-0003 Rule 1). O(width*height) for AUTHORED; PROCEDURAL adds
## [method generate_procedural]'s cost (see its doc comment).
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

	var tile_count: int = map_def.width * map_def.height
	var terrain := PackedByteArray()

	# 2-3. Lay terrain — AUTHORED copies verbatim; PROCEDURAL generates.
	if map_def.mode == Mode.AUTHORED:
		# Validate authored_terrain size (TR-grid-012).
		if map_def.authored_terrain.size() != tile_count:
			push_error("MapDefinition.build_grid: authored_terrain.size() %d != width*height %d" % [map_def.authored_terrain.size(), tile_count])
			return null
		terrain.resize(tile_count)
		for i: int in tile_count:
			terrain[i] = map_def.authored_terrain[i]
	elif map_def.mode == Mode.PROCEDURAL:
		terrain = generate_procedural(map_def)
	else:
		push_error("MapDefinition.build_grid: unrecognized mode %d" % map_def.mode)
		return null

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


## Generates Procedural Center terrain (ADR-0005, TR-grid-009/-010/-011/-012):
## a central band of Cover/Impassable features around the board's midline,
## with a deterministic self-correcting reachability pass. Returns a
## [code]width*height[/code] [PackedByteArray] of [enum GridState.Terrain]
## values — never [code]null[/code]; an all-[constant GridState.Terrain.PLAIN]
## board is always reachable given [method build_grid] has already rejected
## out-of-bounds/Impassable-sitting HQs by the time this could matter, so
## thinning always converges.
##
## [b]Determinism (the whole point of this story)[/b]: every random draw comes
## from one dedicated [RandomNumberGenerator] instance seeded with
## [member proc_seed] — never the engine's global [code]randi()[/code]/
## [code]randf()[/code] family (ADR-0003 Rule 1, banned project-wide). Three
## things are fixed, seed-independent, and stable across runs so the seeded
## draws always line up the same way against the same structure:
## [br]1. the candidate tile list is built in ascending flat-index
## ([code]y*width+x[/code]) order before any RNG runs;
## [br]2. that list is Fisher-Yates shuffled in place using
## [code]rng.randi_range[/code] (index [code]n-1[/code] down to [code]1[/code]) —
## the classic in-place shuffle, so draw order is a pure function of list
## length; the first [code]count[/code] shuffled entries are selected, then
## each selected tile draws one more [code]rng.randi_range(0, 99)[/code] to
## decide Cover vs Impassable, in shuffle order;
## [br]3. the self-correction thinning pass (below) walks ascending flat index
## and involves no RNG at all — it is a pure function of the already-generated
## layout.
## No re-roll ever happens: on a reachability failure, features are removed
## (never re-picked) until the BFS passes, or every candidate feature in the
## band has been thinned (the density clamp), which is logged via
## [method @GlobalScope.push_error] and never emits an unplayable map.
##
## Algorithm:
## [br]1. Start all-Plain.
## [br]2. Compute the candidate band: if [member proc_band_width] is
## [code]>= min(width, height)[/code], the candidate set is the whole board
## (clamped to whole-board scatter, TR-grid-012's band-clamp AC). Otherwise
## the band is centered on the board and oriented perpendicular to the
## HQ-to-HQ axis: if the two [member hq_tiles] differ more in [code]x[/code]
## than [code]y[/code], the band is a vertical strip of columns (perpendicular
## to a mostly-horizontal HQ axis); otherwise (including an exact tie) it is a
## horizontal strip of rows. [member hq_tiles] and [member deploy_tiles] tiles
## are excluded from the candidate set entirely — a feature is never placed on
## them.
## [br]3. Select [code]candidates.size() * proc_density_x100 / 100[/code]
## (integer division) tiles via the seeded shuffle-and-take above.
## [member proc_feature_mix_x100] is the Cover share: each selected tile
## becomes Cover if its draw is [code]< proc_feature_mix_x100[/code], else
## Impassable.
## [br]4. If [member proc_symmetric], every selected tile's feature is mirrored
## onto its counterpart across the board center: across the vertical midline
## for a vertical band, the horizontal midline for a horizontal band, or a
## 180-degree point reflection for the whole-board-scatter case. The mirror
## write is skipped (not forced) if the mirror tile is the tile itself, or is
## an excluded HQ/deploy tile — exclusions always win over symmetry.
## [br]5. Self-correct: run [method _hqs_mutually_reachable]; on failure, scan
## ascending flat index for the first remaining Impassable feature tile, set
## it (and its symmetric partner, if any) back to Plain, and re-test. Repeat
## until reachable or every feature is thinned.
## [codeblock]
## var terrain := MapDefinition.generate_procedural(map_def)
## # terrain.size() == map_def.width * map_def.height
## # generate_procedural(map_def) called again returns a byte-identical array
## [/codeblock]
static func generate_procedural(map_def: MapDefinition) -> PackedByteArray:
	var width: int = map_def.width
	var height: int = map_def.height
	var tile_count: int = width * height

	var terrain := PackedByteArray()
	terrain.resize(tile_count)
	terrain.fill(GridState.Terrain.PLAIN)

	var rng := RandomNumberGenerator.new()
	rng.seed = map_def.proc_seed

	# Excluded set: HQ tiles + deploy tiles, membership-only (never iterated),
	# so Dictionary insertion order has zero influence on determinism.
	var excluded: Dictionary = {}
	for hq: Vector2i in map_def.hq_tiles:
		excluded[hq] = true
	for deploy: Vector2i in map_def.deploy_tiles:
		excluded[deploy] = true

	# Band orientation: whole-board scatter if the band clamps to >= the
	# smaller dimension; otherwise perpendicular to the HQ-to-HQ axis.
	var whole_board: bool = map_def.proc_band_width >= mini(width, height)
	var vertical_band: bool = false
	if not whole_board and map_def.hq_tiles.size() == 2:
		var hq_a: Vector2i = map_def.hq_tiles[0]
		var hq_b: Vector2i = map_def.hq_tiles[1]
		# Differ more in x => HQ axis is mostly horizontal => band is vertical
		# (a strip of columns). Ties default to a horizontal band (rows).
		vertical_band = absi(hq_a.x - hq_b.x) > absi(hq_a.y - hq_b.y)

	# Candidate list, fixed ascending flat-index order (pre-RNG).
	var candidates: Array[Vector2i] = []
	if whole_board:
		for y: int in height:
			for x: int in width:
				var tile := Vector2i(x, y)
				if not excluded.has(tile):
					candidates.append(tile)
	elif vertical_band:
		var band_w: int = map_def.proc_band_width
		var x_start: int = (width - band_w) / 2
		var x_end: int = x_start + band_w # exclusive
		for y: int in height:
			for x: int in range(maxi(0, x_start), mini(width, x_end)):
				var tile := Vector2i(x, y)
				if not excluded.has(tile):
					candidates.append(tile)
	else:
		var band_h: int = map_def.proc_band_width
		var y_start: int = (height - band_h) / 2
		var y_end: int = y_start + band_h # exclusive
		for y: int in range(maxi(0, y_start), mini(height, y_end)):
			for x: int in width:
				var tile := Vector2i(x, y)
				if not excluded.has(tile):
					candidates.append(tile)

	# Deterministic seeded selection: in-place Fisher-Yates shuffle, then take
	# the first `count` entries. Draw order is a pure function of list length.
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var count: int = candidates.size() * map_def.proc_density_x100 / 100

	# Mirror axis matching the band orientation (point reflection for
	# whole-board scatter, since there is no single band axis).
	var mirror_of := func(tile: Vector2i) -> Vector2i:
		if whole_board:
			return Vector2i(width - 1 - tile.x, height - 1 - tile.y)
		elif vertical_band:
			return Vector2i(width - 1 - tile.x, tile.y)
		else:
			return Vector2i(tile.x, height - 1 - tile.y)

	for i: int in count:
		var tile: Vector2i = candidates[i]
		var draw: int = rng.randi_range(0, 99)
		var feature: int = GridState.Terrain.COVER if draw < map_def.proc_feature_mix_x100 else GridState.Terrain.IMPASSABLE
		terrain[_index(tile.x, tile.y, width)] = feature

		if map_def.proc_symmetric:
			var mirror: Vector2i = mirror_of.call(tile)
			if mirror != tile and not excluded.has(mirror):
				terrain[_index(mirror.x, mirror.y, width)] = feature

	# Reachability self-correction: no re-roll, ever. Thin Impassable features
	# in fixed ascending flat-index order and re-test until connected, or
	# until every feature has been thinned (the density clamp).
	if map_def.hq_tiles.size() == 2:
		var hq_a: Vector2i = map_def.hq_tiles[0]
		var hq_b: Vector2i = map_def.hq_tiles[1]
		while not _hqs_mutually_reachable(width, height, terrain, hq_a, hq_b):
			var thinned_this_pass: bool = false
			for idx: int in tile_count:
				if terrain[idx] == GridState.Terrain.IMPASSABLE:
					terrain[idx] = GridState.Terrain.PLAIN
					if map_def.proc_symmetric:
						var idx_x: int = idx % width
						var idx_y: int = idx / width
						var mirror: Vector2i = mirror_of.call(Vector2i(idx_x, idx_y))
						var mirror_idx: int = _index(mirror.x, mirror.y, width)
						if terrain[mirror_idx] == GridState.Terrain.IMPASSABLE:
							terrain[mirror_idx] = GridState.Terrain.PLAIN
					thinned_this_pass = true
					break
			if not thinned_this_pass:
				# Density-clamp backstop (ADR-0005 TR-grid-012: never emit an
				# unplayable map). This is defensive: under the current invariants
				# it is unreachable, because generation starts all-Plain and never
				# places a feature on an HQ/deploy tile (they're excluded from the
				# candidate set), so once every Impassable feature is thinned the
				# board is entirely Plain+Cover — and Cover is passable — leaving
				# the two (in-bounds, non-Impassable, distinct) HQs trivially
				# connected. It is kept as a guarantee should those invariants ever
				# change (e.g. mutable terrain, HQ tiles allowed on features).
				# Never re-roll; proceed with the fully-thinned (all-Plain) band.
				push_error("MapDefinition.generate_procedural: density clamp — HQs %s/%s still unreachable after fully thinning Impassable features; proceeding with an all-Plain band" % [hq_a, hq_b])
				break

	return terrain


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
