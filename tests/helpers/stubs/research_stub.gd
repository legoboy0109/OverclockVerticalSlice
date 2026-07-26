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


## Clears all stubbed terms. Call in each test's setup so one test's stubbed
## state never leaks into the next (test-isolation rule).
static func reset() -> void:
	_economy_tech_income_bonus.clear()
