# Story 005: Death, Shared `destroy_entity()` Hook, HQ Win-Check & Structure-
# Attacker Polymorphism.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-005-death-destroy-entity-structure-attacker.md:
#   AC-1 (same-step removal): 0-hp unit -> grid clears + entities_by_id drops it.
#   AC-2 (HQ destruction event): HQ fixture at 0 hp -> StructureDestroyedEvent{is_hq=true}.
#   AC-3 (non-HQ structure, no false GameOver): StructureDestroyedEvent{is_hq=false},
#         run_win_check leaves match_status IN_PROGRESS.
#   AC-4 (unit destruction event): UnitState at 0 hp -> UnitDestroyedEvent.
#   AC-5 (structure-as-attacker, same pipeline): Defensive Structure fixture
#         (attack 4, range 2, DIRECT) hits an enemy unit (defense 0) for
#         damage 4; AP charged == BaseProduction.defensive_attack_cost(), not
#         CombatBalance.combat.attack_cost. Edge case: friendly blocker on the
#         line -> validate() rejects (DIRECT LoF identical for a structure attacker).
#   AC-6 (HQ-at-exact-damage -> correct event shape via run_win_check): enemy
#         HQ at hp == damage -> Combat.apply()'s events, fed directly into
#         GameState.run_win_check(), set match_status GAME_OVER with the
#         correct winner.
#
# Fixtures mirror tests/unit/combat/attack_pipeline_ap_cost_test.gd's style
# (_make_grid/_make_state/_make_unit/_make_structure/_make_action/_place).
#
# NOT separately tested (deliberate, per this story's scope):
#   * destroy_entity()'s Lab-revert step (a) is a documented no-op today (no
#     Research epic exists) — its "does nothing observable / never crashes"
#     behavior is covered IMPLICITLY: every AC below calls destroy_entity()
#     via Combat.apply() and keeps asserting afterward, so any accidental
#     crash/side-effect there would fail those tests. No dedicated test for a
#     zero-implementation no-op.
#   * validate()'s defensive `else -> ILLEGAL_TARGET` arm (an entity that is
#     neither UnitState nor StructureState) has no in-scope fixture type to
#     exercise it; left uncovered by design until such a type exists.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. BaseProduction is now the real Base & Production Story 002
# class (base_production_stub.gd deleted) -- defensive_attack_cost() reads
# StructureBalance.base_production.defensive_attack_cost (config default 1,
# matching every value this suite previously stubbed), so no reset/setter is
# needed here anymore.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders --------------------------------------------------------

func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


# current_ap defaults to CombatBalance.combat.attack_cost so a legal
# unit-attacker fixture is affordable unless a test explicitly drives it lower.
func _make_state(current_ap: int = -1) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	var ap: int = current_ap if current_ap >= 0 else CombatBalance.combat.attack_cost
	state.per_player[0].current_ap = ap
	state.per_player[1].current_ap = ap
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


# A minimal frail UnitTypeDef (hp 1, defense 0) -- guarantees a lethal hit from
# any nonzero-attack unit attacker, isolating the death-check assertions from
# any particular attacker's exact damage number.
func _make_frail_type() -> UnitTypeDef:
	var frail_type := UnitTypeDef.new()
	frail_type.display_name = "Frail"
	frail_type.hp = 1
	frail_type.attack = 0
	frail_type.attack_range = 1
	frail_type.move_cost = 1
	frail_type.soft_move_cap = 1
	frail_type.produce_cost = 1
	frail_type.defense = 0
	return frail_type


# Sets BOTH type.hp and current_hp explicitly to the same value, so the
# _apply_damage_to inline clamp ceiling never surprises a fixture (mirrors
# attack_pipeline_ap_cost_test.gd's documented trap). NOTE: is_hq=true claims
# the real StructureTypes.HQ template identity (ADR-0007: is_hq() == type ==
# StructureTypes.HQ, a Resource-ref check against the real, immutable HQ
# const -- never a mutable per-fixture flag) -- the [param hp] argument is
# IGNORED in that branch (the real HQ's own hp/defense are load-bearing;
# callers needing an exact-lethal HQ fixture must compute their lethal hp
# against the real HQ's stats via Combat.damage(), not pass a fixture number).
# A non-HQ fixture (is_hq=false, the default) keeps the fresh-per-fixture
# StructureTypeDef this suite's other ACs depend on.
func _make_structure(entity_id: int, owner: int, pos: Vector2i, hp: int = 10, is_hq: bool = false) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	if is_hq:
		structure.type = StructureTypes.HQ
		structure.current_hp = structure.type.hp
	else:
		structure.type = StructureTypeDef.new()
		structure.type.hp = hp
		structure.current_hp = hp
	return structure


# A Defensive Structure attacker fixture: attack 4, range 2, DIRECT -- per the
# story's AC-5 exact stat block.
func _make_defensive_structure(entity_id: int, owner: int, pos: Vector2i) -> StructureState:
	var structure := _make_structure(entity_id, owner, pos)
	structure.type.attack = 4
	structure.type.attack_range = 2
	structure.type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	structure.type.min_range = 1
	return structure


func _make_action(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# --- AC-1: same-step removal (unit defender) ---------------------------------

func test_unit_reduced_to_zero_hp_removed_same_step_grid_and_entities() -> void:
	# Arrange -- Heavy (atk 5) vs a 1-hp defense-0 unit defender: lethal.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail := _make_unit(2, 1, _make_frail_type(), Vector2i(1, 0))
	frail.current_hp = 1
	_place(state, heavy)
	_place(state, frail)
	var action := _make_action(heavy.position, frail.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- removed the same step: grid tile empty, entity gone.
	assert_int(state.grid.occupant_at(frail.position.x, frail.position.y)).is_equal(GridState.EMPTY_OCCUPANT)
	assert_bool(state.entities_by_id.has(frail.entity_id)).is_false()


# --- AC-2: HQ destruction event -----------------------------------------------

func test_hq_reduced_to_zero_hp_appends_structure_destroyed_event_is_hq_true() -> void:
	# Arrange -- Heavy (atk 5) vs the real HQ template (StructureTypes.HQ,
	# defense 2): current_hp set exactly to the real computed damage so the
	# hit is lethal exactly. is_hq=true claims real HQ identity (ADR-0007) --
	# hp/defense are the real template's, not a fixture-picked number.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var enemy_hq := _make_structure(2, 1, Vector2i(1, 0), 0, true)
	_place(state, heavy)
	_place(state, enemy_hq)
	var lethal_damage: int = Combat.damage(state, heavy, enemy_hq)
	enemy_hq.current_hp = lethal_damage
	var action := _make_action(heavy.position, enemy_hq.position, 0)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert
	var found: StructureDestroyedEvent = null
	for e: Event in events:
		if e is StructureDestroyedEvent:
			found = e
	assert_object(found).is_not_null()
	assert_bool(found.is_hq).is_true()
	assert_int(found.entity_id).is_equal(enemy_hq.entity_id)
	assert_bool(state.entities_by_id.has(enemy_hq.entity_id)).is_false()
	assert_int(state.grid.occupant_at(enemy_hq.position.x, enemy_hq.position.y)).is_equal(GridState.EMPTY_OCCUPANT)


# --- AC-3: non-HQ structure -- no false GameOver ------------------------------

func test_non_hq_structure_reduced_to_zero_hp_no_game_over() -> void:
	# Arrange -- Heavy vs an enemy non-HQ structure (defense 0, hp 5): lethal.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var enemy_structure := _make_structure(2, 1, Vector2i(1, 0), 5, false)
	_place(state, heavy)
	_place(state, enemy_structure)
	var action := _make_action(heavy.position, enemy_structure.position, 0)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- event present but is_hq false.
	var found: StructureDestroyedEvent = null
	for e: Event in events:
		if e is StructureDestroyedEvent:
			found = e
	assert_object(found).is_not_null()
	assert_bool(found.is_hq).is_false()
	# Feeding these events to run_win_check must NOT end the match.
	state.run_win_check(events)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)


# --- AC-4: unit destruction event ---------------------------------------------

func test_unit_reduced_to_zero_hp_appends_unit_destroyed_event() -> void:
	# Arrange -- same lethal setup as AC-1.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail := _make_unit(2, 1, _make_frail_type(), Vector2i(1, 0))
	frail.current_hp = 1
	_place(state, heavy)
	_place(state, frail)
	var action := _make_action(heavy.position, frail.position, 0)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert
	var found: UnitDestroyedEvent = null
	for e: Event in events:
		if e is UnitDestroyedEvent:
			found = e
	assert_object(found).is_not_null()
	assert_int(found.entity_id).is_equal(frail.entity_id)


# --- AC-5: structure-as-attacker, same pipeline -------------------------------

func test_defensive_structure_attacker_deals_damage_and_charges_defensive_cost() -> void:
	# Arrange -- Defensive Structure (atk 4, range 2, DIRECT) vs an enemy unit
	# (defense 0) 2 tiles away on a clear cardinal line. Damage = max(1, 4-0-0) = 4.
	var state := _make_state(1) # exactly enough AP for the structure's cost (1), NOT the unit cost (2)
	var attacker := _make_defensive_structure(1, 0, Vector2i(0, 0))
	var enemy_type := UnitTypeDef.new()
	enemy_type.display_name = "Target"
	enemy_type.hp = 20
	enemy_type.attack = 0
	enemy_type.attack_range = 1
	enemy_type.move_cost = 1
	enemy_type.soft_move_cap = 1
	enemy_type.produce_cost = 1
	enemy_type.defense = 0
	var enemy := _make_unit(2, 1, enemy_type, Vector2i(2, 0))
	_place(state, attacker)
	_place(state, enemy)
	var action := _make_action(attacker.position, enemy.position, 0)
	# Act / Assert -- legal (structure attacker no longer rejected by validate()).
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)
	Combat.apply(state, action)
	# Assert -- damage 4, and the AP charged is the structure's DEFENSIVE cost
	# (1), not CombatBalance.combat.attack_cost (2) -- if apply() spent the
	# unit-attacker cost instead, current_ap would go negative/be wrong here.
	assert_int(enemy.current_hp).is_equal(16) # 20 - 4
	assert_int(state.per_player[0].current_ap).is_equal(0) # 1 AP - 1 (defensive cost)
	assert_bool(attacker.has_attacked).is_true()


func test_defensive_structure_attacker_blocked_by_friendly_on_cardinal_line() -> void:
	# Arrange -- same Defensive Structure and enemy unit, but a friendly unit
	# sits on the cardinal line between them -- DIRECT LoF blocks identically
	# for a structure attacker.
	var state := _make_state(1)
	var attacker := _make_defensive_structure(1, 0, Vector2i(0, 0))
	var friendly_blocker := _make_unit(3, 0, UnitTypes.SCOUT, Vector2i(1, 0))
	var enemy_type := UnitTypeDef.new()
	enemy_type.display_name = "Target"
	enemy_type.hp = 20
	enemy_type.attack = 0
	enemy_type.attack_range = 1
	enemy_type.move_cost = 1
	enemy_type.soft_move_cap = 1
	enemy_type.produce_cost = 1
	enemy_type.defense = 0
	var enemy := _make_unit(2, 1, enemy_type, Vector2i(2, 0))
	_place(state, attacker)
	_place(state, friendly_blocker)
	_place(state, enemy)
	var action := _make_action(attacker.position, enemy.position, 0)
	# Act / Assert -- rejected, blocked line -- target not in legal_targets.
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_structure_attacker_already_attacked_this_turn_rejected() -> void:
	# Arrange -- Defensive Structure that has already fired this turn.
	var state := _make_state(1)
	var attacker := _make_defensive_structure(1, 0, Vector2i(0, 0))
	attacker.has_attacked = true
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(2, 0))
	_place(state, attacker)
	_place(state, enemy)
	var action := _make_action(attacker.position, enemy.position, 0)
	# Act / Assert
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)


# --- AC-6: HQ-at-exact-damage -> correct event shape via run_win_check -------

func test_hq_at_exact_damage_destroyed_event_drives_run_win_check_game_over() -> void:
	# Arrange -- Heavy (atk 5) vs the real HQ template (StructureTypes.HQ,
	# defense 2) at hp exactly == the real computed damage. is_hq=true claims
	# real HQ identity (ADR-0007); the real template's hp (40) comfortably
	# exceeds current_hp so the inline clamp ceiling never interferes.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var enemy_hq := _make_structure(2, 1, Vector2i(1, 0), 0, true)
	_place(state, heavy)
	_place(state, enemy_hq)
	var expected_damage: int = Combat.damage(state, heavy, enemy_hq)
	enemy_hq.current_hp = expected_damage
	var action := _make_action(heavy.position, enemy_hq.position, 0)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- Combat.apply()'s returned events already carry the destroyed HQ event.
	assert_int(enemy_hq.current_hp).is_equal(0)
	var found: StructureDestroyedEvent = null
	for e: Event in events:
		if e is StructureDestroyedEvent:
			found = e
	assert_object(found).is_not_null()
	assert_bool(found.is_hq).is_true()
	# Feed those events directly into run_win_check (mirrors win_check_terminal_test.gd).
	state.run_win_check(events)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0) # opponent of the destroyed HQ's owner (1)
