## Research — the forward-declared Research / Tech contract (ADR-0006/0008/0018).
##
## [b]Promoted out of `tests/helpers/stubs/research_stub.gd` on 2026-08-25 (S7-01),
## for exactly the reason [Structure] was promoted the day before.[/b] This class
## was declared under `tests/` while production code called it in three places:
## [br]• [method Unit.effective_attack] → [method attack_tech_bonus]
## [br]• [method Unit.effective_defense] → [method defense_tech_bonus]
## [br]• [method GameState.start_turn] step 3 → [method advance_research_timers],
##   [b]unconditionally, on every turn of every match[/b]
##
## ⚠ [b]It would have failed on export.[/b] GDScript `class_name` is project-global
## and the editor registers it from anywhere in the project, so it resolved
## in-editor and in the headless test run and nothing ever failed. A release preset
## that excludes `tests/` — the normal thing to do — strips the script that defines
## `Research`, and both `unit.gd` and `game_state.gd` then fail to resolve a global
## class they reference. That is the core of the game, in the build a player would
## actually run and in no build a developer tests.
##
## ★ This is the [b]second[/b] instance of the same defect found in two days. The
## guard against a third is automated: `tests/unit/export_safety_test.gd` fails if
## any symbol declared under `tests/` is referenced from `src/` or `tools/`.
##
## [b]Still a forward declaration, and deliberately so.[/b] The real Research / Tech
## epic (ADR-0018: [TechDef] templates, research timers, per-Lab progress) is not
## built in this corpus. What lives here is the minimum production surface its
## callers already depend on, with real defaults, plus the setters those callers'
## tests use to drive it. When the epic lands, the magnitudes should come from
## [TechDef] templates and the `set_*` / [method queue_completion] / [method reset]
## control surface should go with them.
##
## ⚠ [b]Do not read the `set_*` helpers as an invitation.[/b] Nothing in `src/` may
## call them — they exist so the forward declaration is drivable until the epic
## replaces it, and `export_safety_test.gd` does not police that. Production reads
## the three getters and nothing else.
##
## [b]Design note — [method economy_tech_income_bonus] returns an OPAQUE, already-capped
## value, it does NOT compute the cap.[/b] Per ADR-0006 it returns the fully-capped
## term and AP adds it [b]verbatim[/b], never re-applying the cap. Keeping it a dumb
## value-holder rather than re-deriving the formula is deliberate: it keeps AP-001's
## double-cap regression test meaningful — the test sets the expected already-capped
## value (e.g. 6 for BOTH n=6 and n=7, proving the cap re-engages) and asserts AP
## adds it as-is. If this computed the cap it could hide the very bug the test exists
## to catch (the 2026-07-24 architecture-review C3 defect: 36 vs 6 at n=6).
##
## ⚠ No production call site remains for [method economy_tech_income_bonus]: S6-01
## re-based income on research tiers and deleted the outpost-and-econ-tech path.
## Kept because AP-001's regression tests still pin the contract, and because the
## real epic will need it back.
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

## Test-controllable flat Attack-Tech bonus magnitude (Unit-004, TR-unit-006).
## The real Research epic reads this from the Attack-Tech [TechDef] template
## (ADR-0018); the stub returns a test-set value. Default 1 mirrors the GDD's
## illustrative RESEARCH_ATK_BONUS = +1, but tests should set it explicitly
## (e.g. +3) to prove Unit code reads the value rather than hardcoding it.
static var _attack_tech_bonus: int = 1

## Test-controllable flat Defense-Tech bonus magnitude (Unit-005, TR-unit-006).
## Independent of [member _attack_tech_bonus] — the two tech magnitudes never
## alias. Same forward-declaration semantics as Attack Tech.
static var _defense_tech_bonus: int = 1


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


## Sets the stubbed flat Attack-Tech bonus magnitude (Unit-004). Pass what the
## AC expects [method attack_tech_bonus] to report.
static func set_attack_tech_bonus(bonus: int) -> void:
	_attack_tech_bonus = bonus


## Forward-declared contract (ADR-0018, TR-unit-006): the flat Attack-Tech bonus
## magnitude Unit System's [method Unit.effective_attack] adds when the unit's
## owner holds Attack Tech. Flat (not per-player) — the owner gate is read from
## [member PlayerState.has_attack_tech] by the caller. Real impl reads the
## Attack-Tech [TechDef] magnitude; the stub returns the test-set value.
static func attack_tech_bonus() -> int:
	return _attack_tech_bonus


## Sets the stubbed flat Defense-Tech bonus magnitude (Unit-005).
static func set_defense_tech_bonus(bonus: int) -> void:
	_defense_tech_bonus = bonus


## Forward-declared contract (ADR-0018, TR-unit-006): the flat Defense-Tech bonus
## magnitude Unit System's [method Unit.effective_defense] adds when the unit's
## owner holds Defense Tech. Flat (not per-player) — the owner gate is read from
## [member PlayerState.has_defense_tech] by the caller. Real impl reads the
## Defense-Tech [TechDef] magnitude; the stub returns the test-set value.
static func defense_tech_bonus() -> int:
	return _defense_tech_bonus


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
	_attack_tech_bonus = 1
	_defense_tech_bonus = 1
