# Story 008: Post-Commit Re-Selection, Destroyed-Actor Collapse & GAME_OVER
# Convergence.
#
# Covers production/epics/command-action-interface/story-008-post-commit-reselection-gameover-convergence.md
# (TR-cmdui-015, ADR-0015):
#
#   AC-25: after a move that keeps AP + a target in range, the actor re-selects
#     (ENTITY_SELECTED) and its menu re-filters to show Attack enabled.
#   AC-32: an attacker that dies to a Defensive Structure's / counter-unit's
#     counterattack on its own committed attack -> the interface collapses to
#     IDLE, no dangling selection on the destroyed actor.
#   AC-33: a Build commit lands on the newly-placed structure (ENTITY_SELECTED),
#     never a prior selection.
#   AC-34: a commit whose win-check sets match_status = GameOver -> terminal
#     GAME_OVER; subsequent select/preview triggers are inert.
#   AC-35: the non-committing instance (never called apply_action) also converges
#     on GAME_OVER via the same shared action_applied signal.
#
# Integration: real GameState.apply_action + Combat counter pipeline for the
# re-selection ACs; the GAME_OVER-convergence ACs drive the OBSERVATION path this
# story owns (match_status is set + action_applied emitted) — the win-check logic
# itself is Combat/ADR-0010's, out of this story's scope. Real fixtures, faction
# Neutral; auto_free() Node fixtures. Deterministic: no RNG/time/IO.
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


func _make_unit_type(hp: int = 10, attack: int = 3, attack_range: int = 1) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestUnit"
	type.hp = hp
	type.attack = attack
	type.attack_range = attack_range
	type.move_cost = 1
	type.soft_move_cap = 8
	type.produce_cost = 4
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	return type


func _make_counter_type(hp: int = 10, attack: int = 3) -> UnitTypeDef:
	# A throwaway can_counterattack=true DIRECT defender (fresh Resource — every
	# real VS roster type ships can_counterattack=false).
	var type := _make_unit_type(hp, attack, 1)
	type.display_name = "CounterFixture"
	type.can_counterattack = true
	return type


func _make_buildable_type(build_cost: int = 6) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestBuildable"
	type.hp = 20
	type.build_cost = build_cost
	type.build_time = 2
	type.production_cap = 0
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


func _place_structure(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = type
	s.current_hp = type.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[entity_id] = s
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return s


func _move_action(player: int, from: Vector2i, to: Vector2i) -> MoveAction:
	var a := MoveAction.new()
	a.player = player
	a.from = from
	a.to = to
	a.tiles_entered = 1
	return a


func _attack_action(player: int, attacker_tile: Vector2i, target_tile: Vector2i) -> AttackAction:
	var a := AttackAction.new()
	a.player = player
	a.attacker_tile = attacker_tile
	a.target_tile = target_tile
	return a


func _interface(player: int = 0) -> CommandInterface:
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(player)
	return iface


# ==============================================================================
# AC-25: post-commit re-selection — move then attack, one fluid sequence.
# ==============================================================================

func test_post_move_commit_reselects_actor_with_attack_now_enabled() -> void:
	var state := _make_state(0)
	# Mover at (5,5); an enemy at (7,5) — 2 tiles away, in range (attack_range 3)
	# only AFTER the mover steps one tile east to (6,5).
	var mover := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type(10, 3, 3))
	_place_unit(state, 2, 1, Vector2i(7, 5), _make_unit_type())
	state.per_player[0].current_ap = 10

	var iface := _interface(0)
	iface._selected_id = mover.entity_id # the mover was selected pre-commit.

	var result: ActionResult = iface.commit(state, _move_action(0, Vector2i(5, 5), Vector2i(6, 5)))
	assert_bool(result.ok).is_true()

	# Re-selected on the same actor, menu re-filtered against the new position…
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.ENTITY_SELECTED)
	assert_int(iface.selected_id()).is_equal(mover.entity_id)
	# …with Attack now enabled (the enemy is in range from (6,5)) — move→attack.
	var moved := state.entities_by_id[1] as UnitState
	var attack_entry := CommandFSM.menu_model(state, moved)[CommandFSM.Verb.ATTACK]
	assert_bool(attack_entry.enabled).is_true()


# ==============================================================================
# AC-32: attacker dies to a counterattack -> collapse to IDLE.
# ==============================================================================

func test_attacker_destroyed_by_counter_collapses_to_idle() -> void:
	var state := _make_state(0)
	# A 2-hp attacker vs an adjacent can_counterattack defender (attack 3): the
	# attacker survives its own hit but the counter (3) reduces it to 0 -> destroyed.
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type(2, 3, 1))
	_place_unit(state, 2, 1, Vector2i(5, 6), _make_counter_type(10, 3))
	state.per_player[0].current_ap = 10

	var iface := _interface(0)
	iface._selected_id = attacker.entity_id

	var result: ActionResult = iface.commit(state, _attack_action(0, Vector2i(5, 5), Vector2i(5, 6)))
	assert_bool(result.ok).is_true()

	# The attacker is gone; the interface holds no dangling selection on it.
	assert_bool(state.entities_by_id.has(1)).is_false()
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.IDLE)
	assert_int(iface.selected_id()).is_equal(-1)


# ==============================================================================
# AC-33: a Build commit lands on the newly-placed structure.
# ==============================================================================

func test_build_commit_lands_on_new_structure_not_prior_selection() -> void:
	var state := _make_state(0)
	_place_structure(state, 1, 0, Vector2i(5, 5), _make_buildable_type()) # anchor so tiles are legal.
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 20 # fund the build's Credit main cost (dual-cost pivot).

	var buildable := _make_buildable_type(6)
	var preview: CommandFSM.BuildEntry = CommandFSM.build_preview(state, 0, buildable)
	assert_bool(preview.legal_tiles.is_empty()).is_false()
	var target: Vector2i = preview.legal_tiles[0]

	var iface := _interface(0)
	iface._selected_id = 1 # a stale prior selection that must NOT survive the build.

	var action := BuildAction.new()
	action.structure_type = buildable
	action.tile = target
	var result: ActionResult = iface.commit(state, action)
	assert_bool(result.ok).is_true()

	# Landed ENTITY_SELECTED on the NEW structure (under-construction -> Cancel
	# Build is a legal action), never the prior selection id 1.
	var new_id: int = state.grid.occupant_at(target.x, target.y)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.ENTITY_SELECTED)
	assert_int(iface.selected_id()).is_equal(new_id)
	assert_bool(iface.selected_id() != 1).is_true()


# ==============================================================================
# AC-34: a GameOver-setting commit -> terminal GAME_OVER, triggers inert.
# ==============================================================================

func test_gameover_observation_makes_interface_terminal_and_inert() -> void:
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), _make_unit_type())
	state.per_player[0].current_ap = 10

	var iface := _interface(0)
	iface.attach_to_state(state)

	# Simulate the win-check outcome (its logic is Combat/ADR-0010's, out of
	# scope): match ends, then apply_action's action_applied fires.
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.action_applied.emit(ActionResult.new(true))

	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.GAME_OVER)
	assert_int(iface.selected_id()).is_equal(-1)

	# Every subsequent trigger is inert (is_input_live is false once terminal).
	assert_bool(iface.try_select(state, unit)).is_false()
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.GAME_OVER)


# ==============================================================================
# AC-35: the non-committing instance converges on GAME_OVER via the shared signal.
# ==============================================================================

func test_non_committing_instance_also_converges_on_gameover() -> void:
	var state := _make_state(1) # player 1's turn (the committer).
	var iface_local := _interface(0) # player 0 — inert during the opponent's turn.
	var iface_opponent := _interface(1)
	iface_local.attach_to_state(state)
	iface_opponent.attach_to_state(state)

	# Player 1's commit ends the match; the ONE shared signal fires.
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.action_applied.emit(ActionResult.new(true))

	# Both instances converge — including player 0's, which never called apply_action.
	assert_int(iface_opponent.fsm_state()).is_equal(CommandFSM.State.GAME_OVER)
	assert_int(iface_local.fsm_state()).is_equal(CommandFSM.State.GAME_OVER)
