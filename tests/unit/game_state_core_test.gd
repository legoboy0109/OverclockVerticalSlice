# Story 001: GameState Core — Data Model, Read API & clone().
#
# Covers every acceptance criterion in
# production/epics/game-state-turn-manager/story-001-gamestate-core-model-read-clone.md
# against directly-constructed GameState/PlayerState/EntityState instances (no
# apply_action/start_match yet — those land in later stories). No RNG, no
# time-dependent asserts, no file I/O; each test builds and tears down its own
# GameState.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


const GRID_SIZE := 8


# Builds an 8x8 all-Plain grid with empty occupancy — the shared baseline
# fixture for tests that don't care about specific terrain layout.
func _make_blank_grid(size: int = GRID_SIZE) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(-1)
	return grid


# Builds a bare EntityState with the given id/owner/position.
func _make_entity(entity_id: int, owner: int, position: Vector2i) -> EntityState:
	var entity := EntityState.new()
	entity.entity_id = entity_id
	entity.owner = owner
	entity.position = position
	return entity


# Builds a bare PlayerState with the given starting AP.
func _make_player(current_ap: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.current_ap = current_ap
	return player


# Builds a minimal but non-trivial GameState: an 8x8 grid, two players, and
# two entities (one per player) placed on the grid and registered in
# entities_by_id. Shared fixture for most tests below.
func _make_populated_state() -> GameState:
	var state := GameState.new()
	state.grid = _make_blank_grid()
	state.per_player = [_make_player(10), _make_player(8)]

	var entity_a := _make_entity(0, 0, Vector2i(1, 1))
	var entity_b := _make_entity(1, 1, Vector2i(2, 2))
	state.grid.place(entity_a.entity_id, entity_a.position.x, entity_a.position.y)
	state.grid.place(entity_b.entity_id, entity_b.position.x, entity_b.position.y)
	state.entities_by_id = {
		entity_a.entity_id: entity_a,
		entity_b.entity_id: entity_b,
	}
	state.next_entity_id = 2
	state.active_player = 0
	state.round_number = 1
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	return state


# AC: headless construction via .new() (not a Node) — all reads function with
# no scene tree.
func test_headless_construction_all_reads_function_with_no_scene_tree() -> void:
	# Arrange
	var state := _make_populated_state()
	# Act / Assert — every read resolves with no rendering node/scene tree present.
	assert_int(state.active_player).is_equal(0)
	assert_int(state.round_number).is_equal(1)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.current_ap(0)).is_equal(10)
	assert_int(state.entities().size()).is_equal(2)
	assert_object(state.entity_at(Vector2i(1, 1))).is_not_null()
	assert_object(state.grid).is_not_null()


# AC: the critical ADR-0001 clone-isolation test. Clone an entity's position
# and a PlayerState.current_ap on the clone; assert the original is unchanged,
# and vice versa.
func test_clone_isolation_mutating_clone_entity_position_and_player_ap_leaves_original_unchanged() -> void:
	# Arrange
	var original := _make_populated_state()
	# Act
	var clone := original.clone()
	clone.entities_by_id[0].position = Vector2i(7, 7)
	clone.per_player[0].current_ap = 999
	# Assert — original is untouched.
	assert_object(original.entities_by_id[0].position).is_equal(Vector2i(1, 1))
	assert_int(original.per_player[0].current_ap).is_equal(10)
	# Assert — the clone reflects the mutation.
	assert_object(clone.entities_by_id[0].position).is_equal(Vector2i(7, 7))
	assert_int(clone.per_player[0].current_ap).is_equal(999)


# AC: clone-isolation, the reverse direction — mutating the original after
# cloning must not leak into the already-taken clone.
func test_clone_isolation_mutating_original_after_clone_leaves_clone_unchanged() -> void:
	# Arrange
	var original := _make_populated_state()
	var clone := original.clone()
	# Act
	original.entities_by_id[1].position = Vector2i(6, 6)
	original.per_player[1].current_ap = 0
	# Assert — clone is untouched.
	assert_object(clone.entities_by_id[1].position).is_equal(Vector2i(2, 2))
	assert_int(clone.per_player[1].current_ap).is_equal(8)


# AC: clone-determinism — two clone() calls on the same unmodified state
# produce field-wise-equal results with no shared object identity.
func test_clone_determinism_two_clones_are_field_wise_equal_with_no_shared_identity() -> void:
	# Arrange
	var original := _make_populated_state()
	# Act
	var clone_a := original.clone()
	var clone_b := original.clone()
	# Assert — field-wise equal.
	assert_int(clone_a.active_player).is_equal(clone_b.active_player)
	assert_int(clone_a.round_number).is_equal(clone_b.round_number)
	assert_int(clone_a.next_entity_id).is_equal(clone_b.next_entity_id)
	assert_int(clone_a.current_ap(0)).is_equal(clone_b.current_ap(0))
	assert_object(clone_a.entities_by_id[0].position).is_equal(clone_b.entities_by_id[0].position)
	# Assert — no shared object identity between the two clones.
	assert_bool(clone_a == clone_b).is_false()
	assert_bool(clone_a.grid == clone_b.grid).is_false()
	assert_bool(clone_a.per_player[0] == clone_b.per_player[0]).is_false()
	assert_bool(clone_a.entities_by_id[0] == clone_b.entities_by_id[0]).is_false()
	# Mutating one clone must never affect the other.
	clone_a.per_player[0].current_ap = 42
	assert_int(clone_b.current_ap(0)).is_equal(10)


# AC: read API side-effect-freedom — active_player, current_ap(player),
# round_number, match_status, entities(), entity_at(tile), grid,
# faction_of(player) each return the correct value and mutate nothing.
func test_read_api_returns_correct_values_and_mutates_nothing() -> void:
	# Arrange
	var state := _make_populated_state()
	var faction := FactionDef.new()
	state.per_player[0].faction = faction
	# Act — call every read method twice.
	var active_player_first := state.active_player
	var current_ap_first := state.current_ap(0)
	var round_number_first := state.round_number
	var match_status_first := state.match_status
	var entities_first := state.entities()
	var entity_at_first := state.entity_at(Vector2i(1, 1))
	var faction_first := state.faction_of(0)

	var active_player_second := state.active_player
	var current_ap_second := state.current_ap(0)
	var round_number_second := state.round_number
	var match_status_second := state.match_status
	var entities_second := state.entities()
	var entity_at_second := state.entity_at(Vector2i(1, 1))
	var faction_second := state.faction_of(0)
	# Assert — correct values.
	assert_int(active_player_first).is_equal(0)
	assert_int(current_ap_first).is_equal(10)
	assert_int(round_number_first).is_equal(1)
	assert_int(match_status_first).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(entities_first.size()).is_equal(2)
	assert_object(entity_at_first).is_equal(state.entities_by_id[0])
	assert_object(faction_first).is_equal(faction)
	# Assert — repeated calls agree (no hidden mutable state / no side effects).
	assert_int(active_player_second).is_equal(active_player_first)
	assert_int(current_ap_second).is_equal(current_ap_first)
	assert_int(round_number_second).is_equal(round_number_first)
	assert_int(match_status_second).is_equal(match_status_first)
	assert_int(entities_second.size()).is_equal(entities_first.size())
	assert_object(entity_at_second).is_equal(entity_at_first)
	assert_object(faction_second).is_equal(faction_first)


# AC: entities() returns entities in stable entity_id ascending order, not
# Dictionary insertion/hash order — insert deliberately out of id order.
func test_entities_returns_stable_entity_id_ascending_order() -> void:
	# Arrange
	var state := GameState.new()
	state.grid = _make_blank_grid()
	state.per_player = [_make_player()]
	var entity_5 := _make_entity(5, 0, Vector2i(0, 0))
	var entity_1 := _make_entity(1, 0, Vector2i(1, 0))
	var entity_3 := _make_entity(3, 0, Vector2i(2, 0))
	# Insert out of ascending order to prove sort, not insertion order, wins.
	state.entities_by_id = {
		5: entity_5,
		1: entity_1,
		3: entity_3,
	}
	# Act
	var result := state.entities()
	# Assert
	assert_int(result.size()).is_equal(3)
	assert_int(result[0].entity_id).is_equal(1)
	assert_int(result[1].entity_id).is_equal(3)
	assert_int(result[2].entity_id).is_equal(5)


# AC: every field on GameState/PlayerState/EntityState is a plain
# serializable value (int/enum/Vector2i/typed-Resource) — no Node/RID/float.
func test_all_fields_are_plain_serializable_values_no_node_rid_or_float() -> void:
	# Arrange
	var state := _make_populated_state()
	var player := state.per_player[0]
	var entity := state.entities_by_id[0] as EntityState
	# Assert — GameState fields.
	assert_bool(state.grid is GridState).is_true()
	assert_bool(typeof(state.per_player) == TYPE_ARRAY).is_true()
	assert_bool(typeof(state.entities_by_id) == TYPE_DICTIONARY).is_true()
	assert_bool(typeof(state.next_entity_id) == TYPE_INT).is_true()
	assert_bool(typeof(state.active_player) == TYPE_INT).is_true()
	assert_bool(typeof(state.round_number) == TYPE_INT).is_true()
	assert_bool(typeof(state.match_status) == TYPE_INT).is_true()
	# Assert — PlayerState fields.
	assert_bool(typeof(player.current_ap) == TYPE_INT).is_true()
	assert_bool(typeof(player.income_this_turn) == TYPE_INT).is_true()
	assert_bool(typeof(player.has_attack_tech) == TYPE_BOOL).is_true()
	assert_bool(typeof(player.has_defense_tech) == TYPE_BOOL).is_true()
	assert_bool(typeof(player.has_economy_tech) == TYPE_BOOL).is_true()
	assert_bool(typeof(player.is_ai_controlled) == TYPE_BOOL).is_true()
	# Assert — EntityState fields.
	assert_bool(typeof(entity.entity_id) == TYPE_INT).is_true()
	assert_bool(typeof(entity.owner) == TYPE_INT).is_true()
	assert_bool(typeof(entity.position) == TYPE_VECTOR2I).is_true()
	# Assert — GameState/PlayerState/EntityState are all Resource, never Node
	# (statically guaranteed by their `extends Resource` declarations; checked
	# here via get_class() rather than `is Node`, which the static type
	# checker rejects as an always-false expression for a Resource-typed var).
	assert_str(state.get_class()).is_equal("Resource")
	assert_str(player.get_class()).is_equal("Resource")
	assert_str(entity.get_class()).is_equal("Resource")


# Edge case: empty GameState (no entities) — entities() returns [],
# entity_at() returns null.
func test_empty_game_state_entities_returns_empty_array() -> void:
	# Arrange
	var state := GameState.new()
	state.grid = _make_blank_grid()
	# Act / Assert
	assert_array(state.entities()).is_empty()


func test_empty_game_state_entity_at_any_tile_returns_null() -> void:
	# Arrange
	var state := GameState.new()
	state.grid = _make_blank_grid()
	# Act / Assert
	assert_object(state.entity_at(Vector2i(0, 0))).is_null()


# Edge case: clone() on a zero-entity state succeeds and stays independent.
func test_clone_on_zero_entity_state_succeeds_and_stays_independent() -> void:
	# Arrange
	var original := GameState.new()
	original.grid = _make_blank_grid()
	original.per_player = [_make_player(5)]
	# Act
	var clone := original.clone()
	clone.per_player[0].current_ap = 99
	# Assert
	assert_array(clone.entities()).is_empty()
	assert_int(original.per_player[0].current_ap).is_equal(5)
	assert_int(clone.per_player[0].current_ap).is_equal(99)


# Edge case: entity_at(tile) for an out-of-bounds tile returns null (delegates
# to grid.occupant_at, which returns the empty sentinel for OOB).
func test_entity_at_out_of_bounds_tile_returns_null() -> void:
	# Arrange
	var state := _make_populated_state()
	# Act / Assert
	assert_object(state.entity_at(Vector2i(-1, 0))).is_null()
	assert_object(state.entity_at(Vector2i(GRID_SIZE, GRID_SIZE))).is_null()


# Edge case: entity_at(tile) for an unoccupied (but in-bounds) tile returns null.
func test_entity_at_unoccupied_in_bounds_tile_returns_null() -> void:
	# Arrange
	var state := _make_populated_state()
	# Act / Assert — (5,5) was never placed on in _make_populated_state.
	assert_object(state.entity_at(Vector2i(5, 5))).is_null()
