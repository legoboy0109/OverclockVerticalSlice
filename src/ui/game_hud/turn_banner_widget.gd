## TurnBannerWidget — the turn/round indicator + self-clearing YOUR/ENEMY banner
## (ADR-0016 §8, TR-hud-009). Shares the top-center spine with the AP counter.
##
## Extends [HudReactiveControl] (Story 001): reacts to
## [signal GameState.action_applied] via [method CanvasItem.queue_redraw]
## coalescing, reading [method GameStateReader.active_player]/
## [method GameStateReader.round_number]/[method GameStateReader.match_status]
## verbatim (Pass-Through). Since start-of-turn effects flow through
## [signal GameState.action_applied] (ADR-0004 — no dedicated turn signal), a turn
## transition is detected as an [code]active_player[/code]/[code]round_number[/code]
## change across two consecutive emissions.
##
## [b]Banner[/b]: on a transition, shows a neutral-static "YOUR TURN"/"ENEMY TURN"
## for [member HUDConfig.turn_banner_duration_ms], then self-clears via a
## SceneTree timer. [method banner_hold_ms] reports the configured hold (AC-9a);
## the visible slide-in/hold motion is the advisory Visual/Feel evidence (AC-9b).
##
## [b]Out of scope[/b]: victory/defeat one-frame preemption of the banner is
## Story 006's cross-cutting GAME_OVER concern; here the banner merely stops once
## [method GameStateReader.match_status] is GAME_OVER.
##
## Usage:
## [codeblock]
## var banner := TurnBannerWidget.new()
## banner.bind(reader)                          # HudReactiveControl DI
## banner.configure(HudBalance.hud, local_player)   # after bind: syncs baseline
## hud_layer.add_child(banner)
## [/codeblock]
class_name TurnBannerWidget
extends HudReactiveControl

var _config: HUDConfig = null

## The local player, for the YOUR-vs-ENEMY side of the banner/indicator.
var _local_player: int = 0

## Last-observed active player / round, to detect a transition. [member _synced]
## guards the first observation so a baseline sync never fires a spurious banner.
var _prev_active: int = -1
var _prev_round: int = -1
var _synced: bool = false

var _banner_active: bool = false
var _banner_text: String = ""
var _banner_hold_ms: int = 0


## Injects the config + local player (DI seam). Call after [method bind]: it syncs
## the transition baseline from the reader so the first real transition (not the
## initial observation) is what shows a banner.
func configure(config: HUDConfig, local_player: int) -> void:
	_config = config
	_local_player = local_player
	if _reader != null:
		_prev_active = _reader.active_player()
		_prev_round = _reader.round_number()
		_synced = true


## Overrides [method HudReactiveControl._on_action_applied]: refresh the indicator/
## banner from the new state, then request the coalesced redraw.
func _on_action_applied(_result: ActionResult) -> void:
	_refresh()
	queue_redraw()


func _refresh() -> void:
	if _reader == null:
		return
	if _reader.match_status() == GameState.MatchStatus.GAME_OVER:
		# Victory/defeat preemption is Story 006's concern; just stop the banner.
		_banner_active = false
		return
	var active: int = _reader.active_player()
	var rnd: int = _reader.round_number()
	if not _synced:
		_prev_active = active
		_prev_round = rnd
		_synced = true
		return
	if active != _prev_active or rnd != _prev_round:
		_banner_text = "YOUR TURN" if active == _local_player else "ENEMY TURN"
		_banner_hold_ms = _config.turn_banner_duration_ms if _config != null else 0
		_banner_active = true
		_start_banner_timer()
		_prev_active = active
		_prev_round = rnd


func _start_banner_timer() -> void:
	if not is_inside_tree() or _banner_hold_ms <= 0:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(_banner_hold_ms / 1000.0)
	timer.timeout.connect(_on_banner_timeout)


func _on_banner_timeout() -> void:
	if not is_inside_tree():
		return
	_banner_active = false
	queue_redraw()


# --- Display model (Integration-testable getters) ----------------------------

## The active player the indicator currently reflects (live verbatim read).
func indicator_active_player() -> int:
	return _reader.active_player() if _reader != null else -1

## The round the indicator currently reflects (live verbatim read).
func indicator_round() -> int:
	return _reader.round_number() if _reader != null else -1

## The composed indicator text ("Round N — YOUR/ENEMY TURN").
func indicator_text() -> String:
	if _reader == null:
		return ""
	var side: String = "YOUR TURN" if _reader.active_player() == _local_player else "ENEMY TURN"
	return "Round %d — %s" % [_reader.round_number(), side]

## True while the transition banner is showing (before its hold elapses).
func banner_active() -> bool:
	return _banner_active

## The current banner text ("YOUR TURN"/"ENEMY TURN").
func banner_text() -> String:
	return _banner_text

## The banner's configured hold duration in ms (== HUDConfig.turn_banner_duration_ms
## for the transition that raised it, AC-9a).
func banner_hold_ms() -> int:
	return _banner_hold_ms


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(4, 18), indicator_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if _banner_active:
		draw_string(font, Vector2(4, 42), _banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
