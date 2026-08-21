# Story 008 / sprint task S5-06: Combat.apply emits a DamageEvent per landed hit.
#
# DamageEvent is the event ADR-0004 named (`damage_event.gd (Combat)`) and never
# built. Combat previously announced only DEATHS, so nothing downstream could tell
# who struck whom on a hit the defender survived -- the common case, and exactly
# what the Board Renderer's attack lunge and hit recoil need.
#
# Covers:
#   AC-1 (non-lethal hit announces itself): a survived hit emits exactly one
#         DamageEvent naming attacker, target and the damage dealt. This is the
#         case that produced NO events at all before this story.
#   AC-2 (blow precedes death, ADR-0004 ordering): a lethal hit emits its
#         DamageEvent at a LOWER index than the destruction event it causes, so a
#         consumer replaying the array in order sees the hit land, then the kill.
#   AC-3 (counterattack swaps the roles): a counter emits its own second
#         DamageEvent whose attacker_id is the DEFENDER -- the property that lets
#         the renderer lunge the right body with no special case.
#   AC-4 (structure defender): a StructureState target is named as target_id like
#         any other, since damage routes polymorphically through _apply_damage_to.
#   AC-5 (amount is the pre-clamp figure): on an overkill the reported amount is
#         the damage dealt, not the smaller hp delta.
#
# Fixtures mirror tests/unit/combat/counterattack_test.gd
# (_make_grid/_make_state/_make_unit/_make_structure/_make_action/_place).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state.
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


func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].current_ap = CombatBalance.combat.attack_cost
	state.per_player[1].current_ap = CombatBalance.combat.attack_cost
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


# A throwaway DIRECT type. can_counterattack defaults false here (every VS roster
# type ships false); AC-3's fixture opts in explicitly.
func _make_type(hp: int, attack: int, can_counter: bool = false) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "DamageEventFixture"
	type.hp = hp
	type.attack = attack
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = 0
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	type.can_counterattack = can_counter
	return type


func _make_structure(entity_id: int, owner: int, pos: Vector2i, hp: int) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type = StructureTypeDef.new()
	structure.type.hp = hp
	structure.current_hp = hp
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


# Every DamageEvent in [param events], in emission order.
func _damage_events(events: Array) -> Array:
	var found: Array = []
	for event: Event in events:
		if event is DamageEvent:
			found.append(event)
	return found


# The index of the first event of the given kind, or -1. Used for the ordering
# assert rather than a hardcoded index, so an unrelated future event appended to
# the same array cannot silently invalidate the check.
func _index_of_destruction(events: Array) -> int:
	for i: int in events.size():
		if events[i] is UnitDestroyedEvent or events[i] is StructureDestroyedEvent:
			return i
	return -1


# --- AC-1: a survived hit announces itself -----------------------------------

func test_non_lethal_hit_emits_one_damage_event_naming_both_parties() -> void:
	# Arrange -- attacker 3 atk vs a 20 hp defender: survives comfortably.
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_type(10, 3), Vector2i(0, 0))
	var defender := _make_unit(2, 1, _make_type(20, 3), Vector2i(1, 0))
	_place(state, attacker)
	_place(state, defender)
	var expected: int = Combat.damage(state, attacker, defender)
	# Act
	var events: Array = Combat.apply(state, _make_action(Vector2i(0, 0), Vector2i(1, 0), 0))
	# Assert -- exactly one, and it names who hit whom for how much.
	var hits: Array = _damage_events(events)
	assert_int(hits.size()).is_equal(1)
	assert_int((hits[0] as DamageEvent).attacker_id).is_equal(1)
	assert_int((hits[0] as DamageEvent).target_id).is_equal(2)
	assert_int((hits[0] as DamageEvent).amount).is_equal(expected)
	# And the defender really did survive -- otherwise this is testing AC-2.
	assert_int(defender.current_hp).is_greater(0)


# --- AC-2: the blow precedes the death it causes (ADR-0004 ordering) ---------

func test_lethal_hit_emits_damage_event_before_the_destruction_event() -> void:
	# Arrange -- 9 atk into a 1 hp defender: certain kill.
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_type(10, 9), Vector2i(0, 0))
	var defender := _make_unit(2, 1, _make_type(1, 1), Vector2i(1, 0))
	_place(state, attacker)
	_place(state, defender)
	# Act
	var events: Array = Combat.apply(state, _make_action(Vector2i(0, 0), Vector2i(1, 0), 0))
	# Assert -- both present, blow strictly first.
	var destroyed_at: int = _index_of_destruction(events)
	assert_int(destroyed_at).is_greater_equal(0)
	var damage_at: int = -1
	for i: int in events.size():
		if events[i] is DamageEvent:
			damage_at = i
			break
	assert_int(damage_at).is_greater_equal(0)
	assert_int(damage_at).is_less(destroyed_at)


# --- AC-3: a counterattack emits its own event with the roles swapped --------

func test_counterattack_emits_a_second_damage_event_with_roles_swapped() -> void:
	# Arrange -- the defender opts into can_counterattack and is in range of the
	# attacker under its own profile, so the free counter fires.
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_type(20, 2), Vector2i(0, 0))
	var defender := _make_unit(2, 1, _make_type(20, 2, true), Vector2i(1, 0))
	_place(state, attacker)
	_place(state, defender)
	# Act
	var events: Array = Combat.apply(state, _make_action(Vector2i(0, 0), Vector2i(1, 0), 0))
	# Assert -- two hits landed, and the second names the DEFENDER as its attacker.
	var hits: Array = _damage_events(events)
	assert_int(hits.size()).is_equal(2)
	assert_int((hits[0] as DamageEvent).attacker_id).is_equal(1)
	assert_int((hits[0] as DamageEvent).target_id).is_equal(2)
	assert_int((hits[1] as DamageEvent).attacker_id).is_equal(2)
	assert_int((hits[1] as DamageEvent).target_id).is_equal(1)


# --- AC-4: a structure defender is named like any other target --------------

func test_structure_defender_is_named_as_target_id() -> void:
	# Arrange -- damage routes polymorphically through _apply_damage_to, so a
	# StructureState defender must be reported no differently.
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_type(10, 3), Vector2i(0, 0))
	var structure := _make_structure(7, 1, Vector2i(1, 0), 30)
	_place(state, attacker)
	_place(state, structure)
	# Act
	var events: Array = Combat.apply(state, _make_action(Vector2i(0, 0), Vector2i(1, 0), 0))
	# Assert
	var hits: Array = _damage_events(events)
	assert_int(hits.size()).is_equal(1)
	assert_int((hits[0] as DamageEvent).target_id).is_equal(7)
	assert_int(structure.current_hp).is_less(30)


# --- AC-5: amount is the damage dealt, not the hp delta ---------------------

func test_overkill_reports_damage_dealt_not_the_smaller_hp_delta() -> void:
	# Arrange -- a 9-damage blow onto a 1 hp defender. hp moves by 1; the honest
	# figure for a log line is the 9 that was actually dealt.
	var state := _make_state()
	var attacker := _make_unit(1, 0, _make_type(10, 9), Vector2i(0, 0))
	var defender := _make_unit(2, 1, _make_type(1, 1), Vector2i(1, 0))
	_place(state, attacker)
	_place(state, defender)
	var dealt: int = Combat.damage(state, attacker, defender)
	# Act
	var events: Array = Combat.apply(state, _make_action(Vector2i(0, 0), Vector2i(1, 0), 0))
	# Assert -- the reported amount is the pre-clamp damage, which here exceeds
	# the 1 hp the defender actually had.
	var hits: Array = _damage_events(events)
	assert_int(hits.size()).is_equal(1)
	assert_int((hits[0] as DamageEvent).amount).is_equal(dealt)
	assert_int((hits[0] as DamageEvent).amount).is_greater(1)
