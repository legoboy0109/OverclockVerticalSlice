## MatchSetup — builds the starting GameState for a skirmish (faction framework v2).
##
## ★ ONE setup, shared by the game, the match simulator and the diagnostic tools. Each used to
## hand-build its own board and HQs, and every balance number the simulator reports is only
## meaningful if its board matches the game's — the S7-15 placement-bias confound came from
## exactly that kind of hand-copied setup drifting.
##
## Each seat gets its faction's HQ (D5) and one free starting Builder behind it (S8-29) — the
## first unit its HQ produces, so a faction with its own Builder starts with that one (D7).
## Factions are set BEFORE the first start-of-turn, so the opening turn's income and cap
## already include each faction's modifiers.
class_name MatchSetup
extends RefCounted


static func build(map: MapDefinition, factions: Array[FactionDef], starting_player: int,
		max_rounds: int, ai_seats: Array[int] = [1]) -> GameState:
	var state := GameState.new()
	state.grid = MapDefinition.build_grid(map)
	state.per_player = [PlayerState.new(), PlayerState.new()]
	for p: int in 2:
		state.per_player[p].faction = factions[p] if p < factions.size() and factions[p] != null else Factions.NEUTRAL
		state.per_player[p].is_ai_controlled = p in ai_seats
	# build_grid places placeholder occupants 0/1 on the HQ tiles; the real HQs take those ids.
	for p: int in map.hq_tiles.size():
		var hq_type: StructureTypeDef = Faction.hq_type(state.per_player[p].faction)
		var hq := StructureState.new()
		hq.entity_id = p
		hq.owner = p
		hq.position = map.hq_tiles[p]
		hq.type = hq_type
		hq.current_hp = hq_type.hp
		hq.build_status = StructureState.BuildStatus.COMPLETED
		state.entities_by_id[hq.entity_id] = hq
	state.next_entity_id = map.hq_tiles.size()
	seed_starting_builders(state, map.hq_tiles)
	state.starting_player = starting_player
	state.round_number = 1
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	state.max_rounds = max_rounds
	state.start_turn(starting_player)
	return state


## One free Builder behind each HQ (S8-29): the first type that seat's HQ produces. Skips a
## seat whose tile is off-board or blocked — a slower opening, never a broken match.
static func seed_starting_builders(state: GameState, hq_tiles: Array[Vector2i]) -> void:
	for player: int in hq_tiles.size():
		var tile: Vector2i = VSMap.starting_builder_tile(hq_tiles[player], hq_tiles[1 - player])
		if not state.grid.in_bounds(tile.x, tile.y) or not state.grid.is_passable(tile.x, tile.y):
			continue
		var hq_type: StructureTypeDef = Faction.hq_type(state.faction_of(player))
		var builder_type: UnitTypeDef = hq_type.producible_types[0] if not hq_type.producible_types.is_empty() \
			else UnitTypes.BUILDER
		var unit := UnitState.new()
		unit.entity_id = state.next_entity_id
		unit.owner = player
		unit.position = tile
		unit.type = builder_type
		unit.current_hp = builder_type.hp
		state.entities_by_id[unit.entity_id] = unit
		state.next_entity_id += 1
		state.grid.place(unit.entity_id, tile.x, tile.y)
