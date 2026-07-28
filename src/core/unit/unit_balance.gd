## UnitBalance — Autoload, logic-free lookup for Unit System's movement tuning.
##
## Core-layer Autoload per ADR-0009, a sibling of [code]Balance[/code]
## (ADR-0006) and mirroring its thin "read-only lookup convenience" idiom
## ([code]MatchService[/code], ADR-0001). Loads [UnitConfig] once at boot and
## exposes it by reference. Never mutates, validates, or interprets anything —
## systems read [code]UnitBalance.units.*[/code] directly (e.g.
## [method UnitConfig.surcharge_for] reads it internally); only this Autoload
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
