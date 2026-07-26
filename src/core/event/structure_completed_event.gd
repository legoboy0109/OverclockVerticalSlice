## StructureCompletedEvent — fired when a structure finishes its build timer.
##
## Foundation-layer event type per ADR-0008. Appended by
## [code]BaseProduction.advance_build_timers[/code] during
## [method GameState.start_turn]'s step 3, flowing through the existing
## [signal GameState.action_applied] signal like every other [Event] — no new
## signal or polling path (control-manifest forbidden pattern).
##
## [b]Ownership note:[/b] this event type arguably belongs to the Base &
## Production epic (it reports one of that system's state transitions), but
## is scoped here per ADR-0008/Story 003's explicit decision: start_turn's
## step-3 contract must emit a concrete completion event for the
## "completion events flow through [code]action_applied[/code]" acceptance
## criterion to be testable before Base & Production exists. [b]Flag for
## reconciliation[/b] when the Base & Production epic lands — that epic's
## real [code]advance_build_timers[/code] implementation may move/extend
## this file's fields (e.g. [code]structure_id[/code]/[code]structure_type[/code]
## once [code]StructureTypeDef[/code] exists, ADR-0007), but should not need
## to relocate the file, since [Event] subclasses already live in
## [code]src/core/event/[/code] regardless of owning system.
##
## Deliberately minimal today: no fields beyond what [Event] already
## provides. This story does not invent a [code]StructureTypeDef[/code]
## schema (ADR-0007, not yet implemented) — the stub
## [code]BaseProduction.advance_build_timers[/code] only needs a concrete,
## instantiable type to append.
##
## Usage:
## [codeblock]
## # inside BaseProduction.advance_build_timers()'s eventual real body:
## events.append(StructureCompletedEvent.new())
## [/codeblock]
class_name StructureCompletedEvent
extends Event
