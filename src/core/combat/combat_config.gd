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
