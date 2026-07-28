## CombatBalance — Autoload, logic-free lookup for Combat's tuning config.
##
## Core-layer Autoload per ADR-0010, a sibling of [code]Balance[/code]
## (ADR-0006) and [code]UnitBalance[/code] (ADR-0009), mirroring their thin
## "read-only lookup convenience" idiom ([code]MatchService[/code], ADR-0001).
## Loads [CombatConfig] once at boot and exposes it by reference. Never
## mutates, validates, or interprets anything — [code]Combat[/code] reads
## [code]CombatBalance.combat.*[/code] directly; only this Autoload decides
## where the `.tres` lives.
##
## Registered in `project.godot`'s `[autoload]` section so [code]Combat[/code]'s
## static functions can read [code]CombatBalance.combat[/code] as a bare
## global reference.
extends Node

## The loaded [CombatConfig] tuning-constants resource. No other fields. No
## methods beyond direct property access.
var combat: CombatConfig = preload("res://data/combat/combat_config.tres")
