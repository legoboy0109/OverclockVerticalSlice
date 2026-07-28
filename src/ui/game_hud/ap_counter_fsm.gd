## ApCounterFsm — the pure, headless animation-state core of the Game HUD's
## AP counter (ADR-0016 §2/§3, TR-hud-005/006/007).
##
## Mirrors the corpus's established pure-logic / driving-Node split
## ([CommandFSM]/[code]CommandInterface[/code], ADR-0015; [code]AI[/code]/
## [code]AITurnDriver[/code], ADR-0011): the animation-state DECISION is a pure
## function here; the RENDERING (tweens, the [code]→ projected[/code] glyph, the
## [code]OPPONENT[/code] label) is the widget's job (Story 004). Every transition
## is unit-testable headless with zero mocks.
##
## [b]Four states[/b] (TR-hud-005):
## [br]- [constant State.COMMITTED] — the static "trust" state; no motion means
##   the displayed value is real. The committed value moves ONLY on a real commit.
## [br]- [constant State.FILL_FLOURISH] — the start-of-turn AP-fill flourish
##   (plays once per turn).
## [br]- [constant State.TICK_DOWN] — steps the committed value down by exactly N
##   on a real commit. Serialized upstream (see below), never a self-built queue.
## [br]- [constant State.PREVIEW_ECHO] — the committed value is frozen and a
##   [code]→ projected[/code] value renders beside it. SNAPS (no tween); only the
##   local player's counter can reach it.
##
## [b]Opponent restriction[/b] (TR-hud-005): opponent AP can reach only
## [constant State.COMMITTED] (+ [constant State.FILL_FLOURISH] iff the widget's
## [code]show_opponent_fill_flourish[/code] config allows it, +
## [constant State.TICK_DOWN] for the opponent's own commits) — never
## [constant State.PREVIEW_ECHO], since only the local Command & Action Interface
## drives previews. Passing [code]is_opponent = true[/code] structurally refuses
## the [constant Trigger.PREVIEW_OPEN] transition (see [method is_reachable_for_opponent]).
##
## [b]Turn-transition echo force-clear[/b] (TR-hud-006): [constant Trigger.TURN_TRANSITION]
## resolves to [constant State.COMMITTED] from ANY state — it can never yield
## [constant State.FILL_FLOURISH] directly. So the widget clears the preview echo
## FIRST (one [method next_state] call with [constant Trigger.TURN_TRANSITION]),
## THEN evaluates the incoming fill (a SEPARATE [constant Trigger.TURN_START_FILL]
## call). Two distinct calls, never one combined jump — closing the one-frame race
## between the CAI's exit-to-IDLE and the HUD's fill.
##
## [b]GameOver tick-snap[/b] (TR-hud-007): [constant Trigger.GAME_OVER] resolves to
## [constant State.COMMITTED] and [method snaps_to_final] returns [code]true[/code],
## so any in-flight [constant State.TICK_DOWN] is snapped to its final post-spend
## value instantly (the widget reads the snap flag and skips the tween). The
## killing commit's hp-pip drain is a DIFFERENT element (Story 005), not this
## FSM's concern.
##
## [b]AP-tick serialization[/b] (TR-hud-008): this FSM does NOT build its own tick
## queue / interrupt logic. It relies on the upstream ADR-0014 [code]input_locked[/code]
## debounce + the [code]InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms[/code]
## guarantee ([code]HudBalance[/code], Story 002) — one [constant State.TICK_DOWN]
## fully resolves before the next commit's [signal GameState.action_applied]
## arrives. A [constant Trigger.COMMIT_SPEND] arriving mid-[constant State.TICK_DOWN]
## cannot occur under that guarantee; this FSM documents that invariant rather
## than defending against it.
##
## Usage:
## [codeblock]
## var s := ApCounterFsm.State.COMMITTED
## s = ApCounterFsm.next_state(s, ApCounterFsm.Trigger.PREVIEW_OPEN) # -> PREVIEW_ECHO
## s = ApCounterFsm.next_state(s, ApCounterFsm.Trigger.PREVIEW_CLOSE) # -> COMMITTED (no leftover →)
## # turn boundary: clear the echo, THEN fill (two calls, order guaranteed):
## s = ApCounterFsm.next_state(s, ApCounterFsm.Trigger.TURN_TRANSITION) # -> COMMITTED
## s = ApCounterFsm.next_state(s, ApCounterFsm.Trigger.TURN_START_FILL) # -> FILL_FLOURISH
## [/codeblock]
class_name ApCounterFsm
extends RefCounted

## The four animation states (TR-hud-005). [constant COMMITTED] is the rest
## state; the other three are transient animations.
enum State { COMMITTED, FILL_FLOURISH, TICK_DOWN, PREVIEW_ECHO }

## The external events that drive [method next_state] (ADR-0016 §2). Animation
## COMPLETION is not a trigger — it is the widget's own concern (the widget
## settles a finished flourish/tick back to [constant State.COMMITTED] on its
## tween-done callback).
enum Trigger { TURN_START_FILL, COMMIT_SPEND, PREVIEW_OPEN, PREVIEW_CLOSE, TURN_TRANSITION, GAME_OVER }


## PURE, TOTAL: the next animation [enum State] for [param current] under
## [param trigger] (ADR-0016 §2). Depends on [param current] only for the
## opponent-restricted PREVIEW triggers; every other trigger maps to a fixed
## target (the counter animates on the event, not on where it was).
##
## [param is_opponent] structurally forbids [constant State.PREVIEW_ECHO] over
## opponent AP (TR-hud-005): a [constant Trigger.PREVIEW_OPEN]/[constant Trigger.PREVIEW_CLOSE]
## with [param is_opponent] true is a no-op that stays in [param current] — only
## the local player's Command & Action Interface drives previews.
##
## [constant Trigger.GAME_OVER] and [constant Trigger.TURN_TRANSITION] both
## resolve to [constant State.COMMITTED] from any state (GameOver settles to
## rest — snap flag via [method snaps_to_final]; a turn transition force-clears
## any [constant State.PREVIEW_ECHO] before a fill can be evaluated separately).
static func next_state(current: State, trigger: Trigger, is_opponent: bool = false) -> State:
	match trigger:
		Trigger.GAME_OVER:
			return State.COMMITTED
		Trigger.TURN_TRANSITION:
			return State.COMMITTED
		Trigger.TURN_START_FILL:
			return State.FILL_FLOURISH
		Trigger.COMMIT_SPEND:
			return State.TICK_DOWN
		Trigger.PREVIEW_OPEN:
			return current if is_opponent else State.PREVIEW_ECHO
		Trigger.PREVIEW_CLOSE:
			return current if is_opponent else State.COMMITTED
	return current # unreachable given the enum is exhaustive above; keeps the function total.


## PURE: whether [param trigger] forces the committed value to snap to its final
## post-spend value instantly (no tween) — [constant Trigger.GAME_OVER] does
## (TR-hud-007), so a GameOver landing mid-[constant State.TICK_DOWN] completes
## the tick within the transition. The load-bearing case is GameOver-during-tick;
## from a resting state the snap is a harmless no-op. [param current] is accepted
## for signature symmetry with [method next_state] but does not change the answer.
static func snaps_to_final(_current: State, trigger: Trigger) -> bool:
	return trigger == Trigger.GAME_OVER


## PURE: whether [param state] is reachable for OPPONENT AP (TR-hud-005) — every
## state except [constant State.PREVIEW_ECHO], which only the local player's
## previews can produce. Story 007's opponent-muting reads this to assert the
## restriction rather than re-deriving it.
static func is_reachable_for_opponent(state: State) -> bool:
	return state != State.PREVIEW_ECHO
