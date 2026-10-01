## TechDef — one immutable research template (ADR-0018, CR-14).
##
## Like [UnitTypeDef]/[StructureTypeDef], a TechDef is a [code].tres[/code] preset
## preloaded once by the [code]Techs[/code] registry and referenced by IDENTITY
## everywhere — [code]PlayerState.completed_techs[/code] and
## [code]StructureState.research_target[/code] hold the shared preset, never a copy.
## [code]GameState.clone()[/code] ([code]duplicate_deep[/code]) keeps external
## [code].tres[/code] references shared, so [code]tech in completed_techs[/code] and
## [code]===[/code] comparisons survive a clone. Never [code]load()[/code] one fresh.
##
## [b]CR-14 (2026-09-28): effects are DATA, not per-tech code.[/b] Every effect a tech
## can have is a field below; [Research] sums the fields over a player's completed
## techs ([method Research.attack_bonus] etc.). A new tech is a new [code].tres[/code],
## not a new branch in Research — which is why ADR-0018's three named bool flags were
## replaced: they could not scale past the flat 3-tech tree CR-14 retired.
##
## [b]Gates[/b] (all must hold to START research; see [method Research.availability]):
## [br]• [member prerequisites] — every listed tech completed.
## [br]• [member required_structures] — the player owns a COMPLETED structure of each
##   type. Checked only at start: losing the structure later never revokes a completed
##   tech, nor cancels one already in progress (user decision 2026-09-28).
## [br]• [member exclusive_group] — non-empty means "pick one": once any tech sharing
##   the group is completed or under research, the others are locked for the match.
## [br]• [member allowed_factions] — empty means every faction. A placeholder for
##   faction-specific techs (user decision 2026-09-28); no shipped tech uses it yet.
class_name TechDef
extends Resource

## Player-facing name, shown in the research picker.
@export var display_name: String

## One-line player-facing description of the effect.
@export_multiline var description: String

## 1 = trunk (no Lab needed), 2 = branch. Presentation and AI grouping only — the
## gates below are what actually enforce the tree.
@export var tier: int = 1

## Credits spent upfront when research starts (dual-cost with [member ap_surcharge]).
@export var research_cost: int

## Owner-turns until the tech completes, ticked at the owner's start-of-turn.
@export var research_time: int

## AP spent upfront when research starts. [code]-1[/code] means "use the base
## [member EconomyConfig.research_ap_cost]" (ADR-0018 D5).
@export var ap_surcharge: int = -1

## Techs that must all be completed before this one can start.
@export var prerequisites: Array[TechDef] = []

## Structure types the player must own a COMPLETED instance of to start this tech.
@export var required_structures: Array[StructureTypeDef] = []

## Techs sharing a non-empty group are mutually exclusive for the whole match.
@export var exclusive_group: StringName = &""

## Factions allowed to research this. Empty = all factions.
@export var allowed_factions: Array[FactionDef] = []

@export_group("Effects")
## Added to every one of the player's units' attack ([method Unit.effective_attack]).
@export var attack_bonus: int = 0
## Added to every one of the player's units' defense ([method Unit.effective_defense]).
@export var defense_bonus: int = 0
## Added to the attack range of every one of the player's units that can already
## attack at range >= 1 ([method Unit.effective_attack_range]).
@export var attack_range_bonus: int = 0
## The player's unit attacks ignore the defender's Cover ([method Combat.damage]).
@export var ignores_cover: bool = false
## HP restored at the owner's start-of-turn to each unit that neither moved nor
## attacked on the owner's previous turn ([method Research.apply_idle_healing]).
@export var idle_heal: int = 0
## Economy tiers granted on completion (feeds [method Credits.credit_income_breakdown]).
@export var economy_tier_bonus: int = 0
## AP knocked off every Produce, floored at 0.
@export var produce_ap_discount: int = 0
## AP knocked off every Build, floored at 0.
@export var build_ap_discount: int = 0
## Percent knocked off every unit's Credit produce cost, floored at 1 Credit.
@export var produce_cost_discount_pct: int = 0
## Unit types that no longer need a pilot once this is researched (the Galactic Protectorate's
## Mech Autonomy, faction-identity.md CR-11a). Crewed ones eject their pilot on completion.
@export var frees_pilots: Array[UnitTypeDef] = []
## Added to GROUND VEHICLES only (the Holy Cosmic Empire's Doctrine line).
@export var vehicle_attack_bonus: int = 0
## Added to INFANTRY only (Heavy Ordnance since 2026-10-01 — +1 for every unit won 24-0 in sims).
@export var infantry_attack_bonus: int = 0
@export var vehicle_defense_bonus: int = 0

## ★ 2026-10-01 — branching tech trees (user-approved draft, design doc "Overclock Tech Trees").
## Each is summed over the owner's completed techs by [method Research.sum] / [method Research.any].
## Tree: offense | defense | economy (menu grouping)
@export var tree: String = ""
## All units: tiles before the move surcharge
@export var move_cap_bonus: int = 0
## Vehicles and aircraft: tiles before the move surcharge
@export var vehicle_move_cap_bonus: int = 0
## Infantry: AP per tile off (min 1)
@export var infantry_move_cost_discount: int = 0
## Attack vs vehicles, aircraft and structures
@export var attack_vs_armor: int = 0
## Attack vs infantry
@export var attack_vs_infantry: int = 0
## Infantry attack vs structures
@export var infantry_attack_vs_structures: int = 0
## Range for vehicles only (armed)
@export var vehicle_range_bonus: int = 0
## Attack AP off (min 1)
@export var attack_ap_discount: int = 0
## Infantry attack while standing in Cover
@export var infantry_cover_attack: int = 0
## HP healed at turn start by units standing in Cover
@export var cover_heal: int = 0
## Infantry max HP
@export var infantry_hp_bonus: int = 0
## Vehicle (ground) max HP
@export var vehicle_hp_bonus: int = 0
## Vehicles heal this much at turn start even after acting
@export var vehicle_self_repair: int = 0
## Percent added to every structure's max HP
@export var structure_hp_pct: int = 0
## Defence for every structure
@export var structure_defense_bonus: int = 0
## Attack for structures that can attack
@export var defensive_attack_bonus: int = 0
## Range for structures that can attack
@export var defensive_range_bonus: int = 0
## Structures that can attack also counterattack
@export var defensive_counterattack: bool = false
## Structures that can attack may hit aircraft, +this attack vs them
@export var defensive_anti_air: int = 0
## HQ max HP
@export var hq_hp_bonus: int = 0
## HQ weapon attack (0 = none)
@export var hq_attack: int = 0
## HQ weapon range
@export var hq_range: int = 0
## Structure build turns off (min 1)
@export var build_time_discount: int = 0
## Ammo for vehicles and aircraft
@export var ammo_bonus: int = 0
## Percent off Supply Depots
@export var depot_cost_discount_pct: int = 0
## Resupply reach in tiles (0 = adjacent only)
@export var resupply_range: int = 0
## HP healed at turn start beside a supply structure
@export var supply_heal: int = 0
## AP off each Rush (min 1)
@export var rush_ap_discount: int = 0
## Rushing a vehicle/aircraft costs half the AP
@export var vehicle_rush_half: bool = false
## Vehicle/aircraft production turns off (min 1)
@export var vehicle_production_turn_discount: int = 0
## Percent of an enemy unit's cost refunded when you destroy it
@export var kill_refund_pct: int = 0
## AP added every turn
@export var ap_per_turn_bonus: int = 0
## Percent off all upkeep
@export var upkeep_discount_pct: int = 0
## Percent off structure Credit costs
@export var structure_cost_discount_pct: int = 0
## Population cap
@export var pop_cap_bonus: int = 0
## Percent off infantry Credit costs
@export var infantry_cost_discount_pct: int = 0
## Extra units per turn per producer
@export var production_cap_bonus: int = 0
## Defence for structures beside an aura structure (see aura_structures)
@export var aura_defense_bonus: int = 0
## Attack for bonus_unit_types
@export var bonus_unit_attack: int = 0
## Tiles before the surcharge for bonus_unit_types
@export var bonus_unit_move_cap: int = 0
## Unit types that get [member bonus_unit_attack] / [member bonus_unit_move_cap].
## ★ A faction swap: this tech stands in for the listed shared techs — it occupies their slot and
## satisfies any tech that requires them (Research.availability).
@export var replaces: Array[TechDef] = []
## Attack for aircraft (Combined Arms reaches them; vehicle_attack_bonus is ground-only).
@export var aircraft_attack_bonus: int = 0
@export var bonus_unit_types: Array[UnitTypeDef] = []
## Structures whose neighbours get [member aura_defense_bonus].
@export var aura_structures: Array[StructureTypeDef] = []
