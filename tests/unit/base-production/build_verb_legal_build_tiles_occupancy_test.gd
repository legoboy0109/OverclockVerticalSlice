# Base & Production Story 002: Build Verb, legal_build_tiles, Occupancy +
# Placement + Design-Rule Toggles.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-002-build-verb-legal-build-tiles-occupancy.md:
#   Occupancy (Rule 3): Under-Construction structure blocks movement + DIRECT
#     LoF + is a legal target (status-agnostic occupancy, no carve-out);
#     Impassable/occupied tile -> build() rejected / never in legal_build_tiles.
#   Building (Rule 4): affordable + legal tile -> build() spends AP, places
#     Under-Construction, blocks/targets immediately (one atomic apply);
#     fresh Under-Construction structure is inert for completed_outpost_count;
#     unaffordable -> rejected, AP/Grid unchanged; tile occupied between
#     preview and commit -> re-validated and rejected at apply.
#   Placement (Rule 5): legal (unit-adjacent, standoff clear); structure-
#     adjacency (unit OR structure satisfies adjacency); standoff == 2
#     excluded (strict > 2); no-adjacency excluded; empty candidate set;
#     HQ never a candidate; post-placement stability (no re-validation once
#     placed, even if the adjacent friendly later moves away).
#   Design-rule toggles: parallel construction (two builds same turn, AP-
#     gated only); Economy Tech does NOT discount effective_build_cost (flat
#     4 AP); effective_build_cost == base exactly under Neutral.
#
# Injected Grid + AP fixtures (GameStateFactory + a hand-built GridState),
# mirroring tests/unit/combat/attack_pipeline_ap_cost_test.gd's
# _make_grid/_make_state/_place style. Combat/Movement are not exercised here
# (out of this story's scope) — occupancy assertions read GridState directly
# (is_passable/occupant_at), which is what Movement/Combat themselves consult
# per ADR-0017 D2's "status-agnostic occupancy is a property of the shared
# Grid index" design (no per-status branch to test around).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

# ★ S7-06: local stand-in for the retired BaseProduction.completed_outpost_count(). The
# accessor was dead product code — nothing in src/ called it once S6-01 re-based income on
# research tiers — but the BEHAVIOUR these tests observe through it (a structure only counts
# once its build_status reaches COMPLETED) is real and still worth pinning. So the accessor
# goes and the observable stays, defined here rather than shipped.
func _completed_factory_count(state: GameState, player: int) -> int:
	var count: int = 0
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var s: StructureState = e
		if s.type == StructureTypes.FACTORY and s.build_status == StructureState.BuildStatus.COMPLETED:
			count += 1
	return count


const GRID_SIZE: int = 12


# --- Fixture builders --------------------------------------------------------

# Blank all-Plain grid, large enough for every fixture below (standoff-2
# exclusion tests need room around a structure).
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


# current_credits defaults to StructureTypes.FACTORY.build_cost (4, the
# Credit-denominated main cost post-pivot) so a legal build fixture is
# affordable unless a test explicitly drives it lower. current_ap defaults
# independently to Balance.economy.build_ap_cost (2, the AP surcharge) --
# the two pools have different scales under the ADR-0006 dual-cost pivot.
func _make_state(current_ap: int = -1, current_credits: int = -1) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	var ap: int = current_ap if current_ap >= 0 else Balance.economy.build_ap_cost
	var credits: int = current_credits if current_credits >= 0 else StructureTypes.FACTORY.build_cost
	state.per_player[0].current_ap = ap
	state.per_player[1].current_ap = ap
	state.per_player[0].current_credits = credits
	state.per_player[1].current_credits = credits
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


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


func _make_build_action(tile: Vector2i, structure_type: StructureTypeDef, player: int) -> BuildAction:
	var action := BuildAction.new()
	action.player = player
	action.structure_type = structure_type
	action.tile = tile
	return action


# --- Occupancy (Rule 3): status-agnostic, no intangible carve-out -----------

func test_under_construction_structure_blocks_movement_via_grid_is_passable() -> void:
	# Arrange -- a fresh Under-Construction structure sits on tile T.
	var state := _make_state()
	var structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.FACTORY, StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, structure)
	# Act / Assert -- T reports movement-blocked (not passable) purely by
	# occupying the shared Grid index -- no status branch anywhere.
	assert_bool(state.grid.is_passable(5, 5)).is_false()


func test_under_construction_structure_stops_direct_lof_walk_via_occupant_at() -> void:
	# Arrange -- an Under-Construction structure sits between two other tiles
	# on a cardinal line; occupant_at must resolve it (the same lookup
	# Combat._walk_direction uses to stop a DIRECT walk).
	var state := _make_state()
	var structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.FACTORY, StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, structure)
	# Act / Assert
	assert_int(state.grid.occupant_at(5, 5)).is_equal(1)
	assert_bool(state.grid.occupant_at(5, 5) != GridState.EMPTY_OCCUPANT).is_true()


func test_under_construction_structure_is_a_legal_target_resolvable_via_entity_at() -> void:
	# Arrange -- Combat's targeting resolves occupants via GameState.entity_at;
	# an Under-Construction structure must resolve identically to a Completed one.
	var state := _make_state()
	var structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.FACTORY, StructureState.BuildStatus.UNDER_CONSTRUCTION)
	_place(state, structure)
	# Act
	var resolved: EntityState = state.entity_at(Vector2i(5, 5))
	# Assert
	assert_object(resolved).is_same(structure)
	assert_int((resolved as StructureState).build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)


func test_impassable_tile_never_offered_and_build_there_is_rejected() -> void:
	# Arrange -- friendly unit adjacent to an Impassable tile that would
	# otherwise be a legal candidate (adjacency ok, no enemy structures).
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	state.grid.terrain[state.grid.index(6, 5)] = GridState.Terrain.IMPASSABLE
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- never offered.
	assert_bool(Vector2i(6, 5) in tiles).is_false()
	# Act -- build() there is rejected.
	var action := _make_build_action(Vector2i(6, 5), StructureTypes.FACTORY, 0)
	assert_int(BaseProduction.validate_build(state, action)).is_equal(Action.Reason.NOT_LEGAL_BUILD_TILE)


func test_occupied_tile_never_offered_and_build_there_is_rejected() -> void:
	# Arrange -- an otherwise-legal tile is already occupied by another entity.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	var occupant := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(6, 5))
	_place(state, unit)
	_place(state, occupant)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- never offered.
	assert_bool(Vector2i(6, 5) in tiles).is_false()
	# Act -- build() there is rejected.
	var action := _make_build_action(Vector2i(6, 5), StructureTypes.FACTORY, 0)
	assert_int(BaseProduction.validate_build(state, action)).is_equal(Action.Reason.NOT_LEGAL_BUILD_TILE)


# --- Building (Rule 4) -------------------------------------------------------

func test_affordable_legal_build_spends_credits_and_ap_surcharge_places_under_construction_blocks_and_targets() -> void:
	# Arrange -- a friendly unit with an adjacent legal tile, exactly enough
	# Credits (main cost) and AP (surcharge) via _make_state's defaults.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var tile := Vector2i(6, 5)
	var action := _make_build_action(tile, StructureTypes.FACTORY, 0)
	assert_int(BaseProduction.validate_build(state, action)).is_equal(Action.Reason.OK)
	# Act
	var events: Array[Event] = BaseProduction.apply_build(state, action)
	# Assert -- Credits spent exactly build_cost (4); AP spent exactly the
	# build_ap_cost surcharge (2).
	assert_int(state.per_player[0].current_credits).is_equal(0)
	assert_int(state.per_player[0].current_ap).is_equal(0)
	# A new StructureState exists, Under-Construction, placed on the grid.
	var placed: EntityState = state.entity_at(tile)
	assert_object(placed).is_not_null()
	assert_bool(placed is StructureState).is_true()
	var structure: StructureState = placed
	assert_int(structure.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(structure.owner).is_equal(0)
	assert_object(structure.type).is_same(StructureTypes.FACTORY)
	# Blocks/targets immediately (single atomic apply -- Grid already updated).
	assert_bool(state.grid.is_passable(tile.x, tile.y)).is_false()
	# One placement event.
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructurePlacedEvent).is_true()


func test_fresh_under_construction_structure_is_inert_for_completed_outpost_count() -> void:
	# Arrange -- a freshly built Economy Outpost (Under-Construction).
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var action := _make_build_action(Vector2i(6, 5), StructureTypes.FACTORY, 0)
	BaseProduction.apply_build(state, action)
	# Act / Assert -- zero contribution until Completed.
	assert_int(_completed_factory_count(state, 0)).is_equal(0)


func test_unaffordable_build_credits_short_rejected_credits_and_grid_unchanged() -> void:
	# Arrange -- current_credits one short of build_cost (4), the binding leg;
	# AP surcharge fully funded so CANT_AFFORD_CREDITS is unambiguously the
	# Credits gate firing, not the AP gate.
	var state := _make_state(-1, 3)
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var tile := Vector2i(6, 5)
	var action := _make_build_action(tile, StructureTypes.FACTORY, 0)
	# Act
	var reason: int = BaseProduction.validate_build(state, action)
	# Assert
	assert_int(reason).is_equal(Action.Reason.CANT_AFFORD_CREDITS)
	assert_int(state.per_player[0].current_credits).is_equal(3)
	assert_int(state.per_player[0].current_ap).is_equal(Balance.economy.build_ap_cost)
	assert_object(state.entity_at(tile)).is_null()
	# apply_build() itself must also refuse to mutate if called directly
	# against a still-failing validation (idempotent re-validation guard).
	var events: Array[Event] = BaseProduction.apply_build(state, action)
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_credits).is_equal(3)
	assert_int(state.per_player[0].current_ap).is_equal(Balance.economy.build_ap_cost)
	assert_object(state.entity_at(tile)).is_null()


func test_commit_revalidation_rejects_when_tile_becomes_occupied_between_preview_and_commit() -> void:
	# Arrange -- a legal tile at preview time, then occupied by something else
	# before apply_build() actually commits (simulates a stale preview).
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var tile := Vector2i(6, 5)
	var action := _make_build_action(tile, StructureTypes.FACTORY, 0)
	assert_int(BaseProduction.validate_build(state, action)).is_equal(Action.Reason.OK)
	# Act -- tile becomes occupied before commit.
	var intruder := _make_unit(2, 1, UnitTypes.SCOUT, tile)
	_place(state, intruder)
	var credits_before: int = state.per_player[0].current_credits
	var ap_before: int = state.per_player[0].current_ap
	var events: Array[Event] = BaseProduction.apply_build(state, action)
	# Assert -- rejected at commit, no Credits/AP spent, no structure placed.
	assert_array(events).is_empty()
	assert_int(state.per_player[0].current_credits).is_equal(credits_before)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_object(state.entity_at(tile)).is_same(intruder)


# --- Placement (Rule 5) ------------------------------------------------------

func test_tile_adjacent_to_friendly_unit_and_manhattan_3_from_enemy_structure_is_legal() -> void:
	# Arrange -- friendly unit at (5,5); candidate (6,5) is manhattan 1 from it
	# and manhattan 3 from the nearest enemy structure at (9,5).
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	var enemy_structure := _make_structure(2, 1, Vector2i(9, 5), StructureTypes.FACTORY)
	_place(state, unit)
	_place(state, enemy_structure)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert
	assert_bool(Vector2i(6, 5) in tiles).is_true()


func test_tile_adjacent_to_friendly_structure_not_unit_is_legal() -> void:
	# Arrange -- friendly STRUCTURE (not unit) at (5,5); no enemy structures at
	# all, so standoff trivially clears.
	var state := _make_state()
	var friendly_structure := _make_structure(1, 0, Vector2i(5, 5), StructureTypes.FACTORY)
	_place(state, friendly_structure)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- unit OR structure satisfies adjacency.
	assert_bool(Vector2i(6, 5) in tiles).is_true()


func test_tile_at_manhattan_exactly_2_from_enemy_structure_excluded_strict_boundary() -> void:
	# Arrange -- friendly unit at (5,5) so (7,5) is adjacency-eligible via its
	# own frontier scan path is NOT how this candidate arises -- instead place
	# the friendly unit directly adjacent to the standoff-violating tile:
	# unit at (6,4), candidate (6,5) is manhattan 1 from the unit and manhattan
	# EXACTLY 2 from an enemy structure at (6,7).
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(6, 4))
	var enemy_structure := _make_structure(2, 1, Vector2i(6, 7), StructureTypes.FACTORY)
	_place(state, unit)
	_place(state, enemy_structure)
	# Precondition -- manhattan(candidate, enemy) == 2 exactly.
	assert_int(state.grid.manhattan_distance(Vector2i(6, 5), Vector2i(6, 7))).is_equal(2)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- excluded (>2 strict required, exactly-2 does not clear).
	assert_bool(Vector2i(6, 5) in tiles).is_false()


func test_tile_far_from_enemy_but_not_adjacent_to_any_friendly_excluded() -> void:
	# Arrange -- friendly unit far away; enemy structures far away too, but the
	# candidate tile under test has no friendly neighbour at all.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	_place(state, unit)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- a tile with no friendly neighbour (e.g. far corner) is never a
	# candidate at all -- the candidate universe IS the friendly frontier.
	assert_bool(Vector2i(10, 10) in tiles).is_false()


func test_no_tile_satisfies_both_conditions_legal_build_tiles_is_empty() -> void:
	# Arrange -- the player's only unit is completely walled in by enemy
	# structures within standoff distance on every neighbour.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var n_struct := _make_structure(2, 1, Vector2i(5, 4), StructureTypes.FACTORY)
	var e_struct := _make_structure(3, 1, Vector2i(6, 5), StructureTypes.FACTORY)
	var s_struct := _make_structure(4, 1, Vector2i(5, 6), StructureTypes.FACTORY)
	var w_struct := _make_structure(5, 1, Vector2i(4, 5), StructureTypes.FACTORY)
	_place(state, n_struct)
	_place(state, e_struct)
	_place(state, s_struct)
	_place(state, w_struct)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- every neighbour is occupied by an enemy structure -- none pass
	# is_passable AND every candidate frontier tile is occupied, so the
	# result is empty (build unavailable).
	assert_array(tiles).is_empty()


func test_hq_never_offered_as_a_candidate_even_when_adjacent_to_friendly_unit() -> void:
	# Arrange -- HQ is a live structure like any other for occupancy purposes,
	# but legal_build_tiles never offers IT as a destination target -- it is
	# never a candidate because the candidate universe is EMPTY neighbour
	# tiles of the player's own entities, not existing structures themselves.
	# This test instead pins the "HQ never appears in the returned set" AC by
	# confirming the HQ's own tile (occupied) is correctly excluded like any
	# other occupied tile, and that legal_build_tiles never special-cases HQ
	# identity to re-include it.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	var hq := _make_structure(2, 0, Vector2i(6, 5), StructureTypes.HQ, StructureState.BuildStatus.COMPLETED)
	_place(state, unit)
	_place(state, hq)
	# Act
	var tiles := BaseProduction.legal_build_tiles(state, 0, StructureTypes.FACTORY)
	# Assert -- the HQ's own occupied tile is never offered (occupied, like
	# any other occupant) -- no HQ-identity special-case re-adds it.
	assert_bool(Vector2i(6, 5) in tiles).is_false()


func test_structure_placed_adjacent_to_unit_that_later_moves_away_remains_no_reevaluation() -> void:
	# Arrange -- build a structure adjacent to a friendly unit.
	var state := _make_state()
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var tile := Vector2i(6, 5)
	var action := _make_build_action(tile, StructureTypes.FACTORY, 0)
	BaseProduction.apply_build(state, action)
	assert_object(state.entity_at(tile)).is_not_null()
	# Act -- the unit "moves away" (simulated directly via Grid, out of this
	# story's Movement scope) -- no re-validation call exists to remove the
	# already-placed structure.
	state.grid.remove(unit.position.x, unit.position.y)
	unit.position = Vector2i(0, 0)
	state.grid.place(unit.entity_id, 0, 0)
	# Assert -- the structure remains in place, untouched.
	assert_object(state.entity_at(tile)).is_not_null()
	assert_int((state.entity_at(tile) as StructureState).entity_id).is_equal((state.entity_at(tile) as StructureState).entity_id)


# --- Design-rule toggles ------------------------------------------------------

func test_two_builds_same_turn_both_succeed_parallel_construction_ap_gated() -> void:
	# Arrange -- dual-cost pivot: fund BOTH pools for two Economy Outposts --
	# Credits = 2 * build_cost (4+4=8), AP = 2 * build_ap_cost (2+2=4) -- two
	# separate friendly-adjacent legal tiles.
	var state := _make_state(Balance.economy.build_ap_cost * 2, StructureTypes.FACTORY.build_cost * 2)
	var unit := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var tile_a := Vector2i(6, 5)
	var tile_b := Vector2i(4, 5)
	var action_a := _make_build_action(tile_a, StructureTypes.FACTORY, 0)
	# Act -- first build.
	assert_int(BaseProduction.validate_build(state, action_a)).is_equal(Action.Reason.OK)
	BaseProduction.apply_build(state, action_a)
	# Act -- second build, same turn.
	var action_b := _make_build_action(tile_b, StructureTypes.FACTORY, 0)
	assert_int(BaseProduction.validate_build(state, action_b)).is_equal(Action.Reason.OK)
	var events_b: Array[Event] = BaseProduction.apply_build(state, action_b)
	# Assert -- both succeeded; both pools fully spent (Credits 8-4-4=0, AP 4-2-2=0).
	assert_int(events_b.size()).is_equal(1)
	assert_object(state.entity_at(tile_a)).is_not_null()
	assert_object(state.entity_at(tile_b)).is_not_null()
	assert_int(state.per_player[0].current_credits).is_equal(0)
	assert_int(state.per_player[0].current_ap).is_equal(0)


func test_economy_tech_does_not_discount_effective_build_cost_flat_four() -> void:
	# Arrange -- player has researched Economy Tech.
	var state := _make_state()
	state.per_player[0].economy_tier = 1
	# Act / Assert -- effective_build_cost is unmodified: flat 4 AP, no
	# factory_discount hook.
	# ★ S6-09: derived from the type, not hardcoded. This test is about the ABSENCE
	# of an economy-tech discount hook; pinning the literal cost made it fail when
	# the Factory was re-statted to its design values, which is unrelated churn.
	assert_int(BaseProduction.effective_build_cost(state, StructureTypes.FACTORY, 0)) \
		.is_equal(StructureTypes.FACTORY.build_cost)


func test_effective_build_cost_equals_base_exactly_under_neutral() -> void:
	# Arrange -- VS Neutral default (no faction assigned).
	var state := _make_state()
	# Act / Assert -- == base exactly, for both cost and time.
	assert_int(BaseProduction.effective_build_cost(state, StructureTypes.FACTORY, 0)).is_equal(StructureTypes.FACTORY.build_cost)
	assert_int(BaseProduction.effective_build_time(state, StructureTypes.FACTORY, 0)).is_equal(StructureTypes.FACTORY.build_time)
	assert_int(BaseProduction.effective_build_cost(state, StructureTypes.BARRACKS, 0)).is_equal(StructureTypes.BARRACKS.build_cost)
	assert_int(BaseProduction.effective_build_time(state, StructureTypes.BARRACKS, 0)).is_equal(StructureTypes.BARRACKS.build_time)
