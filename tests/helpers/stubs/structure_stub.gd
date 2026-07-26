## Structure — TEST STUB for the forward-declared Base & Production
## per-turn-flag contract.
##
## ⚠️ TEMPORARY. This is NOT the real Base & Production system — it is a
## thin, test-controllable stub for the ONE function
## [method GameState.start_turn] forward-declares (ADR-0008):
## [code]Structure.reset_turn_flags(structure)[/code]. The real
## [code]Structure[/code] lands with the Base & Production epic.
##
## [b]DELETE THIS FILE when the real [code]Structure[/code] class is created
## in [code]src/[/code].[/b] GDScript [code]class_name[/code] is
## project-global, so the real class and this stub would collide (duplicate
## global class name).
##
## Only ONE stub declaration of [code]class_name Structure[/code] may exist in
## the project — this file. GS-003's test suite is the only current consumer;
## never redeclare it per test file.
##
## Usage in a test:
## [codeblock]
## var s := StructureState.new()
## s.owner = 0
## s.has_acted = true
## Structure.reset_turn_flags(s)
## # s.has_acted == false
## [/codeblock]
class_name Structure
extends RefCounted


## Forward-declared contract (ADR-0008, base-production.md States and
## Transitions): resets [param structure]'s per-turn flags. Stub behavior:
## flips the stub [StructureState]'s single test-observable flag
## ([member StructureState.has_acted]) back to [code]false[/code] — enough
## for [method GameState.start_turn]'s step 2 to be assertable without
## modeling the real Base & Production system's full flag set
## (e.g. [code]units_produced_this_turn[/code]).
static func reset_turn_flags(structure: StructureState) -> void:
	structure.has_acted = false
