# Base & Production Story 006: Defensive Structure Attack (AP / Flag / Immobility slice).
#
# Covers the acceptance criteria in
# production/epics/base-production/story-006-defensive-structure-attack.md — the
# B&P-owned slice of a Defensive Structure firing through Combat's shared
# attacker pipeline (ADR-0010 structure-as-attacker + ADR-0017 defensive_attack_cost):
#   - a Completed Defensive Structure fires: exactly 1 AP (defensive_attack_cost,
#     NOT the unit attack_cost 2) spent, has_attacked -> true;
#   - has_attacked true -> Combat.validate rejects, no AP spent;
#   - an Under-Construction Defensive Structure cannot fire -> NOT_COMPLETED, no
#     AP, has_attacked stays false (closes the BP-002 attack-inertness half);
#   - immobility is structural: Movement.validate rejects a structure mover with
#     NO_SUCH_ENTITY (Movement only moves UnitStates — there is no structure-move
#     path/verb);
#   - structure attack is NOT research-buffed: Combat.damage uses the flat
#     type.attack (4) even when the owner has Attack Tech.
#
# Combat's targeting legality, the damage formula internals, and the free
# uncosted counter are Combat's OWN Pure-Logic ACs (combat-resolution epic,
# Complete) — cross-referenced, NOT duplicated here (story cross-reference note).
#
# Combat.validate()/Combat.apply()/Combat.damage() and Movement.validate() are
# called directly against a hand-built GameStateFactory state with real (not
# mocked) AP/GridState, mirroring tests/unit/combat/attack_pipeline_ap_cost_test.gd's
# fixture style. Rejection ACs assert validate() only and never call apply()
# (Combat.apply assumes validate passed — it does not re-validate), matching that
# suite's own convention.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# The Attack-Tech bonus lives on the process-global Research stub static; reset
# before and after every test so this suite neither inherits a leaked bonus nor
# leaks its own injection into a suite that runs later in the same process
# (isolation convention — mirrors tests/unit/effective_attack_test.gd).
func before_test() -> void:
	Research.reset()


func after_test() -> void:
	Research.reset()


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


# Both players pinned to Neutral: a UnitState defender's Combat.damage path reads
# Unit.effective_defense -> Faction.unit_delta(state.faction_of(owner), ...),
# which dereferences a non-null FactionDef.
func _make_state(current_ap: int = 5) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	return state


# A real Defensive Structure (StructureTypes registry template: attack 4,
# attack_range 2, can_counterattack true). Completed by default; a test overrides
# to UNDER_CONSTRUCTION for the inertness case.
func _make_defensive_structure(entity_id: int, owner: int, pos: Vector2i, status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = StructureTypes.DEFENSIVE_STRUCTURE
	s.current_hp = s.type.hp
	s.build_status = status
	return s


# A non-countering, defense-0, high-hp enemy target so the AP/flag assertions on
# the ATTACKER aren't perturbed by the defender dying or countering (both are
# Combat's concern, cross-referenced not tested here). Fresh UnitTypeDef.new()
# defaults can_counterattack to false.
func _make_enemy_unit(entity_id: int, owner: int, pos: Vector2i, hp: int = 20) -> UnitState:
	var t := UnitTypeDef.new()
	t.display_name = "Dummy"
	t.hp = hp
	t.attack = 0
	t.attack_range = 1
	t.move_cost = 1
	t.soft_move_cap = 1
	t.produce_cost = 1
	t.defense = 0
	t.can_counterattack = false
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = t
	u.current_hp = hp
	return u


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _make_action(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


# --- AC-fire-cost-flag (Rule 8) ---------------------------------------------

func test_completed_defensive_structure_fires_spends_1_ap_not_2_and_flips_has_attacked() -> void:
	# Arrange -- Completed Defensive Structure (has_attacked false), an enemy unit
	# adjacent (in range), 5 AP.
	var state := _make_state(5)
	var struct := _make_defensive_structure(1, 0, Vector2i(2, 2))
	var enemy := _make_enemy_unit(2, 1, Vector2i(2, 3))
	_place(state, struct)
	_place(state, enemy)
	var action := _make_action(struct.position, enemy.position, 0)
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)
	# Act
	Combat.apply(state, action)
	# Assert -- exactly defensive_attack_cost (1) spent, strictly below the unit
	# attack_cost (2), and has_attacked flipped.
	var def_cost: int = BaseProduction.defensive_attack_cost()
	assert_int(def_cost).is_equal(1)
	assert_bool(def_cost < CombatBalance.combat.attack_cost).is_true()
	assert_int(state.per_player[0].current_ap).is_equal(5 - def_cost) # 4, not 3
	assert_bool(struct.has_attacked).is_true()


# --- AC-already-attacked -----------------------------------------------------

func test_defensive_structure_already_attacked_this_turn_rejected_no_ap_spent() -> void:
	# Arrange -- Completed structure that already fired this turn.
	var state := _make_state(5)
	var struct := _make_defensive_structure(1, 0, Vector2i(2, 2))
	struct.has_attacked = true
	var enemy := _make_enemy_unit(2, 1, Vector2i(2, 3))
	_place(state, struct)
	_place(state, enemy)
	var action := _make_action(struct.position, enemy.position, 0)
	# Act / Assert -- rejected (validate is pure; a correct caller never reaches
	# apply), no AP spent.
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)
	assert_int(state.per_player[0].current_ap).is_equal(5)


# --- AC-under-construction-inert (BP-002 attack half) ------------------------

func test_under_construction_defensive_structure_cannot_fire_rejected_not_completed() -> void:
	# Arrange -- an Under-Construction Defensive Structure (has_attacked false),
	# a legal-looking enemy target in range, plenty of AP. Only a Completed
	# structure fires (Rule 8) -- this closes the BP-002 attack-inertness half.
	var state := _make_state(5)
	var struct := _make_defensive_structure(1, 0, Vector2i(2, 2), StructureState.BuildStatus.UNDER_CONSTRUCTION)
	var enemy := _make_enemy_unit(2, 1, Vector2i(2, 3))
	_place(state, struct)
	_place(state, enemy)
	var action := _make_action(struct.position, enemy.position, 0)
	# Act
	var reason: int = Combat.validate(state, action)
	# Assert -- rejected NOT_COMPLETED before any cost/flag effect; no AP spent,
	# has_attacked untouched.
	assert_int(reason).is_equal(Action.Reason.NOT_COMPLETED)
	assert_int(state.per_player[0].current_ap).is_equal(5)
	assert_bool(struct.has_attacked).is_false()


# --- AC-immobility -----------------------------------------------------------

func test_defensive_structure_has_no_legal_move_action_immobility() -> void:
	# Arrange -- a Completed Defensive Structure. Immobility is structural: there
	# is no move verb/path for a structure. Movement only operates on UnitStates
	# (reachable(state, unit: UnitState); validate rejects a non-UnitState mover),
	# so a MoveAction naming the structure's tile is rejected NO_SUCH_ENTITY --
	# not via a structure-specific "reject move" guard, but because a structure is
	# simply never a mover.
	var state := _make_state(5)
	var struct := _make_defensive_structure(1, 0, Vector2i(2, 2))
	_place(state, struct)
	# Precondition -- the structure genuinely occupies the from-tile, so the
	# rejection below is provably the "occupant is not a UnitState" path, not a
	# trivial "empty tile" NO_SUCH_ENTITY.
	assert_object(state.entity_at(struct.position)).is_same(struct)
	var move := MoveAction.new()
	move.player = 0
	move.from = struct.position
	move.to = Vector2i(2, 3)
	move.tiles_entered = 1
	# Act / Assert -- the structure is not a UnitState, so it has no move path.
	assert_int(Movement.validate(state, move)).is_equal(Action.Reason.NO_SUCH_ENTITY)


# --- AC-attack-tech-no-buff (toggle regression) ------------------------------

func test_defensive_structure_attack_is_not_buffed_by_owner_attack_tech() -> void:
	# Arrange -- pin a KNOWN, nonzero Attack-Tech bonus (3) so this test does not
	# ride on the Research stub's default value: without pinning, the assertion
	# would stay green even if Attack Tech were globally inert (bonus 0), proving
	# nothing. A Completed Defensive Structure (attack 4) whose owner HAS Attack
	# Tech; a defense-0 enemy on plain terrain (no cover, no defense tech) so the
	# damage isolates the attack term.
	Research.set_attack_tech_bonus(3)
	var state := _make_state(5)
	state.per_player[0].has_attack_tech = true
	var struct := _make_defensive_structure(1, 0, Vector2i(2, 2))
	var enemy := _make_enemy_unit(2, 1, Vector2i(2, 3))
	_place(state, struct)
	_place(state, enemy)
	# Precondition -- the template's flat attack is 4.
	assert_int(struct.type.attack).is_equal(4)
	# Differential control -- an equivalent UNIT attacker (base attack 4, SAME
	# owner + Attack Tech) in the SAME state IS buffed live: 4 + 3 = 7 (Combat.damage
	# is a pure function over the two entity refs, no grid placement needed). This
	# proves the bonus is genuinely live here, so the structure's == 4 below is a
	# real "structure ignores the tech", not "the tech does nothing".
	var unit_attacker_type := UnitTypeDef.new()
	unit_attacker_type.display_name = "CtrlAttacker"
	unit_attacker_type.hp = 10
	unit_attacker_type.attack = 4
	unit_attacker_type.attack_range = 2
	unit_attacker_type.move_cost = 1
	unit_attacker_type.soft_move_cap = 1
	unit_attacker_type.produce_cost = 1
	unit_attacker_type.defense = 0
	var unit_attacker := UnitState.new()
	unit_attacker.entity_id = 99
	unit_attacker.owner = 0
	unit_attacker.position = struct.position
	unit_attacker.type = unit_attacker_type
	unit_attacker.current_hp = 10
	assert_int(Combat.damage(state, unit_attacker, enemy)).is_equal(4 + 3) # unit: buffed to 7
	# Act / Assert -- Combat's damage uses the flat STRUCTURE attack (4), NOT the
	# Attack-Tech-buffed value: 4 - 0 cover - 0 defense = 4 (not 7).
	assert_int(Combat.damage(state, struct, enemy)).is_equal(4)
