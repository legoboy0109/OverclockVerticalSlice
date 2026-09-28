## GameStateFactory — shared builders for GameState/PlayerState in unit tests.
##
## Reduces the per-file [code]_make_*[/code] boilerplate as more Foundation
## systems get tested (AP Economy, Turn FSM, Win-Check). Builds plain typed
## [Resource] instances via [code].new()[/code] — no scene tree, no grid unless
## the caller adds one (AP income/spend never touch the grid; tests that need
## occupancy build and assign a [GridState] themselves).
##
## Existing suites (e.g. game_state_core_test.gd) keep their own local helpers;
## this is for new tests, not a refactor of passing ones.
##
## Usage:
## [codeblock]
## var state := GameStateFactory.make_state(2, 0)      # 2 players, player 0 active
## state.per_player[0].current_ap = 10
## state.per_player[0].economy_tier = 2
## [/codeblock]
class_name GameStateFactory
extends RefCounted


## Builds a bare [PlayerState] with the given starting AP and Economy-Tech flag.
## All other fields keep their class defaults (faction null, other tech flags
## false, not AI-controlled).
static func make_player(current_ap: int = 0, economy_tier: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.current_ap = current_ap
	player.economy_tier = economy_tier
	return player


## Builds a minimal gridless [GameState] with [param player_count] default
## players and [param active_player] set. Round 1, IN_PROGRESS, no grid, no
## entities — enough for AP income/spend tests. Tests needing a board or
## entities assign [code]state.grid[/code] / populate
## [code]state.entities_by_id[/code] themselves.
static func make_state(player_count: int = 2, active_player: int = 0) -> GameState:
	var state := GameState.new()
	for _i: int in player_count:
		state.per_player.append(make_player())
	state.active_player = active_player
	state.round_number = 1
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	return state


## Builds a throwaway [TechDef] carrying only the given effect magnitudes — for tests
## that need to prove a stat fold reads the TECH'S value rather than a hardcoded +1
## (e.g. grant +5 attack and assert +5, which a hardcoded +1 would fail). Not in
## [code]Techs.ALL[/code], so it never affects tree gating.
static func make_tech(attack_bonus: int = 0, defense_bonus: int = 0) -> TechDef:
	var tech := TechDef.new()
	tech.display_name = "Test Tech"
	tech.research_cost = 0
	tech.research_time = 1
	tech.attack_bonus = attack_bonus
	tech.defense_bonus = defense_bonus
	return tech


## Marks [param tech] completed for [param player] directly, bypassing research —
## the test equivalent of the tech having finished on an earlier turn.
static func grant_tech(state: GameState, player: int, tech: TechDef) -> void:
	state.per_player[player].completed_techs.append(tech)
