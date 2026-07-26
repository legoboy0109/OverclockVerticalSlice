## StructureState — TEST STUB for the forward-declared Unit & Structure
## Entity/Stat Schema (ADR-0007)'s [code]StructureState[/code] concrete
## [EntityState] subclass.
##
## ⚠️ TEMPORARY. This is NOT the real [code]StructureState[/code] — it is a
## minimal, test-controllable stand-in carrying just enough shape (one
## test-observable per-turn flag) for [method GameState.start_turn]'s step 2
## (the [code]e is StructureState[/code] dispatch) to be exercised before the
## Unit & Structure Entity/Stat Schema epic lands. The real
## [code]StructureState[/code] lands with that epic (ADR-0007).
##
## [b]DELETE THIS FILE when the real [code]StructureState[/code] class is
## created in [code]src/[/code].[/b] GDScript [code]class_name[/code] is
## project-global, so the real class and this stub would collide (duplicate
## global class name).
##
## Only ONE stub declaration of [code]class_name StructureState[/code] may
## exist in the project — this file. GS-003's test suite is the only current
## consumer; never redeclare it per test file.
##
## Usage in a test:
## [codeblock]
## var s := StructureState.new()
## s.entity_id = 6
## s.owner = 0
## s.has_acted = true
## state.entities_by_id[s.entity_id] = s
## [/codeblock]
class_name StructureState
extends EntityState

## Test-observable per-turn flag, mirroring the real (not-yet-implemented)
## Base & Production system's per-turn structure flags (e.g.
## [code]has_attacked[/code] for a Defensive Structure, base-production.md
## States and Transitions). Defaults [code]true[/code] so a test can assert
## [method Structure.reset_turn_flags] actually flips it to [code]false[/code]
## rather than observing an already-false default.
@export var has_acted: bool = true
