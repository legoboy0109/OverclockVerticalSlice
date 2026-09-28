## StructureTypes — Autoload, logic-free registry of the VS structure roster.
##
## Core-layer Autoload per ADR-0007 (entity/stat schema), mirroring
## [code]UnitTypes[/code]'s thin "read-only lookup convenience" idiom
## (ADR-0006). [code]preload()[/code]s each [StructureTypeDef] `.tres` once at
## boot and exposes it by reference. Never [code]load()[/code] a structure
## `.tres` outside this registry (control-manifest forbidden pattern, ADR-0007) —
## a stray [code]load()[/code] would return a second Resource instance with
## the same content but different identity, silently breaking every
## [code]structure.type == StructureTypes.X[/code] comparison.
##
## Registered in `project.godot`'s `[autoload]` section so any system can read
## [code]StructureTypes.HQ[/code] etc. as a bare global reference. The
## Research Lab is included here (it is a [StructureState] like every other
## structure, ADR-0007) even though its stat values and behavior are
## Research-owned (base-production.md Rule 2b).
extends Node

const HQ: StructureTypeDef = preload("res://data/structures/hq.tres")
const FACTORY: StructureTypeDef = preload("res://data/structures/factory.tres")
const BARRACKS: StructureTypeDef = preload("res://data/structures/barracks.tres")
const DEFENSIVE_STRUCTURE: StructureTypeDef = preload("res://data/structures/defensive_structure.tres")
const RESEARCH_LAB: StructureTypeDef = preload("res://data/structures/research_lab.tres")
const AIRFIELD: StructureTypeDef = preload("res://data/structures/airfield.tres")
# ★ Solar Federation (faction wave 2). Not in the shared roster (buildable = false).
const SOLAR_BARRACKS: StructureTypeDef = preload("res://data/structures/solar_barracks.tres")
const SOLAR_FACTORY: StructureTypeDef = preload("res://data/structures/solar_factory.tres")
const SOLAR_AIRFIELD: StructureTypeDef = preload("res://data/structures/solar_airfield.tres")
const DEFENCE_NODE: StructureTypeDef = preload("res://data/structures/autonomous_defence_node.tres")
# ★ Independents (faction wave 3).
const INDEPENDENTS_BARRACKS: StructureTypeDef = preload("res://data/structures/independents_barracks.tres")
const INDEPENDENTS_FACTORY: StructureTypeDef = preload("res://data/structures/independents_factory.tres")
const INDEPENDENTS_AIRFIELD: StructureTypeDef = preload("res://data/structures/independents_airfield.tres")
# ★ Machinist's Union (faction wave 4).
const UNION_BARRACKS: StructureTypeDef = preload("res://data/structures/union_barracks.tres")
const UNION_FACTORY: StructureTypeDef = preload("res://data/structures/union_factory.tres")
const UNION_AIRFIELD: StructureTypeDef = preload("res://data/structures/union_airfield.tres")
const BULWARK: StructureTypeDef = preload("res://data/structures/bulwark.tres")
# ★ Galactic Protectorate (faction wave 5).
const PROTECTORATE_BARRACKS: StructureTypeDef = preload("res://data/structures/protectorate_barracks.tres")
const PROTECTORATE_FACTORY: StructureTypeDef = preload("res://data/structures/protectorate_factory.tres")
const PROTECTORATE_AIRFIELD: StructureTypeDef = preload("res://data/structures/protectorate_airfield.tres")
const PROTECTORATE_DEFENCE: StructureTypeDef = preload("res://data/structures/protectorate_defence.tres")
# ★ Holy Cosmic Empire (faction wave 6).
const EMPIRE_BARRACKS: StructureTypeDef = preload("res://data/structures/empire_barracks.tres")
const EMPIRE_FACTORY: StructureTypeDef = preload("res://data/structures/empire_factory.tres")
const EMPIRE_AIRFIELD: StructureTypeDef = preload("res://data/structures/empire_airfield.tres")
const CATHEDRAL: StructureTypeDef = preload("res://data/structures/cathedral.tres")

## ★ Every structure type in the roster, in declaration order. See
## [constant UnitTypes.ALL] for why this exists — a coverage guard that keeps its
## own copy of the roster only guards what someone remembered to copy.
const ALL: Array[StructureTypeDef] = [HQ, FACTORY, BARRACKS, DEFENSIVE_STRUCTURE, RESEARCH_LAB, AIRFIELD,
	SOLAR_BARRACKS, SOLAR_FACTORY, SOLAR_AIRFIELD, DEFENCE_NODE,
	INDEPENDENTS_BARRACKS, INDEPENDENTS_FACTORY, INDEPENDENTS_AIRFIELD,
	UNION_BARRACKS, UNION_FACTORY, UNION_AIRFIELD, BULWARK,
	PROTECTORATE_BARRACKS, PROTECTORATE_FACTORY, PROTECTORATE_AIRFIELD, PROTECTORATE_DEFENCE,
	EMPIRE_BARRACKS, EMPIRE_FACTORY, EMPIRE_AIRFIELD, CATHEDRAL]

## Every structure a Builder may raise, in [constant ALL] order — decided by each type's
## [member StructureTypeDef.buildable] (the vault's `buildable` checkbox). The single source
## for the build picker, the HUD, the Build row and the AI.
static var BUILDABLE: Array[StructureTypeDef] = ALL.filter(
	func(t: StructureTypeDef) -> bool: return t.buildable)
