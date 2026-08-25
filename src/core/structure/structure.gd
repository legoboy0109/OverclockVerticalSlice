## Structure — per-structure runtime behaviour, the [StructureState] sibling of
## [Unit] (ADR-0007/ADR-0008).
##
## [b]Promoted out of `tests/helpers/stubs/structure_stub.gd` on 2026-08-25.[/b]
## That stub carried a real, production-called body — [method GameState.start_turn]
## step 2 dispatches [method reset_turn_flags] for every structure on every turn —
## while living under `tests/`. GDScript's `class_name` is project-global and the
## editor registers it from anywhere in the project, so it worked in-editor and in
## the headless test run, and nothing ever failed.
##
## ⚠ [b]It would have failed on export.[/b] A release preset that excludes `tests/`
## (the normal thing to do, and the reason this project has no
## `export_presets.cfg` yet is only that no export has been attempted) strips the
## script that defines `Structure`, and `start_turn` then calls a method on an
## unresolved global class — a crash on the first turn transition of every match,
## in the build a player would actually run and in no build a developer tests.
## The stub's own header asked for exactly this promotion: "DELETE THIS FILE when
## the real Structure class is created in src/."
##
## The body below is unchanged from the stub apart from the stand-down flag, so
## this is a move, not a rewrite.
##
## Usage:
## [codeblock]
## Structure.reset_turn_flags(structure) # start of the owning player's turn
## [/codeblock]
class_name Structure
extends RefCounted


## Resets [param structure]'s per-turn flags at the start of its owner's turn
## (ADR-0008 step 2, TR-baseprod-009): [member StructureState.has_attacked] back to
## [code]false[/code] (Rule 8, Defensive Structure),
## [member StructureState.units_produced_this_turn] back to [code]0[/code]
## (Rule 7, producers), and [member StructureState.stood_down] back to
## [code]false[/code] — a stand-down lasts one turn, never longer.
##
## Harmless no-op writes on structure types that use none of the three (an Economy
## Outpost never produces or shoots) — the same accepted waste-for-simplicity
## ADR-0007's single-[StructureState] shape already bakes in.
##
## [b]Does not touch [member StructureState.production_cooldown_remaining][/b]:
## that is a multi-turn timer, decremented once per owner-turn by
## [method BaseProduction.advance_build_timers], not a per-turn flag to clear.
## Resetting it here would silently disable the reinforcement cooldown that S6-07
## introduced to break the attrition stalemate.
static func reset_turn_flags(structure: StructureState) -> void:
	structure.has_attacked = false
	structure.units_produced_this_turn = 0
	structure.stood_down = false
