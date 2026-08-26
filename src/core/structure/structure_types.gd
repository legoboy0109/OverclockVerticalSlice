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

## ★ Every structure type in the roster, in declaration order. See
## [constant UnitTypes.ALL] for why this exists — a coverage guard that keeps its
## own copy of the roster only guards what someone remembered to copy.
const ALL: Array[StructureTypeDef] = [HQ, FACTORY, BARRACKS, DEFENSIVE_STRUCTURE, RESEARCH_LAB]
