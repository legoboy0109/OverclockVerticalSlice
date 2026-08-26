## UnitTypes — Autoload, logic-free registry of the VS unit roster.
##
## Core-layer Autoload per ADR-0007 (entity/stat schema), mirroring [code]Balance[/code]'s
## thin "read-only lookup convenience" idiom (ADR-0006). [code]preload()[/code]s each
## [UnitTypeDef] `.tres` once at boot and exposes it by reference. Never [code]load()[/code]
## a unit `.tres` outside this registry (control-manifest forbidden pattern, ADR-0007).
##
## Registered in `project.godot`'s `[autoload]` section so any system can read
## [code]UnitTypes.SCOUT[/code] etc. as a bare global reference.
extends Node

## The only thing an HQ produces (user decision 2026-08-25). Defenceless
## (`attack_range = 0` yields no legal targets at all), and CONSUMED by whatever it
## builds — so its cost is really a surcharge on every structure in the game.
const BUILDER: UnitTypeDef = preload("res://data/units/builder.tres")
const SCOUT: UnitTypeDef = preload("res://data/units/scout.tres")
const TROOPER: UnitTypeDef = preload("res://data/units/trooper.tres")
const HEAVY: UnitTypeDef = preload("res://data/units/heavy.tres")
const SNIPER: UnitTypeDef = preload("res://data/units/sniper.tres")

## ★ Every unit type in the roster, in declaration order.
##
## Exists so a coverage check can enumerate the roster instead of transcribing it.
## ⚠ The art-coverage guard used to hold its OWN hand-written list of types, which
## meant it only ever guarded the types someone had remembered to add — the Builder
## shipped with no sprite and the suite stayed green, which is precisely the failure
## that list was written to prevent. Adding a `.tres` to this registry now
## automatically extends the guard.
const ALL: Array[UnitTypeDef] = [BUILDER, SCOUT, TROOPER, HEAVY, SNIPER]
