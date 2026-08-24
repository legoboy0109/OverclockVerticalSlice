## simulate_matches.gd — headless AI-vs-AI match simulator for S5-04's MEASURABLE half.
##
## [b]This is not a substitute for the swing-back playtest.[/b] S5-04 asks two kinds of
## question. Some are judgements only a person can make — does the swing FEEL alive, does
## tempo read at a glance, does spending on economy FEEL like a tempo cost. This tool
## cannot answer any of those and does not try.
##
## What it CAN answer is the half that is structural, and that includes **the one hard
## gate**: "no decided game reverses". Whether a player who has built a decisive lead can
## nevertheless lose is a property of the rules, measurable over many games, and it has
## been blocked behind a human session for three sprints.
##
## Both sides are driven by the shipped [AI] — the same [method AI.choose_action] the
## vertical slice uses, with the driver's pacing timer removed. Games are differentiated
## by a deliberate starting-material handicap, which the protocol explicitly sanctions
## ("note any self-handicap used to force genuinely close/undecided games"): a symmetric
## start tends to produce close games, an asymmetric one tends to produce decided games,
## and the decided ones are what the no-reversal gate needs.
##
## Emits one CSV row per turn on stdout, prefixed `SIM,` so it can be filtered out of
## engine chatter. Post-processed by the analysis in the session record.
##
## Usage: `./redot --headless tools/SimulateMatches.tscn`
##
## [b]A scene, not a `--script` SceneTree.[/b] The balance and registry Autoloads
## (`Balance`, `UnitTypes`, `CombatBalance`, `AIBalance`, ...) are not registered in
## `--script` mode, so every config read fails to compile there. Running a scene through
## the ordinary main loop gets them. Same trap the capture harness hit — see
## `.agent/notes.md`.
extends Node

const MAP_WIDTH: int = 12
const MAP_HEIGHT: int = 10
const HQ_A: Vector2i = Vector2i(2, 5)
const HQ_B: Vector2i = Vector2i(9, 5)

## Bound on turns per game, so a stalemate cannot hang the batch. Games that hit this
## are reported as CAPPED and excluded from closeout statistics — a capped game has no
## meaningful "closeout length".
const MAX_TURNS: int = 200

## Starting bonus units granted to one side, in each direction plus symmetric. This is
## the axis that produces both close and decided games from a deterministic AI.
const HANDICAPS: Array[int] = [0, 1, 2, 3]

## Entity ids for injected bonus units start here, well clear of the ids start_match
## allocates for HQs.
const BONUS_ID_BASE: int = 500


func _ready() -> void:
	_run()


func _run() -> void:
	var game: int = 0
	for handicap: int in HANDICAPS:
		for favoured: int in [0, 1]:
			if handicap == 0 and favoured == 1:
				continue # symmetric is the same game twice; run it once.
			for variant: int in 3:
				game += 1
				_play(game, favoured, handicap, variant)
	print("SIM_DONE")
	get_tree().quit()


## Plays one match to completion, emitting a per-turn snapshot row.
##
## [param variant] perturbs the bonus units' starting tiles so three games at the same
## handicap are not byte-identical — the AI is deterministic, so without this every game
## in a cell would be the same game.
func _play(game: int, favoured: int, handicap: int, variant: int) -> void:
	var state: GameState = _build_match(favoured, handicap, variant)
	var turn: int = 0
	while state.match_status != GameState.MatchStatus.GAME_OVER and turn < MAX_TURNS:
		turn += 1
		_snapshot(game, favoured, handicap, variant, turn, state)
		_run_one_turn(state)
	var capped: int = 1 if turn >= MAX_TURNS else 0
	print("SIM_END,%d,%d,%d,%d,%d,%d,%d" % [
		game, favoured, handicap, variant, turn, state.winner, capped
	])


## The shipped AI turn loop with the pacing timer removed — otherwise identical to
## [method AITurnDriver.run_ai_turn], including the reject bound and the trailing
## [EndTurnAction] that hands the turn back.
func _run_one_turn(state: GameState) -> void:
	var economy_investments: int = 0
	var rejects: int = 0
	while true:
		var action: Action = AI.choose_action(state, economy_investments)
		if action == null:
			break
		var result: ActionResult = state.apply_action(action)
		if not result.ok:
			rejects += 1
			if rejects >= 8:
				break
			continue
		rejects = 0
		# Must match AITurnDriver._is_economy_or_research EXACTLY — this counter feeds
		# back into AI.choose_action's cadence cap (ADR-0011 §1/§6), so a looser rule
		# here would silently simulate a different AI than the one that ships.
		if action.verb == Action.Verb.RESEARCH \
				or (action is BuildAction \
					and (action as BuildAction).structure_type == StructureTypes.FACTORY):
			economy_investments += 1
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			return
	var end_turn := EndTurnAction.new()
	end_turn.player = state.active_player
	state.apply_action(end_turn)


## One row per turn: the material and economy position of both sides, which is what the
## lead curve and the reversal check are computed from downstream.
func _snapshot(game: int, favoured: int, handicap: int, variant: int, turn: int, state: GameState) -> void:
	var hp: Array[int] = [0, 0]
	var units: Array[int] = [0, 0]
	var hq: Array[int] = [0, 0]
	for id: int in state.entities_by_id:
		var e: EntityState = state.entities_by_id[id]
		if e.owner < 0 or e.owner > 1:
			continue
		if e is UnitState:
			hp[e.owner] += (e as UnitState).current_hp
			units[e.owner] += 1
		elif e is StructureState:
			var st := e as StructureState
			if st.type == StructureTypes.HQ:
				hq[e.owner] += st.current_hp
			else:
				hp[e.owner] += st.current_hp
	print("SIM,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
		game, favoured, handicap, variant, turn, state.active_player,
		hp[0], hp[1], units[0], units[1], hq[0], hq[1],
		state.per_player[0].current_credits, state.per_player[1].current_credits,
		state.per_player[0].current_ap
	])


## Builds a vertical-slice-parity match, then grants [param handicap] bonus Troopers to
## [param favoured]. Mirrors VerticalSliceRoot._build_match, including the HQ promotion
## that start_match leaves as bare stubs.
func _build_match(favoured: int, handicap: int, variant: int) -> GameState:
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
	# Mirror the slice: the round cap is armed there, so simulating without it would
	# measure a configuration that no longer ships.
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

	for i: int in handicap:
		var tile: Vector2i = _bonus_tile(favoured, i, variant)
		if not state.grid.in_bounds(tile.x, tile.y):
			continue
		if state.grid.occupant_at(tile.x, tile.y) != GridState.EMPTY_OCCUPANT:
			continue
		var u := UnitState.new()
		u.entity_id = BONUS_ID_BASE + favoured * 50 + i
		u.owner = favoured
		u.position = tile
		u.type = UnitTypes.TROOPER
		u.current_hp = UnitTypes.TROOPER.hp
		state.grid.place(u.entity_id, tile.x, tile.y)
		state.entities_by_id[u.entity_id] = u
	return state


## Bonus units are placed near their owner's HQ, offset by [param variant] so the three
## games in a cell diverge.
func _bonus_tile(favoured: int, index: int, variant: int) -> Vector2i:
	var hq: Vector2i = HQ_A if favoured == 0 else HQ_B
	var dir: int = 1 if favoured == 0 else -1
	return Vector2i(hq.x + dir * (1 + index), hq.y - 1 + variant)
