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
## Whether this unit consumes an infantry-cap slot (`population-cap.md` PC-4).
##
## ★ A per-UNIT property, deliberately not per-class: it is what lets the Galactic
## Protectorate's robotic *infantry* be cap-exempt while still being infantry
## (`faction-identity.md` CR-11a, the corpus's single sanctioned exemption). Vehicles and
## aircraft set this false and are bounded instead through their crew, which is infantry
## and does count (PC-8).
@export var counts_toward_cap: bool = true

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

## Whether this unit can raise structures — the Builder trait (`base-production.md`
## CR-5, user decision 2026-08-25).
##
## ★ [b]A data flag, not a type comparison.[/b] Every rule that asks "can this thing
## build?" reads THIS, never [code]type == UnitTypes.BUILDER[/code], so a second
## builder-capable unit (a faction variant, an engineering vehicle) is a `.tres` edit
## rather than a hunt through the codebase for hard-coded identity checks. Same
## reasoning that made [member counts_toward_cap] per-unit rather than per-class.
##
## ⚠ Build is [b]consumptive[/b]: the unit is spent by the structure it raises (see
## [method BaseProduction.apply_build]). A unit with this set must be costed as part
## of the price of every building it can put down, not as a unit that survives.
@export var can_build: bool = false
