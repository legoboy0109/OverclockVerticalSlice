## Research — TEST STUB for the forward-declared Research / Tech contract.
##
## ⚠️ TEMPORARY. This is NOT the real Research system — it is a thin,
## test-controllable stub for the ONE function AP Economy forward-declares
## (ADR-0006). The real [code]Research[/code] lands with the Research / Tech epic.
##
## [b]DELETE THIS FILE when the real [code]Research[/code] class is created in
## [code]src/[/code].[/b] GDScript [code]class_name[/code] is project-global, so
## the real class and this stub would collide (duplicate global class name).
##
## Only ONE stub declaration of [code]class_name Research[/code] may exist in the
## project — this file. AP-001, AP-003, GS-003 test suites all share it; never
## redeclare it per test file.
##
## GS-003 (ADR-0008) extends this stub with [method advance_research_timers] —
## [method GameState.start_turn]'s step-3 forward-declared research-timer
## contract — plus [method queue_completion], the test hook that drives it.
##
## [b]Design note — this stub returns a test-set OPAQUE value, it does NOT compute
## the cap.[/b] Per ADR-0006, [method economy_tech_income_bonus] returns the
## [i]fully-capped[/i] term (already
## [code]has_economy_tech ? ECONOMY_TECH_INCOME_BONUS × min(n, ECONOMY_TECH_TIER_THRESHOLD) : 0[/code]),
## and AP adds it [b]verbatim[/b], never re-applying the cap. Keeping the stub a
## dumb value-holder (rather than re-deriving the formula) is deliberate: it
## keeps AP-001's double-cap regression test meaningful — the test sets the
## expected already-capped value (e.g. 6 for BOTH n=6 and n=7, proving the cap
## re-engages) and asserts AP adds it as-is. If the stub itself computed the cap,
## it could hide or encode the very bug the test exists to catch (the 2026-07-24
## architecture-review C3 defect: 36 vs 6 at n=6).
##
## Usage in a test:
## [codeblock]
## func before_test() -> void:
##     Research.reset()
##
## func test_income_econ_tech_held_n6_and_n7_both_add_capped_6() -> void:
##     Research.set_economy_tech_income_bonus(0, 6) # already-capped term
##     # ... AP.income(state, 0) must add exactly +6, never re-cap
## [/codeblock]
class_name Research
extends RefCounted

## Test-controllable per-player economy-tech income term (already capped). Keyed
## by player index → term. Set via [method set_economy_tech_income_bonus];
## cleared by [method reset]. Unset players contribute 0 (the un-researched case).
static var _economy_tech_income_bonus: Dictionary = {}

## Test-controllable per-player queued research-timer completions (GS-003,
## ADR-0008). Keyed by player index -> count of completions
## [method advance_research_timers] should synthesize on its next call for
## that player. Set via [method queue_completion]; cleared by [method reset].
static var _queued_completions: Dictionary = {}


## Sets the stubbed, [b]already-capped[/b] economy-tech income term for
## [param player]. This is the value AP adds verbatim — pass what the AC expects
## (0 when the player lacks Economy Tech; the capped bonus when they hold it).
static func set_economy_tech_income_bonus(player: int, bonus: int) -> void:
	_economy_tech_income_bonus[player] = bonus


## Forward-declared contract (ADR-0006): [param player]'s fully-capped economy-tech
## income bonus, added verbatim by AP. Real signature — [param state] is accepted
## to match the real call site exactly, but the stub ignores it and returns the
## test-set value (default 0 if unset — the un-researched contribution).
static func economy_tech_income_bonus(_state: GameState, player: int) -> int:
	return _economy_tech_income_bonus.get(player, 0)


## Test hook (GS-003, ADR-0008): queues [param count] research completions for
## [param player]'s next [method advance_research_timers] call — used to
## simulate "a tech finishes researching this same start-of-turn" without a
## real [code]StructureState[/code] Lab / research-timer model. Each queued
## completion (a) sets [param player]'s stubbed
## [method economy_tech_income_bonus] to [param bonus] (so
## [code]AP.reset_turn[/code]'s same-turn income snapshot, step 4, observes
## it — mirrors the permanent-unlock semantics of the real
## [code]has_economy_tech[/code] flag) and (b) causes
## [method advance_research_timers] to append one [TechCompletedEvent].
## [param bonus] defaults to 1 — any nonzero value is sufficient to prove the
## same-turn-observed contract; a test asserting an exact income total should
## pass the value it expects [method economy_tech_income_bonus] to report.
static func queue_completion(player: int, bonus: int = 1) -> void:
	_queued_completions[player] = _queued_completions.get(player, 0) + 1
	_economy_tech_income_bonus[player] = bonus


## Forward-declared contract (ADR-0008): advances [param player]'s research
## timers for [method GameState.start_turn]'s step 3. Stub behavior: consumes
## every completion queued via [method queue_completion] for [param player],
## returning one [TechCompletedEvent] per completion (the economy-tech bonus
## itself was already applied at queue time, mirroring the real
## once-true-never-false permanence of a tech-unlock flag). Returns
## [code][][/code] when nothing is queued (the default — most turns complete
## no research). [param state] is accepted, unused, to match the real call
## site's signature.
static func advance_research_timers(_state: GameState, player: int) -> Array:
	var pending: int = _queued_completions.get(player, 0)
	if pending <= 0:
		return []
	_queued_completions[player] = 0
	var events: Array = []
	for _i: int in pending:
		events.append(TechCompletedEvent.new())
	return events


## Clears all stubbed terms and queued completions. Call in each test's setup
## so one test's stubbed state never leaks into the next (test-isolation rule).
static func reset() -> void:
	_economy_tech_income_bonus.clear()
	_queued_completions.clear()
