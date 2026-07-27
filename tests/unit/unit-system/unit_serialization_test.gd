# Story 009: duplicate() / Serialization Completeness Audit for Save + AI
# Snapshot.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-009-serialization-completeness-audit.md
# (TR-unit-015 -- runtime state fully serializable/reconstructable for save +
# AI snapshot via duplicate(), no nondeterministic fields; also touches
# TR-unit-003 -- entity_id round-trips through duplicate()):
#
#   AC-1 (full round-trip, holistic): a UnitState with ALL 7 fields set to
#     distinct non-default values simultaneously -- Unit.clone() -- every
#     field round-trips exactly. This is a full-field audit beyond Story
#     003's four-field, per-pair checks (tests/unit/unit_ops_test.gd) --
#     one holistic fixture, all fields at once, including the
#     position = Vector2i(-1, -1) edge case named explicitly in the story
#     (no field-specific special-casing for negative coordinates).
#   AC-2 (no engine refs / no floats): reflection over UnitState's
#     PROPERTY_USAGE_STORAGE-flagged fields (get_property_list()) asserts
#     none is a float (ADR-0003 Rule 2, the float-in-state ban) and none is
#     an engine object reference (Node/RID -- ADR-0001's "no engine object
#     references" Foundation rule). `type: UnitTypeDef` is a TYPE_OBJECT
#     field but a sanctioned Resource (not Node/RID) -- see the
#     _is_engine_ref_field() helper below for exactly how that distinction
#     is made.
#   AC-3 (@export presence): cross-references the same storage-flagged
#     field set against the known full 7-field schema (entity_id, owner,
#     position, type, current_hp, has_attacked, tiles_moved_this_turn) and
#     asserts all 7 are present -- i.e. none is silently missing @export
#     (which would drop it from duplicate_deep() and make it invisible to
#     AC-2's reflection sweep too). Paired with AC-1's known-distinct-value
#     fixture as a cross-check: a field missing @export would still
#     "silently pass" AC-1 by having matching *default* values on both
#     sides unless AC-1 asserts against a KNOWN distinct value, which it does.
#
# A future save/load system and the AI epic's clone()-based lookahead
# snapshotting both build directly on the guarantee this suite proves: every
# UnitState field is a plain, storage-flagged, non-float, non-engine-ref
# value that duplicate_deep() reconstructs exactly.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# The complete, known UnitState schema (own 4 fields + inherited EntityState's
# 3), per ADR-0001/ADR-0007. Used by AC-3 to cross-check the reflection-derived
# storage-flagged set against what the schema is actually supposed to contain.
const KNOWN_FIELDS: Array[String] = [
	"entity_id", "owner", "position",
	"type", "current_hp", "has_attacked", "tiles_moved_this_turn",
]


# Returns the PROPERTY_USAGE_STORAGE-flagged property-list entries for a
# fresh UnitState instance -- the structural, reflection-based answer to
# "which fields actually get walked by duplicate_deep()", not a source-read.
func _storage_flagged_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for p: Dictionary in UnitState.new().get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			props.append(p)
	return props


# True if a storage-flagged property dict describes an engine object
# reference (Node or RID) that ADR-0001's Foundation rule forbids on state.
#
# RID fields never surface as TYPE_OBJECT at all (RID is its own Variant
# type, TYPE_RID) -- caught directly by the type check.
#
# TYPE_OBJECT fields are only forbidden if class_name resolves to a
# ClassDB-known engine class that IS Node or descends from it. Script-defined
# Resource subclasses (e.g. UnitTypeDef) are NOT ClassDB-registered -- this is
# a documented Godot architectural separation (script `class_name` classes live
# in ProjectSettings.get_global_class_list(), never ClassDB, which tracks only
# native engine classes), so ClassDB.class_exists() is false for ANY such class
# and they correctly fall through as sanctioned. (Sanity-checked against the
# pinned Redot 26.2 / Godot 4.6 build: ClassDB.class_exists("UnitTypeDef")
# == false, ClassDB.class_exists("Node") == true, ClassDB.is_parent_class
# ("Node2D", "Node") == true.) This is what lets the check allow Resource-typed
# fields (the sanctioned ADR-0001/0007 pattern) while still flagging a
# hypothetical Node-typed field.
func _is_engine_ref_field(prop: Dictionary) -> bool:
	if prop.type == TYPE_RID:
		return true
	if prop.type == TYPE_OBJECT:
		var class_name_str: String = prop.class_name
		if ClassDB.class_exists(class_name_str):
			return class_name_str == "Node" or ClassDB.is_parent_class(class_name_str, "Node")
	return false


# --- AC-1: full-field holistic round-trip ------------------------------------

func test_clone_round_trips_every_field_when_all_set_to_distinct_nondefault_values() -> void:
	# Arrange -- every field set simultaneously to a distinct non-default
	# value, including the story's explicit negative-position edge case.
	var original := UnitState.new()
	original.entity_id = 42
	original.owner = 1
	original.position = Vector2i(-1, -1)
	original.type = UnitTypes.TROOPER
	original.current_hp = 3
	original.has_attacked = true
	original.tiles_moved_this_turn = 2

	# Act
	var clone: UnitState = Unit.clone(original)

	# Assert -- mutable fields compare by value; type compares by reference
	# identity (ADR-0007: preload()'d templates are shared, not deep-copied).
	assert_int(clone.entity_id).is_equal(42)
	assert_int(clone.owner).is_equal(1)
	assert_vector(clone.position).is_equal(Vector2i(-1, -1))
	assert_object(clone.type).is_same(UnitTypes.TROOPER)
	assert_int(clone.current_hp).is_equal(3)
	assert_bool(clone.has_attacked).is_true()
	assert_int(clone.tiles_moved_this_turn).is_equal(2)


func test_clone_round_trips_negative_position_with_no_special_casing() -> void:
	# Arrange -- isolates the story-named edge case: a negative Vector2i
	# position must round-trip exactly, same as any other position.
	var original := UnitState.new()
	original.entity_id = 7
	original.owner = 0
	original.position = Vector2i(-1, -1)
	original.type = UnitTypes.SCOUT
	original.current_hp = UnitTypes.SCOUT.hp

	# Act
	var clone: UnitState = Unit.clone(original)

	# Assert
	assert_vector(clone.position).is_equal(Vector2i(-1, -1))


# --- AC-2: no engine refs / no floats (structural reflection audit) ---------

func test_no_storage_flagged_field_is_a_float() -> void:
	# Arrange / Act
	var props := _storage_flagged_properties()

	# Assert -- explicit, loudly-failing per-field check (ADR-0003 Rule 2,
	# the float-in-state ban). Currently expected to pass for every field;
	# this is a regression guard, not something expected to fail today.
	for p in props:
		assert_int(p.type).override_failure_message(
			"Field '%s' on UnitState is TYPE_FLOAT (%s) -- ADR-0003 Rule 2 bans floats in state. Use a scaled int instead." % [p.name, p.type]
		).is_not_equal(TYPE_FLOAT)


func test_no_storage_flagged_field_is_an_engine_object_reference() -> void:
	# Arrange / Act
	var props := _storage_flagged_properties()

	# Assert -- explicit, loudly-failing per-field check (ADR-0001's "no
	# engine object references (Node, RID)" Foundation rule). Resource-typed
	# fields (like `type: UnitTypeDef`) are the sanctioned pattern and must
	# NOT be flagged here -- see _is_engine_ref_field()'s doc comment for how
	# that distinction is made.
	for p in props:
		var is_engine_ref: bool = _is_engine_ref_field(p)
		assert_bool(is_engine_ref).override_failure_message(
			"Field '%s' on UnitState is an engine object reference (class_name='%s', type=%s) -- ADR-0001 forbids Node/RID fields in state." % [p.name, p.class_name, p.type]
		).is_false()


func test_type_field_is_a_sanctioned_resource_not_flagged_as_engine_ref() -> void:
	# Arrange -- sanity check that the AC-2 helper correctly allows the ONE
	# TYPE_OBJECT field UnitState actually has (`type: UnitTypeDef`), rather
	# than the audit passing only because nothing exercises the allow-branch.
	var props := _storage_flagged_properties()
	var type_prop: Dictionary = {}
	for p in props:
		if p.name == "type":
			type_prop = p
			break

	# Assert
	assert_bool(type_prop.is_empty()).is_false()
	assert_int(type_prop.type).is_equal(TYPE_OBJECT)
	assert_str(type_prop.class_name).is_equal("UnitTypeDef")
	assert_bool(_is_engine_ref_field(type_prop)).is_false()


# --- AC-3: @export presence cross-check --------------------------------------

func test_every_known_field_carries_export_and_is_storage_flagged() -> void:
	# Arrange
	var props := _storage_flagged_properties()
	var storage_flagged_names: Array[String] = []
	for p in props:
		storage_flagged_names.append(p.name)

	# Act / Assert -- every field in the known 7-field schema (ADR-0001's
	# EntityState base + ADR-0007's UnitState specialization) must appear in
	# the storage-flagged set. A field silently missing @export would drop
	# out of duplicate_deep() (ADR-0001 Foundation rule) and would also be
	# invisible here -- this loudly fails per-field rather than just
	# comparing counts, so a missing field is unambiguous in the failure.
	for field_name in KNOWN_FIELDS:
		assert_array(storage_flagged_names).override_failure_message(
			"Field '%s' is missing @export on UnitState/EntityState -- it will be silently dropped by duplicate_deep() (ADR-0001)." % field_name
		).contains([field_name])


# The storage-flagged property names a BARE Resource carries (script,
# resource_name, resource_local_to_scene, resource_path, ...) -- derived at
# runtime rather than hardcoded, so this stays correct if Godot 4.x ever
# changes which Resource plumbing fields are storage-flagged. These are
# inherited framework fields, NOT part of UnitState's ADR-0007 schema, so the
# completeness check below must allow them through.
func _resource_builtin_storage_fields() -> Array[String]:
	var names: Array[String] = []
	for p: Dictionary in Resource.new().get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			names.append(p.name)
	return names


func test_no_unexpected_storage_flagged_field_beyond_known_schema() -> void:
	# Cross-check the OTHER direction from AC-3's positive-presence test: no
	# unexpected extra @export field sneaked onto UnitState/EntityState without
	# this suite (and the story's ACs) being updated to cover it. Every
	# storage-flagged field must be EITHER a known ADR-0007 schema field OR an
	# inherited Resource built-in -- anything in neither is a genuine, loudly-
	# failing schema drift. (This deliberately does NOT pre-filter to
	# KNOWN_FIELDS before asserting -- doing so would make the check tautological
	# and unable to see a new field at all.)
	var builtin: Array[String] = _resource_builtin_storage_fields()
	for p in _storage_flagged_properties():
		var is_known: bool = KNOWN_FIELDS.has(p.name)
		var is_builtin: bool = builtin.has(p.name)
		assert_bool(is_known or is_builtin).override_failure_message(
			"Unexpected storage-flagged field '%s' on UnitState -- not in the known ADR-0007 schema (KNOWN_FIELDS) and not an inherited Resource built-in. If it's a legitimate new state field, add it to KNOWN_FIELDS and update Story 009's ACs to cover it; if it shouldn't be serialized, it shouldn't carry @export." % p.name
		).is_true()
