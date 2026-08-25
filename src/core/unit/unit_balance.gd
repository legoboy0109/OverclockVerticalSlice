## UnitBalance — Autoload, logic-free lookup for Unit System's movement tuning.
##
## Core-layer Autoload per ADR-0009, a sibling of [code]Balance[/code]
## (ADR-0006) and mirroring its thin "read-only lookup convenience" idiom
## ([code]MatchService[/code], ADR-0001). Loads [UnitConfig] once at boot and
## exposes it by reference. Never mutates, validates, or interprets anything —
## systems read [code]UnitBalance.units.*[/code] directly (e.g.
## [method surcharge_for] reads it internally); only this Autoload
## decides where the `.tres` lives.
##
## A dedicated sibling Autoload rather than a field on [code]Balance[/code]
## keeps AP-Economy's config (`Balance.economy`) and Unit System's config
## (`UnitBalance.units`) owned by their respective epics — no cross-epic edit.
##
## Registered in `project.godot`'s `[autoload]` section so movement code can read
## [code]UnitBalance.units[/code] as a bare global reference.
extends Node

## The loaded [UnitConfig] tuning-constants resource. No other fields. No
## methods beyond direct property access.
var units: UnitConfig = preload("res://data/units/unit_config.tres")


## The flat AP surcharge for one over-cap tile at [param move_cost]:
## `ceil(move_cost * SOFT_MOVE_PENALTY)`, reading the live-tunable penalty from
## [member units]. This is the single-arg form Movement calls (ADR-0009's
## surcharge call site). Always ≥ `move_cost` and always an integer. O(1).
##
## ★ [b]This wrapper lives here, not on [UnitConfig], and that placement is the
## fix for a defect rather than a preference.[/b] On [UnitConfig] its body read
## [code]UnitBalance.units[/code] while this Autoload holds
## [code]preload(...unit_config.tres)[/code] — a parse-time cycle that the editor
## and the headless suite both resolve and that a packaged build cannot. See the
## block comment in `unit_config.gd` for the full failure.
##
## ⚠ This is the one piece of logic on an Autoload documented above as
## "logic-free". Deliberate, and the narrowest available exception: the dependency
## only runs one way here (this Autoload already knows [UnitConfig]; [UnitConfig]
## must not know this Autoload), and the real arithmetic stays in
## [method UnitConfig.surcharge_with_penalty], which remains pure and injectable.
func surcharge_for(move_cost: int) -> int:
	return UnitConfig.surcharge_with_penalty(move_cost, units.soft_move_penalty_x10)
