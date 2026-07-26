## GameState — the single authoritative match state.
##
## Foundation-layer data model per ADR-0001. Holds the grid, all entities, and
## all per-player state in one place, decoupled from the scene tree. Extends
## [Resource] (never [Node]), constructed only via [code].new()[/code] at
## runtime — never loaded from disk — so it is headless-instantiable,
## headless-queryable (TR-gamestate-002), and clones for free via
## [method clone] (TR-gamestate-003). Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001).
##
## There is no Autoload holding authority over an instance of this class — the
## authoritative instance is created by a match-bootstrap script and passed by
## reference (DI). [code]MatchService[/code] (see [code]match_service.gd[/code])
## is a thin, logic-free lookup pointer only; unit tests and the AI construct
## or receive a [GameState] directly and never touch it.
##
## Story 001 ships the data model, the side-effect-free read API, and
## [method clone]. [code]apply_action[/code]/[code]end_turn[/code]/
## [code]start_match[/code]/[code]start_turn[/code] are later stories
## (Story 002/003) — not implemented here.
##
## Usage:
## [codeblock]
## var state := GameState.new()
## state.grid = GridState.new()
## state.per_player = [PlayerState.new(), PlayerState.new()]
##
## var clone := state.clone()
## clone.per_player[0].current_ap = 5 # does not affect state.per_player[0]
## [/codeblock]
class_name GameState
extends Resource

## Match terminal status. [code]IN_PROGRESS[/code] is the default; later
## stories (Story 004) transition to [code]GAME_OVER[/code] via win-check.
enum MatchStatus { IN_PROGRESS, GAME_OVER }

## The authoritative logical board. Owned inside this state, decoupled from
## any render node (ADR-0001, TR-grid-005/-006).
@export var grid: GridState

## Per-player state, indexed by player number (0, 1, ...).
@export var per_player: Array[PlayerState] = []

## int entity_id -> [EntityState]. The single source of truth for every
## entity's data; the grid's [code]occupancy[/code] stores only the matching
## [code]entity_id[/code] int, never an [EntityState] reference (ADR-0005).
@export var entities_by_id: Dictionary = {}

## Next [code]entity_id[/code] to assign. Incremented whenever
## [code]apply_action[/code] creates an entity (Story 002+). Being a plain
## field, it is automatically included in every [method clone].
@export var next_entity_id: int = 0

## Index into [member per_player] identifying whose turn it currently is.
@export var active_player: int = 0

## The current round number. Starts at 1.
@export var round_number: int = 1

## The match's terminal status. See [enum MatchStatus].
@export var match_status: int = MatchStatus.IN_PROGRESS


## Returns [param player]'s AP available to spend this turn. O(1) array index.
func current_ap(player: int) -> int:
	return per_player[player].current_ap


## Returns every entity in this state, sorted ascending by [member EntityState.entity_id]
## for stable iteration (ADR-0003 forbids relying on Dictionary hash/insertion
## order). O(n log n) per call — re-sorted every call, not cached; this is the
## only non-constant read on this class (see class doc comment's Read-API
## complexity note in the governing story). Returns [code][][/code] for an
## empty state.
func entities() -> Array[EntityState]:
	var result: Array[EntityState] = []
	for entity: EntityState in entities_by_id.values():
		result.append(entity)
	result.sort_custom(func(a: EntityState, b: EntityState) -> bool: return a.entity_id < b.entity_id)
	return result


## Returns the [EntityState] occupying [param tile], or [code]null[/code] if
## the tile is empty or unoccupied. Resolves via [code]grid.occupant_at(tile)[/code]
## (O(1)) then an [code]entities_by_id[/code] Dictionary lookup (O(1)) = O(1)
## total. Never stores an [EntityState] reference in the grid itself (ADR-0005).
func entity_at(tile: Vector2i) -> EntityState:
	var entity_id: int = grid.occupant_at(tile.x, tile.y)
	if entity_id == GridState.EMPTY_OCCUPANT:
		return null
	return entities_by_id.get(entity_id)


## Returns [param player]'s [FactionDef]. O(1) array index. May be
## [code]null[/code] before Setup assigns a faction.
func faction_of(player: int) -> FactionDef:
	return per_player[player].faction


## Returns a fully independent deep copy of this state — the single most
## important operation in the project (ADR-0001 Validation Criteria). One
## call, no hand-written per-field copy: every [code]@export[/code]-flagged
## field (including [member grid], every [PlayerState] in [member per_player],
## and every [EntityState] in [member entities_by_id]) is recursively
## deep-copied by [method Resource.duplicate_deep]. Mutating the clone never
## affects the original, and vice versa.
func clone() -> GameState:
	return duplicate_deep() as GameState
