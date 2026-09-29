## MatchSettings — what the player chose on the skirmish setup screen, remembered between runs
## (user://match.cfg, separate from control preferences in settings.cfg).
##
## The player-facing settings are exactly the ones the user chose to expose (2026-09-28): AP per
## turn, round limit, who moves first — plus each seat's faction. Everything else stays
## designer-owned balance (post-gate backlog: "a setup screen that exposes every tuning constant
## is a debug menu, not a game").
class_name MatchSettings
extends RefCounted

const PATH: String = "user://match.cfg"

enum FirstMover { PLAYER, AI, RANDOM }

const AP_MIN: int = 10
const AP_MAX: int = 40
const ROUNDS_MIN: int = 20
const ROUNDS_MAX: int = 200

## The settings the next match starts with. The setup screen writes it; the slice reads it.
static var current: MatchSettings = null

## Faction per seat: [0] is the player, [1] the AI.
var factions: Array[FactionDef] = []
var ap_per_turn: int = 20
var round_limit: int = 80
var first_mover: int = FirstMover.PLAYER
## The board (2026-09-28: bigger maps). Null = the default vertical-slice map.
var map: MapDefinition = null


## Settings with nothing chosen: the first playable faction for both seats and the game's own
## defaults (the economy config's AP budget, the slice's round cap).
static func defaults() -> MatchSettings:
	var m := MatchSettings.new()
	var first: FactionDef = Factions.playable()[0] if not Factions.playable().is_empty() else Factions.NEUTRAL
	m.factions = [first, first]
	m.ap_per_turn = Balance.base_economy.flat_ap_per_turn
	m.map = Maps.all()[0]
	m.round_limit = m.map.default_round_limit
	m.ap_per_turn = m.map.default_ap_per_turn
	return m


## Switches to [param new_map] and to its own default round limit and AP per turn — a long board
## needs a longer game and more AP to cross it, so values chosen for the previous map would be the
## wrong starting point.
func choose_map(new_map: MapDefinition) -> void:
	map = new_map
	round_limit = clampi(new_map.default_round_limit, ROUNDS_MIN, ROUNDS_MAX)
	ap_per_turn = clampi(new_map.default_ap_per_turn, AP_MIN, AP_MAX)


## The settings a loaded save was played with, so "Restart Skirmish" after loading restarts THAT
## matchup rather than whatever the setup screen last held. Not written to disk: the setup
## screen's remembered choice is the player's, not the save's.
static func from_loaded(loaded: SaveGame.Loaded) -> MatchSettings:
	var m := defaults()
	m.factions = [] as Array[FactionDef]
	for p: PlayerState in loaded.state.per_player:
		m.factions.append(p.faction)
	m.map = loaded.map
	m.ap_per_turn = loaded.ap_per_turn
	m.round_limit = loaded.state.max_rounds
	m.first_mover = FirstMover.PLAYER if loaded.state.starting_player == 0 else FirstMover.AI
	return m


## The settings to use now: whatever was chosen this run, else what was saved, else defaults.
static func active() -> MatchSettings:
	if current == null:
		current = load_saved()
	return current


## Who moves first, resolved — RANDOM is decided here, at setup, never inside the rules
## (determinism, Pillar 2, applies to play, not to the coin toss before it).
func starting_player() -> int:
	match first_mover:
		FirstMover.AI:
			return 1
		FirstMover.RANDOM:
			return randi() % 2
	return 0


func save() -> Error:
	var cfg := ConfigFile.new()
	for i: int in factions.size():
		cfg.set_value("match", "faction_%d" % i, factions[i].resource_path if factions[i] != null else "")
	cfg.set_value("match", "ap_per_turn", ap_per_turn)
	cfg.set_value("match", "round_limit", round_limit)
	cfg.set_value("match", "first_mover", first_mover)
	cfg.set_value("match", "map", map.resource_path if map != null else "")
	return cfg.save(PATH)


## Loads the saved choice; anything missing, out of range or no longer existing (a faction
## removed from the vault) falls back to the default rather than failing.
static func load_saved() -> MatchSettings:
	var m := defaults()
	# The test runner sets this so no test depends on the machine's last skirmish.
	if OS.get_environment("OVERCLOCK_TESTS") == "1":
		return m
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return m
	for i: int in 2:
		var path: String = str(cfg.get_value("match", "faction_%d" % i, ""))
		for f: FactionDef in Factions.playable():
			if f.resource_path == path:
				m.factions[i] = f
	m.ap_per_turn = clampi(int(cfg.get_value("match", "ap_per_turn", m.ap_per_turn)), AP_MIN, AP_MAX)
	m.round_limit = clampi(int(cfg.get_value("match", "round_limit", m.round_limit)), ROUNDS_MIN, ROUNDS_MAX)
	m.first_mover = clampi(int(cfg.get_value("match", "first_mover", m.first_mover)), 0, 2)
	var map_path: String = str(cfg.get_value("match", "map", ""))
	for mp: MapDefinition in Maps.all():
		if mp.resource_path == map_path:
			m.map = mp
	return m
