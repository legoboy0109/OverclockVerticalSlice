# Story S6-04: the infantry population cap.
#
# ★ THE PAIRING THAT MATTERS: the cap says how many units you may FIELD; upkeep says how
# long you can AFFORD them (population-cap.md, user decision 2026-08-24). They are tuned
# as a pair -- a cap below the upkeep equilibrium makes upkeep inert, one far above it is
# decorative. Tests for the relationship itself live at the bottom of this file.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


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


func _add_barracks(state: GameState, player: int, pos: Vector2i, \
		status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = StructureTypes.BARRACKS
	st.current_hp = st.type.hp
	st.build_status = status
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


# --- effective_cap ------------------------------------------------------------

func test_base_cap_with_no_barracks() -> void:
	assert_int(Population.effective_cap(_state(), 0)) \
		.is_equal(StructureBalance.base_production.base_infantry_cap)


func test_each_completed_barracks_adds_its_cap_bonus() -> void:
	var state := _state()
	var base: int = StructureBalance.base_production.base_infantry_cap
	_add_barracks(state, 0, Vector2i(1, 1))
	assert_int(Population.effective_cap(state, 0)).is_equal(base + StructureTypes.BARRACKS.cap_bonus)
	_add_barracks(state, 0, Vector2i(2, 1))
	assert_int(Population.effective_cap(state, 0)).is_equal(base + 2 * StructureTypes.BARRACKS.cap_bonus)


func test_under_construction_barracks_grants_no_cap() -> void:
	# Consistent with it paying no upkeep until completed, and with build_time being a
	# deliberate vulnerability window.
	var state := _state()
	_add_barracks(state, 0, Vector2i(1, 1), StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(Population.effective_cap(state, 0)) \
		.is_equal(StructureBalance.base_production.base_infantry_cap)


func test_opponents_barracks_do_not_raise_your_cap() -> void:
	var state := _state()
	_add_barracks(state, 1, Vector2i(9, 9))
	assert_int(Population.effective_cap(state, 0)) \
		.is_equal(StructureBalance.base_production.base_infantry_cap)


func test_full_build_out_ceiling_is_ten() -> void:
	# ★ The Alliance baseline the whole design is balanced against: 4 base + 3 Barracks x 2.
	var state := _state()
	for i: int in range(StructureTypes.BARRACKS.max_count):
		_add_barracks(state, 0, Vector2i(i, 1))
	assert_int(Population.effective_cap(state, 0)).is_equal(10)


func test_cap_never_exceeds_the_hard_ceiling() -> void:
	var state := _state()
	for i: int in range(12):  # far more Barracks than max_count would ever allow
		_add_barracks(state, 0, Vector2i(i, 1))
	assert_int(Population.effective_cap(state, 0)) \
		.is_equal(StructureBalance.base_production.cap_hard_ceiling)


# --- PC-6: the cap FALLS, and units survive ------------------------------------

func test_destroying_a_barracks_lowers_the_cap_without_destroying_units() -> void:
	# ★★ Losing a building must not kill soldiers. The owner is production-locked until
	# attrition brings them under -- that is the whole of PC-6.
	var state := _state()
	var b := _add_barracks(state, 0, Vector2i(1, 1))
	var raised: int = Population.effective_cap(state, 0)
	for i: int in range(raised):
		_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(i, 5))
	assert_int(Population.current_population(state, 0)).is_equal(raised)

	state.destroy_entity(b.entity_id)

	assert_int(Population.effective_cap(state, 0)).is_less(raised)
	assert_int(Population.current_population(state, 0)).is_equal(raised)  # nobody died
	assert_bool(Population.can_field(state, 0, UnitTypes.SCOUT)).is_false() # but locked out


# --- current_population --------------------------------------------------------

func test_current_population_counts_own_living_units_only() -> void:
	var state := _state()
	_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 5))
	_add_unit(state, 0, UnitTypes.HEAVY, Vector2i(1, 5))
	_add_unit(state, 1, UnitTypes.SCOUT, Vector2i(9, 9))
	assert_int(Population.current_population(state, 0)).is_equal(2)
	assert_int(Population.current_population(state, 1)).is_equal(1)


func test_a_destroyed_unit_frees_its_slot() -> void:
	var state := _state()
	var u := _add_unit(state, 0, UnitTypes.SCOUT, Vector2i(0, 5))
	assert_int(Population.current_population(state, 0)).is_equal(1)
	state.destroy_entity(u.entity_id)
	assert_int(Population.current_population(state, 0)).is_equal(0)


func test_cap_exempt_units_do_not_consume_slots() -> void:
	# ★ PC-4 is a per-UNIT property, which is what lets the Protectorate's robotic
	# INFANTRY be exempt while still being infantry. No shipped unit uses it yet.
	var state := _state()
	var exempt := UnitTypeDef.new()
	exempt.hp = 4
	exempt.counts_toward_cap = false
	for i: int in range(20):
		_add_unit(state, 0, exempt, Vector2i(i % GRID_SIZE, 8 + int(i / GRID_SIZE)))
	assert_int(Population.current_population(state, 0)).is_equal(0)
	assert_bool(Population.can_field(state, 0, exempt)).is_true()


func test_a_typeless_unit_is_skipped_rather_than_crashing() -> void:
	# Same robustness contract as Upkeep.total_upkeep -- both iterate the identical
	# entity list, and start_turn's step 2 is required to tolerate malformed entities.
	var state := _state()
	var u := UnitState.new()
	u.entity_id = 900
	u.owner = 0
	state.entities_by_id[u.entity_id] = u
	assert_int(Population.current_population(state, 0)).is_equal(0)


# --- can_field / the produce gate ----------------------------------------------

func test_can_field_is_false_at_the_cap() -> void:
	var state := _state()
	for i: int in range(Population.effective_cap(state, 0)):
		_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(i, 5))
	assert_bool(Population.can_field(state, 0, UnitTypes.SCOUT)).is_false()


func test_can_field_is_true_one_below_the_cap() -> void:
	var state := _state()
	for i: int in range(Population.effective_cap(state, 0) - 1):
		_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(i, 5))
	assert_bool(Population.can_field(state, 0, UnitTypes.SCOUT)).is_true()


func test_produce_at_the_cap_is_rejected_naming_the_population_cap() -> void:
	var state := _state()
	state.per_player[0].current_ap = 999
	state.per_player[0].current_credits = 999999
	var hq := StructureState.new()
	hq.entity_id = state.next_entity_id
	hq.owner = 0
	hq.position = Vector2i(5, 5)
	hq.type = StructureTypes.HQ
	hq.current_hp = hq.type.hp
	hq.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[hq.entity_id] = hq
	state.grid.place(hq.entity_id, 5, 5)
	state.next_entity_id += 1

	for i: int in range(Population.effective_cap(state, 0)):
		_add_unit(state, 0, UnitTypes.SCOUT, Vector2i(i, 12))

	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = hq.entity_id
	a.unit_type = UnitTypes.SCOUT
	a.tile = Vector2i(5, 6)
	assert_int(BaseProduction.validate_produce(state, a)).is_equal(Action.Reason.POPULATION_CAP_REACHED)


# --- ★ The cap/upkeep relationship the whole design rests on --------------------

func test_the_cap_sits_just_above_what_upkeep_can_sustain_on_a_realistic_build() -> void:
	# ★★ The intended relationship (population-cap.md, cross-checked against
	# unit-upkeep.md): you can always field a LITTLE MORE than you can comfortably keep.
	#
	# ★ WHAT WRITING THIS TEST REVEALED, and it is a real design property rather than a
	# test detail: the relationship is BUILD-DEPENDENT, not universal. A player who builds
	# ONLY Barracks maximises cap while minimising upkeep, and can sustain MORE than their
	# ceiling -- they are cap-bound, and upkeep never bites. A player who diversifies into
	# a Factory and a Lab pays their upkeep and becomes upkeep-bound instead.
	#
	# ★ AND A SECOND FINDING, in the design doc rather than the code: population-cap.md
	# asserted "cap 10, sustainable 8-9" by comparing the FULL cap (3 Barracks) against a
	# TWO-Barracks upkeep burden. Computed consistently from the same build the numbers do
	# hold -- 3 Barracks + Factory + Lab gives cap 10 against ~9 sustainable -- but the
	# doc's own worked example mixed two different builds. Corrected there.
	#
	# This test computes BOTH sides from ONE build, which is the only way the claim means
	# anything.
	var state := _state()
	for i: int in range(StructureTypes.BARRACKS.max_count):  # the same build, both sides
		_add_barracks(state, 0, Vector2i(i, 1))
	for pair: Array in [[StructureTypes.FACTORY, Vector2i(6, 1)], [StructureTypes.RESEARCH_LAB, Vector2i(7, 1)]]:
		var st := StructureState.new()
		st.entity_id = state.next_entity_id
		st.owner = 0
		st.position = pair[1]
		st.type = pair[0]
		st.current_hp = st.type.hp
		st.build_status = StructureState.BuildStatus.COMPLETED
		state.entities_by_id[st.entity_id] = st
		state.grid.place(st.entity_id, st.position.x, st.position.y)
		state.next_entity_id += 1
	var cap: int = Population.effective_cap(state, 0)

	# A fully-researched economy, minus a realistic structure upkeep burden.
	state.per_player[0].economy_tier = Balance.economy.max_economy_tier
	var for_army: int = Credits.credit_income(state, 0) - Upkeep.total_upkeep(state, 0)
	var mean_infantry_upkeep: int = 200  # roster mean, unit-upkeep.md
	var sustainable: int = for_army / mean_infantry_upkeep

	var msg: String = "cap (%d) must exceed the sustainable army (%d) - otherwise upkeep never binds and the cap does all the work" % [cap, sustainable]
	assert_int(cap).override_failure_message(msg).is_greater(sustainable)
