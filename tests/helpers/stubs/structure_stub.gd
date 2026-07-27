## Structure — TEST STUB for the forward-declared Base & Production
## per-turn-flag contract.
##
## ⚠️ TEMPORARY. This is NOT the real Base & Production system — it is a
## thin, test-controllable stub for the ONE function
## [method GameState.start_turn] forward-declares (ADR-0008):
## [code]Structure.reset_turn_flags(structure)[/code]. The real
## [code]Structure[/code] (full flag-reset body — [code]units_produced_this_turn[/code]
## included) lands with the Base & Production epic's Story 003.
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
## Story 001 (Structure Schema, Templates & Config) landed the real
## [code]StructureState[/code] (ADR-0007) — that schema has no [code]has_acted[/code]
## field; the per-turn combat flag is [member StructureState.has_attacked]. This
## stub is updated to flip that real field so it keeps compiling against the
## real schema. It still only resets the one flag [method GameState.start_turn]'s
## step 2 needs to be assertable pre-Story-003 — [code]units_produced_this_turn[/code]
## reset is that story's.
##
## Usage in a test:
## [codeblock]
## var s := StructureState.new()
## s.owner = 0
## s.has_attacked = true
## Structure.reset_turn_flags(s)
## # s.has_attacked == false
## [/codeblock]
class_name Structure
extends RefCounted


## Forward-declared contract (ADR-0008, base-production.md States and
## Transitions): resets [param structure]'s per-turn flags. Stub behavior:
## flips the real [StructureState]'s combat flag ([member StructureState.has_attacked])
## back to [code]false[/code] — enough for [method GameState.start_turn]'s step
## 2 to be assertable without modeling the real Base & Production system's
## full flag set (e.g. [code]units_produced_this_turn[/code], Story 003).
static func reset_turn_flags(structure: StructureState) -> void:
	structure.has_attacked = false
