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
