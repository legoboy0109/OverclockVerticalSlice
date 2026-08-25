## CommandInterface — the Presentation [Node] that drives the pure, headless
## [CommandFSM] core and owns the four-tier preview recompute discipline
## (ADR-0015 §1/§3, TR-cmdui-005..009).
##
## Presentation-layer system per ADR-0015. Mirrors the corpus's established
## pure-logic/driving-Node split ([code]AI[/code]/[AITurnDriver], ADR-0011):
## [CommandFSM] is the pure transition/menu core (cai-001); this [Node]
## forwards triggers into it, holds the FSM's [i]current[/i] state, and owns
## the ephemeral per-preview recompute sets ([member _reachable]/
## [member _targets]/[member _after_move_attackable]) — none of which belong
## in the pure core.
##
## [b]Story 002 shipped[/b] the four-tier recompute discipline — [i]when[/i]
## each tier's queries fire, and the O(1) hover-read contract.
##
## [b]Story 003 adds[/b] the real commit-dispatch entry point
## ([method commit], TR-cmdui-015) — building a concrete [Action] and routing
## it through [method GameState.apply_action] exactly like
## [code]AITurnDriver.run_ai_turn[/code] does (same real, authoritative
## [param state], never a clone) — and the turn-boundary input-scoping gate
## ([method is_input_live], AC-21): command input (selection, preview entry,
## commit) is live only during the local player's own live Action phase;
## outside that window every trigger this class exposes must be refused
## before it ever reaches the FSM or [method GameState.apply_action], leaving
## only read-only inspection. [method _on_commit_result]'s Tier-4 reject
## re-issue (Story 002) is unchanged and is exactly what a rejected
## [method commit] call routes into for a unit-bearing preview.
##
## [b]Story 006 adds[/b] overlay rendering ([method _render_overlays],
## TR-cmdui-016) — called at the end of every [method _recompute_tier1_and_2]
## so the [BoardRenderer]'s painted overlay always reflects whichever tier
## dicts are currently held, including re-issues (AC-19/AC-30) and Tier-4
## reject re-issues — and click routing ([method route_click],
## TR-cmdui-003/004): [member _renderer]'s [code]pick_at[/code] is consumed as
## the [i]one[/i] click-routing entry point, resolving occupant-priority
## selection for an own [UnitState] occupant. Also adds
## [method glyph_anchor] (TR-cmdui-017), a pure delegation to
## [method BoardRenderer.glyph_anchor] — the sanctioned
## [code]grid_to_screen(tile) + GLYPH_OFFSETS[class][/code] anchor convention
## is never re-derived here.
##
## Deliberately [b]out of scope[/b] (see the story's Out of Scope section):
## real [code]pick_at[/code]/[code]screen_to_grid[/code] iso-picking math
## (Board Renderer, consumed only), [code]BoardCursor[/code] tile-stepping
## (Story 005), Cancel-Build's hold gesture (Story 004), and the
## [code]input_locked[/code] debounce / shared commit-flash↔AP-tick
## [signal GameState.action_applied] emit wiring (Story 007) — this story
## establishes the [method commit]/[signal GameState.action_applied] plumbing
## Story 007 hangs the flash off, but does not itself fire any flash/audio.
## Story 006's [method route_click] likewise stops at [i]selection[/i] —
## committing a move/attack from a click-in-preview (the action-build +
## [code]INPUT_LOCK_MS[/code] dispatch) is Story 007's scope, not this one's.
##
## [b]Testability seam (Logic story, spy-countable):[/b] every query this
## class calls sits behind an injectable [Callable] field
## ([member _reachable_fn]/[member _legal_targets_fn]/
## [member _legal_targets_from_fn]/[member _attack_cost_fn]), defaulting to
## the real static query. [member _renderer] is an injected, duck-typed
## picking source (anything exposing [code]pick_at(screen_pos: Vector2)[/code]
## returning an object with a [code]tile: Vector2i[/code] field — the real
## production value is a [BoardRenderer], per ADR-0015 §1). Call
## [method configure_dependencies] to substitute counting spies in a test;
## production code never needs to call it (the defaults are the real
## statics).
##
## [b]The four tiers (ADR-0015 §3), where each lives in this file:[/b]
## [br]- [b]Tier 1[/b]: [method _recompute_tier1] — [method _reachable_fn]/
## [method _legal_targets_fn] fire once on preview entry
## ([method enter_preview]) and are RE-ISSUED verbatim (same helper) whenever
## [method notify_action_applied] fires while a preview is open. Never
## per-hover.
## [br]- [b]Tier 2[/b]: [method _recompute_tier2] — batches
## [method _legal_targets_from_fn] across the just-computed Tier-1
## [member _reachable] frontier, only on [constant CommandFSM.State.PREVIEW_MOVE]
## entry/re-issue. Never per-hover.
## [br]- [b]Tier 3[/b]: [method _on_mouse_moved_to_tile] /
## [method get_reachable_tile] / [method get_target] /
## [method is_after_move_attackable] — O(1) dict reads only, on every
## [member _active_tile] change. Zero query calls.
## [br]- [b]Tier 4[/b]: [method _on_commit_result] — not a recompute; reads
## [member ActionResult.ok]. On reject: swallow, spend 0 AP, re-issue Tier-1
## (+Tier-2 if the preview is [constant CommandFSM.State.PREVIEW_MOVE]), stay
## in the menu.
##
## Usage (production):
## [codeblock]
## @onready var _interface := CommandInterface.new()
## _interface.enter_preview(state, some_unit, CommandFSM.State.PREVIEW_MOVE)
## # ... later, on a real board-changing commit:
## _interface.notify_action_applied(state, some_unit)
## [/codeblock]
##
## Usage (test, spying):
## [codeblock]
## var iface := CommandInterface.new()
## var spy := ReachableSpy.new() # wraps Movement.reachable, counts calls
## iface.configure_dependencies(spy.call, Combat.legal_targets, \
##         Combat.legal_targets_from, Combat.attack_cost_for, mock_renderer)
## iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
## assert_int(spy.call_count).is_equal(1)
## [/codeblock]
class_name CommandInterface
extends Node


## Commit-flash request (Story 007, TR-cmdui-023): emitted synchronously when a
## commit resolves with [code]result.ok == true[/code], from this interface's
## subscription to the shared [signal GameState.action_applied]. The visual
## flash layer (Story 009 / art) connects to this and animates the tile/target
## confirm-flash; THIS system fires no flash animation or audio of its own — the
## AP-counter tick-down (Game HUD, a separate epic) subscribes to the SAME
## [signal GameState.action_applied] independently, so flash and tick start on
## the same frame by construction (never one polling/reacting to the other).
signal commit_flash_requested(result: ActionResult)


## Selection/inspection target change (ADR-0016 §6 / ADR-0015 §6 seam,
## TR-hud-013): emitted whenever this interface's persistent selection OR
## transient inspection (peek) target changes. Carries a [SelectionTarget]
## ([code]{entity_id, pinned}[/code]) — [code]pinned == true[/code] for the
## persistent [member _selected_id] selection, [code]false[/code] for a transient
## hover/inspect peek; [code]entity_id == -1[/code] means "no target" (nothing
## selected and nothing being inspected). This is the ONE-WAY outward-in seam the
## Game HUD's detail panel (ADR-0016 §6) subscribes to — the HUD re-renders from a
## read query for [code]target.entity_id[/code] via its own [code]GameStateReader[/code];
## this interface NEVER calls into a HUD node, so the HUD stays a leaf
## (TR-hud-013/020). Emissions are de-duplicated (fire only when the
## (entity_id, pinned) pair actually changes) via [method _emit_selection].
signal selection_changed(target: SelectionTarget)


## Sentinel "no tile hovered yet" value for [member _active_tile] — distinct
## from any real board coordinate a [BoardRenderer]/[code]screen_to_grid[/code]
## would ever return (grid coordinates are non-negative per
## [GridState]'s own contract), so the very first real hover always reads as
## a tile change.
const _NO_ACTIVE_TILE: Vector2i = Vector2i(-1, -1)


## The FSM's current state (ADR-0015 §1) — mutated only via
## [method enter_preview]/[method back_out_of_preview], never assigned
## directly by external callers.
var _fsm_state: CommandFSM.State = CommandFSM.State.IDLE

## The currently selected entity's id, or -1 if none (ADR-0015 §1).
var _selected_id: int = -1

## De-dup state for [signal selection_changed] (ADR-0016 §6): the last
## (entity_id, pinned) pair emitted, so a re-assert of the same target is a
## no-op. [member _last_target_entity_id] starts at -2 (distinct from the -1
## "no target" sentinel) so the very first emit — even a clear to -1 — fires.
var _last_target_entity_id: int = -2
var _last_target_pinned: bool = false

## Tier-1/Tier-3: [code]Vector2i -> Movement.ReachableTile[/code], the
## just-computed reachable frontier for the previewed unit. Populated only
## while [member _fsm_state] is [constant CommandFSM.State.PREVIEW_MOVE].
var _reachable: Dictionary = {}

## Tier-1/Tier-3: [code]Vector2i -> Combat.TargetResult[/code], the
## just-computed legal-target set for the previewed attacker. Populated only
## while [member _fsm_state] is [constant CommandFSM.State.PREVIEW_ATTACK].
var _targets: Dictionary = {}

## Tier-2/Tier-3: [code]Vector2i -> bool[/code], the D-3
## "attack-possible-after-move" marker for every tile in [member _reachable]
## (ADR-0015 §3, AC-11). Populated only while [member _fsm_state] is
## [constant CommandFSM.State.PREVIEW_MOVE].
var _after_move_attackable: Dictionary = {}

## The last tile-gated hover position (TR-cmdui-005) — [constant _NO_ACTIVE_TILE]
## until the first hover/click resolves a tile.
var _active_tile: Vector2i = _NO_ACTIVE_TILE

## Which input locus last moved the active tile (Story 005, TR-cmdui-020,
## ADR-0014). [constant Locus.NONE] until the first input resolves a tile.
enum Locus { NONE, MOUSE, BOARD_CURSOR }

## The input locus that last updated [member _active_tile] — set
## [b]last-handler-wins[/b] with NO timestamp/frame-delta comparison
## (TR-cmdui-020): Godot's synchronous single-threaded input dispatch already
## makes "whichever handler ran last" the correct answer, so a mouse move then a
## cursor key then a mouse move leaves this reflecting each input in dispatch
## order. See [method _on_mouse_moved_to_tile] / [method _on_board_locus_moved].
var _active_locus: Locus = Locus.NONE

## Injectable Tier-1 move query — defaults to the real
## [method Movement.reachable]. Swap for a counting spy in tests via
## [method configure_dependencies].
var _reachable_fn: Callable = Movement.reachable

## Injectable Tier-1 attack query — defaults to the real
## [method Combat.legal_targets].
var _legal_targets_fn: Callable = Combat.legal_targets

## Injectable Tier-2 batch query — defaults to the real
## [method Combat.legal_targets_from].
var _legal_targets_from_fn: Callable = Combat.legal_targets_from

## Injectable attack-cost query (the D-3 affordability term, AC-11) —
## defaults to the real [method Combat.attack_cost_for].
var _attack_cost_fn: Callable = Combat.attack_cost_for

## Injected picking source (production: a [BoardRenderer]; tests: a mock).
## Duck-typed to [code]pick_at(screen_pos: Vector2)[/code] returning an
## object exposing a [code]tile: Vector2i[/code] field — never assumed to be
## a literal [BoardRenderer.PickResult] so a lightweight test double works
## without depending on the Board Renderer's own class.
var _renderer: Object = null

## Which player THIS [CommandInterface] instance acts on behalf of (ADR-0015
## §5 Turn Manager bullet, TR-cmdui-015, AC-21) — the "local player" every
## [method is_input_live] check gates against. Set once via
## [method set_local_player] (production: at scene-setup time, mirroring how
## a real match assigns one [CommandInterface] per local human seat); defaults
## to [code]0[/code] so an un-configured instance in a single-instance test
## still gates sensibly against player 0.
var _local_player: int = 0

## Result of one [method tick_cancel_hold] tick (Story 004, ADR-0015 §2).
enum CancelHoldResult { CONTINUE, COMMITTED, ABORTED }

## Feel/timing knobs for input gestures (ADR-0014 [InputConfig] Resource).
## Injected via [method set_input_config]; defaults to a fresh [InputConfig] so
## an un-configured instance still carries the placeholder cancel-build hold ms.
var _input_config: InputConfig = InputConfig.new()

## Commit-input debounce flag (Story 007, TR-cmdui-022). True from the instant a
## commit dispatches via [method dispatch_commit] until the
## [member InputConfig.input_lock_ms] window elapses; a new dispatch while true
## is inert (AC-27). A UX debounce ONLY — it gates nothing but new commit
## dispatch (hover/cursor/menu-focus stay live), and is NOT the single-commit
## correctness mechanism (that is structural: synchronous dispatch + the FSM's
## immediate transition).
var input_locked: bool = false

## The live [GameState] this interface is subscribed to via
## [method attach_to_state] (Story 007/008), or [code]null[/code] if unattached.
## Held so the shared-signal handler [method _on_action_applied] can read
## [member GameState.match_status] for GAME_OVER convergence (TR-cmdui-015,
## AC-34/AC-35) — the [signal GameState.action_applied] payload carries only the
## [ActionResult], not the state.
var _attached_state: GameState = null

## Accumulated hold time (ms) for the in-progress Cancel-Build gesture — a
## bounded sub-condition WITHIN ENTITY_SELECTED (TR-cmdui-002), never a new FSM
## state. Reset to 0 on commit or abort.
var _cancel_hold_elapsed_ms: float = 0.0

## The structure a live Cancel-Build hold targets, or [code]null[/code] when no
## hold is in progress (also [method _process]'s enable-gate). Set by
## [method begin_cancel_hold], cleared on a terminal tick.
var _cancel_hold_structure: StructureState = null

## The live [GameState] captured for the duration of a Cancel-Build hold so
## [method _process] can forward it to [method tick_cancel_hold].
var _cancel_hold_state: GameState = null


## Dependency-injection seam (project standard: DI over singletons,
## `.claude/docs/technical-preferences.md`). Call once, before driving any
## tier, to substitute counting spies / a mock renderer. Any parameter left
## as [code]null[/code]/unset keeps its current value — pass only what a
## given test needs to observe.
func configure_dependencies(reachable_fn: Callable = _reachable_fn, \
		legal_targets_fn: Callable = _legal_targets_fn, \
		legal_targets_from_fn: Callable = _legal_targets_from_fn, \
		attack_cost_fn: Callable = _attack_cost_fn, \
		renderer: Object = _renderer) -> void:
	_reachable_fn = reachable_fn
	_legal_targets_fn = legal_targets_fn
	_legal_targets_from_fn = legal_targets_from_fn
	_attack_cost_fn = attack_cost_fn
	_renderer = renderer


## Current FSM state — read-only accessor for tests/callers (ADR-0015 §1's
## held state is otherwise private-by-convention).
func fsm_state() -> CommandFSM.State:
	return _fsm_state


## Currently selected entity id, or -1 if none.
func selected_id() -> int:
	return _selected_id


## Emits [signal selection_changed] with a fresh [SelectionTarget] IFF the
## (entity_id, pinned) pair differs from the last emitted one (ADR-0016 §6
## de-dup). [param entity_id] == -1 signals "no target". The single choke point
## every selection/inspection change routes through, so the outward-in HUD seam
## never sees a redundant re-render request.
func _emit_selection(entity_id: int, pinned: bool) -> void:
	if entity_id == _last_target_entity_id and pinned == _last_target_pinned:
		return
	_last_target_entity_id = entity_id
	_last_target_pinned = pinned
	selection_changed.emit(SelectionTarget.new(entity_id, pinned))


## Transient inspection (peek) entry point (ADR-0016 §6 seam, TR-hud-013): the
## scene's hover glue calls this when the pointer / board-cursor rests on
## [param tile]. If an entity occupies [param tile], emits a PEEK
## [signal selection_changed] ([code]pinned == false[/code]) for it; if the tile
## is empty, falls back to the current persistent selection
## ([member _selected_id], [code]pinned == true[/code], or a cleared -1 target if
## nothing is selected) — so un-hovering returns the detail panel to the pinned
## selection. Read-only: never mutates state, never selects, and is deliberately
## NOT gated by [method is_input_live] (inspection stays live on the opponent's
## turn / after GAME_OVER, AC-21). The pinned-vs-peek VISUAL distinction is the
## HUD's / [code]/ux-design[/code]'s concern; this only reports which entity,
## with which flag. O(1) plus one [method GameState.entity_at] lookup.
func inspect(state: GameState, tile: Vector2i) -> void:
	var occupant: EntityState = state.entity_at(tile)
	if occupant != null:
		_emit_selection(occupant.entity_id, false)
	else:
		_emit_selection(_selected_id, _selected_id != -1)


## Sets [member _local_player] — which player this instance acts on behalf of
## (ADR-0015 §5, AC-21). Called once at setup, mirroring
## [method configure_dependencies]'s DI-seam convention.
func set_local_player(player: int) -> void:
	_local_player = player


## Injects the [InputConfig] feel/timing Resource (DI seam, mirrors
## [method configure_dependencies]). Defaults to a fresh [InputConfig].
func set_input_config(config: InputConfig) -> void:
	_input_config = config


## Injects the duck-typed board renderer after construction — the "renderer only"
## passthrough the vertical-slice scene needs to wire click routing without
## re-supplying the query Callables that the all-at-once [method configure_dependencies]
## path demands (mirrors [method set_local_player] / [method set_input_config]).
## The injected object must expose [code]pick_at(screen_pos: Vector2)[/code] (the ONE
## click-routing entry point [method route_click] consumes, ADR-0013 §4) and, for the
## overlay path, [code]set_overlays[/code] / [code]clear_overlay[/code] /
## [code]glyph_anchor[/code]. A null renderer leaves the pick/overlay seams as
## defensive no-ops.
func set_renderer(renderer: Object) -> void:
	_renderer = renderer


## Subscribes this interface to [param state]'s shared
## [signal GameState.action_applied] (Story 007, TR-cmdui-023) — the ONE seam the
## commit-flash (here) and the AP-counter tick (Game HUD epic) both hang off, so
## they start on the same frame by construction. Idempotent: connecting twice is
## a no-op. Call once when the interface is attached to a live match (the scene's
## setup), mirroring [method set_local_player]. Both players' interface instances
## subscribe to the same signal, so each observes every commit (ADR-0004/ADR-0015
## §2's both-instances convergence).
func attach_to_state(state: GameState) -> void:
	_attached_state = state
	if not state.action_applied.is_connected(_on_action_applied):
		state.action_applied.connect(_on_action_applied)


## Disconnects from the shared [signal GameState.action_applied] on tree exit
## (Story 008, control-manifest lifecycle rule) — safe insurance if a
## [GameState] is reused across a match restart within one process (per
## ADR-0001 each match likely constructs a fresh state, in which case this is
## harmless dead cleanup, never wrong). Idempotent.
func _exit_tree() -> void:
	if _attached_state != null and _attached_state.action_applied.is_connected(_on_action_applied):
		_attached_state.action_applied.disconnect(_on_action_applied)


## Shared-signal handler (Story 007, TR-cmdui-023): fires the commit-flash
## request synchronously on a successful commit — the SAME frame
## [signal GameState.action_applied] is emitted from inside
## [method GameState.apply_action] (that signal fires exactly once per commit,
## synchronously). A rejected commit ([code]result.ok == false[/code]) flashes
## nothing. This method NEVER calls [code]AudioStreamPlayer.play()[/code] —
## Combat triggers its own attack cue off this same event, so exactly one system
## plays audio (AC audio-ownership).
##
## [b]GAME_OVER convergence (Story 008, TR-cmdui-015, AC-34/AC-35):[/b] after the
## flash, checks [member _attached_state]'s [member GameState.match_status]; if a
## commit's win-check has set it to [constant GameState.MatchStatus.GAME_OVER]
## (Game State's terminal-check runs BEFORE this emit, ADR-0010), this instance
## enters the absorbing terminal [constant CommandFSM.State.GAME_OVER] — whether
## or not [b]this[/b] instance's own commit caused it. Because both players'
## interfaces subscribe to the SAME signal and read the SAME shared
## [member GameState.match_status], the non-committing (opponent-turn-inert)
## instance converges on the same signal (AC-35), no polling, no "who won"
## bookkeeping.
func _on_action_applied(result: ActionResult) -> void:
	if result.ok:
		commit_flash_requested.emit(result)
	if _attached_state != null and _attached_state.match_status == GameState.MatchStatus.GAME_OVER:
		_enter_game_over()


## Debounced commit dispatch (Story 007, TR-cmdui-022, AC-27): the input-locked
## entry point for a user-driven commit. Inert (returns [code]false[/code], no
## [method GameState.apply_action] call) when [member input_locked] is already
## true — so two rapid inputs (a double-click) fire exactly one commit. Otherwise
## sets [member input_locked], routes the action through [method commit] (the
## real [method GameState.apply_action] path, whose emit drives the flash), then
## schedules the lock release after [member InputConfig.input_lock_ms]. Returns
## whether this call actually dispatched. The lock is a UX debounce layered ON
## TOP of the already-correct single-commit guarantee (do NOT treat it as the
## safety mechanism). Requires this Node be in the scene tree (the release timer
## uses [method Node.get_tree]) — it is a scene-driven Node.
func dispatch_commit(action: Action, state: GameState) -> bool:
	if input_locked:
		return false
	input_locked = true
	commit(state, action)
	_release_lock_after_window()
	return true


## Releases [member input_locked] after [member InputConfig.input_lock_ms] via a
## SceneTree timer (ADR-0014's [code]await create_timer().timeout[/code] idiom,
## 4.6-confirmed). Called fire-and-forget from [method dispatch_commit]: it runs
## synchronously up to the [code]await[/code] (creating the timer), then yields —
## so [method dispatch_commit] stays synchronous and the release lands later on
## its own, with no manual reset anywhere.
func _release_lock_after_window() -> void:
	await get_tree().create_timer(_input_config.input_lock_ms / 1000.0).timeout
	input_locked = false


## Begins a Cancel-Build hold for [param structure] (the selected
## under-construction owned structure). Enables [method _process] ONLY for the
## bounded hold window (ADR-0015 §2 — the per-frame poll is not a steady-state
## cost). The real input handler invokes this when the destructive affordance is
## first pressed.
func begin_cancel_hold(state: GameState, structure: StructureState) -> void:
	_cancel_hold_elapsed_ms = 0.0
	_cancel_hold_state = state
	_cancel_hold_structure = structure
	set_process(true)


## Testable core of the hold-to-confirm gesture (Story 004, TR-cmdui-002,
## AC-18): one accumulator tick. While [param is_pressed], adds [param delta_ms]
## to the running hold total; at >= [member InputConfig.cancel_build_hold_ms] it
## commits a [CancelBuildAction] for [param structure] through [method commit]
## (this layer deducts no AP — [method BaseProduction.apply_cancel] credits the
## refund), resets the accumulator, and returns [constant CancelHoldResult.COMMITTED].
## A release ([param is_pressed] false) after any accumulation but before the
## threshold returns [constant CancelHoldResult.ABORTED] with the accumulator
## reset and zero state change — so a bare single click or a rapid double-click
## (neither sustains a hold) can never trigger the refund-destroy (CR-6a's
## input-shape constraint). Otherwise [constant CancelHoldResult.CONTINUE].
## Never adds a [enum CommandFSM.State] — the hold is a sub-condition of
## ENTITY_SELECTED. Directly unit-testable with synthetic delta/pressed values
## (no real [method _process]/[Input]).
func tick_cancel_hold(delta_ms: float, is_pressed: bool, state: GameState, \
		structure: StructureState) -> CancelHoldResult:
	if not is_pressed:
		if _cancel_hold_elapsed_ms > 0.0:
			_cancel_hold_elapsed_ms = 0.0
			return CancelHoldResult.ABORTED
		return CancelHoldResult.CONTINUE
	_cancel_hold_elapsed_ms += delta_ms
	if _cancel_hold_elapsed_ms >= float(_input_config.cancel_build_hold_ms):
		_cancel_hold_elapsed_ms = 0.0
		var action := CancelBuildAction.new()
		action.player = _local_player
		action.structure_id = structure.entity_id
		commit(state, action)
		return CancelHoldResult.COMMITTED
	return CancelHoldResult.CONTINUE


## Engine glue (ADR-0015 §2): runs ONLY while a Cancel-Build hold is live
## ([member _cancel_hold_structure] non-null — [method begin_cancel_hold] enabled
## it, a terminal tick disables it) — polls the [code]cancel_build[/code] input
## action and forwards to the testable [method tick_cancel_hold]. Not a
## steady-state per-frame cost.
func _process(delta: float) -> void:
	if _cancel_hold_structure == null:
		return
	var result: CancelHoldResult = tick_cancel_hold(delta * 1000.0, \
		Input.is_action_pressed(&"cancel_build"), _cancel_hold_state, _cancel_hold_structure)
	if result != CancelHoldResult.CONTINUE:
		_cancel_hold_structure = null
		_cancel_hold_state = null
		set_process(false)


## Disable per-frame processing by default — Cancel-Build's [method _process] is
## enabled only for a bounded hold window (ADR-0015 §2), never steady-state.
func _ready() -> void:
	set_process(false)


## Turn-boundary input-scoping gate (ADR-0015 §5 Turn Manager bullet,
## TR-cmdui-015, AC-21): true iff command input is live for
## [member _local_player] right now — the match has not ended
## ([member GameState.match_status] is not [constant GameState.MatchStatus.GAME_OVER])
## AND it is [member _local_player]'s own turn
## ([member GameState.active_player] == [member _local_player]). Every
## selection/preview-entry/commit trigger this class exposes must check this
## FIRST and refuse (no [constant CommandFSM.State.ENTITY_SELECTED] transition,
## no [method GameState.apply_action] call) when it is false — leaving only
## read-only inspection (AC-21's "inspection shows but no menu opens and
## nothing commits"). Never gates the pure Tier-3 O(1) read accessors
## ([method get_reachable_tile]/[method get_target]/
## [method is_after_move_attackable]) — those answer "what does the currently
## held preview data say," not "is it legal to act," and read-only inspection
## must keep working even when input is not live. O(1).
func is_input_live(state: GameState) -> bool:
	if state.match_status == GameState.MatchStatus.GAME_OVER:
		return false
	return state.active_player == _local_player


## AC-21 selection entry point: attempts to select [param unit] into
## [constant CommandFSM.State.ENTITY_SELECTED] via [method CommandFSM.next_state],
## but ONLY when [method is_input_live] is true. When input is not live
## (opponent's turn, or the match is over), this is a hard no-op — returns
## [code]false[/code], never touches [member _fsm_state]/[member _selected_id],
## and never calls into [CommandFSM] at all — the FSM transition function is
## never even invoked, so there is structurally no path to
## [constant CommandFSM.State.ENTITY_SELECTED] from a non-live trigger. A
## caller building a real board's click handler uses this (or an equivalent
## own-turn check) before every selection attempt; hover/inspection reads
## (e.g. a read-only info panel) are expected to bypass this gate entirely and
## read [param state] directly, which this method does not prevent.
## ★ 2026-08-24: [param entity] widened from [UnitState] to [EntityState]. CR-3
## says "left-clicking an entity the active player owns... selects it", and a
## defensive structure both attacks and produces — but the old signature made
## every structure unselectable, so the two verbs it owns were unreachable through
## the interface that exists to reach verbs.
func try_select(state: GameState, entity: EntityState) -> bool:
	if not is_input_live(state):
		return false
	_selected_id = entity.entity_id
	_fsm_state = CommandFSM.next_state(_fsm_state, CommandFSM.Trigger.SELECT_OWN, state)
	_emit_selection(_selected_id, true) # pinned selection (ADR-0016 §6).
	return true


## Drives [param unit]'s selection into a preview state and fires that
## preview's Tier-1 (+Tier-2 if [param target_state] is
## [constant CommandFSM.State.PREVIEW_MOVE]) recompute exactly once
## (ADR-0015 §3). [param target_state] is the FSM state this preview enters —
## [constant CommandFSM.State.PREVIEW_MOVE] or
## [constant CommandFSM.State.PREVIEW_ATTACK] — supplied by the caller rather
## than re-derived from a [enum CommandFSM.Trigger] here, since full
## trigger-to-state routing (which verb the player picked, menu wiring) is
## other stories' scope (Story 003/007); this method's job is purely "a
## preview of this kind just began for this unit — recompute its tiers."
##
## Sets [member _selected_id] and [member _fsm_state] via
## [method CommandFSM.next_state] (so the FSM's own transition table — not a
## bespoke assignment — governs the resulting state), then delegates to
## [method _recompute_tier1] (and [method _recompute_tier2] for
## [constant CommandFSM.State.PREVIEW_MOVE]).
func enter_preview(state: GameState, entity: EntityState, target_state: CommandFSM.State) -> void:
	if _fsm_state == CommandFSM.State.GAME_OVER:
		return # absorbing terminal — no preview accepted (Story 008, AC-34).
	_selected_id = entity.entity_id
	# ★ 2026-08-24 — was a binary "PICK_MOVE if PREVIEW_MOVE else PICK_ATTACK",
	# written when only two previews had callers. The action menu opens all four
	# verbs, and the old expression silently mapped Produce and Build onto the
	# ATTACK trigger — which the FSM would then route to PREVIEW_ATTACK, i.e. the
	# wrong preview for the verb the player just picked.
	var trigger: CommandFSM.Trigger = _trigger_for_preview(target_state)
	_fsm_state = CommandFSM.next_state(CommandFSM.State.ENTITY_SELECTED, trigger, state)
	_emit_selection(_selected_id, true) # still the pinned selection; deduped if unchanged.
	_recompute_tier1_and_2(state, entity)


## The [enum CommandFSM.Trigger] that drives [constant CommandFSM.State.ENTITY_SELECTED]
## into [param target_state]. Total over the four preview states; any other value
## falls back to [constant CommandFSM.Trigger.PICK_MOVE], whose transition is inert
## from a non-ENTITY_SELECTED state anyway.
static func _trigger_for_preview(target_state: CommandFSM.State) -> CommandFSM.Trigger:
	match target_state:
		CommandFSM.State.PREVIEW_ATTACK:
			return CommandFSM.Trigger.PICK_ATTACK
		CommandFSM.State.PREVIEW_PRODUCE:
			return CommandFSM.Trigger.PICK_PRODUCE
		CommandFSM.State.PREVIEW_BUILD:
			return CommandFSM.Trigger.PICK_BUILD_CMD
		_:
			return CommandFSM.Trigger.PICK_MOVE


## Backs the interface out of an open preview to
## [constant CommandFSM.State.ENTITY_SELECTED], keeping the selection and clearing
## the preview's overlay. Returns whether anything was backed out of — false when
## no preview is open, so a caller can layer further back-out meanings (deselect,
## then pause) on top without either level guessing
## (`design/ux/action-menu.md`, decision 1).
##
## Spends nothing. CR-1's "cancel exits any preview to the menu, spending nothing
## at every step" is the whole contract here.
func back_out_preview(state: GameState) -> bool:
	if not _is_preview_state(_fsm_state) \
			and _fsm_state != CommandFSM.State.PREVIEW_PRODUCE \
			and _fsm_state != CommandFSM.State.PREVIEW_BUILD:
		return false
	_fsm_state = CommandFSM.next_state(_fsm_state, CommandFSM.Trigger.BACK_OUT, state)
	_reachable.clear()
	_targets.clear()
	_after_move_attackable.clear()
	_render_overlays()
	return true


## Clears the selection to [constant CommandFSM.State.IDLE] — CR-3's "clicking
## empty terrain or pressing ESC deselects". Returns whether there was a selection
## to clear.
##
## Routes through [method CommandFSM.next_state] with
## [constant CommandFSM.Trigger.SELECT_ENEMY_OR_EMPTY] rather than assigning
## [constant CommandFSM.State.IDLE] directly, so the FSM's own table stays the only
## thing that decides where a trigger lands — including from
## [constant CommandFSM.State.GAME_OVER], which is absorbing and must not be left
## by a deselect.
func deselect(state: GameState) -> bool:
	if _fsm_state == CommandFSM.State.IDLE or _fsm_state == CommandFSM.State.GAME_OVER:
		return false
	_fsm_state = CommandFSM.next_state(
		_fsm_state, CommandFSM.Trigger.SELECT_ENEMY_OR_EMPTY, state
	)
	_selected_id = -1
	_reachable.clear()
	_targets.clear()
	_after_move_attackable.clear()
	_emit_selection(-1, false)
	_render_overlays()
	return true


## Board-change re-issue hook (ADR-0015 §3, AC-19): call whenever
## [signal GameState.action_applied] fires while a preview is open. Re-issues
## the [b]exact same[/b] Tier-1 (+Tier-2) recompute [method enter_preview]
## uses — never a bespoke second code path — satisfying "the reachable
## overlay reflects the new board state... no reselect trick." A no-op if no
## preview is currently open (Tier-1/2 have nothing to refresh outside
## [constant CommandFSM.State.PREVIEW_MOVE]/[constant CommandFSM.State.PREVIEW_ATTACK]).
func notify_action_applied(state: GameState, entity: EntityState) -> void:
	if not _is_preview_state(_fsm_state):
		return
	_recompute_tier1_and_2(state, entity)


## Tier-4 (ADR-0015 §3): reacts to a commit's [ActionResult] — never a
## recompute itself, the legality re-validation already happened inside the
## owning system's [code]apply_action[/code] before [param result] was
## returned. On [member ActionResult.ok] == [code]false[/code]: swallow (no
## error propagated), spend 0 AP (nothing here ever deducts AP — Pass-Through
## Invariant), re-issue Tier-1 (+Tier-2) via the same helper
## [method notify_action_applied] uses, and stay in the current preview menu
## (never transition [member _fsm_state]). On [code]true[/code]: this story
## does nothing further — leaving/advancing the FSM on a successful commit is
## Story 007's full commit-dispatch scope.
func _on_commit_result(result: ActionResult, state: GameState, entity: EntityState) -> void:
	if result.ok:
		return
	_recompute_tier1_and_2(state, entity)


## The commit-dispatch entry point (ADR-0015 §5 Turn Manager/Movement/Combat/
## Base & Production bullets, TR-cmdui-011..015, AC-4): routes [param action]
## through the sole mutation vector, [method GameState.apply_action], exactly
## like [code]AITurnDriver.run_ai_turn[/code]'s
## [code]state.apply_action(action)[/code] call — the SAME real, authoritative
## [param state], never a clone. This layer deducts [b]no[/b] AP and mutates
## nothing itself: whichever owning system's [code]apply()[/code] runs inside
## [method GameState.apply_action] (Movement/Combat/BaseProduction) is the
## sole spender (Pass-Through Invariant, ADR-0015 §4) — [method commit] is a
## one-line pass-through, not a second commit path.
##
## [b]Gated by [method is_input_live][/b] (AC-21): if input is not live for
## [member _local_player], this returns a synthesized rejected [ActionResult]
## ([constant Action.Reason.NOT_ACTIVE_PLAYER]) [b]without ever calling
## [method GameState.apply_action][/b] — so an opponent-turn/post-GameOver
## commit attempt provably never reaches the real mutation vector, mirroring
## [method try_select]'s hard no-op.
##
## Callers use the returned [ActionResult] to drive the Tier-4 reaction
## themselves: pass it to [method _on_commit_result] for a unit-bearing
## preview (Move/Attack/Produce) to get the existing swallow-and-re-issue
## reject behavior; a Build commit (no source unit, no Tier-1/2 set to
## re-issue) reads [member ActionResult.ok] directly — there is nothing
## Tier-1/2-shaped to refresh for Build (Move/Attack Tier-1 sets are
## unit-specific; Build's [CommandFSM.BuildEntry] preview is a pure per-call
## query with no held cache to invalidate).
##
## [param action].player is set to [member _local_player] here (the one place
## this class writes onto an [Action] before submission) so every caller
## builds an [Action] without having to remember to stamp the acting player
## itself — mirrors [code]AITurnDriver[/code]'s call sites, which likewise set
## [code]action.player[/code] once before [code]apply_action[/code].
func commit(state: GameState, action: Action) -> ActionResult:
	if not is_input_live(state):
		return ActionResult.new(false, Action.Reason.NOT_ACTIVE_PLAYER, [])
	action.player = _local_player
	var result: ActionResult = state.apply_action(action)
	# Story 008 post-commit convergence (this committing instance). Read directly
	# from [param state] so this is correct even without an [method attach_to_state]
	# subscription; the shared handler independently converges non-committing
	# instances on GAME_OVER.
	if result.ok:
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			_enter_game_over() # AC-34 — terminal overrides any re-selection.
		else:
			_reselect_after_commit(state, action)
	return result


## Post-commit re-selection (Story 008, ADR-0015; AC-25/AC-32/AC-33). After a
## successful, non-terminal commit, lands the interface on the correct entity:
## [br]- A [BuildAction] has no source actor — it lands on the newly-placed
## structure at [member BuildAction.tile] (AC-33).
## [br]- Every other verb re-selects the acting entity ([member _selected_id]).
## [br]The interface stays in [constant CommandFSM.State.ENTITY_SELECTED] (menu
## re-filtered against the now-current AP/`has_attacked`/movement — so a
## move→attack chain flows as one sequence, AC-25) IFF that entity still exists
## AND retains a legal AP-costed action; otherwise it auto-deselects to
## [constant CommandFSM.State.IDLE] — a destroyed actor (dies to a counterattack,
## AC-32) or a fully-spent one collapses cleanly, never a dangling selection.
func _reselect_after_commit(state: GameState, action: Action) -> void:
	var actor: EntityState
	if action is BuildAction:
		actor = state.entity_at(action.tile)
	else:
		actor = state.entities_by_id.get(_selected_id)
	if actor != null and _has_legal_action(state, actor):
		_selected_id = actor.entity_id
		_fsm_state = CommandFSM.State.ENTITY_SELECTED
	else:
		_selected_id = -1
		_fsm_state = CommandFSM.State.IDLE
	_emit_selection(_selected_id, _selected_id != -1) # re-selected actor (pinned) or cleared.
	_render_overlays() # non-preview now → clears the just-committed preview overlay.


## True iff [param entity] has at least one enabled AP-costed verb in its
## [method CommandFSM.menu_model] (any verb but the always-available Wait) —
## the "does a legal action remain?" test that decides ENTITY_SELECTED vs IDLE
## in [method _reselect_after_commit]. Reached only via [CommandFSM]'s queries
## (Pass-Through), never a local re-derivation.
func _has_legal_action(state: GameState, entity: EntityState) -> bool:
	for entry: CommandFSM.VerbEntry in CommandFSM.menu_model(state, entity):
		if entry.verb != CommandFSM.Verb.WAIT and entry.enabled:
			return true
	return false


## Enters the absorbing terminal [constant CommandFSM.State.GAME_OVER] (Story
## 008, TR-cmdui-015): clears any selection and repaints overlays (a non-preview
## state clears them). Idempotent — safe to call from both [method commit] and
## the shared [method _on_action_applied] handler. Once here, [method is_input_live]
## already returns false (match is over), so every later selection/commit trigger
## is inert (AC-34), and [method enter_preview] short-circuits on the state.
func _enter_game_over() -> void:
	_fsm_state = CommandFSM.State.GAME_OVER
	_selected_id = -1
	_emit_selection(-1, false) # terminal — clear the detail-panel target (ADR-0016 §6).
	_render_overlays()


## Tile-change gating (TR-cmdui-005): reads [InputEventMouseMotion] and only
## forwards to [method _on_mouse_moved_to_tile] when the resolved tile
## differs from [member _active_tile] — never per raw motion event. Consumes
## [member _renderer]'s [code]pick_at[/code] exactly like ADR-0015 §3
## specifies; a null [member _renderer] is a defensive no-op (nothing to pick
## against yet, e.g. before the scene's renderer is ready).
func _unhandled_input(event: InputEvent) -> void:
	if _renderer == null:
		return
	if not (event is InputEventMouseMotion):
		return
	var motion: InputEventMouseMotion = event
	var pick: Object = _renderer.pick_at(motion.position)
	var tile: Vector2i = pick.tile
	if tile == _active_tile:
		return
	_on_mouse_moved_to_tile(tile)


## Tier-3 (ADR-0015 §3, TR-cmdui-008): fires on every [member _active_tile]
## change — mouse tile-change (via [method _unhandled_input]) OR a future
## board-cursor move (Story 005). Pure bookkeeping: updates
## [member _active_tile] only. O(1) — issues [b]zero[/b] query calls; the
## actual hover VALUE is read afterward via [method get_reachable_tile]/
## [method get_target]/[method is_after_move_attackable], each an O(1) dict
## lookup against the tiers already held from entry. Directly callable by
## tests (no synthesized [InputEvent] required).
func _on_mouse_moved_to_tile(tile: Vector2i) -> void:
	_active_tile = tile
	_active_locus = Locus.MOUSE


## Board-cursor locus update (Story 005, TR-cmdui-020): a [BoardCursor] step /
## jump moved the grid-space cursor — mirror its [member BoardCursor.grid_pos]
## into [member _active_tile] and claim the active locus. Last-handler-wins with
## NO timestamp comparison, exactly like [method _on_mouse_moved_to_tile]; the
## two handlers race only in the sense that Godot runs whichever input event
## arrived first, and this method simply overwrites — the correct semantics.
func _on_board_locus_moved(cursor: BoardCursor) -> void:
	_active_tile = cursor.grid_pos
	_active_locus = Locus.BOARD_CURSOR


## The input locus that last updated the active tile ([enum Locus]) — read by
## tests/callers to resolve mouse-vs-cursor precedence (Story 005, TR-cmdui-020).
func active_locus() -> Locus:
	return _active_locus


## The last-updated active tile — whichever locus ([method active_locus]) set it
## most recently. [constant _NO_ACTIVE_TILE] until the first input resolves.
func active_tile() -> Vector2i:
	return _active_tile


## Tier-3 O(1) read: the held Tier-1 [ReachableTile] for [param tile], or
## [code]null[/code] if [param tile] is not in the current reachable frontier
## (or no [constant CommandFSM.State.PREVIEW_MOVE] preview is open). Never
## calls [member _reachable_fn].
func get_reachable_tile(tile: Vector2i) -> Movement.ReachableTile:
	return _reachable.get(tile)


## Tier-3 O(1) read: the held Tier-1 [TargetResult] for [param tile], or
## [code]null[/code] if [param tile] has no legal target (or no
## [constant CommandFSM.State.PREVIEW_ATTACK] preview is open). Never calls
## [member _legal_targets_fn].
func get_target(tile: Vector2i) -> Combat.TargetResult:
	return _targets.get(tile)


## Tier-3 O(1) read: the held Tier-2 D-3 marker for [param tile] — true iff
## [param tile] is both reachable and enables a legal, affordable attack from
## it (AC-11). Defaults to [code]false[/code] for any tile not in
## [member _after_move_attackable] (out-of-frontier tiles, or no
## [constant CommandFSM.State.PREVIEW_MOVE] preview open). Never calls
## [member _legal_targets_from_fn].
func is_after_move_attackable(tile: Vector2i) -> bool:
	return _after_move_attackable.get(tile, false)


## Shared Tier-1(+Tier-2) recompute helper — the ONE code path
## [method enter_preview], [method notify_action_applied], and
## [method _on_commit_result]'s reject branch all call, so "re-issue Tier-1"
## is always the literal same recompute, never a second parallel
## implementation (ADR-0015 §3's re-issue requirement). Dispatches on
## [member _fsm_state]:
## [br]- [constant CommandFSM.State.PREVIEW_MOVE]: Tier-1 move set via
## [method _recompute_tier1], then Tier-2 via [method _recompute_tier2].
## [br]- [constant CommandFSM.State.PREVIEW_ATTACK]: Tier-1 attack set via
## [method _recompute_tier1] only (Tier-2 is a Move-only concept, ADR-0015 §3).
## [br]- any other state: no-op (nothing to recompute outside a preview).
## Ends by calling [method _render_overlays] (Story 006, TR-cmdui-016) — so
## every code path that touches Tier-1/2 (entry, board-change re-issue,
## Tier-4 reject re-issue) leaves the painted overlay in sync with whatever it
## just (re)computed, never a second independent "paint the overlay" call site.
func _recompute_tier1_and_2(state: GameState, entity: EntityState) -> void:
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			# Movement's queries are unit-only by construction — structures do not
			# move, and CommandFSM's own Move entry is permanently disabled for them.
			# A structure can still REACH this branch (it is selectable now), so the
			# guard is what keeps a widened selection from reaching a query that has
			# no meaning for it.
			if entity is UnitState:
				_recompute_tier1(state, entity)
				_recompute_tier2(state, entity)
		CommandFSM.State.PREVIEW_ATTACK:
			_recompute_tier1(state, entity) # Combat's queries take any EntityState.
		_:
			pass
	_render_overlays()


## Tier-1 (ADR-0015 §3, TR-cmdui-006): fires [member _reachable_fn] or
## [member _legal_targets_fn] — whichever matches [member _fsm_state] —
## exactly once, and (re)populates the corresponding dict keyed by tile.
## Clears both dicts first so a stale entry from a prior preview/unit can
## never leak into the freshly recomputed set.
func _recompute_tier1(state: GameState, entity: EntityState) -> void:
	_reachable.clear()
	_targets.clear()
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			if not (entity is UnitState):
				return # see _recompute_tier1_and_2's guard.
			var tiles: Array[Movement.ReachableTile] = _reachable_fn.call(state, entity)
			for r: Movement.ReachableTile in tiles:
				_reachable[r.tile] = r
		CommandFSM.State.PREVIEW_ATTACK:
			var results: Array[Combat.TargetResult] = _legal_targets_fn.call(state, entity)
			for t: Combat.TargetResult in results:
				_targets[t.tile] = t


## Tier-2 (ADR-0015 §3, TR-cmdui-007, AC-11): batches
## [member _legal_targets_from_fn] across every tile in the just-computed
## [member _reachable] frontier, once, and populates
## [member _after_move_attackable]'s D-3 marker for each. A tile qualifies
## (AC-11's worked example: ap=9, a tile costing 3 with an enemy in range from
## it, attack_cost 2 -> 3+2=5<=9 -> marked) iff it has >=1 legal target from
## it AND [code]reachable[tile].min_cost + attack_cost_for(unit) <=
## current_ap[/code] — both conjuncts evaluated fresh per tile, never
## inferred from the tile's own [code]is_surcharged[/code] flag (that flag
## answers a different question, ADR-0015 §5's Movement bullet). Reads
## [method AP.current_ap] live (not a preview-entry snapshot) so a re-issue
## after a board/AP change reflects the CURRENT pool, consistent with every
## other Tier-1/2 value being a live query return (Pass-Through Invariant).
## Clears [member _after_move_attackable] first so a stale marker from a
## prior preview/unit never survives a re-issue for a differently-priced
## unit.
func _recompute_tier2(state: GameState, unit: UnitState) -> void:
	_after_move_attackable.clear()
	var attack_cost: int = _attack_cost_fn.call(unit)
	var current_ap: int = AP.current_ap(state, unit.owner)
	for tile: Vector2i in _reachable.keys():
		var r: Movement.ReachableTile = _reachable[tile]
		var targets_from_tile: Array[Combat.TargetResult] = _legal_targets_from_fn.call(state, unit, tile)
		var has_target: bool = not targets_from_tile.is_empty()
		var affordable: bool = r.min_cost + attack_cost <= current_ap
		_after_move_attackable[tile] = has_target and affordable


## True iff [param s] is a preview state Tier-1/2 recompute applies to
## ([constant CommandFSM.State.PREVIEW_MOVE] or
## [constant CommandFSM.State.PREVIEW_ATTACK]) — [constant CommandFSM.State.PREVIEW_PRODUCE]/
## [constant CommandFSM.State.PREVIEW_BUILD] are out of this story's tier
## scope (no [code]reachable()[/code]/[code]legal_targets()[/code] concept;
## Base & Production's own preview queries are Story 003's consumption-wiring
## concern, not a fourth tier family here).
func _is_preview_state(s: CommandFSM.State) -> bool:
	return s == CommandFSM.State.PREVIEW_MOVE or s == CommandFSM.State.PREVIEW_ATTACK


## Story 006 click-routing entry point (TR-cmdui-003/004, ADR-0013 §4):
## consumes [member _renderer]'s [code]pick_at(screen_pos)[/code] as the
## [i]one[/i] click-routing entry point — never [code]screen_to_grid[/code] —
## and, when the pick resolves to an own [UnitState] occupant while
## [method is_input_live] holds, routes the occupant-priority selection
## through [method try_select] exactly like any other selection trigger (no
## bespoke second selection path). Always returns the raw pick result so a
## caller (or a test) can inspect what tile/occupant the click actually
## resolved to regardless of whether a selection happened.
##
## [b]Deliberately does not build or commit an [Action][/b] — a click landing
## inside an open preview (e.g. on a reachable tile) is Story 007's
## action-build + [code]INPUT_LOCK_MS[/code] commit-dispatch scope, not this
## story's. This method resolves the picked tile/occupant and, at most,
## changes selection; nothing here ever calls [method commit].
##
## No-op selection (but the pick still resolves and is still returned) when
## any of: input is not live, no occupant was hit
## ([code]occupant_entity_id == -1[/code]), the occupant is not owned by
## [member _local_player], or the occupant is not a [UnitState] (a structure
## occupant has no [method try_select] path — [method try_select]'s own
## signature is [UnitState]-only, mirroring every other call site in this
## class). [member _renderer] is assumed non-null by callers that reach this
## method directly (mirrors [method _unhandled_input]'s own null-guard
## responsibility sitting at the engine-glue call site, not duplicated here).
func route_click(screen_pos: Vector2, state: GameState) -> Object:
	var pick: Object = _renderer.pick_at(screen_pos)
	if not is_input_live(state):
		return pick
	if pick.occupant_entity_id == -1:
		return pick
	var entity: EntityState = state.entities_by_id.get(pick.occupant_entity_id)
	if entity == null or entity.owner != _local_player:
		return pick
	if not (entity is UnitState):
		return pick
	try_select(state, entity)
	return pick


# NOTE (Story 006 → 007): click routing lives in [method route_click] above —
# the tested, directly-callable entry point (mirroring [method _on_mouse_moved_to_tile]).
# [method _unhandled_input] is NOT extended to InputEventMouseButton here: this
# Node holds no persistent GameState (state is passed per call), so a live
# button handler has nothing to route against until the scene feeds it a state —
# that wiring is Story 007's / the scene's job. route_click is the complete
# TR-cmdui-003/004 routing logic today; only its engine-input trigger is deferred.


## Glyph anchoring (TR-cmdui-017, ADR-0013 §5): pure delegation to
## [method BoardRenderer.glyph_anchor] — the sanctioned
## [code]grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class][/code] anchor
## convention is computed exactly once, on [BoardRenderer], and never
## re-derived here. [param glyph_class] is a plain [code]int[/code] mirroring
## [method BoardRenderer.glyph_anchor]'s own signature; pass one of
## [enum BoardRenderer.GlyphClass]'s named values. The hp-pip-never-occluded
## priority (game-hud.md CR-5/TR-hud-011) is offset-table authoring
## discipline living entirely in [GlyphOffsets] — not re-enforced by this
## pass-through. O(1).
func glyph_anchor(tile: Vector2i, glyph_class: int) -> Vector2:
	return _renderer.glyph_anchor(tile, glyph_class)


## Overlay rendering (TR-cmdui-016, ADR-0013 §3; AC-29/AC-30 wiring): the
## [i]sole[/i] call site of [method BoardRenderer.set_overlays]/
## [method BoardRenderer.clear_overlay] in this class — reached only from the
## end of [method _recompute_tier1_and_2], so a stale overlay from a prior
## preview/tile-set can never linger past the recompute that should have
## replaced it. A null [member _renderer] is a defensive no-op (nothing to
## paint against yet, mirrors [method _unhandled_input]'s own null-guard).
##
## Dispatches on [member _fsm_state]:
## [br]- [constant CommandFSM.State.PREVIEW_MOVE]: splits [member _reachable]
## by [member Movement.ReachableTile.is_surcharged] into
## [constant BoardRenderer.OverlayClass.MOVE_IN_CAP] (false) /
## [constant BoardRenderer.OverlayClass.MOVE_OVER_CAP] (true), and marks every
## tile [method is_after_move_attackable] returns true for as
## [constant BoardRenderer.OverlayClass.AFTER_MOVE_ECHO] (the D-3 echo) — all
## three classes painted in [b]one[/b] [method BoardRenderer.set_overlays]
## call so they coexist (AC-29 requires in-cap AND over-cap visible
## together; [method BoardRenderer.set_overlay]'s single-class contract would
## clear between classes, which is exactly why [method BoardRenderer.set_overlays]
## exists). AC-30 falls out for free here with no extra logic: whatever
## [member _reachable] currently holds (a re-issued, possibly-shrunk set when
## [code]tiles_moved_this_turn > 0[/code], per Story 002's Tier-1 recompute)
## is exactly what gets painted — never a second, independently-tracked
## "full-AP" set.
## [br]- [constant CommandFSM.State.PREVIEW_ATTACK]: every [member _targets]
## tile as [constant BoardRenderer.OverlayClass.ATTACK_TARGET]. The finer
## blocked-by-friendly / out-of-range / AREA-dead-zone split named in AC-28
## is the Visual/advisory portion of this taxonomy (art bible / Story 009) —
## a single [constant BoardRenderer.OverlayClass.ATTACK_TARGET] class is
## sufficient for this story's automated wiring.
## [br]- any other state (IDLE, ENTITY_SELECTED, PREVIEW_PRODUCE,
## PREVIEW_BUILD, GAME_OVER): [method BoardRenderer.clear_overlay] — no
## overlay belongs on the board outside an open Move/Attack preview.
## The tiles the board cursor may jump between right now — the "salient tile set"
## ADR-0014's [method BoardCursor.jump_to_next] is defined against.
##
## ★ Keyed on the SAME [enum CommandFSM.State] switch [method _render_overlays]
## uses, deliberately: the set a player can cycle through must be exactly the set
## that is highlighted on screen. Deriving them separately would let the two drift,
## and a jump landing on an unhighlighted tile — or skipping a highlighted one — is
## the kind of thing a player reads as the game being broken rather than as two
## code paths disagreeing.
##
## Empty outside a preview, which makes cursor-jump a no-op there rather than an
## error (see [method BoardCursor.jump_to_next]'s empty-candidates contract).
func salient_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			for tile: Vector2i in _reachable:
				out.append(tile)
		CommandFSM.State.PREVIEW_ATTACK:
			for tile: Vector2i in _targets:
				out.append(tile)
	return out


func _render_overlays() -> void:
	if _renderer == null:
		return
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			var in_cap: Array[Vector2i] = []
			var over_cap: Array[Vector2i] = []
			var echo: Array[Vector2i] = []
			for tile: Vector2i in _reachable:
				var r: Movement.ReachableTile = _reachable[tile]
				if r.is_surcharged:
					over_cap.append(tile)
				else:
					in_cap.append(tile)
				if is_after_move_attackable(tile):
					echo.append(tile)
			_renderer.set_overlays({
				BoardRenderer.OverlayClass.MOVE_IN_CAP: in_cap,
				BoardRenderer.OverlayClass.MOVE_OVER_CAP: over_cap,
				BoardRenderer.OverlayClass.AFTER_MOVE_ECHO: echo,
			})
		CommandFSM.State.PREVIEW_ATTACK:
			var targets: Array[Vector2i] = []
			for tile: Vector2i in _targets:
				targets.append(tile)
			_renderer.set_overlays({
				BoardRenderer.OverlayClass.ATTACK_TARGET: targets,
			})
		_:
			_renderer.clear_overlay()
