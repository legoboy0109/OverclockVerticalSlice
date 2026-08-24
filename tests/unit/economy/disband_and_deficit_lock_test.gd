# Story S6-02: the disband verb (UR-7) and the deficit lock (UR-6).
#
# These two are one design: the lock creates pressure, and disband is the only way a
# player can act on it by choice. Tested together because either alone is a trap --
# a lock with no escape valve is unrecoverable, and an escape valve with no lock is
# pointless.
#
# ★ Deliberately NO attrition test, because there is deliberately no attrition. A
# death spiral is not a comeback mechanism; UR-6 chose bank-drain + production-lock
# over unit damage precisely so a losing player can recover.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const GRID_SIZE: int = 16

# destroy_entity() clears the grid occupancy of the destroyed entity, so any test that
# destroys or disbands needs a real grid — a bare GameStateFactory.make_state() has none.
func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.active_player = 0
	state.per_player[0].current_ap = Balance.economy.flat_ap_per_turn
	return state


func _add_unit(state: GameState, player: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = player
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _disband(state: GameState, player: int, entity_id: int) -> ActionResult:
	var a := DisbandAction.new()
	a.player = player
	a.entity_id = entity_id
	return state.apply_action(a)


# --- UR-7: disband ----------------------------------------------------------

func test_disband_destroys_the_unit_spends_ap_and_refunds_half_its_cost() -> void:
	var state := _state()
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	state.per_player[0].current_credits = 0
	var ap_before: int = state.per_player[0].current_ap

	var r: ActionResult = _disband(state, 0, u.entity_id)

	assert_bool(r.ok).is_true()
	assert_bool(state.entities_by_id.has(u.entity_id)).is_false()
	assert_int(state.per_player[0].current_ap).is_equal(ap_before - Balance.economy.disband_ap_cost)
	assert_int(state.per_player[0].current_credits).is_equal(Upkeep.disband_refund(UnitTypes.HEAVY))


func test_disband_refund_is_half_the_produce_cost() -> void:
	assert_int(Upkeep.disband_refund(UnitTypes.HEAVY)).is_equal(UnitTypes.HEAVY.produce_cost / 2)


func test_disband_is_strictly_loss_making_so_produce_disband_churn_is_never_profitable() -> void:
	# ★ The guard on the escape valve. If the refund ever exceeded the cost, an AI or a
	# player could farm Credits by cycling units.
	for t: UnitTypeDef in [UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.SNIPER, UnitTypes.HEAVY]:
		assert_int(Upkeep.disband_refund(t)).is_less(t.produce_cost)


func test_disband_removes_the_units_upkeep_from_the_next_charge() -> void:
	# The whole point: disbanding must actually reduce the drain.
	var state := _state()
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	var before: int = Upkeep.total_upkeep(state, 0)
	_disband(state, 0, u.entity_id)
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(before - UnitTypes.HEAVY.upkeep)


func test_disband_targeting_an_enemy_unit_is_rejected() -> void:
	var state := _state()
	var enemy := _add_unit(state, 1, UnitTypes.SCOUT, Vector2i(9, 9))
	var r: ActionResult = _disband(state, 0, enemy.entity_id)
	assert_bool(r.ok).is_false()
	assert_bool(state.entities_by_id.has(enemy.entity_id)).is_true()


func test_disband_targeting_a_structure_is_rejected() -> void:
	var state := _state()
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = Vector2i(3, 3)
	st.type = StructureTypes.RESEARCH_LAB
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, st.position.x, st.position.y)
	state.next_entity_id += 1

	var r: ActionResult = _disband(state, 0, st.entity_id)
	assert_bool(r.ok).is_false()
	assert_bool(state.entities_by_id.has(st.entity_id)).is_true()


func test_disband_of_a_missing_entity_is_rejected() -> void:
	var state := _state()
	assert_bool(_disband(state, 0, 99999).ok).is_false()


func test_disband_with_insufficient_ap_is_rejected_and_changes_nothing() -> void:
	var state := _state()
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	state.per_player[0].current_ap = 0
	state.per_player[0].current_credits = 0

	var r: ActionResult = _disband(state, 0, u.entity_id)

	assert_bool(r.ok).is_false()
	assert_bool(state.entities_by_id.has(u.entity_id)).is_true()
	assert_int(state.per_player[0].current_credits).is_equal(0)


# --- UR-6: the deficit lock -------------------------------------------------

func test_in_deficit_blocks_build() -> void:
	var state := _state()
	state.per_player[0].in_deficit = true
	state.per_player[0].current_credits = 99999
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(1, 1)
	var r: ActionResult = state.apply_action(a)
	assert_bool(r.ok).is_false()
	assert_int(r.reason).is_equal(Action.Reason.IN_DEFICIT)


func test_in_deficit_blocks_build_even_with_ample_credits() -> void:
	# ★ The reason must name the deficit, not affordability. A deficit player may well
	# be broke too, but being broke is not why they are locked out.
	var state := _state()
	state.per_player[0].in_deficit = true
	state.per_player[0].current_credits = 999999
	state.per_player[0].current_ap = 999
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(1, 1)
	assert_int(state.apply_action(a).reason).is_equal(Action.Reason.IN_DEFICIT)


func test_disband_is_permitted_while_in_deficit() -> void:
	# ★★ The load-bearing case. Disband is the ONLY action that reduces upkeep, so
	# locking it would make a deficit unrecoverable by the player's own choice --
	# turning UR-6's pressure into a trap.
	var state := _state()
	state.per_player[0].in_deficit = true
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	var r: ActionResult = _disband(state, 0, u.entity_id)
	assert_bool(r.ok).is_true()
	assert_bool(state.entities_by_id.has(u.entity_id)).is_false()


func test_the_lock_holds_for_the_whole_turn_even_after_disbanding_into_solvency() -> void:
	# UR-6 evaluates the lock once at the economy step and holds it. A lock that
	# flickers mid-turn is unreadable. The disband still counts -- for NEXT turn.
	var state := _state()
	state.per_player[0].in_deficit = true
	state.per_player[0].current_credits = 99999
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	_disband(state, 0, u.entity_id)
	assert_bool(state.per_player[0].in_deficit).is_true()

	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.RESEARCH_LAB
	a.tile = Vector2i(1, 1)
	assert_int(state.apply_action(a).reason).is_equal(Action.Reason.IN_DEFICIT)


func test_deficit_clears_on_the_next_start_of_turn_once_solvent() -> void:
	var state := _state()
	state.per_player[0].in_deficit = true
	state.per_player[0].current_credits = 0
	# No entities owned -> no upkeep -> income banks and the flag clears.
	Upkeep.apply_turn_economy(state, 0)
	assert_bool(state.per_player[0].in_deficit).is_false()
