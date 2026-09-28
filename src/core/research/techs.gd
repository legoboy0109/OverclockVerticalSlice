## Techs — thin, logic-free registry of every [TechDef] preset (ADR-0007 idiom,
## mirroring [code]UnitTypes[/code]/[code]StructureTypes[/code]).
##
## [member ALL] is the canonical, STABLE iteration order: [method
## Research.legal_research_targets], the research picker and the AI all walk it,
## so it is what keeps their output deterministic (ADR-0003). Order is trunk
## first, then each line's branch pair — the order the picker shows them in.
##
## ★ Any test that needs "every tech" must enumerate [member ALL], never a
## hand-written list — S8-14 / S8-19 are what a hand-copied type list costs.
extends Node

const ATTACK_I: TechDef = preload("res://data/techs/attack_1.tres")
const DEFENSE_I: TechDef = preload("res://data/techs/defense_1.tres")
const ECONOMY_I: TechDef = preload("res://data/techs/economy_1.tres")
const PENETRATION: TechDef = preload("res://data/techs/penetration.tres")
const VOLLEY: TechDef = preload("res://data/techs/volley.tres")
const PLATING: TechDef = preload("res://data/techs/plating.tres")
const FIELD_REPAIR: TechDef = preload("res://data/techs/field_repair.tres")
const LOGISTICS: TechDef = preload("res://data/techs/logistics.tres")
const FOUNDRY: TechDef = preload("res://data/techs/foundry.tres")

const ALL: Array[TechDef] = [
	ATTACK_I, DEFENSE_I, ECONOMY_I,
	PENETRATION, VOLLEY,
	PLATING, FIELD_REPAIR,
	LOGISTICS, FOUNDRY,
]
