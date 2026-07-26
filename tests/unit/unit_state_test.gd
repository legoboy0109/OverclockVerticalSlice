# Story 002: UnitState Runtime Schema + Stub Migration (Sprint-1 Seam Closure)
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-002-unitstate-runtime-stub-migration.md
# against the real UnitState class (ADR-0007). AC-3 (stub migration / no
# duplicate class_name) is proven implicitly by this suite loading at all —
# the Sprint-1 unit_state_stub.gd/unit_stub.gd files are deleted, and
# turn_sequencing_test.gd (migrated to has_attacked) still passes alongside
# this file in the same run.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- AC-1: fresh-instance defaults ------------------------------------------

func test_fresh_unit_state_has_attacked_false() -> void:
	# Arrange / Act
	var unit := UnitState.new()
	unit.type = UnitTypeDef.new()
	# Assert — default holds without the caller setting it.
	assert_bool(unit.has_attacked).is_false()


func test_fresh_unit_state_tiles_moved_this_turn_is_zero() -> void:
	# Arrange / Act
	var unit := UnitState.new()
	unit.type = UnitTypeDef.new()
	# Assert
	assert_int(unit.tiles_moved_this_turn).is_equal(0)


# --- AC-2: entity_id uniqueness, scoped to a single GameState --------------

func test_entity_ids_allocated_from_next_entity_id_are_pairwise_distinct() -> void:
	# Arrange — mirrors the allocation pattern at game_state.gd:293-297.
	var state := GameStateFactory.make_state(2, 0)
	var ids: Array[int] = []
	# Act — 5 entities created via the same incrementing counter.
	for _i: int in 5:
		var unit := UnitState.new()
		unit.entity_id = state.next_entity_id
		unit.owner = 0
		state.entities_by_id[unit.entity_id] = unit
		state.next_entity_id += 1
		ids.append(unit.entity_id)
	# Assert — all 5 ids pairwise distinct.
	var unique_ids: Dictionary = {}
	for id: int in ids:
		unique_ids[id] = true
	assert_int(unique_ids.size()).is_equal(5)
	assert_array(ids).is_equal([0, 1, 2, 3, 4])


func test_entity_ids_shared_counter_interleaved_unit_and_structure_still_distinct() -> void:
	# Arrange — a unit and a structure interleaved still draw from the same
	# shared next_entity_id counter (edge case named in the story's QA notes).
	var state := GameStateFactory.make_state(2, 0)
	var unit := UnitState.new()
	unit.entity_id = state.next_entity_id
	unit.owner = 0
	state.entities_by_id[unit.entity_id] = unit
	state.next_entity_id += 1
	var structure := StructureState.new()
	structure.entity_id = state.next_entity_id
	structure.owner = 0
	state.entities_by_id[structure.entity_id] = structure
	state.next_entity_id += 1
	# Assert
	assert_int(unit.entity_id).is_equal(0)
	assert_int(structure.entity_id).is_equal(1)
	assert_bool(unit.entity_id == structure.entity_id).is_false()
