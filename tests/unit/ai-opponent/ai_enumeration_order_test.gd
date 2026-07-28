# Story 002: Approved Query-Facade Allowlist + Deterministic Entity Enumeration
# Order (Logic).
#
# Covers production/epics/ai-opponent/story-002-query-facade-enumeration-order.md
# QA Test Cases:
#
#   AC (order): 5 owned entities inserted in NON-ascending id order -> the
#     internal enumeration list (AI._entities_in_enumeration_order, the
#     documented test seam) is entity-id-ascending.
#   AC (headless): choose_action runs from a plain unit test with no
#     SceneTree/Node and returns without error (implicit in every test below —
#     GdUnit4 unit suites already run headless; this is asserted directly by
#     one dedicated test).
#   AC (no array): documented/behavioral check that no candidate Array of
#     size > 1 is ever held — choose_action's running-best is a single
#     reassigned _Candidate, never appended to a collection (code-review
#     property; the behavioral proxy here is that a 100-owned-entity board
#     completes choose_action without materializing any observable candidate
#     list, and every helper call site only ever receives/returns one
#     candidate reference).
#   Edge: zero owned entities -> enumeration completes with an empty
#     running-best (choose_action returns null), no crash.
#
# Also covers the enumeration seam's ownership filter (only the active
# player's entities are enumerated, never the opponent's) and confirms
# `ai.gd` contains no `await` and does not `extends Node` (ADR-0011
# structural property, lint-checkable — asserted here at the source level
# until CI tooling owns the real lint per ADR-0011 §5/Consequences).
#
# Deterministic: no RNG, no time, no file I/O beyond the one static source
# read for the structural-property check (mirrors
# ai_config_invariant_test.gd's precedent for that kind of check).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Fixture helpers ---------------------------------------------------------

func _make_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestType"
	type.hp = 10
	type.attack = 1
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 8
	type.produce_cost = 1
	return type


func _make_blank_grid(size: int = 10) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	state.grid = _make_blank_grid()
	return state


# Places an owned unit at [param entity_id] for [param owner] on a distinct
# tile derived from [param entity_id] (kept in-bounds for a 10x10 grid).
func _place_unit(state: GameState, entity_id: int, owner: int, type: UnitTypeDef) -> void:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = Vector2i(entity_id % 10, (entity_id / 10) % 10)
	unit.type = type
	unit.current_hp = type.hp
	state.entities_by_id[entity_id] = unit
	state.grid.occupancy[state.grid.index(unit.position.x, unit.position.y)] = entity_id


# --- AC (order): reverse/non-ascending insertion -> ascending enumeration ---

func test_enumeration_order_is_entity_id_ascending_when_inserted_non_ascending() -> void:
	# Arrange — 5 owned entities inserted in NON-ascending id order.
	var state := _make_state(0)
	var type := _make_type()
	var insertion_order: Array[int] = [40, 10, 30, 20, 50]
	for id: int in insertion_order:
		_place_unit(state, id, 0, type)

	# Act
	var enumerated: Array[EntityState] = AI._entities_in_enumeration_order(state)

	# Assert — ascending, never raw (insertion) Dictionary order.
	var ids: Array[int] = []
	for e: EntityState in enumerated:
		ids.append(e.entity_id)
	assert_array(ids).is_equal([10, 20, 30, 40, 50] as Array[int])


func test_enumeration_order_excludes_opponent_owned_entities() -> void:
	# Arrange — mixed ownership, non-ascending insertion.
	var state := _make_state(0)
	var type := _make_type()
	_place_unit(state, 40, 0, type)  # active player
	_place_unit(state, 10, 1, type)  # opponent — must be excluded
	_place_unit(state, 20, 0, type)  # active player
	_place_unit(state, 5, 1, type)   # opponent — must be excluded

	# Act
	var enumerated: Array[EntityState] = AI._entities_in_enumeration_order(state)

	# Assert — only the active player's entities, ascending.
	var ids: Array[int] = []
	for e: EntityState in enumerated:
		ids.append(e.entity_id)
	assert_array(ids).is_equal([20, 40] as Array[int])


# --- AC (headless): plain unit test, no SceneTree/Node, returns cleanly -----

func test_choose_action_runs_headless_with_no_scene_tree_and_returns() -> void:
	# Arrange — this entire suite is a plain GdUnitTestSuite; no Node/SceneTree
	# is ever instantiated. A single owned entity is enough to exercise the
	# full enumeration loop through every helper stub.
	var state := _make_state(0)
	_place_unit(state, 1, 0, _make_type())

	# Act
	var action: Action = AI.choose_action(state, 0)

	# Assert — returns cleanly (stub helpers never produce a candidate yet).
	assert_object(action).is_null()


func test_ai_script_source_has_no_await_and_does_not_extend_node() -> void:
	# Structural property (ADR-0011 Consequences: "ai.gd must not extend Node
	# and must contain no await") — code-level check until CI lint tooling
	# owns this per ADR-0011 §5, mirroring ai_config_invariant_test.gd's
	# precedent for asserting on source form rather than runtime behavior.
	var source := FileAccess.get_file_as_string("res://src/gameplay/ai/ai.gd")
	var code_only := ""
	for line in source.split("\n"):
		var stripped: String = (line as String).strip_edges()
		if not stripped.begins_with("#") and not stripped.begins_with("##"):
			code_only += line + "\n"

	assert_bool(code_only.contains("extends Node")).is_false()
	assert_bool(code_only.contains("await")).is_false()
	assert_str(code_only).contains("extends RefCounted")


# --- AC (no array): running-best is never a materialized candidate Array ---

func test_choose_action_completes_over_many_entities_without_candidate_array() -> void:
	# Behavioral proxy for the code-review property "no Array of size > 1
	# candidates is ever held simultaneously": choose_action's own return
	# type is a single nullable Action (never an Array of results), and the
	# helper stubs each take/return exactly one _Candidate reference. This
	# test's job is to confirm that shape holds even at 100 owned entities —
	# if a future edit accidentally introduced an accumulating candidate
	# Array, this is the scale at which such a regression would be most
	# likely to surface in review/profiling, though the actual guarantee is
	# structural (single reassigned reference), not something a black-box
	# return-value test can fully prove by itself.
	var state := _make_state(0)
	var type := _make_type()
	for id: int in range(1, 101):
		_place_unit(state, id, 0, type)

	var action: Action = AI.choose_action(state, 0)

	assert_object(action).is_null()  # stub helpers never produce a candidate


func test_ai_script_source_never_materializes_candidate_array_then_sorts() -> void:
	# Code-level companion to the behavioral proxy above: no `sort(` call
	# appears anywhere in ai.gd's executable source (the forbidden
	# "materialize full candidate array then sort()" pattern, ADR-0011 §2 /
	# control-manifest forbidden pattern for this layer).
	var source := FileAccess.get_file_as_string("res://src/gameplay/ai/ai.gd")
	var code_only := ""
	for line in source.split("\n"):
		var stripped: String = (line as String).strip_edges()
		if not stripped.begins_with("#") and not stripped.begins_with("##"):
			code_only += line + "\n"

	assert_bool(code_only.contains("sort(")).is_false()
	assert_bool(code_only.contains("sort_custom(")).is_false()


# --- Edge: zero owned entities -> empty running-best, no crash --------------

func test_choose_action_with_zero_owned_entities_returns_null_no_crash() -> void:
	# Arrange — no entities at all.
	var state := _make_state(0)

	# Act
	var action: Action = AI.choose_action(state, 0)

	# Assert — completes cleanly, no crash, empty running-best -> null.
	assert_object(action).is_null()


func test_entities_in_enumeration_order_with_zero_owned_entities_is_empty() -> void:
	# Arrange
	var state := _make_state(0)

	# Act
	var enumerated: Array[EntityState] = AI._entities_in_enumeration_order(state)

	# Assert
	assert_array(enumerated).is_empty()


# --- choose_action never calls apply_action / never mutates authoritative state --

func test_choose_action_does_not_mutate_authoritative_state() -> void:
	# Arrange — choose_action clones internally (ADR-0011 §1); the
	# authoritative state passed in must be unchanged afterward (it never
	# calls apply_action itself).
	var state := _make_state(0)
	_place_unit(state, 1, 0, _make_type())
	var ap_before: int = state.per_player[0].current_ap
	var entity_count_before: int = state.entities_by_id.size()

	# Act
	AI.choose_action(state, 0)

	# Assert
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_int(state.entities_by_id.size()).is_equal(entity_count_before)
