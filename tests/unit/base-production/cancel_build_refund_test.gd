# Base & Production Story 005: Cancel Build & Fixed-Point Refund.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-005-cancel-build-refund.md:
#   Cancel (Rule 10): an Under-Construction Economy/Production/Defensive
#     structure cancelled -> floor(cost*0.5) = 2/4/3 AP credited, structure
#     removed, tile empties; a Completed structure -> rejected (no refund,
#     unchanged, only combat-destroyed); combat destruction never routes through
#     cancel_build so it never refunds; the credited refund rides on the returned
#     ActionResult's event (presentation reads it, never re-derives).
#   Formula (fixed-point floor): cancel_refund(4/9/6) == 2/4/3; odd cost 5 -> 2
#     (integer division floors, not rounds).
#
# Injected Grid + AP fixtures (GameStateFactory + a hand-built GridState),
# mirroring build_verb_legal_build_tiles_occupancy_test.gd's _make_grid/
# _make_state/_place style. Cancel is the active player's voluntary action, so
# owner == active_player == 0 throughout (Credits.credit is active-player-gated
# like Credits.spend/AP.spend). The refund credits real Credits via
# Credits.credit (ADR-0006 pivot — the AP surcharge is not refunded), so
# current_credits is set explicitly per test and asserted after.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 12


# --- Fixture builders --------------------------------------------------------

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


func _make_state(current_ap: int = 0, current_credits: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].current_ap = current_ap
	state.per_player[1].current_ap = current_ap
	state.per_player[0].current_credits = current_credits
	state.per_player[1].current_credits = current_credits
	return state


func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, status: int = StructureState.BuildStatus.UNDER_CONSTRUCTION) -> StructureState:
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


func _make_cancel_action(structure_id: int, player: int = 0) -> CancelBuildAction:
	var action := CancelBuildAction.new()
	action.player = player
	action.structure_id = structure_id
	return action


# --- Cancel (Rule 10): refund per structure type ----------------------------

func test_cancel_under_construction_factory_credits_2_removes_and_empties_tile() -> void:
	# Arrange -- an Under-Construction Economy Outpost (build_cost 4 -> refund 2).
	var state := _make_state()
	var tile := Vector2i(5, 5)
	var structure := _make_structure(1, 0, tile, StructureTypes.FACTORY)
	_place(state, structure)
	var next_id_before: int = state.next_entity_id
	var action := _make_cancel_action(structure.entity_id)
	assert_int(BaseProduction.validate_cancel(state, action)).is_equal(Action.Reason.OK)
	# Act
	var events: Array[Event] = BaseProduction.apply_cancel(state, action)
	# ★ S6-02: derived, not restated -- the ×100 rescale moved build_cost 4 -> 400 and
	# the refund with it. cancel_refund_pct is a RATE and is unaffected.
	var expected_refund: int = StructureTypes.FACTORY.build_cost * StructureBalance.base_production.cancel_refund_pct / 100
	assert_int(state.per_player[0].current_credits).is_equal(expected_refund)
	# Structure removed from the entity map and the grid; tile now empty.
	assert_bool(state.entities_by_id.has(structure.entity_id)).is_false()
	assert_object(state.entity_at(tile)).is_null()
	assert_int(state.grid.occupant_at(tile.x, tile.y)).is_equal(GridState.EMPTY_OCCUPANT)
	assert_bool(state.grid.is_passable(tile.x, tile.y)).is_true()
	# Erasing an entity must not touch the id allocator (cancel is not a spawn).
	assert_int(state.next_entity_id).is_equal(next_id_before)
	# One cancel event.
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructureCancelledEvent).is_true()


func test_cancel_under_construction_barracks_credits_4_removes_and_empties_tile() -> void:
	# Arrange -- Production Outpost (build_cost 9 -> refund 4).
	var state := _make_state()
	var tile := Vector2i(5, 5)
	var structure := _make_structure(1, 0, tile, StructureTypes.BARRACKS)
	_place(state, structure)
	# Act
	BaseProduction.apply_cancel(state, _make_cancel_action(structure.entity_id))
	# ★ S6-02: derived, not restated -- the ×100 rescale moved build_cost 9 -> 900.
	# Removal dimensions still checked per-type so a per-type divergence would be caught.
	var expected_refund_po: int = StructureTypes.BARRACKS.build_cost \
		* StructureBalance.base_production.cancel_refund_pct / 100
	assert_int(state.per_player[0].current_credits).is_equal(expected_refund_po)
	assert_bool(state.entities_by_id.has(structure.entity_id)).is_false()
	assert_int(state.grid.occupant_at(tile.x, tile.y)).is_equal(GridState.EMPTY_OCCUPANT)


func test_cancel_under_construction_defensive_structure_credits_3_removes_and_empties_tile() -> void:
	# Arrange -- Defensive Structure (build_cost 6 -> refund 3).
	var state := _make_state()
	var tile := Vector2i(5, 5)
	var structure := _make_structure(1, 0, tile, StructureTypes.DEFENSIVE_STRUCTURE)
	_place(state, structure)
	# Act
	BaseProduction.apply_cancel(state, _make_cancel_action(structure.entity_id))
	# Assert -- floor(6*0.5) = 3; removal dimensions checked per-type.
	assert_int(state.per_player[0].current_credits).is_equal(300)  # ★ S6-02: ×100 Credit rescale
	assert_bool(state.entities_by_id.has(structure.entity_id)).is_false()
	assert_int(state.grid.occupant_at(tile.x, tile.y)).is_equal(GridState.EMPTY_OCCUPANT)


func test_cancel_refund_adds_to_existing_credits_not_overwrite() -> void:
	# Arrange -- the player already has 10 Credits; cancelling an Economy Outpost
	# (refund 2) must CREDIT (add), not overwrite, the pool.
	var state := _make_state(0, 10)
	var structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.FACTORY)
	_place(state, structure)
	# Act
	BaseProduction.apply_cancel(state, _make_cancel_action(structure.entity_id))
	# ★ S6-02: derived, not restated -- the ×100 rescale moved the refund with build_cost.
	# The claim under test is that the refund is ADDITIVE onto an existing balance.
	var refund: int = StructureTypes.FACTORY.build_cost \
		* StructureBalance.base_production.cancel_refund_pct / 100
	assert_int(state.per_player[0].current_credits).is_equal(10 + refund)


# --- Cancel rejection: Completed structures cannot be cancelled --------------

func test_cancel_completed_structure_rejected_no_refund_unchanged() -> void:
	# Arrange -- a Completed Economy Outpost. Completed structures are only
	# combat-destroyed, never cancelled (Rule 10).
	var state := _make_state()
	var tile := Vector2i(5, 5)
	var structure := _make_structure(1, 0, tile, StructureTypes.FACTORY, StructureState.BuildStatus.COMPLETED)
	_place(state, structure)
	var action := _make_cancel_action(structure.entity_id)
	# Act / Assert -- validate rejects.
	assert_int(BaseProduction.validate_cancel(state, action)).is_equal(Action.Reason.NOT_UNDER_CONSTRUCTION)
	# apply_cancel refuses to mutate too (idempotent re-validation): no refund,
	# structure still present, tile still occupied.
	var events: Array[Event] = BaseProduction.apply_cancel(state, action)
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_credits).is_equal(0)
	assert_object(state.entity_at(tile)).is_same(structure)
	assert_int(state.grid.occupant_at(tile.x, tile.y)).is_equal(structure.entity_id)


func test_cancel_not_owned_structure_rejected_illegal_target() -> void:
	# Arrange -- an Under-Construction structure owned by player 1, while player 0
	# is active. You cannot cancel an opponent's build.
	var state := _make_state()
	var structure := _make_structure(1, 1, Vector2i(5, 5), StructureTypes.FACTORY)
	_place(state, structure)
	var action := _make_cancel_action(structure.entity_id)
	# Act / Assert
	assert_int(BaseProduction.validate_cancel(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)
	var events: Array[Event] = BaseProduction.apply_cancel(state, action)
	assert_array(events).is_empty()
	assert_object(state.entity_at(Vector2i(5, 5))).is_same(structure)
	# No refund credited to either pool on a rejected cancel.
	assert_int(state.per_player[0].current_credits).is_equal(0)
	assert_int(state.per_player[1].current_credits).is_equal(0)


func test_cancel_unknown_structure_id_rejected_no_such_entity() -> void:
	# Arrange -- an action naming a structure id not in entities_by_id.
	var state := _make_state()
	var action := _make_cancel_action(999)
	# Act / Assert
	assert_int(BaseProduction.validate_cancel(state, action)).is_equal(Action.Reason.NO_SUCH_ENTITY)
	assert_array(BaseProduction.apply_cancel(state, action)).is_empty()


# --- Refund rides on the result event (presentation reads it) ---------------

func test_cancel_result_event_carries_refund_and_identity() -> void:
	# Arrange -- Production Outpost. ★ S6-02: refund derives from build_cost, which the
	# ×100 Credit rescale moved 9 -> 900.
	var state := _make_state(0)
	var tile := Vector2i(5, 5)
	var structure := _make_structure(1, 0, tile, StructureTypes.BARRACKS)
	_place(state, structure)
	# Act
	var events: Array[Event] = BaseProduction.apply_cancel(state, _make_cancel_action(structure.entity_id))
	# Assert -- the event carries the refund amount + full identity, so the
	# FSM/HUD render the credited AP from the event rather than re-deriving it.
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructureCancelledEvent).is_true()
	var evt: StructureCancelledEvent = events[0]
	assert_int(evt.refund).is_equal(StructureTypes.BARRACKS.build_cost \
		* StructureBalance.base_production.cancel_refund_pct / 100)
	assert_int(evt.entity_id).is_equal(structure.entity_id)
	assert_object(evt.structure_type).is_same(StructureTypes.BARRACKS)
	assert_int(evt.owner).is_equal(0)
	assert_int(evt.tile.x).is_equal(tile.x)
	assert_int(evt.tile.y).is_equal(tile.y)


# --- Combat destruction is a separate, no-refund path (Rule 10 boundary) -----

func test_combat_destruction_is_a_separate_path_completed_yields_no_cancel_refund() -> void:
	# The refund lives solely on the CANCEL_BUILD verb path (apply_cancel ->
	# cancel_refund). Combat destruction's terminal exit is GameState.destroy_entity
	# (ADR-0010, Base & Production Story 007 / Combat) which never calls
	# cancel_build, so it never refunds. destroy_entity does not exist yet, so the
	# testable slice here is the invariant that keeps a refund off the destruction
	# path: a Completed structure (the state a built structure sits in when combat
	# destroys it) cannot be cancelled at all -> zero AP credited via cancel. The
	# under-construction destroy_entity contrast is Story 010's integration case.
	var state := _make_state(0)
	var structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.BARRACKS, StructureState.BuildStatus.COMPLETED)
	_place(state, structure)
	# Act -- attempt to cancel the Completed structure.
	var events: Array[Event] = BaseProduction.apply_cancel(state, _make_cancel_action(structure.entity_id))
	# Assert -- no refund reaches the pool through any cancel attempt.
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_ap).is_equal(0)


# --- Formula (fixed-point floor via integer division) -----------------------

func test_cancel_refund_formula_floors_via_integer_division() -> void:
	# The boundary values ARE the point (test-standards exception): refund =
	# build_cost * cancel_refund_pct(50) / 100 truncates toward zero = floor for
	# these non-negative operands.
	assert_int(BaseProduction.cancel_refund(0)).is_equal(0) # 0-cost boundary (e.g. HQ): 0*50/100 = 0, a valid 0-refund
	assert_int(BaseProduction.cancel_refund(4)).is_equal(2) # Economy Outpost
	assert_int(BaseProduction.cancel_refund(9)).is_equal(4) # Production Outpost (9*50/100 = 4, floor of 4.5)
	assert_int(BaseProduction.cancel_refund(6)).is_equal(3) # Defensive Structure
	assert_int(BaseProduction.cancel_refund(5)).is_equal(2) # odd fixture cost: 5*50/100 = 2 (floors, not rounds to 3)
	# Reads the live config value, not a hardcoded 50 -- the registry consts back
	# these build_costs, and the refunds match the real .tres cancel_refund_pct.
	# ★ S6-02: derived from the live build_cost, which the ×100 rescale moved. The claim
	# under test is the FLOORING (integer division), proven by the odd-cost fixtures above.
	var pct: int = StructureBalance.base_production.cancel_refund_pct
	for st: StructureTypeDef in [StructureTypes.FACTORY, StructureTypes.BARRACKS, \
			StructureTypes.DEFENSIVE_STRUCTURE]:
		assert_int(BaseProduction.cancel_refund(st.build_cost)).is_equal(st.build_cost * pct / 100)
