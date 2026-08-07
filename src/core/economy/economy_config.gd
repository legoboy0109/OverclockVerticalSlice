## EconomyConfig — data-driven tuning constants for the AP & Credits Economy.
##
## Foundation-layer config asset per ADR-0006. A dedicated [Resource] (`.tres`),
## mirroring the `MapDefinition` config-asset pattern (ADR-0005) — never
## GDScript `const`s, never stored on [GameState] (it is static, shared,
## read-only build data, not per-match mutable state, so it must never ride
## along on [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]Balance[/code] Autoload
## and read via [code]Balance.economy[/code] — never threaded through call
## sites as an explicit parameter. Its ten fields fall in three groups
## (the 2026-08-05 AP↔Credits pivot added the last five):
## [br]• [b]Credit-income curve[/b] (`base_income` .. `economy_tech_tier_threshold`)
##   — read by [code]Credits.credit_income()[/code] (the diminishing-outpost income
##   curve, re-denominated from AP into the banked Credits pool by the pivot).
## [br]• [b]AP tactical budget[/b] (`flat_ap_per_turn`, `ap_carryover_cap`) — read by
##   [code]AP.reset_turn()[/code]. Flat per-turn, not income-driven.
## [br]• [b]AP logistics surcharges[/b] (`produce_ap_cost`, `build_ap_cost`,
##   `research_ap_cost`) — economy-owned, read cross-system by Base & Production /
##   Research on each economic action (the tempo half of the dual-cost gate).
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

# --- Credit-income curve (funds the banked Credits pool; ADR-0006) ---

## Floor Credit income granted regardless of outpost count (n=0 case).
@export var base_income: int = 10

## Per-outpost Credit income for outposts within the first tier (n <= tier_threshold).
@export var outpost_bonus_tier1: int = 2

## Per-outpost Credit income for outposts beyond the first tier (n > tier_threshold).
@export var outpost_bonus_tier2: int = 1

## Outpost count at which the bonus rate steps down from tier1 to tier2.
@export var tier_threshold: int = 4

## Outpost count at which Economy Tech's income bonus term caps out (owned by
## AP & Credits Economy, read cross-system by Research's `economy_tech_income_bonus()`).
@export var economy_tech_tier_threshold: int = 6

# --- AP tactical budget (the per-turn action-point pool; ADR-0006 pivot) ---

## Flat AP granted at every start-of-turn reset — the tactical budget floor.
## Not income-driven: AP does not scale with the economy (contrast the Credit curve).
@export var flat_ap_per_turn: int = 10

## Max unspent AP that carries into the next turn (any excess is lost). Start-of-turn
## AP = flat_ap_per_turn + min(leftover, ap_carryover_cap), so max AP = 15 at defaults.
@export var ap_carryover_cap: int = 5

# --- AP logistics surcharges (economy-owned; read by B&P / Research per action) ---

## AP surcharge spent (on top of the Credit cost) to produce a unit — the tempo
## half of produce's dual-cost gate.
@export var produce_ap_cost: int = 1

## AP surcharge spent (on top of the Credit cost) to build a structure.
@export var build_ap_cost: int = 2

## BASE AP surcharge spent (on top of the Credit cost) to research a tech. A tech
## may override this per-tech via `TechDef.ap_surcharge` (Research-owned), which
## defaults to this value.
@export var research_ap_cost: int = 1
