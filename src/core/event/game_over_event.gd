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
## events.append(evt)
## [/codeblock]
class_name GameOverEvent
extends Event

## The winning player, or [code]-1[/code] if unset (should never be [code]-1[/code]
## on an actually-appended [GameOverEvent] — [method GameState.run_win_check]
## always resolves a concrete winner before appending one).
@export var winner: int = -1
