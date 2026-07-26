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
## state.per_player[0].has_economy_tech = true
## [/codeblock]
class_name GameStateFactory
extends RefCounted


## Builds a bare [PlayerState] with the given starting AP and Economy-Tech flag.
## All other fields keep their class defaults (faction null, other tech flags
## false, not AI-controlled).
static func make_player(current_ap: int = 0, has_economy_tech: bool = false) -> PlayerState:
	var player := PlayerState.new()
	player.current_ap = current_ap
	player.has_economy_tech = has_economy_tech
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
