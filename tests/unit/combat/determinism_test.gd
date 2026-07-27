# Story 007: Determinism & Clone Isolation.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-007-determinism-clone-isolation.md:
#   Group 1 (cross-clone equal result) — given a state S and two independent
#     clones A = S.clone(), B = S.clone(), applying the identical AttackAction
#     to both via Combat.apply() yields equal returned damage ints AND leaves
#     A/B field-wise equal afterward:
#       AC-1a non-lethal primary hit (defender survives, no counter)
#       AC-1b lethal primary hit (defender destroyed/removed in both clones)
#       AC-1c counter-triggering hit (both primary and counter damage present
#             identically in both clones)
#   Group 2 (clone isolation from source) — given a state S and a clone
#     C = S.clone(), applying the AttackAction only to C leaves C reflecting
#     the attack while S is unchanged (snapshotted before the clone/attack):
#       AC-2a non-lethal hit
#       AC-2b lethal hit — the destroyed entity is still present (alive) in S
#             and its tile still occupied in S.grid.occupancy, while absent
#             from C.entities_by_id / C.grid.occupancy shows the tile empty
#       AC-2c counter-triggering hit
#   Negative sanity (code-review follow-up): _states_equal()/_assert_states_equal()
#     are only ever exercised in "should be equal" contexts above, so a latent
#     comparator bug (early return, reference-identity compare, forgotten
#     field) would make every assertion above vacuously green. Two tests close
#     that gap by deliberately diverging a clone on exactly one field and
#     proving the predicate reports the pair unequal (hp; occupancy+presence).
#
# This story adds no new production code (Story 006 already shipped the full
# Combat.apply() pipeline: primary damage -> primary death -> conditional
# counter -> counter death). It is a dedicated assertion pass proving that
# pipeline already satisfies ADR-0003's determinism guarantee (no RNG,
# integer-only state, stable iteration order) and ADR-0001's clone-isolation
# guarantee (duplicate_deep() never lets a clone mutation leak back into the
# source). Tests Combat.apply()/Combat.damage() directly against fixture-built
# GameStates -- NOT through GameState.apply_action() (that integration-level
# concern is Story 008's, explicitly out of scope here).
#
# Fixtures mirror tests/unit/combat/destroy_entity_test.gd and
# counterattack_test.gd's style (_make_grid/_make_state/_make_unit/
# _make_structure/_make_action/_place/_make_counter_type).
#
# State-equality helper: this story's Implementation Notes call for a
# test-local field-wise comparison function (no reusable generic GameState
# state-equality helper exists yet in tests/helpers/ -- movement_determinism_test.gd's
# _assert_result_sets_identical is Movement-specific, comparing
# Array[Movement.ReachableTile], not a GameState). _states_equal() (a pure
# predicate) is the single source of truth; _assert_states_equal() is a thin
# assertion wrapper over it. Compares, for every entity present in either
# state's entities_by_id: presence/absence, current_hp, position, and
# has_attacked (a "destroyed" entity is simply absent -- no separate boolean
# to check) -- plus the full grid.occupancy PackedInt32Array via direct `==`
# (confirmed to type-check; PackedInt32Array supports direct equality
# comparison in GDScript 4.6).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders (mirrors destroy_entity_test.gd / counterattack_test.gd) -

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


# A tough, can_counterattack=false defender -- survives a hit without
# triggering a counter (isolates the "non-lethal, no counter" pipeline shape).
func _make_tough_type(hp: int = 20, defense: int = 0) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "ToughTestFixture"
	type.hp = hp
	type.attack = 0
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = defense
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	type.can_counterattack = false
	return type


# A 1-hp, defense-0 defender -- guarantees a lethal hit from any nonzero-attack
# attacker (mirrors destroy_entity_test.gd's _make_frail_type()).
func _make_frail_type() -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "FrailTestFixture"
	type.hp = 1
	type.attack = 0
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = 0
	type.targeting_mode = UnitTypeDef.TargetingMode.DIRECT
	type.min_range = 1
	type.can_counterattack = false
	return type


# A throwaway DIRECT UnitTypeDef fixture with can_counterattack = true --
# mirrors counterattack_test.gd's _make_counter_type() pattern.
func _make_counter_type(hp: int = 10, attack: int = 4, attack_range: int = 1, defense: int = 0) -> UnitTypeDef:
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


func _make_action(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# --- State-equality helper (test-local; no reusable GameState-equality helper
# exists yet in tests/helpers/, per this story's Implementation Notes) ---------
#
# _states_equal() is the single source of truth for "are these two GameStates
# field-wise equal" -- a pure predicate, returning false on the first field
# mismatch found (occupancy, presence/absence, position, current_hp,
# has_attacked). _assert_states_equal() is a thin wrapper asserting the
# predicate is true; this guarantees the exact comparison code path guarding
# every "should be equal" test is also the one the negative sanity test below
# proves actually detects inequality -- no second, parallel comparison to
# accidentally drift out of sync (single-source-of-truth over per-field
# diagnostics: a failure here reports "states not equal", not which field).

# Pure predicate: true iff [param a] and [param b] are field-wise equal --
# full grid.occupancy equality, plus for every entity present in either
# state's entities_by_id: identical presence/absence, position, current_hp,
# and has_attacked. Short-circuits (returns false) on the first mismatch
# found; never mutates either state.
func _states_equal(a: GameState, b: GameState) -> bool:
	if a.grid.occupancy != b.grid.occupancy:
		return false

	var ids: Dictionary[int, bool] = {}
	for id: int in a.entities_by_id.keys():
		ids[id] = true
	for id: int in b.entities_by_id.keys():
		ids[id] = true
	var sorted_ids: Array[int] = ids.keys()
	sorted_ids.sort()

	for id: int in sorted_ids:
		var in_a: bool = a.entities_by_id.has(id)
		var in_b: bool = b.entities_by_id.has(id)
		if in_a != in_b:
			return false
		if not in_a or not in_b:
			continue # destroyed identically in both -- absence IS the equality
		var ea: EntityState = a.entities_by_id[id]
		var eb: EntityState = b.entities_by_id[id]
		if ea.position != eb.position:
			return false
		if _current_hp_of(ea) != _current_hp_of(eb):
			return false
		if _has_attacked_of(ea) != _has_attacked_of(eb):
			return false
	return true


# Thin assertion wrapper over [method _states_equal] -- fails the calling test
# immediately if [param a]/[param b] diverge. See that method's doc comment
# for why this deliberately does not re-implement per-field comparison.
func _assert_states_equal(a: GameState, b: GameState) -> void:
	assert_bool(_states_equal(a, b)).is_true()


# Deliberately two-subtype only (UnitState / StructureState) -- mirrors
# production's own EntityState specialization (ADR-0007: exactly these two
# concrete subclasses, no further subclassing), so no third branch is needed.
func _current_hp_of(e: EntityState) -> int:
	if e is UnitState:
		return (e as UnitState).current_hp
	return (e as StructureState).current_hp


# Deliberately two-subtype only (UnitState / StructureState) -- see
# [method _current_hp_of]'s doc comment.
func _has_attacked_of(e: EntityState) -> bool:
	if e is UnitState:
		return (e as UnitState).has_attacked
	return (e as StructureState).has_attacked


# --- Group 1: cross-clone equal result ----------------------------------------

# AC-1a: non-lethal primary hit, no counter -- A/B both take the identical
# non-lethal hit and end up field-wise equal.
func test_cross_clone_non_lethal_hit_equal_damage_and_equal_states() -> void:
	# Arrange -- Heavy (atk 5) vs a tough, can_counterattack=false defender:
	# non-lethal, no counter fires.
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var tough := _make_unit(2, 1, _make_tough_type(20), Vector2i(1, 0))
	_place(source, heavy)
	_place(source, tough)
	var clone_a: GameState = source.clone()
	var clone_b: GameState = source.clone()
	var action_a := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)
	var action_b := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act
	var dmg_a: int = Combat.damage(clone_a, clone_a.entities_by_id[1], clone_a.entities_by_id[2])
	var dmg_b: int = Combat.damage(clone_b, clone_b.entities_by_id[1], clone_b.entities_by_id[2])
	Combat.apply(clone_a, action_a)
	Combat.apply(clone_b, action_b)

	# Assert -- equal returned damage; A/B field-wise equal afterward; defender
	# survived (non-lethal) and no counter reached the attacker (tough is
	# can_counterattack=false).
	assert_int(dmg_a).is_equal(dmg_b)
	assert_int(clone_a.entities_by_id[2].current_hp).is_greater(0)
	_assert_states_equal(clone_a, clone_b)


# AC-1b: lethal primary hit -- defender destroyed/removed identically in both
# clones (grid + entities_by_id).
func test_cross_clone_lethal_hit_equal_damage_and_equal_states() -> void:
	# Arrange -- Heavy (atk 5) vs a 1-hp frail defender: lethal.
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail := _make_unit(2, 1, _make_frail_type(), Vector2i(1, 0))
	_place(source, heavy)
	_place(source, frail)
	var clone_a: GameState = source.clone()
	var clone_b: GameState = source.clone()
	var action_a := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)
	var action_b := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act
	var dmg_a: int = Combat.damage(clone_a, clone_a.entities_by_id[1], clone_a.entities_by_id[2])
	var dmg_b: int = Combat.damage(clone_b, clone_b.entities_by_id[1], clone_b.entities_by_id[2])
	Combat.apply(clone_a, action_a)
	Combat.apply(clone_b, action_b)

	# Assert -- equal returned damage; defender destroyed identically in both
	# (removed from entities_by_id + grid cleared); A/B field-wise equal.
	assert_int(dmg_a).is_equal(dmg_b)
	assert_bool(clone_a.entities_by_id.has(2)).is_false()
	assert_bool(clone_b.entities_by_id.has(2)).is_false()
	assert_int(clone_a.grid.occupant_at(1, 0)).is_equal(GridState.EMPTY_OCCUPANT)
	assert_int(clone_b.grid.occupant_at(1, 0)).is_equal(GridState.EMPTY_OCCUPANT)
	_assert_states_equal(clone_a, clone_b)


# AC-1c: counter-triggering hit -- both primary and counter damage present
# identically in both clones.
func test_cross_clone_counter_triggering_hit_equal_damage_and_equal_states() -> void:
	# Arrange -- Trooper (atk 3, range 2) attacks a can_counterattack=true
	# defender (hp 10, atk 4, range 1) at distance 1 -- inside both profiles.
	# Defender survives and counters back for its own damage.
	var source := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_defender := _make_unit(2, 1, _make_counter_type(10, 4, 1), Vector2i(1, 0))
	_place(source, trooper)
	_place(source, counter_defender)
	var clone_a: GameState = source.clone()
	var clone_b: GameState = source.clone()
	var action_a := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)
	var action_b := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act -- primary damage (attacker -> defender) and counter damage
	# (defender -> attacker), computed identically on each clone.
	var primary_dmg_a: int = Combat.damage(clone_a, clone_a.entities_by_id[1], clone_a.entities_by_id[2])
	var primary_dmg_b: int = Combat.damage(clone_b, clone_b.entities_by_id[1], clone_b.entities_by_id[2])
	var counter_dmg_a: int = Combat.damage(clone_a, clone_a.entities_by_id[2], clone_a.entities_by_id[1])
	var counter_dmg_b: int = Combat.damage(clone_b, clone_b.entities_by_id[2], clone_b.entities_by_id[1])
	Combat.apply(clone_a, action_a)
	Combat.apply(clone_b, action_b)

	# Assert -- both damage ints equal across clones; defender survived and
	# countered in both (attacker hp reduced by counter damage in both);
	# A/B field-wise equal afterward.
	assert_int(primary_dmg_a).is_equal(primary_dmg_b)
	assert_int(counter_dmg_a).is_equal(counter_dmg_b)
	assert_int(clone_a.entities_by_id[2].current_hp).is_greater(0)
	assert_int(clone_b.entities_by_id[2].current_hp).is_greater(0)
	assert_int(clone_a.entities_by_id[1].current_hp).is_equal(UnitTypes.TROOPER.hp - counter_dmg_a)
	assert_int(clone_b.entities_by_id[1].current_hp).is_equal(UnitTypes.TROOPER.hp - counter_dmg_b)
	_assert_states_equal(clone_a, clone_b)


# --- Group 2: clone isolation from source --------------------------------------

# AC-2a: non-lethal hit applied only to the clone leaves the source unchanged.
func test_clone_isolation_non_lethal_hit_source_unchanged() -> void:
	# Arrange -- same non-lethal, no-counter setup as AC-1a.
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var tough := _make_unit(2, 1, _make_tough_type(20), Vector2i(1, 0))
	_place(source, heavy)
	_place(source, tough)
	var source_snapshot: GameState = source.clone() # pre-clone/attack snapshot
	var clone: GameState = source.clone()
	var action := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act -- attack only the clone.
	Combat.apply(clone, action)

	# Assert -- clone reflects the attack (defender took damage); source is
	# field-wise identical to its pre-attack snapshot (never mutated).
	assert_int(clone.entities_by_id[2].current_hp).is_less(tough.type.hp)
	_assert_states_equal(source, source_snapshot)


# AC-2b: lethal hit -- the destroyed entity is still present (alive) in S and
# its tile still occupied in S.grid.occupancy, while absent from
# C.entities_by_id and C.grid.occupancy shows the tile empty.
func test_clone_isolation_lethal_hit_source_still_has_entity_alive() -> void:
	# Arrange -- same lethal setup as AC-1b.
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail := _make_unit(2, 1, _make_frail_type(), Vector2i(1, 0))
	_place(source, heavy)
	_place(source, frail)
	var source_snapshot: GameState = source.clone() # pre-clone/attack snapshot
	var clone: GameState = source.clone()
	var action := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act -- attack only the clone; lethal, destroys the defender in the clone.
	Combat.apply(clone, action)

	# Assert -- the clone reflects the destruction: absent from entities_by_id,
	# tile empty in the clone's grid.
	assert_bool(clone.entities_by_id.has(2)).is_false()
	assert_int(clone.grid.occupant_at(1, 0)).is_equal(GridState.EMPTY_OCCUPANT)

	# Assert -- the SOURCE is untouched: the entity is still present/alive
	# (full hp) and its tile is still occupied in the source's own grid.
	assert_bool(source.entities_by_id.has(2)).is_true()
	assert_int(source.entities_by_id[2].current_hp).is_equal(frail.type.hp)
	assert_int(source.grid.occupant_at(1, 0)).is_equal(2)

	# Assert -- source is field-wise identical to its pre-attack snapshot.
	_assert_states_equal(source, source_snapshot)


# AC-2c: counter-triggering hit applied only to the clone leaves the source
# untouched (both the primary AND the counter effects stay clone-local).
func test_clone_isolation_counter_triggering_hit_source_unchanged() -> void:
	# Arrange -- same counter-triggering setup as AC-1c.
	var source := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var counter_defender := _make_unit(2, 1, _make_counter_type(10, 4, 1), Vector2i(1, 0))
	_place(source, trooper)
	_place(source, counter_defender)
	var source_snapshot: GameState = source.clone() # pre-clone/attack snapshot
	var clone: GameState = source.clone()
	var action := _make_action(Vector2i(0, 0), Vector2i(1, 0), 0)

	# Act -- attack only the clone; defender survives and counters.
	Combat.apply(clone, action)

	# Assert -- clone reflects both the primary hit and the counter.
	assert_int(clone.entities_by_id[2].current_hp).is_less(10)
	assert_int(clone.entities_by_id[1].current_hp).is_less(UnitTypes.TROOPER.hp)

	# Assert -- source is field-wise identical to its pre-attack snapshot —
	# neither the primary damage nor the counter damage leaked back.
	_assert_states_equal(source, source_snapshot)


# --- Negative sanity: _states_equal() actually detects inequality -------------
#
# Every positive test above only ever calls _states_equal() (via
# _assert_states_equal()) in a "should be equal" context. Without a test that
# deliberately diverges two states and checks for false, a latent bug in the
# comparator (an early return, a reference-identity compare instead of a
# value compare, a forgotten field) would make every assertion above
# vacuously green. These tests close that gap by mutating exactly ONE field
# on a clone and asserting the predicate reports the pair unequal.

func test_states_equal_detects_hp_divergence() -> void:
	# Arrange -- two states starting field-wise equal (clones of the same source).
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	_place(source, heavy)
	var base: GameState = source.clone()
	var diverged: GameState = source.clone()
	# Sanity precondition -- the two clones start out equal.
	assert_bool(_states_equal(base, diverged)).is_true()

	# Act -- mutate ONLY current_hp on the diverged clone's entity.
	(diverged.entities_by_id[1] as UnitState).current_hp -= 1

	# Assert -- the predicate reports the pair unequal.
	assert_bool(_states_equal(base, diverged)).is_false()


func test_states_equal_detects_occupancy_and_presence_divergence() -> void:
	# Arrange -- two states starting field-wise equal (clones of the same source).
	var source := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail := _make_unit(2, 1, _make_frail_type(), Vector2i(1, 0))
	_place(source, heavy)
	_place(source, frail)
	var base: GameState = source.clone()
	var diverged: GameState = source.clone()
	# Sanity precondition -- the two clones start out equal.
	assert_bool(_states_equal(base, diverged)).is_true()

	# Act -- erase ONE entity from the diverged clone and clear its grid tile
	# (mirrors what a destroy_entity() call does, but done directly here so
	# this test exercises only the comparator, not Combat.apply()).
	diverged.grid.remove(1, 0)
	diverged.entities_by_id.erase(2)

	# Assert -- the predicate reports the pair unequal (both the occupancy
	# divergence and the presence/absence divergence are each independently
	# sufficient; this single mutation exercises both).
	assert_bool(_states_equal(base, diverged)).is_false()
