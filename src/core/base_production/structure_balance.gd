## StructureBalance — Autoload, logic-free lookup for Base & Production's
## tuning config.
##
## Core-layer Autoload per ADR-0017 D6, a sibling of [code]Balance[/code]/
## [code]UnitBalance[/code]/[code]CombatBalance[/code] and mirroring their
## thin "read-only lookup convenience" idiom. Loads [BaseProductionConfig]
## once at boot and exposes it by reference. Never mutates, validates, or
## interprets anything — systems read
## [code]StructureBalance.base_production.*[/code] directly; only this
## Autoload decides where the `.tres` lives.
##
## A dedicated sibling Autoload rather than a field on [code]Balance[/code]
## keeps AP Economy's config (`Balance.economy`), Unit System's config
## (`UnitBalance.units`), Combat's config (`CombatBalance.combat`), and Base &
## Production's config (`StructureBalance.base_production`) owned by their
## respective epics — no cross-epic edit.
##
## Registered in `project.godot`'s `[autoload]` section so Base & Production
## code (and cross-system readers like Combat's `defensive_attack_cost`) can
## read [code]StructureBalance.base_production[/code] as a bare global
## reference.
extends Node

## The loaded [BaseProductionConfig] tuning-constants resource. No other
## fields. No methods beyond direct property access.
var base_production: BaseProductionConfig = preload("res://data/base_production/base_production_config.tres")
