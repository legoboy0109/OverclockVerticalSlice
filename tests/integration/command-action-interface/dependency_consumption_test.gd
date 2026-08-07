# Story 003: Dependency Consumption Contracts — Movement, Combat, Base &
# Production, AP, Turn Manager.
#
# Covers production/epics/command-action-interface/story-003-dependency-consumption-contracts.md
# (TR-cmdui-011/012/013/014/015, ADR-0015 §1/§5):
#
#   AC-4 (preview == commit, byte-for-byte, one test per action family):
#     move -> current_ap delta == the previewed reachable().min_cost;
#     attack -> target.current_hp delta == Combat.preview_damage's return;
#     build -> current_ap delta == CommandFSM.build_preview's build_cost.
#   AC-5: projected_remaining_ap is evaluated independently per preview —
#     ap=9, a move costing 6 shows 3; a SEPARATE attack preview costing 2
#     independently shows 7, never 9-6-2=1.
#   AC-6: current_ap=1, attack_cost=2 -> Attack disabled, INSUFFICIENT_AP,
#     evaluated against the REAL live AP.can_afford/current_ap.
#   AC-7: has_attacked=true -> Attack disabled ALREADY_ATTACKED regardless of
#     current_ap, evaluated against real Unit.can_attack.
#   AC-16 (Logic portion): CommandFSM.build_preview exposes build_cost/
#     build_time (both from BaseProduction's live queries), affordability
#     (AP.can_afford), legal_tiles (BaseProduction.legal_build_tiles), and the
#     two distinguishable exclusion reasons (insufficient_ap / no_legal_tile)
#     as independent booleans.
#   AC-26: a Defensive Structure attacker's previewed AND committed cost is
#     the QUERIED Combat.attack_cost_for(structure) ==
#     BaseProduction.defensive_attack_cost() (1) — asserted against the query
#     return, never a hardcoded literal, and proven != CombatBalance's
#     unit attack_cost (2).
#   AC-21: during the opponent's turn (state.active_player != local_player) a
#     selection/commit attempt makes NO ENTITY_SELECTED transition and NO
#     apply_action call — proven via CommandInterface.try_select returning
#     false with fsm_state/selected_id unchanged, CommandInterface.commit
#     returning a synthesized reject with the real GameState byte-identical
#     before/after, and a control test proving the SAME inputs succeed when
#     it genuinely is the local player's live turn.
#
# Integration story: uses the REAL Movement/Combat/AP/BaseProduction query
# surfaces and the REAL GameState.apply_action commit pipeline — no query
# stubs (mirrors combat_apply_action_integration_test.gd's precedent). Real
# GameStateFactory fixtures, both players pinned to Factions.NEUTRAL (mirrors
# command_fsm_test.gd / recompute_tiers_test.gd's fixture convention) so every
# effective_* fold is a no-op. auto_free() every CommandInterface Node fixture
# (recompute_tiers_test.gd's precedent — Node fixtures leak orphans otherwise).
#
# Deterministic: no RNG, no time-dependent assertions, no external I/O.
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Fixture helpers (mirrors command_fsm_test.gd / recompute_tiers_test.gd) -

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
	# Pin both players to Neutral so any effective_* balance fold is a no-op
	# (== base) — mirrors command_fsm_test.gd's fixture convention.
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


func _move_action(player: int, from: Vector2i, to: Vector2i, tiles_entered: int) -> MoveAction:
	var action := MoveAction.new()
	action.player = player
	action.from = from
	action.to = to
	action.tiles_entered = tiles_entered
	return action


func _attack_action(player: int, attacker_tile: Vector2i, target_tile: Vector2i) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


# ==============================================================================
# AC-4: preview == commit, byte-for-byte, one test per action family.
# ==============================================================================

func test_ac4_move_commit_ap_delta_equals_previewed_min_cost() -> void:
	var state := _make_state(0)
	var type := _make_unit_type(2, 8, 1) # move_cost 2, distance-1 tile costs 2.
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), type)
	state.per_player[0].current_ap = 10

	# Preview: read the exact min_cost the same way CommandInterface's Tier-1
	# holds it (Movement.reachable is the sole source of truth).
	var reachable: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	var destination := Vector2i(6, 5)
	var previewed: Movement.ReachableTile = null
	for r: Movement.ReachableTile in reachable:
		if r.tile == destination:
			previewed = r
			break
	assert_object(previewed).is_not_null()
	assert_int(previewed.min_cost).is_equal(2)

	var ap_before: int = AP.current_ap(state, 0)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var result: ActionResult = iface.commit(state, _move_action(0, unit.position, destination, 1))

	assert_bool(result.ok).is_true()
	var ap_after: int = AP.current_ap(state, 0)
	# Byte-for-byte: the committed AP delta equals the PREVIEWED min_cost, not
	# a re-derived/hardcoded value.
	assert_int(ap_before - ap_after).is_equal(previewed.min_cost)


func test_ac4_attack_commit_hp_delta_equals_previewed_damage() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3, 10, 4)
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5), attacker_type)
	var defender_type := _make_unit_type(1, 8, 1, 12, 2)
	var defender := _place_unit(state, 2, 1, Vector2i(5, 6), defender_type)
	state.per_player[0].current_ap = 10

	# Preview: Combat.preview_damage is the exact same value the story
	# requires equal the committed delta.
	var previewed_damage: int = Combat.preview_damage(state, attacker, defender)
	assert_int(previewed_damage).is_greater(0)
	var hp_before: int = defender.current_hp

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var result: ActionResult = iface.commit(state, _attack_action(0, attacker.position, defender.position))

	assert_bool(result.ok).is_true()
	var hp_after: int = (state.entities_by_id[2] as UnitState).current_hp
	assert_int(hp_before - hp_after).is_equal(previewed_damage)


func test_ac4_build_commit_splits_ap_surcharge_and_credit_main_cost() -> void:
	var state := _make_state(0)
	var hq_type := _make_structure_type_for_build()
	_place_structure(state, 1, 0, Vector2i(5, 5), hq_type)
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 20  # fund Credits (build main cost, ADR-0006 pivot)

	var buildable := _make_structure_type_for_build(6)
	var preview: CommandFSM.BuildEntry = CommandFSM.build_preview(state, 0, buildable)
	assert_bool(preview.affordable).is_true()
	assert_bool(preview.legal_tiles.is_empty()).is_false()
	var target_tile: Vector2i = preview.legal_tiles[0]

	var ap_before: int = AP.current_ap(state, 0)
	var credits_before: int = Credits.current_credits(state, 0)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var action := BuildAction.new()
	action.structure_type = buildable
	action.tile = target_tile
	var result: ActionResult = iface.commit(state, action)

	assert_bool(result.ok).is_true()
	# Dual-cost: the AP delta is the build_ap_cost surcharge; the Credit main cost
	# (preview.build_cost) comes out of the Credits pool.
	assert_int(ap_before - AP.current_ap(state, 0)).is_equal(Balance.economy.build_ap_cost)
	assert_int(credits_before - Credits.current_credits(state, 0)).is_equal(preview.build_cost)


func _make_structure_type_for_build(build_cost: int = 6) -> StructureTypeDef:
	var type := StructureTypeDef.new()
	type.display_name = "TestBuildable"
	type.hp = 20
	type.build_cost = build_cost
	type.build_time = 2
	type.production_cap = 0
	return type


# ==============================================================================
# AC-5: projected_remaining_ap independent per preview, never summed.
# ==============================================================================

func test_ac5_projected_remaining_ap_independent_per_preview_never_summed() -> void:
	var state := _make_state(0)
	state.per_player[0].current_ap = 9

	var move_projection: int = CommandFSM.projected_remaining_ap(state, 0, 6)
	var attack_projection: int = CommandFSM.projected_remaining_ap(state, 0, 2)

	assert_int(move_projection).is_equal(3)
	# Independently computed against the SAME live current_ap=9 pool — never
	# 9 - 6 - 2 == 1.
	assert_int(attack_projection).is_equal(7)
	assert_int(attack_projection).is_not_equal(1)


# ==============================================================================
# AC-6: insufficient AP -> Attack disabled with reason, against LIVE state.
# ==============================================================================

func test_ac6_insufficient_ap_attack_disabled_with_reason_against_live_ap() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3)
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5), attacker_type)
	var defender_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 6), defender_type)

	# Real attack_cost_for(attacker) == CombatBalance.combat.attack_cost == 2.
	var real_cost: int = Combat.attack_cost_for(attacker)
	assert_int(real_cost).is_equal(2)
	state.per_player[0].current_ap = real_cost - 1 # exactly one short.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = menu[CommandFSM.Verb.ATTACK]

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason & CommandFSM.Reason.INSUFFICIENT_AP).is_equal(CommandFSM.Reason.INSUFFICIENT_AP)


# ==============================================================================
# AC-7: has_attacked=true -> Attack disabled ALREADY_ATTACKED regardless of AP.
# ==============================================================================

func test_ac7_already_attacked_disabled_regardless_of_ap_live_state() -> void:
	var state := _make_state(0)
	var attacker_type := _make_unit_type(1, 8, 3)
	var attacker := _place_unit(state, 1, 0, Vector2i(5, 5), attacker_type)
	var defender_type := _make_unit_type()
	_place_unit(state, 2, 1, Vector2i(5, 6), defender_type)
	# Plenty of AP — proves the disable is NOT an affordability issue.
	state.per_player[0].current_ap = 999
	attacker.has_attacked = true
	assert_bool(Unit.can_attack(attacker)).is_false() # real live-state read.

	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, attacker)
	var attack_entry: CommandFSM.VerbEntry = menu[CommandFSM.Verb.ATTACK]

	assert_bool(attack_entry.enabled).is_false()
	assert_int(attack_entry.reason).is_equal(CommandFSM.Reason.ALREADY_ATTACKED)


# ==============================================================================
# AC-16 (Logic portion): Build preview — cost/time from queries, affordability,
# legal_tiles, two distinguishable exclusion reasons.
# ==============================================================================

func test_ac16_build_preview_cost_time_affordability_and_legal_tiles() -> void:
	var state := _make_state(0)
	var hq_type := _make_structure_type_for_build()
	_place_structure(state, 1, 0, Vector2i(5, 5), hq_type)
	state.per_player[0].current_ap = 20

	var buildable := _make_structure_type_for_build(6)
	buildable.build_time = 3

	var preview: CommandFSM.BuildEntry = CommandFSM.build_preview(state, 0, buildable)

	# build_cost/build_time come from BaseProduction's live queries, not the
	# raw template fields, though under Neutral they agree numerically —
	# assert against the QUERY return, per the Pass-Through discipline.
	assert_int(preview.build_cost).is_equal(BaseProduction.effective_build_cost(state, buildable, 0))
	assert_int(preview.build_time).is_equal(BaseProduction.effective_build_time(state, buildable, 0))
	assert_bool(preview.affordable).is_true()
	assert_array(preview.legal_tiles).is_equal(BaseProduction.legal_build_tiles(state, 0, buildable))
	assert_bool(preview.insufficient_ap).is_false()
	assert_bool(preview.no_legal_tile).is_false()


func test_ac16_build_preview_two_exclusion_reasons_distinguishable() -> void:
	var state := _make_state(0)
	var hq_type := _make_structure_type_for_build()
	_place_structure(state, 1, 0, Vector2i(5, 5), hq_type)

	# Case 1: insufficient AP only — legal_tiles is non-empty (HQ has open
	# neighbours), but current_ap is 0.
	var buildable := _make_structure_type_for_build(6)
	state.per_player[0].current_ap = 0
	var unaffordable_preview: CommandFSM.BuildEntry = CommandFSM.build_preview(state, 0, buildable)
	assert_bool(unaffordable_preview.insufficient_ap).is_true()
	assert_bool(unaffordable_preview.no_legal_tile).is_false()

	# Case 2: no legal tile only — wall off every cardinal neighbour of the
	# HQ with IMPASSABLE terrain (never a candidate, and never itself a
	# friendly entity whose OWN neighbours would reopen new candidates — the
	# failure mode a friendly-unit "ring" fixture has: legal_build_tiles scans
	# every friendly entity's neighbours, so filler units would just push the
	# open frontier outward instead of closing it). AP is plentiful.
	state.per_player[0].current_ap = 999
	for n: Vector2i in [Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6), Vector2i(4, 5)]:
		state.grid.terrain[state.grid.index(n.x, n.y)] = GridState.Terrain.IMPASSABLE
	var no_tile_preview: CommandFSM.BuildEntry = CommandFSM.build_preview(state, 0, buildable)
	assert_bool(no_tile_preview.no_legal_tile).is_true()
	assert_bool(no_tile_preview.insufficient_ap).is_false()


# ==============================================================================
# AC-26: Defensive Structure attack cost is the QUERIED value, not hardcoded.
# ==============================================================================

func test_ac26_defensive_structure_attack_cost_is_queried_value_not_hardcoded_two() -> void:
	var state := _make_state(0)
	var defensive_type := _make_structure_type_for_build()
	defensive_type.attack = 5
	defensive_type.attack_range = 2
	defensive_type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	defensive_type.min_range = 1
	var structure := _place_structure(state, 1, 0, Vector2i(5, 5), defensive_type)

	var target_type := _make_unit_type(1, 8, 1, 20, 1)
	var target := _place_unit(state, 2, 1, Vector2i(5, 6), target_type)

	# The queried cost — the only value this test is allowed to assert
	# against for "what should be spent."
	var queried_cost: int = Combat.attack_cost_for(structure)
	assert_int(queried_cost).is_equal(BaseProduction.defensive_attack_cost())
	assert_int(queried_cost).is_equal(1)
	# Proves the worked example: NOT the unit attack_cost (2).
	assert_int(queried_cost).is_not_equal(CombatBalance.combat.attack_cost)

	# Preview: menu_model's Attack entry must be affordable at exactly the
	# queried cost, never the unit cost.
	state.per_player[0].current_ap = queried_cost
	var menu: Array[CommandFSM.VerbEntry] = CommandFSM.menu_model(state, structure)
	assert_bool(menu[CommandFSM.Verb.ATTACK].enabled).is_true()

	var ap_before: int = AP.current_ap(state, 0)
	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var result: ActionResult = iface.commit(state, _attack_action(0, structure.position, target.position))

	assert_bool(result.ok).is_true()
	var ap_after: int = AP.current_ap(state, 0)
	# Committed AND subtracted cost == the queried value, never a hardcoded 2.
	assert_int(ap_before - ap_after).is_equal(queried_cost)


# ==============================================================================
# AC-21: opponent's turn -> read-only inspection only, no transition, no
# apply_action.
# ==============================================================================

func test_ac21_opponent_turn_select_attempt_is_inspection_only_no_transition() -> void:
	# active_player is 1 (the opponent); THIS interface acts for player 0.
	var state := _make_state(1)
	var unit_type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), unit_type)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	assert_bool(iface.is_input_live(state)).is_false()

	var selected: bool = iface.try_select(state, unit)

	assert_bool(selected).is_false()
	# No ENTITY_SELECTED transition — FSM stays exactly where it started.
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.IDLE)
	assert_int(iface.selected_id()).is_equal(-1)


func test_ac21_opponent_turn_commit_attempt_makes_no_apply_action_state_unchanged() -> void:
	var state := _make_state(1) # opponent's turn.
	var unit_type := _make_unit_type(2, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), unit_type)
	state.per_player[0].current_ap = 10

	var ap_before: int = state.per_player[0].current_ap
	var occupancy_before: PackedInt32Array = state.grid.occupancy.duplicate()
	var entities_before: int = state.entities_by_id.size()

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	var result: ActionResult = iface.commit(state, _move_action(0, unit.position, Vector2i(6, 5), 1))

	# Synthesized reject — never routed through the real apply_action pipeline.
	assert_bool(result.ok).is_false()
	assert_int(result.reason).is_equal(Action.Reason.NOT_ACTIVE_PLAYER)
	assert_array(result.events).is_empty()

	# Real state byte-identical before/after — no apply_action side effect
	# leaked through (mirrors combat_apply_action_integration_test.gd's
	# unchanged-state assertion pattern for a rejected commit).
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_array(state.grid.occupancy).is_equal(occupancy_before)
	assert_int(state.entities_by_id.size()).is_equal(entities_before)
	assert_vector((state.entities_by_id[1] as UnitState).position).is_equal(Vector2i(5, 5))


func test_ac21_own_live_action_phase_input_is_live_control() -> void:
	# Control test: the SAME shape of input succeeds when it genuinely is the
	# local player's own live turn — proves AC-21's gate is turn-scoped, not a
	# blanket rejection.
	var state := _make_state(0) # local player 0's own turn.
	var unit_type := _make_unit_type(2, 8, 1)
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), unit_type)
	state.per_player[0].current_ap = 10

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)
	assert_bool(iface.is_input_live(state)).is_true()

	var selected: bool = iface.try_select(state, unit)
	assert_bool(selected).is_true()
	assert_int(iface.fsm_state()).is_equal(CommandFSM.State.ENTITY_SELECTED)
	assert_int(iface.selected_id()).is_equal(unit.entity_id)

	var result: ActionResult = iface.commit(state, _move_action(0, unit.position, Vector2i(6, 5), 1))
	assert_bool(result.ok).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(8)


func test_ac21_game_over_input_is_not_live_even_for_active_player() -> void:
	var state := _make_state(0)
	state.match_status = GameState.MatchStatus.GAME_OVER
	var unit_type := _make_unit_type()
	var unit := _place_unit(state, 1, 0, Vector2i(5, 5), unit_type)

	var iface: CommandInterface = auto_free(CommandInterface.new())
	iface.set_local_player(0)

	assert_bool(iface.is_input_live(state)).is_false()
	assert_bool(iface.try_select(state, unit)).is_false()
