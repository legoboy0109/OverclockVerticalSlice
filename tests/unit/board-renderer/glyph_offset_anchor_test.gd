# Story 005: On-Board Glyph Anchoring Convention — glyph_anchor()/GLYPH_OFFSETS coverage
# (production/epics/board-renderer/story-005-glyph-anchoring-convention.md).
#
# Covers the two Logic QA Test Cases (formula, data-driven) plus the AC-4
# all-12-classes coverage guard, against BoardRenderer.glyph_anchor() and
# GlyphOffsets.offset_for() — no rendering, no live scene, no visual
# occlusion/legibility claims (those are AC-3/AC-4's Visual/Feel half; see
# production/qa/evidence/board-renderer-glyph-legibility-evidence.md, owed).
#
# Logic-typed per the story (glyph_anchor() needs no scene-tree/_ready()
# state — like Story 004's pick_at(), auto_free() alone is sufficient; no
# add_child() required).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _make_offsets_with_hp_pip(offset: Vector2) -> GlyphOffsets:
	var offsets := GlyphOffsets.new()
	offsets.hp_pip = offset
	return offsets


# AC-1 / QA (formula): given a tile and a glyph_class with a known offset,
# glyph_anchor() returns exactly grid_to_screen(tile) + offset — arithmetic
# assertion, no rendering, no second computation path.
func test_glyph_anchor_equals_grid_to_screen_plus_known_offset() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var offsets := GlyphOffsets.new()
	offsets.ap_cost_badge = Vector2(-32.0, -20.0)
	renderer.glyph_offsets = offsets
	var tile := Vector2i(3, 4)

	# Act
	var anchor := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.AP_COST_BADGE)

	# Assert — exactly grid_to_screen(tile) + offset, no other path.
	assert_vector(anchor).is_equal(renderer.grid_to_screen(tile) + Vector2(-32.0, -20.0))


# AC-1 companion: a different tile + a different glyph_class also resolves
# exactly — proves the formula generalizes, not hardcoded to one sample point.
func test_glyph_anchor_equals_grid_to_screen_plus_offset_for_a_different_tile_and_class() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var offsets := GlyphOffsets.new()
	offsets.d3_echo = Vector2(0.0, -16.0)
	renderer.glyph_offsets = offsets
	var tile := Vector2i(9, 1)

	# Act
	var anchor := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.D3_ECHO)

	# Assert
	assert_vector(anchor).is_equal(renderer.grid_to_screen(tile) + Vector2(0.0, -16.0))


# AC-1 edge case: a zero offset (hp_pip's authored default) still adds
# correctly — glyph_anchor(tile) must equal plain grid_to_screen(tile) in
# that case, regression guard against an accidental extra term.
func test_glyph_anchor_with_zero_offset_equals_plain_grid_to_screen() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var offsets := GlyphOffsets.new()
	offsets.hp_pip = Vector2.ZERO
	renderer.glyph_offsets = offsets
	var tile := Vector2i(6, 6)

	# Act
	var anchor := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)

	# Assert
	assert_vector(anchor).is_equal(renderer.grid_to_screen(tile))


# AC-2 / QA (data-driven): load offsets from an injected GlyphOffsets
# instance, then change a value on it and confirm the anchor reflects the
# new value with ZERO code change — proving glyph_anchor() reads through
# GLYPH_OFFSETS as data, not a hardcoded literal.
func test_glyph_anchor_reflects_a_changed_offset_value_with_no_code_change() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var offsets := _make_offsets_with_hp_pip(Vector2(5.0, 5.0))
	renderer.glyph_offsets = offsets
	var tile := Vector2i(2, 2)
	var anchor_before := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)

	# Act — retune the SAME resource instance's value (simulating a
	# designer/artist edit to the .tres), no code path changes.
	offsets.hp_pip = Vector2(99.0, -42.0)
	var anchor_after := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)

	# Assert — the anchor moved by exactly the offset delta; same formula,
	# same call site, only the data changed.
	assert_vector(anchor_before).is_equal(renderer.grid_to_screen(tile) + Vector2(5.0, 5.0))
	assert_vector(anchor_after).is_equal(renderer.grid_to_screen(tile) + Vector2(99.0, -42.0))
	assert_vector(anchor_after).is_not_equal(anchor_before)


# AC-2 companion: swapping in a WHOLLY DIFFERENT injected GlyphOffsets
# instance (not just mutating a field) also changes the anchor — proves
# glyph_anchor() genuinely reads member glyph_offsets at call time, not a
# cached/baked-in value from construction.
func test_glyph_anchor_reflects_a_wholly_different_injected_offsets_instance() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var tile := Vector2i(7, 3)
	renderer.glyph_offsets = _make_offsets_with_hp_pip(Vector2(1.0, 1.0))
	var anchor_a := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)

	# Act
	renderer.glyph_offsets = _make_offsets_with_hp_pip(Vector2(-77.0, 12.0))
	var anchor_b := renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)

	# Assert
	assert_vector(anchor_a).is_equal(renderer.grid_to_screen(tile) + Vector2(1.0, 1.0))
	assert_vector(anchor_b).is_equal(renderer.grid_to_screen(tile) + Vector2(-77.0, 12.0))
	assert_vector(anchor_b).is_not_equal(anchor_a)


# AC-2 / lazy-load seam: glyph_offsets defaults to null on a bare
# BoardRenderer.new() and glyph_anchor() lazy-loads the real
# data/ui/glyph_offsets.tres resource on first call (never in _ready) —
# confirms the external-data file itself loads and resolves without error,
# and that the loaded resource is cached (same instance) across calls.
func test_glyph_anchor_lazy_loads_default_resource_when_unset() -> void:
	# Arrange
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	assert_object(renderer.glyph_offsets).is_null()

	# Act
	var anchor := renderer.glyph_anchor(Vector2i(0, 0), BoardRenderer.GlyphClass.HP_PIP)
	var loaded_offsets := renderer.glyph_offsets

	# Assert — resource loaded, anchor resolves via that resource's own
	# offset_for(), and a second call reuses the same cached instance
	# (never reloads).
	assert_object(loaded_offsets).is_not_null()
	assert_vector(anchor).is_equal(renderer.grid_to_screen(Vector2i(0, 0)) + loaded_offsets.offset_for(BoardRenderer.GlyphClass.HP_PIP))
	renderer.glyph_anchor(Vector2i(1, 1), BoardRenderer.GlyphClass.HP_PIP)
	assert_object(renderer.glyph_offsets).is_same(loaded_offsets)


# AC-4 (all 12 classes resolve): every named GlyphClass value resolves to a
# defined (non-crashing, well-typed) offset via GlyphOffsets.offset_for() —
# a future class added to the enum without a matching field would be caught
# here failing to differ from the fallback, not silently.
func test_all_twelve_glyph_classes_resolve_to_a_defined_offset() -> void:
	# Arrange
	var offsets := GlyphOffsets.new()
	var all_classes: Array[BoardRenderer.GlyphClass] = [
		BoardRenderer.GlyphClass.HP_PIP,
		BoardRenderer.GlyphClass.HAS_ACTED,
		BoardRenderer.GlyphClass.TECH_MARKER,
		BoardRenderer.GlyphClass.STRUCTURE_HP,
		BoardRenderer.GlyphClass.BUILD_TIMER_BADGE,
		BoardRenderer.GlyphClass.RESEARCH_MARKER,
		BoardRenderer.GlyphClass.AP_COST_BADGE,
		BoardRenderer.GlyphClass.DAMAGE_NUMBER,
		BoardRenderer.GlyphClass.COVER_GLYPH,
		BoardRenderer.GlyphClass.TURNS_NUMERAL,
		BoardRenderer.GlyphClass.TARGET_BRACKET,
		BoardRenderer.GlyphClass.D3_ECHO,
	]

	# Assert — exactly 12 classes named (AC-4's exact enumerated list), and
	# every one resolves through offset_for() to its own authored field.
	assert_int(all_classes.size()).is_equal(12)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.HP_PIP)).is_equal(offsets.hp_pip)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.HAS_ACTED)).is_equal(offsets.has_acted)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.TECH_MARKER)).is_equal(offsets.tech_marker)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.STRUCTURE_HP)).is_equal(offsets.structure_hp)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.BUILD_TIMER_BADGE)).is_equal(offsets.build_timer_badge)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.RESEARCH_MARKER)).is_equal(offsets.research_marker)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.AP_COST_BADGE)).is_equal(offsets.ap_cost_badge)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.DAMAGE_NUMBER)).is_equal(offsets.damage_number)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.COVER_GLYPH)).is_equal(offsets.cover_glyph)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.TURNS_NUMERAL)).is_equal(offsets.turns_numeral)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.TARGET_BRACKET)).is_equal(offsets.target_bracket)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.D3_ECHO)).is_equal(offsets.d3_echo)


# AC-4 companion: confirm HP_PIP is authored at Vector2.ZERO (first claim on
# the anchor's own origin point) — a direct, automatable slice of the
# hp-pip-priority authoring guarantee (the full occlusion claim across all
# 12 classes stays Visual/Feel and is NOT verified here — see the evidence
# stub).
func test_hp_pip_offset_defaults_to_zero_first_claim_on_anchor_origin() -> void:
	# Arrange / Act
	var offsets := GlyphOffsets.new()

	# Assert
	assert_vector(offsets.hp_pip).is_equal(Vector2.ZERO)


# AC-4 companion: an unrecognized glyph_class int (not one of the 12 named
# values) degrades to Vector2.ZERO rather than crashing — regression guard
# for offset_for()'s documented fallback behavior.
func test_offset_for_unrecognized_glyph_class_falls_back_to_zero() -> void:
	# Arrange
	var offsets := GlyphOffsets.new()

	# Act
	var result := offsets.offset_for(9999)

	# Assert
	assert_vector(result).is_equal(Vector2.ZERO)


# Regression guard: the real on-disk data/ui/glyph_offsets.tres resource
# loads as a GlyphOffsets instance and every one of the 12 classes resolves
# through it without error — confirms the external-data file (not just the
# in-memory GlyphOffsets.new() default) is wired correctly end-to-end.
func test_default_tres_resource_loads_and_resolves_all_twelve_classes() -> void:
	# Arrange
	var offsets: GlyphOffsets = load("res://data/ui/glyph_offsets.tres")

	# Assert
	assert_object(offsets).is_not_null()
	assert_bool(offsets is GlyphOffsets).is_true()
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.HP_PIP)).is_equal(Vector2.ZERO)
	assert_vector(offsets.offset_for(BoardRenderer.GlyphClass.D3_ECHO)).is_equal(offsets.d3_echo)
