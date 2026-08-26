## StructureTypeDef — immutable per-type stat template for the VS structure roster.
##
## Core-layer data schema per ADR-0007 (entity/stat schema). A [Resource]
## template (`.tres`), never [code]load()[/code]ed ad hoc — always referenced
## through the [code]StructureTypes[/code] registry Autoload's
## [code]preload()[/code] consts, mirroring the [code]UnitTypes[/code]/
## [code]Balance[/code]/[code]EconomyConfig[/code] pattern (ADR-0006/0007).
##
## Fields are the GDD `base-production.md` Section D stat-template table
## (Rules 1–2, 2b) plus the two combat-infra fields (`targeting_mode`,
## `min_range`) `combat.gd` reads on a structure attacker via
## [code]attacker.type.targeting_mode[/code]/[code]min_range[/code] — mirrors
## [code]UnitTypeDef[/code]'s own fields exactly so a [code]StructureState[/code]
## attacker (the Defensive Structure) flows through the identical
## [method Combat.legal_targets]/DIRECT-walk pipeline a [code]UnitState[/code]
## attacker uses, with no attacker-subtype branch.
##
## Usage:
## [codeblock]
## var hq_hp: int = StructureTypes.HQ.hp
## var producible: Array[UnitTypeDef] = StructureTypes.BARRACKS.producible_types
## [/codeblock]
class_name StructureTypeDef
extends Resource

@export var display_name: String
@export var hp: int

## Infantry-cap slots this structure grants its owner while completed and alive
## (`population-cap.md` PC-5). The Barracks is the only type that grants any.
##
## ★ Granting cap through an ATTACKABLE structure rather than an untouchable purchase is
## the design point: destroying a Barracks lowers the enemy's ceiling, which is a way to
## attack an army's *future* rather than its present — exactly the kind of reason to
## attack the PIVOT verdict found the game lacking.
@export var cap_bonus: int = 0

## Maximum number of this structure a player may have at once — completed AND under
## construction combined. ★ **0 means unlimited** (the pre-S6-03 behaviour), so adding
## this field changes nothing until a type opts in.
##
## ★★ **This is the load-bearing half of the PIVOT fix at the rules layer.** The vertical
## slice failed because the AI always had another thing worth building, so AP never
## reached movement. With every structure capped, a player reaches a state with
## **nothing left to build** — at which point AP has nowhere to go but manoeuvre.
##
## Per `base-production.md` these are per-FACTION values (Faction Identity domain D5);
## until factions ship, the value here is the baseline for every player.
@export var max_count: int = 0

@export var upkeep: int = 0

@export var build_cost: int
@export var build_time: int
@export var production_cap: int = 0
@export var producible_types: Array[UnitTypeDef] = []
@export var attack: int = 0
@export var attack_range: int = 0
@export var defense: int = 0
@export var can_counterattack: bool = false

## Combat targeting profile for this structure as an attacker (the Defensive
## Structure is the only VS structure that fires). Mirrors
## [member UnitTypeDef.targeting_mode] — AREA is dormant in the VS roster.
@export var targeting_mode: int = UnitTypeDef.TargetingMode.DIRECT

## Minimum attack range for this structure as an attacker. Mirrors
## [member UnitTypeDef.min_range]; must satisfy `min_range <= attack_range`
## per the schema invariant Combat enforces (ADR-0010, TR-combat-011).
@export var min_range: int = 1
