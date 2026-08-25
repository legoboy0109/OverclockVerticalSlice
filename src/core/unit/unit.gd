## Unit — static utility class for [UnitState]-owned pure operations.
##
## Core-layer system per ADR-0007 (entity/stat schema). Holds only pure/static
## functions that take the entity explicitly — no instance fields of its own.
## Mirrors the verb-handler shape ADR-0002/0006 established for
## [code]AP[/code]/[code]Movement[/code]/[code]Combat[/code]/[code]BaseProduction[/code]
## (static, stateless, state/entity passed explicitly).
##
## This formally replaces the Sprint-1 [code]tests/helpers/stubs/unit_stub.gd[/code]
## stand-in — [method reset_turn_flags] keeps the exact same signature the
## stub used, so [code]GameState.start_turn[/code]'s step-2 call site
## ([code]Unit.reset_turn_flags(e)[/code], ADR-0008) needs zero change.
##
## Usage:
## [codeblock]
## if Unit.can_attack(unit):
##     ...
## Unit.reset_turn_flags(unit) # start-of-turn, ADR-0008 step 2
## var copy: UnitState = Unit.clone(unit) # AI lookahead, ADR-0011
## Unit.apply_hp_delta(unit, -5) # sole hp mutator, ADR-0007
## [/codeblock]
class_name Unit
extends RefCounted

## Move-cost floor (ADR-0012 §3): "[code]MIN_MOVE_COST[/code] already exists"
## as a conceptual rule (Movement's Approved [code]move_cost >= 1[/code]), but
## no named symbol existed in [code]src/[/code] before this story. Materializes
## that floor as a real [code]Unit[/code]-owned const so
## [method effective_move_cost]'s [code]max(MIN_MOVE_COST, …)[/code] binds to a
## symbol, not a magic literal.
const MIN_MOVE_COST := 1


## Pure precondition query: can [param unit] currently attack? Combat reads
## this (ADR-0010) but Unit owns/tests it (GDD Rule 2a). O(1).
static func can_attack(unit: UnitState) -> bool:
	return not unit.has_attacked


## Resets [param unit]'s per-turn flags: [member UnitState.has_attacked] back
## to [code]false[/code] and [member UnitState.tiles_moved_this_turn] back to
## [code]0[/code]. Pure, per-instance — no [code]GameState[/code] or Turn
## Manager object required.
##
## Called only from [code]GameState.start_turn[/code]'s step 2 (ADR-0008),
## dispatched per active-player [UnitState] in [code]entity_id[/code]-ascending
## order. Same signature as the Sprint-1 stub it replaces — the call site
## needs zero change.
static func reset_turn_flags(unit: UnitState) -> void:
	unit.has_attacked = false
	unit.tiles_moved_this_turn = 0
	unit.stood_down = false # a stand-down lasts one turn, never longer.


## Returns an independent deep copy of [param unit] via
## [method Resource.duplicate_deep] (ADR-0001/0007) — never a hand-written
## per-field copy. [member UnitState.type] stays a [b]shared reference[/b]
## ([code]===[/code]) across the clone (a path-having, [code]preload()[/code]d
## [UnitTypeDef] template); [member UnitState.current_hp],
## [member EntityState.position], [member UnitState.has_attacked], and
## [member UnitState.tiles_moved_this_turn] all deep-copy independently.
## Mirrors the same bare-no-arg [code]duplicate_deep()[/code] call
## [code]GameState.clone()[/code] uses.
##
## [b]Named [code]clone[/code], not [code]duplicate[/code][/b] (the GDD Rule 2a
## wording): a [code]class_name[/code] script is itself a [Resource], whose
## built-in [method Resource.duplicate] shadows any static [code]duplicate[/code]
## when called as [code]Unit.duplicate(...)[/code]. [code]clone[/code] also
## matches [method GameState.clone] — one deep-copy verb across the codebase.
static func clone(unit: UnitState) -> UnitState:
	return unit.duplicate_deep() as UnitState


## The sole mutator of [member UnitState.current_hp] (ADR-0007, TR-unit-005).
## Applies [param delta] (positive heal or negative damage) and clamps the
## result to [code]0 <= current_hp <= unit.type.hp[/code] — both the ceiling
## (named by the story's AC) and the floor (Combat depends on the [code]0[/code]
## clamp so hp never reads negative). Never assign
## [member UnitState.current_hp] directly outside this function.
static func apply_hp_delta(unit: UnitState, delta: int) -> void:
	unit.current_hp = clampi(unit.current_hp + delta, 0, unit.type.hp)


## The attack value Combat uses (ADR-0010's forward-declared Unit-owned
## contract, TR-unit-006): [param unit]'s base attack (from its
## [UnitTypeDef]) plus the flat Attack-Tech bonus when the unit's owner holds
## Attack Tech. Computed [b]live[/b] every call — never baked at construction —
## so an already-built unit reflects its owner researching Attack Tech mid-match
## (Research tech-unlock flags are permanent, ADR-0018).
##
## The bonus [b]magnitude[/b] is Research-owned and read at call time via the
## forward-declared [method Research.attack_tech_bonus] (mirroring
## [method Research.economy_tech_income_bonus], ADR-0006/0018) — never hardcoded
## in Unit code (control-manifest). The [i]gate[/i] is read directly from
## [member PlayerState.has_attack_tech] (ADR-0001, sole-writer Research). O(1).
##
## Scope: typed to [UnitState] for the VS unit roster (Story 004). Combat may
## widen the contract to [EntityState] for a Defensive Structure's attack during
## Combat-epic wiring; deferred here (no structure uses Attack Tech in the VS).
static func effective_attack(state: GameState, unit: UnitState) -> int:
	var bonus: int = Research.attack_tech_bonus() if state.per_player[unit.owner].has_attack_tech else 0
	return unit.type.attack + bonus


## The defense value Combat's damage formula subtracts (ADR-0010's
## `defense(defender)` term, TR-unit-006/007): [param unit]'s base defense (from
## its [UnitTypeDef], 0 across the whole VS roster) plus the flat Defense-Tech
## bonus when the unit's owner holds Defense Tech. Computed [b]live[/b] every
## call (Research flags are permanent, ADR-0018).
##
## Independent of [method effective_attack]: the [member PlayerState.has_defense_tech]
## gate and the Defense-Tech magnitude never touch Attack Tech's flag/bonus, and
## vice-versa — the two tech folds share this class but read disjoint state. The
## Defense-Tech [b]magnitude[/b] is read at call time from the forward-declared
## [method Research.defense_tech_bonus] (mirroring [method effective_attack]'s
## Research seam) — never hardcoded in Unit code. O(1).
static func effective_defense(state: GameState, unit: UnitState) -> int:
	var bonus: int = Research.defense_tech_bonus() if state.per_player[unit.owner].has_defense_tech else 0
	return unit.type.defense + bonus


## The AP cost to produce a unit of [param unit_type] for [param player]
## (ADR-0012 §3's Faction-identity read-site, TR-unit-011): [param unit_type]'s
## base [member UnitTypeDef.produce_cost] plus [param player]'s faction's
## [member FactionUnitDelta.cost_delta] for that type (0 if the faction carries
## no entry for it — orphaned/absent is inert, [method Faction.unit_delta]),
## floored at [code]1[/code] so a subtractive delta can never reach a free or
## negative-cost verb (CR-3). Computed [b]live[/b] every call, never baked —
## same discipline as [method effective_attack]/[method effective_defense].
##
## Under [code]Factions.NEUTRAL[/code] (empty [member FactionDef.unit_deltas]),
## [code]d[/code] is always [code]null[/code], so this returns exactly
## [code]unit_type.produce_cost[/code] — the ADR-0012 §5 Neutral no-op
## regression pin. Combat stats ([code]attack[/code]/[code]defense[/code]/
## [code]attack_range[/code]) are [b]not[/b] read or folded here — they stay
## faction-identity-locked per ADR-0012 CR-6 (this story does not touch them).
static func effective_produce_cost(state: GameState, unit_type: UnitTypeDef, player: int) -> int:
	var d: FactionUnitDelta = Faction.unit_delta(state.faction_of(player), unit_type)
	return maxi(1, unit_type.produce_cost + (d.cost_delta if d else 0))


## The AP cost to move [param unit_type] one tile for [param player]
## (ADR-0012 §3's Faction-identity read-site, TR-unit-011): [param unit_type]'s
## base [member UnitTypeDef.move_cost] plus [param player]'s faction's
## [member FactionUnitDelta.move_cost_delta] for that type (0 if absent/
## orphaned — [method Faction.unit_delta]), floored at [constant MIN_MOVE_COST]
## so a subtractive delta can never reach a free or negative move (CR-3, the
## conceptual floor Movement already enforced, now a named symbol here).
## Computed live every call, same discipline as the other [code]effective_*[/code]
## functions on this class.
##
## Under [code]Factions.NEUTRAL[/code] this returns exactly
## [code]unit_type.move_cost[/code] (Neutral no-op, ADR-0012 §5). Combat stats
## are not read or folded here — see [method effective_produce_cost]'s note.
static func effective_move_cost(state: GameState, unit_type: UnitTypeDef, player: int) -> int:
	var d: FactionUnitDelta = Faction.unit_delta(state.faction_of(player), unit_type)
	return maxi(MIN_MOVE_COST, unit_type.move_cost + (d.move_cost_delta if d else 0))
