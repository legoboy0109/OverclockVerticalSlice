# Story 002: Four-Tier Recompute Discipline (Tier 1-4).
#
# Covers production/epics/command-action-interface/story-002-four-tier-recompute.md
# (TR-cmdui-005/006/007/008/009, ADR-0015 §3):
#
#   AC (Tier-1): reachable()/legal_targets() fire exactly once at preview
#     entry; a board-change (action_applied) re-issue while a preview is open
#     fires exactly one additional call, never per-hover.
#   AC (Tier-2): legal_targets_from fires exactly once, batched across the
#     whole reachable frontier, per PREVIEW_MOVE entry/re-issue - not per
#     tile/hover.
#   AC (Tier-3): a hover sweep across ~10 frontier tiles issues ZERO further
#     reachable()/legal_targets() calls - O(1) dict reads only.
#   AC-19: action_applied mid-preview triggers exactly one Tier-1 re-issue
#     before the next hover read.
#   AC-20/Tier-4: a rejecting apply_action result leaves current_ap unchanged,
#     FSM stays in the menu (preview state unchanged), _reachable refreshed.
#   AC-11: the D-3 "attack-possible-after-move" marker worked example -
#     ap=9, Scout, a 3-cost reachable tile with a target in range from it
#     (attack_cost 2, 3+2=5<=9) is marked; a reachable tile with no target is
#     not; an 8-cost tile (8+2=10>9) is not.
#
# Deterministic: no RNG, no time-dependent assertions, no external I/O.
# Fixtures pin both players' faction to Factions.NEUTRAL so
# Unit.effective_produce_cost/any effective_* fold is a no-op, mirroring
# command_fsm_test.gd's and the base-production test suite's own convention.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Spy helpers --------------------------------------------------------------

## Wraps a query [Callable], counting every invocation and forwarding the
## call through unchanged - lets a test assert exact call counts (Tier-1/2's
## "exactly once" ACs) without touching the real Movement/Combat statics'
## own internals.
class _CallSpy extends RefCounted:
	var call_count: int = 0
	var _wrapped: Callable

	func _init(wrapped: Callable) -> void:
		_wrapped = wrapped

	func call_2(a, b):
		call_count += 1
		return _wrapped.call(a, b)

	func call_3(a, b, c):
		call_count += 1
		return _wrapped.call(a, b, c)

	func call_1(a):
		call_count += 1
		return _wrapped.call(a)


## Minimal duck-typed picking source (mirrors [BoardRenderer.PickResult]'s
## shape - a [code]tile: Vector2i[/code] field only) so tests never depend on
## the Board Renderer's own class (this story consumes [code]pick_at[/code],
## it does not implement it).
class _PickResultStub extends RefCounted:
	var tile: Vector2i

	func _init(t: Vector2i) -> void:
		tile = t


class _RendererStub extends RefCounted:
	var next_tile: Vector2i = Vector2i.ZERO

	func pick_at(_screen_pos: Vector2) -> _PickResultStub:
		return _PickResultStub.new(next_tile)


# --- Fixture helpers ------------------------------------------------------------

func _make_blank_grid(size: int = 10) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.grid = _make_blank_grid()
	# Pin both players to Neutral so any effective_* balance fold is a no-op
	# (== base) - mirrors command_fsm_test.gd's fixture convention.
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type(move_cost: int = 1, soft_move_cap: int = 8, attack_range: int = 1, \
		hp: int = 10, attack: int = 3) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestScout"
	type.hp = hp
	type.attack = attack
	type.attack_range = attack_range
	type.move_cost = move_cost
	type.soft_move_cap = soft_move_cap
	type.produce_cost = 4
	return type


func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	state.entities_by_id[entity_id] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return unit


# ==============================================================================
# Tier-1: exactly once on entry.
# ==============================================================================

func test_tier1_reachable_fires_exactly_once_on_preview_move_entry() -> void:
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var spy := _CallSpy.new(Movement.reachable)
	iface.configure_dependencies(spy.call_2)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	assert_int(spy.call_count).is_equal(1)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.PREVIEW_MOVE)


func test_tier1_legal_targets_fires_exactly_once_on_preview_attack_entry() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 3)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	var enemy_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 6), enemy_type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var spy := _CallSpy.new(Combat.legal_targets)
	iface.configure_dependencies(Movement.reachable, spy.call_2)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_ATTACK)

	assert_int(spy.call_count).is_equal(1)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.PREVIEW_ATTACK)


# ==============================================================================
# Tier-2: legal_targets_from batched exactly once per PREVIEW_MOVE entry.
# ==============================================================================

func test_tier2_legal_targets_from_called_exactly_once_batched_per_entry() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	var enemy_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 2), enemy_type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var spy := _CallSpy.new(Combat.legal_targets_from)
	iface.configure_dependencies(Movement.reachable, Combat.legal_targets, spy.call_3)

	var count_after_entry: int = spy.call_count

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	# legal_targets_from is invoked once per reachable tile, all within this
	# single enter_preview call - the precise "exactly N == frontier size, in
	# one batched pass" proof lives in the worked-example test below; this
	# test's job is just to confirm the batch actually ran (non-zero) and
	# didn't run before enter_preview was called.
	assert_int(count_after_entry).is_equal(0)
	assert_int(spy.call_count).is_greater(0)


func test_tier2_legal_targets_from_not_recalled_on_second_entry_of_same_kind_without_reissue() -> void:
	# A second, independent PREVIEW_ATTACK entry between two PREVIEW_MOVE
	# entries must not itself trigger a Tier-2 batch (Tier-2 is
	# PREVIEW_MOVE-only) - guards against a naive implementation that batches
	# on every _recompute_tier1_and_2 call regardless of state.
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 3)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var spy := _CallSpy.new(Combat.legal_targets_from)
	iface.configure_dependencies(Movement.reachable, Combat.legal_targets, spy.call_3)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_ATTACK)

	assert_int(spy.call_count).is_equal(0)


func test_tier2_batched_exactly_once_worked_example_frontier_count() -> void:
	# Precise batching proof: legal_targets_from is called exactly once PER
	# TILE in the just-computed Movement.reachable() frontier - no more (a
	# second redundant scan), no less (a tile silently skipped) - all within
	# ONE enter_preview call. The frontier size is read directly from the
	# real, unwrapped Movement.reachable() (rather than hand-computing the
	# BFS geometry, which also depends on the AP-bounded, not
	# soft-cap-clipped, termination Movement.reachable actually uses) so this
	# test's expected count can never drift from the query's own real
	# contract.
	var state := _make_state(0)
	var type := _make_unit_type(1, 2, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10
	var expected_frontier_size: int = Movement.reachable(state, unit).size()
	assert_int(expected_frontier_size).is_greater(0) # sanity - fixture actually has a frontier.

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var spy := _CallSpy.new(Combat.legal_targets_from)
	iface.configure_dependencies(Movement.reachable, Combat.legal_targets, spy.call_3)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	assert_int(spy.call_count).is_equal(expected_frontier_size)


# ==============================================================================
# Tier-3: hover sweep issues ZERO further reachable()/legal_targets() calls -
# O(1) dict reads only.
# ==============================================================================

func test_tier3_hover_sweep_of_ten_frontier_tiles_adds_zero_further_queries() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var reachable_spy := _CallSpy.new(Movement.reachable)
	var legal_targets_spy := _CallSpy.new(Combat.legal_targets)
	var legal_targets_from_spy := _CallSpy.new(Combat.legal_targets_from)
	iface.configure_dependencies(reachable_spy.call_2, legal_targets_spy.call_2, legal_targets_from_spy.call_3)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	var reachable_after_entry: int = reachable_spy.call_count
	var legal_targets_after_entry: int = legal_targets_spy.call_count
	var legal_targets_from_after_entry: int = legal_targets_from_spy.call_count

	# Sweep 10 distinct frontier tiles (Manhattan distance 1 or 2 - all
	# reachable at move_cost=1, soft_move_cap=8).
	var frontier_tiles: Array[Vector2i] = [
		Vector2i(6, 5), Vector2i(4, 5), Vector2i(5, 6), Vector2i(5, 4),
		Vector2i(7, 5), Vector2i(3, 5), Vector2i(5, 7), Vector2i(5, 3),
		Vector2i(6, 6), Vector2i(4, 4),
	]
	for tile: Vector2i in frontier_tiles:
		iface._on_mouse_moved_to_tile(tile)
		# Tier-3 O(1) reads - must never call a query.
		iface.get_reachable_tile(tile)
		iface.get_target(tile)
		iface.is_after_move_attackable(tile)

	assert_int(reachable_spy.call_count).is_equal(reachable_after_entry)
	assert_int(legal_targets_spy.call_count).is_equal(legal_targets_after_entry)
	assert_int(legal_targets_from_spy.call_count).is_equal(legal_targets_from_after_entry)


func test_tier3_active_tile_updates_on_hover() -> void:
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface._on_mouse_moved_to_tile(Vector2i(3, 4))
	assert_vector(iface._active_tile).is_equal(Vector2i(3, 4))


# ==============================================================================
# AC-19: action_applied mid-preview triggers exactly one Tier-1 re-issue
# before the next hover read.
# ==============================================================================

func test_ac19_action_applied_mid_preview_triggers_exactly_one_tier1_reissue() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var reachable_spy := _CallSpy.new(Movement.reachable)
	iface.configure_dependencies(reachable_spy.call_2)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	assert_int(reachable_spy.call_count).is_equal(1)

	# A blocker died mid-preview (a committed attack removed it, changing the
	# board) - action_applied fires.
	iface.notify_action_applied(state, unit)
	assert_int(reachable_spy.call_count).is_equal(2)

	# The next hover read must be a pure O(1) dict lookup against the
	# freshly-reissued set - no additional query call.
	iface._on_mouse_moved_to_tile(Vector2i(6, 5))
	iface.get_reachable_tile(Vector2i(6, 5))
	assert_int(reachable_spy.call_count).is_equal(2)


func test_ac19_action_applied_with_no_preview_open_is_a_noop() -> void:
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var reachable_spy := _CallSpy.new(Movement.reachable)
	iface.configure_dependencies(reachable_spy.call_2)

	# No enter_preview call - FSM sits at IDLE.
	iface.notify_action_applied(state, unit)

	assert_int(reachable_spy.call_count).is_equal(0)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.IDLE)


# ==============================================================================
# AC-20 / Tier-4: rejecting apply_action result leaves current_ap unchanged,
# FSM stays in the menu (preview unchanged), _reachable refreshed.
# ==============================================================================

func test_ac20_tier4_reject_leaves_ap_unchanged_stays_in_preview_refreshes_reachable() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var reachable_spy := _CallSpy.new(Movement.reachable)
	iface.configure_dependencies(reachable_spy.call_2)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	assert_int(reachable_spy.call_count).is_equal(1)

	var ap_before: int = state.per_player[0].current_ap
	var rejecting_result := ActionResult.new(false, Action.Reason.CANT_AFFORD, [])

	iface._on_commit_result(rejecting_result, state, unit)

	# 0 AP spent - this Node never deducts AP anywhere in the reject path.
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	# FSM stays in the same preview menu, never transitions on a reject.
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.PREVIEW_MOVE)
	# _reachable was refreshed via exactly one additional Tier-1 call.
	assert_int(reachable_spy.call_count).is_equal(2)


func test_ac20_tier4_accept_does_not_reissue_tier1() -> void:
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	var reachable_spy := _CallSpy.new(Movement.reachable)
	iface.configure_dependencies(reachable_spy.call_2)

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	assert_int(reachable_spy.call_count).is_equal(1)

	var accepting_result := ActionResult.new(true, Action.Reason.OK, [])
	iface._on_commit_result(accepting_result, state, unit)

	assert_int(reachable_spy.call_count).is_equal(1)


# ==============================================================================
# AC-11: D-3 "attack-possible-after-move" marker worked example.
# ap=9, Scout, reachable tile costing 3 with a legal target in range from it
# (attack_cost=2) -> 3+2=5<=9 -> marked. A reachable tile with no target in
# range, and an 8-cost tile, do not.
# ==============================================================================

func test_ac11_d3_marker_worked_example_marks_only_the_affordable_tile_with_a_target() -> void:
	var state := _make_state(0)
	# Scout: move_cost=1 so distance == AP cost (tile at distance 3 costs 3,
	# tile at distance 8 costs 8); soft_move_cap=20 keeps BOTH tiles in-cap so
	# neither is surcharged (a cap of 8 would surcharge the distance-8 move and
	# push it past ap=9 out of the frontier); attack_range=1 so the enemy must
	# be adjacent to the marked tile to be "in range from it".
	var scout_type := _make_unit_type(1, 20, 1)
	var scout := _place_unit(state, 1, 0, Vector2i(0, 0), scout_type)
	state.per_player[0].current_ap = 9

	# The 3-cost tile: Vector2i(3, 0), Manhattan distance 3 from (0,0).
	var marked_tile := Vector2i(3, 0)
	# An enemy adjacent to marked_tile (Manhattan 1, attack_range=1) so
	# legal_targets_from(marked_tile) is non-empty. Placed SOUTH of it at (3,1),
	# NOT east at (4,0): an enemy unit is a hard movement blocker, and one on
	# the row-0 east path would force the scout to detour around it to reach the
	# 8-cost tile (8,0), pushing that tile's true path cost to 10 > ap=9 and out
	# of the frontier. (3,1) keeps the marked tile targetable while leaving the
	# straight-line path to (8,0) clear.
	var enemy_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(3, 1), enemy_type)

	# The no-target reachable tile: Vector2i(0, 3), Manhattan distance 3 -
	# same cost, but no enemy adjacent to it.
	var no_target_tile := Vector2i(0, 3)

	# The 8-cost tile: Vector2i(8, 0), Manhattan distance 8 -> cost 8;
	# 8 + attack_cost_for(scout) must exceed ap=9, i.e. attack_cost_for must
	# be >= 2 for this worked example to hold (CombatBalance's real
	# attack_cost is used here via the default _attack_cost_fn - asserted
	# below to be exactly 2, matching the story's own worked numbers).
	var expensive_tile := Vector2i(8, 0)
	# No enemy needed near expensive_tile - it must be excluded on
	# affordability alone, regardless of target presence, so leave it
	# target-free too (both conjuncts fail, still correctly unmarked).

	var iface: CommandInterface = auto_free(CommandInterface.new())
	# Use the REAL Combat.attack_cost_for (unwrapped) to prove the worked
	# example holds against the actual production cost, per the story text's
	# literal "attack_cost 2" example.
	assert_int(Combat.attack_cost_for(scout)).is_equal(2)

	iface.enter_preview(state, scout, CommandFSM.State.PREVIEW_MOVE)

	assert_bool(iface.is_after_move_attackable(marked_tile)).is_true()
	assert_bool(iface.is_after_move_attackable(no_target_tile)).is_false()
	assert_bool(iface.is_after_move_attackable(expensive_tile)).is_false()

	# Sanity: all three tiles are indeed in the reachable frontier at the
	# expected costs (proves the "unmarked" results are due to the D-3 gate,
	# not simply being unreachable).
	assert_int(iface.get_reachable_tile(marked_tile).min_cost).is_equal(3)
	assert_int(iface.get_reachable_tile(no_target_tile).min_cost).is_equal(3)
	assert_int(iface.get_reachable_tile(expensive_tile).min_cost).is_equal(8)


# ==============================================================================
# TR-cmdui-005 tile-change gating (_unhandled_input) — the "Required" control-
# manifest rule. A CommandInterface subclass counts _on_mouse_moved_to_tile
# forwards, so the gate ("act only on a NEW tile, never per raw motion event")
# is provable without a public _active_tile accessor.
# ==============================================================================

class _SpyInterface extends CommandInterface:
	var moved_count: int = 0
	var last_tile: Vector2i = Vector2i(-999, -999)

	func _on_mouse_moved_to_tile(tile: Vector2i) -> void:
		moved_count += 1
		last_tile = tile
		super._on_mouse_moved_to_tile(tile)


func _mouse_motion() -> InputEventMouseMotion:
	var m := InputEventMouseMotion.new()
	m.position = Vector2(1, 1) # ignored by _RendererStub; its next_tile decides the resolved tile.
	return m


func test_unhandled_input_forwards_to_on_mouse_moved_only_on_a_new_tile() -> void:
	var iface: _SpyInterface = auto_free(_SpyInterface.new())
	var renderer := _RendererStub.new()
	iface._renderer = renderer

	renderer.next_tile = Vector2i(2, 2)
	iface._unhandled_input(_mouse_motion())
	assert_int(iface.moved_count).is_equal(1)
	assert_object(iface.last_tile).is_equal(Vector2i(2, 2))

	# Same tile resolved again -> gated, no forward.
	iface._unhandled_input(_mouse_motion())
	assert_int(iface.moved_count).is_equal(1)

	# A different tile -> forwards again.
	renderer.next_tile = Vector2i(3, 3)
	iface._unhandled_input(_mouse_motion())
	assert_int(iface.moved_count).is_equal(2)
	assert_object(iface.last_tile).is_equal(Vector2i(3, 3))

	# A non-motion event -> ignored (renderer non-null, so control reaches the
	# event-type gate and returns before touching the tile).
	iface._unhandled_input(InputEventKey.new())
	assert_int(iface.moved_count).is_equal(2)


func test_unhandled_input_null_renderer_is_a_noop() -> void:
	var iface: _SpyInterface = auto_free(_SpyInterface.new())
	# _renderer defaults to null — a motion event is swallowed (defensive no-op
	# before the scene's renderer is wired), never a crash or a forward.
	iface._unhandled_input(_mouse_motion())
	assert_int(iface.moved_count).is_equal(0)


# ==============================================================================
# Dict-clear-on-reissue: _recompute_tier1/2 clear their held sets first, so a
# stale tile from a prior (wider) frontier can never leak into a re-issue for a
# now-narrower one. A merge-instead-of-clear regression would pass every other
# test - this is the one that catches it.
# ==============================================================================

func test_reissue_clears_stale_frontier_entries_no_leak() -> void:
	var state := _make_state(0)
	var type := _make_unit_type() # move_cost 1
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 8 # wide frontier

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	var far_tile := Vector2i(8, 5) # distance 3, reachable at ap=8
	assert_object(iface.get_reachable_tile(far_tile)).is_not_null()

	# Shrink AP and re-issue (board-change): the far tile's path now exceeds the
	# pool, so it must be GONE from the recomputed set, not lingering from before.
	state.per_player[0].current_ap = 1
	iface.notify_action_applied(state, unit)
	assert_object(iface.get_reachable_tile(far_tile)).is_null()
	# A distance-1 tile is still reachable at ap=1 - proves the set was recomputed,
	# not merely emptied.
	assert_object(iface.get_reachable_tile(Vector2i(6, 5))).is_not_null()


# ==============================================================================
# PREVIEW_ATTACK entry computes Tier-1 only - Tier-2's _after_move_attackable is
# a Move-only concept and must stay unset (data-level proof complementing the
# call-count proof above).
# ==============================================================================

func test_preview_attack_entry_leaves_after_move_attackable_unset() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 3) # attack_range 3
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	var enemy_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 6), enemy_type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_ATTACK)

	assert_bool(iface.is_after_move_attackable(Vector2i(5, 6))).is_false()
	assert_bool(iface.is_after_move_attackable(Vector2i(5, 5))).is_false()


# ==============================================================================
# Tier-3 O(1) reads never fabricate: an out-of-frontier tile reads back as
# null / default-false, never a queried or invented value.
# ==============================================================================

func test_tier3_reads_return_null_default_for_out_of_frontier_tile() -> void:
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 2 # small frontier

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	var far := Vector2i(0, 0) # distance 10 - far outside a 2-AP frontier
	assert_object(iface.get_reachable_tile(far)).is_null()
	assert_bool(iface.is_after_move_attackable(far)).is_false()
