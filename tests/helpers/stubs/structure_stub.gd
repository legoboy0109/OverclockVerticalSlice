## Structure — TEST STUB for the forward-declared Base & Production
## per-turn-flag contract.
##
## ⚠️ TEMPORARY. This is NOT the real Base & Production system — it is a
## thin stub for the ONE function [method GameState.start_turn]
## forward-declares (ADR-0008): [code]Structure.reset_turn_flags(structure)[/code].
##
## [b]DELETE THIS FILE when the real [code]Structure[/code] class is created
## in [code]src/[/code].[/b] GDScript [code]class_name[/code] is
## project-global, so the real class and this stub would collide (duplicate
## global class name). Base & Production Story 002 deliberately keeps this
## body living here rather than moving it to a real [code]class_name Structure[/code]
## (its approved stub-migration notes: creating a real [code]Structure[/code]
## class now would collide with nothing today, but is left for a later story
## once more per-structure runtime behavior needs a home there).
##
## Only ONE stub declaration of [code]class_name Structure[/code] may exist in
## the project — this file.
##
## Story 001 (Structure Schema, Templates & Config) landed the real
## [code]StructureState[/code] (ADR-0007) — that schema has no [code]has_acted[/code]
## field; the per-turn combat flag is [member StructureState.has_attacked]. This
## stub flips that real field.
##
## Base & Production Story 002 (ADR-0008 step 2 body, TR-baseprod-009) extends
## this to also reset [member StructureState.units_produced_this_turn] to
## [code]0[/code] — the full per-turn flag set [method GameState.start_turn]'s
## step 2 resets for a player's structures. This is the real body of that
## forward-declared contract now (plain, deterministic field writes — not
## test-controllable state the way [code]base_production_stub.gd[/code] was;
## that stub is deleted by this story).
##
## Usage in a test:
## [codeblock]
## var s := StructureState.new()
## s.owner = 0
## s.has_attacked = true
## s.units_produced_this_turn = 2
## Structure.reset_turn_flags(s)
## # s.has_attacked == false, s.units_produced_this_turn == 0
## [/codeblock]
class_name Structure
extends RefCounted


## Forward-declared contract (ADR-0008, base-production.md States and
## Transitions; ADR-0017 D1, TR-baseprod-009): resets [param structure]'s
## per-turn flags — [member StructureState.has_attacked] back to
## [code]false[/code] (Rule 8, Defensive Structure) and
## [member StructureState.units_produced_this_turn] back to [code]0[/code]
## (Rule 7, producers). Harmless no-op writes on structure types that don't
## use one of the two fields (e.g. an Economy Outpost's
## [code]units_produced_this_turn[/code]) — the same accepted waste-for-
## simplicity ADR-0007's single-[code]StructureState[/code] shape already
## bakes in.
static func reset_turn_flags(structure: StructureState) -> void:
	structure.has_attacked = false
	structure.units_produced_this_turn = 0
