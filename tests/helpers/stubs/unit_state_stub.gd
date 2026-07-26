## UnitState — TEST STUB for the forward-declared Unit & Structure Entity/Stat
## Schema (ADR-0007)'s [code]UnitState[/code] concrete [EntityState] subclass.
##
## ⚠️ TEMPORARY. This is NOT the real [code]UnitState[/code] — it is a
## minimal, test-controllable stand-in carrying just enough shape (one
## test-observable per-turn flag) for [method GameState.start_turn]'s step 2
## (the [code]e is UnitState[/code] dispatch) to be exercised before the
## Unit & Structure Entity/Stat Schema epic lands. The real [code]UnitState[/code]
## lands with that epic (ADR-0007).
##
## [b]DELETE THIS FILE when the real [code]UnitState[/code] class is created
## in [code]src/[/code].[/b] GDScript [code]class_name[/code] is
## project-global, so the real class and this stub would collide (duplicate
## global class name).
##
## Only ONE stub declaration of [code]class_name UnitState[/code] may exist in
## the project — this file. GS-003's test suite is the only current consumer;
## never redeclare it per test file.
##
## Usage in a test:
## [codeblock]
## var u := UnitState.new()
## u.entity_id = 5
## u.owner = 0
## u.has_acted = true
## state.entities_by_id[u.entity_id] = u
## [/codeblock]
class_name UnitState
extends EntityState

## Test-observable per-turn flag, mirroring the real (not-yet-implemented)
## Unit System's [code]has_attacked[/code]-shaped fields (unit-system.md Rule
## 2a). Defaults [code]true[/code] so a test can assert [method Unit.reset_turn_flags]
## actually flips it to [code]false[/code] rather than observing an
## already-false default.
@export var has_acted: bool = true
