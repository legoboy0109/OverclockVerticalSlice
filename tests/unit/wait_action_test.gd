# WaitAction — the per-turn stand-down mark (design/ux/action-menu.md OQ-1).
#
# The GDD has always said Wait "ends this entity's involvement without spending".
# Until 2026-08-25 nothing in the simulation could record that, so Wait was a
# deselect and the entity went on looking exactly like one the player had not got
# to yet.
#
# The mark is ADVISORY by design (user decision, 2026-08-25): it changes what the
# INTERFACE offers, never what the rules allow. These tests pin both halves — that
# it is recorded and cleared correctly, and that it gates nothing.
#
# Deterministic: no RNG, no time, no I/O.
extends GdUnitTestSuite


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


func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_blank_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_ap = 20
		state.per_player[i].current_credits = 500
	return state


func _place_unit(state: GameState, id: int, owner: int, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = id
	unit.owner = owner
	unit.position = pos
	unit.type = UnitTypes.SCOUT
	unit.current_hp = unit.type.hp
	state.entities_by_id[id] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = id
	return unit


func _wait_on(state: GameState, entity_id: int, player: int = 0) -> ActionResult:
	var action := WaitAction.new()
	action.player = player
	action.entity_id = entity_id
	return state.apply_action(action)


# --- The mark itself --------------------------------------------------------

func test_waiting_marks_the_entity_stood_down() -> void:
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4))

	var result: ActionResult = _wait_on(state, 1)

	assert_bool(result.ok).is_true()
	assert_bool(unit.stood_down).is_true()


func test_waiting_spends_nothing() -> void:
	# ★ Every other verb in the game is priced (Pillar 1). This one is not, because
	# it buys nothing — it is the player telling the interface what they have
	# already decided. A priced Wait would tax tidiness.
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))
	var ap_before: int = state.per_player[0].current_ap
	var credits_before: int = state.per_player[0].current_credits

	_wait_on(state, 1)

	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_int(state.per_player[0].current_credits).is_equal(credits_before)


func test_waiting_emits_an_event_so_the_log_can_show_it() -> void:
	# Without an event this would be the one commit that leaves no trace — a player
	# reconstructing their turn from the log would find their tidying missing.
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))

	var result: ActionResult = _wait_on(state, 1)

	assert_int(result.events.size()).is_equal(1)
	assert_bool(result.events[0] is EntityStoodDownEvent).is_true()
	assert_int((result.events[0] as EntityStoodDownEvent).entity_id).is_equal(1)


func test_a_structure_can_stand_down_too() -> void:
	# Both concrete state classes carry the field, because both appear in the
	# contextual menu and both can be something the player is finished with.
	var state := _make_state()
	var structure := StructureState.new()
	structure.entity_id = 2
	structure.owner = 0
	structure.position = Vector2i(6, 6)
	structure.type = StructureTypes.HQ
	structure.current_hp = structure.type.hp
	structure.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[2] = structure

	_wait_on(state, 2)

	assert_bool(structure.stood_down).is_true()


# --- What it must NOT do ----------------------------------------------------

func test_a_stood_down_unit_keeps_every_verb_it_had() -> void:
	# ★★ THE test for the advisory decision. A hard lockout was the other option on
	# the table; this pins that it was not taken. If a future change gates a verb on
	# stood_down, this fails and forces that rules change to be a deliberate one.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4))
	var before: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)

	_wait_on(state, 1)
	var after: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)

	assert_int(after.size()).is_equal(before.size())
	for i: int in before.size():
		assert_int(after[i].verb).is_equal(before[i].verb)
		assert_bool(after[i].enabled).override_failure_message(
			"standing down must not disable verb %d — the mark is advisory, not binding"
			% after[i].verb
		).is_equal(before[i].enabled)


func test_a_stood_down_unit_can_still_actually_move() -> void:
	# The menu saying a verb is available and the validator agreeing are two
	# different claims. This pins the second.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4))
	_wait_on(state, 1)

	var move := MoveAction.new()
	move.player = 0
	move.from = Vector2i(4, 4)
	move.to = Vector2i(4, 5)
	move.tiles_entered = 1
	var result: ActionResult = state.apply_action(move)

	assert_bool(result.ok).override_failure_message(
		"a stood-down unit must still be able to move — the mark forbids nothing"
	).is_true()
	assert_vector(unit.position).is_equal(Vector2i(4, 5))


# --- Clearing ---------------------------------------------------------------

func test_acting_clears_the_mark() -> void:
	# ★ The mark records "I am finished with this one". A player who then moves it
	# has visibly changed their mind, and leaving it set would keep the unit dim and
	# skipped while it still had a turn left.
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4))
	_wait_on(state, 1)
	assert_bool(unit.stood_down).is_true()

	var move := MoveAction.new()
	move.player = 0
	move.from = Vector2i(4, 4)
	move.to = Vector2i(4, 5)
	move.tiles_entered = 1
	state.apply_action(move)

	assert_bool(unit.stood_down).is_false()


func test_the_mark_lasts_exactly_one_turn() -> void:
	var state := _make_state()
	var unit := _place_unit(state, 1, 0, Vector2i(4, 4))
	_wait_on(state, 1)

	state.start_turn(0) # the owner's next turn begins

	assert_bool(unit.stood_down).override_failure_message(
		"a stand-down must not survive into the next turn"
	).is_false()


func test_standing_down_twice_is_harmless_not_an_error() -> void:
	# Rejecting it would make a double-press of a harmless tidying verb produce a
	# "Refused" line for no reason.
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))

	assert_bool(_wait_on(state, 1).ok).is_true()
	assert_bool(_wait_on(state, 1).ok).is_true()


# --- Ownership + validity ---------------------------------------------------

func test_you_cannot_stand_down_an_entity_you_do_not_own() -> void:
	var state := _make_state()
	var enemy := _place_unit(state, 9, 1, Vector2i(7, 7))

	var result: ActionResult = _wait_on(state, 9, 0)

	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_bool(enemy.stood_down).is_false()


func test_standing_down_a_missing_entity_is_refused_cleanly() -> void:
	var state := _make_state()

	var result: ActionResult = _wait_on(state, 404)

	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NO_SUCH_ENTITY)


# --- The idle count the End-Turn notice reads -------------------------------

func test_idle_count_drops_as_entities_are_stood_down() -> void:
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))
	_place_unit(state, 2, 0, Vector2i(6, 4))
	var reader := GameStateReader.new(state)

	assert_int(reader.idle_entity_count(0)).is_equal(2)
	_wait_on(state, 1)
	assert_int(reader.idle_entity_count(0)).is_equal(1)
	_wait_on(state, 2)
	assert_int(reader.idle_entity_count(0)).is_equal(0)


func test_idle_count_ignores_the_opponents_entities() -> void:
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))
	_place_unit(state, 9, 1, Vector2i(7, 7))
	var reader := GameStateReader.new(state)

	assert_int(reader.idle_entity_count(0)).is_equal(1)


func test_an_entity_with_nothing_it_could_do_is_not_counted_as_idle() -> void:
	# ★ "Idle" means "still has something to do", not "has not been told to stop".
	# A unit with no AP left is finished whether or not the player said so, and
	# nagging about it at End Turn would be nagging about nothing.
	var state := _make_state()
	_place_unit(state, 1, 0, Vector2i(4, 4))
	state.per_player[0].current_ap = 0
	var reader := GameStateReader.new(state)

	assert_int(reader.idle_entity_count(0)).is_equal(0)
