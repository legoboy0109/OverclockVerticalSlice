# Story 006: Counterattack Resolution.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-006-counterattack-resolution.md:
#   AC-1 (no counter, VS default): each of the 4 VS unit types as a surviving
#         defender -> no counter fires (can_counterattack defaults false
#         roster-wide).
#   AC-2 (counter fires when in-profile): a can_counterattack=true defender
#         that survives, with the attacker inside the defender's own DIRECT
#         range -> a free counter fires (attacker hp drops by the defender's
#         damage(), neither has_attacked changes, no AP deducted for the
#         counter).
#   AC-3 (dead defenders never counter): a can_counterattack=true defender
#         reduced to 0 hp by the primary hit -> no counter (primary death
#         check runs strictly before the counter check).
#   AC-4 (out-of-profile defender never counters): a can_counterattack=true,
#         range-1 DIRECT defender struck by an attacker at range 3 (Sniper) ->
#         no counter; an AREA defender whose attacker sits outside its
#         [min_range, attack_range] ring -> same result.
#   AC-5 (counter-kills-attacker, no counter-to-counter): a counter that
#         reduces the attacker to 0 hp -> the attacker is destroyed (grid
#         cleared, removed from entities_by_id, a UnitDestroyedEvent/
#         StructureDestroyedEvent present); the pipeline terminates after one
#         counter step.
#
# Also (mandatory per the story's Implementation Notes, not optional):
#   * a StructureState defender (the Defensive Structure) counters an
#     in-profile attacker.
#   * a StructureState attacker (a Defensive Structure) is countered and
#     killed by the counter -- regression guard that the counter damage
#     routes through _apply_damage_to, not Unit.apply_hp_delta directly.
#
# Fixtures mirror tests/unit/combat/destroy_entity_test.gd's style
# (_make_grid/_make_state/_make_unit/_make_structure/_make_action/_place).
# Unit-defender counter fixtures use a throwaway UnitTypeDef.new() with
# can_counterattack = true set directly (fresh Resource, not a loaded .tres),
# mirroring destroy_entity_test.gd's _make_frail_type() pattern -- since every
# real VS roster UnitTypeDef ships can_counterattack = false.
#
# Out of scope (do not implement here, per the story):
#   * Story 007: determinism/clone-isolation of the full pipeline including
#     counter scenarios.
#   * Story 008: end-to-end integration proving both primary and counter hp
#     changes are present after a real apply_action call.
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


# A throwaway DIRECT UnitTypeDef fixture with can_counterattack = true set
# directly -- a fresh Resource.new(), never load()'d, since every real VS
# roster type ships can_counterattack = false. Mirrors destroy_entity_test.gd's
# _make_frail_type() pattern.
func _make_counter_type(hp: int = 10, attack: int = 3, attack_range: int = 1, defense: int = 0) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "CounterTestFixture"
	type.hp = hp
	type.attack = attack
	type.attack_range = attack_range
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = defense
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	type.can_counterattack = true
	return type


# A throwaway AREA UnitTypeDef fixture with can_counterattack = true --
# mirrors area_targeting_test.gd's _make_area_type() pattern.
func _make_area_counter_type(min_range: int = 2, attack_range: int = 4, hp: int = 10, attack: int = 3) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "AreaCounterTestFixture"
	type.hp = hp
	type.attack = attack
	type.attack_range = attack_range
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = 0
	type.targeting_mode = UnitTypeDef.TargetingMode.AREA
	type.min_range = min_range
	type.can_counterattack = true
	return type


# Sets BOTH type.hp and current_hp explicitly to the same value, so the
# _apply_damage_to inline clamp ceiling never surprises a fixture. NOTE:
# is_hq=true claims the real StructureTypes.HQ template identity (ADR-0007:
# is_hq() == type == StructureTypes.HQ, a Resource-ref check against the
# real, immutable HQ const) -- [param hp] is ignored in that branch. Never
# invoked with is_hq=true in this suite today (no HQ-identity fixture is
# needed here), but kept schema-faithful for signature parity with
# destroy_entity_test.gd's identical helper.
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


# A Defensive Structure fixture (attack 4, range 2, DIRECT, can_counterattack
# true) -- per the story's own framing of the Defensive Structure as the
# GDD's first live counter case. Reuses destroy_entity_test.gd's AC-5 stat
# block, plus can_counterattack.
func _make_counter_structure(entity_id: int, owner: int, pos: Vector2i, hp: int = 10) -> StructureState:
	var structure := _make_structure(entity_id, owner, pos, hp)
	structure.type.attack = 4
	structure.type.attack_range = 2
	structure.type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	structure.type.min_range = 1
	structure.type.can_counterattack = true
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


# --- AC-1: no counter, VS default (can_counterattack defaults false) ---------

func test_all_four_vs_unit_types_default_no_counterattack_field() -> void:
	# Arrange/Act/Assert -- the roster-wide default this AC depends on: every
	# VS UnitTypeDef ships can_counterattack = false.
	for type: UnitTypeDef in [UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.HEAVY, UnitTypes.SNIPER]:
		assert_bool(type.can_counterattack).is_false()


func test_vs_unit_defender_survives_hit_no_counter_fires() -> void:
	# Arrange -- Trooper (atk 3) attacks a full-hp Scout (hp 3, can_counterattack
	# false); damage floors well short of lethal so the Scout survives.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var scout_type := UnitTypeDef.new()
	scout_type.display_name = "ScoutTough"
	scout_type.hp = 20
	scout_type.attack = 2
	scout_type.attack_range = 1
	scout_type.move_cost = 1
	scout_type.soft_move_cap = 4
	scout_type.produce_cost = 2
	scout_type.can_counterattack = false
	var scout := _make_unit(2, 1, scout_type, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, scout)
	var attacker_hp_before: int = trooper.current_hp
	var action := _make_action(trooper.position, scout.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- defender survived, but no counter damage landed on the attacker.
	assert_int(scout.current_hp).is_greater(0)
	assert_int(trooper.current_hp).is_equal(attacker_hp_before)


# --- AC-2: counter fires when in-profile --------------------------------------

func test_counterattack_true_defender_in_profile_counters_for_free() -> void:
	# Arrange -- Trooper (atk 3, range 2) attacks a can_counterattack=true
	# defender (hp 10, atk 4, range 1) at distance 1 -- inside BOTH profiles.
	# Defender survives (10 - 3 = 7); counters back for its own damage (4).
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 4, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, defender)
	var expected_counter_dmg: int = Combat.damage(state, defender, trooper)
	var attacker_hp_before: int = trooper.current_hp
	var action := _make_action(trooper.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- defender survived and counter damage landed on the attacker.
	assert_int(defender.current_hp).is_greater(0)
	assert_int(trooper.current_hp).is_equal(attacker_hp_before - expected_counter_dmg)


func test_counter_step_changes_neither_entitys_has_attacked() -> void:
	# Arrange -- same in-profile counter setup as above.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 4, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, defender)
	var action := _make_action(trooper.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- has_attacked was already set true on the attacker by the
	# PRIMARY hit (Story 004/005 behavior, unrelated to the counter); the
	# defender's has_attacked must remain untouched by the free counter step.
	assert_bool(trooper.has_attacked).is_true()
	assert_bool(defender.has_attacked).is_false()


func test_counter_step_deducts_no_ap_beyond_the_primary_attack_cost() -> void:
	# Arrange -- current_ap set to exactly the primary attack's cost, so any
	# extra deduction from the (free) counter would drive it negative or
	# leave a mismatch.
	var state := _make_state(CombatBalance.combat.attack_cost)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 4, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, defender)
	var action := _make_action(trooper.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- exactly the primary attack_cost was spent; the counter (an
	# action by player 1, the defender's owner) never touches player 0's AP,
	# and no AP pool was charged for the counter itself (counters are free --
	# there is no AP.spend call anywhere in the counter block).
	assert_int(state.per_player[0].current_ap).is_equal(0)
	assert_int(state.per_player[1].current_ap).is_equal(CombatBalance.combat.attack_cost)


# --- AC-3: dead defenders never counter ---------------------------------------

func test_defender_killed_by_primary_hit_never_counters() -> void:
	# Arrange -- Heavy (atk 5) vs a 1-hp can_counterattack=true defender in
	# range 1 -- the primary hit is lethal, so the death check must run
	# before the counter check.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var counter_type := _make_counter_type(1, 4, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	defender.current_hp = 1
	_place(state, heavy)
	_place(state, defender)
	var attacker_hp_before: int = heavy.current_hp
	var action := _make_action(heavy.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- defender is dead, and no counter damage reached the attacker.
	assert_int(defender.current_hp).is_equal(0)
	assert_int(heavy.current_hp).is_equal(attacker_hp_before)


# --- AC-4: out-of-profile defender never counters -----------------------------

func test_range_one_defender_struck_by_sniper_at_range_three_never_counters() -> void:
	# Arrange -- Sniper (range 3) attacks a can_counterattack=true, range-1
	# DIRECT defender from distance 3 -- inside the Sniper's own range, but
	# OUTSIDE the defender's own range-1 profile (the range-gate that makes
	# kiting real, per the story's QA framing).
	var state := _make_state()
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 4, 1) # range 1
	var defender := _make_unit(2, 1, counter_type, Vector2i(3, 0)) # distance 3
	_place(state, sniper)
	_place(state, defender)
	var attacker_hp_before: int = sniper.current_hp
	var action := _make_action(sniper.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- defender survived (Sniper hp low but damage isn't lethal here
	# since it's the sniper hitting the defender, not vice versa) and no
	# counter reached the attacker.
	assert_int(defender.current_hp).is_greater(0)
	assert_int(sniper.current_hp).is_equal(attacker_hp_before)


func test_area_defender_attacker_outside_ring_never_counters() -> void:
	# Arrange -- an AREA can_counterattack=true defender (min_range 2,
	# attack_range 4) struck by a Sniper (range 3) at distance 1 -- inside the
	# Sniper's own range, but inside the AREA defender's DEAD ZONE (< min_range 2).
	var state := _make_state()
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var area_counter_type := _make_area_counter_type(2, 4, 10, 4)
	var defender := _make_unit(2, 1, area_counter_type, Vector2i(1, 0)) # distance 1
	_place(state, sniper)
	_place(state, defender)
	var attacker_hp_before: int = sniper.current_hp
	var action := _make_action(sniper.position, defender.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- defender survived and no counter reached the attacker (outside
	# the defender's own ring).
	assert_int(defender.current_hp).is_greater(0)
	assert_int(sniper.current_hp).is_equal(attacker_hp_before)


# --- AC-5: counter-kills-attacker, no counter-to-counter -----------------------

func test_counter_kills_attacker_destroys_it_no_counter_to_counter() -> void:
	# Arrange -- a can_counterattack=true, high-attack defender (atk 20) vs a
	# 1-hp attacker in range 1 -- the counter is guaranteed lethal to the
	# attacker. The attacker's own primary hit does not kill the defender
	# (defender hp 10, attacker atk 0).
	var state := _make_state()
	var weak_attacker_type := UnitTypeDef.new()
	weak_attacker_type.display_name = "WeakAttacker"
	weak_attacker_type.hp = 1
	weak_attacker_type.attack = 0
	weak_attacker_type.attack_range = 1
	weak_attacker_type.move_cost = 1
	weak_attacker_type.soft_move_cap = 1
	weak_attacker_type.produce_cost = 1
	var attacker := _make_unit(1, 0, weak_attacker_type, Vector2i(0, 0))
	attacker.current_hp = 1
	var counter_type := _make_counter_type(10, 20, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, attacker)
	_place(state, defender)
	var action := _make_action(attacker.position, defender.position, 0)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- defender survived the (0-damage-floored-to-MIN_DAMAGE) primary
	# hit, then the counter killed the attacker: grid cleared, removed from
	# entities_by_id, a UnitDestroyedEvent present. The defender itself takes
	# no further damage after the one counter step (pipeline terminates).
	assert_int(defender.current_hp).is_greater(0)
	assert_int(attacker.current_hp).is_equal(0)
	assert_bool(state.entities_by_id.has(attacker.entity_id)).is_false()
	assert_int(state.grid.occupant_at(0, 0)).is_equal(GridState.EMPTY_OCCUPANT)
	var found: UnitDestroyedEvent = null
	for e: Event in events:
		if e is UnitDestroyedEvent and e.entity_id == attacker.entity_id:
			found = e
	assert_object(found).is_not_null()


# --- Mandatory: StructureState defender counters an in-profile attacker ------

func test_structure_defender_counterattacks_in_profile_attacker() -> void:
	# Arrange -- a Defensive Structure (can_counterattack=true, atk 4, range 2,
	# DIRECT) survives an attack from a Trooper (atk 3, range 2) at distance 1
	# -- inside the structure's own range-2 profile.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var defensive_structure := _make_counter_structure(2, 1, Vector2i(1, 0), 10)
	_place(state, trooper)
	_place(state, defensive_structure)
	var expected_counter_dmg: int = Combat.damage(state, defensive_structure, trooper)
	var attacker_hp_before: int = trooper.current_hp
	var action := _make_action(trooper.position, defensive_structure.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- structure survived the primary hit (10 - 3 = 7) and countered.
	assert_int(defensive_structure.current_hp).is_greater(0)
	assert_int(trooper.current_hp).is_equal(attacker_hp_before - expected_counter_dmg)
	assert_bool(defensive_structure.has_attacked).is_false()


# --- Mandatory: StructureState attacker countered and killed (regression) ----
# Exercises that the counter damage routes through _apply_damage_to (which
# branches unit-vs-structure), NOT Unit.apply_hp_delta directly -- the latter
# is typed to UnitState only and would crash on a StructureState attacker.

func test_structure_attacker_countered_and_killed_routes_through_apply_damage_to() -> void:
	# Arrange -- a Defensive Structure attacker (atk 4, range 2, DIRECT, low
	# hp) attacks a can_counterattack=true unit defender (high attack) at
	# distance 1 -- inside the defender's own range-1 profile. The counter is
	# guaranteed lethal to the structure attacker.
	var state := _make_state(1)
	var structure_attacker := _make_defensive_structure_low_hp(1, 0, Vector2i(0, 0))
	var counter_type := _make_counter_type(10, 20, 1)
	var defender := _make_unit(2, 1, counter_type, Vector2i(1, 0))
	_place(state, structure_attacker)
	_place(state, defender)
	var action := _make_action(structure_attacker.position, defender.position, 0)
	# Act -- would crash here (Unit.apply_hp_delta expects a UnitState) if the
	# counter step ever regressed to bypass _apply_damage_to's polymorphism.
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- the structure attacker was destroyed by the counter.
	assert_int(structure_attacker.current_hp).is_equal(0)
	assert_bool(state.entities_by_id.has(structure_attacker.entity_id)).is_false()
	assert_int(state.grid.occupant_at(0, 0)).is_equal(GridState.EMPTY_OCCUPANT)
	var found: StructureDestroyedEvent = null
	for e: Event in events:
		if e is StructureDestroyedEvent and e.entity_id == structure_attacker.entity_id:
			found = e
	assert_object(found).is_not_null()
	assert_bool(found.is_hq).is_false()


# A Defensive Structure attacker fixture with low hp (1), guaranteed to die to
# any nonzero counter -- otherwise identical to destroy_entity_test.gd's
# _make_defensive_structure() (atk 4, range 2, DIRECT).
func _make_defensive_structure_low_hp(entity_id: int, owner: int, pos: Vector2i) -> StructureState:
	var structure := _make_structure(entity_id, owner, pos, 1)
	structure.type.attack = 4
	structure.type.attack_range = 2
	structure.type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	structure.type.min_range = 1
	return structure
