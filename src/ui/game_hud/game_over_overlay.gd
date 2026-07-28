## GameOverOverlay — the victory/defeat presentation (ADR-0016 §8, TR-hud-016).
##
## Reactive [HudReactiveControl] that, on [code]match_status == GameOver[/code],
## shows a victory/defeat screen naming the winner ([method GameStateReader.winner],
## verbatim) WITHIN ONE FRAME of the terminal transition. Because it reacts to the
## same [signal GameState.action_applied] that set the terminal status, and the
## [TurnBannerWidget] self-clears its banner on that same signal, the overlay
## appears while any in-flight/pending turn banner disappears on the same frame —
## the one-frame preemption (AC-17), no cross-widget coordination needed.
##
## The AP-counter tick-snap and the killing commit's hp-pip drain are OTHER
## widgets' concerns on the same transition ([ApCounterWidget] Story 004 snaps to
## the final value; [OnBoardGlyphLayer] Story 005 plays the drain unclipped) —
## this overlay owns only the win/lose presentation, silent (Story 008 owns the
## audio cue).
##
## Usage:
## [codeblock]
## var overlay := GameOverOverlay.new()
## overlay.bind(reader)
## overlay.configure(local_player)   # to pick VICTORY vs DEFEAT
## hud_layer.add_child(overlay)
## [/codeblock]
class_name GameOverOverlay
extends HudReactiveControl

## The local player, to render VICTORY (this seat won) vs DEFEAT.
var _local_player: int = 0


func configure(local_player: int) -> void:
	_local_player = local_player


func _on_action_applied(_result: ActionResult) -> void:
	# match_status/winner are read live in the getters/_draw; just repaint.
	queue_redraw()


# --- Display model (Integration-testable) ------------------------------------

## True iff the match is over (the overlay is visible).
func is_showing() -> bool:
	return _reader != null and _reader.match_status() == GameState.MatchStatus.GAME_OVER

## The winning player's index (verbatim read), or -1 if not over.
func winning_player() -> int:
	return _reader.winner() if _reader != null else -1

## True iff the local player won (VICTORY) — false during DEFEAT or an ongoing match.
func is_local_victory() -> bool:
	return is_showing() and _reader.winner() == _local_player

## The result text ("VICTORY"/"DEFEAT"), or "" while the match is ongoing.
func result_text() -> String:
	if not is_showing():
		return ""
	return "VICTORY" if _reader.winner() == _local_player else "DEFEAT"


func _draw() -> void:
	if not is_showing():
		return
	# Dim the board, then name the result + winner.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6))
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(8, 40), "%s — winner: P%d" % [result_text(), _reader.winner()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
