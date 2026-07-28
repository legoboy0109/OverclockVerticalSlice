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
## [b]This story (Story 002) ships the four-tier recompute discipline only[/b]
## — [i]when[/i] each tier's queries fire, and the O(1) hover-read contract.
## Deliberately [b]out of scope[/b] (see the story's Out of Scope section):
## real [code]pick_at[/code]/[code]screen_to_grid[/code] iso-picking math
## (Board Renderer, consumed only), [code]BoardCursor[/code] tile-stepping
## (Story 005), and the full commit dispatch / [code]input_locked[/code]
## debounce / shared [signal GameState.action_applied] emit wiring
## (Story 007) — [method _on_commit_result] here is only the Tier-4
## [code]ActionResult.ok[/code] re-validation-reaction contract, not the
## dispatcher itself.
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
func enter_preview(state: GameState, unit: UnitState, target_state: CommandFSM.State) -> void:
	_selected_id = unit.entity_id
	var trigger: CommandFSM.Trigger = CommandFSM.Trigger.PICK_MOVE \
		if target_state == CommandFSM.State.PREVIEW_MOVE else CommandFSM.Trigger.PICK_ATTACK
	_fsm_state = CommandFSM.next_state(CommandFSM.State.ENTITY_SELECTED, trigger, state)
	_recompute_tier1_and_2(state, unit)


## Board-change re-issue hook (ADR-0015 §3, AC-19): call whenever
## [signal GameState.action_applied] fires while a preview is open. Re-issues
## the [b]exact same[/b] Tier-1 (+Tier-2) recompute [method enter_preview]
## uses — never a bespoke second code path — satisfying "the reachable
## overlay reflects the new board state... no reselect trick." A no-op if no
## preview is currently open (Tier-1/2 have nothing to refresh outside
## [constant CommandFSM.State.PREVIEW_MOVE]/[constant CommandFSM.State.PREVIEW_ATTACK]).
func notify_action_applied(state: GameState, unit: UnitState) -> void:
	if not _is_preview_state(_fsm_state):
		return
	_recompute_tier1_and_2(state, unit)


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
func _on_commit_result(result: ActionResult, state: GameState, unit: UnitState) -> void:
	if result.ok:
		return
	_recompute_tier1_and_2(state, unit)


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
func _recompute_tier1_and_2(state: GameState, unit: UnitState) -> void:
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			_recompute_tier1(state, unit)
			_recompute_tier2(state, unit)
		CommandFSM.State.PREVIEW_ATTACK:
			_recompute_tier1(state, unit)
		_:
			pass


## Tier-1 (ADR-0015 §3, TR-cmdui-006): fires [member _reachable_fn] or
## [member _legal_targets_fn] — whichever matches [member _fsm_state] —
## exactly once, and (re)populates the corresponding dict keyed by tile.
## Clears both dicts first so a stale entry from a prior preview/unit can
## never leak into the freshly recomputed set.
func _recompute_tier1(state: GameState, unit: UnitState) -> void:
	_reachable.clear()
	_targets.clear()
	match _fsm_state:
		CommandFSM.State.PREVIEW_MOVE:
			var tiles: Array[Movement.ReachableTile] = _reachable_fn.call(state, unit)
			for r: Movement.ReachableTile in tiles:
				_reachable[r.tile] = r
		CommandFSM.State.PREVIEW_ATTACK:
			var results: Array[Combat.TargetResult] = _legal_targets_fn.call(state, unit)
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
