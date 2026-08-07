## PlayerState — per-player runtime state held on [GameState.per_player].
##
## Foundation-layer data model per ADR-0001. Extends [Resource] (never [Node])
## so it clones cleanly as a nested value inside [code]GameState[/code]'s
## [code]duplicate_deep()[/code] pass. Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001).
##
## Field ownership (documented here, enforced by later stories, not this one):
## [member current_ap] (tactical pool) is written only by [code]AP.spend()[/code]
## and the start-of-turn reset; [member current_credits] (economic pool) only by
## [code]Credits.spend()[/code], the start-of-turn income add, and Credits'
## [code]credit()[/code] cancel-refund; the three tech flags only by Research;
## [member faction] and [member is_ai_controlled] are Setup-locked, immutable after
## Setup->PlayerTurn (enforcement lives in Story 002's [code]apply_action[/code]
## validation, not here).
##
## Usage:
## [codeblock]
## var player := PlayerState.new()
## player.current_ap = 10
## player.current_credits = 6
## [/codeblock]
class_name PlayerState
extends Resource

## The player's faction. Forward-declared stub type ([FactionDef]) until the
## Faction Identity epic (ADR-0012) lands the full 6-domain schema. May be
## [code]null[/code] until Setup assigns it.
@export var faction: FactionDef

## AP (tactical pool) available to spend this turn. Flat per-turn budget with
## capped carryover (ADR-0006 pivot) — unspent AP carries into the next turn up
## to [code]EconomyConfig.ap_carryover_cap[/code], never discarded. Sole writers:
## [code]AP.spend()[/code] and the start-of-turn reset ([code]AP.reset_turn[/code]).
@export var current_ap: int = 0

## Credits (economic pool) — a banked war chest that accumulates across turns
## with no cap (ADR-0006 pivot). Sole writers: [code]Credits.spend()[/code], the
## start-of-turn income add ([code]Credits.add_income[/code]), and the cancel-build
## refund ([code]Credits.credit[/code]). Never negative.
@export var current_credits: int = 0

## One-time permanent unlock flag. Sole writer: Research (later stories); once
## true, never reset to false.
@export var has_attack_tech: bool = false

## One-time permanent unlock flag. Sole writer: Research (later stories); once
## true, never reset to false.
@export var has_defense_tech: bool = false

## One-time permanent unlock flag. Sole writer: Research (later stories); once
## true, never reset to false.
@export var has_economy_tech: bool = false

## True if this player is controlled by the AI opponent (ADR-0011). Set once
## at Setup; immutable after Setup->PlayerTurn.
@export var is_ai_controlled: bool = false
