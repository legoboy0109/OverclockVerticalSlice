# Story 003: AREA Targeting, Ring Invariant & Hypothetical-Tile Overload.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-003-area-targeting-hypothetical-overload.md:
#   AC-1: AREA ignores line-of-fire (friendly blocker / Impassable terrain edge case).
#   AC-2: dead zone (< min_range) and beyond-max (> attack_range) both excluded.
#   AC-3: inclusive ring boundaries (== min_range and == attack_range both included).
#   AC-4: illegal schema invariant (min_range > attack_range) -> empty + has_valid_targeting_schema() == false.
#   AC-5: hypothetical-tile parity (from_tile == position) for both DIRECT and AREA.
#   AC-6: hypothetical-tile actually hypothetical (candidate tile finds a target the real position can't).
#   AC-7: purity — legal_targets_from() never mutates state/grid/attacker.position.
#
# Fixtures: AREA units use a throwaway UnitTypeDef.new() (min_range 2,
# attack_range 4, targeting_mode AREA) since no VS roster unit is AREA, per
# the story's own fixture guidance. DIRECT fixtures reuse the real
# UnitTypes.TROOPER/SCOUT roster stats, mirroring direct_targeting_test.gd's
# fixture style.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders --------------------------------------------------------

# Blank all-Plain grid, with an optional list of Impassable tiles painted in.
func _make_grid(impassable_tiles: Array[Vector2i] = []) -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	for tile: Vector2i in impassable_tiles:
		grid.terrain[grid.index(tile.x, tile.y)] = GridState.Terrain.IMPASSABLE
	return grid


func _make_state(impassable_tiles: Array[Vector2i] = []) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid(impassable_tiles)
	return state


# Throwaway AREA UnitTypeDef fixture (min_range 2, attack_range 4) — the
# story's own fixture guidance: a fresh Resource.new(), never load()'d, since
# no VS roster unit is AREA.
func _make_area_type(min_range: int = 2, attack_range: int = 4) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "AreaTestFixture"
	type.hp = 10
	type.attack = 3
	type.attack_range = attack_range
	type.move_cost = 1
	type.soft_move_cap = 3
	type.produce_cost = 1
	type.defense = 0
	type.targeting_mode = UnitTypeDef.TargetingMode.AREA
	type.min_range = min_range
	type.can_counterattack = false
	return type


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _make_structure(entity_id: int, owner: int, pos: Vector2i) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	return structure


# Registers an entity into both grid occupancy and entities_by_id, so
# state.entity_at() resolves it the way Combat's scan/walk requires.
func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# Returns true if a Combat.TargetResult array contains a target_id.
func _contains_target(results: Array[Combat.TargetResult], target_id: int) -> bool:
	for r: Combat.TargetResult in results:
		if r.target_id == target_id:
			return true
	return false


# --- AC-1: AREA ignores line-of-fire -----------------------------------------

func test_area_attacker_ignores_friendly_blocker_between_attacker_and_target() -> void:
	# Arrange — AREA attacker (min_range 2, attack_range 4) at (0,0), a
	# friendly unit directly between attacker and target (east, distance 1),
	# an enemy at distance 3 (east).
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var friendly_between := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0))
	var enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, attacker)
	_place(state, friendly_between)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — the enemy is targetable despite the intervening friendly (LoF ignored).
	assert_bool(_contains_target(results, 3)).is_true()


func test_area_attacker_ignores_impassable_terrain_between_attacker_and_target() -> void:
	# Arrange — same as above, but the intervening tile is Impassable terrain
	# instead of a friendly unit.
	var impassable_tile := Vector2i(1, 0)
	var state := _make_state([impassable_tile])
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — still targetable; AREA "arcs over" terrain too.
	assert_bool(_contains_target(results, 2)).is_true()


# --- AC-2: dead zone + beyond-max ---------------------------------------------

func test_enemy_inside_dead_zone_distance_one_is_not_targetable() -> void:
	# Arrange — AREA attacker (min_range 2, attack_range 4), enemy at distance 1
	# (< min_range).
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert
	assert_bool(_contains_target(results, 2)).is_false()


func test_enemy_beyond_max_range_distance_five_is_not_targetable() -> void:
	# Arrange — same attacker, enemy at distance 5 (> attack_range 4).
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(5, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert
	assert_bool(_contains_target(results, 2)).is_false()


func test_dead_zone_and_beyond_max_both_absent_simultaneously() -> void:
	# Arrange — both edge enemies present at once (AC-2's exact scenario): one
	# at distance 1 (dead zone), one at distance 5 (beyond max). Neither present.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var near_enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	var far_enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(5, 0))
	_place(state, attacker)
	_place(state, near_enemy)
	_place(state, far_enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — this is a LEGITIMATELY empty ring (no schema violation): both
	# candidates are ordinarily out-of-band, distinct from AC-4's schema-error case.
	assert_array(results).is_empty()
	assert_bool(Combat.has_valid_targeting_schema(attacker)).is_true()


# --- AC-3: inclusive ring boundaries -------------------------------------------

func test_enemy_at_exactly_min_range_distance_two_is_targetable() -> void:
	# Arrange — enemy at exactly distance 2 (== min_range) — inclusive lower bound.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert
	assert_bool(_contains_target(results, 2)).is_true()


func test_enemy_at_exactly_attack_range_distance_four_is_targetable() -> void:
	# Arrange — enemy at exactly distance 4 (== attack_range) — inclusive upper bound.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(4, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert
	assert_bool(_contains_target(results, 2)).is_true()


func test_both_inclusive_boundaries_and_both_exclusive_neighbors_off_by_one_guard() -> void:
	# Arrange — the full off-by-one guard in one board: distances 1 (excluded),
	# 2 (included), 4 (included), 5 (excluded), all simultaneously present.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var d1 := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	var d2 := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	var d4 := _make_unit(4, 1, UnitTypes.SCOUT, Vector2i(0, 4))
	var d5 := _make_unit(5, 1, UnitTypes.SCOUT, Vector2i(5, 0))
	_place(state, attacker)
	_place(state, d1)
	_place(state, d2)
	_place(state, d4)
	_place(state, d5)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert
	assert_bool(_contains_target(results, 2)).is_false() # distance 1, excluded
	assert_bool(_contains_target(results, 3)).is_true()  # distance 2, included
	assert_bool(_contains_target(results, 4)).is_true()  # distance 4, included
	assert_bool(_contains_target(results, 5)).is_false() # distance 5, excluded


# --- AC-4: illegal schema invariant --------------------------------------------

func test_illegal_schema_min_range_greater_than_attack_range_yields_empty_and_predicate_false() -> void:
	# Arrange — an AREA fixture with min_range 5, attack_range 3 (min > max) —
	# an illegal schema state — with an enemy placed at a variety of distances
	# so an ordinary out-of-band placement can't be confused with this case.
	var state := _make_state()
	var bad_type := _make_area_type(5, 3)
	var attacker := _make_unit(1, 0, bad_type, Vector2i(0, 0))
	var enemy_near := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	var enemy_mid := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	var enemy_far := _make_unit(4, 1, UnitTypes.SCOUT, Vector2i(5, 0))
	_place(state, attacker)
	_place(state, enemy_near)
	_place(state, enemy_mid)
	_place(state, enemy_far)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — BOTH halves distinguish this from AC-2's ordinary empty ring:
	# the predicate is what proves this is a genuine schema violation, not
	# merely "no enemy currently in range."
	assert_array(results).is_empty()
	assert_bool(Combat.has_valid_targeting_schema(attacker)).is_false()


func test_valid_schema_min_range_less_than_or_equal_attack_range_predicate_true() -> void:
	# Arrange — a legitimately-configured AREA unit (min_range 2 <= attack_range 4).
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	# Act / Assert
	assert_bool(Combat.has_valid_targeting_schema(attacker)).is_true()


func test_direct_unit_always_satisfies_schema_invariant() -> void:
	# Arrange — DIRECT roster units default min_range=1, always <= attack_range.
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	# Act / Assert
	assert_bool(Combat.has_valid_targeting_schema(trooper)).is_true()


# --- AC-5: hypothetical-tile parity (from_tile == position) -------------------

func test_direct_unit_legal_targets_from_own_position_matches_legal_targets() -> void:
	# Arrange — a DIRECT unit (Trooper) with a genuinely non-empty legal_targets()
	# result (an enemy in range).
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	# Act
	var zero_arg: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	var from_tile: Array[Combat.TargetResult] = Combat.legal_targets_from(state, trooper, trooper.position)
	# Assert — non-empty and identical (same target_ids/tiles), not "both empty."
	assert_int(zero_arg.size()).is_equal(1)
	assert_int(from_tile.size()).is_equal(zero_arg.size())
	assert_int(from_tile[0].target_id).is_equal(zero_arg[0].target_id)
	assert_vector(from_tile[0].tile).is_equal(zero_arg[0].tile)


func test_area_unit_legal_targets_from_own_position_matches_legal_targets() -> void:
	# Arrange — an AREA unit with a genuinely non-empty legal_targets() result
	# (an enemy inside the ring).
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, attacker)
	_place(state, enemy)
	# Act
	var zero_arg: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	var from_tile: Array[Combat.TargetResult] = Combat.legal_targets_from(state, attacker, attacker.position)
	# Assert — non-empty and identical (same target_ids/tiles).
	assert_int(zero_arg.size()).is_equal(1)
	assert_int(from_tile.size()).is_equal(zero_arg.size())
	assert_int(from_tile[0].target_id).is_equal(zero_arg[0].target_id)
	assert_vector(from_tile[0].tile).is_equal(zero_arg[0].tile)


# --- AC-6: hypothetical-tile actually hypothetical -----------------------------

func test_direct_unit_hypothetical_tile_finds_target_real_position_cannot() -> void:
	# Arrange — Trooper (range 2) at (0,0) with NO legal target from its real
	# position (enemy too far east), but a candidate tile (3,0) would put the
	# enemy at distance 1 — a legal target from that hypothetical origin.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(4, 0))
	_place(state, trooper)
	_place(state, enemy)
	var candidate_tile := Vector2i(3, 0)
	# Act
	var real_position_results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	var hypothetical_results: Array[Combat.TargetResult] = Combat.legal_targets_from(state, trooper, candidate_tile)
	# Assert
	assert_array(real_position_results).is_empty()
	assert_int(hypothetical_results.size()).is_equal(1)
	assert_int(hypothetical_results[0].target_id).is_equal(2)
	# The unit's actual position field is unchanged after the call.
	assert_vector(trooper.position).is_equal(Vector2i(0, 0))


func test_area_unit_hypothetical_tile_finds_target_real_position_cannot() -> void:
	# Arrange — AREA attacker (min_range 2, attack_range 4) at (0,0) with the
	# enemy at distance 1 from the real position (dead zone, no target), but a
	# candidate tile (2,0) puts the enemy at distance 3 — inside the ring.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, attacker)
	_place(state, enemy)
	var candidate_tile := Vector2i(-2, 0)
	# Act
	var real_position_results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	var hypothetical_results: Array[Combat.TargetResult] = Combat.legal_targets_from(state, attacker, candidate_tile)
	# Assert
	assert_array(real_position_results).is_empty()
	assert_int(hypothetical_results.size()).is_equal(1)
	assert_int(hypothetical_results[0].target_id).is_equal(2)
	# The unit's actual position field is unchanged after the call.
	assert_vector(attacker.position).is_equal(Vector2i(0, 0))


# --- AC-7: purity/no mutation ---------------------------------------------------

func test_legal_targets_from_does_not_mutate_state_grid_or_attacker_direct() -> void:
	# Arrange — a DIRECT unit/board where legal_targets_from() is called with a
	# hypothetical origin distinct from the real position.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(3, 3))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(4, 3))
	_place(state, trooper)
	_place(state, enemy)
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var entity_count_before: int = state.entities_by_id.size()
	var position_before := trooper.position
	# Act
	Combat.legal_targets_from(state, trooper, Vector2i(0, 0))
	Combat.legal_targets_from(state, trooper, trooper.position)
	# Assert — grid occupancy, entity roster, and the attacker's position are
	# byte-for-byte unchanged.
	assert_array(state.grid.occupancy).is_equal(occupancy_before)
	assert_int(state.entities_by_id.size()).is_equal(entity_count_before)
	assert_vector(trooper.position).is_equal(position_before)


func test_legal_targets_from_does_not_mutate_state_grid_or_attacker_area() -> void:
	# Arrange — an AREA unit/board where legal_targets_from() is called with a
	# hypothetical origin distinct from the real position.
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(3, 3))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(5, 3))
	_place(state, attacker)
	_place(state, enemy)
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var entity_count_before: int = state.entities_by_id.size()
	var position_before := attacker.position
	# Act
	Combat.legal_targets_from(state, attacker, Vector2i(0, 0))
	Combat.legal_targets_from(state, attacker, attacker.position)
	# Assert
	assert_array(state.grid.occupancy).is_equal(occupancy_before)
	assert_int(state.entities_by_id.size()).is_equal(entity_count_before)
	assert_vector(attacker.position).is_equal(position_before)


# --- Enemy structure inside the ring is a legal AREA target -------------------
# Mirrors direct_targeting_test.gd's enemy-structure-as-target coverage: ring
# membership is decided by ownership (occupant.owner != attacker.owner), not by
# occupant kind — an enemy STRUCTURE (HQ/outpost) inside the ring is targetable
# exactly like an enemy unit.

func test_enemy_structure_inside_ring_is_legal_area_target() -> void:
	# Arrange — AREA attacker (min_range 2, attack_range 4), an enemy structure
	# at distance 3 (inside the ring).
	var state := _make_state()
	var area_type := _make_area_type()
	var attacker := _make_unit(1, 0, area_type, Vector2i(0, 0))
	var enemy_structure := _make_structure(2, 1, Vector2i(3, 0))
	_place(state, attacker)
	_place(state, enemy_structure)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — the enemy structure is a legal target (ownership decides, not kind).
	assert_bool(_contains_target(results, 2)).is_true()


# --- Degenerate ring (min_range == attack_range) — single-radius diamond -------
# Boundary: when min_range == attack_range the ring collapses to exactly one
# Manhattan radius. The dist < min_range or dist > attack_range guard degenerates
# to "dist != min_range" — only enemies at exactly that distance are targetable.

func test_degenerate_ring_min_equals_max_only_exact_distance_targetable() -> void:
	# Arrange — AREA attacker with min_range 2 == attack_range 2 at (0,0); three
	# enemies at distances 1 (inside), 2 (exact — the only legal ring), 3 (outside).
	var state := _make_state()
	var degenerate_type := _make_area_type(2, 2)
	var attacker := _make_unit(1, 0, degenerate_type, Vector2i(0, 0))
	var d1 := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0)) # distance 1, excluded
	var d2 := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0)) # distance 2, the only band
	var d3 := _make_unit(4, 1, UnitTypes.SCOUT, Vector2i(3, 0)) # distance 3, excluded
	_place(state, attacker)
	_place(state, d1)
	_place(state, d2)
	_place(state, d3)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, attacker)
	# Assert — a valid (min <= max) degenerate ring: only the exact-distance enemy.
	assert_bool(Combat.has_valid_targeting_schema(attacker)).is_true()
	assert_bool(_contains_target(results, 2)).is_false() # distance 1
	assert_bool(_contains_target(results, 3)).is_true()  # distance 2 (exact)
	assert_bool(_contains_target(results, 4)).is_false() # distance 3
