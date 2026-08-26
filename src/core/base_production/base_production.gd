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
## and [method defensive_attack_cost] (Combat's
## cross-system config read, ADR-0010/ADR-0017, unchanged behavior from the
## stub it replaces).
##
## [b]Scope added (Story 004):[/b] [method legal_deploy_tiles] (ADR-0017 D4,
## empty/passable/in-bounds manhattan==1 deploy frontier), the [ProduceAction]
## verb handler ([method validate_produce]/[method apply_produce]), and
## [method effective_production_cap] (the ADR-0012 two-sided cap fold, == base
## under Neutral).
##
## [b]Scope added (Story 005):[/b] [method cancel_refund] (fixed-point integer
## refund math, ADR-0017 D6) and the [CancelBuildAction] verb handler
## ([method validate_cancel]/[method apply_cancel]) — the voluntary terminal
## exit for an under-construction structure (credits refund AP, clears the grid,
## erases the entity). Combat-destruction's terminal exit ([code]destroy_entity[/code],
## ADR-0010) is a separate path that never refunds.
##
## Usage:
## [codeblock]
## var tiles: Array[Vector2i] = BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
## var n: int = BaseProduction.structure_count(state, 0, StructureTypes.BARRACKS)
## [/codeblock]
##
## ⚠ [b]`completed_outpost_count()` was retired in S7-06.[/b] It counted COMPLETED Factories
## for ADR-0006's AP-income contract, and S6-01 re-based income on research tiers — after which
## nothing in `src/` called it for two sprints. [method structure_count] is the nearest
## replacement but is [b]not[/b] a drop-in: it ignores
## [member StructureState.build_status], so a caller that genuinely needs "completed only"
## must filter for it.
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
## call).
##
## ⚠ [b]The candidate universe narrowed on 2026-08-25[/b] (user decision): it used
## to be the neighbours of every entity the player owned, because Build was a
## player-level command with no unit behind it. It is now the neighbours of the
## player's BUILDERS only — see [method legal_build_tiles_for], which is the real
## rule. This union form answers "could this player build anywhere?", which is what
## a menu's grey-out and the AI's affordability gate need; it must NOT be used to
## validate a commit, because it accepts tiles beside a builder other than the one
## acting. With no living Builder it correctly returns empty.
##
## Candidate universe = passable, empty, in-bounds neighbours of
## [param player]'s own Builders (scanned N->E->S->W),
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
	return _sorted_build_tiles(state, player, builders_of(state, player))


## Every legal build tile for ONE [param builder] — the tiles that unit could
## actually raise a structure on right now (`base-production.md` CR-5, user
## decision 2026-08-25).
##
## ★ [b]This is the authoritative placement rule[/b]; [method legal_build_tiles] is
## the union of it across a player's Builders, kept so that "can this player build
## anything at all?" stays one cheap call for menus and the AI's affordability gate.
## Commit-time validation always goes through THIS function, because the union
## would happily accept a tile beside a DIFFERENT builder than the one acting.
##
## Returns empty for a null unit or one whose type cannot build
## ([member UnitTypeDef.can_build]) — an ordinary answer, not an error: most units
## cannot build, and asking is how the menu learns to grey the row out.
static func legal_build_tiles_for(state: GameState, builder: UnitState) -> Array[Vector2i]:
	if builder == null or builder.type == null or not builder.type.can_build:
		return [] as Array[Vector2i]
	return _sorted_build_tiles(state, builder.owner, [builder] as Array[UnitState])


## Every live [UnitState] of [param player] whose type can build, in stable
## [member EntityState.entity_id]-ascending order (ADR-0003 determinism).
static func builders_of(state: GameState, player: int) -> Array[UnitState]:
	var out: Array[UnitState] = []
	for e: EntityState in state.entities():
		if e is UnitState and e.owner == player and e.type != null and e.type.can_build:
			out.append(e as UnitState)
	return out


## Shared placement core: passable, empty, in-bounds neighbours of [param sources]
## (scanned N->E->S->W), filtered by [method _clears_enemy_standoff], returned in
## canonical tile-index order.
##
## One implementation, parameterized by which units count as the frontier — never
## two parallel copies — so the single-builder rule and the player-wide union can
## never drift apart in what they consider legal.
static func _sorted_build_tiles(state: GameState, player: int, \
		sources: Array[UnitState]) -> Array[Vector2i]:
	var grid: GridState = state.grid
	var candidates: Dictionary = {} # Vector2i -> true, dedup ONLY — see doc above.
	for e: UnitState in sources:
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
	# Dual-cost (ADR-0006 pivot): effective_build_cost is the Credit main cost;
	# build also spends a BUILD_AP_COST AP surcharge. Legal iff BOTH afford.
	var cost: int = effective_build_cost(state, action.structure_type, player)
	# ★ S6-02 (unit-upkeep.md UR-6): a player in deficit cannot expand. Checked
	# BEFORE affordability so the reason names the real cause -- a deficit player
	# may well be unable to afford the build too, but the deficit is why.
	if state.per_player[player].in_deficit:
		return Action.Reason.IN_DEFICIT
	# ★ S6-03: per-structure maximum. Checked BEFORE affordability so the reason names the
	# real cause -- a player at their maximum may also be broke, but the cap is why.
	if not can_build_more(state, player, action.structure_type):
		return Action.Reason.STRUCTURE_MAX_REACHED
	if not Credits.can_afford(state, player, cost):
		return Action.Reason.CANT_AFFORD_CREDITS
	if not AP.can_afford(state, player, Balance.economy.build_ap_cost):
		return Action.Reason.CANT_AFFORD
	# ★ The acting Builder, checked BEFORE the tile — a missing builder makes the
	# tile question meaningless, and "you have no builder" is the answer a player
	# can act on. Validated against the SINGLE-builder tile set, never the
	# player-wide union, so a tile beside some other builder is correctly refused.
	var builder: UnitState = builder_for(state, action)
	if builder == null:
		return Action.Reason.NOT_A_BUILDER
	if not (action.tile in legal_build_tiles_for(state, builder)):
		return Action.Reason.NOT_LEGAL_BUILD_TILE
	return Action.Reason.OK


## The living, owned, build-capable [UnitState] named by [param action], or null
## when there is not one. Null covers every way the requirement can fail — no id,
## destroyed since the preview, someone else's, or simply not a Builder — because
## all four mean the same thing at the point of use.
static func builder_for(state: GameState, action: BuildAction) -> UnitState:
	var entity: EntityState = state.entities_by_id.get(action.builder_id)
	if not (entity is UnitState):
		return null
	var unit: UnitState = entity as UnitState
	if unit.owner != state.active_player:
		return null
	if unit.type == null or not unit.type.can_build:
		return null
	return unit


## [BuildAction]'s [code]apply()[/code] handler (ADR-0017 D1/D2, ADR-0002,
## TR-baseprod-004) — re-runs [method validate_build] first (idempotent
## commit re-validation, ADR-0002: a tile/affordability change between
## preview and commit is rejected here with [b]no mutation at all[/b], rather
## than trusting the caller's earlier preview-time check). Only after that
## re-validation passes does this mutate, atomically: (1) dual-cost spend —
## [method Credits.spend] the [method effective_build_cost] (Credit main cost) and
## [method AP.spend] the [code]build_ap_cost[/code] surcharge (both-or-neither, ADR-0006);
## (2) construct a new [StructureState]
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
	# Dual-cost spend, both-or-neither (safe: validate_build re-checked BOTH pools
	# above, so neither leg can fail here — ADR-0002 validate-before-mutate).
	var cost: int = effective_build_cost(state, action.structure_type, player)
	Credits.spend(state, player, cost)                       # Credit main cost
	AP.spend(state, player, Balance.economy.build_ap_cost)   # AP surcharge

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

	# ★ The Builder is CONSUMED by what it raises (user decision 2026-08-25). Done
	# LAST, after the structure is placed and its event built, so a mid-apply
	# failure can never leave a player who has paid and lost their Builder with
	# nothing on the board. The destroy events are appended rather than discarded —
	# the board renderer and the population counter both learn the unit is gone from
	# them, and dropping them would leave a ghost sprite standing next to its own
	# building.
	var events: Array[Event] = [evt] as Array[Event]
	var builder: UnitState = builder_for(state, action)
	if builder != null:
		for e: Event in state.destroy_entity(builder.entity_id):
			events.append(e)
	return events


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
## Places the unit a producer has finished building, clearing its queue (S8-28).
##
## ⚠ [b]RE-VALIDATES the deploy tile.[/b] `production_tile` was legal when production
## started; two owner-turns later it can hold anything. If it is no longer legal this
## falls back to any other legal deploy tile, and only gives up when the producer has
## none — that case keeps the unit in the queue rather than destroying it, so a
## temporarily boxed-in base does not silently eat what the player already paid for.
##
## ★ The population check is NOT repeated here. PC-3 counts a unit from the moment
## production is committed, so its cap slot was reserved at commit — re-checking would
## double-count it against itself and could refuse to deliver a unit already paid for.
static func _complete_production(state: GameState, producer: StructureState) -> Array[Event]:
	var unit_type: UnitTypeDef = producer.producing_type
	var tile: Vector2i = producer.production_tile
	var legal: Array[Vector2i] = legal_deploy_tiles(state, producer, null)
	if not (tile in legal):
		if legal.is_empty():
			# Boxed in. Hold the unit — it is paid for, and the block is usually temporary.
			producer.production_turns_remaining = 1
			return [] as Array[Event]
		tile = legal[0]

	var unit := UnitState.new()
	unit.entity_id = state.next_entity_id
	unit.owner = producer.owner
	unit.position = tile
	unit.type = unit_type
	unit.current_hp = unit_type.hp
	state.entities_by_id[unit.entity_id] = unit
	state.next_entity_id += 1
	var placed: bool = state.grid.place(unit.entity_id, tile.x, tile.y)
	assert(placed, "BaseProduction._complete_production: Grid.place failed on a tile legal_deploy_tiles accepted — legal_deploy_tiles/Grid desync.")

	producer.producing_type = null
	producer.production_turns_remaining = 0

	var evt := UnitDeployedEvent.new()
	evt.entity_id = unit.entity_id
	evt.unit_type = unit_type
	evt.owner = producer.owner
	evt.tile = tile
	return [evt] as Array[Event]


static func advance_build_timers(state: GameState, player: int) -> Array[Event]:
	var events: Array[Event] = []
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var structure: StructureState = e
		# ★ S8-28: tick the PRODUCTION queue here. Runs once per owner-turn, strictly
		# before the economy step — the cadence a per-turn timer wants, and real product
		# code, unlike Structure.reset_turn_flags which is satisfied by a TEST STUB
		# (tests/helpers/stubs/structure_stub.gd).
		# ⚠ Deliberately ticks BEFORE the under-construction guard below: a COMPLETED
		# producer is exactly the case that has a unit in flight, and an early `continue`
		# would freeze every queue on the board.
		if structure.producing_type != null:
			structure.production_turns_remaining -= 1
			if structure.production_turns_remaining <= 0:
				events.append_array(_complete_production(state, structure))
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

## Counts how many of [param structure_type] [param player] currently holds, counting
## [b]both[/b] completed and under-construction instances (S6-03).
##
## ★ Under-construction ones MUST count, or the maximum does nothing: a player could
## queue any number simultaneously and only be stopped once they finished. This mirrors
## `population-cap.md` PC-3's identical reasoning for queued units.
##
## Pure, O(n) over entities.
static func structure_count(state: GameState, player: int, structure_type: StructureTypeDef) -> int:
	var count: int = 0
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		if (e as StructureState).type == structure_type:
			count += 1
	return count


## Whether [param player] may build another [param structure_type] without exceeding its
## [member StructureTypeDef.max_count]. A `max_count` of 0 means unlimited.
static func can_build_more(state: GameState, player: int, structure_type: StructureTypeDef) -> bool:
	if structure_type.max_count <= 0:
		return true
	return structure_count(state, player, structure_type) < structure_type.max_count
## The AP cost a Defensive Structure attacker spends per [method Combat.apply]
## (ADR-0010/ADR-0017, TR-combat-012) — replaces
## [code]base_production_stub.gd[/code]'s test-controllable stand-in;
## [code]Combat._attack_cost_for[/code] calls this cross-system exactly as it
## called the stub. Reads [member BaseProductionConfig.defensive_attack_cost]
## (Story 001's config) via the [code]StructureBalance[/code] Autoload — never
## a hardcoded literal. O(1).
static func defensive_attack_cost() -> int:
	return StructureBalance.base_production.defensive_attack_cost


## The AP refunded for cancelling a structure whose base build cost is
## [param build_cost] (ADR-0017 D5/D6, TR-baseprod-013) — [b]fixed-point integer
## percent[/b]: [code]build_cost * cancel_refund_pct / 100[/code], where
## [member BaseProductionConfig.cancel_refund_pct] is read from the
## [code]StructureBalance[/code] Autoload (Story 001's config, default 50), never
## a hardcoded literal or a float rate (control-manifest forbids the GDD's
## [code]CANCEL_REFUND_RATE: float = 0.5[/code]; the economy is integer-only per
## ADR-0003).
##
## GDScript's [code]*[/code] and [code]/[/code] share precedence and associate
## left-to-right, so this evaluates as [code](build_cost * pct) / 100[/code] —
## the multiply happens before the integer division, avoiding a premature
## truncation to 0. Integer [code]/[/code] truncates toward zero, which equals
## [code]floor[/code] for these non-negative operands: 4→2, 9→4, 6→3, odd 5→2
## (floors, never rounds). O(1). Pure — no [param state] needed (faction never
## folds the refund; the rate is a flat B&P config).
static func cancel_refund(build_cost: int) -> int:
	return build_cost * StructureBalance.base_production.cancel_refund_pct / 100


## [CancelBuildAction]'s [code]validate()[/code] handler (ADR-0017 D5, ADR-0002,
## TR-baseprod-013) — [b]pure and total[/b]: checks every failure condition,
## never mutates [param state]. Registered into the dispatch table by
## [method GameState._ensure_dispatch_registered].
##
## Checks, in order: (1) [param action].structure_id resolves to a live
## [StructureState] ([constant Action.Reason.NO_SUCH_ENTITY] otherwise); (2) that
## structure is owned by [member GameState.active_player]
## ([constant Action.Reason.ILLEGAL_TARGET] otherwise — you cannot cancel an
## opponent's build); (3) it is
## [constant StructureState.BuildStatus.UNDER_CONSTRUCTION]
## ([constant Action.Reason.NOT_UNDER_CONSTRUCTION] otherwise — a Completed
## structure can only be combat-destroyed, never cancelled; Rule 10).
##
## Idempotency (ADR-0002): re-running this against current state re-validates
## fresh — a structure that completed or was destroyed between preview and commit
## is caught here, so [method apply_cancel] can lean on it as a commit re-check.
##
## O(1) — one [Dictionary] lookup plus two field comparisons (control-manifest
## Performance Guardrail).
static func validate_cancel(state: GameState, action: CancelBuildAction) -> int:
	var entity: EntityState = state.entities_by_id.get(action.structure_id, null)
	if entity == null or not (entity is StructureState):
		return Action.Reason.NO_SUCH_ENTITY
	var structure: StructureState = entity
	if structure.owner != state.active_player:
		return Action.Reason.ILLEGAL_TARGET
	if structure.build_status != StructureState.BuildStatus.UNDER_CONSTRUCTION:
		return Action.Reason.NOT_UNDER_CONSTRUCTION
	return Action.Reason.OK


## [CancelBuildAction]'s [code]apply()[/code] handler (ADR-0017 D5, ADR-0002,
## TR-baseprod-013) — re-runs [method validate_cancel] first (idempotent commit
## re-validation, ADR-0002: a structure that completed or was destroyed between
## preview and commit is rejected here with [b]no mutation at all[/b]). Only
## after that passes does this mutate, atomically: (1) compute the refund via
## [method cancel_refund] on the structure's base [member StructureTypeDef.build_cost];
## (2) [method Credits.credit] the refund to the owner's pool in CREDITS (ADR-0006
## pivot — the Credits-owned write path, never a direct
## [member PlayerState.current_credits] mutation; the AP surcharge is not refunded); (3)
## [method GridState.remove] the structure's tile; (4)
## [method Dictionary.erase] the entity from [member GameState.entities_by_id]
## (the "in `entities_by_id` ⇔ alive" invariant's terminal exit, ADR-0017 D1);
## (5) append one [StructureCancelledEvent] carrying the [member StructureCancelledEvent.refund]
## so presentation reads the credited amount from the event, never re-deriving it.
##
## Returns [code][][/code] (no event, no mutation) on the defensive
## re-validation-failure path — the same atomicity guarantee
## [method GameState.apply_action] provides for a normal first commit; matters
## only for a caller invoking [method apply_cancel] directly without going
## through [method GameState.apply_action] (e.g. a test), so the re-validation is
## not bypassable.
##
## O(1) plus the internal [method validate_cancel] re-check (control-manifest
## Performance Guardrail).
## Rejection cause for [method apply_cancel_production], or [constant Action.Reason.OK].
static func validate_cancel_production(state: GameState, action: CancelProductionAction) -> int:
	if state.match_status != GameState.MatchStatus.IN_PROGRESS:
		return Action.Reason.GAME_OVER
	var player: int = state.active_player
	var e: EntityState = state.entities_by_id.get(action.producer_id)
	if e == null or not (e is StructureState):
		return Action.Reason.NO_SUCH_ENTITY
	var producer: StructureState = e as StructureState
	if producer.owner != player:
		return Action.Reason.ILLEGAL_TARGET
	if producer.producing_type == null:
		return Action.Reason.NOTHING_IN_PRODUCTION
	return Action.Reason.OK


## Abandons a producer's in-flight build, refunding Credits at the SAME rate
## structures use (S8-28).
##
## ⚠ The AP surcharge is not refunded — identical to [method apply_cancel]. AP bought
## tempo, the tempo was spent, and only Credits were ever recoverable.
##
## ★ Frees the population slot PC-3 reserved at commit, which is the whole reason a
## player would cancel: it is the only way to undo a queue decision that has boxed them
## out of producing something they now need more.
static func apply_cancel_production(state: GameState, action: CancelProductionAction) -> Array[Event]:
	if validate_cancel_production(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var producer: StructureState = state.entities_by_id[action.producer_id]
	var unit_type: UnitTypeDef = producer.producing_type
	var refund: int = cancel_refund(Unit.effective_produce_cost(state, unit_type, player))
	Credits.credit(state, player, refund)

	producer.producing_type = null
	producer.production_turns_remaining = 0

	var evt := ProductionCancelledEvent.new()
	evt.entity_id = producer.entity_id
	evt.unit_type = unit_type
	evt.owner = player
	evt.refund = refund
	return [evt] as Array[Event]


static func apply_cancel(state: GameState, action: CancelBuildAction) -> Array[Event]:
	if validate_cancel(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var structure: StructureState = state.entities_by_id[action.structure_id]
	# Refund is in CREDITS (ADR-0006 pivot: build was paid mainly in Credits; the
	# AP surcharge is not refunded). Was AP.credit pre-pivot.
	var refund: int = cancel_refund(structure.type.build_cost)
	Credits.credit(state, player, refund)
	# validate_cancel (re-run above) guarantees this is a live StructureState, and
	# every structure is Grid.place'd when built (apply_build) — so remove() cannot
	# fail here. Assert it loudly rather than silently discard the bool: a false
	# return would mean an entities_by_id/Grid desync (an entity with no grid
	# occupant), leaving a half-committed cancel (Credits credited, entity erased,
	# event emitted) with a stale grid cell. Mirrors apply_build/apply_produce's Grid
	# tripwire. (Dev-only; assert is stripped in release, matching convention.)
	var removed: bool = state.grid.remove(structure.position.x, structure.position.y)
	assert(removed, "BaseProduction.apply_cancel: Grid.remove failed on a live structure's tile — entities_by_id/Grid desync.")
	state.entities_by_id.erase(structure.entity_id)

	var evt := StructureCancelledEvent.new()
	evt.entity_id = structure.entity_id
	evt.structure_type = structure.type
	evt.owner = player
	evt.tile = structure.position
	evt.refund = refund
	return [evt] as Array[Event]


## Returns every legal deploy tile for a unit produced by [param producer]
## (ADR-0017 D4, TR-baseprod-008) — a pure, [b]live[/b] query, never cached.
## The candidate universe is every tile within [member BaseProductionConfig.deploy_radius] manhattan
## steps of the producer, kept only if in-bounds, passable and unoccupied — exactly
## what [method GridState.is_passable] answers (it folds bounds + non-Impassable
## terrain + empty-occupant into one O(1) check). The trailing
## [code]sort_custom(_by_tile_index)[/code] makes the returned order canonical
## (ADR-0003/ADR-0009 determinism discipline), mirroring
## [method legal_build_tiles]' ordering.
##
## [b]★ The radius was 1 until 2026-08-24, and that was a game-ending defect.[/b]
## At radius 1 a producer has at most FOUR deploy tiles, so four enemy units
## standing on them ended that player's game permanently: production is the only
## route back onto the board, and it was closed with no counterplay. S5-04 measured
## the consequence — a +1-Trooper advantage produced ZERO lead changes across six
## games, against 6.75 in an even match — and
## `s5-04-one-unit-cliff-diagnosis-2026-08-24.md` traced it to exactly this
## function. Radius 2 gives up to 12 tiles, so a lock needs more units than the
## population cap allows.
##
## [b]Distance, not reachability.[/b] The scan is a manhattan-radius test and does
## NOT path around occupied tiles — a unit may deploy "over" a besieging enemy to a
## free tile behind it. That is deliberate and is the whole point: a
## flood-fill-through-passable-tiles version would be blocked by the same four
## enemies and would reproduce the defect exactly.
##
## ⚠ Consequence to know: a destination separated from the producer by IMPASSABLE
## terrain is still legal if it is within 2 steps. No VS map uses impassable
## terrain, so nothing exercises it today; a map that does will want a
## line-of-deployment rule here. Flagged rather than pre-solved.
##
## [param unit_type] does not change deploy legality in the VS (every unit needs
## the same empty tile to stand on) — accepted for signature alignment with
## ADR-0011/0015' forward declarations and future terrain rules; unused today.
##
## O(r²) scan (12 candidate tiles at radius 2) plus a bounded sort — cheap
## (control-manifest Performance Guardrail); safe to recompute every preview frame.
static func legal_deploy_tiles(state: GameState, producer: StructureState, _unit_type: UnitTypeDef) -> Array[Vector2i]:
	var grid: GridState = state.grid
	var radius: int = StructureBalance.base_production.deploy_radius
	var out: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		var span: int = radius - absi(dy)
		for dx: int in range(-span, span + 1):
			if dx == 0 and dy == 0:
				continue # the producer's own tile
			var t := Vector2i(producer.position.x + dx, producer.position.y + dy)
			if grid.in_bounds(t.x, t.y) and grid.is_passable(t.x, t.y):
				out.append(t)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.index(a.x, a.y) < grid.index(b.x, b.y))
	return out


## The faction-folded per-turn production cap for [param producer] owned by
## [param player] (ADR-0012 §3's B&P-owned [code]effective_X[/code] read site,
## ADR-0017 D4 Risk) — the [b]two-sided[/b] invariant, never a single symmetric
## clamp: a base cap of [code]0[/code] (a non-producer: Economy Outpost,
## Defensive Structure, Research Lab) stays [code]0[/code] — no faction delta can
## turn a non-producer into a producer — while a base cap [code]>= 1[/code]
## folds as [code]max(1, base + delta)[/code], so a subtractive faction delta can
## never drop a real producer below a cap of 1.
##
## The faction [code]production_cap[/code] delta fold is [b]deferred to the
## Faction Identity epic[/b] ([code]Faction.structure_delta[/code] is
## forward-declared only, ADR-0012 §3) — exactly as this file's
## [method effective_build_cost]/[method effective_build_time] defer their folds.
## Under the VS's Neutral-only roster [code]delta == 0[/code], so this returns
## [b]exactly[/b] [param producer].type.production_cap (Neutral no-op,
## ADR-0012 §5). Non-Neutral delta values are out of this story's scope.
##
## O(1). Called by [method validate_produce]'s cap gate (checked before the AP
## gate, so an at-cap producer is rejected even with AP to spare).
static func effective_production_cap(_state: GameState, producer: StructureState, _player: int) -> int:
	var base_cap: int = producer.type.production_cap
	if base_cap == 0:
		return 0
	var delta: int = 0 # Faction production_cap fold deferred to Faction epic (0 under Neutral).
	return maxi(1, base_cap + delta)


## [ProduceAction]'s [code]validate()[/code] handler (ADR-0017 D4, ADR-0002,
## TR-baseprod-008) — [b]pure and total[/b]: checks every failure condition,
## never mutates [param state]. Registered into the dispatch table by
## [method GameState._ensure_dispatch_registered].
##
## The acting player is [param state]'s [member GameState.active_player] (already
## gated by [method GameState.apply_action]'s step 2 before this handler runs);
## [param action].producer_id names which owned structure spawns the unit.
##
## Checks, in order: two producer preconditions then the five ADR-0017 D4 gates —
## (0a) [param action].producer_id resolves to a live [StructureState]
## ([constant Action.Reason.NO_SUCH_ENTITY] otherwise); (0b) that structure is
## owned by the active player ([constant Action.Reason.ILLEGAL_TARGET]
## otherwise); (1) it is [constant StructureState.BuildStatus.COMPLETED]
## ([constant Action.Reason.NOT_COMPLETED] otherwise); (2) [param action].unit_type
## is in the producer's [member StructureTypeDef.producible_types] by
## [b]Resource-reference membership[/b] — never a string/enum compare
## ([constant Action.Reason.NOT_PRODUCIBLE] otherwise); (3)
## [member StructureState.units_produced_this_turn] is below
## [method effective_production_cap] ([constant Action.Reason.PRODUCTION_CAP_REACHED]
## otherwise — checked [b]before[/b] AP so the cap gates independently of a full
## wallet); (4) [method AP.can_afford] the [method Unit.effective_produce_cost]
## ([constant Action.Reason.CANT_AFFORD] otherwise); (5) [param action].tile is in
## [method legal_deploy_tiles] ([constant Action.Reason.NOT_LEGAL_DEPLOY_TILE]
## otherwise — covers occupied/off-board/Impassable/non-adjacent in one gate).
##
## Idempotency (ADR-0002): re-running this against current state re-validates
## every gate fresh — a producer destroyed/reverted or a deploy tile that became
## occupied between preview and commit is caught here, so [method apply_produce]
## can lean on it as a commit re-check.
##
## O(1) plus one [method legal_deploy_tiles] call (O(4)); control-manifest
## Performance Guardrail.
static func validate_produce(state: GameState, action: ProduceAction) -> int:
	var producer_entity: EntityState = state.entities_by_id.get(action.producer_id, null)
	if producer_entity == null or not (producer_entity is StructureState):
		return Action.Reason.NO_SUCH_ENTITY
	var producer: StructureState = producer_entity
	var player: int = state.active_player
	if producer.owner != player:
		return Action.Reason.ILLEGAL_TARGET
	if producer.build_status != StructureState.BuildStatus.COMPLETED:
		return Action.Reason.NOT_COMPLETED
	if not (action.unit_type in producer.type.producible_types):
		return Action.Reason.NOT_PRODUCIBLE
	if producer.units_produced_this_turn >= effective_production_cap(state, producer, player):
		return Action.Reason.PRODUCTION_CAP_REACHED
	# ★ S6-04: the infantry cap (population-cap.md PC-2). Checked at PRODUCTION only --
	# a player already above their cap (possible after a Barracks is destroyed, PC-6) is
	# never forced to lose units, they simply cannot produce until back under.
	if not Population.can_field(state, player, action.unit_type):
		return Action.Reason.POPULATION_CAP_REACHED
	# ★ S6-07: reinforcement rate limit (user decision 2026-08-24, "slower reinforcement").
	# Distinct from PRODUCTION_CAP_REACHED, which is a per-turn throughput limit on a
	# producer that is otherwise free to produce again next turn.
	# ★ S8-28: one unit at a time. A producer with a build in flight is busy until it
	# completes — this is what replaced the flat per-structure cooldown, so the wait is
	# now a property of WHAT is being made rather than of the building making it.
	if producer.producing_type != null:
		return Action.Reason.PRODUCER_ON_COOLDOWN
	# Dual-cost (ADR-0006 pivot): effective_produce_cost is the Credit main cost;
	# produce also spends a PRODUCE_AP_COST AP surcharge. Legal iff BOTH afford.
	var cost: int = Unit.effective_produce_cost(state, action.unit_type, player)
	# ★ S6-02 (unit-upkeep.md UR-6): a player in deficit cannot expand. Checked
	# BEFORE affordability so the reason names the real cause -- a deficit player
	# may well be unable to afford the build too, but the deficit is why.
	if state.per_player[player].in_deficit:
		return Action.Reason.IN_DEFICIT
	if not Credits.can_afford(state, player, cost):
		return Action.Reason.CANT_AFFORD_CREDITS
	if not AP.can_afford(state, player, Balance.economy.produce_ap_cost):
		return Action.Reason.CANT_AFFORD
	if not (action.tile in legal_deploy_tiles(state, producer, action.unit_type)):
		return Action.Reason.NOT_LEGAL_DEPLOY_TILE
	return Action.Reason.OK


## [ProduceAction]'s [code]apply()[/code] handler (ADR-0017 D4, ADR-0002,
## TR-baseprod-008) — re-runs [method validate_produce] first (idempotent commit
## re-validation, ADR-0002: a producer/tile change between preview and commit is
## rejected here with [b]no mutation at all[/b], rather than trusting the caller's
## earlier preview-time check). Only after that passes does this mutate,
## atomically: (1) dual-cost spend — [method Credits.spend] the
## [method Unit.effective_produce_cost] (Credit main cost) and [method AP.spend]
## the [code]produce_ap_cost[/code] surcharge (both-or-neither, ADR-0006);
## (2) construct a new [UnitState] ([member UnitState.type] = [param action].unit_type,
## [member UnitState.owner] = active player, [member EntityState.position] =
## [param action].tile, [member UnitState.current_hp] = [code]type.hp[/code]) —
## a unit is [b]Active the instant it exists[/b] (units have no build lifecycle,
## Unit Rule 2, so there is no under-construction state to set); (3) register it
## under a freshly allocated [member GameState.next_entity_id]; (4)
## [method GridState.place] it on the deploy tile; (5) increment the producer's
## [member StructureState.units_produced_this_turn]; (6) append one
## [UnitDeployedEvent].
##
## Returns [code][][/code] (no event, no mutation) on the defensive
## re-validation-failure path — the same "atomic, no partial mutation" guarantee
## [method GameState.apply_action] already provides for a normal first commit;
## this only matters for a caller invoking [method apply_produce] directly
## without going through [method GameState.apply_action] (e.g. a test), so the
## re-validation is not bypassable.
##
## O(1) plus the internal [method validate_produce] re-check (control-manifest
## Performance Guardrail).
static func apply_produce(state: GameState, action: ProduceAction) -> Array[Event]:
	if validate_produce(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var producer: StructureState = state.entities_by_id[action.producer_id]
	# Dual-cost spend, both-or-neither (validate_produce re-checked BOTH pools above).
	var cost: int = Unit.effective_produce_cost(state, action.unit_type, player)
	Credits.spend(state, player, cost)                          # Credit main cost
	AP.spend(state, player, Balance.economy.produce_ap_cost)    # AP surcharge

	# ★ S8-28: production is no longer instant. The commit STARTS a build; the unit is
	# placed by advance_build_timers when the timer reaches zero. Costs are spent HERE,
	# at commit, so a queued unit is already paid for — which is what makes PC-3
	# ("units under production count against the cap") meaningful rather than a loophole.
	producer.producing_type = action.unit_type
	producer.production_turns_remaining = action.unit_type.production_turns
	producer.production_tile = action.tile

	producer.units_produced_this_turn += 1
	# ★ 2026-08-25: acting clears the stand-down mark. It records "I am finished
	# with this one", and the player has visibly changed their mind — leaving it
	# set would keep the entity dim and skipped while it still had a turn left.
	producer.stood_down = false

	var evt := ProductionStartedEvent.new()
	evt.entity_id = producer.entity_id
	evt.unit_type = action.unit_type
	evt.owner = player
	evt.tile = action.tile
	evt.turns_remaining = producer.production_turns_remaining
	return [evt] as Array[Event]
