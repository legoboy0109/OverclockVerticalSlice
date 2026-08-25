# Story S6-02: Unit Upkeep — the Credit drain that bounds the banked economy.
#
# Covers design/gdd/unit-upkeep.md UR-1..UR-7 against Upkeep.total_upkeep(),
# net_credit_income(), apply_turn_economy(), and the disband verb.
#
# WHY this system exists: production/vertical-slice/REPORT.md returned PIVOT --
# Credits peaked at 5,724 and were still climbing linearly at turn 200 because the
# game had faucets and no drains. This is the drain, and the stock-bounding half of
# the fix (S6-01's finite research tiers bound the rate).
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


func _add_structure(state: GameState, player: int, type: StructureTypeDef, pos: Vector2i, \
		status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = type
	st.current_hp = type.hp
	st.build_status = status
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


# --- UR-1 / the derived-upkeep convention -----------------------------------

func test_shipped_roster_upkeep_matches_the_derived_convention() -> void:
	# ★ The regression that protects the cap/upkeep relationship. Before the ×100
	# Credit rescale the derivation was a bare ceil(cost/3) and produced the intended
	# values only because ceil rounded hard on single digits. UPKEEP_GRANULARITY
	# restores that; if it is ever removed these four drift low and the sustainable
	# army silently rises past the population cap.
	assert_int(UnitTypes.SCOUT.upkeep).is_equal(Upkeep.default_upkeep(UnitTypes.SCOUT.produce_cost))
	assert_int(UnitTypes.TROOPER.upkeep).is_equal(Upkeep.default_upkeep(UnitTypes.TROOPER.produce_cost))
	assert_int(UnitTypes.SNIPER.upkeep).is_equal(Upkeep.default_upkeep(UnitTypes.SNIPER.produce_cost))
	assert_int(UnitTypes.HEAVY.upkeep).is_equal(Upkeep.default_upkeep(UnitTypes.HEAVY.produce_cost))


func test_shipped_roster_upkeep_is_100_200_200_300() -> void:
	assert_int(UnitTypes.SCOUT.upkeep).is_equal(100)
	assert_int(UnitTypes.TROOPER.upkeep).is_equal(200)
	assert_int(UnitTypes.SNIPER.upkeep).is_equal(200)
	assert_int(UnitTypes.HEAVY.upkeep).is_equal(300)


func test_every_entity_upkeep_is_non_negative() -> void:
	for t: UnitTypeDef in [UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.SNIPER, UnitTypes.HEAVY]:
		assert_int(t.upkeep).is_greater_equal(0)
	for t: StructureTypeDef in [StructureTypes.HQ, StructureTypes.RESEARCH_LAB, \
			StructureTypes.DEFENSIVE_STRUCTURE, StructureTypes.BARRACKS]:
		assert_int(t.upkeep).is_greater_equal(0)


# --- UR-4: the HQ is the sole exemption -------------------------------------

func test_hq_upkeep_is_zero() -> void:
	assert_int(StructureTypes.HQ.upkeep).is_equal(0)


func test_hq_contributes_nothing_to_total_upkeep() -> void:
	var state := _state()
	_add_structure(state, 0, StructureTypes.HQ, Vector2i(0, 0))
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(0)


# --- UR-5: value-generating structures still pay ----------------------------

func test_research_lab_pays_upkeep_despite_being_the_economy_engine() -> void:
	# ★ Exempting it would make "build a Lab, research everything, sit" free, which is
	# the unbounded-accumulation defect the PIVOT diagnosed wearing a different hat.
	assert_int(StructureTypes.RESEARCH_LAB.upkeep).is_greater(0)


# --- UR-3: only completed, living entities pay ------------------------------

func test_under_construction_structure_contributes_nothing() -> void:
	var state := _state()
	_add_structure(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(1, 0), \
		StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(0)


func test_completed_structure_contributes_its_upkeep() -> void:
	var state := _state()
	_add_structure(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(1, 0))
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(StructureTypes.RESEARCH_LAB.upkeep)


func test_destroyed_entity_contributes_nothing_from_that_moment() -> void:
	var state := _state()
	var u := _add_unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 0))
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(UnitTypes.HEAVY.upkeep)
	state.destroy_entity(u.entity_id)
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(0)


# --- Summation and per-player isolation -------------------------------------

func test_total_upkeep_sums_units_and_structures() -> void:
	var state := _state()
	_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 1))     # 100
	_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(1, 1))     # 300
	_add_structure(state, 0, StructureTypes.RESEARCH_LAB, Vector2i(2, 1))  # 200
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(600)


func test_total_upkeep_counts_only_the_named_players_entities() -> void:
	var state := _state()
	_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 1))
	_add_unit(state, 1, UnitTypes.HEAVY, Vector2i(5, 5))
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(UnitTypes.SCOUT.upkeep)
	assert_int(Upkeep.total_upkeep(state, 1)).is_equal(UnitTypes.HEAVY.upkeep)


# --- Net income --------------------------------------------------------------

func test_net_credit_income_is_gross_minus_upkeep() -> void:
	var state := _state()
	state.per_player[0].economy_tier = 2
	_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))
	var expected: int = Credits.credit_income(state, 0) - Upkeep.total_upkeep(state, 0)
	assert_int(Upkeep.net_credit_income(state, 0)).is_equal(expected)


func test_net_credit_income_goes_negative_when_upkeep_exceeds_income() -> void:
	var state := _state()
	for i: int in range(12):
		_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(i, 3))  # 12 x 300 = 3600 > 1000
	assert_int(Upkeep.net_credit_income(state, 0)).is_less(0)


# --- UR-2 / UR-6: the start-of-turn charge and the deficit rule --------------

func test_apply_turn_economy_banks_net_income() -> void:
	var state := _state()
	state.per_player[0].current_credits = 0
	_add_unit(state, 0, UnitTypes.TROOPER, Vector2i(0, 1))
	var net: int = Upkeep.net_credit_income(state, 0)
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(net)
	assert_bool(state.per_player[0].in_deficit).is_false()


func test_deficit_drains_the_bank_but_never_below_zero() -> void:
	var state := _state()
	state.per_player[0].current_credits = 500
	for i: int in range(12):
		_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(i, 3))
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(0)
	assert_bool(state.per_player[0].in_deficit).is_true()


func test_no_debt_is_recorded_anywhere_when_the_bank_floors() -> void:
	# ★ A hidden negative balance is exactly the kind of invisible state that makes an
	# economy unreadable. Two consecutive deficit turns must not compound into a hole.
	var state := _state()
	state.per_player[0].current_credits = 0
	for i: int in range(12):
		_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(i, 3))
	Upkeep.apply_turn_economy(state, 0)
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(0)


func test_a_player_reduced_to_their_hq_recovers_income() -> void:
	# Correct behaviour, and a real comeback property: a player wiped down to their HQ
	# pays no upkeep at all, so their full income banks.
	var state := _state()
	state.per_player[0].current_credits = 0
	_add_structure(state, 0, StructureTypes.HQ, Vector2i(0, 0))
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(Credits.credit_income(state, 0))
	assert_bool(state.per_player[0].in_deficit).is_false()


# --- UR-3: a unit produced this turn is not charged this turn ----------------

func test_a_unit_added_after_the_economy_step_is_not_charged_until_next_turn() -> void:
	# ★ This needs no flag: the charge runs once at the owner's start of turn, before
	# they act, so anything produced afterwards is first charged next turn. UR-3 falls
	# out of the ordering rather than being enforced separately.
	var state := _state()
	state.per_player[0].current_credits = 0
	Upkeep.apply_turn_economy(state, 0)
	var after_first: int = state.per_player[0].current_credits
	_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(0, 1))   # "produced" mid-turn
	assert_int(state.per_player[0].current_credits).is_equal(after_first) # not retro-charged
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits) \
		.is_equal(after_first + Credits.credit_income(state, 0) - UnitTypes.HEAVY.upkeep)


# --- Robustness: total_upkeep must be TOTAL over every entity the map can hold ---

func test_entity_with_no_type_contributes_zero_rather_than_crashing() -> void:
	# ★ Found by S6-02's own suite run: start_turn's step 2 is explicitly required to
	# skip a bare EntityState safely, and several fixtures build typeless units. The
	# economy step runs over the SAME entity list, so it must tolerate them too --
	# crashing the whole turn over one malformed entity is strictly worse than
	# charging it nothing.
	var state := _state()
	var bare := EntityState.new()
	bare.entity_id = 777
	bare.owner = 0
	bare.position = Vector2i(4, 4)
	state.entities_by_id[bare.entity_id] = bare

	var typeless := UnitState.new()
	typeless.entity_id = 778
	typeless.owner = 0
	typeless.position = Vector2i(5, 4)
	state.entities_by_id[typeless.entity_id] = typeless

	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(0)
	# And the whole economy step still completes.
	Upkeep.apply_turn_economy(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(Credits.credit_income(state, 0))
