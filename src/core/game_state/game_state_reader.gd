## GameStateReader — read-only facade over [GameState] for Presentation-layer
## consumers (HUD, Command & Action Interface).
##
## Presentation-layer contract per ADR-0016 §1 ("Read-only facade: never-mutates
## is structural, not reviewed", TR-hud-003). Originally the **Story 010 stub**
## shipping only [method unit_info] (TR-unit-013 — "HUD/Cmd read-surface: type,
## cur/max hp, effective attack, move cost, has-acted, blocked-shot reason;
## read-only"). **Story 009** (TR-baseprod-017) extends this same file with the
## Base & Production read-surface: [method legal_build_tiles],
## [method legal_deploy_tiles], [method structure_info] (build-timer progress,
## remaining production cap, cancel-refund preview, current/max hp), and
## affordability ([method can_afford_build]/[method can_afford_produce]).
## **Game HUD Story 001** (TR-hud-001/002/003/020/023) extends this same file
## with the remaining full getter set named in ADR-0016 §1's skeleton —
## [method active_player], [method round_number], [method match_status],
## [method current_ap], [method income_breakdown], [method can_afford],
## [method entities], [method entity_at] — plus a signal-subscription broker
## ([method subscribe_action_applied]/[method unsubscribe_action_applied]) so a
## HUD [Control] can react to [signal GameState.action_applied] without ever
## holding a live [GameState] reference itself. [method entities]/
## [method entity_at] hand out live [EntityState] refs (consistent with
## existing BoardRenderer/Command & Action Interface Presentation usage);
## consumers treat them as read-only. The read-only guarantee is structural:
## AC-3 reflects over the facade's own declared method set and finds zero
## mutation-shaped name — the broker methods register a signal listener and are
## not state mutators. [method unit_info]/[method structure_info] remain the
## recommended path when only display values are needed.
##
## [b]Structural read-only, not convention[/b]: GDScript has no access-modifier
## keywords, so "read-only" cannot be enforced by a [code]private[/code] marker.
## It is enforced by shape instead — this class exposes getters only (no setter,
## no [code]apply_action[/code]), and every accessor below returns a freshly
## built value snapshot (copied primitives + immutable template references,
## or a fresh [Array]/[Dictionary] already produced per-call by the owning
## query), never the live [UnitState]/[StructureState]/[member _state]. There
## is no reachable path from a caller holding this reader, or holding any
## accessor's return value, back to any [GameState] mutator.
##
## [b]Pass-Through Invariant[/b] (ADR-0015/0016, TR-baseprod-017): this class
## holds no balance constant by name and re-derives no formula — cost,
## legality, cap, and refund values are always the literal return of an
## owning system's ([BaseProduction]/[Unit]/[AP]) side-effect-free query.
##
## Usage:
## [codeblock]
## var reader := GameStateReader.new(state)
## var info := reader.unit_info(unit.entity_id)
## print(info["type"].display_name, " ", info["current_hp"], "/", info["hp"])
##
## var tiles: Array[Vector2i] = reader.legal_build_tiles(0, StructureTypes.ECONOMY_OUTPOST)
## var s_info := reader.structure_info(structure.entity_id)
## print(s_info["build_turns_remaining"], " turns left, refund ", s_info["cancel_refund"])
## [/codeblock]
class_name GameStateReader
extends RefCounted

## The wrapped authoritative state. Never exposed by any accessor — no getter
## returns [member _state] or an object holding a live reference back to it.
var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Returns a read-only value-snapshot [Dictionary] describing the unit at
## [param entity_id]. (TR-unit-013 / ADR-0016 §1's [code]unit_info(entity_id)[/code]-
## shaped accessor.)
##
## Keys: [code]"type"[/code] ([UnitTypeDef] registry template reference —
## immutable per ADR-0007, safe to hand out as-is), [code]"current_hp"[/code]
## (int), [code]"hp"[/code] (int, = [code]type.hp[/code], the max), [code]"effective_attack"[/code]
## (int, [method Unit.effective_attack] — Story 004's live Research-tech fold),
## [code]"move_cost"[/code] (int, = [code]type.move_cost[/code]), [code]"has_attacked"[/code]
## (bool), [code]"attack_range"[/code] (int, = [code]type.attack_range[/code] — the
## Combat-owned [code]BlockedReason[/code] classification itself is Out of Scope
## for this story per ADR-0010; Unit only surfaces its own fields as inputs).
##
## [b]Total/safe contract[/b]: [member GameState.entities_by_id] is keyed by
## [EntityState] and holds BOTH [UnitState] and [code]StructureState[/code].
## If [param entity_id] does not resolve to a live entity, OR resolves to a
## non-[UnitState] entity (e.g. a structure's id queried through this unit-only
## accessor), this returns an empty [Dictionary] — never a runtime type error.
## This is a deliberate, read-only total function, not an omission.
##
## The returned [Dictionary] is a fresh value copy on every call — mutating it
## can never alias or perturb [member _state] (structural AC-2 read-only proof).
func unit_info(entity_id: int) -> Dictionary:
	var entity: EntityState = _state.entities_by_id.get(entity_id)
	if entity == null or not (entity is UnitState):
		return {}
	var unit := entity as UnitState

	return {
		"type": unit.type,
		"current_hp": unit.current_hp,
		"hp": unit.type.hp,
		"effective_attack": Unit.effective_attack(_state, unit),
		"move_cost": unit.type.move_cost,
		"has_attacked": unit.has_attacked,
		"attack_range": unit.type.attack_range,
	}


## Returns every legal build tile for [param player] building [param
## structure_type] — a straight pass-through to [method BaseProduction.legal_build_tiles]
## (Story 009, TR-baseprod-017; ADR-0016 §1 Pass-Through Invariant: no locally
## re-derived adjacency/standoff rule lives here). [Array] is a value type in
## GDScript — the [Array] returned by [method BaseProduction.legal_build_tiles]
## is already a fresh allocation per call (never cached), so this hands the
## caller a snapshot with no path back to [member _state]; mutating the
## returned [Array] cannot perturb [member _state] or any future call's result.
##
## O(query) — identical cost to the owning call (control-manifest Performance
## Guardrail note: this is a read accessor, not a simulation-hot-path call; the
## Presentation layer is responsible for how often it polls this per frame).
func legal_build_tiles(player: int, structure_type: StructureTypeDef) -> Array[Vector2i]:
	return BaseProduction.legal_build_tiles(_state, player, structure_type)


## Returns every legal deploy tile for a unit produced by the structure at
## [param producer_id] (Story 009, TR-baseprod-017) — resolves the producer
## internally via [member GameState.entities_by_id] so this facade never
## accepts or hands out a live [StructureState] reference; only a straight
## pass-through to [method BaseProduction.legal_deploy_tiles] follows.
##
## [b]Total/safe contract[/b] (mirrors [method unit_info]): if [param producer_id]
## does not resolve to a live entity, OR resolves to a non-[StructureState]
## entity (e.g. a unit's id queried through this producer-only accessor), this
## returns an empty [Array] — never a runtime type error. Deliberate, read-only
## total function, not an omission.
##
## O(query) — identical cost to the owning call (control-manifest Performance
## Guardrail note: read accessor, not simulation-hot-path; per-frame HUD
## polling cadence is a Presentation-layer concern, out of scope here).
func legal_deploy_tiles(producer_id: int, unit_type: UnitTypeDef) -> Array[Vector2i]:
	var entity: EntityState = _state.entities_by_id.get(producer_id)
	if entity == null or not (entity is StructureState):
		return []
	var producer := entity as StructureState
	return BaseProduction.legal_deploy_tiles(_state, producer, unit_type)


## Returns a read-only value-snapshot [Dictionary] describing the structure at
## [param entity_id] (Story 009, TR-baseprod-017 — build-timer progress,
## remaining production cap, cancel-refund preview, current/max hp).
##
## Keys: [code]"type"[/code] ([StructureTypeDef] registry template reference —
## immutable per ADR-0007, safe to hand out as-is, mirrors [method unit_info]'s
## [code]"type"[/code] key), [code]"current_hp"[/code] (int),
## [code]"hp"[/code] (int, = [code]type.hp[/code], the max),
## [code]"build_status"[/code] (int, [enum StructureState.BuildStatus]),
## [code]"build_turns_remaining"[/code] (int, the build-timer progress read),
## [code]"units_produced_this_turn"[/code] (int),
## [code]"remaining_production_cap"[/code] (int, =
## [method BaseProduction.effective_production_cap] [code]−[/code]
## [code]units_produced_this_turn[/code] — [b]not[/b] a locally-held cap
## constant, the two owning-query terms combined at read time), and
## [code]"cancel_refund"[/code] (int, = [code]BaseProduction.cancel_refund(type.build_cost)[/code] —
## [b]the structure's base [member StructureTypeDef.build_cost][/b], the exact
## same expression [method BaseProduction.apply_cancel] evaluates for the real
## refund, [b]never[/b] [method BaseProduction.effective_build_cost] — so this
## preview can never drift from what a real cancel actually credits).
##
## [b]Total/safe contract[/b] (mirrors [method unit_info]): if [param entity_id]
## does not resolve to a live entity, OR resolves to a non-[StructureState]
## entity (e.g. a unit's id queried through this structure-only accessor), this
## returns an empty [Dictionary] — never a runtime type error.
##
## The returned [Dictionary] is a fresh value copy on every call — mutating it
## can never alias or perturb [member _state] (structural AC-8 read-only
## proof, mirrors [method unit_info]).
##
## O(query) — one [Dictionary] lookup plus two O(1) [BaseProduction] calls
## (control-manifest Performance Guardrail note: read accessor, not
## simulation-hot-path; per-frame HUD polling cadence is a Presentation-layer
## concern, out of scope here).
func structure_info(entity_id: int) -> Dictionary:
	var entity: EntityState = _state.entities_by_id.get(entity_id)
	if entity == null or not (entity is StructureState):
		return {}
	var structure := entity as StructureState

	var player: int = structure.owner
	var cap: int = BaseProduction.effective_production_cap(_state, structure, player)

	return {
		"type": structure.type,
		"current_hp": structure.current_hp,
		"hp": structure.type.hp,
		"build_status": structure.build_status,
		"build_turns_remaining": structure.build_turns_remaining,
		"units_produced_this_turn": structure.units_produced_this_turn,
		"remaining_production_cap": cap - structure.units_produced_this_turn,
		"cancel_refund": BaseProduction.cancel_refund(structure.type.build_cost),
	}


## True iff [param player] can currently afford to build [param structure_type]
## (Story 009, TR-baseprod-017) — [b]never[/b] a locally re-derived cost
## (ADR-0015/0016 Pass-Through Invariant): reads
## [method BaseProduction.effective_build_cost] then hands it straight to
## [method AP.can_afford]. This facade holds no build-cost constant by name.
##
## O(query) — two O(1) calls (control-manifest Performance Guardrail note:
## read accessor, not simulation-hot-path).
func can_afford_build(player: int, structure_type: StructureTypeDef) -> bool:
	var cost: int = BaseProduction.effective_build_cost(_state, structure_type, player)
	return AP.can_afford(_state, player, cost)


## True iff [param player] can currently afford to produce [param unit_type]
## (Story 009, TR-baseprod-017) — [b]never[/b] a locally re-derived cost
## (ADR-0015/0016 Pass-Through Invariant): reads
## [method Unit.effective_produce_cost] then hands it straight to
## [method AP.can_afford]. This facade holds no produce-cost constant by name.
##
## O(query) — two O(1) calls (control-manifest Performance Guardrail note:
## read accessor, not simulation-hot-path).
func can_afford_produce(player: int, unit_type: UnitTypeDef) -> bool:
	var cost: int = Unit.effective_produce_cost(_state, unit_type, player)
	return AP.can_afford(_state, player, cost)


## The active player's index into [member GameState.per_player] (TR-hud-009,
## ADR-0016 §1) — a direct pass-through to [member GameState.active_player].
## O(1).
func active_player() -> int:
	return _state.active_player


## The current round number (TR-hud-009, ADR-0016 §1) — a direct pass-through
## to [member GameState.round_number]. O(1).
func round_number() -> int:
	return _state.round_number


## The match's terminal status ([enum GameState.MatchStatus], TR-hud-016/017,
## ADR-0016 §1) — a direct pass-through to [member GameState.match_status].
## O(1).
func match_status() -> int:
	return _state.match_status


## The winning player's index, or -1 if the match is not over (TR-hud-016,
## ADR-0016 §6/§8) — a direct pass-through to [member GameState.winner], set by
## [method GameState.run_win_check]. The victory/defeat overlay reads this to
## name the winner (verbatim, never inferred). O(1).
func winner() -> int:
	return _state.winner


## [param player]'s AP available to spend this turn (TR-hud-005, ADR-0016 §1) —
## a direct pass-through to [method AP.current_ap]. Never a locally re-derived
## value (Pass-Through Invariant). O(1).
func current_ap(player: int) -> int:
	return AP.current_ap(_state, player)


## [param player]'s AP income decomposed into its three additive terms
## ([code]{base, outpost, econ_tech}[/code], TR-hud-019, ADR-0016 §1) — a
## direct pass-through to [method AP.ap_income_breakdown]. A real pass-through,
## not a stub: [method AP.ap_income_breakdown] is a fully implemented AP Economy
## query as of this story. Never locally re-split from raw inputs (Pass-Through
## Invariant — ADR-0016 §1 forbids the HUD receiving raw outpost count/tech flag
## and splitting locally). O(1) plus the owning query's own O(1) reads.
func income_breakdown(player: int) -> Dictionary:
	return AP.ap_income_breakdown(_state, player)


## True iff [param player] can currently afford [param amount] AP (TR-hud-015,
## ADR-0016 §1) — a direct pass-through to [method AP.can_afford]. O(1).
func can_afford(player: int, amount: int) -> bool:
	return AP.can_afford(_state, player, amount)


## Every entity in the match, in stable [member EntityState.entity_id]-ascending
## order (TR-hud-020, ADR-0016 §1) — a direct pass-through to
## [method GameState.entities]. Already a fresh [code]Array[EntityState][/code]
## allocation per call (see [method GameState.entities]); the returned array
## holds live [EntityState] refs (see this class's doc-comment scoping note),
## consistent with existing Presentation-layer usage. O(n log n) — re-sorted
## every call, not cached.
func entities() -> Array[EntityState]:
	return _state.entities()


## The [EntityState] occupying [param tile], or [code]null[/code] if the tile
## is empty/unoccupied (TR-hud-010/011, ADR-0016 §1) — a direct pass-through to
## [method GameState.entity_at]. Returns a live [EntityState] ref (see this
## class's doc-comment scoping note). O(1).
func entity_at(tile: Vector2i) -> EntityState:
	return _state.entity_at(tile)


## Subscribes [param handler] to the wrapped state's
## [signal GameState.action_applied] (TR-hud-023, ADR-0016 §8) — the sole
## sanctioned way a HUD [Control] reacts to a commit without ever holding a
## live [GameState] reference itself. Idempotent: connecting the same
## [Callable] twice is a no-op (mirrors [CommandInterface]'s
## [code]is_connected[/code] guard convention). Registers a listener on an
## existing signal — NOT a state mutator (see this class's doc-comment note).
func subscribe_action_applied(handler: Callable) -> void:
	if not _state.action_applied.is_connected(handler):
		_state.action_applied.connect(handler)


## Disconnects [param handler] from the wrapped state's
## [signal GameState.action_applied] (TR-hud-023, ADR-0016 §8) — call from the
## subscriber's [method Node._exit_tree] so connections never accumulate across
## a match restart within one process (mirrors [CommandInterface]'s
## guarded-disconnect convention). Idempotent: disconnecting a [Callable] that
## isn't connected is a no-op.
func unsubscribe_action_applied(handler: Callable) -> void:
	if _state.action_applied.is_connected(handler):
		_state.action_applied.disconnect(handler)
