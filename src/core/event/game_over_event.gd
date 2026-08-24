## GameOverEvent — fired the instant [method GameState.run_win_check] sets
## [constant GameState.MatchStatus.GAME_OVER].
##
## Foundation-layer event type per ADR-0002/ADR-0004 ("no silent state
## transitions" — control-manifest forbidden pattern). Appended by [method
## GameState.run_win_check] to the same [code]events[/code] array the
## triggering verb's [code]apply()[/code] already populated, so the terminal
## transition is observable through the existing [signal
## GameState.action_applied] signal like every other [Event] — no new signal
## or polling path.
##
## Usage:
## [codeblock]
## # inside GameState.run_win_check, once a winner is decided:
## var evt := GameOverEvent.new()
## evt.winner = winner
## evt.reason = GameState.WinReason.HQ_DESTROYED
## events.append(evt)
## [/codeblock]
class_name GameOverEvent
extends Event

## The winning player, or [code]-1[/code] if unset (should never be [code]-1[/code]
## on an actually-appended [GameOverEvent] — [method GameState.run_win_check]
## always resolves a concrete winner before appending one).
@export var winner: int = -1


## Why the match ended (see [enum GameState.WinReason]) — [constant
## GameState.WinReason.HQ_DESTROYED] or [constant GameState.WinReason.ROUND_LIMIT].
##
## ★ Added 2026-08-24 (S6-08) so the victory presentation can say [i]how[/i] the
## game was won, not just who won it (`game-hud.md` CR-9/AC-22). It must be carried
## on the event rather than derived by a listener: the HQ that decided the match is
## already erased from [member GameState.entities_by_id] by the time anyone reads
## the terminal state, so the cause is unrecoverable after the fact.
@export var reason: int = GameState.WinReason.NONE

## The [enum GameState.TiebreakMetric] that decided a [constant
## GameState.WinReason.ROUND_LIMIT] result. Meaningless (and left at its default)
## for an HQ-destruction win.
@export var metric: int = GameState.TiebreakMetric.TOTAL_HQ_HP

## Each player's tiebreak-metric score at the moment the round cap fired, indexed by
## player. Empty for an HQ-destruction win.
##
## Carried so the presentation can show the player [i]the numbers they lost on[/i]
## rather than only the verdict — a capped game that ends "DEFEAT" with no figures
## is the single most opaque way for this match to finish, because nothing visibly
## died to cause it.
@export var metric_by_player: Array[int] = []
