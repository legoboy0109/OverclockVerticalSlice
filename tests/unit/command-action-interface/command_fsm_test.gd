# Story 001: CommandFSM Core — States, Transitions, Menu Model, Pass-Through
# Enforcement.
#
# Covers production/epics/command-action-interface/story-001-command-fsm-core.md
# (TR-cmdui-001: explicit 7-state FSM with terminal no-return GAME_OVER;
# TR-cmdui-010: Pass-Through Invariant — zero balance-constant copies):
#
#   AC (next_state totality): the full 7 states x 11 triggers cross-product
#     returns the GDD States-table target where the table lists a transition,
#     and an inert self-transition (current) everywhere the table is silent;
#     GAME_OVER absorbs every trigger.
#   AC-1: owned unit, non-empty affordable reachable() -> Move enabled=true;
#     empty reachable() -> Move enabled=false with a specific reason.
#   AC-2: enemy/neutral entity handling is a read-only-inspection contract
#     the Node (not this pure core) enforces — see test docstring below for
#     what is/isn't testable at this layer.
#   AC-3: selection clear/switch is Node-owned selection bookkeeping;
#     next_state's IDLE/ENTITY_SELECTED transitions for SELECT_OWN/
#     SELECT_ENEMY_OR_EMPTY/BACK_OUT are covered by the totality table.
#   AC-8: target both out-of-range AND unaffordable -> Attack disabled with
#     BOTH reasons; only-one-conjunct-fails -> only that reason.
#   AC-9: empty reachable()/legal_targets() -> verb disabled-with-reason, not
#     hidden/erroring.
#   AC-10: fully-spent entity / producer with production_cap exhausted / no
#     legal deploy tile -> still selects (menu_model returns a full row set),
#     AP verbs disabled-with-reason, Wait clickable.
#   AC (Pass-Through lint): command_fsm.gd's source holds zero references to
#     any owning-system balance-constant access pattern.
#
# Deterministic: no RNG, no time-dependent assertions, no external I/O beyond
# one static source read for the Pass-Through lint (mirrors
# ai_enumeration_order_test.gd's precedent for that kind of check).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Fixture helpers ---------------------------------------------------------

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
	# Pin both players to Neutral so Unit.effective_produce_cost's faction fold
	# is a no-op (== base). make_state leaves faction null; effective_produce_cost
	# would otherwise dereference a null FactionDef (the VS pin — mirrors the
	# base-production produce tests' fixture convention).
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit_type(move_cost: int = 1, soft_move_cap: int = 8, attack_range: int = 1, \
		hp: int = 10, attack: int = 3) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestUnit"
	type.hp = hp
	type.attack = attack
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


func _make_structure_type(build_cost: int = 6, production_cap: int = 1, \
		producible: Array[UnitTypeDef] = []) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestStructure"
	type.hp = 20
	type.build_cost = build_cost
	type.build_time = 2
	type.production_cap = production_cap
	type.producible_types = producible
	type.attack = 2
	type.attack_range = 1
	return type


func _place_structure(state: GameState, entity_id: int, owner: int, pos: Vector2i, \
		type: StructureTypeDef, build_status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
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


# ==============================================================================
# AC (next_state totality): full 7 x 11 cross-product, table target where
# listed, inert self-transition (current) where silent, GAME_OVER absorbing.
# ==============================================================================

# The GDD States table target for every LISTED (state, trigger) pair,
# transcribed exactly per the coordinator-approved scoping (base "To state"
# column only; see command_fsm.gd's next_state doc comment). Any pair absent
# from this dictionary is asserted to self-transition (return `current`)
# below — this dictionary plus the self-transition default together define
# the total function under test.
static func _expected_transitions() -> Dictionary:
	return {
		[CommandFSM.State.IDLE, CommandFSM.Trigger.SELECT_OWN]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.IDLE, CommandFSM.Trigger.SELECT_ENEMY_OR_EMPTY]: CommandFSM.State.IDLE,
		[CommandFSM.State.IDLE, CommandFSM.Trigger.PICK_BUILD_CMD]: CommandFSM.State.PREVIEW_BUILD,

		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.PICK_MOVE]: CommandFSM.State.PREVIEW_MOVE,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.PICK_ATTACK]: CommandFSM.State.PREVIEW_ATTACK,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.PICK_PRODUCE]: CommandFSM.State.PREVIEW_PRODUCE,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.PICK_BUILD_CMD]: CommandFSM.State.PREVIEW_BUILD,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.SELECT_OWN]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.SELECT_ENEMY_OR_EMPTY]: CommandFSM.State.IDLE,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.WAIT]: CommandFSM.State.IDLE,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.BACK_OUT]: CommandFSM.State.IDLE,
		[CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.COMMIT]: CommandFSM.State.ENTITY_SELECTED,

		[CommandFSM.State.PREVIEW_MOVE, CommandFSM.Trigger.COMMIT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_MOVE, CommandFSM.Trigger.BACK_OUT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_ATTACK, CommandFSM.Trigger.COMMIT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_ATTACK, CommandFSM.Trigger.BACK_OUT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_PRODUCE, CommandFSM.Trigger.COMMIT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_PRODUCE, CommandFSM.Trigger.BACK_OUT]: CommandFSM.State.ENTITY_SELECTED,

		[CommandFSM.State.PREVIEW_BUILD, CommandFSM.Trigger.COMMIT]: CommandFSM.State.ENTITY_SELECTED,
		[CommandFSM.State.PREVIEW_BUILD, CommandFSM.Trigger.BACK_OUT]: CommandFSM.State.IDLE,
	}


func test_next_state_matches_gdd_table_for_every_listed_pair() -> void:
	var state := _make_state()
	var expected: Dictionary = _expected_transitions()
	for key: Array in expected.keys():
		var current: CommandFSM.State = key[0]
		var trigger: CommandFSM.Trigger = key[1]
		var target: CommandFSM.State = expected[key]
		var actual: CommandFSM.State = CommandFSM.next_state(current, trigger, state)
		assert_int(actual).override_failure_message( \
			"next_state(%s, %s) expected %s, got %s" % [current, trigger, target, actual]) \
			.is_equal(target)


func test_next_state_self_transitions_for_every_unlisted_pair() -> void:
	var state := _make_state()
	var expected: Dictionary = _expected_transitions()
	var all_states: Array = CommandFSM.State.values()
	var all_triggers: Array = CommandFSM.Trigger.values()

	for current: CommandFSM.State in all_states:
		if current == CommandFSM.State.GAME_OVER:
			continue # covered by the dedicated absorbing-state test below.
		for trigger: CommandFSM.Trigger in all_triggers:
			if trigger == CommandFSM.Trigger.OBSERVE_GAME_OVER:
				continue # universal transition, covered separately below.
			if expected.has([current, trigger]):
				continue # covered by the listed-pair test above.
			var actual: CommandFSM.State = CommandFSM.next_state(current, trigger, state)
			assert_int(actual).override_failure_message( \
				"next_state(%s, %s) expected inert self-transition %s, got %s" \
				% [current, trigger, current, actual]) \
				.is_equal(current)


func test_next_state_observe_game_over_from_any_non_terminal_state_transitions_to_game_over() -> void:
	var state := _make_state()
	for current: CommandFSM.State in CommandFSM.State.values():
		var actual: CommandFSM.State = CommandFSM.next_state( \
			current, CommandFSM.Trigger.OBSERVE_GAME_OVER, state)
		assert_int(actual).is_equal(CommandFSM.State.GAME_OVER)


func test_next_state_game_over_absorbs_every_trigger() -> void:
	var state := _make_state()
	for trigger: CommandFSM.Trigger in CommandFSM.Trigger.values():
		var actual: CommandFSM.State = CommandFSM.next_state( \
			CommandFSM.State.GAME_OVER, trigger, state)
		assert_int(actual).override_failure_message( \
			"next_state(GAME_OVER, %s) expected GAME_OVER (absorbing), got %s" % [trigger, actual]) \
			.is_equal(CommandFSM.State.GAME_OVER)


func test_next_state_full_cross_product_is_total_77_pairs_no_crash() -> void:
	# Explicit whole-cross-product smoke test (7 states x 11 triggers = 77
	# pairs) — every call must return SOME valid State enum value with no
	# error, proving next_state is total over its full input domain, not
	# merely over the subset the two tests above individually assert on.
	var state := _make_state()
	var call_count := 0
	for current: CommandFSM.State in CommandFSM.State.values():
		for trigger: CommandFSM.Trigger in CommandFSM.Trigger.values():
			var result: CommandFSM.State = CommandFSM.next_state(current, trigger, state)
			assert_bool(result in CommandFSM.State.values()).is_true()
			call_count += 1
	assert_int(call_count).is_equal(77)


# ==============================================================================
# AC-1: owned unit menu — Move enabled/disabled with reason
# ==============================================================================

func test_menu_model_owned_unit_with_affordable_reachable_tile_move_enabled() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8)
	var unit := _place_unit(state, 1, 0, Vector2i(2, 2), type)
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)

	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)
	assert_bool(move_entry.enabled).is_true()
	assert_int(move_entry.reason).is_equal(CommandFSM.Reason.NONE)


func test_disband_is_offered_only_when_it_would_unblock_something() -> void:
	# ★ User decision, 2026-08-25 (revised the same day to add the second trigger).
	# Disband appears when it would RELIEVE something — a Credit deficit or a
	# population ceiling. Those are the two states it exists for; outside them it
	# would be a permanently visible, irreversible row on every unit the player
	# owns. A player with nothing blocked gets NOTHING_BLOCKED, which the menu DROPS
	# rather than renders — see ActionMenu._is_inapplicable for why that is a
	# deliberate exception to the "situational disablement earns a visible row" rule.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(3, 3), _make_unit_type())
	state.per_player[0].current_ap = 10

	var clear: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, unit), CommandFSM.Verb.DISBAND
	)
	assert_bool(clear.enabled).is_false()
	assert_int(clear.reason).is_equal(CommandFSM.Reason.NOTHING_BLOCKED)

	state.per_player[0].in_deficit = true
	var broke: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, unit), CommandFSM.Verb.DISBAND
	)
	assert_bool(broke.enabled).override_failure_message(
		"a player in deficit must be offered the one action that reduces upkeep"
	).is_true()
	assert_int(broke.ap_cost).is_greater(0)


func test_population_cap_offers_disband_even_to_a_solvent_player() -> void:
	# ★★ The second trigger, and the reason it was added the same day. Freeing
	# population is a legitimate NON-deficit reason to disband, and with only the
	# deficit trigger a solvent player at cap was production-locked with no
	# voluntary way out — they had to wait for a unit to die.
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(3, 3), type)
	state.per_player[0].current_ap = 10
	assert_bool(state.per_player[0].in_deficit).is_false() # solvent throughout

	# Fill to the ceiling. effective_cap is read rather than assumed so this stays
	# correct if the faction base or a cap bonus is retuned.
	var cap: int = Population.effective_cap(state, 0)
	var next_id: int = 100
	while Population.current_population(state, 0) < cap:
		_place_unit(state, next_id, 0, Vector2i(next_id % 9, 8), type)
		next_id += 1

	var entry: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, unit), CommandFSM.Verb.DISBAND
	)
	assert_bool(entry.enabled).override_failure_message(
		"a solvent player at population cap must still be able to make room"
	).is_true()


func test_being_over_a_fallen_cap_offers_disband_too() -> void:
	# ★ "At cap" is >=, not ==, and the difference is a real game state: the cap
	# FALLS when a Barracks dies (population-cap.md PC-6) and units above the new
	# ceiling are deliberately not destroyed. A player sitting strictly OVER cap is
	# production-locked, which is exactly when a voluntary way back under matters
	# most — an == test would have left them stranded.
	var state := _make_state(0)
	var type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(3, 3), type)
	state.per_player[0].current_ap = 10

	var cap: int = Population.effective_cap(state, 0)
	var next_id: int = 200
	while Population.current_population(state, 0) <= cap: # deliberately one PAST
		_place_unit(state, next_id, 0, Vector2i(next_id % 9, 7), type)
		next_id += 1
	assert_int(Population.current_population(state, 0)).is_greater(cap)

	var entry: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, unit), CommandFSM.Verb.DISBAND
	)
	assert_bool(entry.enabled).is_true()


func test_disband_in_deficit_is_still_gated_on_ap_and_nothing_else() -> void:
	# ★ Never gated on the deficit LOCK that blocks produce/build/research: disband
	# is the one action that REDUCES upkeep, so refusing it while in deficit would
	# make a deficit unrecoverable by the player's own choice (UR-7). The deficit is
	# what SHOWS this verb; it must never be what blocks it.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(3, 3), _make_unit_type())
	state.per_player[0].in_deficit = true
	state.per_player[0].current_ap = 0

	var entry: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, unit), CommandFSM.Verb.DISBAND
	)

	assert_bool(entry.enabled).is_false()
	assert_int(entry.reason).override_failure_message(
		"the only thing that may disable an offered Disband is AP"
	).is_equal(CommandFSM.Reason.INSUFFICIENT_AP)


func test_attack_entry_carries_its_ap_price_when_enabled() -> void:
	# ★ 2026-08-25 (action-menu.md OQ-2). Attack is the one verb whose price is a
	# single number known before any preview opens, so the model carries it and the
	# menu shows it on the row. The widget renders this figure; it never computes
	# one (Pass-Through Invariant).
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var attacker := _place_unit(state, 1, 0, Vector2i(3, 3), type)
	_place_unit(state, 2, 1, Vector2i(3, 4), type) # adjacent enemy = a legal target
	state.per_player[0].current_ap = 10

	var entry: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, attacker), CommandFSM.Verb.ATTACK
	)

	assert_bool(entry.enabled).is_true()
	assert_int(entry.ap_cost).is_equal(Combat.attack_cost_for(attacker))
	assert_int(entry.ap_cost).is_greater(0)


func test_attack_entry_still_carries_its_price_when_disabled() -> void:
	# ★ The price is MORE useful on the disabled row, not less: "needs AP" alone
	# says you are short, "2 AP · needs AP" says by how much.
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var attacker := _place_unit(state, 1, 0, Vector2i(3, 3), type)
	_place_unit(state, 2, 1, Vector2i(3, 4), type)
	state.per_player[0].current_ap = 0

	var entry: CommandFSM.VerbEntry = _find_entry(
		CommandFSM.menu_model(state, attacker), CommandFSM.Verb.ATTACK
	)

	assert_bool(entry.enabled).is_false()
	assert_int(entry.ap_cost).is_equal(Combat.attack_cost_for(attacker))


func test_verbs_without_a_single_price_say_so_rather_than_reporting_zero() -> void:
	# ★★ The sentinel earns its keep here. Move's price is per-TILE, Produce's is
	# per-TYPE, and Wait is genuinely free — reporting 0 for any of them would put
	# "0 AP" on a row and tell the player something false about two of the three.
	var state := _make_state(0)
	var unit := _place_unit(state, 1, 0, Vector2i(3, 3), _make_unit_type(1, 8))
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)
	for verb: int in [CommandFSM.Verb.MOVE, CommandFSM.Verb.PRODUCE, CommandFSM.Verb.WAIT]:
		assert_int(_find_entry(menu, verb).ap_cost).override_failure_message(
			"verb %d has no single price and must report NO_SINGLE_COST, not a number" % verb
		).is_equal(CommandFSM.NO_SINGLE_COST)


func test_menu_model_unit_with_zero_ap_move_disabled_insufficient_ap() -> void:
	# ★ 2026-08-24 — this test's NAME was right all along and its ASSERTION was
	# wrong. It expected OUT_OF_RANGE for a unit standing in open ground with 0 AP,
	# because that is what the code did: Movement.reachable() applies its
	# affordability cut INSIDE the BFS, so "no AP" and "walled in" both came back
	# as an empty set and the menu reported both as "no route".
	#
	# The two point a player at opposite fixes — clear a path, versus end the turn —
	# so the conflation was a real defect (action-menu.md OQ-5), not a wording nit.
	# Left as a cautionary note: a test whose name contradicts its assertion is
	# worth reading twice, because one of the two is describing intent and the other
	# is describing a bug.
	var state := _make_state(0)
	var type := _make_unit_type(1, 8)
	var unit := _place_unit(state, 1, 0, Vector2i(2, 2), type)
	state.per_player[0].current_ap = 0 # open ground all around; only AP is missing.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)
	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)

	assert_bool(move_entry.enabled).is_false()
	assert_int(move_entry.reason).override_failure_message(
		"a unit in open ground with no AP needs AP — it is not out of range"
	).is_equal(CommandFSM.Reason.INSUFFICIENT_AP)


func test_a_unit_both_boxed_in_and_broke_reports_out_of_range_not_ap() -> void:
	# ★ When both are true, OUT_OF_RANGE is the more useful thing to say: no amount
	# of AP would help this unit, so pointing the player at their AP pool would send
	# them to end their turn and find the unit still stuck. The two reasons are
	# mutually exclusive here on purpose — each one names the fix that would
	# actually work.
	var state := _make_state(0)
	var type := _make_unit_type(1, 8)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 0
	_place_unit(state, 2, 1, Vector2i(5, 4), type)
	_place_unit(state, 3, 1, Vector2i(5, 6), type)
	_place_unit(state, 4, 1, Vector2i(4, 5), type)
	_place_unit(state, 5, 1, Vector2i(6, 5), type)

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)
	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)

	assert_bool(move_entry.enabled).is_false()
	assert_int(move_entry.reason).override_failure_message(
		"no amount of AP frees a boxed-in unit — saying 'needs AP' sends the player nowhere"
	).is_equal(CommandFSM.Reason.OUT_OF_RANGE)


func test_menu_model_unit_fully_boxed_in_move_disabled_out_of_range() -> void:
	# Every orthogonal neighbor occupied by an enemy unit -> reachable() is
	# empty even with ample AP (AC-9's "no open tiles" case).
	var state := _make_state(0)
	var type := _make_unit_type(1, 8)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10
	var blocker_type := _make_unit_type(1, 8)
	_place_unit(state, 2, 1, Vector2i(5, 4), blocker_type)
	_place_unit(state, 3, 1, Vector2i(6, 5), blocker_type)
	_place_unit(state, 4, 1, Vector2i(5, 6), blocker_type)
	_place_unit(state, 5, 1, Vector2i(4, 5), blocker_type)

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)
	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)

	assert_bool(move_entry.enabled).is_false()
	assert_int(move_entry.reason).is_equal(CommandFSM.Reason.OUT_OF_RANGE)


# ==============================================================================
# AC-8: Attack — both-reasons-surfaced when both legality AND affordability fail
# ==============================================================================

func test_menu_model_attack_out_of_range_and_unaffordable_surfaces_both_reasons() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 1) # attack_range = 1
	var attacker := _place_unit(state, 1, 0, Vector2i(0, 0), attacker_type)
	state.per_player[0].current_ap = 0 # unaffordable regardless of range.
	# No enemy anywhere in range -> legal_targets() is empty (out of range).
	var target_type := _make_unit_type(1, 8, 1)
	_place_unit(state, 2, 1, Vector2i(9, 9), target_type)

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_bool((attack_entry.reason & CommandFSM.Reason.NO_TARGETS) != 0).is_true()
	assert_bool((attack_entry.reason & CommandFSM.Reason.INSUFFICIENT_AP) != 0).is_true()


func test_menu_model_attack_only_out_of_range_surfaces_only_that_reason() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 1)
	var attacker := _place_unit(state, 1, 0, Vector2i(0, 0), attacker_type)
	state.per_player[0].current_ap = 10 # affordable.
	var target_type := _make_unit_type(1, 8, 1)
	_place_unit(state, 2, 1, Vector2i(9, 9), target_type) # far out of range.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.NO_TARGETS)


func test_menu_model_attack_only_unaffordable_surfaces_only_that_reason() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3) # attack_range = 3, in reach.
	var attacker := _place_unit(state, 1, 0, Vector2i(0, 0), attacker_type)
	state.per_player[0].current_ap = 0 # unaffordable.
	var target_type := _make_unit_type(1, 8, 1)
	_place_unit(state, 2, 1, Vector2i(0, 2), target_type) # in range.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.INSUFFICIENT_AP)


func test_menu_model_attack_legal_and_affordable_enabled_no_reason() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3)
	var attacker := _place_unit(state, 1, 0, Vector2i(0, 0), attacker_type)
	state.per_player[0].current_ap = 10
	var target_type := _make_unit_type(1, 8, 1)
	_place_unit(state, 2, 1, Vector2i(0, 2), target_type)

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_true()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.NONE)


# AC-7 (already-attacked short-circuits — cross-referenced by AC-8's "only one
# conjunct" family; kept explicit since D-2/Edge Cases single it out).
func test_menu_model_attack_already_attacked_disabled_regardless_of_ap_or_range() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3)
	var attacker := _place_unit(state, 1, 0, Vector2i(0, 0), attacker_type)
	attacker.has_attacked = true
	state.per_player[0].current_ap = 10 # ample AP.
	var target_type := _make_unit_type(1, 8, 1)
	_place_unit(state, 2, 1, Vector2i(0, 2), target_type) # in range.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.ALREADY_ATTACKED)


# ==============================================================================
# AC-9: empty reachable()/legal_targets() -> disabled with specific reason,
# not hidden (menu_model always returns a full 5-row set) or erroring.
# ==============================================================================

func test_menu_model_always_returns_a_row_for_every_verb_never_hides_one() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(0, 0), type)
	state.per_player[0].current_ap = 0 # nothing affordable, nothing in range.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)

	# ★ Derived from the enum, not a hardcoded count. This test asserted "5" and
	# broke on the day Disband was added (2026-08-25) — correctly, but for the
	# wrong reason: what MATTERS is that the model reports on every verb it knows
	# about, whatever that set currently is. Counting off the enum keeps that
	# property true as verbs come and go, and still fails loudly if menu_model ever
	# starts omitting one.
	#
	# The MODEL never hides a verb. The WIDGET drops the ones disabled because they
	# do not apply to this kind of entity (ActionMenu._is_inapplicable) — that is a
	# rendering choice made downstream of this, on a complete model.
	assert_int(menu.size()).is_equal(CommandFSM.Verb.size())
	var verbs: Array[int] = []
	for entry: CommandFSM.VerbEntry in menu:
		verbs.append(entry.verb)
	for verb: int in CommandFSM.Verb.values():
		assert_array(verbs).override_failure_message(
			"menu_model returned no row for verb %d" % verb
		).contains([verb])


func test_menu_model_empty_legal_targets_attack_disabled_no_targets_not_erroring() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(0, 0), type)
	state.per_player[0].current_ap = 10
	# No enemy anywhere on the board.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.NO_TARGETS)


func test_menu_model_structure_produce_no_deploy_space_disabled_not_erroring() -> void:
	var state := _make_state(0)
	var unit_type := _make_unit_type()
	var producer_type := _make_structure_type(6, 1, [unit_type])
	var producer := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type)
	state.per_player[0].current_ap = 10
	# Occupy the producer's ENTIRE deploy radius so legal_deploy_tiles() is empty.
	# ★ S6-16: this filled only the four cardinal neighbours, which stopped being
	# sufficient when the deploy radius moved 1 -> 2 to fix the one-unit cliff
	# (s5-04-one-unit-cliff-diagnosis). Derived from the config so it keeps
	# testing "no deploy space" rather than "four specific tiles".
	var blocker_type := _make_unit_type()
	var radius: int = StructureBalance.base_production.deploy_radius
	var next_id: int = 2
	for dy: int in range(-radius, radius + 1):
		var span: int = radius - absi(dy)
		for dx: int in range(-span, span + 1):
			if dx == 0 and dy == 0:
				continue
			_place_unit(state, next_id, 0, Vector2i(5 + dx, 5 + dy), blocker_type)
			next_id += 1
	assert_array(BaseProduction.legal_deploy_tiles(state, producer, unit_type)) \
		.override_failure_message("the arrangement must actually leave no deploy space") \
		.is_empty()

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, producer)
	var produce_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.PRODUCE)

	assert_bool(produce_entry.enabled).is_false()
	assert_bool((produce_entry.reason & CommandFSM.Reason.NO_DEPLOY_SPACE) != 0).is_true()


# ==============================================================================
# AC-10: fully-spent entity / production_cap exhausted / no legal deploy tile
# -> still selects (menu_model returns rows), AP verbs disabled-with-reason,
# Wait clickable.
# ==============================================================================

func test_menu_model_fully_spent_unit_all_ap_verbs_disabled_wait_enabled() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(1, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(0, 0), type)
	unit.has_attacked = true
	state.per_player[0].current_ap = 0 # no AP for Move either.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, unit)

	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)
	var wait_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.WAIT)

	assert_bool(move_entry.enabled).is_false()
	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.ALREADY_ATTACKED)
	assert_bool(wait_entry.enabled).is_true()
	assert_int(wait_entry.reason).is_equal(CommandFSM.Reason.NONE)


func test_menu_model_producer_at_production_cap_disabled_cap_reached_and_offers_no_wait() -> void:
	var state := _make_state(0)
	var unit_type := _make_unit_type()
	var producer_type := _make_structure_type(6, 1, [unit_type]) # cap = 1
	var producer := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type)
	producer.units_produced_this_turn = 1 # already at the cap.
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, producer)
	var produce_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.PRODUCE)
	var wait_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.WAIT)

	assert_bool(produce_entry.enabled).is_false()
	assert_bool((produce_entry.reason & CommandFSM.Reason.PRODUCTION_CAP_REACHED) != 0).is_true()
	# ⚠ REWRITTEN S8-32 (user decision): Wait is a UNIT verb now. The entry is still
	# REPORTED — menu_model's contract is one entry per verb — but flagged NOT_A_UNIT,
	# the "does not apply to this KIND of thing" reason ActionMenu already hides. This
	# narrows CR-4's AC-10 ("always enabled, never gated"), so the assertion is inverted
	# rather than deleted: a structure silently regaining a live Wait row must fail here.
	assert_bool(wait_entry.enabled).is_false()
	assert_int(wait_entry.reason).is_equal(CommandFSM.Reason.NOT_A_UNIT)


func test_menu_model_under_construction_structure_still_selects_ap_verbs_disabled() -> void:
	# Under-construction structure: Produce disabled NOT_COMPLETED, Attack
	# disabled NOT_COMPLETED, Move disabled (not a UnitState), Wait still
	# clickable — "it still selects" (AC-10), Cancel Build is Story 004's
	# scope and is never emitted by this story's menu_model.
	var state := _make_state(0)
	var unit_type := _make_unit_type()
	var producer_type := _make_structure_type(6, 1, [unit_type])
	var producer := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type, \
		StructureState.BuildStatus.UNDER_CONSTRUCTION)
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, producer)

	# Enum-derived, for the same reason as the row-count test above: the point is
	# that the model reports on every verb, not that there happen to be N of them.
	assert_int(menu.size()).is_equal(CommandFSM.Verb.size())
	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)
	var produce_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.PRODUCE)
	var wait_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.WAIT)
	var cancel_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.CANCEL_BUILD)

	assert_bool(move_entry.enabled).is_false()
	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.NOT_COMPLETED)
	assert_bool(produce_entry.enabled).is_false()
	assert_int(produce_entry.reason).is_equal(CommandFSM.Reason.NOT_COMPLETED)
	# ⚠ S8-32: Wait is unit-only now, so a structure reports it NOT_A_UNIT and the menu
	# hides the row. ★ "It still selects" (AC-10) is unaffected — selecting an
	# under-construction structure is what surfaces its Cancel Build, asserted next.
	assert_bool(wait_entry.enabled).is_false()
	assert_int(wait_entry.reason).is_equal(CommandFSM.Reason.NOT_A_UNIT)
	# Story 004: an under-construction owned structure DOES offer Cancel Build.
	assert_bool(cancel_entry.enabled).is_true()
	# ...and never Disband, whatever its state: structures are not disbanded (UR-7).
	# The two destructive verbs are mutually exclusive by entity KIND, which is what
	# keeps a menu from ever offering two ways to destroy the same thing.
	var disband_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.DISBAND)
	assert_bool(disband_entry.enabled).is_false()
	assert_int(disband_entry.reason).is_equal(CommandFSM.Reason.NOT_A_UNIT)


func test_menu_model_non_producer_structure_produce_disabled_not_a_producer() -> void:
	var state := _make_state(0)
	var defensive_type := _make_structure_type(6, 0, []) # production_cap = 0, no producible_types.
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), defensive_type)
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, structure)
	var produce_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.PRODUCE)

	assert_bool(produce_entry.enabled).is_false()
	assert_int(produce_entry.reason).is_equal(CommandFSM.Reason.NOT_A_PRODUCER)


# ==============================================================================
# AC-2 / AC-3 note (Node-owned selection semantics — documented, not directly
# testable at this pure-core layer):
#
# AC-2 ("never enters ENTITY_SELECTED" for an enemy/neutral entity) and AC-3
# (selection clear/switch on empty-terrain/ESC/a-different-owned-entity) are
# both about WHICH trigger the future CommandInterface Node decides to feed
# next_state for a given click — e.g. the Node must never feed SELECT_OWN for
# an entity it doesn't own. That trigger-selection policy lives in the Node
# (a later story), not in this pure (State, Trigger, GameState) -> State
# function, which cannot see "was the clicked entity enemy-owned" without an
# entity parameter (the same scoping argument approved for the COMMIT
# destination refinements). What IS this story's responsibility, and IS
# covered above by the totality table, is that SELECT_OWN/SELECT_ENEMY_OR_EMPTY/
# BACK_OUT/WAIT resolve to the correct base state once the Node has already
# classified the trigger correctly (IDLE+SELECT_OWN -> ENTITY_SELECTED;
# ENTITY_SELECTED+SELECT_ENEMY_OR_EMPTY -> IDLE; ENTITY_SELECTED+SELECT_OWN ->
# ENTITY_SELECTED "switch"; ENTITY_SELECTED+BACK_OUT -> IDLE).
# ==============================================================================


# ==============================================================================
# Structure-attacker cost path: _attack_entry prices a StructureState attacker
# via Combat.attack_cost_for's StructureState branch (BaseProduction.
# defensive_attack_cost()), distinct from the UnitState branch exercised above.
# ==============================================================================

func test_menu_model_completed_structure_attacker_prices_via_defensive_cost_branch() -> void:
	# A COMPLETED, not-yet-attacked structure with attack capability drives
	# _attack_entry all the way to Combat.attack_cost_for(structure), which
	# takes the StructureState branch -> BaseProduction.defensive_attack_cost().
	# With 0 AP the (positive) defensive cost is unaffordable, so INSUFFICIENT_AP
	# is surfaced — proving the structure cost branch was invoked and returned a
	# spendable price (0 AP can never be "insufficient" against a 0 cost).
	var state := _make_state(0)
	var producer_type := _make_structure_type() # attack=2, attack_range=1 (attack-capable).
	var attacker := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type)
	attacker.has_attacked = false
	state.per_player[0].current_ap = 0

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_false()
	assert_bool((attack_entry.reason & CommandFSM.Reason.INSUFFICIENT_AP) != 0).is_true()


func test_menu_model_completed_structure_attacker_with_target_and_ap_attack_enabled() -> void:
	# The positive path: a COMPLETED attack-capable structure with an adjacent
	# enemy (a legal target) and ample AP yields Attack enabled — the affordability
	# conjunct is satisfied against the StructureState-branch defensive cost.
	var state := _make_state(0)
	var producer_type := _make_structure_type()
	var attacker := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type)
	attacker.has_attacked = false
	var enemy_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 4), enemy_type) # adjacent enemy (owner 1).
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.ATTACK)

	assert_bool(attack_entry.enabled).is_true()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.NONE)


# ==============================================================================
# Produce happy path: an under-cap producer with open deploy space and AP to
# spare yields Produce enabled with Reason.NONE (the positive counterpart to the
# cap-reached / no-deploy-space / not-a-producer disabled cases above).
# ==============================================================================

func test_menu_model_producer_under_cap_with_deploy_space_and_ap_produce_enabled() -> void:
	var state := _make_state(0)
	var unit_type := _make_unit_type()
	var producer_type := _make_structure_type(6, 2, [unit_type]) # cap = 2.
	var producer := _place_structure(state, 1, 0, Vector2i(5, 5), producer_type)
	producer.units_produced_this_turn = 0 # under cap.
	# Dual-cost (ADR-0006 pivot): produce needs Credits (produce_cost 4) AND the AP
	# surcharge (produce_ap_cost 1) — fund both so the verb is enabled.
	state.per_player[0].current_ap = 10
	state.per_player[0].current_credits = 10
	# (5,5) sits on an open blank grid, so all 4 cardinal deploy tiles are free.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, producer)
	var produce_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.PRODUCE)

	assert_bool(produce_entry.enabled).is_true()
	assert_int(produce_entry.reason).is_equal(CommandFSM.Reason.NONE)


# ==============================================================================
# AC-1 (structure non-mover): a structure has no reachable() concept, so its
# Move entry is disabled with the specific OUT_OF_RANGE reason (not merely
# enabled=false with an unspecified reason).
# ==============================================================================

func test_menu_model_structure_move_disabled_out_of_range_reason() -> void:
	var state := _make_state(0)
	var structure_type := _make_structure_type()
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), structure_type)
	state.per_player[0].current_ap = 10

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, structure)
	var move_entry: CommandFSM.VerbEntry = _find_entry(menu, CommandFSM.Verb.MOVE)

	assert_bool(move_entry.enabled).is_false()
	assert_int(move_entry.reason).is_equal(CommandFSM.Reason.OUT_OF_RANGE)


# ==============================================================================
# AC (Pass-Through lint): zero owning-system balance-constant references.
# ==============================================================================

func test_command_fsm_source_never_references_balance_constants_by_name() -> void:
	# Structural property (ADR-0015 §4/TR-cmdui-010, this story's own AC) —
	# code-level check until CI lint tooling owns this per ADR-0015's
	# "candidate lint" note, mirroring ai_enumeration_order_test.gd's
	# established precedent for asserting on source form rather than runtime
	# behavior.
	#
	# This checks for the DANGEROUS ACCESS PATTERNS a violation would take
	# (a *Config/*Balance autoload dotted-access, or a bare tuning-constant
	# field read), not a blind substring match on every literal listed in the
	# story text — a blind substring match on "attack_cost" would false-
	# positive on the legitimate PUBLIC QUERY this story's implementation
	# introduces (Combat.attack_cost_for, coordinator-approved cai-001 seam)
	# and on BaseProduction's existing defensive_attack_cost()/
	# Unit.effective_produce_cost() query names, which are the CORRECT
	# Pass-Through-compliant way to reach these values (they call through to
	# the owning system's query, never hold the constant locally). The
	# violating pattern is a *Config/*Balance reference or a bare field/const
	# access — never a "*_for("/"effective_*("/"defensive_*(" query call.
	var source := FileAccess.get_file_as_string("res://src/ui/command_action_interface/command_fsm.gd")

	# 1. No *Config or *Balance autoload/class reference anywhere (the two
	#    concrete ways a balance constant enters this file: CombatConfig/
	#    CombatBalance, EconomyConfig/Balance, UnitConfig, BaseProductionConfig/
	#    StructureBalance, AIConfig/AIBalance).
	var forbidden_types: Array[String] = [
		"CombatConfig", "CombatBalance",
		"EconomyConfig",
		"UnitConfig",
		"BaseProductionConfig", "StructureBalance",
		"AIConfig", "AIBalance",
	]
	for forbidden: String in forbidden_types:
		assert_bool(source.contains(forbidden)).override_failure_message( \
			"command_fsm.gd references forbidden balance-holding type '%s'" % forbidden).is_false()

	# Scrub sanctioned Pass-Through-COMPLIANT query-call identifiers before the
	# bare-field check below. A query like `Combat.attack_cost_for(` literally
	# contains the substring `.attack_cost`, so a naive substring test would
	# false-positive on the CORRECT way to reach the value (a method call that
	# routes through the owning system's query, never a locally-held constant).
	# Replacing the whole query identifier with a neutral placeholder leaves any
	# genuine bare-field access (e.g. `CombatBalance.combat.attack_cost`) intact.
	var scrubbed := source
	for query_name: String in [
		"attack_cost_for", "defensive_attack_cost", "effective_produce_cost",
		"effective_move_cost", "effective_build_cost",
	]:
		scrubbed = scrubbed.replace(query_name, "SANCTIONED_QUERY")

	# 2. No bare tuning-constant field/const access pattern (a dotted access
	#    ending in the constant name, or a `const NAME` declaration) for any
	#    of the story's named example constants. Run against the scrubbed source
	#    so the sanctioned queries above cannot trip it.
	var forbidden_field_patterns: Array[String] = [
		".move_cost", "SOFT_MOVE_PENALTY", ".attack_cost", ".cover_dr", "COVER_DR",
		"CANCEL_REFUND_RATE", ".build_cost", ".produce_cost", ".cancel_refund_pct",
		".min_damage", ".base_income", ".outpost_bonus",
	]
	for pattern: String in forbidden_field_patterns:
		assert_bool(scrubbed.contains(pattern)).override_failure_message( \
			"command_fsm.gd contains forbidden balance-constant access pattern '%s'" % pattern).is_false()


func test_command_fsm_uses_only_public_query_calls_for_attack_cost() -> void:
	# Companion positive check: the file DOES call the sanctioned public query
	# (Combat.attack_cost_for) rather than omitting cost-checking entirely.
	var source := FileAccess.get_file_as_string("res://src/ui/command_action_interface/command_fsm.gd")
	assert_str(source).contains("Combat.attack_cost_for(")


# --- Shared helper ------------------------------------------------------------

func _find_entry(menu: Array[CommandFSM.VerbEntry], verb: int) -> CommandFSM.VerbEntry:
	for entry: CommandFSM.VerbEntry in menu:
		if entry.verb == verb:
			return entry
	fail("menu_model did not return a VerbEntry for verb %d" % verb)
	return null
