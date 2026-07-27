## BaseProduction — static utility class for structure placement, building,
## start-of-turn timer advance, and the completed-outpost AP-income contract.
##
## Core-layer system per ADR-0017 (Base & Production Mechanics), Story 002
## (merged with former Story 003). Holds only pure/static functions that take
## [code]state[/code] explicitly — no instance fields of its own. Mirrors the
## verb-handler shape ADR-0002/0006 established for [code]AP[/code]/
## [code]Movement[/code]/[code]Combat[/code].
##
## [b]Scope so far (Story 002):[/b] [method legal_build_tiles] (ADR-0017 D3,
## live friendly-frontier + enemy-standoff query), the [BuildAction] verb
## handler ([method validate_build]/[method apply_build]), [method effective_build_cost]/
## [method effective_build_time] (ADR-0012 folds, == base under Neutral),
## [method advance_build_timers] (the concrete body of ADR-0008 step 3),
## [method completed_outpost_count] (the AP-income contract ADR-0006
## forward-declared, previously served by [code]base_production_stub.gd[/code]
## — deleted by this story), and [method defensive_attack_cost] (Combat's
## cross-system config read, ADR-0010/ADR-0017, unchanged behavior from the
## stub it replaces). Produce/deploy (Story 004) and cancel (Story 005) are
## out of scope here.
##
## Usage:
## [codeblock]
## var tiles: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.ECONOMY_OUTPOST)
## var n: int = BaseProduction.completed_outpost_count(state, 0)
## [/codeblock]
class_name BaseProduction
extends RefCounted


## The four fixed cardinal step offsets [method legal_build_tiles] scans, in
## this exact N->E->S->W order — mirrors [method Movement._neighbors_in_fixed_order]
## / [method Combat._CARDINAL_DIRECTIONS]'s established fixed-offset-order
## convention (ADR-0003 stable iteration), never [method GridState.neighbors]
## (whose iteration order is not pinned by its own contract).
const _CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), # N
	Vector2i(1, 0),  # E
	Vector2i(0, 1),  # S
	Vector2i(-1, 0), # W
]


## Returns every legal build tile for [param player] building [param structure_type]
## (ADR-0017 D3, TR-baseprod-005) — a pure, [b]live[/b] query, never cached
## (a destroyed enemy structure frees formerly-excluded tiles on the very next
## call). Candidate universe = passable, empty, in-bounds neighbours of
## [param player]'s OWN entities (units AND structures, scanned N->E->S->W),
## deduplicated via a transient membership [Dictionary] whose iteration order
## is [b]never observed[/b] — only the trailing [code]sort_custom(_by_tile_index)[/code]
## call below makes the returned order canonical (ADR-0003/ADR-0009
## determinism discipline; do not copy this Dictionary-as-set idiom into a
## context that returns/iterates it without a following sort). Each candidate
## is then filtered by [method _clears_enemy_standoff] (strict manhattan
## [code]> 2[/code] from EVERY enemy structure).
##
## The HQ is never a candidate: it is setup-placed, not a buildable
## [param structure_type] any caller offers here (Rule 2 / AC).
##
## [param structure_type] does not change placement legality in the VS (every
## buildable shares the same adjacency+standoff rule) — accepted for
## forward-compatibility and signature alignment with ADR-0011/0015's forward
## declarations; unused today.
##
## O(friendly_count * 4 * enemy_structure_count) — bounded and cheap
## (control-manifest Performance Guardrail); safe to recompute every preview
## frame.
static func legal_build_tiles(state: GameState, player: int, _structure_type: StructureTypeDef) -> Array[Vector2i]:
	var grid: GridState = state.grid
	var candidates: Dictionary = {} # Vector2i -> true, dedup ONLY — see doc above.
	for e: EntityState in _friendly_entities(state, player):
		for n: Vector2i in _neighbors_in_fixed_order(e.position):
			if grid.in_bounds(n.x, n.y) and grid.is_passable(n.x, n.y):
				candidates[n] = true
	var out: Array[Vector2i] = []
	for t: Vector2i in candidates:
		if _clears_enemy_standoff(state, player, t):
			out.append(t)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.index(a.x, a.y) < grid.index(b.x, b.y))
	return out


## Every one of [param player]'s own live entities (units AND structures) —
## the friendly-frontier source set [method legal_build_tiles] scans
## neighbours of. Stable [member EntityState.entity_id]-ascending order
## (ADR-0003) via [method GameState.entities], filtered to [param player].
static func _friendly_entities(state: GameState, player: int) -> Array[EntityState]:
	var out: Array[EntityState] = []
	for e: EntityState in state.entities():
		if e.owner == player:
			out.append(e)
	return out


## Returns the four cardinal-offset neighbours of [param pos] in fixed
## N->E->S->W order — bounds/passability are validated by the caller (mirrors
## [method Combat._walk_direction]'s and [method Movement._neighbors_in_fixed_order]'s
## own split of "generate offsets" vs "validate"). O(4).
static func _neighbors_in_fixed_order(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in _CARDINAL_DIRECTIONS:
		out.append(pos + d)
	return out


## True iff [param tile] is strictly more than 2 manhattan tiles from EVERY
## enemy (non-[param player]) [code]StructureState[/code] — the Rule 5
## standoff filter (ADR-0017 D3). A tile with zero enemy structures on the
## board trivially clears (vacuously true). O(enemy_structure_count).
static func _clears_enemy_standoff(state: GameState, player: int, tile: Vector2i) -> bool:
	for e: EntityState in state.entities():
		if e is StructureState and e.owner != player:
			if state.grid.manhattan_distance(tile, e.position) <= 2:
				return false
	return true


## [BuildAction]'s [code]validate()[/code] handler (ADR-0017, ADR-0002,
## TR-baseprod-004) — [b]pure and total[/b]: checks every failure condition,
## never mutates [param state]. Registered into [method GameState.register_verb]'s
## dispatch table by [method GameState._ensure_dispatch_registered].
##
## The builder is [param state]'s [member GameState.active_player] — a
## [BuildAction] carries no separate player field (mirrors how [param action].player
## is already gated to the active player by [method GameState.apply_action]'s
## step 2, before this handler ever runs).
##
## Checks, in order: (1) [method AP.can_afford] against
## [method effective_build_cost] ([constant Action.Reason.CANT_AFFORD]
## otherwise); (2) [param action].tile is present in [method legal_build_tiles]
## for the active player and [param action].structure_type
## ([constant Action.Reason.NOT_LEGAL_BUILD_TILE] otherwise).
##
## Idempotency (ADR-0002): re-running this against current state re-validates
## affordability and tile legality fresh every time — no dedup IDs, no
## seen-set. A tile that became illegal (occupied, or now within a fresh
## enemy structure's standoff) between preview and commit is caught here.
##
## O(1) affordability check plus one [method legal_build_tiles] call (already
## budgeted O(friendly_count * 4 * enemy_structure_count), control-manifest
## Performance Guardrail).
static func validate_build(state: GameState, action: BuildAction) -> int:
	var player: int = state.active_player
	var cost: int = effective_build_cost(state, action.structure_type, player)
	if not AP.can_afford(state, player, cost):
		return Action.Reason.CANT_AFFORD
	if not (action.tile in legal_build_tiles(state, player, action.structure_type)):
		return Action.Reason.NOT_LEGAL_BUILD_TILE
	return Action.Reason.OK


## [BuildAction]'s [code]apply()[/code] handler (ADR-0017 D1/D2, ADR-0002,
## TR-baseprod-004) — re-runs [method validate_build] first (idempotent
## commit re-validation, ADR-0002: a tile/affordability change between
## preview and commit is rejected here with [b]no mutation at all[/b], rather
## than trusting the caller's earlier preview-time check). Only after that
## re-validation passes does this mutate, atomically: (1) [method AP.spend]
## the [method effective_build_cost]; (2) construct a new [StructureState]
## ([member StructureState.type] = [param action].structure_type,
## [member StructureState.owner] = active player,
## [member StructureState.position] = [param action].tile,
## [member StructureState.current_hp] = [code]type.hp[/code],
## [member StructureState.build_status] = [constant StructureState.BuildStatus.UNDER_CONSTRUCTION],
## [member StructureState.build_turns_remaining] = [method effective_build_time]);
## (3) register it in [member GameState.entities_by_id] under a freshly
## allocated [member GameState.next_entity_id]; (4) [method GridState.place]
## it — occupancy is written [b]regardless of build status[/b] (ADR-0017 D2,
## no intangible-under-construction carve-out), so it blocks movement and is
## targetable the instant this commits; (5) append one placement event.
##
## Returns [code][][/code] (no event) on the defensive re-validation-failure
## path — the same "atomic, no partial mutation" guarantee
## [method GameState.apply_action]'s validate-before-mutate step already
## provides for a normal first-time commit; this only matters for a caller
## that invokes [method apply_build] directly without going through
## [method GameState.apply_action] (e.g. a test), so the re-validation is not
## bypassable.
##
## O(1) plus the cost of the internal [method validate_build] re-check
## (control-manifest Performance Guardrail).
static func apply_build(state: GameState, action: BuildAction) -> Array[Event]:
	if validate_build(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var cost: int = effective_build_cost(state, action.structure_type, player)
	AP.spend(state, player, cost)

	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = player
	structure.position = action.tile
	structure.type = action.structure_type
	structure.current_hp = action.structure_type.hp
	structure.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	structure.build_turns_remaining = effective_build_time(state, action.structure_type, player)

	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1
	# validate_build (re-run above) guarantees the tile is in legal_build_tiles,
	# i.e. in-bounds/passable/unoccupied — so place() cannot fail here. Assert it
	# loudly rather than silently discard the bool: a false return would mean a
	# legal_build_tiles/Grid desync leaving a half-committed structure (AP spent,
	# entity registered, event emitted) with no grid occupant. (Dev-only tripwire;
	# assert is stripped in release, matching this codebase's convention.)
	var placed: bool = state.grid.place(structure.entity_id, action.tile.x, action.tile.y)
	assert(placed, "BaseProduction.apply_build: Grid.place failed on a tile validate_build accepted — legal_build_tiles/Grid desync.")

	var evt := StructurePlacedEvent.new()
	evt.entity_id = structure.entity_id
	evt.structure_type = action.structure_type
	evt.owner = player
	evt.tile = action.tile
	return [evt] as Array[Event]


## The faction-folded AP cost to build [param structure_type] for [param player]
## (ADR-0012 B&P-owned [code]effective_X[/code] read site, TR-baseprod-007's
## sibling contract): [code]max(base + faction_delta, floor)[/code]. Under the
## VS's Neutral-only faction roster, [code]faction_delta == 0[/code] always,
## so this returns [param structure_type].build_cost verbatim — [b]exactly[/b]
## base, never a discounted value (Economy Tech does NOT route through this
## function; that hook was explicitly removed per ADR-0017/the story's
## regression-guard AC). Non-Neutral faction delta values are out of this
## story's scope (Faction epic).
static func effective_build_cost(_state: GameState, structure_type: StructureTypeDef, _player: int) -> int:
	return structure_type.build_cost


## The faction-folded number of owner-turns [param structure_type] takes to
## complete for [param player] (ADR-0012 B&P-owned [code]effective_X[/code]
## read site): [code]max(base + faction_delta, floor)[/code]. Under Neutral,
## [code]faction_delta == 0[/code], so this returns
## [param structure_type].build_time verbatim — exactly base. Non-Neutral
## faction delta values are out of this story's scope (Faction epic).
static func effective_build_time(_state: GameState, structure_type: StructureTypeDef, _player: int) -> int:
	return structure_type.build_time


## Advances [param player]'s build timers — the concrete body of ADR-0008
## step 3's forward-declared contract (ADR-0017 D1, TR-baseprod-006),
## replacing [code]base_production_stub.gd[/code]'s test-controllable stand-in.
## Iterates [param player]'s [constant StructureState.BuildStatus.UNDER_CONSTRUCTION]
## structures in stable [member EntityState.entity_id]-ascending order (via
## [method GameState.entities], ADR-0003), decrementing
## [member StructureState.build_turns_remaining] by 1; any structure reaching
## 0 flips to [constant StructureState.BuildStatus.COMPLETED] and this appends
## one [StructureCompletedEvent] for it. Batch-safe: multiple structures
## completing in the same call each get their own event, all within this one
## pass.
##
## Reads no income state — stays commutative with
## [code]Research.advance_research_timers[/code] (ADR-0008's explicit
## same-turn joint-completion order-independence requirement); called only
## from [method GameState.start_turn]'s step 3, strictly before step 4's AP
## income snapshot (owned/sequenced by ADR-0008, not this function).
##
## O(entity count) — one filtered, stable-order pass over [param player]'s
## entities (control-manifest Performance Guardrail); runs once per player
## per turn, never per-frame.
static func advance_build_timers(state: GameState, player: int) -> Array[Event]:
	var events: Array[Event] = []
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var structure: StructureState = e
		if structure.build_status != StructureState.BuildStatus.UNDER_CONSTRUCTION:
			continue
		structure.build_turns_remaining -= 1
		if structure.build_turns_remaining <= 0:
			structure.build_status = StructureState.BuildStatus.COMPLETED
			var evt := StructureCompletedEvent.new()
			evt.entity_id = structure.entity_id
			evt.structure_type = structure.type
			evt.owner = structure.owner
			evt.tile = structure.position
			events.append(evt)
	return events


## The AP-income contract (ADR-0006 forward-declared, TR-baseprod-007) —
## replaces [code]base_production_stub.gd[/code]'s test-controllable stand-in;
## [code]AP.ap_income_breakdown[/code] calls this cross-system exactly as it
## called the stub. Counts [param player]'s alive, owned structures where
## [member StructureState.type] [code]==[/code] [constant StructureTypes.ECONOMY_OUTPOST]
## (Resource-reference identity, never a string/enum compare) AND
## [member StructureState.build_status] [code]==[/code]
## [constant StructureState.BuildStatus.COMPLETED]. Excludes: opponent-owned,
## Under-Construction, destroyed (not in [member GameState.entities_by_id] —
## "alive" is defined by presence, ADR-0017 D1), the HQ, Production Outposts,
## Research Labs, and Defensive Structures. Returns [code]0[/code], never
## [code]null[/code], when nothing qualifies.
##
## O(entity count) — a single pass over [param state]'s entities
## (control-manifest Performance Guardrail); called once per player per turn
## via [code]AP.reset_turn[/code] (ADR-0008 step 4), never per-frame.
static func completed_outpost_count(state: GameState, player: int) -> int:
	var count: int = 0
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var structure: StructureState = e
		if structure.type == StructureTypes.ECONOMY_OUTPOST and structure.build_status == StructureState.BuildStatus.COMPLETED:
			count += 1
	return count


## The AP cost a Defensive Structure attacker spends per [method Combat.apply]
## (ADR-0010/ADR-0017, TR-combat-012) — replaces
## [code]base_production_stub.gd[/code]'s test-controllable stand-in;
## [code]Combat._attack_cost_for[/code] calls this cross-system exactly as it
## called the stub. Reads [member BaseProductionConfig.defensive_attack_cost]
## (Story 001's config) via the [code]StructureBalance[/code] Autoload — never
## a hardcoded literal. O(1).
static func defensive_attack_cost() -> int:
	return StructureBalance.base_production.defensive_attack_cost
