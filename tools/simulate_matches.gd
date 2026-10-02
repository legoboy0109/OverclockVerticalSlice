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
## ⚠ Player turns, not rounds: two per round. Must exceed 2 × MatchSettings.ROUNDS_MAX, or a map
## with a long round limit (Highlands 160) is cut off by this safety net instead of its own limit.
const MAX_TURNS: int = 2 * 200 + 2

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

## ★ 2026-10-01 (tech-tree balance): a fixed research path per seat — `--plan0=A|B|C` /
## `--plan1=...` (tech display names, in order). Whenever that seat's researcher is idle, the
## next unfinished tech on its path starts [b]free[/b] (no Credits, no AP): the experiment
## compares two branches of the same tier, which cost the same, so waiving the price removes
## the "could it afford it this turn" noise without favouring either side. Once a path is
## exhausted the AI researches on its own as usual. Empty = shipped behaviour.
var _plans: Array = [[], []]

## `--free-lab`: both seats start with a completed Research Lab beside their HQ, so tier-2+
## techs on a path are reachable without depending on whether the AI chooses to build one.
var _free_lab: bool = false

## Keys "game|player|type" already reported by SIM_FIRST_BUILD.
var _first_built: Dictionary = {}

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
var _produced: Dictionary = {}
var _built: Dictionary = {}
var _factions: Array[FactionDef] = [Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE]
var _abilities: Dictionary = {}
var _dump_turn: int = -1
## Diagnostic (2026-09-28): --push-trace prints a SIM_PUSH row at the start of every turn — the
## active side's fighters, its largest group, units ready to push, and defenders at the enemy HQ.
var _push_trace: bool = false
## --research-trace: whenever the AI starts a tech, one SIM_RVAL row listing every tree-legal
## target with the AI's value for it (before the per-match lean), so a lopsided pick rate can be
## traced to the price that caused it (2026-10-02 balance pass).
var _research_trace: bool = false
## With --push-trace: "attacker type>victim type" -> kills, printed as SIM_KILL rows.
var _kills: Dictionary = {}
## With --ap-trace: AP spent per action category, summed over the batch (SIM_AP rows), plus one
## SIM_APTURN row per turn: player, AP at start, AP left, how the turn ended, the AI's thinking
## time that turn in ms, and how many entities were on the board.
var _ap_trace: bool = false
## --econ=flat_ap_per_turn=N given: use it instead of the map's own default AP.
var _ap_override: bool = false
var _ap_spent: Dictionary = {}
## With --ap-trace: why each fighter that could have moved did not, at the end of its turn
## ("pushing:" prefix when it was ready to push). Printed as SIM_IDLE rows.
var _idle: Dictionary = {}
var _idle_detail: bool = false   # --idle-detail: split SIM_IDLE by unit type and move score
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
		elif arg.begins_with("--vehicle-scale="):
			# Balance experiment (2026-10-01): scale EVERY vehicle and aircraft at once, e.g.
			# --vehicle-scale=hp:125,attack:125,defense+:1 (percent for hp/attack, "+" adds a flat
			# amount). Mutates the loaded resources for this run only, like --unit-stat.
			for f: String in DirAccess.get_files_at("res://data/units"):
				if not f.ends_with(".tres"):
					continue
				var res: Resource = load("res://data/units/" + f)
				if not (res is UnitTypeDef) or (res as UnitTypeDef).unit_class == UnitTypeDef.UnitClass.INFANTRY:
					continue   # unit_config.tres lives in the same folder
				var vt: UnitTypeDef = res
				for part: String in arg.trim_prefix("--vehicle-scale=").split(","):
					var kv: PackedStringArray = part.split(":")
					if kv[0].ends_with("+"):
						var prop: String = kv[0].trim_suffix("+")
						vt.set(prop, int(vt.get(prop)) + int(kv[1]))
					elif int(vt.get(kv[0])) > 0:
						vt.set(kv[0], maxi(1, roundi(float(vt.get(kv[0])) * int(kv[1]) / 100.0)))
			print("SIM_VEHICLE_SCALE,%s" % arg.trim_prefix("--vehicle-scale="))
		elif arg.begins_with("--unit-stat="):
			# Balance experiment without touching the vault: --unit-stat=sniper.attack=5 (repeatable).
			# Mutates the loaded resource, which every reference shares, for this run only.
			var spec: PackedStringArray = arg.split("=")
			var unit_and_prop: PackedStringArray = spec[1].split(".")
			var ut: UnitTypeDef = load("res://data/units/%s.tres" % unit_and_prop[0])
			ut.set(unit_and_prop[1], int(spec[2]))
			print("SIM_UNIT_STAT,%s,%s,%d" % [unit_and_prop[0], unit_and_prop[1], int(ut.get(unit_and_prop[1]))])
		elif arg == "--idle-detail":
			_idle_detail = true
		elif arg.begins_with("--faction-stat="):
			# Faction experiment for this run only: --faction-stat=machinists_union.base_income_delta=-200
			# (repeatable). Mutates the loaded FactionDef, which every reference shares.
			var fspec: PackedStringArray = arg.trim_prefix("--faction-stat=").split("=")
			var fparts: PackedStringArray = fspec[0].split(".")
			var fd: FactionDef = load("res://data/factions/%s.tres" % fparts[0])
			fd.set(fparts[1], int(fspec[1]))
			print("SIM_FACTION_STAT,%s,%s,%d" % [fparts[0], fparts[1], int(fd.get(fparts[1]))])
		elif arg.begins_with("--combat="):
			# Combat-config experiment for this run only: --combat=rank_hp=0,1,3,5 (int lists) or
			# --combat=merit_per_kill=4. Sets the loaded CombatConfig every system reads.
			var ckv: PackedStringArray = arg.trim_prefix("--combat=").split("=")
			var cur: Variant = CombatBalance.combat.get(ckv[0])
			if cur is PackedInt32Array:
				CombatBalance.combat.set(ckv[0], PackedInt32Array(Array(ckv[1].split(",")).map(func(x: String) -> int: return int(x))))
			else:
				CombatBalance.combat.set(ckv[0], int(ckv[1]))
			print("SIM_COMBAT,%s,%s" % [ckv[0], str(CombatBalance.combat.get(ckv[0]))])
		elif arg.begins_with("--econ="):
			# Economy experiment for this run only: --econ=base_income=1500 (repeatable). Set on
			# the BASE config, because every game's Balance.reset() copies the match economy from it.
			var ekv: PackedStringArray = arg.trim_prefix("--econ=").split("=")
			Balance.base_economy.set(ekv[0], int(ekv[1]))
			if ekv[0] == "flat_ap_per_turn":
				_ap_override = true
			print("SIM_ECON,%s,%d" % [ekv[0], int(Balance.base_economy.get(ekv[0]))])
		elif arg.begins_with("--ai="):
			# AI-knob experiment for this run only: --ai=fortify_hold_rule=0 (repeatable).
			var kv: PackedStringArray = arg.trim_prefix("--ai=").split("=")
			var cur: Variant = AIBalance.ai.get(kv[0])
			var v: Variant = (kv[1] == "true") if cur is bool else (float(kv[1]) if cur is float else int(kv[1]))
			AIBalance.ai.set(kv[0], v)
			print("SIM_AI_KNOB,%s,%s" % [kv[0], str(AIBalance.ai.get(kv[0]))])
		elif arg == "--ap-trace":
			_ap_trace = true
		elif arg.begins_with("--econ-tiers="):
			# e.g. --econ-tiers=250,400,600 — income steps per Economy tech (EconomyConfig.econ_tier_bonuses).
			# ⚠ Mutates the shared config for the batch, like --econ=.
			Balance.economy.econ_tier_bonuses = PackedInt32Array(Array(arg.split("=")[1].split(",")).map(func(x: String) -> int: return int(x)))
			print("SIM_ECON_TIERS,%s" % str(Balance.economy.econ_tier_bonuses))
		elif arg == "--research-trace":
			_research_trace = true
		elif arg == "--push-trace":
			_push_trace = true
		elif arg.begins_with("--dump-turn="):
			# Diagnostic: print every entity's position at this turn (SIM_POS rows).
			_dump_turn = int(arg.split("=")[1])
		elif arg.begins_with("--map="):
			# ★ Bigger maps: e.g. --map=highlands (a vault map id). Default: the vertical slice.
			for mp: MapDefinition in Maps.all():
				if mp.resource_path.get_file().get_basename() == arg.split("=")[1]:
					VSMap.select(mp)
		elif arg.begins_with("--factions="):
			# ★ Faction waves (CR-10): e.g. --factions=solar_federation,democratic_alliance — the
			# ids are the vault notes' ids. Seat 0 plays the first. Default: Alliance mirror.
			var ids: PackedStringArray = arg.split("=")[1].split(",")
			for seat: int in mini(2, ids.size()):
				for f: FactionDef in Factions.ALL:
					if f.resource_path.get_file().get_basename() == ids[seat]:
						_factions[seat] = f
		elif arg.begins_with("--start-player="):
			_start_player_override = clampi(int(arg.split("=")[1]), 0, 1)
		elif arg == "--swap-hqs":
			_swap_hqs = true
		elif arg.begins_with("--first-turn-ap="):
			_first_turn_ap_override = maxi(0, int(arg.split("=")[1]))
		elif arg.begins_with("--variants="):
			_variants = clampi(int(arg.split("=")[1]), 1, _VARIANT_Y_OFFSETS.size())
		elif arg.begins_with("--plan0=") or arg.begins_with("--plan1="):
			var seat_idx: int = int(arg.substr(6, 1))
			for tech_name: String in arg.substr(8).split("|", false):
				var found: TechDef = null
				for t: TechDef in Techs.ALL:
					if t.display_name == tech_name:
						found = t
				if found == null:
					push_error("simulate_matches: unknown tech in plan: '%s'" % tech_name)
				else:
					_plans[seat_idx].append(found)
			print("SIM_PLAN,%d,%s" % [seat_idx, arg.substr(8)])
		elif arg == "--free-lab":
			_free_lab = true
			print("SIM_FREE_LAB")
	if _degrade_favoured_pct != 0 or _only_handicap != -1 or _variants != 3 or _plain_map:
		print("SIM_CONFIG,degrade_favoured_pct=%d,only_handicap=%d,variants=%d,plain=%s" % [
			_degrade_favoured_pct, _only_handicap, _variants, str(_plain_map)
		])
	# ★ Always announce the terrain actually in play. The S7-10 cover experiment silently
	# no-opped (PackedByteArray is a value type) and produced a sweep byte-identical to its
	# own baseline; the numbers were clean, confident and meaningless. Report, do not assume.
	if _start_player_override >= 0:
		print("SIM_START_OVERRIDE,forced_starting_player=%d" % _start_player_override)
	print("SIM_FACTIONS,%s,%s" % [_factions[0].display_name, _factions[1].display_name])
	print("SIM_MAP,%s,%dx%d" % [VSMap.data().display_name, VSMap.WIDTH, VSMap.HEIGHT])
	print("SIM_TERRAIN,cover_tiles=%d,of=%d,plain=%s,max_rounds=%d" % [
		0 if _plain_map else VSMap.COVER_TILES.size(), VSMap.WIDTH * VSMap.HEIGHT, str(_plain_map),
		_max_rounds_override if _max_rounds_override > 0 else VSMap.data().default_round_limit
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
	# ★ 2026-09-28: what the AI actually fields and raises, across the whole batch — so a new
	# unit or structure the AI never touches shows up as a zero rather than as silence.
	for key: String in _produced:
		print("SIM_PRODUCED,%s,%d" % [key, _produced[key]])
	for key: String in _built:
		print("SIM_BUILT,%s,%d" % [key, _built[key]])
	for key: String in _abilities:
		print("SIM_ABILITY,%s,%d" % [key, _abilities[key]])
	for key: String in _kills:
		print("SIM_KILL,%s,%d" % [key, _kills[key]])
	for key: String in _ap_spent:
		print("SIM_AP,%s,%d" % [key, _ap_spent[key]])
	for key: String in _idle:
		print("SIM_IDLE,%s,%d" % [key, _idle[key]])
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
		if _push_trace:
			_trace_push(game, turn, state)
		if turn == _dump_turn:
			for e: EntityState in state.entities():
				var tname: String = e.type.display_name if e.get("type") != null else "?"
				print("SIM_POS,%d,%d,%d,%s,%d,%d,%d" % [game, turn, e.owner, tname, e.position.x, e.position.y,
					(e as UnitState).current_hp if e is UnitState else (e as StructureState).current_hp])
		_run_one_turn(state, game, turn, favoured)
	var capped: int = 1 if turn >= MAX_TURNS else 0
	print("SIM_END,%d,%d,%d,%d,%d,%d,%d" % [
		game, favoured, handicap, variant, turn, state.winner, capped
	])
	# ★ CR-14: what each side researched, whether it raised a Lab, and HOW the game ended
	# (win_reason distinguishes an HQ kill from the round-cap tiebreak — SIM_END's `capped`
	# cannot, since the round cap ends games long before MAX_TURNS).
	for p: int in state.per_player.size():
		var names := PackedStringArray()
		for t: TechDef in state.per_player[p].completed_techs:
			names.append(t.display_name)
		print("SIM_RESEARCH,%d,%d,%d,%d,%s" % [game, p, state.win_reason,
			1 if Research._owns_completed(state, p, StructureTypes.RESEARCH_LAB) else 0, "|".join(names)])


## The shipped AI turn loop with the pacing timer removed — otherwise identical to
## [method AITurnDriver.run_ai_turn], including the reject bound and the trailing
## [EndTurnAction] that hands the turn back.
func _run_one_turn(state: GameState, game: int = 0, turn: int = 0, favoured: int = -1) -> void:
	_advance_plan(state)
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
	var ap_start: int = state.per_player[state.active_player].current_ap
	var think_start_usec: int = Time.get_ticks_usec()   # --ap-trace: the AI's thinking time this turn
	var ended_by: String = "rejects"
	while true:
		var action: Action = AI.choose_action(state, economy_investments)
		if action == null:
			ended_by = "nothing_worth_it"
			break
		var ap_key: String = _ap_category(state, action) if _ap_trace else ""
		if _research_trace and action is ResearchAction:
			var parts := PackedStringArray()
			for t: TechDef in Research.legal_research_targets(state, state.active_player):
				parts.append("%s:%.3f" % [t.display_name, AI._tech_research_value(state, state.active_player, t)])
			print("SIM_RVAL,%d,%d,%d,%s,%s" % [game, state.active_player, state.round_number,
				(action as ResearchAction).tech.display_name, ";".join(parts)])
		var ap_before: int = state.per_player[state.active_player].current_ap
		var victim_key: String = ""
		var victim_id: int = -1
		if _push_trace and action is AttackAction:
			var atk: EntityState = state.entity_at((action as AttackAction).attacker_tile)
			var vic: EntityState = state.entity_at((action as AttackAction).target_tile)
			if atk != null and vic != null:
				victim_id = vic.entity_id
				victim_key = "%s>%s" % [atk.type.display_name, vic.type.display_name]
		var result: ActionResult = state.apply_action(action)
		if _ap_trace and result.ok:
			_ap_spent[ap_key] = _ap_spent.get(ap_key, 0) + ap_before - state.per_player[state.active_player].current_ap
		if result.ok and victim_id >= 0 and not state.entities_by_id.has(victim_id):
			_kills[victim_key] = _kills.get(victim_key, 0) + 1
		if result.ok and action is ProduceAction:
			var key: String = (action as ProduceAction).unit_type.display_name
			_produced[key] = _produced.get(key, 0) + 1
		if result.ok and action is UseAbilityAction:
			var akey: String = (action as UseAbilityAction).ability.display_name
			_abilities[akey] = _abilities.get(akey, 0) + 1
		if result.ok and action is BuildAction:
			var bkey: String = (action as BuildAction).structure_type.display_name
			_built[bkey] = _built.get(bkey, 0) + 1
			# First time this seat raises this type, this game: SIM_FIRST_BUILD,game,player,type,round.
			var fkey: String = "%d|%d|%s" % [game, state.active_player, bkey]
			if not _first_built.has(fkey):
				_first_built[fkey] = true
				print("SIM_FIRST_BUILD,%d,%d,%s,%d" % [game, state.active_player, bkey, state.round_number])
		if result.ok and action is RushAction:
			# Counted under SIM_BUILT so the existing summary prints it (2026-10-01).
			_built["Rush"] = _built.get("Rush", 0) + 1
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
	if _ap_trace:
		var think_ms: int = (Time.get_ticks_usec() - think_start_usec) / 1000   # before the diagnostics below
		_tally_idle(state)
		print("SIM_APTURN,%d,%d,%d,%d,%d,%s,%d,%d" % [game, turn, state.active_player, ap_start,
			state.per_player[state.active_player].current_ap, ended_by, think_ms, state.entities().size()])
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
	# ★ 2026-09-28: the SAME MatchSetup the slice uses (faction HQs, starting Builders, round
	# cap), so the board simulated is the board that ships. Both seats play the baseline
	# faction — a mirror is what this harness measures — and the economy is the shipped one.
	Balance.reset()
	# ★ The map's own AP per turn, exactly as the setup screen would start the match — unless a
	# run overrides it. apply_match copies the base economy, so other --econ changes survive.
	if not _ap_override:
		Balance.apply_match(map.default_ap_per_turn)
	var max_rounds: int = _max_rounds_override if _max_rounds_override > 0 \
		else map.default_round_limit
	var state: GameState = MatchSetup.build(map, _factions, starting_player, max_rounds, [0, 1])
	# Fixed per game (never 0, never random) so the AI's research lean varies across a batch
	# the way it does across real matches, and every batch stays reproducible.
	state.match_seed = 1 + variant + 100 * handicap + 1000 * favoured

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
				if not state.grid.is_passable(tile.x, tile.y):   # occupied OR blocked ground (bigger maps)
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
		if not state.grid.is_passable(tile.x, tile.y):   # occupied OR blocked ground (bigger maps)
			continue
		var u := UnitState.new()
		u.entity_id = BONUS_ID_BASE + favoured * 50 + i
		u.owner = favoured
		u.position = tile
		u.type = UnitTypes.TROOPER
		u.current_hp = UnitTypes.TROOPER.hp
		state.grid.place(u.entity_id, tile.x, tile.y)
		state.entities_by_id[u.entity_id] = u
	if _free_lab:
		_place_free_labs(state, hq_of)
	return state


## --plan0/--plan1: if the active seat's researcher is idle, start the next unfinished tech on
## its path for free. A tech the seat cannot take (a faction swap replaces it, or a gate fails)
## is skipped with a SIM_PLAN_SKIP row rather than silently stalling the path.
func _advance_plan(state: GameState) -> void:
	var p: int = state.active_player
	var lab: StructureState = Research.researcher(state, p)
	if lab == null or lab.research_target != null:
		return
	for t: TechDef in _plans[p]:
		if Research.has_tech(state, p, t):
			continue
		if Research.availability(state, p, t) != Action.Reason.OK:
			print("SIM_PLAN_SKIP,%d,%s,%d" % [p, t.display_name, Research.availability(state, p, t)])
			continue
		lab.research_target = t
		lab.research_turns_remaining = Research.effective_research_time(state, t, p)
		return


## --free-lab: a completed Research Lab on the first open tile behind (or beside) each HQ.
func _place_free_labs(state: GameState, hq_of: Array[Vector2i]) -> void:
	for player: int in 2:
		var hq: Vector2i = hq_of[player]
		var back: int = -1 if hq.x < VSMap.WIDTH / 2 else 1
		var candidates: Array[Vector2i] = []
		for r: int in [1, 2, 3]:
			for dy: int in [0, -1, 1, -2, 2, -3, 3]:
				candidates.append(Vector2i(hq.x + back * r, hq.y + dy))
			for dy: int in [-r, r]:
				candidates.append(Vector2i(hq.x, hq.y + dy))
		for tile: Vector2i in candidates:
			if not state.grid.in_bounds(tile.x, tile.y) or not state.grid.is_passable(tile.x, tile.y):
				continue
			var lab := StructureState.new()
			lab.entity_id = BONUS_ID_BASE + 800 + player
			lab.owner = player
			lab.position = tile
			lab.type = StructureTypes.RESEARCH_LAB
			lab.current_hp = StructureTypes.RESEARCH_LAB.hp
			lab.build_status = StructureState.BuildStatus.COMPLETED
			state.grid.place(lab.entity_id, tile.x, tile.y)
			state.entities_by_id[lab.entity_id] = lab
			break


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



## SIM_PUSH,game,turn,player,fighters,largest_group,ready,defenders,avg_hq_dist,in_enemy_half —
## why a push does or does not happen. Groups are counted the way AI._push_ready counts them
## (fighters within mass_radius of a unit, itself included).
func _trace_push(game: int, turn: int, state: GameState) -> void:
	var p: int = state.active_player
	var hq: StructureState = AI._enemy_hq(state, p)
	var own: StructureState = AI._own_hq(state, p)
	if hq == null or own == null:
		return
	var fighters: Array[UnitState] = []
	for e: EntityState in state.entities():
		if e is UnitState and e.owner == p and (e as UnitState).type.attack > 0 and not (e as UnitState).type.can_build:
			fighters.append(e)
	var largest: int = 0
	var ready: int = 0
	var dist_sum: int = 0
	var forward: int = 0
	for u: UnitState in fighters:
		var g: int = 0
		for f: UnitState in fighters:
			if state.grid.manhattan_distance(u.position, f.position) <= AIBalance.ai.mass_radius:
				g += 1
		largest = maxi(largest, g)
		if AI._push_ready(state, u, hq):
			ready += 1
		var d: int = state.grid.manhattan_distance(u.position, hq.position)
		dist_sum += d
		if d < state.grid.manhattan_distance(u.position, own.position):
			forward += 1
	var defenders: int = 0
	for e: EntityState in state.entities():
		if e.owner == p or e.owner < 0 or e == hq:
			continue
		var armed: bool = (e as UnitState).type.attack > 0 if e is UnitState else (e as StructureState).type.attack > 0
		if armed and state.grid.manhattan_distance(e.position, hq.position) <= AIBalance.ai.push_defence_radius:
			defenders += 1
	# Promotion factions: how many units hold a rank, the average, and whether rank support stands.
	var f: FactionDef = state.faction_of(p)
	if f != null and f.promotes:
		var ranked: int = 0
		var rank_sum: int = 0
		for u: UnitState in fighters:
			if u.rank > 0:
				ranked += 1
			rank_sum += u.rank
		print("SIM_RANK,%d,%d,%d,%d,%d,%.2f,%d" % [game, turn, p, fighters.size(), ranked,
			float(rank_sum) / maxf(1.0, float(fighters.size())), 1 if Promotion._supported(state, p) else 0])
	print("SIM_PUSH,%d,%d,%d,%d,%d,%d,%d,%.1f,%d" % [game, turn, p, fighters.size(), largest, ready,
		defenders, float(dist_sum) / maxf(1.0, float(fighters.size())), forward])


## The --ap-trace category an action's AP is booked under. Moves are split by WHO moves, since
## "the army advances slowly" is a question about fighter moves specifically; a fighter's
## move+attack combo commits as a move, so it lands in move_fighter too.
func _ap_category(state: GameState, action: Action) -> String:
	if action is MoveAction:
		var u: EntityState = state.entity_at((action as MoveAction).from)
		if u is UnitState:
			var t: UnitTypeDef = (u as UnitState).type
			if t.can_build:
				return "move_builder"
			if t.attack <= 0:
				return "move_unarmed"
			return "move_fighter"
		return "move_other"
	if action is AttackAction:
		return "attack"
	if action is ProduceAction:
		return "produce"
	if action is BuildAction:
		return "build"
	if action is ResearchAction:
		return "research"
	if action is UseAbilityAction:
		return "ability"
	return "other_" + action.get_class()


## For every fighter of the side whose turn just ended that neither moved nor attacked, the
## first reason (in this order) the AI left it where it was. Uses the AI's own scoring helpers,
## so "why" means what the AI saw, not a re-derivation.
func _tally_idle(state: GameState) -> void:
	var p: int = state.active_player
	var hq: StructureState = AI._enemy_hq(state, p)
	for e: EntityState in state.entities():
		if not (e is UnitState) or e.owner != p:
			continue
		var u: UnitState = e
		if u.type.attack <= 0 or u.type.can_build or u.has_attacked or u.tiles_moved_this_turn > 0:
			continue
		var why: String = ""
		if u.fortify > 0:
			why = "fortified"
		else:
			var best := AI._score_positional_and_retreat_candidates(state, u, AI._Candidate.new())
			if best.action != null:
				why = "move_scored_%s" % ("above_threshold" if best.score > AIBalance.ai.pass_threshold else "below_threshold")
			else:
				var reachable: int = 0
				var closing: int = 0
				var premature: int = 0
				var target_tiles: int = 0
				var before: int = state.grid.manhattan_distance(u.position, hq.position) if hq else 0
				for r: Movement.ReachableTile in Movement.reachable(state, u):
					if not AP.can_afford(state, p, r.min_cost):
						continue
					reachable += 1
					if hq == null or state.grid.manhattan_distance(r.tile, hq.position) >= before:
						continue
					closing += 1
					if not Combat.legal_targets_from(state, u, r.tile).is_empty():
						target_tiles += 1
					elif AI._advance_is_premature(state, u, r.tile):
						premature += 1
				if reachable == 0:
					why = "cannot_move"
				elif closing == 0:
					why = "no_tile_closer_to_hq"
				elif premature == closing:
					why = "massing_rule_blocks_all"
				elif target_tiles + premature == closing:
					why = "only_attack_tiles_left"
				else:
					why = "no_candidate_other"
		var key: String = ("pushing:" if AI._push_ready(state, u, hq) else "") + why
		if _idle_detail:
			key += "|%s|moved=%d|carried=%s" % [u.type.display_name, u.tiles_moved_this_turn,
				str(state.entity_at(u.position) != u)]
			if why.ends_with("cannot_move"):
				var free: int = 0
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: Vector2i = u.position + d
					if state.grid.in_bounds(n.x, n.y) and state.grid.is_passable(n.x, n.y):
						free += 1
				key += "|ap=%s|open_sides=%d" % ["<move_cost" if state.current_ap(p) < u.type.move_cost else "enough", free]
			if why == "move_scored_below_threshold":
				var b := AI._score_positional_and_retreat_candidates(state, u, AI._Candidate.new())
				var mv: MoveAction = b.action
				key += "|score=%.2f|tiles=%d|closer_by=%d" % [b.score, mv.tiles_entered,
					AI._nearest_live_enemy_distance(state, u.position, p) - AI._nearest_live_enemy_distance(state, mv.to, p)]
		_idle[key] = _idle.get(key, 0) + 1
