# Story 007: Commit Dispatch, INPUT_LOCK_MS Debounce & Commit-Flash↔AP-Tick
# Shared Signal.
#
# Covers production/epics/command-action-interface/story-007-commit-dispatch-input-lock-shared-signal.md
# (TR-cmdui-022/023, ADR-0014/ADR-0015):
#
#   AC-27: two rapid commit dispatches (double-click) -> exactly ONE commit
#     fires and the resource change applies exactly once; the second is inert.
#   AC (lock scope): input_locked gates ONLY new commit dispatch — hover /
#     board-cursor stay live during the lock window.
#   AC-023 (same frame): a successful commit fires commit_flash_requested
#     synchronously, from the shared GameState.action_applied subscription (which
#     apply_action emits exactly once per commit) — same frame, no tolerance.
#   AC (lock timing): input_locked stays true for the window then releases
#     automatically (await create_timer), no manual reset.
#   AC (audio ownership): CommandInterface plays no audio of its own.
#
# Integration: real GameState.apply_action commit path; the CommandInterface is
# add_child()'d so its release timer's get_tree() resolves. input_lock_ms is set
# small so the async release test is fast. Real fixtures, faction Neutral;
# auto_free() Node fixtures. Deterministic: no RNG, timing driven by an explicit
# short input_lock_ms + create_timer awaits (not wall-clock tolerance windows).
extends GdUnitTestSuite


func _make_grid(size: int = 12) -> GridState:
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
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestUnit"
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


func _move_action(player: int, from: Vector2i, to: Vector2i) -> MoveAction:
	var action := MoveAction.new()
	action.player = player
	action.from = from
	action.to = to
	action.tiles_entered = 1
	return action


func _fast_lock_interface(state: GameState, lock_ms: int = 30) -> CommandInterface:
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var config := InputConfig.new()
	config.input_lock_ms = lock_ms
	iface.set_input_config(config)
	add_child(iface) # the release timer needs get_tree()
	return iface


# ==============================================================================
# AC-27: double-click -> exactly one commit; second inert.
# ==============================================================================

func test_double_dispatch_fires_exactly_one_commit_second_inert() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	state.per_player[0].current_ap = 10
	var ap_start: int = AP.current_ap(state, 0)

	var iface := _fast_lock_interface(state)

	# First dispatch commits a real move (cost 1); input then locks.
	var first: bool = iface.dispatch_commit(_move_action(0, Vector2i(5, 5), Vector2i(6, 5)), state)
	assert_bool(first).is_true()
	assert_bool(iface.input_locked).is_true()
	var ap_after_first: int = AP.current_ap(state, 0)
	assert_int(ap_start - ap_after_first).is_equal(1) # exactly one move cost applied.

	# A second, would-be-valid move (from the unit's NEW tile) lands within the
	# lock window -> inert: no dispatch, no second apply_action, AP unchanged.
	var second: bool = iface.dispatch_commit(_move_action(0, Vector2i(6, 5), Vector2i(7, 5)), state)
	assert_bool(second).is_false()
	assert_int(AP.current_ap(state, 0)).is_equal(ap_after_first)
	assert_object((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(6, 5)) # still at the first move's tile.

	# Let the lock release cleanly (avoids a dangling timer on the freed node),
	# which also proves AC (lock timing): it releases automatically, no reset.
	await get_tree().create_timer(0.06).timeout
	assert_bool(iface.input_locked).is_false()


# ==============================================================================
# AC (lock scope): the lock gates commit dispatch ONLY — hover stays live.
# ==============================================================================

func test_input_lock_does_not_block_hover_updates() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	state.per_player[0].current_ap = 10

	var iface := _fast_lock_interface(state)
	iface.dispatch_commit(_move_action(0, Vector2i(5, 5), Vector2i(6, 5)), state)
	assert_bool(iface.input_locked).is_true()

	# A hover tile-change during the lock window still updates live.
	iface._on_mouse_moved_to_tile(Vector2i(9, 9))
	assert_object(iface.active_tile()).is_equal(Vector2i(9, 9))
	assert_int(iface.active_locus()).is_equal(CommandInterface.Locus.MOUSE)

	await get_tree().create_timer(0.06).timeout # clean release.


# ==============================================================================
# AC-023: commit-flash fires synchronously on the shared action_applied signal.
# ==============================================================================

func test_commit_flash_fires_once_synchronously_on_successful_commit() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	state.per_player[0].current_ap = 10

	var iface := _fast_lock_interface(state)
	iface.attach_to_state(state) # subscribe to GameState.action_applied.

	var flashes: Array = []
	iface.commit_flash_requested.connect(func(result: ActionResult) -> void: flashes.append(result))

	# The commit resolves synchronously inside dispatch_commit -> apply_action
	# emits action_applied -> _on_action_applied -> commit_flash_requested. No
	# await between the dispatch and the assertion: same frame by construction.
	iface.dispatch_commit(_move_action(0, Vector2i(5, 5), Vector2i(6, 5)), state)

	assert_int(flashes.size()).is_equal(1) # fired exactly once, this same frame.
	assert_bool((flashes[0] as ActionResult).ok).is_true()

	await get_tree().create_timer(0.06).timeout # clean release.


func test_rejected_commit_fires_no_flash() -> void:
	# active_player is 1 (opponent); this interface acts for player 0 -> commit()
	# synthesizes a rejected result, action_applied never carries an ok=true here.
	var state := _make_state(1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	state.per_player[0].current_ap = 10

	var iface := _fast_lock_interface(state)
	iface.attach_to_state(state)
	var flashes: Array = []
	iface.commit_flash_requested.connect(func(result: ActionResult) -> void: flashes.append(result))

	iface.dispatch_commit(_move_action(0, Vector2i(5, 5), Vector2i(6, 5)), state)

	assert_int(flashes.size()).is_equal(0) # no flash on a rejected/no-op commit.

	await get_tree().create_timer(0.06).timeout


# ==============================================================================
# AC (audio ownership): this system fires no audio of its own.
# ==============================================================================

func test_command_interface_plays_no_audio() -> void:
	# Structural: Combat owns the attack cue off the same action_applied event,
	# so CommandInterface must never play audio itself. Strip full-comment lines
	# first so doc comments that MENTION the forbidden call (to document that it
	# is never made) don't false-positive — the check inspects CODE only.
	var source := FileAccess.get_file_as_string("res://src/ui/command_action_interface/command_interface.gd")
	var code_lines: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		code_lines.append(line)
	var code: String = "\n".join(code_lines)
	assert_bool(code.contains("AudioStreamPlayer")).override_failure_message(
		"CommandInterface must own no AudioStreamPlayer — audio is Combat's off the shared event").is_false()
	assert_bool(code.contains(".play(")).override_failure_message(
		"CommandInterface must call no .play() — exactly one system (Combat) plays on action_applied").is_false()
