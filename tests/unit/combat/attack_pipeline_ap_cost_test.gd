# Story 004: AttackAction Verb Handler — AP Cost, Once-Per-Turn, Enemy-Only, Atomicity.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-004-attack-verb-ap-cost-atomicity.md:
#   AC-1: offered when legal (has_attacked=false, current_ap>=2) -> OK.
#   AC-2: once-per-turn rejection -> rejected before AP/target eval, nothing changed.
#   AC-3: has_attacked flips true regardless of outcome (lethal and non-lethal).
#   AC-4: unaffordable attack (current_ap<2) -> CANT_AFFORD, full atomicity.
#   AC-5: double-submit idempotency (stateless re-validation) + target-gone edge case.
#   AC-6: enemy-only -- own unit / own HQ target -> ILLEGAL_TARGET.
#   AC-7: primary damage lands exactly Combat.damage(...), both a UnitState
#         defender (via Unit.apply_hp_delta) and a StructureState defender
#         (via the _apply_damage_to inline clamp).
#
# Combat.validate()/Combat.apply() are called directly against a hand-built
# GameStateFactory state with real (not mocked) AP/GridState, per the story's
# "fake/injected Grid + AP" framing -- these are real, lightweight, headless
# classes constructed as small test fixtures, never through the full
# apply_action dispatch (that end-to-end wiring is Story 008).
#
# Fixtures mirror tests/unit/combat/direct_targeting_test.gd's style
# (_make_grid/_make_state/_make_unit/_make_structure/_place) plus
# damage_formula_test.gd's _make_unit_type convention.
#
# Combat Resolution Story 005 removed the guard this suite's
# test_structure_attacker_rejected_illegal_target() pinned (a StructureState
# attacker was TEMPORARILY rejected ILLEGAL_TARGET pending Story 005's
# structure-attacker polymorphism -- that test's own comment said so). That
# guard is now gone by design; the corrected, opposite behavior (a structure
# attacker resolves through the same pipeline, AP cost from
# BaseProduction.defensive_attack_cost()) is covered by
# tests/unit/combat/destroy_entity_test.gd's AC-5 tests instead. The obsolete
# test was removed here rather than inverted in place, since its whole
# premise (structure-as-attacker == illegal) no longer holds.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# --- Fixture builders --------------------------------------------------------

# Blank all-Plain grid, large enough for every fixture below.
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


# current_ap defaults to CombatBalance.combat.attack_cost so a legal attack is
# affordable unless a test explicitly drives it below that.
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


# Sets BOTH type.hp and current_hp explicitly to the same value, so the
# _apply_damage_to inline clamp ceiling never surprises a fixture that expects
# a specific starting hp. type is a fresh StructureTypeDef (real
# StructureState.type is null by default, ADR-0007) carrying only the hp this
# story's fixtures need; defense defaults to StructureTypeDef's own 0.
func _make_structure(entity_id: int, owner: int, pos: Vector2i, hp: int = 10) -> StructureState:
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


# Registers an entity into both grid occupancy and entities_by_id, so
# state.entity_at() resolves it the way Combat's handlers require.
func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# --- AC-1: offered when legal -------------------------------------------------

func test_legal_attack_has_attacked_false_enough_ap_returns_ok() -> void:
	# Arrange -- Trooper (range 2) adjacent to an enemy Scout, full AP, never attacked.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	var action := _make_action(trooper.position, enemy.position, 0)
	# Act / Assert
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)


# --- AC-2: once-per-turn rejection --------------------------------------------

func test_already_attacked_this_turn_rejected_before_ap_or_target_eval() -> void:
	# Arrange -- attacker already flagged has_attacked=true.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	trooper.has_attacked = true
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	var ap_before: int = state.per_player[0].current_ap
	var hp_before: int = enemy.current_hp
	var action := _make_action(trooper.position, enemy.position, 0)
	# Act
	var reason: int = Combat.validate(state, action)
	# Assert -- rejected, and neither AP nor target hp changed (nothing mutated).
	assert_int(reason).is_not_equal(Action.Reason.OK)
	assert_int(state.per_player[0].current_ap).is_equal(ap_before)
	assert_int(enemy.current_hp).is_equal(hp_before)


# --- AC-3: has_attacked flips true regardless of outcome ----------------------

func test_successful_attack_flips_has_attacked_true_non_lethal() -> void:
	# Arrange -- Scout (atk 2) vs a high-defense unit defender: damage floors at
	# MIN_DAMAGE (1), well short of lethal.
	var state := _make_state()
	var scout := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	var tough_type := UnitTypeDef.new()
	tough_type.display_name = "Tough"
	tough_type.hp = 20
	tough_type.attack = 0
	tough_type.attack_range = 1
	tough_type.move_cost = 1
	tough_type.soft_move_cap = 1
	tough_type.produce_cost = 1
	tough_type.defense = 20
	var tough := _make_unit(2, 1, tough_type, Vector2i(1, 0))
	_place(state, scout)
	_place(state, tough)
	var action := _make_action(scout.position, tough.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- has_attacked flips true even though the target barely scratched.
	assert_bool(scout.has_attacked).is_true()
	assert_int(tough.current_hp).is_equal(19) # 20 - 1 (MIN_DAMAGE floor)


func test_successful_attack_flips_has_attacked_true_lethal() -> void:
	# Arrange -- Heavy (atk 5) vs a 1-hp defense-0 unit defender: lethal, clamps to 0.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var frail_type := UnitTypeDef.new()
	frail_type.display_name = "Frail"
	frail_type.hp = 1
	frail_type.attack = 0
	frail_type.attack_range = 1
	frail_type.move_cost = 1
	frail_type.soft_move_cap = 1
	frail_type.produce_cost = 1
	frail_type.defense = 0
	var frail := _make_unit(2, 1, frail_type, Vector2i(1, 0))
	frail.current_hp = 1
	_place(state, heavy)
	_place(state, frail)
	var action := _make_action(heavy.position, frail.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- has_attacked flips true; target clamped to 0 (destruction itself
	# is Story 005's concern, not asserted here).
	assert_bool(heavy.has_attacked).is_true()
	assert_int(frail.current_hp).is_equal(0)


# --- AC-4: unaffordable attack -- full atomicity ------------------------------

func test_insufficient_ap_returns_cant_afford_and_changes_nothing() -> void:
	# Arrange -- current_ap 1, below the 2-AP attack_cost.
	var state := _make_state(1)
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	var hp_before: int = enemy.current_hp
	var action := _make_action(trooper.position, enemy.position, 0)
	# Act
	var reason: int = Combat.validate(state, action)
	# Assert -- rejected CANT_AFFORD; apply() never reached (caller respects
	# validate's rejection) so AP/has_attacked/target hp are all unchanged.
	assert_int(reason).is_equal(Action.Reason.CANT_AFFORD)
	assert_int(state.per_player[0].current_ap).is_equal(1)
	assert_bool(trooper.has_attacked).is_false()
	assert_int(enemy.current_hp).is_equal(hp_before)


# --- AC-5: double-submit idempotency -------------------------------------------

func test_resubmitting_identical_action_after_apply_is_rejected_no_double_apply() -> void:
	# Arrange -- a legal attack applied once.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var enemy := _make_unit(2, 1, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, enemy)
	var action := _make_action(trooper.position, enemy.position, 0)
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)
	Combat.apply(state, action)
	var hp_after_first_apply: int = enemy.current_hp
	var ap_after_first_apply: int = state.per_player[0].current_ap
	# Act -- re-validate the identical action against the now-updated state.
	var second_reason: int = Combat.validate(state, action)
	# Assert -- rejected (attacker already has_attacked); no second damage, no
	# second AP deduction (apply() is never reached again by a correct caller).
	assert_int(second_reason).is_not_equal(Action.Reason.OK)
	assert_int(enemy.current_hp).is_equal(hp_after_first_apply)
	assert_int(state.per_player[0].current_ap).is_equal(ap_after_first_apply)


func test_resubmitting_against_a_target_that_no_longer_exists_rejects_never_crashes() -> void:
	# Arrange -- the target tile is now empty (as if destroyed by some other
	# means); validate() must reject cleanly, never null-dereference.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var action := _make_action(trooper.position, Vector2i(1, 0), 0) # no entity there
	# Act
	var reason: int = Combat.validate(state, action)
	# Assert -- a clean rejection, one of the two documented reasons.
	assert_bool(reason == Action.Reason.NO_SUCH_ENTITY or reason == Action.Reason.ILLEGAL_TARGET).is_true()


# --- AC-6: enemy-only ----------------------------------------------------------

func test_target_is_attackers_own_unit_rejected_illegal_target() -> void:
	# Arrange -- target tile occupied by the attacker's own (friendly) unit.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var friendly := _make_unit(2, 0, UnitTypes.SCOUT, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, friendly)
	var action := _make_action(trooper.position, friendly.position, 0)
	# Act / Assert
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_target_is_attackers_own_hq_structure_rejected_illegal_target() -> void:
	# Arrange -- target tile occupied by the attacker's own HQ/structure fixture.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var own_hq := _make_structure(2, 0, Vector2i(1, 0))
	_place(state, trooper)
	_place(state, own_hq)
	var action := _make_action(trooper.position, own_hq.position, 0)
	# Act / Assert
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)


# --- AC-7: primary damage lands, unit AND structure defender ------------------

func test_apply_reduces_unit_defender_hp_by_exactly_combat_damage() -> void:
	# Arrange -- Heavy (atk 5) attacks a tanky unit defender (hp 20, well above
	# the damage this hit deals) so the assertion isolates "exactly
	# Combat.damage(...) subtracted" from Unit.apply_hp_delta's floor clamp
	# (that clamp behavior is already covered by the lethal has_attacked AC-3
	# fixture above). Expected damage computed BEFORE mutation, compared
	# against the pre-hit formula result.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var tanky_type := UnitTypeDef.new()
	tanky_type.display_name = "Tanky"
	tanky_type.hp = 20
	tanky_type.attack = 0
	tanky_type.attack_range = 1
	tanky_type.move_cost = 1
	tanky_type.soft_move_cap = 1
	tanky_type.produce_cost = 1
	tanky_type.defense = 0
	var tanky := _make_unit(2, 1, tanky_type, Vector2i(1, 0))
	_place(state, heavy)
	_place(state, tanky)
	var expected_damage: int = Combat.damage(state, heavy, tanky)
	var hp_before: int = tanky.current_hp
	var action := _make_action(heavy.position, tanky.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- damaged via Unit.apply_hp_delta (the sole current_hp mutator),
	# never a re-derived inline formula.
	assert_int(tanky.current_hp).is_equal(hp_before - expected_damage)


func test_apply_reduces_enemy_structure_defender_hp_by_exactly_combat_damage() -> void:
	# Arrange -- Heavy attacks an enemy structure (HQ-style) defender with
	# defense 2, fixture hp explicitly set on both type.hp and current_hp.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var enemy_hq := _make_structure(2, 1, Vector2i(1, 0), 10)
	enemy_hq.type.defense = 2
	_place(state, heavy)
	_place(state, enemy_hq)
	var expected_damage: int = Combat.damage(state, heavy, enemy_hq)
	var hp_before: int = enemy_hq.current_hp
	var action := _make_action(heavy.position, enemy_hq.position, 0)
	# Act
	Combat.apply(state, action)
	# Assert -- damaged via the _apply_damage_to inline clamp path (structure
	# branch), through the same shared Combat.damage() formula, never a
	# separately re-derived structure-only calculation.
	assert_int(enemy_hq.current_hp).is_equal(hp_before - expected_damage)


# --- Degenerate self-target: attacker_tile == target_tile ----------------------

func test_self_target_same_tile_rejected_illegal_target() -> void:
	# Arrange -- attacker_tile == target_tile resolves the SAME entity for both
	# attacker and target; the `target.owner == attacker.owner` check catches it
	# (an entity always shares its own owner) -> ILLEGAL_TARGET, never a crash or
	# a unit attacking itself.
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	_place(state, trooper)
	var action := _make_action(trooper.position, trooper.position, 0)
	# Act / Assert
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.ILLEGAL_TARGET)
