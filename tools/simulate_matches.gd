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

## ★ S5-04: symmetric openings for the CLOSE-game cell.
##
## The handicap axis above produces *decided* games by construction -- a side handed
## extra units is ahead from turn 0, so those cells measure whether an advantage
## CONVERTS, not whether a game can swing. Only the +0 mirror is a genuinely close
## game, and it was effectively n=1: `variant` reached the board solely through
## [method _bonus_tile], which is inside the handicap loop, so at handicap 0 all
## three "variants" were byte-identical runs of one deterministic match.
##
## These give the mirror cell real variety without giving either side an edge: each
## entry seeds BOTH players one Trooper at mirrored tiles, and the starting player
## alternates. Fair openings, different games.
##
## Handicap cells are deliberately left untouched so the S6-06 gate numbers stay
## comparable across batches.
const MIRROR_OPENINGS: Array[Vector2i] = [
	Vector2i(0, 0),   # no seed units -- the original bare-HQ mirror, preserved as a baseline
	Vector2i(2, -1),  # seeded forward and high
	Vector2i(2, 1),   # seeded forward and low
	Vector2i(3, 0),   # seeded further forward, level
]


## ★ S7-09 EXPERIMENT KNOB — play-strength degradation applied to the FAVOURED side only.
##
## [b]Why this exists.[/b] S5-04 reported "the +1 cell shows ZERO lead changes" and read it
## as *the game has no recoverable middle*. But this harness drives BOTH seats with the same
## [method AI.choose_action] and the same weights, fully deterministically — there is no
## skill differential anywhere in it. Equal play from a worse position losing every single
## time is arithmetic, not a design property.
##
## ⇒ **The harness could not express the thing the conclusion was about.** A comeback requires
## the trailing player to play BETTER, and nothing here can play better or worse than anything
## else. This knob introduces the missing variable so the question becomes answerable.
##
## [b]The model.[/b] With probability [code]_degrade_favoured_pct[/code] per turn, the favoured
## side commits at most ONE action that turn instead of playing its turn out. That is "played a
## worse turn" rather than "did not show up" — monotone in the percentage, and it never makes
## the favoured side do anything illegal or actively self-harming.
##
## ⚠ [b]Default 0 = byte-identical to the shipped batch.[/b] The S6-06 gate numbers must stay
## comparable, so the degradation path is entirely inert unless asked for.
##
## Usage:
## [codeblock]
## ./redot --headless tools/SimulateMatches.tscn -- --degrade-favoured=20 --only-handicap=1
## [/codeblock]
var _degrade_favoured_pct: int = 0

## Restricts the batch to a single handicap cell (-1 = all). The sweep only needs +1, and a
## full batch is ~25 minutes against ~7 for one cell.
var _only_handicap: int = -1

## ★ S7-10 EXPERIMENT KNOB — cover density on the simulated map, as a percentage.
##
## [b]Why this exists.[/b] Every measurement this project has ever taken ran on a board with
## [b]no terrain at all[/b]: both this harness and [method VerticalSliceRoot._build_match] fill
## their map with [code]GridState.Terrain.PLAIN[/code]. Cover is fully implemented — a
## [member CombatConfig.cover_dr] constant, [method GridState.is_cover], and shipped
## `tile_cover` art from S4 — and [b]no map in the project places a single cover tile.[/b]
##
## ⇒ That matters for the swing question specifically. With every tile identical, the only
## variables in an exchange are unit count and position, so **unit count dominates by
## construction**. Cover is the game's built-in way for a well-placed defender to win a fight
## they are numerically losing — i.e. exactly the "skill route back" the cliff work is about,
## built and never switched on.
##
## ⚠ [b]Default 0 keeps the harness faithful to the shipped slice[/b], which is also plain.
## This knob measures what cover WOULD do; it does not decide that the game should have it.
##
## Tiles are placed mirror-symmetrically about the vertical axis so neither seat is favoured.
var _cover_pct: int = 0

## Variants per handicap cell (default 3 = the shipped batch). ★ Raised only for experiments:
## the +1 cell at 3 variants is n=6, which is too thin to read a gradient from — the S7-09
## sweep's first pass showed a non-monotone dip that was purely sample noise.
var _variants: int = 3


func _ready() -> void:
	_parse_args()
	_run()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--degrade-favoured="):
			_degrade_favoured_pct = int(arg.split("=")[1])
		elif arg.begins_with("--only-handicap="):
			_only_handicap = int(arg.split("=")[1])
		elif arg.begins_with("--cover="):
			_cover_pct = clampi(int(arg.split("=")[1]), 0, 40)
		elif arg.begins_with("--variants="):
			_variants = clampi(int(arg.split("=")[1]), 1, _VARIANT_Y_OFFSETS.size())
	if _degrade_favoured_pct != 0 or _only_handicap != -1 or _variants != 3 or _cover_pct != 0:
		print("SIM_CONFIG,degrade_favoured_pct=%d,only_handicap=%d,variants=%d,cover_pct=%d" % [
			_degrade_favoured_pct, _only_handicap, _variants, _cover_pct
		])


## Deterministic per-(game, turn) draw in [0, 100). ★ Never [method @GlobalScope.randi] —
## ADR-0003 forbids unseeded RNG anywhere near a reproducible measurement, and a sweep whose
## rows cannot be re-derived is not evidence. Same inputs always give the same draw.
static func _draw(game: int, turn: int) -> int:
	var h: int = (game * 73856093) ^ (turn * 19349663)
	return absi(h) % 100


func _run() -> void:
	var game: int = 0
	for handicap: int in HANDICAPS:
		if _only_handicap != -1 and handicap != _only_handicap:
			continue
		for favoured: int in [0, 1]:
			if handicap == 0 and favoured == 1:
				continue # symmetric is the same game twice; run it once.
			# ★ S5-04: the mirror cell runs one game per symmetric opening (each a
			# genuinely different close game); handicap cells keep their original
			# three variants so gate numbers stay comparable batch to batch.
			var count: int = MIRROR_OPENINGS.size() if handicap == 0 else _variants
			for variant: int in count:
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
		_run_one_turn(state, game, turn, favoured)
	var capped: int = 1 if turn >= MAX_TURNS else 0
	print("SIM_END,%d,%d,%d,%d,%d,%d,%d" % [
		game, favoured, handicap, variant, turn, state.winner, capped
	])


## The shipped AI turn loop with the pacing timer removed — otherwise identical to
## [method AITurnDriver.run_ai_turn], including the reject bound and the trailing
## [EndTurnAction] that hands the turn back.
func _run_one_turn(state: GameState, game: int = 0, turn: int = 0, favoured: int = -1) -> void:
	var economy_investments: int = 0
	var rejects: int = 0
	var committed: int = 0
	# ★ S7-09: at most one action this turn, for the favoured side only, on a draw that
	# fires _degrade_favoured_pct of the time. Inert at the default 0.
	var capped_turn: bool = (
		_degrade_favoured_pct > 0
		and state.active_player == favoured
		and _draw(game, turn) < _degrade_favoured_pct
	)
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
		committed += 1
		# Must match AITurnDriver._is_economy_or_research EXACTLY — this counter feeds
		# back into AI.choose_action's cadence cap (ADR-0011 §1/§6), so a looser rule
		# here would silently simulate a different AI than the one that ships.
		# ★ S6-09: RESEARCH only — a Factory build is not an economy investment (it
		# grants no income; the ECONOMY_OUTPOST identity was carried onto it by
		# S6-03's mechanical rename). Kept in lockstep with the driver by hand;
		# ai_economy_throttle_parity_test.gd asserts the two agree.
		if action.verb == Action.Verb.RESEARCH:
			economy_investments += 1
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			return
		if capped_turn and committed >= 1:
			break
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
	terrain = _scatter_cover(terrain)
	map.authored_terrain = terrain
	map.hq_tiles = [HQ_A, HQ_B]
	map.deploy_tiles = []

	# ★ S5-04: alternate the starting player across mirror openings. On a symmetric
	# board with a deterministic AI, who moves first is the only asymmetry there is,
	# and it is a real one -- so it belongs in the sample rather than being fixed.
	var starting_player: int = (variant % 2) if handicap == 0 else 0
	var state: GameState = GameState.start_match(map, starting_player)
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

	# ★ S5-04 mirror seeding: BOTH players get the same unit at mirrored tiles, so
	# the position differs between variants while staying exactly fair.
	if handicap == 0 and variant < MIRROR_OPENINGS.size():
		var off: Vector2i = MIRROR_OPENINGS[variant]
		if off != Vector2i.ZERO:
			for player: int in 2:
				var dir: int = 1 if player == 0 else -1
				var tile := Vector2i(HQ_A.x + off.x * dir if player == 0 \
						else HQ_B.x + off.x * dir, HQ_A.y + off.y)
				if not state.grid.in_bounds(tile.x, tile.y):
					continue
				if state.grid.occupant_at(tile.x, tile.y) != GridState.EMPTY_OCCUPANT:
					continue
				var seed_unit := UnitState.new()
				seed_unit.entity_id = BONUS_ID_BASE + 900 + player
				seed_unit.owner = player
				seed_unit.position = tile
				seed_unit.type = UnitTypes.TROOPER
				seed_unit.current_hp = UnitTypes.TROOPER.hp
				state.grid.place(seed_unit.entity_id, tile.x, tile.y)
				state.entities_by_id[seed_unit.entity_id] = seed_unit

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
## ★ S7-09: offsets are a TABLE rather than `hq.y - 1 + variant` so the variant count can
## be raised for statistical power without walking the bonus units off the map. The first
## three entries reproduce the old arithmetic EXACTLY (-1, 0, +1), so every previously
## recorded batch number stays comparable; entries 3+ fan out symmetrically instead of
## marching in one direction toward the south edge.
const _VARIANT_Y_OFFSETS: Array[int] = [-1, 0, 1, -2, 2, -3, 3]


func _bonus_tile(favoured: int, index: int, variant: int) -> Vector2i:
	var hq: Vector2i = HQ_A if favoured == 0 else HQ_B
	var dir: int = 1 if favoured == 0 else -1
	var dy: int = _VARIANT_Y_OFFSETS[variant % _VARIANT_Y_OFFSETS.size()]
	return Vector2i(hq.x + dir * (1 + index), hq.y + dy)


## Paints [member _cover_pct] percent of the board as Cover, mirror-symmetric about the
## vertical axis. No-op at the default 0.
##
## ★ Symmetry is not cosmetic here. The batch already alternates the starting player because
## on a symmetric board that is the only asymmetry there is; an asymmetric cover layout would
## quietly hand one seat an advantage and every "not seat-determined" reading downstream would
## be measuring the map instead of the game.
##
## ⚠ HQ tiles and their immediate surroundings are left clear so cover never interacts with
## the deploy ring — that rule has caused one game-ending defect already (the S6-15 latch) and
## this experiment has no business perturbing it.
## ⚠ [b]Returns the array rather than mutating in place.[/b] A [PackedByteArray] is a value
## type in GDScript — mutating a parameter writes to a local copy and the caller keeps the
## original. The first version of this took the array and mutated it, and the sweep came back
## byte-identical to the no-cover baseline: the knob silently did nothing. ★ Same family as the
## S7-03 guard that could not fail — **an experiment that quietly no-ops produces clean,
## confident, meaningless numbers.** The `SIM_COVER` line below exists so that can never happen
## again unnoticed.
func _scatter_cover(terrain: PackedByteArray) -> PackedByteArray:
	if _cover_pct <= 0:
		return terrain
	var target: int = (MAP_WIDTH * MAP_HEIGHT * _cover_pct) / 100
	var placed: int = 0
	# Walk the left half in a fixed order; mirror each placement to the right half.
	for x: int in range(1, MAP_WIDTH / 2):
		for y: int in MAP_HEIGHT:
			if placed >= target:
				_report_cover(placed)
				return terrain
			var here := Vector2i(x, y)
			var mirror := Vector2i(MAP_WIDTH - 1 - x, y)
			if _too_close_to_a_hq(here) or _too_close_to_a_hq(mirror):
				continue
			# Fixed deterministic pattern rather than a draw: every third tile on a
			# staggered diagonal, which spreads cover instead of clumping it.
			if (x * 3 + y * 5) % 7 >= 3:
				continue
			terrain[here.y * MAP_WIDTH + here.x] = GridState.Terrain.COVER
			terrain[mirror.y * MAP_WIDTH + mirror.x] = GridState.Terrain.COVER
			placed += 2
	_report_cover(placed)
	return terrain


## Emitted once per match so a run can be checked for "did the knob actually do anything".
var _cover_reported: bool = false


func _report_cover(placed: int) -> void:
	if _cover_reported:
		return
	_cover_reported = true
	print("SIM_COVER,requested_pct=%d,tiles_placed=%d,of=%d" % [
		_cover_pct, placed, MAP_WIDTH * MAP_HEIGHT
	])


func _too_close_to_a_hq(tile: Vector2i) -> bool:
	for hq: Vector2i in [HQ_A, HQ_B]:
		if absi(tile.x - hq.x) + absi(tile.y - hq.y) <= 2:
			return true
	return false
