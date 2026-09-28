## CombatConfig — Combat-owned tuning constants for the damage formula and attack AP cost.
##
## Core-layer config asset per ADR-0010. A dedicated [Resource] (`.tres`),
## mirroring [EconomyConfig]/[UnitConfig]'s config-as-Resource pattern
## (ADR-0006/0009) — never GDScript `const`s, never stored on [GameState] (it
## is static, shared, read-only tuning data, so it must never ride along on
## [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]CombatBalance[/code]
## Autoload and read via [code]CombatBalance.combat[/code].
##
## [b]attack_cost[/b] is included here even though it isn't consumed until
## Story 004 (the [code]attack()[/code] verb handler) — it is Combat-owned
## tuning per ADR-0010's Key Interfaces (`ATTACK_COST = 2`) and belongs in
## one place with the rest of Combat's constants.
##
## Usage:
## [codeblock]
## var cfg: CombatConfig = CombatBalance.combat
## var cover: int = cfg.cover_dr
## [/codeblock]
class_name CombatConfig
extends Resource

## Damage floor: no attack ever deals less than this, regardless of mitigation.
@export var min_damage: int = 1

## Flat damage reduction applied when a [code]UnitState[/code] defender stands
## on a Cover tile. Never applies to a [code]StructureState[/code] defender
## (structures are cover-immune, ADR-0010).
@export var cover_dr: int = 1

## AP cost to perform a unit attack (consumed starting Story 004).
@export var attack_cost: int = 2

## Extra AP an area attack costs on top of [member attack_cost] (damage-types.md
## AREA_AP_SURCHARGE): hitting several tiles for the price of one is not a decision.
@export var area_ap_surcharge: int = 1

## ★ Promotion & veterancy (promotion-veterancy.md). Only factions with
## [member FactionDef.promotes] earn merit; for everyone else these are inert.
## Cumulative merit needed for ranks 0..3 (PV-2). The escalation is the anti-snowball guard:
## raise thresholds before touching bonuses.
@export var rank_thresholds: PackedInt32Array = PackedInt32Array([0, 6, 16, 32])
## Per-rank bonuses, additive (PV-3), indexed by rank 0..3.
@export var rank_attack: PackedInt32Array = PackedInt32Array([0, 1, 1, 2])
@export var rank_hp: PackedInt32Array = PackedInt32Array([0, 0, 2, 4])
@export var rank_range: PackedInt32Array = PackedInt32Array([0, 0, 0, 1])
## Merit per destroyed enemy unit / destroyed enemy structure / non-killing hit (PV-1).
@export var merit_per_kill: int = 3
@export var merit_per_structure: int = 2
@export var merit_per_hit: int = 1
