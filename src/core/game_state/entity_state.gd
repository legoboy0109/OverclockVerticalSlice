## EntityState — base runtime state for anything occupying a grid tile.
##
## Foundation-layer data model per ADR-0001. Extends [Resource] (never [Node])
## so it is render-decoupled, headless-testable, and clones cleanly as a
## nested value inside [code]GameState.entities_by_id[/code]'s
## [code]duplicate_deep()[/code] pass. Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001).
##
## This is the base class only. ADR-0007 (a later entity-schema epic)
## specializes [EntityState] into [code]UnitState[/code]/[code]StructureState[/code]
## concrete subclasses — do not add unit/structure-specific fields here.
##
## [b]Never store an [EntityState] reference in [code]GridState.occupancy[/code][/b] —
## the grid stores only the [code]entity_id[/code] int; resolve back to an
## [EntityState] via [code]GameState.entity_at(tile)[/code] (ADR-0005).
##
## Usage:
## [codeblock]
## var entity := EntityState.new()
## entity.entity_id = 0
## entity.owner = 0
## entity.position = Vector2i(3, 4)
## [/codeblock]
class_name EntityState
extends Resource

## Unique identifier within one [GameState], assigned from
## [code]GameState.next_entity_id[/code] on creation. Never reused within a match.
@export var entity_id: int

## Index into [code]GameState.per_player[/code] identifying which player owns
## this entity.
@export var owner: int

## The tile this entity occupies, in grid coordinates. Mirrors the id stored
## at [code]GridState.occupancy[index(position)][/code] — the two must always
## agree; keeping them in sync is the owning mutation code's responsibility.
@export var position: Vector2i
