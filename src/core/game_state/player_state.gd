## PlayerState — per-player runtime state held on [GameState.per_player].
##
## Foundation-layer data model per ADR-0001. Extends [Resource] (never [Node])
## so it clones cleanly as a nested value inside [code]GameState[/code]'s
## [code]duplicate_deep()[/code] pass. Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001).
##
## Field ownership (documented here, enforced by later stories, not this one):
## [member current_ap] is written only by AP Economy's [code]spend()[/code] and
## the turn-reset step; [member income_this_turn] only by AP Economy's
## start-of-turn snapshot; the three tech flags only by Research; [member faction]
## and [member is_ai_controlled] are Setup-locked, immutable after
## Setup->PlayerTurn (enforcement lives in Story 002's [code]apply_action[/code]
## validation, not here).
##
## Usage:
## [codeblock]
## var player := PlayerState.new()
## player.current_ap = 10
## player.income_this_turn = 10
## [/codeblock]
class_name PlayerState
extends Resource

## The player's faction. Forward-declared stub type ([FactionDef]) until the
## Faction Identity epic (ADR-0012) lands the full 6-domain schema. May be
## [code]null[/code] until Setup assigns it.
@export var faction: FactionDef

## AP available to spend this turn. Sole writers: AP Economy's [code]spend()[/code]
## and the turn-reset step (later stories).
@export var current_ap: int = 0

## Frozen AP income snapshot taken at start-of-turn. Sole writer: AP Economy's
## start-of-turn snapshot (later stories).
@export var income_this_turn: int = 0

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
