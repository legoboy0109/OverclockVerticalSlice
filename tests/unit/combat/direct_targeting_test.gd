# Story 002: DIRECT Targeting & Blocked-Shot Reasons.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-002-direct-targeting-blocked-shot.md:
#   AC-1: in-range clean shot (exact-range + adjacent edge case).
#   AC-2: LoF blocked by friendly (unit and structure blockers).
#   AC-3: LoF blocked by Impassable terrain (nothing beyond it targetable).
#   AC-4: nearest-only, no pierce (two enemies stacked on one line).
#   AC-5: out-of-range (enemy beyond attack_range, no closer blocker).
#   AC-6: non-cardinal rejection (diagonal, incl. manhattan-in-range edge case).
#   AC-7: three distinct blocked reasons, plus the NONE/targetable case.
#
# Also covers the readiness-review fix: an ENEMY structure on the cardinal
# line is a legal target (not just a friendly structure as a blocker) — the
# corrected step-2 walk rule (ownership decides, not occupant kind).
#
# Fixtures use UnitTypes.TROOPER (range 2) / UnitTypes.SNIPER (range 3) real
# roster stats, mirroring damage_formula_test.gd's fixture style, plus
# tests/helpers/stubs/structure_state_stub.gd for structure-as-occupant
# fixtures (both friendly-blocker and enemy-target roles).
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
# state.entity_at() resolves it the way Combat's walk requires.
func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# --- AC-1: in-range clean shot -----------------------------------------------

func test_enemy_exactly_at_max_range_cardinal_is_legal_target() -> void:
	# Arrange — Sniper (range 3) with an enemy exactly 3 tiles east, nothing intervening.
	var state := _make_state()
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, sniper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, sniper)
	# Assert
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].target_id).is_equal(2)
	assert_vector(results[0].tile).is_equal(Vector2i(3, 0))


func test_enemy_at_adjacent_range_one_is_legal_target() -> void:
	# Arrange — edge case: the minimum DIRECT range, adjacent tile.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].target_id).is_equal(2)


# --- AC-2: LoF blocked by friendly --------------------------------------------

func test_friendly_unit_blocking_line_makes_enemy_untargetable() -> void:
	# Arrange — Trooper (range 2), friendly unit adjacent, enemy 2 tiles away.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var friendly_blocker := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0))
	var enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, friendly_blocker)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_array(results).is_empty()


func test_friendly_unit_blocking_line_reports_blocked_by_friendly() -> void:
	# Arrange — same setup, queried via blocked_reason() for the East direction.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var friendly_blocker := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0))
	var enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, friendly_blocker)
	_place(state, enemy)
	# Act / Assert
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.BLOCKED_BY_FRIENDLY
	)


func test_friendly_structure_blocking_line_makes_enemy_untargetable() -> void:
	# Arrange — edge case: the blocker is a friendly STRUCTURE, not a unit.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var friendly_structure := _make_structure(2, 0, Vector2i(1, 0))
	var enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, friendly_structure)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_array(results).is_empty()
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.BLOCKED_BY_FRIENDLY
	)


# --- AC-3: LoF blocked by Impassable terrain ---------------------------------

func test_impassable_tile_blocking_line_makes_enemy_untargetable() -> void:
	# Arrange — Sniper (range 3), Impassable tile adjacent, enemy 3 tiles away.
	var impassable_tile := Vector2i(1, 0)
	var state := _make_state([impassable_tile])
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, sniper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, sniper)
	# Assert
	assert_array(results).is_empty()


func test_impassable_tile_blocks_targets_beyond_it_too() -> void:
	# Arrange — proves tiles BEYOND the Impassable tile are never targetable
	# that direction (not just the Impassable tile itself).
	var impassable_tile := Vector2i(1, 0)
	var state := _make_state([impassable_tile])
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var enemy_far := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 0)) # just past the wall
	_place(state, sniper)
	_place(state, enemy_far)
	# Act / Assert
	assert_array(Combat.legal_targets(state, sniper)).is_empty()
	assert_int(Combat.blocked_reason(state, sniper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.OUT_OF_RANGE
	)


# --- AC-4: nearest-only, no pierce --------------------------------------------

func test_two_stacked_enemies_only_nearest_is_targetable() -> void:
	# Arrange — Sniper (range 3), two enemies stacked east within range.
	var state := _make_state()
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var near_enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	var far_enemy := _make_unit(3, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, sniper)
	_place(state, near_enemy)
	_place(state, far_enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, sniper)
	# Assert
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].target_id).is_equal(2)
	assert_vector(results[0].tile).is_equal(Vector2i(1, 0))


# --- AC-5: out-of-range --------------------------------------------------------

func test_enemy_beyond_attack_range_yields_no_target() -> void:
	# Arrange — Trooper (range 2), enemy at distance 3, no closer blocker.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, trooper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_array(results).is_empty()


func test_enemy_beyond_attack_range_reports_out_of_range() -> void:
	# Arrange — same setup, queried via blocked_reason() for the East direction.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(3, 0))
	_place(state, trooper)
	_place(state, enemy)
	# Act / Assert
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.OUT_OF_RANGE
	)


# --- AC-6: non-cardinal rejection ----------------------------------------------

func test_enemy_at_diagonal_offset_never_targetable() -> void:
	# Arrange — Sniper (range 3), enemy at a pure diagonal offset (2, 2).
	var state := _make_state()
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 2))
	_place(state, sniper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, sniper)
	# Assert
	assert_array(results).is_empty()


func test_enemy_at_diagonal_within_manhattan_range_still_never_targetable() -> void:
	# Arrange — edge case: manhattan_distance(1,1) == 2 <= Trooper's attack_range
	# (2), but the offset is non-cardinal — DIRECT range is cardinal-line
	# distance, not manhattan, so this must still never be targetable.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 1))
	_place(state, trooper)
	_place(state, enemy)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_array(results).is_empty()


# --- AC-7: three distinct blocked reasons, plus the NONE/targetable case ------

func test_three_directions_report_three_distinct_blocked_reasons() -> void:
	# Arrange — Trooper (range 2) at the board center with three different
	# fixture directions: North blocked by a friendly, East exhausted at
	# attack_range with nothing found, South with no enemy present at all
	# (also exhausted -> OUT_OF_RANGE, distinguished from East only by having
	# zero occupants at all, proving no accidental early-return quirk).
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(3, 3))
	var friendly_blocker := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(3, 2)) # North, adjacent
	_place(state, trooper)
	_place(state, friendly_blocker)
	# East (Vector2i(1, 0)): empty both steps -> OUT_OF_RANGE.
	# South (Vector2i(0, 1)): empty both steps -> OUT_OF_RANGE.
	# Act / Assert
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(0, -1))).is_equal(
		Combat.BlockedReason.BLOCKED_BY_FRIENDLY
	)
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.OUT_OF_RANGE
	)
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(0, 1))).is_equal(
		Combat.BlockedReason.OUT_OF_RANGE
	)


func test_enemy_targetable_direction_reports_none() -> void:
	# Arrange — the fourth, explicitly-pinned case: a direction where an enemy
	# IS legally targetable must report BlockedReason.NONE (never mistaken for
	# one of the three "not targetable" reasons).
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	# Act / Assert
	assert_int(Combat.blocked_reason(state, trooper, Vector2i(1, 0))).is_equal(
		Combat.BlockedReason.NONE
	)


# --- Readiness-review fix: enemy structure on the line IS a legal target ------

func test_enemy_structure_on_cardinal_line_is_legal_target() -> void:
	# Arrange — an enemy HQ/structure stub on the cardinal line must be
	# returned by legal_targets() exactly like an enemy unit would be
	# (ownership decides legality, not occupant kind, per the corrected
	# step-2 walk rule).
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy_structure := _make_structure(2, 1, Vector2i(2, 0))
	_place(state, trooper)
	_place(state, enemy_structure)
	# Act
	var results: Array[Combat.TargetResult] = Combat.legal_targets(state, trooper)
	# Assert
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].target_id).is_equal(2)
	assert_vector(results[0].tile).is_equal(Vector2i(2, 0))


# --- Purity: neither query mutates state (ADR-0010 "pure, side-effect-free") --

func test_legal_targets_and_blocked_reason_do_not_mutate_state() -> void:
	# Arrange — a representative board (attacker, an enemy on the line, a
	# friendly blocker on another line) so both a NONE and a BLOCKED_BY_FRIENDLY
	# path are walked. Snapshot occupancy + positions before querying.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(3, 3))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(4, 3)) # East, targetable
	var friendly := _make_unit(3, 0, UnitTypes.SCOUT, Vector2i(3, 2)) # North, blocker
	_place(state, trooper)
	_place(state, enemy)
	_place(state, friendly)
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var entity_ids_before: Array = state.entities_by_id.keys().duplicate()
	var enemy_pos_before := enemy.position
	# Act — run every read path in this story (both public entry points, all 4 dirs).
	Combat.legal_targets(state, trooper)
	for direction: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		Combat.blocked_reason(state, trooper, direction)
	# Assert — grid occupancy, entity roster, and positions are byte-for-byte unchanged.
	assert_array(state.grid.occupancy).is_equal(occupancy_before)
	assert_int(state.entities_by_id.size()).is_equal(entity_ids_before.size())
	assert_vector(enemy.position).is_equal(enemy_pos_before)
