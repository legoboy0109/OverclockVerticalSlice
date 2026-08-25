## UnitConfig — Unit-owned global movement tuning constants (fixed-point).
##
## Core-layer config asset per ADR-0009. A dedicated [Resource] (`.tres`),
## mirroring [EconomyConfig]'s config-as-Resource pattern (ADR-0006) — never
## GDScript `const`s, never stored on [GameState] (it is static, shared,
## read-only tuning data, so it must never ride along on
## [method GameState.clone]'s `duplicate_deep()` pass — same reasoning as
## [EconomyConfig]).
##
## Loaded once at boot by the thin, logic-free [code]UnitBalance[/code] Autoload
## and read via [code]UnitBalance.units[/code].
##
## [b]Ownership:[/b] `SOFT_MOVE_PENALTY` is a Unit-owned [b]global[/b] constant
## (not per-type — ADR-0007's [UnitTypeDef] is per-type and the wrong home). It
## is stored fixed-point as [member soft_move_penalty_x10] (an integer, ×10) so
## the over-cap surcharge is computed with integer ceil-division — no float ever
## enters the AP path (the Integer-AP invariant, TR-movement-011). Movement's
## reachable-search and its move-billing both call [method surcharge_for], the
## single shared over-cap primitive.
##
## Usage:
## [codeblock]
## var surcharge: int = UnitBalance.surcharge_for(unit.move_cost) # ceil(cost * 2.0)
## [/codeblock]
class_name UnitConfig
extends Resource

## Over-cap move surcharge multiplier, fixed-point ×10: `20` = 2.0 (the VS
## default; GDD range 1.5–3.0 → 15–30). Every over-cap tile costs
## `ceil(move_cost * soft_move_penalty_x10 / 10)` AP. Integer, never a float.
@export var soft_move_penalty_x10: int = 20


## ⛔ [b]`surcharge_for()` used to live here and now lives on [code]UnitBalance[/code]
## (moved 2026-08-25, S7-02). Do not move it back.[/b]
##
## Its body read [code]UnitBalance.units.soft_move_penalty_x10[/code] — and
## [code]UnitBalance[/code] holds [code]var units: UnitConfig = preload(...)[/code],
## so this script and that Autoload each needed the other resolved first. GDScript
## must resolve an Autoload's script type to typecheck a member access on it, so
## the cycle is a [b]parse-time[/b] one, not merely a runtime ordering quirk.
##
## ⚠ [b]It cost nothing in the editor and nothing in the test suite, and it broke
## the exported build outright:[/b]
## [codeblock]
## SCRIPT ERROR: Parse Error: Could not resolve external class member "units".
##           at: GDScript::reload (res://src/core/unit/unit_config.gd:40)
## ERROR: Failed to load script "res://src/core/unit/unit_config.gd"
## [/codeblock]
## The editor tolerates the cycle because it holds a fully-populated global class
## cache and re-parses incrementally; a packaged build resolves each script once,
## in dependency order, and there is no valid order for a cycle. The failure is
## therefore invisible in every build a developer runs and fatal in the one a
## player runs — found only when the project's first-ever export was attempted.
##
## ★ The five sibling configs ([EconomyConfig], [CombatConfig],
## [BaseProductionConfig], [AIConfig], [HUDConfig]) never referenced their
## Autoloads. This file was the sole exception, so the fix is to make it match its
## siblings rather than to invent a pattern.
##
## ⇒ [b]The rule: a config [Resource] holds data and pure functions over data it is
## given. Reaching back to the Autoload that loads it is what creates the cycle.[/b]
## Pinned by `tests/unit/export_safety_test.gd`.


## Pure integer ceil-division primitive: `ceil(move_cost * penalty_x10 / 10)`.
## Takes the penalty explicitly (dependency injection) so the surcharge math is
## unit-testable without the [code]UnitBalance[/code] Autoload — the boundary
## cases (e.g. penalty 1.5 → `ceil(1 × 1.5) = 2`, not 1) are tested against this
## form. [method UnitBalance.surcharge_for] is the Autoload-reading wrapper over
## it. O(1).
static func surcharge_with_penalty(move_cost: int, penalty_x10: int) -> int:
	return (move_cost * penalty_x10 + 9) / 10   # integer ceil-division (+9 = +(10-1))
