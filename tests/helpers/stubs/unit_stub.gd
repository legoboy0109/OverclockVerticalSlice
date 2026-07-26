## Unit — TEST STUB for the forward-declared Unit System per-turn-flag contract.
##
## ⚠️ TEMPORARY. This is NOT the real Unit System — it is a thin,
## test-controllable stub for the ONE function [method GameState.start_turn]
## forward-declares (ADR-0008): [code]Unit.reset_turn_flags(unit)[/code]. The
## real [code]Unit[/code] lands with the Unit System epic.
##
## [b]DELETE THIS FILE when the real [code]Unit[/code] class is created in
## [code]src/[/code].[/b] GDScript [code]class_name[/code] is project-global,
## so the real class and this stub would collide (duplicate global class name).
##
## Only ONE stub declaration of [code]class_name Unit[/code] may exist in the
## project — this file. GS-003's test suite is the only current consumer;
## never redeclare it per test file.
##
## Usage in a test:
## [codeblock]
## var u := UnitState.new()
## u.owner = 0
## u.has_acted = true
## Unit.reset_turn_flags(u)
## # u.has_acted == false
## [/codeblock]
class_name Unit
extends RefCounted


## Forward-declared contract (ADR-0008, unit-system.md Rule 2a): resets
## [param unit]'s per-turn flags. Stub behavior: flips the stub
## [UnitState]'s single test-observable flag ([member UnitState.has_acted])
## back to [code]false[/code] — enough for [method GameState.start_turn]'s
## step 2 to be assertable (reset happened / was skipped for the right
## entities) without modeling the real Unit System's full flag set
## (e.g. [code]tiles_moved_this_turn[/code]).
static func reset_turn_flags(unit: UnitState) -> void:
	unit.has_acted = false
