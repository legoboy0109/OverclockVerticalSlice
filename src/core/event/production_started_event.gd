## ProductionStartedEvent — a producer has begun building a unit (S8-28).
##
## Emitted by [method BaseProduction.apply_produce], which no longer places a unit:
## production takes [member UnitTypeDef.production_turns] owner-turns, and the unit
## arrives via [UnitDeployedEvent] when the timer reaches zero.
##
## ⚠ [b]The costs are already spent when this fires.[/b] A queued unit is paid for at
## commit, which is what makes `population-cap.md` PC-3 ("units under production count
## against the cap") a real rule rather than a loophole to queue past the cap.
##
## Presentation reads this to show a build in progress on the producer; it is the only
## signal that anything happened on a produce commit, because the board does not change.
class_name ProductionStartedEvent
extends Event

## The PRODUCER's entity id — not the unit's. The unit does not exist yet and has no
## id until it is placed.
@export var entity_id: int = -1

## What is being built.
@export var unit_type: UnitTypeDef

## Which player started it.
@export var owner: int = -1

## The tile the unit is expected to appear on. ⚠ Provisional — re-validated on
## completion, because a tile legal now can be occupied two turns from now.
@export var tile: Vector2i

## Owner-turns until the unit is placed, at the moment production started.
@export var turns_remaining: int = 0
