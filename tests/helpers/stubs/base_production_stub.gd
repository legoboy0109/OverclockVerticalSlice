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
## GS-003 (ADR-0008) extends this stub with [method advance_build_timers] —
## [method GameState.start_turn]'s step-3 forward-declared build-timer
## contract — plus [method queue_completion], the test hook that drives it.
##
## Usage in a test:
## [codeblock]
## func before_test() -> void:
##     BaseProduction.reset() # isolation — clear any leaked stub state
##
## func test_income_with_four_outposts() -> void:
##     BaseProduction.set_completed_outpost_count(0, 4)
##     # ... AP.income(state, 0) now sees n = 4 for player 0
##
## func test_start_turn_income_observes_same_turn_completion() -> void:
##     BaseProduction.queue_completion(0) # one outpost finishes this turn
##     state.start_turn(0)
##     # ... AP.reset_turn's step-4 snapshot already reflects it
## [/codeblock]
class_name BaseProduction
extends RefCounted

## Test-controllable per-player completed-outpost counts. Keyed by player index
## → count. Set via [method set_completed_outpost_count]; cleared by [method reset].
static var _completed_outpost_counts: Dictionary = {}

## Test-controllable per-player queued build-timer completions (GS-003,
## ADR-0008). Keyed by player index -> count of completions
## [method advance_build_timers] should synthesize on its next call for that
## player. Set via [method queue_completion]; cleared by [method reset].
static var _queued_completions: Dictionary = {}


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


## Test hook (GS-003, ADR-0008): queues [param count] build completions for
## [param player]'s next [method advance_build_timers] call — used to
## simulate "an outpost finishes building this same start-of-turn" without a
## real [code]StructureState[/code]/build-timer model. Each queued completion
## (a) bumps [method completed_outpost_count]'s stubbed value for [param player]
## by 1 so [code]AP.reset_turn[/code]'s same-turn income snapshot (step 4)
## observes it, and (b) causes [method advance_build_timers] to append one
## [StructureCompletedEvent].
static func queue_completion(player: int, count: int = 1) -> void:
	_queued_completions[player] = _queued_completions.get(player, 0) + count


## Forward-declared contract (ADR-0008): advances [param player]'s build
## timers for [method GameState.start_turn]'s step 3. Stub behavior: consumes
## every completion queued via [method queue_completion] for [param player],
## bumping [method completed_outpost_count]'s stubbed value by the same
## amount (so the step-4 income snapshot sees it) and returning one
## [StructureCompletedEvent] per completion. Returns [code][][/code] when
## nothing is queued (the default — most turns complete nothing). [param state]
## is accepted, unused, to match the real call site's signature.
static func advance_build_timers(_state: GameState, player: int) -> Array:
	var pending: int = _queued_completions.get(player, 0)
	if pending <= 0:
		return []
	_queued_completions[player] = 0
	var current: int = _completed_outpost_counts.get(player, 0)
	_completed_outpost_counts[player] = current + pending
	var events: Array = []
	for _i: int in pending:
		events.append(StructureCompletedEvent.new())
	return events


## Clears all stubbed counts and queued completions. Call in each test's
## setup (e.g. [code]before_test[/code]) so one test's stubbed state never
## leaks into the next (test-isolation rule).
static func reset() -> void:
	_completed_outpost_counts.clear()
	_queued_completions.clear()
