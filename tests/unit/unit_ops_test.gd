# Story 003: Unit-Owned Pure Operations — can_attack, reset_turn_flags,
# duplicate, apply_hp_delta.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-003-pure-ops-hp-delta.md against the
# real Unit static-utility class (ADR-0007). All fixtures are bare
# UnitState/UnitTypeDef instances constructed in-memory — no GameState, no
# file I/O, no RNG.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _make_type(hp: int = 10) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.hp = hp
	return type


func _make_unit(hp: int = 10, current_hp: int = 10) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = 0
	unit.owner = 0
	unit.position = Vector2i(1, 1)
	unit.type = _make_type(hp)
	unit.current_hp = current_hp
	return unit


# --- AC-1: can_attack --------------------------------------------------------

func test_can_attack_returns_false_when_has_attacked_true() -> void:
	# Arrange
	var unit := _make_unit()
	unit.has_attacked = true
	# Act / Assert
	assert_bool(Unit.can_attack(unit)).is_false()


func test_can_attack_returns_true_when_has_attacked_false() -> void:
	# Arrange
	var unit := _make_unit()
	unit.has_attacked = false
	# Act / Assert
	assert_bool(Unit.can_attack(unit)).is_true()


func test_can_attack_returns_true_on_fresh_unit() -> void:
	# Arrange — edge case: a freshly constructed unit, no explicit flag set.
	var unit := _make_unit()
	# Act / Assert
	assert_bool(Unit.can_attack(unit)).is_true()


# --- AC-2: reset_turn_flags --------------------------------------------------

func test_reset_turn_flags_resets_has_attacked_and_tiles_moved_on_bare_instance() -> void:
	# Arrange — no GameState/Turn Manager required, pure per-instance.
	var unit := _make_unit()
	unit.has_attacked = true
	unit.tiles_moved_this_turn = 3
	# Act
	Unit.reset_turn_flags(unit)
	# Assert
	assert_bool(unit.has_attacked).is_false()
	assert_int(unit.tiles_moved_this_turn).is_equal(0)


func test_reset_turn_flags_is_idempotent_on_already_reset_unit() -> void:
	# Arrange — edge case: calling reset on an already-reset unit is a no-op.
	var unit := _make_unit()
	unit.has_attacked = false
	unit.tiles_moved_this_turn = 0
	# Act
	Unit.reset_turn_flags(unit)
	# Assert
	assert_bool(unit.has_attacked).is_false()
	assert_int(unit.tiles_moved_this_turn).is_equal(0)


# --- AC-3: duplicate independence -------------------------------------------

func test_duplicate_produces_independent_copy_mutating_a_does_not_affect_b() -> void:
	# Arrange
	var a := _make_unit(10, 8)
	a.has_attacked = false
	a.tiles_moved_this_turn = 1
	# Act
	var b: UnitState = Unit.clone(a)
	a.current_hp = 3
	a.position = Vector2i(9, 9)
	a.has_attacked = true
	a.tiles_moved_this_turn = 5
	# Assert — B unaffected by A's post-clone mutations.
	assert_int(b.current_hp).is_equal(8)
	assert_vector(b.position).is_equal(Vector2i(1, 1))
	assert_bool(b.has_attacked).is_false()
	assert_int(b.tiles_moved_this_turn).is_equal(1)


func test_duplicate_produces_independent_copy_mutating_b_does_not_affect_a() -> void:
	# Arrange — repeat in the opposite direction (bidirectional independence).
	var a := _make_unit(10, 8)
	a.has_attacked = false
	a.tiles_moved_this_turn = 1
	var b: UnitState = Unit.clone(a)
	# Act
	b.current_hp = 1
	b.position = Vector2i(4, 4)
	b.has_attacked = true
	b.tiles_moved_this_turn = 7
	# Assert — A unaffected by B's post-clone mutations.
	assert_int(a.current_hp).is_equal(8)
	assert_vector(a.position).is_equal(Vector2i(1, 1))
	assert_bool(a.has_attacked).is_false()
	assert_int(a.tiles_moved_this_turn).is_equal(1)


func test_duplicate_shares_type_by_identity_and_copies_owner_and_entity_id() -> void:
	# Arrange — use a REAL preload'd registry template (UnitTypes.SCOUT), not an
	# in-memory UnitTypeDef.new(): ADR-0007's "type stays shared (===) across the
	# clone" guarantee holds only for disk-loaded/external resources (is_built_in()
	# false). A built-in UnitTypeDef.new() would be deep-copied by duplicate_deep(),
	# which is NOT how production units (always registry-referenced) behave — so the
	# faithful fixture is the preload'd const.
	var a := UnitState.new()
	a.type = UnitTypes.SCOUT
	a.current_hp = UnitTypes.SCOUT.hp
	a.position = Vector2i(1, 1)
	a.entity_id = 42
	a.owner = 1
	# Act
	var b: UnitState = Unit.clone(a)
	# Assert — type is the SAME Resource reference (shared, ===); owner/id
	# compare equal (plain value fields, independently copied).
	assert_object(b.type).is_same(a.type)
	assert_bool(a.type == b.type).is_true()
	assert_int(b.owner).is_equal(a.owner)
	assert_int(b.entity_id).is_equal(a.entity_id)


# --- AC-4: apply_hp_delta clamp ---------------------------------------------

func test_apply_hp_delta_clamps_at_ceiling_when_already_at_max_hp() -> void:
	# Arrange — current_hp == hp.
	var unit := _make_unit(10, 10)
	# Act
	Unit.apply_hp_delta(unit, 5)
	# Assert — unchanged, never exceeds type.hp.
	assert_int(unit.current_hp).is_equal(10)


func test_apply_hp_delta_clamps_at_floor_never_goes_negative() -> void:
	# Arrange — edge case named explicitly in the story: a large negative
	# delta must clamp at 0, never go negative.
	var unit := _make_unit(10, 10)
	# Act
	Unit.apply_hp_delta(unit, -(unit.type.hp + 10))
	# Assert
	assert_int(unit.current_hp).is_equal(0)


func test_apply_hp_delta_applies_partial_damage_within_bounds() -> void:
	# Arrange — sanity check: a delta within bounds applies exactly, no clamp.
	var unit := _make_unit(10, 10)
	# Act
	Unit.apply_hp_delta(unit, -4)
	# Assert
	assert_int(unit.current_hp).is_equal(6)
