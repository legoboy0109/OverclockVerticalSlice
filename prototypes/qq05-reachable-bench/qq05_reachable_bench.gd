# QQ-05 performance spike -- ADR-0009 (reachable-search pathfinding).
#
# Throwaway benchmark, NOT a GdUnit4 test. Run headless:
#   ./redot --headless --script prototypes/spikes/qq05_reachable_bench.gd
#
# Purpose: produce a concrete ms/call number for Movement.reachable() on the
# ADR-0009 worst-case board (24x24) so ADR-0009 can move Proposed -> Accepted.
#
# This is a faithful, self-contained port of ADR-0009's algorithm shape:
#   - plain BFS-by-depth (not priority-queue Dijkstra)
#   - fresh-per-call PackedInt32Array visited_depth, flat index = y*w+x
#   - fixed N->E->S->W neighbor expansion order
#   - closed-form depth->cost via _cost_for_depth (soft_move_cap surcharge)
#   - monotonic early-exit the instant a depth's cost exceeds current_ap
#
# src/ does not yet contain GridState/GameState/UnitState (ADR-0009 is still
# Proposed, Movement System epic is blocked on Accept) -- so this spike uses
# minimal stand-in structures (flat terrain/occupant arrays, a UnitStub) that
# mirror the ADR's data shapes closely enough to measure the real algorithm's
# cost. No caching, no pooling, no shortcuts beyond what the ADR describes.
extends SceneTree

const BOARD_W := 24
const BOARD_H := 24
const WARMUP_CALLS := 200
const TIMED_CALLS := 10000
const FRAME_BUDGET_US := 16600.0  # 16.6ms in microseconds

# -----------------------------------------------------------------------
# Stand-in grid: flat arrays, same indexing convention as ADR-0005/ADR-0009.
# -----------------------------------------------------------------------
class GridStub:
	var width: int
	var height: int
	var terrain: PackedInt32Array   # 0 = passable, 1 = impassable
	var occupant_owner: PackedInt32Array  # -1 = empty, else owner id

	func _init(w: int, h: int) -> void:
		width = w
		height = h
		terrain = PackedInt32Array()
		terrain.resize(w * h)
		terrain.fill(0)
		occupant_owner = PackedInt32Array()
		occupant_owner.resize(w * h)
		occupant_owner.fill(-1)

	func index(x: int, y: int) -> int:
		return y * width + x

	func in_bounds(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < width and y < height

	func is_passable(x: int, y: int) -> bool:
		var idx := index(x, y)
		return terrain[idx] == 0 and occupant_owner[idx] == -1


class UnitStub:
	var position: Vector2i
	var owner: int
	var move_cost: int
	var soft_move_cap: int
	var tiles_moved_this_turn: int

	func _init(pos: Vector2i, mover_owner: int, mc: int, cap: int, moved: int = 0) -> void:
		position = pos
		owner = mover_owner
		move_cost = mc
		soft_move_cap = cap
		tiles_moved_this_turn = moved


class ReachableTile:
	var tile: Vector2i
	var min_cost: int
	var is_surcharged: bool

	func _init(t: Vector2i, c: int, surcharged: bool) -> void:
		tile = t
		min_cost = c
		is_surcharged = surcharged


const SOFT_MOVE_PENALTY_X10 := 20  # 2.0 fixed-point, per GDD default


static func surcharge_for(move_cost: int) -> int:
	return (move_cost * SOFT_MOVE_PENALTY_X10 + 9) / 10  # integer ceil-division


static func _cost_for_depth(unit: UnitStub, tiles_entered: int) -> int:
	var c: int = unit.soft_move_cap
	var m: int = unit.tiles_moved_this_turn
	var t: int = tiles_entered
	var surcharge: int = surcharge_for(unit.move_cost)
	var base_tiles: int = max(0, min(t, c - m))
	var overcap_tiles: int = t - base_tiles
	return base_tiles * unit.move_cost + overcap_tiles * surcharge


static func _is_surcharged_at_depth(unit: UnitStub, depth: int) -> bool:
	return depth > max(0, unit.soft_move_cap - unit.tiles_moved_this_turn)


static func _is_traversable(grid: GridStub, x: int, y: int, mover_owner: int) -> bool:
	if not grid.in_bounds(x, y):
		return false
	var idx := grid.index(x, y)
	if grid.terrain[idx] == 1:
		return false
	var occ := grid.occupant_owner[idx]
	if occ == -1:
		return true
	return occ == mover_owner  # friendly-unit pass-through; enemy/structure blocks


static func _is_valid_destination(grid: GridStub, x: int, y: int) -> bool:
	return grid.is_passable(x, y)


static func _neighbors_in_fixed_order(grid: GridStub, pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for d in offsets:
		var n: Vector2i = pos + d
		if grid.in_bounds(n.x, n.y):
			out.append(n)
	return out


# Faithful port of ADR-0009's Movement.reachable(). Fresh-per-call, no cache.
static func reachable(grid: GridStub, unit: UnitStub, current_ap: int) -> Array[ReachableTile]:
	var w: int = grid.width
	var h: int = grid.height
	var visited_depth := PackedInt32Array()
	visited_depth.resize(w * h)
	visited_depth.fill(-1)

	var start: Vector2i = unit.position
	visited_depth[grid.index(start.x, start.y)] = 0
	var frontier: Array[Vector2i] = [start]
	var results: Array[ReachableTile] = []
	var depth := 0

	while not frontier.is_empty():
		depth += 1
		var cost_at_depth := _cost_for_depth(unit, depth)
		if cost_at_depth > current_ap:
			break
		var surcharged := _is_surcharged_at_depth(unit, depth)
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for n in _neighbors_in_fixed_order(grid, pos):
				var idx := grid.index(n.x, n.y)
				if visited_depth[idx] != -1:
					continue
				if not _is_traversable(grid, n.x, n.y, unit.owner):
					continue
				visited_depth[idx] = depth
				next_frontier.append(n)
				if _is_valid_destination(grid, n.x, n.y):
					results.append(ReachableTile.new(n, cost_at_depth, surcharged))
		frontier = next_frontier

	return results


# -----------------------------------------------------------------------
# Board generation
# -----------------------------------------------------------------------
static func make_board(w: int, h: int, obstacle_density: float, seed_value: int) -> GridStub:
	var grid := GridStub.new(w, h)
	if obstacle_density <= 0.0:
		return grid
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var center := Vector2i(w / 2, h / 2)
	for y in range(h):
		for x in range(w):
			if Vector2i(x, y) == center:
				continue  # keep the unit's own start tile clear
			if rng.randf() < obstacle_density:
				grid.terrain[grid.index(x, y)] = 1
	return grid


# -----------------------------------------------------------------------
# Scenario definitions -- GDD-sourced archetypes (movement-system.md):
#   Scout   move_cost 1, soft_move_cap 4
#   Trooper move_cost 2, soft_move_cap 3
#   Heavy   move_cost 3, soft_move_cap 2
#   Sniper  move_cost 2, soft_move_cap 3
# -----------------------------------------------------------------------
class Scenario:
	var label: String
	var move_cost: int
	var soft_move_cap: int
	var current_ap: int
	var obstacle_density: float

	func _init(l: String, mc: int, cap: int, ap: int, density: float) -> void:
		label = l
		move_cost = mc
		soft_move_cap = cap
		current_ap = ap
		obstacle_density = density


static func build_scenarios() -> Array[Scenario]:
	var s: Array[Scenario] = []
	s.append(Scenario.new("Scout   (mc1 cap4) AP10  0% obstacles", 1, 4, 10, 0.0))
	s.append(Scenario.new("Scout   (mc1 cap4) AP10 20% obstacles", 1, 4, 10, 0.2))
	s.append(Scenario.new("Trooper (mc2 cap3) AP10  0% obstacles", 2, 3, 10, 0.0))
	s.append(Scenario.new("Trooper (mc2 cap3) AP10 20% obstacles", 2, 3, 10, 0.2))
	s.append(Scenario.new("Heavy   (mc3 cap2) AP10  0% obstacles", 3, 2, 10, 0.0))
	s.append(Scenario.new("Heavy   (mc3 cap2) AP10 20% obstacles", 3, 2, 10, 0.2))
	s.append(Scenario.new("Sniper  (mc2 cap3) AP10  0% obstacles", 2, 3, 10, 0.0))
	s.append(Scenario.new("Sniper  (mc2 cap3) AP10 20% obstacles", 2, 3, 10, 0.2))
	# Worst-case row: maxed AP, cheapest move_cost, no obstacles -- forces the
	# frontier to saturate most/all of the open 24x24 board. This is the true
	# upper bound on frontier size and the number ADR-0009 most needs to cite.
	s.append(Scenario.new("WORST-CASE Scout (mc1 cap4) AP99  0% obstacles (full-board saturation)", 1, 4, 99, 0.0))
	return s


# -----------------------------------------------------------------------
# Timing harness
# -----------------------------------------------------------------------
func _run_scenario(sc: Scenario) -> void:
	var grid := make_board(BOARD_W, BOARD_H, sc.obstacle_density, 12345)
	var center := Vector2i(BOARD_W / 2, BOARD_H / 2)
	var unit := UnitStub.new(center, 0, sc.move_cost, sc.soft_move_cap, 0)

	# Warm up -- discard timings, let any JIT/allocator warmup settle.
	var warm_result_size := 0
	for i in range(WARMUP_CALLS):
		var r := reachable(grid, unit, sc.current_ap)
		warm_result_size = r.size()

	# Timed run -- one reachable() call per iteration, individually timed.
	var durations_us := PackedInt64Array()
	durations_us.resize(TIMED_CALLS)
	var result_size := 0
	for i in range(TIMED_CALLS):
		var t0 := Time.get_ticks_usec()
		var r := reachable(grid, unit, sc.current_ap)
		var t1 := Time.get_ticks_usec()
		durations_us[i] = t1 - t0
		result_size = r.size()

	_report(sc, durations_us, result_size)


func _report(sc: Scenario, durations_us: PackedInt64Array, result_size: int) -> void:
	var sorted_us := durations_us.duplicate()
	sorted_us.sort()

	var total: int = 0
	for v in sorted_us:
		total += v
	var mean_us: float = float(total) / sorted_us.size()
	var min_us: int = sorted_us[0]
	var max_us: int = sorted_us[sorted_us.size() - 1]
	var p50_us: int = sorted_us[int(sorted_us.size() * 0.50)]
	var p95_us: int = sorted_us[int(sorted_us.size() * 0.95)]
	var p99_us: int = sorted_us[int(sorted_us.size() * 0.99)]

	var calls_per_frame: float = FRAME_BUDGET_US / mean_us

	print("--------------------------------------------------------------------")
	print("Scenario: %s" % sc.label)
	print("  reachable tiles returned: %d" % result_size)
	print("  calls timed: %d (after %d warmup calls, discarded)" % [TIMED_CALLS, WARMUP_CALLS])
	print("  min:  %d us" % min_us)
	print("  mean: %.2f us" % mean_us)
	print("  p50:  %d us" % p50_us)
	print("  p95:  %d us" % p95_us)
	print("  p99:  %d us" % p99_us)
	print("  max:  %d us" % max_us)
	print("  calls per 16.6ms frame (at mean cost): %.1f" % calls_per_frame)


func _initialize() -> void:
	print("======================================================================")
	print("QQ-05 reachable() performance spike -- ADR-0009")
	print("Board: %dx%d | Warmup: %d calls | Timed: %d calls/scenario" % [BOARD_W, BOARD_H, WARMUP_CALLS, TIMED_CALLS])
	print("Algorithm: BFS-by-depth, fresh-per-call PackedInt32Array visited_depth,")
	print("fixed N->E->S->W neighbor order, closed-form soft-cap cost -- per ADR-0009.")
	print("======================================================================")

	var scenarios := build_scenarios()
	for sc in scenarios:
		_run_scenario(sc)

	print("--------------------------------------------------------------------")
	print("Done.")
	quit()
