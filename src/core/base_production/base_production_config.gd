## BaseProductionConfig — Base & Production-owned global tuning constants.
##
## Core-layer config asset per ADR-0017 D6. A dedicated [Resource] (`.tres`),
## mirroring [EconomyConfig]/[UnitConfig]'s config-as-Resource pattern
## (ADR-0006/0009) — never GDScript `const`s, never stored on [GameState] (it
## is static, shared, read-only tuning data, so it must never ride along on
## [method GameState.clone]'s `duplicate_deep()` pass).
##
## Loaded once at boot by the thin, logic-free [code]StructureBalance[/code]
## Autoload and read via [code]StructureBalance.base_production.*[/code].
##
## [b]Ownership:[/b] non-template Base & Production constants only — per-type
## stat values (`hp`, `build_cost`, etc.) live on [StructureTypeDef], not here
## (ADR-0007 owns templates; this Resource owns the generic constants every
## structure type shares).
class_name BaseProductionConfig
extends Resource

## Fixed-point integer percent (not a float rate) refunded on voluntary
## cancel of an Under-Construction structure: `refund = build_cost *
## cancel_refund_pct / 100` via integer division (floors toward the harsher
## side, e.g. 4→2, 9→4, 6→3, odd 5→2). Keeps the AP-refund path integer-only
## per ADR-0003; numerically identical to the GDD's `floor(build_cost × 0.5)`
## across the whole tunable range (30–60). Story 005 owns the refund
## arithmetic itself — this Resource only stores the constant.
## Infantry-cap slots a player has before building any Barracks
## (`population-cap.md`). Per-FACTION once factions ship (domain D3); this is the
## Democratic Alliance baseline.
@export var base_infantry_cap: int = 4

## Absolute ceiling on the infantry cap regardless of Barracks or tech. ★ With
## `max_count` now hard-capping Barracks this rarely binds — it is retained as a
## backstop against a faction authored with an extreme combination, not as a routine dial.
@export var cap_hard_ceiling: int = 14

## How far from a producer a newly-produced unit may be placed, in manhattan steps
## (`base-production.md` Rule 4).
##
## ★ **This was effectively 1 until 2026-08-24, and 1 is unshippable.** A producer
## has 4 tiles at radius 1, so four enemy units standing on them ended that player's
## game permanently — production is the only route back onto the board. S5-04
## measured a +1-unit advantage producing ZERO lead changes across six games against
## 6.75 in an even match; the diagnosis traced it to exactly that.
##
## At 2 a producer has up to 12 candidate tiles, so locking one out needs more units
## than `cap_hard_ceiling` allows. **Do not lower this to 1.** Raising it further
## mostly makes reinforcements arrive further forward, which is a feel question
## rather than a safety one.
@export var deploy_radius: int = 2

@export var cancel_refund_pct: int = 50

## AP cost to fire a Defensive Structure — deliberately lower than the unit
## `attack_cost`, its reward for immobility (Rule 8). Base-&-Production-owned
## but read cross-system by Combat (ADR-0010) to price a structure attacker's
## action, the same cross-system-config-read pattern as
## [code]EconomyConfig[/code]'s tier threshold.
@export var defensive_attack_cost: int = 1

## Hard ceiling on total completed outposts, if [member max_outpost_count_enabled]
## is ever flipped on. Documented tuning lever only — a nameable cap AP
## income could be given if playtest needs it (ADR-0017 D6).
@export var max_outpost_count: int = 10

## Whether [member max_outpost_count] is actually enforced. `false` in the VS
## (Section G "disabled" toggle) — the only bound on `completed_outpost_count`
## is board-tile availability + AP; no `build()` call is ever rejected on
## count grounds while this is `false`. A dedicated bool (rather than
## overloading `max_outpost_count == 0` as "disabled") keeps "the cap is off"
## and "the cap is zero" from ever being ambiguous to a future reader.
@export var max_outpost_count_enabled: bool = false
