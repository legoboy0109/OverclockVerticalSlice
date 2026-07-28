# Story 005: On-Board Glyph Layer — hp pip/numeric branch (Logic sub-slice).
#
# Covers the BLOCKING Logic slice of production/epics/game-hud/story-005-on-board-glyph-layer.md
# (TR-hud-010/011/012, ADR-0016 pip/numeric branch). The Visual/Feel legibility
# criteria (AC-11/26, shape distinctness at 1080p/1440p) are advisory and signed
# off separately in production/qa/evidence/on-board-glyph-layer-evidence.md.
#
#   AC-10: hp renders as discrete pips below PIP_MAX_HP, numeric at/above it —
#     the `>=` boundary is load-bearing (max_hp == PIP_MAX_HP → numeric).
#   Marker derivation: HAS_ACTED iff a unit has attacked; BUILD_TIMER_BADGE iff a
#     structure is under construction. TECH_MARKER / RESEARCH_MARKER are STUBBED
#     (owner-tech read + Research system not implemented) and never surface.
#
# Deterministic: no RNG, no time, no rendering (the layer's data model is asserted
# directly; _draw / glyph anchoring is the advisory Visual/Feel surface).
extends GdUnitTestSuite


func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _unit_type(hp: int) -> UnitTypeDef:
	var t := UnitTypeDef.new()
	t.display_name = "TestUnit"
	t.hp = hp
	t.attack = 3
	t.attack_range = 1
	t.move_cost = 1
	t.produce_cost = 4
	return t


func _struct_type(hp: int) -> StructureTypeDef:
	var t := StructureTypeDef.new()
	t.display_name = "TestBuildable"
	t.hp = hp
	t.build_cost = 6
	t.build_time = 2
	t.production_cap = 0
	return t


func _place_unit(state: GameState, entity_id: int, hp: int, has_attacked: bool = false) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = 0
	u.position = Vector2i(1, 1)
	u.type = _unit_type(hp)
	u.current_hp = hp
	u.has_attacked = has_attacked
	state.entities_by_id[entity_id] = u
	return u


func _place_structure(state: GameState, entity_id: int, hp: int, \
		status: StructureState.BuildStatus, turns: int = 0) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = 0
	s.position = Vector2i(2, 2)
	s.type = _struct_type(hp)
	s.current_hp = hp
	s.build_status = status
	s.build_turns_remaining = turns
	state.entities_by_id[entity_id] = s
	return s


func _layer(reader: GameStateReader, config: HUDConfig = null) -> OnBoardGlyphLayer:
	var l: OnBoardGlyphLayer = auto_free(OnBoardGlyphLayer.new())
	# Logic methods read only the reader; anchor_source (null here) is used only
	# by _draw, which these tests never invoke.
	l.bind(reader, null, config if config != null else HUDConfig.new())
	return l


# ==============================================================================
# AC-10: the pure pip/numeric branch (the >= boundary is load-bearing).
# ==============================================================================

func test_hp_render_mode_branches_on_pip_max_hp() -> void:
	assert_int(OnBoardGlyphLayer.hp_render_mode(9, 10)).is_equal(OnBoardGlyphLayer.HpMode.PIPS)
	assert_int(OnBoardGlyphLayer.hp_render_mode(10, 10)) \
		.override_failure_message("max_hp == pip_max_hp must render NUMERIC (the >= boundary)") \
		.is_equal(OnBoardGlyphLayer.HpMode.NUMERIC)
	assert_int(OnBoardGlyphLayer.hp_render_mode(14, 10)).is_equal(OnBoardGlyphLayer.HpMode.NUMERIC)
	assert_int(OnBoardGlyphLayer.hp_render_mode(1, 10)).is_equal(OnBoardGlyphLayer.HpMode.PIPS)


func test_hp_mode_for_unit_branches_against_config() -> void:
	var state := _make_state()
	_place_unit(state, 1, 9) # below 10 → pips
	_place_unit(state, 2, 14) # at/above 10 → numeric
	var l := _layer(GameStateReader.new(state))
	assert_int(l.hp_mode_for(1)).is_equal(OnBoardGlyphLayer.HpMode.PIPS)
	assert_int(l.hp_mode_for(2)).is_equal(OnBoardGlyphLayer.HpMode.NUMERIC)


func test_hp_mode_for_structure_boundary_is_numeric() -> void:
	var state := _make_state()
	_place_structure(state, 5, 10, StructureState.BuildStatus.COMPLETED) # exactly at threshold.
	var l := _layer(GameStateReader.new(state))
	assert_int(l.hp_mode_for(5)).is_equal(OnBoardGlyphLayer.HpMode.NUMERIC)


# ==============================================================================
# Marker derivation (available data).
# ==============================================================================

func test_has_acted_marker_only_when_unit_has_attacked() -> void:
	var state := _make_state()
	_place_unit(state, 1, 9, true) # attacked
	_place_unit(state, 2, 9, false) # not
	var l := _layer(GameStateReader.new(state))
	assert_array(l.active_markers_for(1)).contains([BoardRenderer.GlyphClass.HAS_ACTED])
	assert_array(l.active_markers_for(2)).not_contains([BoardRenderer.GlyphClass.HAS_ACTED])


func test_build_badge_only_when_under_construction() -> void:
	var state := _make_state()
	_place_structure(state, 5, 20, StructureState.BuildStatus.UNDER_CONSTRUCTION, 3)
	_place_structure(state, 6, 20, StructureState.BuildStatus.COMPLETED)
	var l := _layer(GameStateReader.new(state))
	assert_array(l.active_markers_for(5)).contains([BoardRenderer.GlyphClass.BUILD_TIMER_BADGE])
	assert_array(l.active_markers_for(6)).is_empty()


# ==============================================================================
# STUB documentation: tech + research markers never surface (data not built yet).
# ==============================================================================

func test_tech_and_research_markers_are_stubbed() -> void:
	var state := _make_state()
	_place_unit(state, 1, 9, true)
	_place_structure(state, 5, 20, StructureState.BuildStatus.UNDER_CONSTRUCTION, 3)
	var l := _layer(GameStateReader.new(state))
	assert_array(l.active_markers_for(1)).not_contains([BoardRenderer.GlyphClass.TECH_MARKER])
	assert_array(l.active_markers_for(5)).not_contains([BoardRenderer.GlyphClass.RESEARCH_MARKER])
