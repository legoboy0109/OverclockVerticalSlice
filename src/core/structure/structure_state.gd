## StructureState — per-structure runtime state for a live [StructureTypeDef]-
## templated entity.
##
## Core-layer data schema per ADR-0007 (entity/stat schema). Extends
## [EntityState] (ADR-0001) and inherits [code]entity_id[/code]/[code]owner[/code]/
## [code]position[/code] from it — do not redeclare them here. Every field
## carries [code]@export[/code] so no field is silently dropped by
## [method Resource.duplicate_deep] (storage-usage requirement, ADR-0001/0007).
##
## [member type] is the only field that stays a [b]shared reference[/b]
## ([code]===[/code]) across [method GameState.clone]'s [code]duplicate_deep()[/code]
## call — it is a path-having, [code]preload()[/code]d [StructureTypeDef]
## template (via the [code]StructureTypes[/code] registry), never a
## per-structure copy. Every other field here is a plain value/path-less
## instance and deep-copies independently per clone.
##
## The persisted lifecycle is exactly the 2-value [enum BuildStatus] —
## "Destroyed"/"Removed" are terminal exits (erase from
## [code]entities_by_id[/code] + [code]GridState.remove()[/code]), never
## stored states (ADR-0017 D1).
##
## This is the concrete [EntityState] specialization for structures — the
## Research Lab is a [StructureState] with [code]type == StructureTypes.RESEARCH_LAB[/code],
## [b]not[/b] a third subclass (ADR-0007 forbids a [code]ResearchLabState[/code]).
## See [code]UnitState[/code] for the unit counterpart. Do not add
## structure-specific fields to the shared [EntityState] base.
##
## Usage:
## [codeblock]
## var structure := StructureState.new()
## structure.entity_id = state.next_entity_id
## structure.owner = 0
## structure.position = Vector2i(3, 4)
## structure.type = StructureTypes.FACTORY
## structure.current_hp = structure.type.hp
## structure.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
## structure.build_turns_remaining = structure.type.build_time
## [/codeblock]
class_name StructureState
extends EntityState

## The persisted structure lifecycle (ADR-0007/ADR-0017 D1) — exactly these
## two values. "Destroyed" and "Removed" are terminal erasure exits, never
## stored states.
enum BuildStatus { UNDER_CONSTRUCTION, COMPLETED }

## The immutable per-type stat template this structure was instantiated from.
## Always a reference into the [code]StructureTypes[/code] registry's
## [code]preload()[/code]d consts — never a per-structure duplicate. Shared by
## identity ([code]===[/code]) across [method GameState.clone].
@export var type: StructureTypeDef

## Current hit points. Clamped to `0 <= current_hp <= type.hp` by the owning
## mutation code (Combat's structure-defender damage path, ADR-0010).
@export var current_hp: int

## Where this structure sits in the build lifecycle. Defaults to
## [code]UNDER_CONSTRUCTION[/code] — a fresh structure is always placed
## mid-build (ADR-0017 D1's `build()` transition); a caller representing an
## already-complete structure (e.g. the setup-placed HQ) must set this
## explicitly.
@export var build_status: BuildStatus = BuildStatus.UNDER_CONSTRUCTION

## Owner-turns remaining until this structure completes (Rule 6). Decremented
## by [code]BaseProduction.advance_build_timers[/code] (ADR-0017, Story 002+);
## unused/`0` once [member build_status] is `COMPLETED`.
@export var build_turns_remaining: int = 0

## Units produced by this structure so far this owner-turn — producers only
## (`production_cap > 0`); `0`/unused on non-producer structure types. Reset
## to `0` at the owner's start-of-turn (ADR-0008 step 2).
## Turns remaining before this producer may produce again (S6-07). Set to the type's
## [member StructureTypeDef.production_cooldown_turns] on a successful produce, and
## decremented once per owner-turn by [method Structure.reset_turn_flags].
@export var production_cooldown_remaining: int = 0

@export var units_produced_this_turn: int = 0

## Whether this structure has already fired this turn — the Defensive
## Structure only (Rule 8); `false`/unused on every other structure type.
## Reset to `false` at the owner's start-of-turn (ADR-0008 step 2).
@export var has_attacked: bool = false
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
## Cleared at the start of the owning player's turn by [method Structure.reset_turn_flags],
## exactly like [member has_attacked].
@export var stood_down: bool = false


## Whether this structure is the owning player's HQ. Answered by
## Resource-reference identity against the preload'd registry — never a
## parallel boolean flag — so a fixture only needs to assign
## [code]type = StructureTypes.HQ[/code] for HQ identity to hold everywhere
## (e.g. [method GameState.destroy_entity]'s [code]StructureDestroyedEvent.is_hq[/code]
## win-check hook, ADR-0010).
func is_hq() -> bool:
	return type == StructureTypes.HQ
