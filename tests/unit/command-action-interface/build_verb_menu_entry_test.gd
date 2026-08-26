# The Build row — Build as a Builder's verb (user decision, 2026-08-25).
#
# WHY THIS SUITE EXISTS: Build used to be a PLAYER-level command (CR-5) with no
# entity behind it — a persistent HUD button, deliberately absent from
# `menu_model` entirely. It now belongs to a Builder unit, is placed on a tile
# beside that unit, and CONSUMES it. That makes it an ordinary menu verb, and it
# needs the same coverage every other verb has.
#
# The rule these tests pin hardest is CR-4's STRUCTURAL vs SITUATIONAL line, as
# clarified in S8-11:
#   • "this kind of thing can never build" -> the row is HIDDEN (a Trooper must not
#     carry a permanently dead "Build — not a builder" row, which is the exact
#     defect the NOT_A_PRODUCER fix removed from every unit in S8-10);
#   • "you cannot afford it / there is no room right now" -> the row STAYS, dimmed,
#     saying which, because that row is what teaches the player the price.
extends GdUnitTestSuite


func _make_grid(size: int = 10) -> GridState:
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


func _make_state(credits: int = 100000, ap: int = 100) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_credits = credits
		state.per_player[i].current_ap = ap
	return state


func _place(state: GameState, entity: EntityState) -> void:
	state.entities_by_id[entity.entity_id] = entity
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)


func _place_unit(state: GameState, id: int, type: UnitTypeDef, pos: Vector2i, \
		owner: int = 0) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	_place(state, unit)
	return unit


func _build_entry(state: GameState, entity: EntityState) -> CommandFSM.VerbEntry:
	# By verb, never by enum ordinal — the menu array is ordered for display.
	return CommandFSM.entry_for(CommandFSM.menu_model(state, entity), CommandFSM.Verb.BUILD)


# ==============================================================================
# Who gets a Build row at all — the structural half of CR-4.
# ==============================================================================

func test_a_builder_with_room_and_funds_can_build() -> void:
	# Arrange
	var state := _make_state()
	var builder := _place_unit(state, 1, UnitTypes.BUILDER, Vector2i(5, 5))

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, builder)

	# Assert
	assert_bool(entry.enabled).is_true()
	assert_int(entry.reason).is_equal(CommandFSM.Reason.NONE)


func test_an_ordinary_unit_reports_a_structural_reason_so_the_row_is_hidden() -> void:
	# ★ The row must be HIDDEN, not dimmed. A dimmed "Build — not a builder" line on
	# every Scout, Trooper, Heavy and Sniper in the game teaches nothing and costs a
	# row on almost every menu — the same defect S8-10 removed for Produce.
	# Arrange
	var state := _make_state()
	var scout := _place_unit(state, 1, UnitTypes.SCOUT, Vector2i(5, 5))

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, scout)

	# Assert
	assert_bool(entry.enabled).is_false()
	assert_bool((entry.reason & CommandFSM.Reason.NOT_A_BUILDER) != 0).is_true()
	assert_bool(ActionMenu._is_inapplicable(entry)).override_failure_message(
		"a unit that can NEVER build must have its Build row hidden, not dimmed"
	).is_true()


func test_a_structure_never_gets_a_build_row() -> void:
	# Structures produce units; they do not raise buildings. Also structural.
	# Arrange
	var state := _make_state()
	var hq := StructureState.new()
	hq.entity_id = 1
	hq.owner = 0
	hq.position = Vector2i(5, 5)
	hq.type = StructureTypes.HQ
	hq.current_hp = StructureTypes.HQ.hp
	hq.build_status = StructureState.BuildStatus.COMPLETED
	_place(state, hq)

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, hq)

	# Assert
	assert_bool(entry.enabled).is_false()
	assert_bool(ActionMenu._is_inapplicable(entry)).is_true()


# ==============================================================================
# Why a Builder cannot build right now — the situational half. These rows STAY.
# ==============================================================================

func test_a_penniless_builder_keeps_a_visible_row_naming_the_pool() -> void:
	# Arrange -- plenty of AP, no Credits.
	var state := _make_state(0, 100)
	var builder := _place_unit(state, 1, UnitTypes.BUILDER, Vector2i(5, 5))

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, builder)

	# Assert -- disabled for the RIGHT pool, and still shown.
	assert_bool(entry.enabled).is_false()
	assert_bool((entry.reason & CommandFSM.Reason.INSUFFICIENT_CREDITS) != 0).is_true()
	assert_bool((entry.reason & CommandFSM.Reason.NOT_A_BUILDER) != 0).is_false()
	assert_bool(ActionMenu._is_inapplicable(entry)).override_failure_message(
		"'you cannot afford this' is SITUATIONAL — the row must stay visible, " +
		"because that row is what teaches the player what building costs"
	).is_false()


func test_a_boxed_in_builder_says_it_has_no_room() -> void:
	# Arrange -- every cardinal neighbour walled off, so the Builder's frontier is
	# empty even though it is standing on open ground with money in the bank.
	var state := _make_state()
	var builder := _place_unit(state, 1, UnitTypes.BUILDER, Vector2i(5, 5))
	for n: Vector2i in [Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6), Vector2i(4, 5)]:
		state.grid.terrain[state.grid.index(n.x, n.y)] = GridState.Terrain.IMPASSABLE

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, builder)

	# Assert
	assert_bool(entry.enabled).is_false()
	assert_bool((entry.reason & CommandFSM.Reason.NO_BUILD_SPACE) != 0).is_true()
	assert_bool(ActionMenu._is_inapplicable(entry)).is_false()


func test_both_failing_conjuncts_are_named_not_just_the_first() -> void:
	# AC-8's multi-reason discipline, applied to Build: a Builder that is broke AND
	# boxed in has two problems, and fixing only the one it mentions leaves the
	# player pressing a row that still does nothing.
	# Arrange
	var state := _make_state(0, 100)
	var builder := _place_unit(state, 1, UnitTypes.BUILDER, Vector2i(5, 5))
	for n: Vector2i in [Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6), Vector2i(4, 5)]:
		state.grid.terrain[state.grid.index(n.x, n.y)] = GridState.Terrain.IMPASSABLE

	# Act
	var entry: CommandFSM.VerbEntry = _build_entry(state, builder)

	# Assert
	assert_bool((entry.reason & CommandFSM.Reason.INSUFFICIENT_CREDITS) != 0).is_true()
	assert_bool((entry.reason & CommandFSM.Reason.NO_BUILD_SPACE) != 0).is_true()


# ==============================================================================
# Placement is scoped to the acting Builder, not to the player.
# ==============================================================================

func test_build_tiles_come_from_the_acting_builder_not_from_any_owned_entity() -> void:
	# ★ THE REGRESSION THIS RULE REPLACED. legal_build_tiles used to scan every
	# entity the player owned, so a base on the far side of the map made tiles legal
	# next to itself. Scoped to one Builder, only ITS neighbours count — otherwise a
	# player could raise a building beside a builder standing somewhere else.
	# Arrange -- two Builders far apart.
	var state := _make_state()
	var near := _place_unit(state, 1, UnitTypes.BUILDER, Vector2i(2, 2))
	var far := _place_unit(state, 2, UnitTypes.BUILDER, Vector2i(8, 8))

	# Act
	var near_tiles: Array[Vector2i] = BaseProduction.legal_build_tiles_for(state, near)
	var far_tiles: Array[Vector2i] = BaseProduction.legal_build_tiles_for(state, far)

	# Assert -- disjoint, and each hugs its own builder.
	assert_bool(near_tiles.has(Vector2i(3, 2))).is_true()
	assert_bool(near_tiles.has(Vector2i(8, 7))).override_failure_message(
		"a Builder must not make tiles legal beside a DIFFERENT builder"
	).is_false()
	assert_bool(far_tiles.has(Vector2i(8, 7))).is_true()


func test_a_unit_that_cannot_build_yields_no_build_tiles() -> void:
	# An ordinary answer, not an error — asking is how the menu learns to hide the row.
	var state := _make_state()
	var scout := _place_unit(state, 1, UnitTypes.SCOUT, Vector2i(5, 5))
	assert_array(BaseProduction.legal_build_tiles_for(state, scout)).is_empty()


func test_a_player_with_no_builder_can_build_nowhere() -> void:
	# The rule that replaced the HUD Build button, stated at the query level.
	var state := _make_state()
	_place_unit(state, 1, UnitTypes.SCOUT, Vector2i(5, 5))
	assert_array(BaseProduction.legal_build_tiles(state, 0, StructureTypes.BARRACKS)) \
		.override_failure_message(
			"an army without a Builder must have nowhere to build at all"
		).is_empty()
