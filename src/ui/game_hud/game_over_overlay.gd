## GameOverOverlay — the victory/defeat presentation (ADR-0016 §8, TR-hud-016;
## `game-hud.md` CR-9 / AC-17 / AC-22).
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
## [b]★ Both CR-9 clauses, 2026-08-24 (S6-08).[/b] CR-9 always had two: an
## HQ-destruction victory (AC-17) and a [code]MAX_ROUNDS[/code] tiebreak (AC-22).
## AC-22 was deferred as untestable because the round cap was off in the vertical
## slice — [b]it was armed at 30 in S6-03[/b], and the S6-06 batch ends roughly 1
## game in 7 that way, so the deferral is spent and both clauses are live here.
## They need genuinely different presentation, which is why this is not one code
## path with a swapped noun:
##
## [br]• An [b]HQ kill[/b] explains itself. Something visibly died; the player saw
## it. The screen only has to name the outcome.
## [br]• A [b]round-limit[/b] finish explains nothing. Nothing died, the clock
## simply ran out, and the player is told they lost a game that looked ongoing.
## So that path additionally shows the metric and both scores — the numbers the
## match was actually decided on. A capped defeat with no figures is the most
## opaque way this game can end.
##
## [b]Testable model[/b]: [method is_showing] / [method winning_player] /
## [method is_local_victory] / [method result_text] / [method reason_text] /
## [method detail_text]; [method _draw] renders them (advisory).
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

## Board dim behind the result. Heavy enough to pull focus off the board, light
## enough that the final position stays readable underneath — players want to see
## what the board looked like when it ended.
const SCRIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)


## The local player, to render VICTORY (this seat won) vs DEFEAT.
var _local_player: int = 0


func configure(local_player: int) -> void:
	_local_player = local_player


# ★ 2026-10-01 (holo glass): a centred glass plate carries the result. The text is drawn on a
# child laid over the plate (a GlassBackdrop paints over its parent's own _draw), so the order
# is: scrim (this node) -> plate -> text.
const PLATE_SIZE: Vector2 = Vector2(560, 186)
var _plate: Control = null
var _text_layer: Control = null


func _ready() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.size = PLATE_SIZE
	add_child(_plate)
	_text_layer = Control.new()
	_text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_layer.size = PLATE_SIZE
	_text_layer.draw.connect(_draw_text)
	_plate.add_child(_text_layer)
	resized.connect(_sync_plate)
	_sync_plate()


func _sync_plate() -> void:
	if _plate == null:
		return
	_plate.position = ((size - PLATE_SIZE) * 0.5).floor()
	_plate.visible = is_showing()
	if _plate.visible and _plate.get_child_count() == 1:
		# Built lazily so the plate edge can take the WINNER's hue.
		var hue: Color = UiTheme.player_hue(winning_player())
		var b := GlassBackdrop.attach(_plate, Color(hue, 0.75), 18.0)
		b.cut_px = 18.0
	_text_layer.queue_redraw()


func _on_action_applied(_result: ActionResult) -> void:
	# match_status/winner/win_reason are read live in the getters/_draw; just repaint.
	_sync_plate()
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

## True iff this match ended on the round cap rather than an HQ destruction.
func is_round_limit_result() -> bool:
	return is_showing() and _reader.win_reason() == GameState.WinReason.ROUND_LIMIT

## One line naming HOW the match ended, phrased from the local player's side.
## [code]""[/code] while the match is ongoing.
func reason_text() -> String:
	if not is_showing():
		return ""
	if is_round_limit_result():
		return "Round limit reached — decided on %s" % _metric_name()
	return "Enemy HQ destroyed" if is_local_victory() else "Your HQ was destroyed"

## The supporting figures for a round-limit result — the metric scores that decided
## it, local player first so "you / them" reads in the order the player thinks in.
## [code]""[/code] for an HQ-destruction win, which needs no figures.
func detail_text() -> String:
	if not is_round_limit_result():
		return ""
	var scores: Array[int] = _reader.tiebreak_scores()
	if scores.size() < 2:
		return ""
	var mine: int = scores[_local_player]
	var theirs: int = scores[1 - _local_player]
	return "%s — you %d, opponent %d" % [_metric_name(), mine, theirs]


## Human-readable name of the deciding metric.
func _metric_name() -> String:
	match _reader.tiebreak_metric():
		GameState.TiebreakMetric.TOTAL_HQ_HP:
			return "total HQ health"
		GameState.TiebreakMetric.UNIT_COUNT:
			return "surviving units"
		_:
			# An unmapped metric is a code change that forgot this switch. Say so
			# plainly rather than rendering a bare integer at the player.
			return "an unnamed tiebreak metric"


func _draw() -> void:
	if not is_showing():
		return
	draw_rect(Rect2(Vector2.ZERO, size), SCRIM_COLOR)


## The plate's text: the result glowing in the WINNER's hue (yours on a victory, theirs on a
## defeat — the art bible allows no "success green / failure red"), the reason, then the
## tiebreak figures for a round-limit result.
func _draw_text() -> void:
	if not is_showing():
		return
	var t: Control = _text_layer
	var w: float = PLATE_SIZE.x
	var result: String = result_text()
	var hue: Color = UiTheme.player_hue(winning_player())
	var big: Font = UiTheme.font(800)
	var rw: float = big.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	UiTheme.draw_glow_text(t, big, Vector2((w - rw) * 0.5, 92), result, 60, hue)
	var reason: String = reason_text().to_upper()
	var lf: Font = UiTheme.label_font()
	var rsw: float = lf.get_string_size(reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	t.draw_string(lf, Vector2((w - rsw) * 0.5, 134), reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT)
	var detail: String = detail_text()
	if detail != "":
		var dw: float = UiTheme.font(500).get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		t.draw_string(UiTheme.font(500), Vector2((w - dw) * 0.5, 166), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			UiTheme.TEXT_MUTED)
