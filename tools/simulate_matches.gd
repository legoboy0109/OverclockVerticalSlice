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
## ★ S7-16: widened 4 -> 12. The mirror cell is the ONLY one that can measure a turn-order
## effect — every handicap cell starts with a material asymmetry that swamps it — and at n=4 it
## could not support tuning a compensation value. The first four entries are unchanged and in
## their original order, so every batch recorded before S7-16 stays comparable.
##
## Each entry is an offset from a player's OWN HQ, applied in that player's own forward
## direction, so both seats are seeded identically in their own frame. ⚠ Offsets of x=3 put the
## two seeded Troopers in immediate contact (west lands on x=5, east on x=6) — that is a real
## opening shape, not a mistake, and it belongs in the sample.
const MIRROR_OPENINGS: Array[Vector2i] = [
	Vector2i(0, 0),   # no seed units -- the original bare-HQ mirror, preserved as a baseline
	Vector2i(2, -1),  # seeded forward and high
	Vector2i(2, 1),   # seeded forward and low
	Vector2i(3, 0),   # seeded further forward, level -- immediate contact
	# --- S7-16 additions ---
	Vector2i(1, 0),   # hugging the HQ, level
	Vector2i(2, 0),   # forward, level
	Vector2i(1, -2),  # close and wide high (lands on a cover tile)
	Vector2i(1, 2),   # close and wide low  (lands on a cover tile)
	Vector2i(2, -2),  # forward and wide high
	Vector2i(2, 2),   # forward and wide low
	Vector2i(3, -1),  # far forward, high -- immediate contact
	Vector2i(3, 1),   # far forward, low  -- immediate contact
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

## ★ S7-11 — force the pre-cover, terrain-free board.
##
## The shipping map now carries 14 Cover tiles ([VSMap]). Every batch recorded before S7-11
## ran on a board with no terrain at all, so this exists purely so a new run can be compared
## against those numbers on equal footing. [b]Nothing that ships passes this.[/b]
##
## Usage: `./redot --headless tools/SimulateMatches.tscn -- --plain`
var _plain_map: bool = false

## ★ S7-12 — override the round cap for a batch, so the shipped value can be CHOSEN from a
## curve rather than guessed. 0 = use [constant VerticalSliceRoot.VS_MAX_ROUNDS].
##
## The cap became the binding constraint on close games after S7-10 (faster reinforcement)
## and S7-11 (cover) both lengthened matches — it was calibrated before either.
var _max_rounds_override: int = 0

## ★ S7-13 — force which seat moves first, for every game in the batch. -1 = the default
## (mirror cell alternates by variant; handicap cells always start P0).
##
## [b]This exists to separate two hypotheses that the default batch cannot tell apart.[/b]
## "P1 wins every close game" and "whoever moves SECOND wins every close game" fit the same
## data, because the handicap cells always start P0 — so P1 is always the second mover there.
## They need opposite fixes, so guessing is not an option.
var _start_player_override: int = -1

## ★ S7-13 — swap which HQ each seat owns, so the bias can be attributed.
##
## The map is mirror-symmetric and the seats are mechanically identical, yet P1 wins the
## mirror cell 3/4 no matter who moves first. Two candidates remain: something intrinsic to
## the player INDEX (entity-id ordering, tie-breaks) or something about the POSITION each
## seat starts from. Swapping the HQs separates them: if P1 keeps winning, it is the index;
## if the winner follows the west HQ, it is the position.
var _swap_hqs: bool = false

## ★ S7-16 — override [member EconomyConfig.first_turn_ap_bonus] for a batch, so the shipped
## value is chosen from a curve rather than guessed. -1 = use the configured value.
var _first_turn_ap_override: int = -1

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
		elif arg == "--plain":
			_plain_map = true
		elif arg.begins_with("--max-rounds="):
			_max_rounds_override = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--start-player="):
			_start_player_override = clampi(int(arg.split("=")[1]), 0, 1)
		elif arg == "--swap-hqs":
			_swap_hqs = true
		elif arg.begins_with("--first-turn-ap="):
			_first_turn_ap_override = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--variants="):
			_variants = clampi(int(arg.split("=")[1]), 1, _VARIANT_Y_OFFSETS.size())
	if _degrade_favoured_pct != 0 or _only_handicap != -1 or _variants != 3 or _plain_map:
		print("SIM_CONFIG,degrade_favoured_pct=%d,only_handicap=%d,variants=%d,plain=%s" % [
			_degrade_favoured_pct, _only_handicap, _variants, str(_plain_map)
		])
	# ★ Always announce the terrain actually in play. The S7-10 cover experiment silently
	# no-opped (PackedByteArray is a value type) and produced a sweep byte-identical to its
	# own baseline; the numbers were clean, confident and meaningless. Report, do not assume.
	if _start_player_override >= 0:
		print("SIM_START_OVERRIDE,forced_starting_player=%d" % _start_player_override)
	print("SIM_TERRAIN,cover_tiles=%d,of=%d,plain=%s,max_rounds=%d" % [
		0 if _plain_map else VSMap.COVER_TILES.size(), VSMap.WIDTH * VSMap.HEIGHT, str(_plain_map),
		_max_rounds_override if _max_rounds_override > 0 else VerticalSliceRoot.VS_MAX_ROUNDS
	])


## Deterministic per-(game, turn) draw in [0, 100). ★ Never [method @GlobalScope.randi] —
## ADR-0003 forbids unseeded RNG anywhere near a reproducible measurement, and a sweep whose
## rows cannot be re-derived is not evidence. Same inputs always give the same draw.
static func _draw(game: int, turn: int) -> int:
	var h: int = (game * 73856093) ^ (turn * 19349663)
	return absi(h) % 100


func _run() -> void:
	# ⚠ Mutates the shared EconomyConfig resource for the whole batch. Acceptable in a
	# measurement tool; never do this in shipped code.
	if _first_turn_ap_override >= 0:
		Balance.economy.first_turn_ap_bonus = _first_turn_ap_override
		print("SIM_FIRST_TURN_AP,bonus=%d" % _first_turn_ap_override)
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
	# ★ S7-11 — cover occupancy, emitted as its OWN row type rather than appended to SIM.
	# analyse_swing.py pins the SIM column map to this emitter by hand, with a comment
	# recording that a first pass read it one column early and produced a confident,
	# entirely wrong report. Widening that row to answer a new question is not worth
	# re-opening that failure mode.
	#
	# This exists because "the AI uses cover" must be MEASURED, not assumed: the S7-10
	# cover experiment silently no-opped and returned numbers identical to its own
	# baseline. If these counts are flat zero, the AI is not using cover whatever the
	# scoring says.
	var on_cover: Array[int] = [0, 0]
	for id: int in state.entities_by_id:
		var e: EntityState = state.entities_by_id[id]
		if e is UnitState and e.owner >= 0 and e.owner <= 1 \
				and state.grid.is_cover(e.position.x, e.position.y):
			on_cover[e.owner] += 1
	print("SIM_COVER_USE,%d,%d,%d,%d" % [game, turn, on_cover[0], on_cover[1]])


## Builds a vertical-slice-parity match, then grants [param handicap] bonus Troopers to
## [param favoured]. Mirrors VerticalSliceRoot._build_match, including the HQ promotion
## that start_match leaves as bare stubs.
func _build_match(favoured: int, handicap: int, variant: int) -> GameState:
	# ★ S7-11: the map now comes from VSMap, the SAME definition the slice builds from.
	# This file's own header demands it mirror the slice; hand-building the map here was
	# only ever safe while every tile was Plain. `--plain` forces the pre-cover board so a
	# batch can be compared against everything recorded before S7-11.
	var map: MapDefinition = VSMap.build(_plain_map)
	# ★ Which tile each SEAT owns. With --swap-hqs this is reversed, and every placement
	# below must follow it. The first version of the swap read the VSMap.HQ_A/HQ_B constants
	# directly, so a swapped player's bonus Troopers spawned next to the ENEMY base — a
	# confound that produced a confident, completely wrong attribution before it was caught.
	# ⚠ Built with a typed literal and an if, not a ternary: `[a,b] if c else [d,e]` infers a
	# plain Array in GDScript and will not assign to an Array[Vector2i].
	var hq_of: Array[Vector2i] = [VSMap.HQ_A, VSMap.HQ_B]
	if _swap_hqs:
		hq_of = [VSMap.HQ_B, VSMap.HQ_A]
	map.hq_tiles = hq_of

	# ★ S5-04: alternate the starting player across mirror openings. On a symmetric
	# board with a deterministic AI, who moves first is the only asymmetry there is,
	# and it is a real one -- so it belongs in the sample rather than being fixed.
	var starting_player: int = (variant % 2) if handicap == 0 else 0
	if _start_player_override >= 0:
		starting_player = _start_player_override
	var state: GameState = GameState.start_match(map, starting_player)
	# Mirror the slice: the round cap is armed there, so simulating without it would
	# measure a configuration that no longer ships.
	state.max_rounds = _max_rounds_override if _max_rounds_override > 0 \
		else VerticalSliceRoot.VS_MAX_ROUNDS
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
				# Push each seed unit AWAY from its own HQ, toward the middle — derived
				# from the HQ the seat actually owns, so --swap-hqs stays honest.
				var own_hq: Vector2i = hq_of[player]
				var dir: int = 1 if own_hq.x < VSMap.WIDTH / 2 else -1
				var tile := Vector2i(own_hq.x + off.x * dir, own_hq.y + off.y)
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
		var tile: Vector2i = _bonus_tile(hq_of[favoured], i, variant)
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


## ⚠ Takes the favoured seat's OWN HQ tile rather than deriving it from the seat index.
## Deriving it was a real defect: under --swap-hqs the favoured player's bonus Troopers were
## placed beside the enemy base, which silently invalidated the whole attribution experiment.
func _bonus_tile(own_hq: Vector2i, index: int, variant: int) -> Vector2i:
	# Forward = toward the middle of the map, whichever side this HQ sits on.
	var dir: int = 1 if own_hq.x < VSMap.WIDTH / 2 else -1
	var dy: int = _VARIANT_Y_OFFSETS[variant % _VARIANT_Y_OFFSETS.size()]
	return Vector2i(own_hq.x + dir * (1 + index), own_hq.y + dy)

