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

## The three unit classes (unit-classes.md UC-1, closed set). A class decides how a unit
## meets terrain, whether Cover protects it, and who can shoot it — see [Unit] for the rules.
enum UnitClass { INFANTRY, GROUND_VEHICLE, AIR }

## Damage types, closed set (damage-types.md DT-1).
enum DamageType { KINETIC, EMF, INCENDIARY }

## Area-of-effect shapes, closed set (DT-7). SINGLE is the default and hits only the target.
enum AreaShape { SINGLE, BURST, LINE }

## This unit's class (UC-1). Immutable for the life of the unit (UC-8).
@export var unit_class: int = UnitClass.INFANTRY

## The classes this unit can attack (UC-4). Structures count as ground targets: they are
## attackable by anything that can target INFANTRY or GROUND_VEHICLE. Empty = unarmed.
@export var can_target: Array[int] = [UnitClass.INFANTRY, UnitClass.GROUND_VEHICLE]

## What kind of damage this deals (damage-types.md DT-1). KINETIC is neutral — every unit
## that existed before damage types is KINETIC, which is what keeps their matchups unchanged.
@export var damage_type: int = UnitTypeDef.DamageType.KINETIC

## Flat damage adjustments by incoming type (DT-3/DT-4): subtracted in the damage formula, so
## positive resists and NEGATIVE is "weak to". Band [-3, +3], enforced by the vault converter.
@export var resist_kinetic: int = 0
@export var resist_emf: int = 0
@export var resist_incendiary: int = 0

## Area shape (DT-7): SINGLE, BURST (target + its 4 neighbours) or LINE (a straight run of
## [member area_length] tiles from beside the attacker, through the target). Area damage hits
## friendlies too (DT-8), costs [member CombatConfig.area_ap_surcharge] extra AP, and only
## the primary target may counterattack.
@export var area_shape: int = AreaShape.SINGLE

## Tiles a LINE attack covers (DT-7). Ignored by other shapes.
@export var area_length: int = 4

## Catalogue abilities this unit carries (unit-abilities.md AB-2). Embark and disembark are
## not listed here — every unit that fits in a transport may use them (see [Ability]).
@export var abilities: Array[AbilityDef] = []

## May crew a vehicle (transport-and-pilots.md TP-5c). Infantry only.
@export var can_pilot: bool = false

## Inert until a pilot climbs in: cannot move, attack or use abilities (TP-5). Every ground
## vehicle ships with this on (TP-5a) — it is what makes armour cost an infantry slot.
@export var requires_pilot: bool = false

## Passenger slots (TP-2); 0 = not a transport. The pilot's seat is separate.
@export var transport_capacity: int = 0

## Unit classes this transport accepts as passengers (TP-2).
@export var transport_accepts: Array[int] = []

## Slots this unit takes as a passenger: 1 for infantry, 3 for a vehicle (TP-2).
@export var transport_size: int = 1

## This unit's attacks hit a crewed vehicle's PILOT instead of the vehicle (TP-7).
@export var targets_crew: bool = false

## TP-5d: attack added to a vehicle while this unit is its pilot (a trained crew is better).
@export var crew_bonus_attack: int = 0
## TP-5d: added to a vehicle's AP-per-tile move cost while this unit pilots it (negative =
## faster). The result never drops below [constant Unit.MIN_MOVE_COST].
@export var crew_bonus_move_cost: int = 0

## Merit a unit of this type is produced with (the Holy Cosmic Empire's Knight enters at rank 1).
## Only meaningful for a faction that promotes; uses the existing merit machinery, no new rule.
@export var starting_merit: int = 0

## Borrow another type's sprites (its id) until this one has its own art — a faction's
## variant of a shared building, or a new unit awaiting art. Empty = its own id.
## ⚠ Placeholder: two types sharing art look identical on the board.
@export var art_id: StringName = &""

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


## Owner-turns this unit spends IN PRODUCTION before it appears on the board
## (S8-28, user decision 2026-08-26). Production is no longer instant: a
## [ProduceAction] commits the cost and starts a build, and the unit is placed
## when the timer reaches zero.
##
## ★ [b]This REPLACES the per-structure [code]production_cooldown_turns[/code].[/b]
## A producer is busy while its unit is building, so the wait is now a property of
## WHAT you are making rather than of the building making it — which is what makes
## "more powerful units take longer" expressible at all.
##
## Shipped values: Builder 1 · Scout 1 · Trooper 1 · Sniper [b]2[/b] · Heavy [b]2[/b].
## ⚠ Chosen by the user from three candidate curves; the gentler one, so only the two
## most powerful units carry a delay and the early game keeps its pace.
@export var production_turns: int = 1
