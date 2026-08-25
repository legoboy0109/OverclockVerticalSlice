## Movement — static utility class for the reachable-tile search.
##
## Core-layer system per ADR-0009 (reachable-search / pathfinding strategy).
## Holds only pure/static functions that take a [GameState] explicitly — no
## instance fields of its own. Mirrors [AP]'s established static-utility
## shape (ADR-0006) and ADR-0002's verb-handler module conventions.
##
## Story 001 implements the read-only side of the contract: [method reachable]
## — a side-effect-free BFS-by-depth search over the passed [GameState], safe
## to call against the authoritative state or any [method GameState.clone].
## Story 002 adds [code]move()[/code]/[code]MoveAction[/code] wiring, AP spend,
## and grid occupancy mutation, sharing [method _cost_for_depth] verbatim via
## its own public [code]move_path_cost()[/code] forwarder (out of scope here).
##
## [b]Algorithm:[/b] plain BFS by depth, plus a closed-form length->cost
## conversion — not a priority-queue Dijkstra. Under the GDD's proven
## min-length == min-cost property (cost is a pure function of path length
## given a fixed starting [member UnitState.tiles_moved_this_turn]), the
## shortest path to a tile is always its cheapest path, so a tile only needs
## to be visited once, at the first (shallowest) BFS layer that reaches it.
## Each layer's cost is monotonically non-decreasing in depth, so expansion
## stops the instant a layer's cost exceeds [method GameState.current_ap] —
## nothing deeper is affordable. This shortcut is explicitly scoped to the
## current uniform-terrain ruleset (ADR-0009 Decision).
##
## Usage:
## [codeblock]
## var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
## for r in results:
##     print(r.tile, r.min_cost, r.is_surcharged)
## [/codeblock]
class_name Movement
extends RefCounted


## ReachableTile — one legal move destination returned by [method reachable].
##
## Inner class of [Movement]; not auto-registered as a global [code]class_name[/code]
## (GDScript inner-class limitation) — external references (tests, later the
## Command & Action Interface overlay) must use the [code]Movement.ReachableTile[/code]
## prefix.
class ReachableTile extends RefCounted:
	## The destination tile, in grid coordinates.
	var tile: Vector2i
	## The exact integer AP cost to reach and stop on [member tile] this turn.
	var min_cost: int
	## True iff the shortest path to [member tile] crosses the unit's
	## [member UnitTypeDef.soft_move_cap] at any step (per-depth, not inferred
	## from [member min_cost] alone).
	var is_surcharged: bool

	func _init(t: Vector2i, c: int, surcharged: bool) -> void:
		tile = t
		min_cost = c
		is_surcharged = surcharged


## Returns every tile [param unit] can legally reach and stop on this turn, at
## exact integer AP cost, honoring 4-directional traversal, friendly-unit
## pass-through (structures always block, even friendly ones), and the
## depth-dependent soft-move-cap surcharge. Pure, side-effect-free — safe to
## call against the authoritative [param state] or any [method GameState.clone]
## (AI lookahead). Recomputed fresh every call: a new [PackedInt32Array] is
## allocated per invocation, never cached or pooled (ADR-0009 — avoids a
## stale-depth-across-clones bug class).
##
## Visited/cost bookkeeping is a flat [PackedInt32Array] indexed
## [code]y * width + x[/code] (ADR-0003), never a [Dictionary]. Neighbor
## expansion uses [method _neighbors_in_fixed_order]'s explicit N->E->S->W
## order, never [method GridState.neighbors] (whose iteration order is not
## part of its contract — ADR-0009 Risks).
##
## O(frontier size) per call, bounded by the tiles within [param unit]'s
## current AP reach, not the full board (ADR-0009 Performance Implications).
##
## [b]Returns empty for BOTH "boxed in" and "cannot afford a single step"[/b] — the
## affordability cut below stops expansion before depth 1 when the mover has too
## little AP. Callers that need to tell those apart must ask
## [method reachable_ignoring_ap] as well; see its doc comment for why that
## distinction matters to a player.
##
## Usage:
## [codeblock]
## var results: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
## for r in results:
##     print(r.tile, r.min_cost, r.is_surcharged)
## [/codeblock]
static func reachable(state: GameState, unit: UnitState) -> Array[ReachableTile]:
	return _reachable_within(state, unit, state.current_ap(unit.owner))


## Every tile [param unit] could legally reach [b]if AP were no object[/b] — the
## same BFS as [method reachable] with the affordability cut removed.
##
## [b]Why this exists (2026-08-24).[/b] [method reachable] stops expanding the
## moment a depth costs more than the mover's current AP, so at 0 AP it returns an
## EMPTY array — indistinguishable from a unit that is genuinely boxed in by
## terrain, friendly bodies or the board edge. Every consumer that reads "empty
## means nowhere to go" was therefore telling a player with no AP that they had no
## route, which is a different problem with a different solution (end the turn vs.
## move something out of the way). Asking this question separately is the only way
## to tell the two apart.
##
## [b]Not a movement legality API.[/b] Nothing may commit a move off this result —
## it deliberately reports tiles the mover cannot pay for. It exists to answer
## "would this unit have anywhere to go with more AP?", and
## [method CommandFSM._move_entry] is its only intended caller. [method validate]
## remains the sole authority on whether a move is legal.
##
## O(board) worst case rather than O(AP reach), because there is no budget to stop
## it early. Call it only when [method reachable] has already come back empty —
## which is exactly when the distinction matters and when the common path has
## nothing to walk anyway.
static func reachable_ignoring_ap(state: GameState, unit: UnitState) -> Array[ReachableTile]:
	return _reachable_within(state, unit, _NO_AP_LIMIT)


## Sentinel budget meaning "do not stop for cost" — see
## [method reachable_ignoring_ap]. Negative because a real AP budget is never
## negative ([method AP.can_afford] rejects negative amounts outright).
const _NO_AP_LIMIT: int = -1


## The shared BFS behind [method reachable] and [method reachable_ignoring_ap].
##
## [param ap_budget] is the affordability ceiling: expansion stops at the first
## depth costing more than it. [constant _NO_AP_LIMIT] disables that stop entirely,
## leaving the visited set (and therefore the board) as the only bound.
##
## Extracted rather than duplicated so the two queries can never disagree about
## traversal, destination validity, neighbour order or surcharge depth — the four
## things a hand-copied second BFS would drift on first. The budget is read ONCE
## here instead of per-depth inside the loop, which is equivalent (nothing mutates
## [param state] mid-query) and marginally cheaper on the AI's hot path.
static func _reachable_within(state: GameState, unit: UnitState, ap_budget: int) -> Array[ReachableTile]:
	var grid: GridState = state.grid
	var w: int = grid.width
	var h: int = grid.height

	var visited_depth := PackedInt32Array()
	visited_depth.resize(w * h)
	visited_depth.fill(-1) # -1 = unvisited; fresh per call, no pooling.

	var start: Vector2i = unit.position
	visited_depth[grid.index(start.x, start.y)] = 0
	var frontier: Array[Vector2i] = [start]
	var results: Array[ReachableTile] = []
	var depth := 0

	while not frontier.is_empty():
		depth += 1
		var cost_at_depth: int = _cost_for_depth(unit, depth)
		if ap_budget != _NO_AP_LIMIT and cost_at_depth > ap_budget:
			break # Monotonic cost — nothing deeper is affordable.
		var surcharged: bool = _is_surcharged_at_depth(unit, depth)
		var next_frontier: Array[Vector2i] = []
		for pos: Vector2i in frontier:
			for n: Vector2i in _neighbors_in_fixed_order(grid, pos):
				var idx: int = grid.index(n.x, n.y)
				if visited_depth[idx] != -1:
					continue # Already settled at an equal-or-shallower depth.
				if not _is_traversable(state, n.x, n.y, unit.owner):
					continue
				visited_depth[idx] = depth
				next_frontier.append(n)
				if _is_valid_destination(state, n.x, n.y):
					results.append(ReachableTile.new(n, cost_at_depth, surcharged))
		frontier = next_frontier

	return results


## BFS expansion predicate — can a path CROSS this tile? False if out of
## bounds or [constant GridState.Terrain.IMPASSABLE]. An empty tile is always
## traversable. An occupied tile is traversable only when the occupant
## [code]is UnitState[/code] (checked via [code]is[/code], never
## [method Object.get_class]) and shares [param mover_owner] — friendly units
## pass through; every [code]StructureState[/code] (any owner) and every enemy
## [code]UnitState[/code] is a hard blocker (ADR-0009). O(1).
static func _is_traversable(state: GameState, x: int, y: int, mover_owner: int) -> bool:
	if not state.grid.in_bounds(x, y):
		return false
	if state.grid.terrain_at(x, y) == GridState.Terrain.IMPASSABLE:
		return false
	var occupant_id: int = state.grid.occupant_at(x, y)
	if occupant_id == GridState.EMPTY_OCCUPANT:
		return true
	var occupant: EntityState = state.entity_at(Vector2i(x, y))
	return occupant is UnitState and occupant.owner == mover_owner


## Destination-filter predicate — can a path STOP here? Reuses
## [method GridState.is_passable] verbatim: "terrain != Impassable and
## occupant is empty." Applied only when deciding whether to emit a result,
## never when deciding whether to expand through the tile (a friendly-occupied
## tile is traversable but excluded from the returned set). O(1).
static func _is_valid_destination(state: GameState, x: int, y: int) -> bool:
	return state.grid.is_passable(x, y)


## Returns the orthogonal in-bounds neighbors of [param pos], in an explicit
## fixed N->E->S->W order this search owns itself — never
## [method GridState.neighbors], whose iteration order is not pinned by its
## contract (ADR-0009 Risks). Determinism (the tie-break AC) depends on this
## order being self-contained here. O(4).
static func _neighbors_in_fixed_order(grid: GridState, pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n: Vector2i = pos + d
		if grid.in_bounds(n.x, n.y):
			out.append(n)
	return out


## The closed-form soft-move-cap cost summation for entering [param tiles_entered]
## tiles this turn, given [param unit]'s current
## [member UnitState.tiles_moved_this_turn]. The first
## [code]unit.type.soft_move_cap - unit.tiles_moved_this_turn[/code] tiles
## (floored at 0) cost [code]unit.type.move_cost[/code] each; every tile beyond
## costs the flat [method UnitConfig.surcharge_for] surcharge. Monotonically
## non-decreasing in [param tiles_entered] — the property [method reachable]'s
## early-break relies on. This exact function is reused verbatim by Story
## 002's [code]move_path_cost()[/code] billing — the reachable-vs-billed
## agreement invariant depends on there being exactly one implementation. O(1).
static func _cost_for_depth(unit: UnitState, tiles_entered: int) -> int:
	var c: int = unit.type.soft_move_cap
	var m: int = unit.tiles_moved_this_turn
	var t: int = tiles_entered
	var surcharge: int = UnitConfig.surcharge_for(unit.type.move_cost)
	var base_tiles: int = max(0, min(t, c - m))
	var overcap_tiles: int = t - base_tiles
	return base_tiles * unit.type.move_cost + overcap_tiles * surcharge


## Does a min-length path of [param depth] steps cross the soft cap at all?
## True iff [param depth] exceeds the number of remaining in-cap tiles
## ([code]max(0, soft_move_cap - tiles_moved_this_turn)[/code]) — a tile at
## exactly that boundary depth is not yet surcharged. O(1).
static func _is_surcharged_at_depth(unit: UnitState, depth: int) -> bool:
	return depth > max(0, unit.type.soft_move_cap - unit.tiles_moved_this_turn)


## The public forwarder for [method _cost_for_depth] — Story 002's billing
## entry point, sharing the exact same summation [method reachable] uses for
## its per-depth cost (the reachable-vs-billed agreement invariant depends on
## there being exactly one implementation; this call is the load-bearing part
## of that guarantee, ADR-0009 Implementation Notes). O(1).
static func move_path_cost(unit: UnitState, tiles_entered: int) -> int:
	return _cost_for_depth(unit, tiles_entered)


## [MoveAction]'s [code]validate()[/code] handler (ADR-0002 verb-handler
## contract) — pure, total, never mutates. Resolves the mover via
## [method GameState.entity_at]([member MoveAction.from]); rejects with
## [constant Action.Reason.NO_SUCH_ENTITY] if no entity is there, it is not a
## [UnitState], or it is not owned by [member Action.player]. Confirms
## [member MoveAction.to] is present in [method reachable]'s result set at
## [i]exactly[/i] the reported [member Movement.ReachableTile.min_cost] for
## [member MoveAction.tiles_entered] — a mismatch (stale/forged
## [code]tiles_entered[/code] that doesn't match the destination's true
## min-cost) rejects with [constant Action.Reason.ILLEGAL_TARGET], the same as
## an absent destination. Finally confirms [method AP.can_afford] for the
## computed cost, rejecting with [constant Action.Reason.CANT_AFFORD].
## Returns [constant Action.Reason.OK] only when every check passes.
static func validate(state: GameState, action: Action) -> int:
	# Typed as the base Action (the ADR-0002 dispatch contract calls every
	# handler with an Action; matching _validate_end_turn) — cast to MoveAction.
	var move: MoveAction = action as MoveAction
	var entity: EntityState = state.entity_at(move.from)
	if entity == null or not (entity is UnitState) or entity.owner != move.player:
		return Action.Reason.NO_SUCH_ENTITY
	var unit: UnitState = entity as UnitState

	var cost: int = move_path_cost(unit, move.tiles_entered)

	var destination: ReachableTile = null
	for r: ReachableTile in reachable(state, unit):
		if r.tile == move.to:
			destination = r
			break
	if destination == null or destination.min_cost != cost:
		return Action.Reason.ILLEGAL_TARGET

	if not AP.can_afford(state, unit.owner, cost):
		return Action.Reason.CANT_AFFORD

	return Action.Reason.OK


## [MoveAction]'s [code]apply()[/code] handler (ADR-0002 verb-handler
## contract) — assumes [method validate] already passed; never fails. Resolves
## the mover, computes [param action]'s exact cost via [method move_path_cost]
## (the same summation [method validate] used), then commits in order: (1)
## [method AP.spend] (ADR-0006 — sole AP deductor), (2)
## [method GridState.move] (ADR-0005 — sole occupancy mutator), (3)
## [member UnitState.position] update, (4)
## [member UnitState.tiles_moved_this_turn] increment — the cumulative counter
## [method reachable]/[method _cost_for_depth] read as their [code]m[/code]
## term, so a later move (same turn or a split multi-call move) bills
## correctly with no extra bookkeeping. Returns a single [UnitMovedEvent].
static func apply(state: GameState, action: Action) -> Array[Event]:
	# Base-Action signature per the ADR-0002 dispatch contract — cast to MoveAction.
	var move: MoveAction = action as MoveAction
	var unit: UnitState = state.entity_at(move.from) as UnitState
	var cost: int = move_path_cost(unit, move.tiles_entered)

	AP.spend(state, unit.owner, cost)
	state.grid.move(move.from, move.to)
	unit.position = move.to
	unit.tiles_moved_this_turn += move.tiles_entered
	# ★ 2026-08-25: acting clears the stand-down mark. It records "I am finished
	# with this one", and the player has visibly changed their mind — leaving it
	# set would keep the entity dim and skipped while it still had a turn left.
	unit.stood_down = false

	return [UnitMovedEvent.new(unit.entity_id, move.from, move.to, cost)] as Array[Event]
