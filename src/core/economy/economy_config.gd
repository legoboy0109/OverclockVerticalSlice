## EconomyConfig — data-driven tuning constants for AP Economy's income formula.
##
## Foundation-layer config asset per ADR-0006. A dedicated [Resource] (`.tres`),
## mirroring the `MapDefinition` config-asset pattern (ADR-0005) — never
## GDScript `const`s, never stored on [GameState] (it is static, shared,
## read-only build data, not per-match mutable state, so it must never ride
## along on [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]Balance[/code] Autoload
## and read by [code]AP[/code] via [code]Balance.economy[/code] — never
## threaded through `AP` call sites as an explicit parameter.
##
## [b]Deliberately excluded (see ADR-0006 Risks):[/b] no `base_income_floor`
## field and no faction income-delta fields exist here. ADR-0006's Risks
## section explicitly defers the Faction Identity income-delta fold and its
## `BASE_INCOME_FLOOR` guard to the Alpha faction-asymmetry prototype
## (ADR-0012) — adding them now would be speculative, unexercised surface.
##
## [b]Note:[/b] `ECONOMY_TECH_INCOME_BONUS` (the constant, value 1) is
## deliberately NOT a field here — it is Research-owned, living in Research's
## own config resource, per ADR-0006's Key Interfaces comment.
##
## Usage:
## [codeblock]
## var cfg: EconomyConfig = Balance.economy
## var outpost_bonus: int = cfg.outpost_bonus_tier1 * min(n, cfg.tier_threshold)
## [/codeblock]
class_name EconomyConfig
extends Resource

## Floor income granted regardless of outpost count (n=0 case).
@export var base_income: int = 10

## Per-outpost AP bonus for outposts within the first tier (n <= tier_threshold).
@export var outpost_bonus_tier1: int = 2

## Per-outpost AP bonus for outposts beyond the first tier (n > tier_threshold).
@export var outpost_bonus_tier2: int = 1

## Outpost count at which the bonus rate steps down from tier1 to tier2.
@export var tier_threshold: int = 4

## Outpost count at which Economy Tech's income bonus term caps out (owned by
## AP Economy, read cross-system by Research's `economy_tech_income_bonus()`).
@export var economy_tech_tier_threshold: int = 6
