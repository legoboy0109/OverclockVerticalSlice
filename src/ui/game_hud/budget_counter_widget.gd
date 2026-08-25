## BudgetCounterWidget — the resource-agnostic reactive base for the Game HUD's
## two first-class budget counters: the [ApCounterWidget] (tactical AP) and the
## [CreditsCounterWidget] (banked Credits). ADR-0016 §2/§8, CR-3/CR-3d,
## TR-hud-005/006/007.
##
## The 2026-08-05 economy pivot made the HUD show [b]two[/b] co-equal budget
## counters that, per CR-3d, "mirror the AP counter's animation states." Because
## every counter reads its committed value [b]verbatim[/b] through the injected
## [GameStateReader] and NEVER computes or infers it (Pass-Through Invariant,
## ADR-0016 §8), the accumulate-vs-reset difference between the two budgets lives
## entirely in the [i]engine[/i] ([method Credits.add_income] banks onto the pile
## while [method AP.reset_turn] overwrites) — the widget only ever observes
## "committed value rose at turn start -> fill flourish" either way. So the FSM
## wiring, preview echo, settle timing, and opponent muting are genuinely
## identical for both budgets and live here once; the two subclasses differ only
## in [b]which resource they read[/b] ([method _read_committed_value]) and [b]how
## they render[/b] ([method _budget_color]/[method _committed_text]/
## [method _insufficient_noun]).
##
## Extends [HudReactiveControl] (Story 001), so it reacts to
## [signal GameState.action_applied] via native [method CanvasItem.queue_redraw]
## coalescing. Every displayed number is a live verbatim read through the reader
## or is handed in from CAI (the previewed projection) — this widget NEVER
## computes a budget value locally.
##
## [b]Display model[/b] (the Integration-testable surface): the getters
## [method committed_value]/[method showing_echo]/[method projected_value]/
## [method insufficient_budget]/[method opponent_label_shown]/[method is_muted]/
## [method fsm_state] report exactly what the widget would render, so the blocking
## ACs assert values headlessly; [method _draw] is a thin rendering of that model.
##
## [b]FSM wiring[/b]: the committed value is refreshed on every
## [signal GameState.action_applied] — a decrease is a spend
## ([constant ApCounterFsm.Trigger.COMMIT_SPEND] -> [constant ApCounterFsm.State.TICK_DOWN]),
## an increase at a turn boundary is the start-of-turn fill/income
## ([constant ApCounterFsm.Trigger.TURN_START_FILL] -> [constant ApCounterFsm.State.FILL_FLOURISH]),
## a mid-turn increase (a Cancel-Build refund credit) does NOT flourish, and
## GAME_OVER settles to rest. The [ApCounterFsm] is a pure, resource-agnostic
## state machine (despite its name), reused verbatim for both budgets.
##
## [b]Opponent muting[/b] (CR-3b): an [code]is_opponent[/code] instance renders a
## persistent [code]OPPONENT[/code] label + muted treatment and can never reach
## [constant ApCounterFsm.State.PREVIEW_ECHO] (previews are local-only) —
## [method open_preview] is a no-op on it.
##
## Not instantiated directly — always through [ApCounterWidget] or
## [CreditsCounterWidget].
class_name BudgetCounterWidget
extends HudReactiveControl

## Sentinel "no projection" value for [member _projected] — distinct from any
## real budget value (a budget is non-negative when affordable; an unaffordable
## projection is never displayed, so a real value is never negative here).
const _NO_PROJECTION: int = -1

## The loaded [HUDConfig] (durations). Injected via [method configure].
var _config: HUDConfig = null

## Which player's budget this counter shows.
var _player: int = 0

## Opponent-context mode: persistent OPPONENT label + muted + no echo (CR-3b).
var _is_opponent: bool = false

## The current animation state (pure [ApCounterFsm] decides transitions).
var _fsm_state: ApCounterFsm.State = ApCounterFsm.State.COMMITTED

## Last-read committed budget — the "trust" value shown at rest. A live verbatim
## read via [method _read_committed_value], never locally derived.
var _committed: int = 0

## Whether a preview echo is currently open.
var _echo_active: bool = false

## The previewed projection (handed in by CAI, verbatim) when the echo is open and
## affordable; [constant _NO_PROJECTION] otherwise.
var _projected: int = _NO_PROJECTION

## Whether the open preview is affordable — an unaffordable preview shows
## "insufficient", never a negative or `-> negative`.
var _preview_affordable: bool = true

## Last-observed active player / round — to distinguish a genuine turn boundary
## (route through [constant ApCounterFsm.Trigger.TURN_TRANSITION] then a gated
## start-of-turn fill) from a mid-turn change (a spend -> tick, or a Cancel-Build
## refund credit -> NO flourish). [member _synced] guards the baseline so the
## first observation is never mistaken for a transition.
var _prev_active: int = -1
var _prev_round: int = -1
var _synced: bool = false


## Injects the config + which player this counter tracks (DI seam, mirrors
## [CommandInterface]'s setter convention). Call after [method bind]; initializes
## the committed value from the reader so it reads correctly before the first
## [signal GameState.action_applied]. [param is_opponent] enables the muted,
## echo-forbidden opponent mode.
func configure(config: HUDConfig, player: int, is_opponent: bool = false) -> void:
	_config = config
	_player = player
	_is_opponent = is_opponent
	if _reader != null:
		_committed = _read_committed_value()
		_prev_active = _reader.active_player()
		_prev_round = _reader.round_number()
		_synced = true


## Overrides [method HudReactiveControl._on_action_applied]: refresh the committed
## value + FSM from the new state, then request the coalesced redraw.
func _on_action_applied(_result: ActionResult) -> void:
	_refresh_committed()
	queue_redraw()


## Reads the current committed budget and drives the FSM: a decrease is a spend
## (tick-down), an increase at a turn boundary is the start-of-turn fill/income,
## GAME_OVER settles to rest. Any board change clears a stale preview echo (the
## committed value has moved).
func _refresh_committed() -> void:
	if _reader == null:
		return
	if _reader.match_status() == GameState.MatchStatus.GAME_OVER:
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.GAME_OVER, _is_opponent)
		_committed = _read_committed_value()
		_clear_echo()
		return
	var new_value: int = _read_committed_value()
	var active: int = _reader.active_player()
	var rnd: int = _reader.round_number()
	var is_transition: bool = _synced and (active != _prev_active or rnd != _prev_round)

	if is_transition:
		# TR-hud-006: force-clear any open echo FIRST, as its own synchronous step
		# (TURN_TRANSITION -> COMMITTED from any state) — the FSM state never routes
		# straight to a fill ...
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.TURN_TRANSITION, _is_opponent)
		_clear_echo()
		# ... THEN evaluate the incoming start-of-turn fill/income, only on a real
		# rise and only when a fill is allowed for this counter (opponent-gated).
		if new_value > _committed and _fill_allowed():
			_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.TURN_START_FILL, _is_opponent)
			_start_settle(_config.ap_fill_flourish_ms if _config != null else 0)
	elif new_value < _committed:
		# Mid-turn spend -> discrete tick-down (an opponent's own commits included).
		_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.COMMIT_SPEND, _is_opponent)
		_start_settle(_config.ap_tick_duration_ms if _config != null else 0)
		_clear_echo()
	else:
		# Mid-turn non-decrease (e.g. a Cancel-Build refund credit): the committed
		# value may rise, but this is NOT a start-of-turn fill — no flourish. Any
		# board change still clears a stale echo.
		_clear_echo()

	_committed = new_value
	_prev_active = active
	_prev_round = rnd
	_synced = true


## Whether a start-of-turn fill flourish may play: always for the local player,
## and for the opponent only iff [member HUDConfig.show_opponent_fill_flourish]
## (ADR-0016 §2). Opponent [constant ApCounterFsm.State.TICK_DOWN] (their own
## commits) is unaffected and always plays.
func _fill_allowed() -> bool:
	if not _is_opponent:
		return true
	return _config != null and _config.show_opponent_fill_flourish


## Opens a preview echo (scene glue calls this when CAI opens a preview).
## [param projected] is CAI's projected-remaining-budget result (verbatim — this
## widget never computes it); [param affordable] is CAI's affordability read. On
## an opponent counter [constant ApCounterFsm.Trigger.PREVIEW_OPEN] is refused
## (echo unreachable), so this is a no-op. An unaffordable preview stores no
## projection and renders "insufficient" (never a negative).
func open_preview(projected: int, affordable: bool) -> void:
	var next: ApCounterFsm.State = ApCounterFsm.next_state(
		_fsm_state, ApCounterFsm.Trigger.PREVIEW_OPEN, _is_opponent)
	if next != ApCounterFsm.State.PREVIEW_ECHO:
		return # opponent context: PREVIEW_ECHO unreachable — no echo.
	_fsm_state = next
	_echo_active = true
	_preview_affordable = affordable
	_projected = projected if affordable else _NO_PROJECTION
	queue_redraw()


## Closes the preview echo (cancel/commit) — reverts to the plain committed value
## with no leftover projection. No state mutation ever happens here.
func close_preview() -> void:
	_fsm_state = ApCounterFsm.next_state(_fsm_state, ApCounterFsm.Trigger.PREVIEW_CLOSE, _is_opponent)
	_clear_echo()
	queue_redraw()


func _clear_echo() -> void:
	_echo_active = false
	_projected = _NO_PROJECTION
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

## The committed budget shown at rest (live verbatim read).
func committed_value() -> int:
	return _committed

## True iff an affordable preview echo is open (renders `committed -> projected`).
func showing_echo() -> bool:
	return _echo_active and _preview_affordable

## The projected budget shown beside the arrow (only meaningful when
## [method showing_echo]); [constant _NO_PROJECTION] otherwise — never a negative.
func projected_value() -> int:
	return _projected

## True iff an unaffordable preview is open — renders "insufficient".
func insufficient_budget() -> bool:
	return _echo_active and not _preview_affordable

## True iff this is the opponent counter (persistent OPPONENT label).
func opponent_label_shown() -> bool:
	return _is_opponent

## True iff this counter uses the muted treatment (opponent budget, CR-3b).
func is_muted() -> bool:
	return _is_opponent

## The current [enum ApCounterFsm.State].
func fsm_state() -> ApCounterFsm.State:
	return _fsm_state


# --- Resource + presentation hooks (overridden by each subclass) --------------

## The current committed budget, read VERBATIM from the reader. Subclasses
## override this to select their pool ([method GameStateReader.current_ap] for AP,
## [method GameStateReader.current_credits] for Credits). Only ever called with a
## non-null reader (both callers guard). The base returns 0 as an inert default.
func _read_committed_value() -> int:
	return 0

## The neon hue for this budget, respecting the muted opponent treatment. The two
## counters sit in DISTINCT hue families (CR-3/CR-3d) so tempo and war chest never
## blur; the final split is an /art-bible decision (OQ-9). Overridden per subclass.
func _budget_color() -> Color:
	return Color(0.55, 0.55, 0.6) if _is_opponent else Color.WHITE

## The committed-value text (incl. the OPPONENT label + any resource glyph/label).
## Overridden per subclass so each budget is distinguishable by more than hue
## alone (accessibility — CR-3d). Default is the bare number.
func _committed_text() -> String:
	# ★ 2026-08-24: always carries its resource label, and no longer repeats
	# "OPPONENT". The player's AP counter used to render a BARE NUMBER — the HUD's
	# most-consulted figure showed as "30" with nothing saying what 30 was. And the
	# opponent's counters are now inside a panel titled OPPONENT, so the prefix said
	# it three times in one box. `opponent_label_shown()` still reports true (AC-19
	# is about the readout being identifiable as the opponent's, which the panel
	# title now does more clearly than a repeated word).
	return "%s %d" % [_resource_label(), _committed]


## The short resource label the counter carries ("AP" / "CR"). Overridden per
## subclass, alongside [method _insufficient_noun].
func _resource_label() -> String:
	return "" 

## The noun for the "insufficient <noun>" unaffordable-preview text
## ("AP" / "credits"). Overridden per subclass.
func _insufficient_noun() -> String:
	return "budget"


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return # headless / no font — the display model is still valid; skip pixels.
	var font_size: int = 16
	var text: String = _committed_text()
	if showing_echo():
		text += "  -> %d" % _projected # ASCII arrow — the engine fallback font has no U+2192 glyph (renders as a tofu box).
	elif insufficient_budget():
		text += "  (insufficient %s)" % _insufficient_noun()
	draw_string(font, Vector2(4, font_size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _budget_color())
