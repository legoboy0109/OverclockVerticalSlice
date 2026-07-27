# Base & Production Story 004: Produce Verb, legal_deploy_tiles, effective_production_cap.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-004-produce-legal-deploy-tiles.md:
#   Production (Rule 7): Completed Production Outpost (counter 0) + AP ->
#     produce(Trooper, empty adjacent tile) spends AP, creates an immediately-
#     Active Trooper on the tile, counter -> 1; HQ produce(Heavy) rejected
#     (Heavy not in HQ's producible_types — HQ makes only Scouts); a producer at
#     production_cap is rejected with AP to spare (cap gates independently of
#     AP); no empty adjacent tile -> blocked, no AP spent; Under-Construction
#     producer -> rejected (requires Completed); producer no-longer-Completed OR
#     deploy tile occupied between preview and commit -> apply re-validates and
#     rejects (no unit, no AP); effective_production_cap is two-sided (base 0
#     stays 0; base >= 1 -> max(1, base+delta); == base under Neutral).
#   legal_deploy_tiles: empty/passable/in-bounds manhattan==1 neighbours, in
#     canonical tile-index order; occupied/Impassable/off-board neighbours excluded.
#
# Injected Grid + AP fixtures (GameStateFactory + a hand-built GridState),
# mirroring build_verb_legal_build_tiles_occupancy_test.gd's _make_grid/
# _make_state/_place style. The acting player's faction is Factions.NEUTRAL so
# Unit.effective_produce_cost's faction fold is a no-op (== base) — the VS pin.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 12


# --- Fixture builders --------------------------------------------------------

# Blank all-Plain grid, large enough for every fixture below.
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


# current_ap defaults generous (100) so cap/tile gates are exercised without AP
# ever being the limiter, unless a test drives it lower. Both players' faction
# is pinned to Neutral (make_state leaves it null; effective_produce_cost would
# otherwise dereference a null FactionDef).
func _make_state(current_ap: int = 100) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = status
	return structure


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _make_produce_action(producer_id: int, unit_type: UnitTypeDef, tile: Vector2i, player: int = 0) -> ProduceAction:
	var action := ProduceAction.new()
	action.player = player
	action.producer_id = producer_id
	action.unit_type = unit_type
	action.tile = tile
	return action


# --- legal_deploy_tiles ------------------------------------------------------

func test_legal_deploy_tiles_returns_four_open_neighbours_in_canonical_index_order() -> void:
	# Arrange -- a Completed Production Outpost alone on an open board.
	var state := _make_state()
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	# Act
	var tiles := BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- all four manhattan==1 neighbours, sorted by y*width+x ascending:
	# (5,4)=53, (4,5)=64, (6,5)=66, (5,6)=77.
	assert_array(tiles).is_equal([Vector2i(5, 4), Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 6)])


# The three exclusion reasons (occupied / Impassable / off-board) are tested in
# ISOLATION -- one disqualified neighbour, the other three still legal -- so each
# assertion pins the specific exclusion path rather than an aggregate all-fail
# that a single broken filter could still satisfy (qa-tester false-green guard).

func test_legal_deploy_tiles_excludes_only_the_occupied_neighbour() -> void:
	# Arrange -- producer at open (5,5); its E neighbour (6,5) is occupied.
	var state := _make_state()
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	_place(state, _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(6, 5)))
	# Act
	var tiles := BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- exactly the other three neighbours remain, in canonical order.
	assert_array(tiles).is_equal([Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 6)])


func test_legal_deploy_tiles_excludes_only_the_impassable_neighbour() -> void:
	# Arrange -- producer at open (5,5); its E neighbour (6,5) is Impassable terrain.
	var state := _make_state()
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	state.grid.terrain[state.grid.index(6, 5)] = GridState.Terrain.IMPASSABLE
	# Act
	var tiles := BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- exactly the other three neighbours remain, in canonical order.
	assert_array(tiles).is_equal([Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 6)])


func test_legal_deploy_tiles_excludes_only_the_offboard_neighbour() -> void:
	# Arrange -- producer against the left edge at (0,5); its W neighbour (-1,5)
	# is off-board. N/E/S stay in-bounds and open.
	var state := _make_state()
	var producer := _make_structure(1, 0, Vector2i(0, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	# Act
	var tiles := BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- (0,4)=48, (1,5)=61, (0,6)=72 remain; the off-board W is gone.
	assert_array(tiles).is_equal([Vector2i(0, 4), Vector2i(1, 5), Vector2i(0, 6)])


func test_legal_deploy_tiles_excludes_offboard_neighbours_at_high_board_edge() -> void:
	# Arrange -- producer in the far corner (11,11) so E (12,11) and S (11,12) are
	# off-board on the UPPER bounds (the low-edge test above only exercises the
	# lower bound). N (11,10) and W (10,11) stay in-bounds and open.
	var state := _make_state()
	var producer := _make_structure(1, 0, Vector2i(GRID_SIZE - 1, GRID_SIZE - 1), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	# Act
	var tiles := BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)
	# Assert -- (11,10)=131 and (10,11)=142 remain (ascending index); both
	# off-board upper-bound neighbours (E (12,11), S (11,12)) gone.
	assert_array(tiles).is_equal([Vector2i(11, 10), Vector2i(10, 11)])


# --- Production (Rule 7): the happy path -------------------------------------

func test_produce_spends_ap_creates_active_unit_on_tile_and_increments_counter() -> void:
	# Arrange -- Completed Production Outpost, counter 0, AP exactly the cost.
	var cost: int = UnitTypes.TROOPER.produce_cost
	var state := _make_state(cost)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	var tile := Vector2i(6, 5)
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, tile)
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.OK)
	var next_id_before: int = state.next_entity_id
	# Act
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	# Assert -- AP spent exactly the produce cost.
	assert_int(state.per_player[0].current_ap).is_equal(0)
	# The new unit took the pending id and next_entity_id advanced by exactly one.
	assert_int(state.next_entity_id).is_equal(next_id_before + 1)
	# A new UnitState exists on the tile, immediately Active (no build lifecycle).
	var deployed: EntityState = state.entity_at(tile)
	assert_object(deployed).is_not_null()
	assert_bool(deployed is UnitState).is_true()
	var unit: UnitState = deployed
	assert_int(unit.owner).is_equal(0)
	assert_object(unit.type).is_same(UnitTypes.TROOPER)
	assert_int(unit.current_hp).is_equal(UnitTypes.TROOPER.hp)
	assert_int(unit.entity_id).is_equal(next_id_before)
	# The unit occupies the grid the instant this commits (single atomic apply).
	assert_bool(state.grid.is_passable(tile.x, tile.y)).is_false()
	# Producer counter incremented to 1.
	assert_int(producer.units_produced_this_turn).is_equal(1)
	# One deployment event carrying the unit's full identity (incl. owner).
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is UnitDeployedEvent).is_true()
	var evt: UnitDeployedEvent = events[0]
	assert_int(evt.entity_id).is_equal(unit.entity_id)
	assert_object(evt.unit_type).is_same(UnitTypes.TROOPER)
	assert_int(evt.owner).is_equal(0)
	assert_int(evt.tile.x).is_equal(tile.x)
	assert_int(evt.tile.y).is_equal(tile.y)


# --- Production (Rule 7): rejection gates ------------------------------------

func test_produce_type_not_in_producible_types_is_rejected_resource_ref_membership() -> void:
	# Arrange -- the HQ (producible_types == [Scout]) asked to make a Heavy.
	var state := _make_state()
	var hq := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.HQ)
	_place(state, hq)
	var action := _make_produce_action(hq.entity_id, UnitTypes.HEAVY, Vector2i(6, 5))
	# Act / Assert -- rejected: Heavy is not a Resource-ref member of HQ's roster.
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.NOT_PRODUCIBLE)
	# Sanity: the HQ *can* make a Scout (positive side of the membership check).
	var ok_action := _make_produce_action(hq.entity_id, UnitTypes.SCOUT, Vector2i(6, 5))
	assert_int(BaseProduction.validate_produce(state, ok_action)).is_equal(Action.Reason.OK)


func test_produce_at_production_cap_is_rejected_independently_of_ap() -> void:
	# Arrange -- producer already at cap (4) but with plenty of AP to spare.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	producer.units_produced_this_turn = StructureTypes.PRODUCTION_OUTPOST.production_cap
	_place(state, producer)
	var tile := Vector2i(6, 5)
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, tile)
	# Act
	var reason: int = BaseProduction.validate_produce(state, action)
	# Assert -- the cap gate fires (before/independently of the affordable AP).
	assert_int(reason).is_equal(Action.Reason.PRODUCTION_CAP_REACHED)
	# apply_produce refuses to mutate too (idempotent re-validation).
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(100)
	assert_object(state.entity_at(tile)).is_null()


func test_produce_with_no_empty_adjacent_tile_is_blocked_no_ap_spent() -> void:
	# Arrange -- producer with all four neighbours occupied by other units.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	_place(state, _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(5, 4)))
	_place(state, _make_unit(3, 0, UnitTypes.SCOUT, Vector2i(6, 5)))
	_place(state, _make_unit(4, 0, UnitTypes.SCOUT, Vector2i(5, 6)))
	_place(state, _make_unit(5, 0, UnitTypes.SCOUT, Vector2i(4, 5)))
	# Precondition -- no legal deploy tile exists.
	assert_array(BaseProduction.legal_deploy_tiles(state, producer, UnitTypes.TROOPER)).is_empty()
	# Act -- attempt to produce onto one of the occupied neighbours.
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, Vector2i(6, 5))
	var reason: int = BaseProduction.validate_produce(state, action)
	# Assert -- rejected, no AP spent.
	assert_int(reason).is_equal(Action.Reason.NOT_LEGAL_DEPLOY_TILE)
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(100)


func test_produce_from_under_construction_producer_is_rejected_requires_completed() -> void:
	# Arrange -- an Under-Construction Production Outpost.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, producer)
	var tile := Vector2i(6, 5)
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, tile)
	# Act / Assert -- production requires Completed status.
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.NOT_COMPLETED)
	# apply_produce refuses to mutate too (parity with the other rejection tests):
	# no unit, no AP spent, counter untouched.
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(100)
	assert_object(state.entity_at(tile)).is_null()
	assert_int(producer.units_produced_this_turn).is_equal(0)


func test_produce_commit_revalidation_rejects_when_producer_no_longer_completed() -> void:
	# Arrange -- validate passes at preview time.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	var tile := Vector2i(6, 5)
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, tile)
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.OK)
	# Act -- the producer reverts to Under-Construction before commit (e.g. a
	# Research-Lab-style state change), mirroring the deploy-tile stale-preview case.
	producer.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	var ap_before: int = state.per_player[0].current_ap
	var next_id_before: int = state.next_entity_id
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	# Assert -- rejected at commit: no unit, no AP spent, no id burned.
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_object(state.entity_at(tile)).is_null()
	assert_int(producer.units_produced_this_turn).is_equal(0)
	assert_int(state.next_entity_id).is_equal(next_id_before)


func test_produce_commit_revalidation_rejects_when_deploy_tile_occupied_between_preview_and_commit() -> void:
	# Arrange -- a legal deploy tile at preview time, then occupied before commit.
	var state := _make_state(100)
	var producer := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, producer)
	var tile := Vector2i(6, 5)
	var action := _make_produce_action(producer.entity_id, UnitTypes.TROOPER, tile)
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.OK)
	# Act -- tile becomes occupied before commit (stale preview).
	var intruder := _make_unit(2, 1, UnitTypes.SCOUT, tile)
	_place(state, intruder)
	var ap_before: int = state.per_player[0].current_ap
	var next_id_before: int = state.next_entity_id
	var events: Array[Event] = BaseProduction.apply_produce(state, action)
	# Assert -- rejected at commit: no new unit, no AP spent, intruder untouched,
	# no id burned.
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_object(state.entity_at(tile)).is_same(intruder)
	assert_int(producer.units_produced_this_turn).is_equal(0)
	assert_int(state.next_entity_id).is_equal(next_id_before)


# --- effective_production_cap: two-sided invariant --------------------------

func test_effective_production_cap_base_zero_stays_zero_no_producer_via_faction() -> void:
	# Arrange -- an Economy Outpost (base production_cap 0, a non-producer).
	var state := _make_state()
	var econ := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.ECONOMY_OUTPOST)
	_place(state, econ)
	# Act / Assert -- base 0 stays 0 (early-return branch); a non-producer is
	# never promoted into a producer by any faction delta.
	assert_int(BaseProduction.effective_production_cap(state, econ, 0)).is_equal(0)


func test_effective_production_cap_base_positive_equals_base_under_neutral() -> void:
	# Arrange -- producers with base cap >= 1 under Neutral (delta 0).
	var state := _make_state()
	var outpost := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	var hq := _make_structure(2, 0, Vector2i(8, 8), StructureTypes.HQ)
	_place(state, outpost)
	_place(state, hq)
	# Act / Assert -- max(1, base + 0) == base exactly (Neutral no-op).
	assert_int(BaseProduction.effective_production_cap(state, outpost, 0)).is_equal(StructureTypes.PRODUCTION_OUTPOST.production_cap)
	assert_int(BaseProduction.effective_production_cap(state, hq, 0)).is_equal(StructureTypes.HQ.production_cap)


# --- Producer resolution preconditions --------------------------------------

func test_produce_unknown_producer_id_is_rejected_no_such_entity() -> void:
	# Arrange -- an action naming a producer id that is not in entities_by_id.
	var state := _make_state()
	var action := _make_produce_action(999, UnitTypes.TROOPER, Vector2i(6, 5))
	# Act / Assert
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.NO_SUCH_ENTITY)


func test_produce_from_enemy_owned_producer_is_rejected_illegal_target() -> void:
	# Arrange -- a Completed Production Outpost owned by player 1, while player 0
	# is active.
	var state := _make_state()
	var enemy_producer := _make_structure(1, 1, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST)
	_place(state, enemy_producer)
	var action := _make_produce_action(enemy_producer.entity_id, UnitTypes.TROOPER, Vector2i(6, 5))
	# Act / Assert -- the active player cannot produce from an enemy's structure.
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_produce_from_non_producer_with_empty_producible_types_is_rejected() -> void:
	# Arrange -- a Completed Economy Outpost (producible_types == [], cap 0): a
	# non-producer. The empty-array membership check must uniformly reject any
	# unit type (distinct from the HQ "wrong type" case). NOT_PRODUCIBLE fires
	# before the cap gate (gate order: Completed -> producible -> cap).
	var state := _make_state(100)
	var econ := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.ECONOMY_OUTPOST)
	_place(state, econ)
	var action := _make_produce_action(econ.entity_id, UnitTypes.TROOPER, Vector2i(6, 5))
	# Act / Assert
	assert_int(BaseProduction.validate_produce(state, action)).is_equal(Action.Reason.NOT_PRODUCIBLE)
