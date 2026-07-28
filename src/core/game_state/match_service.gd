## MatchService — thin, logic-free lookup pointer for the current match's GameState.
##
## Foundation-layer script per ADR-0001. This is NOT the authoritative owner of
## [GameState] — the authoritative instance is created by a match-bootstrap
## script and passed by reference (DI) to whoever needs it. This class exists
## purely as a lookup convenience so Presentation nodes can fetch the current
## live match's state once at [code]_ready()[/code] without threading it
## through every scene-tree branch.
##
## [b]No other methods. No validation, no mutation, no signals of its own.[/b]
## Unit tests and the AI must never touch this class — they construct or
## receive a [GameState] directly, which is what makes them independent of
## any global (ADR-0001).
##
## This script is intentionally NOT registered as a project.godot Autoload by
## this story — no scene or bootstrap script consumes it yet (Presentation
## layer isn't in this sprint). Autoload registration is a later story's job
## once something actually needs to look it up.
extends Node

## The current live match's [GameState], or [code]null[/code] if no match is
## active. Set exclusively via [method set_current].
var current: GameState = null


## Returns [member current]. Pure lookup, no side effects.
func get_current() -> GameState:
	return current


## Sets [member current] to [param state]. The sole mutator on this class.
func set_current(state: GameState) -> void:
	current = state
