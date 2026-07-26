## BaseProduction — TEST STUB for the forward-declared Base & Production contract.
##
## ⚠️ TEMPORARY. This is NOT the real Base & Production system — it is a thin,
## test-controllable stub for the ONE function AP Economy forward-declares
## (ADR-0006). The real [code]BaseProduction[/code] lands with the Base &
## Production epic (ADR-0007 implementation).
##
## [b]DELETE THIS FILE when the real [code]BaseProduction[/code] class is created
## in [code]src/[/code].[/b] GDScript [code]class_name[/code] is project-global,
## so the real class and this stub would collide (duplicate global class name).
## The GDD's forward-declared-stub strategy (TR-apecon-014) explicitly expects
## the stub to be swapped for the real body when that epic lands.
##
## Only ONE stub declaration of [code]class_name BaseProduction[/code] may exist
## in the project — this file. AP-001, AP-003, GS-003 test suites all share it;
## never redeclare it per test file.
##
## Usage in a test:
## [codeblock]
## func before_test() -> void:
##     BaseProduction.reset() # isolation — clear any leaked stub state
##
## func test_income_with_four_outposts() -> void:
##     BaseProduction.set_completed_outpost_count(0, 4)
##     # ... AP.income(state, 0) now sees n = 4 for player 0
## [/codeblock]
class_name BaseProduction
extends RefCounted

## Test-controllable per-player completed-outpost counts. Keyed by player index
## → count. Set via [method set_completed_outpost_count]; cleared by [method reset].
static var _completed_outpost_counts: Dictionary = {}


## Sets the stubbed completed-outpost count for [param player]. The count is
## returned verbatim by [method completed_outpost_count] — including negatives,
## so a test can exercise AP's [code]max(0, n)[/code] clamp (ADR-0006).
static func set_completed_outpost_count(player: int, count: int) -> void:
	_completed_outpost_counts[player] = count


## Forward-declared contract (ADR-0006): number of [param player]'s completed,
## alive outposts. Real signature — [param state] is accepted to match the real
## [code]BaseProduction[/code] call site exactly, but the stub ignores it and
## returns the test-set value (default 0 if unset). [param state] is typed
## [GameState] so callers compile identically against stub and real class.
static func completed_outpost_count(_state: GameState, player: int) -> int:
	return _completed_outpost_counts.get(player, 0)


## Clears all stubbed counts. Call in each test's setup (e.g. [code]before_test[/code])
## so one test's stubbed state never leaks into the next (test-isolation rule).
static func reset() -> void:
	_completed_outpost_counts.clear()
