# Story 006: Isometric Picking & Overlay Integration.
#
# Covers production/epics/command-action-interface/story-006-iso-picking-overlay-integration.md
# (TR-cmdui-003/004/016/017, ADR-0013 §3/§4/§5):
#
#   TR-cmdui-004 (occupant priority): route_click consumes BoardRenderer.pick_at
#     so a click over an occupant's overlapping region resolves to the occupant
#     (and selects it if it's an own UnitState), not the underlying tile.
#   TR-cmdui-003 (round-trip): a click with no occupant resolves to the plain
#     screen_to_grid tile, occupant_entity_id == -1, no selection.
#   TR-cmdui-016 / AC-29 / AC-30 (overlay wiring): _render_overlays maps the held
#     tier dicts to BoardRenderer.set_overlays — Move paints MOVE_IN_CAP +
#     MOVE_OVER_CAP (+ AFTER_MOVE_ECHO) together in one call; the in-cap set
#     shrinks to a strict subset when the unit has already moved (AC-30).
#   TR-cmdui-017 (glyph anchor): glyph_anchor is a pure delegation to
#     BoardRenderer.glyph_anchor (the sanctioned grid_to_screen + GLYPH_OFFSETS
#     convention), never re-derived.
#
# Integration: real BoardRenderer for pick_at/glyph_anchor consumption (the
# occupant_pick_regions seam per pick_at_occupant_priority_test.gd); a spy
# renderer records set_overlays for the overlay-wiring/AC-30 assertions (the
# CommandInterface's _renderer is duck-typed, so a lightweight double works).
# Real GameState fixtures, faction Neutral; auto_free() Node fixtures.
# Deterministic: no RNG, no time-dependent assertions, no external I/O.
extends GdUnitTestSuite


# --- Spy renderer: records the last set_overlays payload + clear count --------

class _SpyRenderer extends RefCounted:
	var last_overlays: Dictionary = {}
	var set_overlays_count: int = 0
	var clear_count: int = 0

	func set_overlays(class_tiles: Dictionary) -> void:
		set_overlays_count += 1
		last_overlays = class_tiles.duplicate(true)

	func clear_overlay() -> void:
		clear_count += 1

	func glyph_anchor(tile: Vector2i, _glyph_class: int) -> Vector2:
		return Vector2(tile)

	func pick_at(_screen_pos: Vector2) -> Object:
		return null # not exercised in the overlay-wiring tests


# --- Fixtures -----------------------------------------------------------------

func _make_grid(size: int = 14) -> GridState:
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
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type(move_cost: int = 1, soft_move_cap: int = 2, attack_range: int = 1) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestUnit"
	type.hp = 10
	type.attack = 3
	type.attack_range = attack_range
	type.move_cost = move_cost
	type.soft_move_cap = soft_move_cap
	type.produce_cost = 4
	return type


func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i, type: UnitTypeDef) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	state.entities_by_id[entity_id] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return unit


func _in_cap_tiles(spy: _SpyRenderer) -> Array:
	return spy.last_overlays.get(BoardRenderer.OverlayClass.MOVE_IN_CAP, [])


# ==============================================================================
# TR-cmdui-004: occupant-priority click routing via pick_at.
# ==============================================================================

func test_route_click_resolves_to_occupant_and_selects_own_unit_not_underlying_tile() -> void:
	var state := _make_state(0)
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var click_pos := Vector2(500.0, 300.0)
	var occupant_tile := Vector2i(3, 3) # a fixed in-bounds tile the occupant sits on.

	# An own unit occupies occupant_tile; its pick-region overlaps the click.
	var unit := _place_unit(state, 7, 0, occupant_tile, _make_unit_type())
	var region := BoardRenderer.OccupantPickRegion.new()
	region.rect = Rect2(click_pos - Vector2(20, 20), Vector2(40, 40))
	region.entity_id = unit.entity_id
	region.tile = occupant_tile
	renderer.occupant_pick_regions = [region]

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = renderer

	var pick: Object = iface.route_click(click_pos, state)

	# occupant_entity_id != -1 proves the occupant region won over the plain
	# screen_to_grid diamond fallback (which would report -1) — the essence of
	# occupant priority (TR-cmdui-004) — and the pick reports the occupant's tile…
	assert_int(pick.occupant_entity_id).is_equal(unit.entity_id)
	assert_object(pick.tile).is_equal(occupant_tile)
	# …and the interface selected that own unit.
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.ENTITY_SELECTED)
	assert_int(iface.selected_id()).is_equal(unit.entity_id)


func test_route_click_no_occupant_resolves_tile_via_fallback_no_selection() -> void:
	var state := _make_state(0)
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var click_pos := Vector2(500.0, 300.0)
	# No occupant regions -> plain screen_to_grid fallback.

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = renderer

	var pick: Object = iface.route_click(click_pos, state)

	assert_int(pick.occupant_entity_id).is_equal(-1)
	assert_object(pick.tile).is_equal(renderer.screen_to_grid(click_pos))
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.IDLE)
	assert_int(iface.selected_id()).is_equal(-1)


func test_route_click_on_opponent_turn_resolves_pick_but_makes_no_selection() -> void:
	# active_player is 1; this interface acts for player 0 -> input not live.
	var state := _make_state(1)
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var click_pos := Vector2(500.0, 300.0)
	var occupant_tile := Vector2i(3, 3)
	var unit := _place_unit(state, 7, 0, occupant_tile, _make_unit_type())
	var region := BoardRenderer.OccupantPickRegion.new()
	region.rect = Rect2(click_pos - Vector2(20, 20), Vector2(40, 40))
	region.entity_id = unit.entity_id
	region.tile = occupant_tile
	renderer.occupant_pick_regions = [region]

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = renderer

	var pick: Object = iface.route_click(click_pos, state)

	# The pick still resolves (inspection is always allowed) but nothing selects.
	assert_int(pick.occupant_entity_id).is_equal(unit.entity_id)
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.IDLE)
	assert_int(iface.selected_id()).is_equal(-1)


# ==============================================================================
# TR-cmdui-016 / AC-29 / AC-30: overlay wiring via set_overlays.
# ==============================================================================

func test_move_preview_paints_in_cap_and_over_cap_together_in_one_set_overlays() -> void:
	# soft_move_cap=2 with ample AP -> the frontier has both in-cap (dist<=2) and
	# over-cap (dist>=3, surcharged) tiles, so both classes must be painted.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(7, 7), _make_unit_type(1, 2, 1))
	state.per_player[0].current_ap = 6

	var spy := _SpyRenderer.new()
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = spy

	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)

	assert_int(spy.set_overlays_count).is_equal(1)
	assert_bool(spy.last_overlays.has(BoardRenderer.OverlayClass.MOVE_IN_CAP)).is_true()
	assert_bool(spy.last_overlays.has(BoardRenderer.OverlayClass.MOVE_OVER_CAP)).is_true()
	assert_bool((spy.last_overlays[BoardRenderer.OverlayClass.MOVE_IN_CAP] as Array).is_empty()).is_false()
	assert_bool((spy.last_overlays[BoardRenderer.OverlayClass.MOVE_OVER_CAP] as Array).is_empty()).is_false()


func test_reselect_after_moving_shrinks_in_cap_overlay_to_a_strict_subset() -> void:
	# AC-30: the cheap (in-cap) zone visibly shrinks when a partially-moved unit
	# is reselected — the reselected in-cap set is a STRICT SUBSET of the full-AP one.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(7, 7), _make_unit_type(1, 2, 1))
	state.per_player[0].current_ap = 6

	var spy := _SpyRenderer.new()
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = spy

	# Full-AP preview: capture in-cap set A.
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	var set_a: Array = _in_cap_tiles(spy).duplicate()

	# Reselect after moving 1 tile -> the in-cap allowance drops by 1.
	unit.tiles_moved_this_turn = 1
	iface.enter_preview(state, unit, CommandFSM.State.PREVIEW_MOVE)
	var set_b: Array = _in_cap_tiles(spy).duplicate()

	assert_bool(set_b.size() < set_a.size()).override_failure_message(
		"in-cap set must shrink: |B|=%d must be < |A|=%d" % [set_b.size(), set_a.size()]).is_true()
	for tile: Vector2i in set_b:
		assert_bool(set_a.has(tile)).override_failure_message(
			"reselected in-cap tile %s must already be in the full-AP set (strict subset)" % tile).is_true()


func test_attack_preview_paints_target_class() -> void:
	var state := _make_state(0)
	var attacker := _place_unit(state, 1, 0, Vector2i(7, 7), _make_unit_type(1, 8, 3))
	_place_unit(state, 2, 1, Vector2i(7, 8), _make_unit_type()) # adjacent enemy target.
	state.per_player[0].current_ap = 10

	var spy := _SpyRenderer.new()
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	iface._renderer = spy

	iface.enter_preview(state, attacker, CommandFSM.State.PREVIEW_ATTACK)

	assert_int(spy.set_overlays_count).is_equal(1)
	assert_bool(spy.last_overlays.has(BoardRenderer.OverlayClass.ATTACK_TARGET)).is_true()
	assert_bool((spy.last_overlays[BoardRenderer.OverlayClass.ATTACK_TARGET] as Array).is_empty()).is_false()


# ==============================================================================
# TR-cmdui-017: glyph anchoring is a pure delegation to BoardRenderer.
# ==============================================================================

func test_glyph_anchor_delegates_to_board_renderer_convention() -> void:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface._renderer = renderer

	var tile := Vector2i(4, 5)
	assert_object(iface.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP)).is_equal(
		renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.HP_PIP))
	assert_object(iface.glyph_anchor(tile, BoardRenderer.GlyphClass.D3_ECHO)).is_equal(
		renderer.glyph_anchor(tile, BoardRenderer.GlyphClass.D3_ECHO))
