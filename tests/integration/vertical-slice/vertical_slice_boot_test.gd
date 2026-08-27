# Vertical slice boot — VerticalSliceRoot assembles the whole stack and runs the
# turn loop.
#
# Covers src/game/vertical_slice_root.gd — the bootable main scene. Proves the
# full stack (match → board → camera → CommandInterface → GameHud → AITurnDriver)
# boots without error and the human↔AI turn loop cycles a full round. Drives the
# loop through the root's own try_end_human_turn() entry point (no synthesised
# InputEvent). Deterministic: the AI turn is synchronous; we await idle frames
# only to let the deferred hand-off run.
extends GdUnitTestSuite

# run_ai_turn paces its commits via AIBalance.ai.commit_pacing_sec (a coroutine);
# shrink it to a tiny yield for these tests so the paced AI turn resolves fast and
# deterministically. Saved/restored per test (mirrors ai_turn_driver_loop_test) so
# no fast pacing leaks into an unrelated suite.
var _saved_commit_pacing_sec: float


func before_test() -> void:
	_saved_commit_pacing_sec = AIBalance.ai.commit_pacing_sec
	AIBalance.ai.commit_pacing_sec = 0.01


func after_test() -> void:
	AIBalance.ai.commit_pacing_sec = _saved_commit_pacing_sec


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(VerticalSliceRoot.new())
	add_child(root) # _ready() builds the whole slice.
	return root


# ==============================================================================
# Boot: a live match with a rendered board, an assembled HUD, and an AI opponent.
# ==============================================================================

func test_boots_a_live_match_with_board_hud_and_ai() -> void:
	var root := _make_root()
	var state := root.state()

	# Match is live.
	assert_object(state).is_not_null()
	assert_object(state.grid).is_not_null()
	assert_int(state.active_player).is_equal(0) # the human starts.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_bool(state.per_player[1].is_ai_controlled).is_true()
	# Ownership-by-hue precondition (S4-02/S4-03): the two sides pin to DISTINCT
	# factions (Rush vs Boom), not a Neutral mirror — both empty-delta so VS parity
	# still holds. Distinctness is what lets the renderer color ownership by hue.
	assert_object(state.per_player[0].faction).is_same(Factions.RUSH)
	assert_object(state.per_player[1].faction).is_same(Factions.BOOM)
	assert_bool(state.per_player[0].faction == state.per_player[1].faction).is_false()

	# Two HQs and two starting Builders — one behind each HQ (S8-29). Nothing else yet:
	# the human hasn't acted and no AI turn has run.
	# ⚠ Was 2 until 2026-08-29. The free Builder exists because since S8-13 the HQ makes
	# ONLY Builders, so without it every game opens with the same forced turn.
	assert_int(state.entities().size()).is_equal(4)
	# ★ Behind the HQ, never in front: a Builder has attack_range 0 and cannot defend
	# itself, so seeding it toward the enemy would gift the opponent a turn-one kill.
	for player: int in 2:
		var behind: Vector2i = VSMap.starting_builder_tile(state.entities_by_id[player].position)
		var seeded: EntityState = state.entity_at(behind)
		assert_object(seeded).override_failure_message(
			"No starting Builder behind player %d's HQ." % player).is_not_null()
		assert_bool(seeded is UnitState).is_true()
		assert_object((seeded as UnitState).type).is_same(UnitTypes.BUILDER)
		assert_int(seeded.owner).is_equal(player)

	# Board + command interface + HUD all assembled and wired.
	assert_object(root.board()).is_not_null()
	assert_object(root.command_interface()).is_not_null()
	assert_object(root.hud().ap_counter()).is_not_null()
	assert_object(root.hud().glyph_layer()).is_not_null() # on-board layer on the board.
	assert_object(root.hud().audio()).is_not_null()


# ==============================================================================
# Turn loop: a human End-Turn drives the AI's turn and hands control back.
# ==============================================================================

func test_human_end_turn_drives_ai_then_returns_control() -> void:
	var root := _make_root()
	var state := root.state()
	assert_int(state.active_player).is_equal(0)
	var round_before: int = state.round_number

	# Human ends turn (synchronous route) → the AI turn plays out paced across
	# frames (fire-and-forget) → control returns to the human.
	assert_bool(root.try_end_human_turn()).is_true()

	# Await the paced AI turn to fully complete (each commit yields a frame).
	var frames: int = 0
	while root.is_ai_turn_running() and frames < 1500:
		await get_tree().process_frame
		frames += 1

	assert_bool(root.is_ai_turn_running()).is_false()          # AI turn fully finished.
	assert_int(state.active_player).is_equal(0)                # back to the human.
	assert_int(state.round_number).is_equal(round_before + 1)  # a full round elapsed.
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)


# ==============================================================================
# End-Turn is turn-scoped: it never acts on the AI's turn (the loop owns it).
# ==============================================================================

func test_end_turn_is_a_noop_out_of_the_human_turn() -> void:
	var root := _make_root()
	var state := root.state()

	# Force the AI's turn context (as if mid-loop) and confirm the human entry
	# point refuses to act — control belongs to the driver, not the player.
	state.active_player = 1
	assert_bool(root.try_end_human_turn()).is_false()
	assert_int(state.active_player).is_equal(1) # unchanged.


func _place_unit(state: GameState, id: int, owner: int, tile: Vector2i, \
		type: UnitTypeDef = UnitTypes.SCOUT) -> void:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[id] = u
	state.grid.place(id, tile.x, tile.y)


# ==============================================================================
# Keyboard board cursor — moves, peeks the entity under it, selects own units
# (the work-around for the blocked click-pick seam).
# ==============================================================================

func test_cursor_starts_on_local_hq_and_peeks_it() -> void:
	var root := _make_root()
	# The cursor opens on the local player's HQ and peeks it into the detail panel.
	assert_vector(root.cursor_tile()).is_equal(Vector2i(2, 5))
	assert_int(root.hud().detail_panel().shown_entity_id()).is_equal(0) # HQ entity id 0.


func test_cursor_moves_and_clears_peek_over_empty_tiles() -> void:
	var root := _make_root()
	assert_bool(root.move_cursor(Vector2i.RIGHT)).is_true()
	assert_vector(root.cursor_tile()).is_equal(Vector2i(3, 5))     # moved off the HQ ...
	assert_bool(root.hud().detail_panel().is_showing()).is_false()  # ... onto an empty tile.


func test_cursor_selects_own_unit_but_not_structures_or_enemies() -> void:
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 10, 0, Vector2i(4, 5)) # friendly
	_place_unit(state, 11, 1, Vector2i(6, 5)) # enemy

	root.move_cursor(Vector2i.RIGHT) # (3,5)
	root.move_cursor(Vector2i.RIGHT) # (4,5) — the friendly unit
	assert_bool(root.select_at_cursor()).is_true()
	assert_int(root.command_interface().selected_id()).is_equal(10)

	root.move_cursor(Vector2i.RIGHT) # (5,5)
	root.move_cursor(Vector2i.RIGHT) # (6,5) — the enemy unit
	assert_bool(root.select_at_cursor()).is_false() # opponent unit — refused.


func test_cursor_stops_at_the_board_edge() -> void:
	var root := _make_root()
	for _i: int in 5:
		root.move_cursor(Vector2i.LEFT)
	assert_vector(root.cursor_tile()).is_equal(Vector2i(0, 5)) # clamped at the west edge.
	assert_bool(root.move_cursor(Vector2i.LEFT)).is_false()     # can't step past it.
	assert_vector(root.cursor_tile()).is_equal(Vector2i(0, 5))


# ==============================================================================
# Mouse click-select (scope §8 seam b) — the board authors an occupant pick-region
# per live entity, and a left-click routes through CommandInterface.route_click →
# BoardRenderer.pick_at against those regions (the ADR-0013 §4 CAI boundary — never
# screen_to_grid for routing).
# ==============================================================================

func test_boot_authors_a_pick_region_per_starting_entity() -> void:
	var root := _make_root()
	var board := root.board()
	var regions: Array = board.occupant_pick_regions
	# Four starting entities at boot — two HQs and two Builders (S8-29) → four regions,
	# each carrying its entity id + tile, its rect covering that tile's centre so a click
	# on the tile resolves the occupant.
	# ⚠ Was 2 until 2026-08-29. ★ That this number tracks the starting roster is the
	# point of the test: a seeded entity with no pick region would be unclickable.
	assert_int(regions.size()).is_equal(4)
	for region: BoardRenderer.OccupantPickRegion in regions:
		assert_bool(region.rect.has_point(board.grid_to_screen(region.tile))).is_true()
	# Authored back-to-front (ascending screen Y = the Y-sort paint order) so pick_at's
	# reverse scan resolves an overlap to the front-most (nearest-camera) occupant.
	for i: int in range(1, regions.size()):
		assert_bool(regions[i - 1].rect.position.y <= regions[i].rect.position.y).is_true()


func test_left_click_selects_own_unit_through_pick_regions() -> void:
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 10, 0, Vector2i(4, 5)) # friendly
	_place_unit(state, 11, 1, Vector2i(6, 5)) # enemy
	root._refresh_occupant_pick_regions() # a commit re-authors regions; do it directly here.

	# Left-click the friendly unit's tile centre → routed through pick_at → selected,
	# and the keyboard cursor syncs to the clicked tile.
	var friendly: Vector2 = root.board().grid_to_screen(Vector2i(4, 5))
	assert_bool(root.select_at_board_point(friendly)).is_true()
	assert_int(root.command_interface().selected_id()).is_equal(10)
	assert_vector(root.cursor_tile()).is_equal(Vector2i(4, 5))

	# Left-click the enemy unit → pick resolves it, but route_click refuses (not
	# owned): the prior own-unit selection is left untouched.
	var enemy: Vector2 = root.board().grid_to_screen(Vector2i(6, 5))
	assert_bool(root.select_at_board_point(enemy)).is_false()
	assert_int(root.command_interface().selected_id()).is_equal(10) # unchanged.


func test_left_click_on_own_structure_does_not_select() -> void:
	var root := _make_root()
	# The local player's HQ is a structure — pick_at resolves it, but route_click
	# selects units only, so nothing gets pinned.
	var hq: Vector2 = root.board().grid_to_screen(Vector2i(2, 5))
	assert_bool(root.select_at_board_point(hq)).is_false()
	assert_int(root.command_interface().selected_id()).is_equal(-1)


func _move_cursor_to(root: VerticalSliceRoot, target: Vector2i) -> void:
	var guard: int = 200
	while root.cursor_tile() != target and guard > 0:
		var cur: Vector2i = root.cursor_tile()
		var dir: Vector2i
		if cur.x != target.x:
			dir = Vector2i(signi(target.x - cur.x), 0)
		else:
			dir = Vector2i(0, signi(target.y - cur.y))
		root.move_cursor(dir)
		guard -= 1


# ==============================================================================
# Build — a selected Builder raises a structure on a tile beside it.
#
# ⚠ REWRITTEN 2026-08-25 (user decision). These tests used to drive
# `request_build_at_cursor()` / `cycle_buildable()` / `selected_buildable()` — a
# player-level Build that placed a hidden "currently selected" type on any frontier
# tile with no unit involved. All three are gone: Build belongs to a Builder, is
# placed beside that unit, and consumes it.
# ==============================================================================

## Puts a Builder on the board beside the player's HQ and selects it. The match
## opens with two HQs and no units at all, so every build test must field one.
func _select_a_builder(root: VerticalSliceRoot, tile: Vector2i = Vector2i(4, 5)) -> UnitState:
	var state: GameState = root.state()
	_place_unit(state, 90, 0, tile, UnitTypes.BUILDER)
	_move_cursor_to(root, tile)
	root.select_at_cursor()
	return state.entities_by_id[90] as UnitState


func test_the_build_roster_still_excludes_the_factory() -> void:
	# ★ S6-09: the Factory stays out until it can produce something -- a
	# 1,000-Credit structure that does nothing is a trap rather than a choice.
	var root := _make_root()
	var roster: Array[StructureTypeDef] = root._buildable_roster()
	assert_bool(roster.has(StructureTypes.FACTORY)).override_failure_message(
		"the Factory must stay out of the build roster until it can produce something"
	).is_false()
	assert_bool(roster.has(StructureTypes.BARRACKS)).is_true()


func test_build_places_a_structure_on_a_tile_beside_the_builder() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var builder: UnitState = _select_a_builder(root)
	var type: StructureTypeDef = StructureTypes.BARRACKS

	var legal: Array[Vector2i] = BaseProduction.legal_build_tiles_for(state, builder)
	assert_bool(legal.is_empty()).is_false()
	var target: Vector2i = legal[0]

	root.begin_build_preview(type)
	_move_cursor_to(root, target)
	var entities_before: int = state.entities().size()
	var ap_before: int = state.per_player[0].current_ap
	assert_bool(root.commit_at_cursor()).is_true()

	# A structure was placed on the target tile and AP was spent...
	assert_object(state.entity_at(target)).is_not_null()
	assert_int(state.per_player[0].current_ap).is_less(ap_before)
	# ...and the BUILDER IS GONE, so the entity count is unchanged: one unit spent,
	# one structure gained.
	assert_object(state.entities_by_id.get(90)).override_failure_message(
		"the Builder must be consumed by the structure it raises"
	).is_null()
	assert_int(state.entities().size()).is_equal(entities_before)


func test_build_refused_on_a_tile_the_builder_is_not_beside() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var builder: UnitState = _select_a_builder(root)
	root.begin_build_preview(StructureTypes.BARRACKS)

	# The far side of the board is nowhere near the Builder.
	var far := Vector2i(9, 1)
	assert_bool(BaseProduction.legal_build_tiles_for(state, builder).has(far)).is_false()
	_move_cursor_to(root, far)
	var entities_before: int = state.entities().size()

	assert_bool(root.commit_at_cursor()).is_false()
	assert_int(state.entities().size()).is_equal(entities_before) # nothing was built.
	assert_object(state.entities_by_id.get(90)).override_failure_message(
		"a refused build must not consume the Builder"
	).is_not_null()


func test_build_is_refused_outright_with_no_builder_selected() -> void:
	# The rule that replaced the HUD Build button: with no Builder there is no build.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var entities_before: int = state.entities().size()

	assert_bool(root.open_build_picker()).override_failure_message(
		"the Build picker must refuse to open without a Builder selected"
	).is_false()
	root.begin_build_preview(StructureTypes.BARRACKS)
	assert_int(root.command_interface().fsm_state()).override_failure_message(
		"no Builder means no build preview at all"
	).is_not_equal(CommandFSM.State.PREVIEW_BUILD)
	assert_int(state.entities().size()).is_equal(entities_before)


# ==============================================================================
# Produce / Move / Attack — the selected-unit + HQ-production gameplay verbs.
# ==============================================================================

func test_produce_starts_a_build_that_deploys_a_unit_from_the_hq() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	var hq: StructureState = state.entities_by_id[0] as StructureState # local HQ, id 0.
	var utype: UnitTypeDef = hq.type.producible_types[0]
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(0, utype)
	assert_bool(deploy.is_empty()).is_false()
	var target: Vector2i = deploy[0]
	_move_cursor_to(root, target)

	var before: int = state.entities().size()
	assert_bool(root.request_produce_at_cursor()).is_true()
	# ⚠ S8-28: production is multi-turn. The commit starts a build and the board is
	# UNCHANGED until the timer runs out — that is the behaviour under test now.
	assert_int(state.entities().size()).is_equal(before)
	assert_object(hq.producing_type).is_same(utype)

	BaseProduction.advance_build_timers(state, 0)

	assert_int(state.entities().size()).is_equal(before + 1)   # a unit was deployed ...
	assert_bool(state.entity_at(target) is UnitState).is_true() # ... on the target tile.


# ==============================================================================
# S8-32/S8-35 — when the action menu stays up, and when it gets out of the way.
# ==============================================================================

func test_the_menu_reopens_after_a_move_so_the_unit_can_attack_or_wait() -> void:
	# ★ Moving is the one action that is routinely a SETUP for another, so the menu
	# re-filters for the same unit rather than making the player re-select — CR-4's
	# AC-25/AC-12, kept exactly where it earns its place.
	var root := _make_root()
	var state := root.state()
	# ⚠ Force reduced motion on the menu. ActionMenu.close() only sets `visible = false`
	# IMMEDIATELY under reduced motion; otherwise it starts a fade tween and hides at the
	# END of it — and a tween never advances in a headless test, so `is_open()` would
	# report TRUE for a menu that is on its way out. Without this the close assertion is
	# unfalsifiable, which is exactly how the first draft of this pair passed against
	# every possible implementation.
	root._action_menu.configure(true)
	state.per_player[0].current_ap = 20
	_place_unit(state, 20, 0, Vector2i(4, 5))
	_move_cursor_to(root, Vector2i(4, 5))
	assert_bool(root.select_at_cursor()).is_true()

	var dest := Vector2i(-1, -1)
	for r in Movement.reachable(state, state.entities_by_id[20]):
		if r.tile != Vector2i(4, 5):
			dest = r.tile
			break
	assert_bool(dest != Vector2i(-1, -1)).is_true()
	_move_cursor_to(root, dest)
	assert_bool(root.act_at_cursor()).is_true()

	assert_bool(root._action_menu.is_open()).override_failure_message(
		"The menu closed after a move. Move is the setup action — closing here forces " +
		"a re-select in the middle of the game's most common sequence."
	).is_true()
	assert_int(root._action_menu.entity_id()).is_equal(20)


func test_the_menu_closes_after_an_action_that_is_not_a_move() -> void:
	# ⚠ The other half of the rule, and it must be asserted separately: S8-32 closed the
	# menu after EVERY action and S8-35 narrowed that to "every action except a move".
	# Without this, reverting to the old always-reopen behaviour would pass the test above.
	var root := _make_root()
	var state := root.state()
	# ⚠ Force reduced motion on the menu. ActionMenu.close() only sets `visible = false`
	# IMMEDIATELY under reduced motion; otherwise it starts a fade tween and hides at the
	# END of it — and a tween never advances in a headless test, so `is_open()` would
	# report TRUE for a menu that is on its way out. Without this the close assertion is
	# unfalsifiable, which is exactly how the first draft of this pair passed against
	# every possible implementation.
	root._action_menu.configure(true)
	state.per_player[0].current_ap = 20
	var hq: StructureState = state.entities_by_id[0] as StructureState
	var utype: UnitTypeDef = hq.type.producible_types[0]
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(0, utype)
	assert_bool(deploy.is_empty()).is_false()

	# ⚠ SELECT THE PRODUCER FIRST, so a menu is actually OPEN going in. A first draft of
	# this test produced without ever opening one and then asserted it was closed — which
	# passed no matter what the code did. It was verified vacuous by reverting to the
	# always-reopen behaviour and watching it still pass.
	_move_cursor_to(root, hq.position)
	assert_bool(root.select_at_cursor()).is_true()
	assert_bool(root._action_menu.is_open()).override_failure_message(
		"Setup failed: selecting the HQ did not open a menu, so this test would be " +
		"asserting nothing."
	).is_true()

	_move_cursor_to(root, deploy[0])
	assert_bool(root.request_produce_at_cursor()).is_true()

	assert_bool(root._action_menu.is_open()).override_failure_message(
		"The menu stayed open after a produce. Only a MOVE re-opens it; everything " +
		"else should hand the board back."
	).is_false()


func test_move_relocates_the_selected_unit() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 20, 0, Vector2i(4, 5))
	_move_cursor_to(root, Vector2i(4, 5))
	assert_bool(root.select_at_cursor()).is_true()

	# Pick a reachable tile other than the unit's own.
	var dest := Vector2i(-1, -1)
	for r in Movement.reachable(state, state.entities_by_id[20]):
		if r.tile != Vector2i(4, 5):
			dest = r.tile
			break
	assert_bool(dest != Vector2i(-1, -1)).is_true()

	_move_cursor_to(root, dest)
	assert_bool(root.act_at_cursor()).is_true()
	assert_vector((state.entities_by_id[20] as UnitState).position).is_equal(dest)


func test_attack_damages_an_adjacent_enemy() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 20, 0, Vector2i(4, 5), UnitTypes.TROOPER) # friendly attacker
	_place_unit(state, 21, 1, Vector2i(5, 5), UnitTypes.TROOPER) # enemy, adjacent
	_move_cursor_to(root, Vector2i(4, 5))
	assert_bool(root.select_at_cursor()).is_true()

	# (5,5) must be a legal target of the selected attacker for the act to attack.
	var is_target := false
	for t in Combat.legal_targets(state, state.entities_by_id[20]):
		if t.tile == Vector2i(5, 5):
			is_target = true
	assert_bool(is_target).is_true()

	var hp_before: int = (state.entities_by_id[21] as UnitState).current_hp
	_move_cursor_to(root, Vector2i(5, 5))
	assert_bool(root.act_at_cursor()).is_true()

	# The enemy took damage (or was destroyed → removed from the entity set).
	var enemy: Variant = state.entities_by_id.get(21)
	var damaged: bool = enemy == null or (enemy as UnitState).current_hp < hp_before
	assert_bool(damaged).is_true()


func _place_structure(state: GameState, id: int, owner: int, tile: Vector2i, \
		type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = id
	s.owner = owner
	s.position = tile
	s.type = type
	s.current_hp = type.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[id] = s
	state.grid.place(id, tile.x, tile.y)
	return s


func test_produce_uses_a_second_producer_when_the_hq_is_at_cap() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	# Max out the HQ's production this turn, so the producer scan must skip it.
	var hq: StructureState = state.entities_by_id[0] as StructureState
	hq.units_produced_this_turn = hq.type.production_cap
	# The player also owns a completed Production Outpost with capacity. Select a
	# type the OUTPOST makes (the HQ makes only Scout and is maxed): the roster is
	# [Scout(HQ), Trooper, Heavy, Sniper(outpost)], so cycle off Scout onto an
	# outpost type.
	var outpost: StructureState = _place_structure(state, 30, 0, Vector2i(3, 5), StructureTypes.BARRACKS)
	root.cycle_produce_type()
	var utype: UnitTypeDef = root.selected_produce_type()
	assert_bool(outpost.type.producible_types.has(utype)).is_true()
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(30, utype)
	assert_bool(deploy.is_empty()).is_false()
	var target: Vector2i = deploy[0]
	_move_cursor_to(root, target)

	var before: int = state.entities().size()
	assert_bool(root.request_produce_at_cursor()).is_true() # produced from the outpost, HQ skipped.
	# ⚠ S8-28: the commit starts a build on the OUTPOST; deliver it before asserting.
	# ★ That the outpost — not the maxed HQ — is the one holding the build is the real
	# subject of this test, and it is now directly observable rather than inferred.
	assert_object(outpost.producing_type).is_same(utype)
	assert_object(hq.producing_type).is_null()
	BaseProduction.advance_build_timers(state, 0)
	assert_int(state.entities().size()).is_equal(before + 1)
	assert_bool(state.entity_at(target) is UnitState).is_true()


func test_produce_unit_type_selection_cycles_and_deploys_the_selected_type() -> void:
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	# Own a Production Outpost (produces multiple types) so the roster has >1 entry
	# (the HQ alone only makes one).
	_place_structure(state, 30, 0, Vector2i(3, 5), StructureTypes.BARRACKS)

	# Selection defaults to the roster's first type; V cycles it to a different one.
	var first: UnitTypeDef = root.selected_produce_type()
	root.cycle_produce_type()
	var chosen: UnitTypeDef = root.selected_produce_type()
	assert_bool(chosen != first).is_true()
	# ★ 2026-08-24: the status overlay no longer names the produce type. It used to,
	# because the type was a HIDDEN cycled value with nowhere else to be read; the
	# action menu's Produce submenu now lists every type with its live cost, so the
	# legend went back to being a legend. What must still hold is that the roster
	# offers the type and that producing it deploys it — both asserted below.
	assert_bool(root._produce_roster().has(chosen)).is_true()

	# Produce deploys the SELECTED type at the cursor (from a producer offering it).
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(30, chosen)
	assert_bool(deploy.is_empty()).is_false()
	var target: Vector2i = deploy[0]
	_move_cursor_to(root, target)
	assert_bool(root.request_produce_at_cursor()).is_true()
	# ⚠ S8-28: deliver the build. The assertion that matters — the SELECTED type is the
	# one that arrives — is unchanged, and is now also checkable before delivery.
	BaseProduction.advance_build_timers(state, 0)
	var produced: EntityState = state.entity_at(target)
	assert_bool(produced is UnitState).is_true()
	assert_str((produced as UnitState).type.display_name).is_equal(chosen.display_name)


func test_under_construction_producer_excluded_from_roster_until_complete() -> void:
	# Regression for "can't produce anything but Scout": a freshly-built Production
	# Outpost is UNDER_CONSTRUCTION (build_time 2) and cannot produce yet. Its types
	# must stay OUT of the roster (so the player can't cycle to an un-producible
	# type and have P silently do nothing), and the overlay must flag it.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	var outpost: StructureState = _place_structure(state, 30, 0, Vector2i(3, 5), StructureTypes.BARRACKS)
	outpost.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION
	outpost.build_turns_remaining = 2

	# While building: roster is only the HQ's Scout; cycling can't reach an outpost
	# type, and the overlay flags the building producer.
	root.cycle_produce_type()
	assert_bool(outpost.type.producible_types.has(root.selected_produce_type())).is_false()
	# ★ 2026-08-24: the "X building (N turns)" note left the status overlay with the
	# rest of the produce copy. What it existed to tell the player — that an
	# unfinished producer's units are not available yet — is now told where the
	# choice is made: the Produce submenu simply does not list them, and the verb row
	# itself reads "still building". The ROSTER assertion above is the real invariant
	# and it still holds.

	# Complete it → its types join the roster and one becomes producible.
	outpost.build_status = StructureState.BuildStatus.COMPLETED
	outpost.build_turns_remaining = 0
	var guard: int = 0
	while not outpost.type.producible_types.has(root.selected_produce_type()) and guard < 8:
		root.cycle_produce_type()
		guard += 1
	var chosen: UnitTypeDef = root.selected_produce_type()
	assert_bool(outpost.type.producible_types.has(chosen)).is_true()
	var deploy: Array[Vector2i] = GameStateReader.new(state).legal_deploy_tiles(30, chosen)
	assert_bool(deploy.is_empty()).is_false()
	_move_cursor_to(root, deploy[0])
	var before: int = state.entities().size()
	assert_bool(root.request_produce_at_cursor()).is_true() # now produces from the completed outpost
	# ⚠ S8-28: deliver the build. The invariant under test — an UNDER_CONSTRUCTION
	# producer's types stay out of the roster until it completes — is untouched by the
	# production queue and is asserted above.
	BaseProduction.advance_build_timers(state, 0)
	assert_int(state.entities().size()).is_equal(before + 1)


func test_act_with_no_ap_flashes_an_ap_reason_instead_of_silently_doing_nothing() -> void:
	# Regression for "produced units can't move or attack": producing spends the
	# shared AP budget, so a fresh unit may have no AP to act the same turn. Pressing
	# M must explain that (not silently no-op).
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 10, 0, Vector2i(5, 5), UnitTypes.TROOPER)
	state.per_player[0].current_ap = 0 # spent it all producing.

	_move_cursor_to(root, Vector2i(5, 5))
	assert_bool(root.select_at_cursor()).is_true()
	_move_cursor_to(root, Vector2i(5, 6)) # a cursor move clears any prior flash first.
	assert_bool(root.act_at_cursor()).is_false() # can't move or attack with 0 AP
	# ★ 2026-08-24: the reason comes from CommandFSM's own Reason bitmask via
	# ActionMenu.reason_text rather than from a bespoke hint string, so the keyboard
	# accelerator and the greyed-out menu row give the SAME explanation instead of
	# two hand-written ones that could drift apart.
	#
	# ★★ And the wording is now the RIGHT one. This test used to accept "no route"
	# and carried a note explaining why that was the model's honest answer:
	# Movement.reachable() is AP-bounded, so at 0 AP it returned an empty set and
	# _move_entry could not tell "broke" from "walled in". That was recorded as
	# action-menu.md OQ-5 and has since been FIXED — a second, AP-free query
	# separates the two, so a unit standing in open ground with no AP is told it
	# needs AP, which points at ending the turn rather than at clearing a path.
	assert_str(root.status_text()).contains("Move unavailable")
	assert_str(root.status_text()).override_failure_message(
		"a unit in open ground with no AP must be told it needs AP, not that it has no route"
	).contains("needs AP")


func test_selecting_a_unit_renders_its_range_overlay_without_error() -> void:
	# Selecting a unit draws its reachable/attackable range (blue fill / red outline)
	# in _draw. Force a redraw + frame so _draw_selection_overlay runs; a bad draw
	# call would surface as a script error here.
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 11, 0, Vector2i(6, 5), UnitTypes.TROOPER)
	state.per_player[0].current_ap = 10
	_move_cursor_to(root, Vector2i(6, 5))
	assert_bool(root.select_at_cursor()).is_true()
	root.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	# Selection holds and the range was computed/drawn without error.
	assert_int(root.command_interface().selected_id()).is_equal(11)


func test_status_legend_names_the_selection_independent_controls_only() -> void:
	# ★ REWRITTEN 2026-08-24 for the action menu. This test used to assert that the
	# legend named the current Build type, its [C] cycle key, a "Produce [P]:" line
	# with a live cost, and eleven bindings across two lines — because every verb was
	# its own key and every type choice was a hidden cycled value with nowhere else
	# to be read. All of that moved to where the decision is made: the menu shows the
	# verbs and their shortcuts, the pickers show the types and their costs.
	#
	# What is left, and what this now pins, is the complement: the legend names the
	# controls that belong to NO selection. Those have no other home, and an unnamed
	# binding is an unreachable feature — the failure mode that left cursor-jump
	# declared, unhandled and unused for four sprints.
	var root := _make_root()
	var legend: String = root.status_text()

	assert_str(legend).contains("cursor")     # how to move around the board
	assert_str(legend).contains("confirm")    # how to act on the tile you are on
	assert_str(legend).contains("back")       # how to get out of anything
	assert_str(legend).contains("end turn")   # how to finish
	assert_str(legend).contains("jump cursor")
	assert_str(legend).contains("build")      # the one player-level verb (CR-5)


func test_status_legend_no_longer_names_the_retired_cycle_bindings() -> void:
	# action-menu.md AC-17. The [C]/[V] type-cycle commands were REMOVED, not
	# rebound — the submenu shows every type outright, so a cycle would be a second
	# way to mutate a choice the menu already displays. A legend that still named
	# them would be telling the player about keys that do nothing, which is the exact
	# failure the whole menu exists to end.
	var root := _make_root()
	var legend: String = root.status_text()

	assert_str(legend).not_contains("[C] cycle")
	assert_str(legend).not_contains("[V] cycle")
	assert_str(legend).not_contains("cycle Build")
	assert_bool(InputMap.has_action(&"board_build_cycle")).override_failure_message(
		"the retired cycle action must be gone from the InputMap, not just from the legend"
	).is_false()
	assert_bool(InputMap.has_action(&"board_produce_cycle")).is_false()
	# ...and its replacement must exist, or Attack has no accelerator at all.
	assert_bool(InputMap.has_action(&"board_attack")).is_true()


func test_opening_a_move_preview_shows_the_projected_ap_on_the_counter() -> void:
	# ★ 2026-08-24 (/ux-review blocking finding 4). command-action-interface.md D-1
	# requires `projected_remaining_ap` to render inline on the HUD's AP counter as
	# `current -> projected`, and game-hud.md records that seam as RESOLVED. It was
	# resolved on paper only: GameHud.open_ap_preview() had no production caller in
	# the entire codebase — just its own unit test — so the projected-cost readout
	# the GDD promises had never once been shown to a player. Entering a preview
	# from the action menu is exactly when it should fire.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 10, 0, Vector2i(5, 5), UnitTypes.TROOPER)

	_move_cursor_to(root, Vector2i(5, 5))
	assert_bool(root.select_at_cursor()).is_true()
	assert_bool(root.open_verb_preview(CommandFSM.Verb.MOVE)).is_true()
	# Step onto a neighbouring reachable tile — a move's price is per-tile, so the
	# echo only means anything once the cursor is somewhere it could actually go.
	_move_cursor_to(root, Vector2i(5, 6))

	var counter: ApCounterWidget = root.hud().ap_counter()
	assert_bool(counter.showing_echo()).override_failure_message(
		"entering a move preview must open the AP counter's current -> projected echo"
	).is_true()
	var reach: Movement.ReachableTile = root.command_interface().get_reachable_tile(Vector2i(5, 6))
	assert_object(reach).is_not_null()
	assert_int(counter.projected_value()).override_failure_message(
		"the projection must be CommandFSM's, not a local subtraction"
	).is_equal(CommandFSM.projected_remaining_ap(state, 0, reach.min_cost))


func test_backing_out_of_a_preview_clears_the_projection() -> void:
	# ★ A stale projection is worse than none: it sits on the counter claiming AP
	# the player still has. Backing out is one of six paths that must clear it,
	# which is why the slice recomputes from state rather than pairing open/close
	# calls at each verb.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 10, 0, Vector2i(5, 5), UnitTypes.TROOPER)

	_move_cursor_to(root, Vector2i(5, 5))
	root.select_at_cursor()
	root.open_verb_preview(CommandFSM.Verb.MOVE)
	_move_cursor_to(root, Vector2i(5, 6))
	assert_bool(root.hud().ap_counter().showing_echo()).is_true()

	root.back_out()

	assert_bool(root.hud().ap_counter().showing_echo()).override_failure_message(
		"the echo outlived the preview it was pricing"
	).is_false()


func test_an_economic_preview_prices_BOTH_pools_at_once() -> void:
	# ★ D-1b: Build and Produce spend Credits AND AP, and a player shown only one
	# of them cannot tell which pool the purchase will exhaust. The Credits half of
	# this seam had no passthrough on GameHud at all until this was wired.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	_select_a_builder(root)
	var type: StructureTypeDef = StructureTypes.BARRACKS

	root.begin_build_preview(type)

	var ap: ApCounterWidget = root.hud().ap_counter()
	var credits: CreditsCounterWidget = root.hud().credits_counter()
	assert_bool(ap.showing_echo()).is_true()
	assert_bool(credits.showing_echo()).override_failure_message(
		"an economic preview must price the Credit pool alongside the AP pool"
	).is_true()
	assert_int(credits.projected_value()).is_equal(
		5000 - BaseProduction.effective_build_cost(state, type, 0)
	)


func test_a_move_preview_leaves_the_credit_counter_alone() -> void:
	# The complement: Move and Attack are AP-only, so an echo reading
	# "1000 -> 1000" on the Credit counter would be noise pretending to be
	# information.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	_place_unit(state, 10, 0, Vector2i(5, 5), UnitTypes.TROOPER)

	_move_cursor_to(root, Vector2i(5, 5))
	root.select_at_cursor()
	root.open_verb_preview(CommandFSM.Verb.MOVE)
	_move_cursor_to(root, Vector2i(5, 6))

	assert_bool(root.hud().credits_counter().showing_echo()).is_false()


func test_the_menu_driven_build_flow_actually_commits_at_the_cursor() -> void:
	# ★ REGRESSION, found 2026-08-24 by the /ux-review cost-echo work. The
	# menu-driven Build flow painted its legal-tile overlay and held its pending
	# type, but never drove the FSM into PREVIEW_BUILD — so fsm_state stayed IDLE,
	# commit_at_cursor's match fell through to its "nothing previewed, so select
	# what is under the cursor" default, and confirming on a highlighted build tile
	# silently did nothing. The old direct request_build_at_cursor() path still
	# worked, which is why every existing build test passed over the defect.
	var root := _make_root()
	var state := root.state()
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 5000
	var builder: UnitState = _select_a_builder(root)
	var type: StructureTypeDef = StructureTypes.BARRACKS

	root.begin_build_preview(type)
	assert_int(root.command_interface().fsm_state()).override_failure_message(
		"begin_build_preview must put the interface INTO the build preview state"
	).is_equal(CommandFSM.State.PREVIEW_BUILD)

	var legal: Array[Vector2i] = BaseProduction.legal_build_tiles_for(state, builder)
	assert_bool(legal.is_empty()).is_false()
	_move_cursor_to(root, legal[0])
	var before: int = state.entities().size()

	assert_bool(root.commit_at_cursor()).override_failure_message(
		"confirming on a highlighted build tile must place the structure"
	).is_true()
	# One unit spent for one structure, so the entity count holds steady.
	assert_int(state.entities().size()).is_equal(before)
	assert_bool(state.entity_at(legal[0]) is StructureState).is_true()


func test_a_refused_commit_tells_the_player_why_instead_of_nothing() -> void:
	# ★ 2026-08-24 (/ux-review advisory 8). GameState.action_applied is emitted on
	# SUCCESS only (ADR-0004 step 7), and dispatch_commit returns "a commit was
	# dispatched" rather than "it worked" — so a refused commit reached nothing in
	# the slice. The player pressed confirm, the action was refused, and the screen
	# said nothing: they would read that as the input not registering and press
	# again. Rejections are rare (every path pre-checks against the same queries the
	# validators use), and rare is exactly what makes a silent one unreadable.
	var root := _make_root()
	var state := root.state()

	# Force a refusal the pre-checks cannot catch: a legal-looking action aimed at
	# a player who is not the active one.
	var action := EndTurnAction.new()
	action.player = 0
	state.active_player = 1
	root.command_interface().commit(state, action)

	assert_str(root.status_text()).override_failure_message(
		"a refused commit must say why — silence is the failure being fixed"
	).contains("Refused")


func test_rejection_wording_comes_from_the_same_vocabulary_the_menu_uses() -> void:
	# The greyed-out row that would have predicted the refusal and the line the
	# player reads after it must speak the same way. Two tables in two files drift
	# into two vocabularies.
	assert_str(ActionMenu.commit_rejection_text(Action.Reason.CANT_AFFORD)).is_equal("needs AP")
	assert_str(ActionMenu.commit_rejection_text(Action.Reason.CANT_AFFORD_CREDITS)) \
		.is_equal("needs Credits")
	# ...and the same phrases the menu's own disabled rows use.
	assert_str(ActionMenu.reason_text(CommandFSM.Reason.INSUFFICIENT_AP)).is_equal("needs AP")
	assert_str(ActionMenu.reason_text(CommandFSM.Reason.INSUFFICIENT_CREDITS)) \
		.is_equal("needs Credits")


func test_an_unmapped_rejection_still_says_something_naming_its_code() -> void:
	# A rejection the interface cannot name is still one the player must be told
	# about — and the code makes it reportable.
	var text: String = ActionMenu.commit_rejection_text(9999)
	assert_str(text).is_not_empty()
	assert_str(text).contains("9999")


func test_camera_frames_the_whole_board_within_the_view() -> void:
	# The fit-to-board camera must show every board tile at boot (regression for the
	# "board off-screen / window too small" report — old fixed zoom 2.0 clipped it).
	# Pin a realistic window size — the headless default viewport is 64x64, which
	# degenerates any framing check.
	var prev_size: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	var root := _make_root()
	var cam: Camera2D = root.camera()
	var board: BoardRenderer = root.board()
	var half_view: Vector2 = root.get_viewport_rect().size * 0.5 / cam.zoom
	var view_min: Vector2 = cam.position - half_view
	var view_max: Vector2 = cam.position + half_view

	# All four corner tiles fall inside the visible world rect.
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(11, 0), Vector2i(0, 9), Vector2i(11, 9)]:
		var p: Vector2 = board.grid_to_screen(tile)
		assert_bool(p.x >= view_min.x and p.x <= view_max.x).is_true()
		assert_bool(p.y >= view_min.y and p.y <= view_max.y).is_true()

	# And the camera is zoomed to fit (never the old clipped 2.0, never degenerate).
	assert_float(cam.zoom.x).is_between(0.3, 1.5)

	get_window().size = prev_size


func test_move_relocates_a_non_scout_unit() -> void:
	# Regression: moving a Trooper/Heavy/Sniper (move_cost > 1) was rejected because
	# MoveAction.tiles_entered was set to the AP cost (reach.min_cost) instead of the
	# tile count, so validate_move's cost check failed for everything but the Scout.
	var root := _make_root()
	var state := root.state()
	_place_unit(state, 12, 0, Vector2i(6, 5), UnitTypes.TROOPER) # move_cost 2
	state.per_player[0].current_ap = 20 # ample AP — not an affordability case.

	_move_cursor_to(root, Vector2i(6, 5))
	assert_bool(root.select_at_cursor()).is_true()
	_move_cursor_to(root, Vector2i(6, 6)) # an adjacent reachable tile
	assert_bool(root.act_at_cursor()).is_true() # the Trooper moves (was falsely rejected)
	assert_bool(state.entity_at(Vector2i(6, 6)) is UnitState).is_true()
	assert_vector((state.entities_by_id[12] as UnitState).position).is_equal(Vector2i(6, 6))


func test_board_occupant_layer_holds_one_real_sprite_per_live_entity() -> void:
	# Story 006 replaced this test's original premise. It used to assert the layer
	# was EMPTY at boot, because BoardRenderer._ready seeded br-002 Polygon2D demo
	# fixtures the slice had to strip. Those fixtures are gone and the layer now
	# holds the real board, so the regression worth guarding is the inverse: every
	# child is genuine content, and nothing placeholder-shaped survives.
	var root := _make_root()
	var board: BoardRenderer = root.board()
	var state := root.state()
	var children := board.occupant_layer.get_children()

	var sprites := 0
	for child: Node in children:
		# No Polygon2D placeholders, and nothing that fights the parent Y-sort.
		assert_bool(child is Sprite2D).is_true()
		assert_int((child as Node2D).z_index).is_equal(0)
		if not child.name.begins_with(BoardRenderer.COVER_PROP_NAME_PREFIX):
			sprites += 1

	# One entity sprite per live entity — two HQs and two starting Builders at boot
	# (S8-29). ★ The first assertion is the real invariant and is self-maintaining; the
	# literal below is deliberately kept alongside it so the suite would notice the
	# starting roster changing SILENTLY, which is how the Builder shipped with no art.
	assert_int(sprites).is_equal(state.entities().size())
	assert_int(sprites).is_equal(4)
