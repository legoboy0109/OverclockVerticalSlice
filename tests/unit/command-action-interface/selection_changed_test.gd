# Cross-epic addendum (resolves ADR-0016 §6 forward-declaration): CommandInterface
# emits selection_changed(target: SelectionTarget) — the outward-in seam the Game
# HUD detail panel (hud-006) subscribes to (TR-hud-013).
#
# Covers:
#   - PINNED emission on selection (try_select) and selection switch.
#   - PEEK emission on inspect() over an occupied tile (pinned == false).
#   - inspect() over an empty tile falls back to the pinned selection (or a
#     cleared -1 target when nothing is selected).
#   - De-duplication: re-asserting the same (entity_id, pinned) target is a no-op.
#   - inspect() is NOT input-gated — inspection works on the opponent's turn.
#   - GAME_OVER convergence clears the target (-1, false).
#
# Deterministic: no RNG, no time-dependent assertions, no external I/O.
# Fixtures pin both players to Factions.NEUTRAL (mirrors recompute_tiers_test.gd).
extends GdUnitTestSuite


# --- Fixture helpers ---------------------------------------------------------

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
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestScout"
	type.hp = 10
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 8
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


## Builds an interface with a captured-target list wired to selection_changed.
## Returns [iface, captured] — captured is an Array of SelectionTarget in emit
## order (Array is a reference type, so the lambda append is visible here).
func _iface_with_capture(local_player: int = 0) -> Array:
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(local_player)
	var captured: Array = []
	iface.selection_changed.connect(func(t: SelectionTarget) -> void: captured.append(t))
	return [iface, captured]


# ==============================================================================
# PINNED selection.
# ==============================================================================

func test_try_select_emits_pinned_target() -> void:
	# Arrange
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	# Act
	var selected: bool = iface.try_select(state, unit)

	# Assert
	assert_bool(selected).is_true()
	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0].entity_id).is_equal(1)
	assert_bool(captured[0].pinned).is_true()


func test_switching_selection_emits_the_new_pinned_target() -> void:
	var state := _make_state(0)
	var a := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	var b := _place_unit(state, 2, 0, Vector2i(6, 6), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.try_select(state, a)
	iface.try_select(state, b)

	assert_int(captured.size()).is_equal(2)
	assert_int(captured[1].entity_id).is_equal(2)
	assert_bool(captured[1].pinned).is_true()


func test_try_select_on_opponent_turn_emits_nothing() -> void:
	# is_input_live is false on the opponent's turn, so try_select is a hard
	# no-op and no selection target is emitted.
	var state := _make_state(1) # active_player 1, local 0 -> not live.
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	var selected: bool = iface.try_select(state, unit)

	assert_bool(selected).is_false()
	assert_int(captured.size()).is_equal(0)


# ==============================================================================
# PEEK (inspect).
# ==============================================================================

func test_inspect_occupied_tile_emits_peek_target() -> void:
	var state := _make_state(0)
	_place_unit(state, 7, 1, Vector2i(3, 4), _make_unit_type()) # an enemy unit.
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.inspect(state, Vector2i(3, 4))

	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0].entity_id).is_equal(7)
	assert_bool(captured[0].pinned).is_false() # peek, not pinned.


func test_inspect_empty_tile_falls_back_to_pinned_selection() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.try_select(state, unit) # captured[0] = pinned(1)
	iface.inspect(state, Vector2i(9, 9)) # empty -> fall back to pinned selection.

	# The fallback target equals the pinned selection, so it de-dups to a no-op:
	# still exactly the one pinned emission, and the last target is pinned(1).
	assert_int(captured.size()).is_equal(1)
	assert_int(captured[captured.size() - 1].entity_id).is_equal(1)
	assert_bool(captured[captured.size() - 1].pinned).is_true()


func test_inspect_empty_tile_with_no_selection_emits_cleared_target() -> void:
	var state := _make_state(0)
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.inspect(state, Vector2i(9, 9)) # empty, nothing selected -> cleared.

	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0].entity_id).is_equal(-1)
	assert_bool(captured[0].pinned).is_false()


func test_inspect_is_not_input_gated_peeks_on_opponent_turn() -> void:
	# inspection is read-only and must work even when input is not live.
	var state := _make_state(1) # opponent's turn.
	_place_unit(state, 7, 1, Vector2i(3, 4), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.inspect(state, Vector2i(3, 4))

	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0].entity_id).is_equal(7)
	assert_bool(captured[0].pinned).is_false()


# ==============================================================================
# De-duplication.
# ==============================================================================

func test_selection_changed_is_deduplicated_for_same_target() -> void:
	var state := _make_state(0)
	_place_unit(state, 7, 1, Vector2i(3, 4), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.inspect(state, Vector2i(3, 4))
	iface.inspect(state, Vector2i(3, 4)) # same peek target -> deduped.

	assert_int(captured.size()).is_equal(1)


# ==============================================================================
# GAME_OVER convergence clears the target.
# ==============================================================================

func test_game_over_clears_the_selection_target() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	var pair := _iface_with_capture(0)
	var iface: CommandInterface = pair[0]
	var captured: Array = pair[1]

	iface.attach_to_state(state)
	iface.try_select(state, unit) # captured[0] = pinned(1)

	# A commit whose win-check set match_status to GAME_OVER: the shared
	# action_applied handler converges this instance to terminal, clearing the
	# detail-panel target.
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, []))

	assert_int(captured[captured.size() - 1].entity_id).is_equal(-1)
	assert_bool(captured[captured.size() - 1].pinned).is_false()
