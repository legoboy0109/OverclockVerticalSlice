# Action menu option models — CommandFSM.produce_options / build_options, and
# ActionMenu.reason_text (design/ux/action-menu.md).
#
# These are the models the contextual action menu's two TYPE PICKERS render.
# CommandFSM.menu_model already answers "can this entity produce anything at all"
# by short-circuiting on the first affordable type — the right answer for a menu
# ROW and the wrong one for a menu you choose FROM, because it cannot say WHICH
# types are the affordable ones. These functions answer that, per type.
#
#   AC-13: the Produce submenu lists every producible type with its dual cost, and
#     an unaffordable type is disabled naming the BINDING pool (CR-8 / D-2).
#   AC-4:  a row disabled for two reasons renders both — reason_text must never
#     drop a flag (AC-8b's "no reason is hidden for the player to discover later"
#     is a rendering requirement as much as a model one).
#
# Deterministic: no RNG, no time, no I/O.
extends GdUnitTestSuite


# --- Fixture helpers (mirroring command_fsm_test.gd's conventions) ------------

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
	# Neutral pins the faction fold in effective_produce_cost to a no-op, so the
	# costs asserted below are the base numbers and nothing else.
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type(name: String, produce_cost: int) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = name
	type.hp = 10
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 8
	type.produce_cost = produce_cost
	return type


func _make_structure_type(producible: Array[UnitTypeDef]) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestProducer"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 2
	type.production_cap = 2
	type.producible_types = producible
	return type


func _place_structure(state: GameState, entity_id: int, owner: int, pos: Vector2i, \
		type: StructureTypeDef, \
		build_status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = build_status
	state.entities_by_id[entity_id] = structure
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return structure


func _place_unit(state: GameState, entity_id: int, owner: int, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = _make_unit_type("Placed", 4)
	unit.current_hp = unit.type.hp
	state.entities_by_id[entity_id] = unit
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = entity_id
	return unit


# ==============================================================================
# produce_options — AC-13
# ==============================================================================

func test_produce_options_lists_every_producible_type_in_the_producers_order() -> void:
	# Arrange — the whole reason this exists: menu_model's Produce row can only say
	# "yes, something is producible". The picker must name all of them.
	var state := _make_state()
	var cheap := _make_unit_type("Cheap", 2)
	var dear := _make_unit_type("Dear", 5)
	var producer_type := _make_structure_type([cheap, dear] as Array[UnitTypeDef])
	var producer := _place_structure(state, 1, 0, Vector2i(4, 4), producer_type)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500

	# Act
	var options: Array[CommandFSM.ProduceOption] = CommandFSM.produce_options(state, producer)

	# Assert — order follows producible_types, so the picker's rows are stable
	# between openings rather than reshuffling with affordability.
	assert_int(options.size()).is_equal(2)
	assert_object(options[0].unit_type).is_same(cheap)
	assert_object(options[1].unit_type).is_same(dear)


func test_produce_options_reports_each_types_own_dual_cost() -> void:
	# Arrange
	var state := _make_state()
	var cheap := _make_unit_type("Cheap", 2)
	var dear := _make_unit_type("Dear", 5)
	var producer := _place_structure(
		state, 1, 0, Vector2i(4, 4), _make_structure_type([cheap, dear] as Array[UnitTypeDef])
	)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500

	# Act
	var options: Array[CommandFSM.ProduceOption] = CommandFSM.produce_options(state, producer)

	# Assert — Credits differ per type; the AP surcharge is per-ACTION and therefore
	# identical on every row (ADR-0006 dual-cost).
	assert_int(options[0].credit_cost).is_equal(
		Unit.effective_produce_cost(state, cheap, 0)
	)
	assert_int(options[1].credit_cost).is_equal(
		Unit.effective_produce_cost(state, dear, 0)
	)
	assert_int(options[0].ap_cost).is_equal(options[1].ap_cost)


func test_an_affordable_and_an_unaffordable_type_appear_in_the_same_list() -> void:
	# ★ THE test for this function. Under menu_model alone the player is told
	# "Produce is available" and then has to discover by trying that the Heavy is
	# out of reach. The picker must show both facts at once.
	var state := _make_state()
	var cheap := _make_unit_type("Cheap", 2)
	var dear := _make_unit_type("Dear", 999)
	var producer := _place_structure(
		state, 1, 0, Vector2i(4, 4), _make_structure_type([cheap, dear] as Array[UnitTypeDef])
	)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = Unit.effective_produce_cost(state, cheap, 0)

	# Act
	var options: Array[CommandFSM.ProduceOption] = CommandFSM.produce_options(state, producer)

	# Assert
	assert_bool(options[0].enabled).override_failure_message(
		"the affordable type must stay enabled even though a sibling is not"
	).is_true()
	assert_bool(options[1].enabled).is_false()
	assert_bool((options[1].reason & CommandFSM.Reason.INSUFFICIENT_CREDITS) != 0) \
		.override_failure_message(
			"the disablement must name the BINDING pool (Credits), never a generic 'unaffordable'"
		).is_true()
	assert_bool((options[1].reason & CommandFSM.Reason.INSUFFICIENT_AP) != 0) \
		.override_failure_message("AP was sufficient — naming it would be a lie").is_false()


func test_an_ap_shortfall_names_ap_on_every_row_because_the_surcharge_is_shared() -> void:
	# Arrange — the mirror of the Credits case. The AP surcharge is per-action, so
	# an AP shortfall is not a property of any one type and must show on all of them.
	var state := _make_state()
	var a := _make_unit_type("A", 2)
	var b := _make_unit_type("B", 3)
	var producer := _place_structure(
		state, 1, 0, Vector2i(4, 4), _make_structure_type([a, b] as Array[UnitTypeDef])
	)
	state.per_player[0].current_ap = 0
	state.per_player[0].current_credits = 500

	# Act
	var options: Array[CommandFSM.ProduceOption] = CommandFSM.produce_options(state, producer)

	# Assert
	for option: CommandFSM.ProduceOption in options:
		assert_bool(option.enabled).is_false()
		assert_bool((option.reason & CommandFSM.Reason.INSUFFICIENT_AP) != 0).is_true()


func test_a_producer_wide_gate_disables_every_row_with_that_same_reason() -> void:
	# Arrange — production cap is a property of the PRODUCER, not of any type, so
	# every row must carry it. A player at cap who saw one row enabled would pick it
	# and have the commit rejected, which is the affordance failure population-cap.md
	# AC-12 was written about.
	var state := _make_state()
	var a := _make_unit_type("A", 2)
	var producer_type := _make_structure_type([a] as Array[UnitTypeDef])
	var producer := _place_structure(state, 1, 0, Vector2i(4, 4), producer_type)
	producer.units_produced_this_turn = producer_type.production_cap
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500

	# Act
	var options: Array[CommandFSM.ProduceOption] = CommandFSM.produce_options(state, producer)

	# Assert
	assert_int(options.size()).is_equal(1)
	assert_bool(options[0].enabled).is_false()
	assert_bool((options[0].reason & CommandFSM.Reason.PRODUCTION_CAP_REACHED) != 0).is_true()


func test_a_non_producer_yields_an_empty_list_rather_than_an_error() -> void:
	# Empty is the honest answer to "what can this make", not a failure — and the
	# caller has already been told NOT_A_PRODUCER by menu_model's own Produce row,
	# so a submenu is never opened here in the first place.
	var state := _make_state()
	var unit := _place_unit(state, 7, 0, Vector2i(2, 2))

	assert_array(CommandFSM.produce_options(state, unit)).is_empty()


func test_an_unfinished_producer_offers_nothing_until_it_completes() -> void:
	# Arrange — its units unlock when it finishes; listing them beforehand would
	# offer a choice that cannot be taken.
	var state := _make_state()
	var a := _make_unit_type("A", 2)
	var producer := _place_structure(
		state, 1, 0, Vector2i(4, 4), _make_structure_type([a] as Array[UnitTypeDef]),
		StructureState.BuildStatus.UNDER_CONSTRUCTION
	)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500

	# Act + Assert
	assert_array(CommandFSM.produce_options(state, producer)).is_empty()

	# ...and the moment it completes, the roster appears.
	producer.build_status = StructureState.BuildStatus.COMPLETED
	assert_int(CommandFSM.produce_options(state, producer).size()).is_equal(1)


# ==============================================================================
# build_options — the player-level Build picker (CR-5)
# ==============================================================================

func test_build_options_costs_and_affordability_are_reported_per_type() -> void:
	# Arrange — Build takes a PLAYER, not an entity: it is not an action any one
	# entity performs, which is why menu_model has no Build row at all.
	var state := _make_state()
	_place_structure(state, 1, 0, Vector2i(4, 4), _make_structure_type([] as Array[UnitTypeDef]))
	var cheap := StructureTypeDef.new()
	cheap.display_name = "Cheap"
	cheap.hp = 10
	cheap.build_cost = 3
	cheap.build_time = 1
	var dear := StructureTypeDef.new()
	dear.display_name = "Dear"
	dear.hp = 10
	dear.build_cost = 9999
	dear.build_time = 1
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = BaseProduction.effective_build_cost(state, cheap, 0)

	# Act
	var options: Array[CommandFSM.BuildOption] = CommandFSM.build_options(
		state, 0, [cheap, dear] as Array[StructureTypeDef]
	)

	# Assert
	assert_int(options.size()).is_equal(2)
	assert_bool(options[0].enabled).is_true()
	assert_bool(options[1].enabled).is_false()
	assert_bool((options[1].reason & CommandFSM.Reason.INSUFFICIENT_CREDITS) != 0).is_true()
	assert_int(options[1].credit_cost).override_failure_message(
		"a disabled row must still show its price — the price IS the explanation"
	).is_greater(0)


# ==============================================================================
# reason_text — AC-4 / AC-8b as a RENDERING requirement
# ==============================================================================

func test_every_set_reason_flag_is_named_not_just_the_first() -> void:
	# ★ A UI that showed only the first flag would break AC-8b while the model
	# stayed perfectly correct — "no reason is hidden for the player to discover
	# later" is a promise about what reaches the screen.
	var mask: int = CommandFSM.Reason.NO_TARGETS \
		| CommandFSM.Reason.INSUFFICIENT_AP \
		| CommandFSM.Reason.INSUFFICIENT_CREDITS
	var text: String = ActionMenu.reason_text(mask)

	assert_str(text).contains("no targets")
	assert_str(text).contains("needs AP")
	assert_str(text).contains("needs Credits")


func test_multi_reason_wording_is_deterministic_not_flag_value_ordered() -> void:
	# The same mask must always read the same way. Ordering off the enum's numeric
	# values would let a future flag renumbering silently reword existing messages.
	var mask: int = CommandFSM.Reason.INSUFFICIENT_AP | CommandFSM.Reason.NO_TARGETS
	assert_str(ActionMenu.reason_text(mask)).is_equal(
		ActionMenu.reason_text(CommandFSM.Reason.NO_TARGETS | CommandFSM.Reason.INSUFFICIENT_AP)
	)
	# ...and legality is stated before affordability: "no targets, needs AP" reads
	# as a sentence; the reverse reads as a list.
	assert_bool(
		ActionMenu.reason_text(mask).find("no targets")
			< ActionMenu.reason_text(mask).find("needs AP")
	).is_true()


func test_an_economic_reason_never_reads_as_a_generic_unaffordable() -> void:
	# CR-8 / D-2: which pool fell short is the actionable half of the message.
	assert_str(ActionMenu.reason_text(CommandFSM.Reason.INSUFFICIENT_CREDITS)) \
		.is_equal("needs Credits")
	assert_str(ActionMenu.reason_text(CommandFSM.Reason.INSUFFICIENT_AP)).is_equal("needs AP")


func test_no_reason_renders_as_empty_so_an_enabled_row_shows_its_shortcut_instead() -> void:
	assert_str(ActionMenu.reason_text(CommandFSM.Reason.NONE)).is_empty()


func test_every_reason_flag_has_player_facing_wording() -> void:
	# ★ The regression that matters as the model grows: a new Reason added to
	# CommandFSM without a label here would render as an EMPTY right-hand column —
	# a row greyed out for no stated cause, which is the exact failure the menu
	# exists to prevent, and one no other test would catch.
	for flag: int in CommandFSM.Reason.values():
		if flag == CommandFSM.Reason.NONE:
			continue
		assert_str(ActionMenu.reason_text(flag)).override_failure_message(
			"Reason flag %d has no entry in ActionMenu.REASON_LABELS/REASON_ORDER" % flag
		).is_not_empty()
