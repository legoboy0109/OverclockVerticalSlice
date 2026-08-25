## UnitState — per-unit runtime state for a live [UnitTypeDef]-templated entity.
##
## Core-layer data schema per ADR-0007 (entity/stat schema). Extends
## [EntityState] (ADR-0001) and inherits [code]entity_id[/code]/[code]owner[/code]/
## [code]position[/code] from it — do not redeclare them here. Every field
## carries [code]@export[/code] so no field is silently dropped by
## [method Resource.duplicate_deep] (storage-usage requirement, ADR-0001/0007).
##
## [member type] is the only field that stays a [b]shared reference[/b]
## ([code]===[/code]) across [method Unit.clone]'s [code]duplicate_deep()[/code]
## call — it is a path-having, [code]preload()[/code]d [UnitTypeDef] template
## (via the [code]UnitTypes[/code] registry), never a per-unit copy. Every
## other field here is a plain value/path-less instance and deep-copies
## independently per clone.
##
## This is the concrete [EntityState] specialization for units; see
## [code]StructureState[/code] for the structure counterpart. Do not add
## unit-specific fields to the shared [EntityState] base.
##
## Usage:
## [codeblock]
## var unit := UnitState.new()
## unit.entity_id = state.next_entity_id
## unit.owner = 0
## unit.position = Vector2i(3, 4)
## unit.type = UnitTypes.SCOUT
## unit.current_hp = unit.type.hp
## [/codeblock]
class_name UnitState
extends EntityState

## The immutable per-type stat template this unit was instantiated from.
## Always a reference into the [code]UnitTypes[/code] registry's
## [code]preload()[/code]d consts — never a per-unit duplicate. Shared by
## identity ([code]===[/code]) across [method Unit.clone].
@export var type: UnitTypeDef

## Current hit points. Mutated only through [method Unit.apply_hp_delta]
## (ADR-0007) — never assign this field directly outside that function.
## Clamped to [code]0 <= current_hp <= type.hp[/code].
@export var current_hp: int

## Whether this unit has already attacked this turn. Reset to [code]false[/code]
## at the start of the owning player's turn by [method Unit.reset_turn_flags]
## (ADR-0008 step 2).
@export var has_attacked: bool = false

## Tiles moved so far this turn, toward the Movement epic's soft-cap penalty
## (forward-declared; the writer is out of scope here). Reset to [code]0[/code]
## at the start of the owning player's turn by [method Unit.reset_turn_flags]
## (ADR-0008 step 2).
@export var tiles_moved_this_turn: int = 0
## True once the player has explicitly stood this entity down for the turn
## ([WaitAction]) — "I am finished with this one".
##
## [b]Advisory, never binding[/b] (user decision, 2026-08-25). It changes what the
## INTERFACE offers, not what the rules allow: a stood-down entity stops breathing
## on the board, is skipped by the idle-entity cursor cycle, and stops counting
## toward the End-Turn idle notice — but it is still selectable and every verb it
## had is still legal. Acting with it clears the flag, because the mark records an
## intention the player has visibly changed their mind about.
##
## Chosen over a hard lockout deliberately: Wait is a single unconfirmed menu row,
## and locking an entity out of its turn from one click is the same trap the
## Cancel-Build confirmation gate exists to prevent.
##
## Cleared at the start of the owning player's turn by [method Unit.reset_turn_flags],
## exactly like [member has_attacked].
@export var stood_down: bool = false

