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

# ★ 2026-10-01: the branching tech trees (design doc "Overclock Tech Trees"). ATTACK_I / DEFENSE_I /
# ECONOMY_I keep their names (and their .tres ids, for saves) as Heavy Ordnance / Hardened Armor /
# Industrial Base.
const ATTACK_I: TechDef = preload("res://data/techs/attack_1.tres")
const RAPID_DEPLOYMENT: TechDef = preload("res://data/techs/rapid_deployment.tres")
const PENETRATION: TechDef = preload("res://data/techs/penetration.tres")
const VOLLEY: TechDef = preload("res://data/techs/volley.tres")
const BLITZ: TechDef = preload("res://data/techs/blitz.tres")
const INFILTRATORS: TechDef = preload("res://data/techs/infiltrators.tres")
const ARMOR_PIERCING: TechDef = preload("res://data/techs/armor_piercing.tres")
const SHREDDER_ROUNDS: TechDef = preload("res://data/techs/shredder_rounds.tres")
const LONG_GUNS: TechDef = preload("res://data/techs/long_guns.tres")
const FIRE_DISCIPLINE: TechDef = preload("res://data/techs/fire_discipline.tres")
const COMBINED_ARMS: TechDef = preload("res://data/techs/combined_arms.tres")
const OVERDRIVE: TechDef = preload("res://data/techs/overdrive.tres")
const AMBUSH: TechDef = preload("res://data/techs/ambush.tres")
const SAPPERS: TechDef = preload("res://data/techs/sappers.tres")
const DEFENSE_I: TechDef = preload("res://data/techs/defense_1.tres")
const FORTIFICATIONS: TechDef = preload("res://data/techs/fortifications.tres")
const PLATING: TechDef = preload("res://data/techs/plating.tres")
const FIELD_REPAIR: TechDef = preload("res://data/techs/field_repair.tres")
const POINT_DEFENSE: TechDef = preload("res://data/techs/point_defense.tres")
const REINFORCED_CONCRETE: TechDef = preload("res://data/techs/reinforced_concrete.tres")
const REACTIVE_ARMOR: TechDef = preload("res://data/techs/reactive_armor.tres")
const DIG_IN: TechDef = preload("res://data/techs/dig_in.tres")
const RAPID_REPAIR: TechDef = preload("res://data/techs/rapid_repair.tres")
const TRIAGE: TechDef = preload("res://data/techs/triage.tres")
const OVERWATCH_GRID: TechDef = preload("res://data/techs/overwatch_grid.tres")
const FLAK_BATTERIES: TechDef = preload("res://data/techs/flak_batteries.tres")
const HARDPOINTS: TechDef = preload("res://data/techs/hardpoints.tres")
const RAPID_CONSTRUCTION: TechDef = preload("res://data/techs/rapid_construction.tres")
const ECONOMY_I: TechDef = preload("res://data/techs/economy_1.tres")
const SUPPLY_LINES: TechDef = preload("res://data/techs/supply_lines.tres")
const FOUNDRY: TechDef = preload("res://data/techs/foundry.tres")
const LOGISTICS: TechDef = preload("res://data/techs/logistics.tres")
const FORWARD_DEPOTS: TechDef = preload("res://data/techs/forward_depots.tres")
const RAPID_REQUISITION: TechDef = preload("res://data/techs/rapid_requisition.tres")
const MASS_PRODUCTION: TechDef = preload("res://data/techs/mass_production.tres")
const SALVAGE: TechDef = preload("res://data/techs/salvage.tres")
const COMMAND_NETWORK: TechDef = preload("res://data/techs/command_network.tres")
const QUARTERMASTERS: TechDef = preload("res://data/techs/quartermasters.tres")
const FIELD_WORKSHOPS: TechDef = preload("res://data/techs/field_workshops.tres")
const AMMO_SURPLUS: TechDef = preload("res://data/techs/ammo_surplus.tres")
const BULK_CONTRACTS: TechDef = preload("res://data/techs/bulk_contracts.tres")
const EMERGENCY_DRAFT: TechDef = preload("res://data/techs/emergency_draft.tres")

# Faction swaps (each replaces one shared tech in that faction's tree).
const LEVY_EN_MASSE: TechDef = preload("res://data/techs/levy_en_masse.tres")
const TECHNICALS_DOCTRINE: TechDef = preload("res://data/techs/technicals_doctrine.tres")
const ASSEMBLY_LINES: TechDef = preload("res://data/techs/assembly_lines.tres")
const SLAB_WALLS: TechDef = preload("res://data/techs/slab_walls.tres")
const STRIP_THE_WRECKS: TechDef = preload("res://data/techs/strip_the_wrecks.tres")
const SCRAP_PLATING: TechDef = preload("res://data/techs/scrap_plating.tres")
const SELF_REPAIR_PROTOCOLS: TechDef = preload("res://data/techs/self_repair_protocols.tres")
const MECH_AUTONOMY: TechDef = preload("res://data/techs/mech_autonomy.tres")
const DOCTRINE: TechDef = preload("res://data/techs/doctrine.tres")
const CONSECRATION: TechDef = preload("res://data/techs/consecration.tres")

# Legacy (no longer in any tree) — kept so saves that researched them still load.
const DOCTRINE_I: TechDef = preload("res://data/techs/doctrine_1.tres")
const DOCTRINE_II: TechDef = preload("res://data/techs/doctrine_2.tres")
const DOCTRINE_III: TechDef = preload("res://data/techs/doctrine_3.tres")

## The SHARED tree, in tree order (Offense, Defense, Economy; tier by tier). A faction with its
## own `techs` list uses that instead ([method Faction.techs]).
const ALL: Array[TechDef] = [
	ATTACK_I, RAPID_DEPLOYMENT, PENETRATION, VOLLEY,
	BLITZ, INFILTRATORS, ARMOR_PIERCING, SHREDDER_ROUNDS,
	LONG_GUNS, FIRE_DISCIPLINE, COMBINED_ARMS, OVERDRIVE,
	AMBUSH, SAPPERS, DEFENSE_I, FORTIFICATIONS,
	PLATING, FIELD_REPAIR, POINT_DEFENSE, REINFORCED_CONCRETE,
	REACTIVE_ARMOR, DIG_IN, RAPID_REPAIR, TRIAGE,
	OVERWATCH_GRID, FLAK_BATTERIES, HARDPOINTS, RAPID_CONSTRUCTION,
	ECONOMY_I, SUPPLY_LINES, FOUNDRY, LOGISTICS,
	FORWARD_DEPOTS, RAPID_REQUISITION, MASS_PRODUCTION, SALVAGE,
	COMMAND_NETWORK, QUARTERMASTERS, FIELD_WORKSHOPS, AMMO_SURPLUS,
	BULK_CONTRACTS, EMERGENCY_DRAFT,
]
