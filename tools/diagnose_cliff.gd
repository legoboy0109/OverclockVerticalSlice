## DiagnoseCliff — why does a one-unit deficit become unrecoverable? (S5-04 §3)
##
## S5-04 measured a cliff: mirror matches change hands 6.75 times, and a +1-Trooper
## match changes hands ZERO times across six games. Tracing one showed the mechanism
## is not attrition — the favoured side lost no units at all — but that the underdog
## STOPS PRODUCING while sitting on 7,500 banked Credits and an empty board.
##
## This replays that exact match and, every turn, reports the underdog's produce
## eligibility broken into its individual gates, so the blocking one is named rather
## than inferred:
## [br]• Credits, AP, in-deficit flag
## [br]• population headroom (can_field)
## [br]• legal deploy tiles for each producer it owns
## [br]• what validate_produce actually returns
##
## Usage: `./redot --headless tools/DiagnoseCliff.tscn`
extends Node

const MAP_WIDTH: int = 12
const MAP_HEIGHT: int = 10
const HQ_A: Vector2i = Vector2i(2, 5)
const HQ_B: Vector2i = Vector2i(9, 5)
const BONUS_ID_BASE: int = 500
const MAX_TURNS: int = 40

var _favoured: int = 0
var _underdog: int = 1


func _ready() -> void:
	_run()


func _run() -> void:
	var state: GameState = _build()
	print("DIAGNOSE CLIFF — +1 Trooper handicap, favoured P%d, underdog P%d\n"
			% [_favoured, _underdog])
	print("turn | u:units cred    AP  def | can_field | deploy | validate_produce")
	print("-----|------------------------|-----------|--------|------------------")

	var turn: int = 0
	while state.match_status != GameState.MatchStatus.GAME_OVER and turn < MAX_TURNS:
		turn += 1
		if state.active_player == _underdog:
			_report(state, turn)
		_run_one_turn(state)
	print("\nended turn %d, winner P%d" % [turn, state.winner])
	get_tree().quit()


func _report(state: GameState, turn: int) -> void:
	var p: int = _underdog
	var units: int = 0
	var producers: Array[StructureState] = []
	for e: EntityState in state.entities():
		if e.owner != p:
			continue
		if e is UnitState:
			units += 1
		elif e is StructureState:
			var st: StructureState = e
			if st.type != null and not st.type.producible_types.is_empty():
				producers.append(st)

	var ps: PlayerState = state.per_player[p]
	var can_field: bool = Population.can_field(state, p, UnitTypes.SCOUT)

	var deploy_total: int = 0
	var reason_text: String = "no producer"
	for prod: StructureState in producers:
		var tiles: Array[Vector2i] = BaseProduction.legal_deploy_tiles(state, prod, null)
		deploy_total += tiles.size()
		if reason_text == "no producer" or reason_text.begins_with("REJECT"):
			var pa := ProduceAction.new()
			pa.player = p
			pa.producer_id = prod.entity_id
			pa.unit_type = UnitTypes.SCOUT
			pa.tile = tiles[0] if not tiles.is_empty() else Vector2i(-1, -1)
			var r: int = BaseProduction.validate_produce(state, pa)
			reason_text = ("OK" if r == Action.Reason.OK
					else "REJECT %s" % Action.Reason.keys()[r])

	# Who is standing on the HQ's spawn ring? The whole cliff turns on this.
	var ring: Array[String] = []
	for prod: StructureState in producers:
		for n: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var t: Vector2i = prod.position + n
			if not state.grid.in_bounds(t.x, t.y):
				ring.append("edge"); continue
			var occ: int = state.grid.occupant_at(t.x, t.y)
			if occ == GridState.EMPTY_OCCUPANT:
				ring.append("free")
			else:
				var ent: EntityState = state.entities_by_id.get(occ)
				ring.append(("ENEMY" if ent != null and ent.owner != p else "own"))
	print("%4d | u:%-2d %6d %5d %5s | %-9s | %6d | %-28s | ring %s" % [
		turn, units, ps.current_credits, ps.current_ap,
		"YES" if ps.in_deficit else "no",
		"YES" if can_field else "NO",
		deploy_total, reason_text, "/".join(ring)])


func _run_one_turn(state: GameState) -> void:
	var rejects: int = 0
	var economy_investments: int = 0
	while true:
		var action: Action = AI.choose_action(state, economy_investments)
		if action == null or action is EndTurnAction:
			break
		var result: ActionResult = state.apply_action(action)
		if not result.ok:
			rejects += 1
			if rejects > 8:
				break
			continue
		rejects = 0
		if action.verb == Action.Verb.RESEARCH:
			economy_investments += 1
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			return
	var end_turn := EndTurnAction.new()
	end_turn.player = state.active_player
	state.apply_action(end_turn)


func _build() -> GameState:
	var map := MapDefinition.new()
	map.width = MAP_WIDTH
	map.height = MAP_HEIGHT
	map.mode = MapDefinition.Mode.AUTHORED
	var terrain := PackedByteArray()
	terrain.resize(MAP_WIDTH * MAP_HEIGHT)
	terrain.fill(GridState.Terrain.PLAIN)
	map.authored_terrain = terrain
	map.hq_tiles = [HQ_A, HQ_B]
	map.deploy_tiles = []

	var state: GameState = GameState.start_match(map, 0)
	state.max_rounds = VerticalSliceRoot.VS_MAX_ROUNDS
	state.per_player[0].faction = Factions.RUSH
	state.per_player[1].faction = Factions.BOOM
	state.per_player[0].is_ai_controlled = true
	state.per_player[1].is_ai_controlled = true

	for player: int in map.hq_tiles.size():
		var s := StructureState.new()
		s.entity_id = player
		s.owner = player
		s.position = map.hq_tiles[player]
		s.type = StructureTypes.HQ
		s.current_hp = StructureTypes.HQ.hp
		s.build_status = StructureState.BuildStatus.COMPLETED
		state.entities_by_id[s.entity_id] = s

	# The single bonus Trooper that produces the cliff.
	var tile := Vector2i(HQ_A.x + 1, HQ_A.y)
	var u := UnitState.new()
	u.entity_id = BONUS_ID_BASE
	u.owner = _favoured
	u.position = tile
	u.type = UnitTypes.TROOPER
	u.current_hp = UnitTypes.TROOPER.hp
	state.grid.place(u.entity_id, tile.x, tile.y)
	state.entities_by_id[u.entity_id] = u
	return state
