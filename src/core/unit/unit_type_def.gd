## UnitTypeDef — immutable per-type stat template for the Vertical Slice roster.
##
## Core-layer data schema per ADR-0007 (entity/stat schema). A [Resource]
## template (`.tres`), never [code]load()[/code]ed ad hoc — always referenced
## through the [code]UnitTypes[/code] registry Autoload's [code]preload()[/code]
## consts, mirroring the [code]Balance[/code]/[code]EconomyConfig[/code]
## pattern (ADR-0006).
##
## Fields are the GDD `unit-system.md` Rule 3 stat table plus the four
## combat-infra fields (Rule 3a), which ship off/neutral by default across the
## whole VS roster (`defense = 0`, `targeting_mode = DIRECT`, `min_range = 1`,
## `can_counterattack = false`).
##
## Usage:
## [codeblock]
## var scout_hp: int = UnitTypes.SCOUT.hp
## [/codeblock]
class_name UnitTypeDef
extends Resource

## AREA targeting is dormant in the VS (no roster member uses it yet).
enum TargetingMode { DIRECT, AREA }

@export var display_name: String
@export var hp: int
@export var attack: int
@export var attack_range: int
@export var move_cost: int
@export var soft_move_cap: int
## Credits drained every turn while this unit is alive (S6-02, `unit-upkeep.md`).
## 0 is legal; negative fails schema validation.
##
## Convention (not enforced in code — authored values ship): derived as
## `ceil(produce_cost / (UPKEEP_DIVISOR × UPKEEP_GRANULARITY)) × UPKEEP_GRANULARITY`,
## which yields 100/200/200/300 for Scout/Trooper/Sniper/Heavy.
@export var upkeep: int = 0

@export var produce_cost: int
@export var defense: int = 0
@export var targeting_mode: int = TargetingMode.DIRECT
@export var min_range: int = 1
@export var can_counterattack: bool = false
