## Event — base type for everything a verb handler's [code]apply()[/code] can report.
##
## Foundation-layer event/signal architecture per ADR-0004. A small,
## short-lived [RefCounted] carrying no fields of its own — every owning Core
## system (Movement, Combat, Base & Production, Research) defines its own
## typed subclasses as top-level files (mirroring [Action]'s per-verb
## convention), e.g. [code]unit_moved_event.gd[/code],
## [code]damage_event.gd[/code], [code]hq_destroyed_event.gd[/code] — none of
## which are in scope for this story.
##
## A verb handler's [code]apply()[/code] appends [Event] instances to the
## [code]Array[Event][/code] it returns, in the exact order those effects
## happened — that append order [b]is[/b] the resolution order (TR-hud-014);
## nothing downstream (the pipeline, the [signal GameState.action_applied]
## signal, a subscriber) may reorder it.
##
## Consumers narrow with [code]if e is DamageEvent:[/code], never a
## [code]match[/code] on runtime type — covariant [code]Array[Event][/code]
## holding subclass instances is supported in Godot 4.6 (ADR-0002/0004 Engine
## Notes).
##
## Usage:
## [codeblock]
## # inside some future verb handler's apply():
## var events: Array[Event] = []
## events.append(SomeConcreteEvent.new())
## return events
## [/codeblock]
class_name Event
extends RefCounted
