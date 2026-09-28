## Abilities — thin registry of every [AbilityDef] (ADR-0007 idiom, like UnitTypes).
## [member ALL] is the stable order menus and the AI walk.
extends Node

const REPAIR: AbilityDef = preload("res://data/abilities/repair.tres")
const FORTIFY: AbilityDef = preload("res://data/abilities/fortify.tres")
const DEMOLISH: AbilityDef = preload("res://data/abilities/demolish.tres")
const SELF_DESTRUCT: AbilityDef = preload("res://data/abilities/self_destruct.tres")
const CAPTURE_VEHICLE: AbilityDef = preload("res://data/abilities/capture_vehicle.tres")
const PARADROP: AbilityDef = preload("res://data/abilities/paradrop.tres")
## Implicit: every passenger-capable unit may use these without listing them (TP-3).
const EMBARK: AbilityDef = preload("res://data/abilities/embark.tres")
const DISEMBARK: AbilityDef = preload("res://data/abilities/disembark.tres")

const ALL: Array[AbilityDef] = [REPAIR, FORTIFY, DEMOLISH, SELF_DESTRUCT, CAPTURE_VEHICLE, PARADROP, EMBARK, DISEMBARK]
