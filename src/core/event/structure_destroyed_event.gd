## StructureDestroyedEvent — fired when a structure is destroyed (hp reaches 0).
##
## Foundation-layer event type, forward-declared for Story 004
## (`win-check-terminal-conditions`) per ADR-0002 step 6 / ADR-0010. The real
## producer of this event is Combat's shared `GameState.destroy_entity()` hook
## (ADR-0010: `StructureDestroyedEvent{entity_id, is_hq}`), which does not
## exist yet (Combat epic, not yet implemented). This story needs a concrete,
## instantiable event type so [method GameState.run_win_check] has something
## real to scan for — it is driven here by test doubles (a throwaway verb
## whose [code]apply()[/code] appends this event directly) standing in for
## Combat's future destruction pipeline.
##
## [b]Ownership note:[/b] this event type belongs to the Combat epic (ADR-0010
## defines its full shape, including [code]entity_id[/code]). It is scoped
## here — mirroring the [StructureCompletedEvent]/[TechCompletedEvent]
## precedent from Story 003/ADR-0008 — because [method GameState.run_win_check]
## must consume a concrete [code]StructureDestroyedEvent{is_hq}[/code] for its
## HQ-destruction acceptance criteria to be testable before Combat exists.
## [b]Flag for reconciliation[/b] when the Combat epic (ADR-0010) lands: its
## real [code]destroy_entity()[/code] implementation constructs and appends
## the authoritative version of this event (adding [code]entity_id[/code] if
## not already present here) — this file should not need to relocate, since
## [Event] subclasses already live in [code]src/core/event/[/code] regardless
## of owning system.
##
## [method GameState.run_win_check] scans the commit's [code]events[/code] for
## instances of this type with [member is_hq] `true` — never a separate HQ hp
## re-scan (ADR-0010, control-manifest Core Layer Rules).
##
## Usage:
## [codeblock]
## # inside a (test-double or future Combat) apply() that destroys an HQ:
## var evt := StructureDestroyedEvent.new()
## evt.is_hq = true
## evt.owner = defender.owner
## events.append(evt)
## [/codeblock]
class_name StructureDestroyedEvent
extends Event

## Whether the destroyed structure was its owner's HQ. [method
## GameState.run_win_check] treats [code]true[/code] as a decisive,
## match-ending event.
@export var is_hq: bool = false

## Which player owned the destroyed structure. Used by [method
## GameState.run_win_check] to compute the opponent when exactly one HQ is
## destroyed ([code]winner = 1 - owner[/code] in the 2-player VS model).
@export var owner: int = -1

## The destroyed structure's former [code]entity_id[/code] — already removed
## from [code]GameState.entities_by_id[/code] by the time this event is
## observed. Added by Combat Resolution Story 005 (the real
## [method GameState.destroy_entity] producer); additive — pre-Story-005 test
## doubles that construct this event without setting it get the [code]-1[/code]
## default, which [method GameState.run_win_check]'s [code]is_hq[/code] filter
## never reads.
@export var entity_id: int = -1
