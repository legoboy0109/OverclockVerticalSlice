## ApCounterWidget — the reactive Control that renders the AP counter, wrapping
## the pure [ApCounterFsm] (Story 003) per ADR-0016 §2/§8 (TR-hud-005/006/007).
##
## Extends [HudReactiveControl] (Story 001), so it reacts to
## [signal GameState.action_applied] via native [method CanvasItem.queue_redraw]
## coalescing. Every displayed number is a live verbatim read through the
## injected [GameStateReader] (committed AP) or is handed in from CAI (the
## previewed projection) — this widget NEVER computes or infers an AP value
## locally (Pass-Through Invariant, ADR-0016 §8).
##
## [b]Display model[/b] (the Integration-testable surface): the getters
## [method committed_value]/[method showing_echo]/[method projected_value]/
## [method insufficient_ap]/[method opponent_label_shown]/[method is_muted]/
## [method fsm_state] report exactly what the widget would render, so the
## blocking ACs (AC-6/7/19/28) assert values headlessly; [method _draw] is a thin
## rendering of that model (its motion quality — glow-fill, chunky tick — is the
## advisory Visual/Feel evidence, AC-3b/5b).
##
## [b]FSM wiring[/b]: committed AP is refreshed on every [signal GameState.action_applied]
## — a decrease is a spend ([constant ApCounterFsm.Trigger.COMMIT_SPEND] →
## [constant ApCounterFsm.State.TICK_DOWN]), an increase is the start-of-turn fill
## ([constant ApCounterFsm.Trigger.TURN_START_FILL] → [constant ApCounterFsm.State.FILL_FLOURISH]),
## GAME_OVER settles to rest. The preview echo is driven by the explicit
## [method open_preview]/[method close_preview] entry points the scene glue calls
## when CAI opens/closes a preview (mirroring [method CommandInterface.route_click]/
## [method CommandInterface.inspect] — CAI exposes no preview signal). The echo
## SNAPS (no tween) and the committed value moves only on a real commit.
##
## [b]Opponent muting[/b] (CR-3b): an [code]is_opponent[/code] instance renders a
## persistent [code]OPPONENT[/code] label + muted treatment and can never reach
## [constant ApCounterFsm.State.PREVIEW_ECHO] (previews are local-only) —
## [method open_preview] is a no-op on it.
##
## Usage:
## [codeblock]
## var counter := ApCounterWidget.new()
## counter.bind(reader)                       # HudReactiveControl DI
## counter.configure(HudBalance.hud, local_player)
## hud_layer.add_child(counter)
## # when CAI opens an affordable move preview costing C:
## counter.open_preview(CommandFSM.projected_remaining_ap(state, local_player, C), true)
## [/codeblock]
class_name ApCounterWidget
extends HudReactiveControl

## Sentinel "no projection" value for [member _projected_ap] — distinct from any
## real AP (AP is non-negative when affordable; an unaffordable projection is
## never displayed, so a real value is never negative here).
const _NO_PROJECTION: int = -1

## The loaded [HUDConfig] (durations). Injected via [method configure].
var _config: HUDConfig = null

## Which player's AP this counter shows.
var _player: int = 0

## Opponent-context mode: persistent OPPONENT label + muted + no echo (CR-3b).
var _is_opponent: bool = false

## The current animation state (pure [ApCounterFsm] decides transitions).
var _fsm_state: ApCounterFsm.State = ApCounterFsm.State.COMMITTED

## Last-read committed AP — the "trust" value shown at rest. A live verbatim
## read of [method GameStateReader.current_ap], never locally derived.
var _committed_ap: int = 0

## Whether a preview echo is currently open.
var _echo_active: bool = false

## The previewed projection ([method CommandFSM.projected_remaining_ap], verbatim)
## when the echo is open and affordable; [constant _NO_PROJECTION] otherwise.
var _projected_ap: int = _NO_PROJECTION

## Whether the open preview is affordable — an unaffordable preview shows
## "insufficient AP", never a negative or `→ negative` (AC-7).
var _preview_affordable: bool = true

## Last-observed active player / round — to distinguish a genuine turn boundary
## (route through [constant ApCounterFsm.Trigger.TURN_TRANSITION] then a gated
## start-of-turn fill) from a mid-turn AP change (a spend → tick, or a
## Cancel-Build refund credit → NO flourish). [member _synced] guards the
## baseline so the first observation is never mistaken for a transition.
var _prev_active: int = -1
var _prev_round: int = -1
var _synced: bool = false


## Injects the config + which player this counter tracks (DI seam, mirrors
## [CommandInterface]'s setter convention). Call after [method bind]; initializes
## the committed value from the reader so it reads correctly before the first
## [signal GameState.action_applied]. [param is_opponent] enables the muted,
## echo-forbidden opponent-AP mode.
func configure(config: HUDConfig, player: int, is_opponent: bool = false) -> void:
	_config = config
	_player = player
	_is_opponent = is_opponent
	if _reader != null:
		_committed_ap = _reader.current_ap(_player)
		_prev_active = _reader.active_player()
		_prev_round = _reader.round_number()
		_synced = true


## Overrides [method HudReactiveControl._on_action_applied]: refresh the committed
## value + FSM from the new state, then request the coalesced redraw.
func _on_action_applied(_result: ActionResult) -> void:
	_refresh_committed()
	queue_redraw()


## Reads the current committed AP and drives the FSM: a decrease is a spend
## (tick-down), an increase is the start-of-turn fill, GAME_OVER settles to rest.
## Any board change clears a stale preview echo (the committed value has moved).
func _refresh_committed() -> void:
	if _reader == null:
		return
	if _reader.match_status() == GameState.MatchStatus.GAME_OVER:
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.GAME_OVER, _is_opponent)
		_committed_ap = _reader.current_ap(_player)
		_clear_echo()
		return
	var new_ap: int = _reader.current_ap(_player)
	var active: int = _reader.active_player()
	var rnd: int = _reader.round_number()
	var is_transition: bool = _synced and (active != _prev_active or rnd != _prev_round)

	if is_transition:
		# TR-hud-006: force-clear any open echo FIRST, as its own synchronous step
		# (TURN_TRANSITION → COMMITTED from any state) — the FSM state never routes
		# straight to a fill ...
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.TURN_TRANSITION, _is_opponent)
		_clear_echo()
		# ... THEN evaluate the incoming start-of-turn fill, only on a real income
		# rise and only when a fill is allowed for this counter (opponent-gated).
		if new_ap > _committed_ap and _fill_allowed():
			_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.TURN_START_FILL, _is_opponent)
			_start_settle(_config.ap_fill_flourish_ms if _config != null else 0)
	elif new_ap < _committed_ap:
		# Mid-turn spend → discrete tick-down (an opponent's own commits included).
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.COMMIT_SPEND, _is_opponent)
		_start_settle(_config.ap_tick_duration_ms if _config != null else 0)
		_clear_echo()
	else:
		# Mid-turn non-decrease (e.g. a Cancel-Build refund credit): the committed
		# value may rise, but this is NOT a start-of-turn fill — no flourish. Any
		# board change still clears a stale echo.
		_clear_echo()

	_committed_ap = new_ap
	_prev_active = active
	_prev_round = rnd
	_synced = true


## Whether a start-of-turn fill flourish may play: always for the local player,
## and for the opponent only iff [member HUDConfig.show_opponent_fill_flourish]
## (ADR-0016 §2 — opponent AP reaches [constant ApCounterFsm.State.FILL_FLOURISH]
## "iff SHOW_OPPONENT_FILL_FLOURISH"). Opponent [constant ApCounterFsm.State.TICK_DOWN]
## (their own commits) is unaffected and always plays.
func _fill_allowed() -> bool:
	if not _is_opponent:
		return true
	return _config != null and _config.show_opponent_fill_flourish


## Opens a preview echo (scene glue calls this when CAI opens a preview).
## [param projected_ap] is CAI's [method CommandFSM.projected_remaining_ap] result
## (verbatim — this widget never computes it); [param affordable] is CAI's
## affordability read. On an opponent counter [constant ApCounterFsm.Trigger.PREVIEW_OPEN]
## is refused (echo unreachable), so this is a no-op. An unaffordable preview
## stores no projection and renders "insufficient AP" (never a negative).
func open_preview(projected_ap: int, affordable: bool) -> void:
	var next: ApCounterFsm.State = ApCounterFsm.next_state(
		_fsm_state, ApCounterFsm.Trigger.PREVIEW_OPEN, _is_opponent)
	if next != ApCounterFsm.State.PREVIEW_ECHO:
		return # opponent context: PREVIEW_ECHO unreachable — no echo.
	_fsm_state = next
	_echo_active = true
	_preview_affordable = affordable
	_projected_ap = projected_ap if affordable else _NO_PROJECTION
	queue_redraw()


## Closes the preview echo (cancel/commit) — reverts to the plain committed value
## with no leftover projection (AC-25). No state mutation ever happens here.
func close_preview() -> void:
	_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.PREVIEW_CLOSE, _is_opponent)
	_clear_echo()
	queue_redraw()


func _clear_echo() -> void:
	_echo_active = false
	_projected_ap = _NO_PROJECTION
	_preview_affordable = true


## Starts a settle timer that returns a fill/tick animation to
## [constant ApCounterFsm.State.COMMITTED] after [param duration_ms] (the widget's
## own render-completion concern — the pure FSM has no "animation done" trigger).
## Advisory motion; a no-op outside the tree or with a non-positive duration.
func _start_settle(duration_ms: int) -> void:
	if not is_inside_tree() or duration_ms <= 0:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(duration_ms / 1000.0)
	timer.timeout.connect(_on_settle)


func _on_settle() -> void:
	if not is_inside_tree():
		return
	if _fsm_state == ApCounterFsm.State.FILL_FLOURISH or _fsm_state == ApCounterFsm.State.TICK_DOWN:
		_fsm_state = ApCounterFsm.State.COMMITTED
		queue_redraw()


# --- Display model (Integration-testable getters) ----------------------------

## The committed AP shown at rest (live verbatim read).
func committed_value() -> int:
	return _committed_ap

## True iff an affordable preview echo is open (renders `committed → projected`).
func showing_echo() -> bool:
	return _echo_active and _preview_affordable

## The projected AP shown beside the arrow (only meaningful when
## [method showing_echo]); [constant _NO_PROJECTION] otherwise — never a negative.
func projected_value() -> int:
	return _projected_ap

## True iff an unaffordable preview is open — renders "insufficient AP" (AC-7).
func insufficient_ap() -> bool:
	return _echo_active and not _preview_affordable

## True iff this is the opponent-AP counter (persistent OPPONENT label).
func opponent_label_shown() -> bool:
	return _is_opponent

## True iff this counter uses the muted treatment (opponent AP, CR-3b).
func is_muted() -> bool:
	return _is_opponent

## The current [enum ApCounterFsm.State].
func fsm_state() -> ApCounterFsm.State:
	return _fsm_state


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return # headless / no font — the display model is still valid; skip pixels.
	var font_size: int = 16
	var col: Color = Color(0.55, 0.55, 0.6) if _is_opponent else Color(0.2, 1.0, 0.9)
	var text: String = "OPPONENT  %d" % _committed_ap if _is_opponent else "%d" % _committed_ap
	if showing_echo():
		text += "  → %d" % _projected_ap
	elif insufficient_ap():
		text += "  (insufficient AP)"
	draw_string(font, Vector2(4, font_size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
