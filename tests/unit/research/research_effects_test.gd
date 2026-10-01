# CR-14 (2026-09-28): what each shipped tech DOES once completed.
#
# Effects are summed data folded at their single read site (Research's effect folds),
# read live — so these tests grant a tech directly and check the board-level outcome at
# the site the player experiences it: Combat damage, Combat targeting, the produce price,
# the AP actually charged, HP restored at start-of-turn.
#
# ★ Every effect test measures the SAME quantity with and without the tech, so it proves
# the tech changes it — not merely that the number happens to equal some constant.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


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


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
		state.per_player[i].current_ap = 99
		state.per_player[i].current_credits = 99999
	return state


func _unit(state: GameState, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = state.next_entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	state.entities_by_id[unit.entity_id] = unit
	state.grid.place(unit.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return unit


func _set_cover(state: GameState, tile: Vector2i) -> void:
	state.grid.terrain[state.grid.index(tile.x, tile.y)] = GridState.Terrain.COVER


# --- Tier 1 ------------------------------------------------------------------------

func test_attack_tech_adds_one_attack() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Unit.effective_attack(state, unit)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_int(Unit.effective_attack(state, unit)).is_equal(before + 1)


func test_defense_tech_adds_one_defense() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Unit.effective_defense(state, unit)
	GameStateFactory.grant_tech(state, 0, Techs.DEFENSE_I)
	assert_int(Unit.effective_defense(state, unit)).is_equal(before + 1)


func test_economy_tech_raises_income_by_one_tier() -> void:
	var state := _state()
	var before: int = Credits.credit_income(state, 0)
	var ps: PlayerState = state.per_player[0]
	ps.completed_techs.append(Techs.ECONOMY_I)
	ps.economy_tier += Techs.ECONOMY_I.economy_tier_bonus # what completion writes
	assert_int(Credits.credit_income(state, 0)).is_equal(before + Credits.tier_income(1))


func test_tech_effects_are_per_player() -> void:
	var state := _state()
	var theirs := _unit(state, 1, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Unit.effective_attack(state, theirs)
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_int(Unit.effective_attack(state, theirs)).is_equal(before)


# --- Combat branch -----------------------------------------------------------------

func test_penetration_ignores_cover() -> void:
	var state := _state()
	var attacker := _unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 2))
	var defender := _unit(state, 1, UnitTypes.HEAVY, Vector2i(3, 2))
	var in_the_open: int = Combat.damage(state, attacker, defender)
	_set_cover(state, defender.position)
	var in_cover: int = Combat.damage(state, attacker, defender)
	assert_int(in_cover).override_failure_message("Fixture: Cover did not reduce damage.").is_less(in_the_open)
	GameStateFactory.grant_tech(state, 0, Techs.PENETRATION)
	assert_int(Combat.damage(state, attacker, defender)).is_equal(in_the_open)


func test_penetration_does_not_help_the_defender() -> void:
	var state := _state()
	var attacker := _unit(state, 0, UnitTypes.HEAVY, Vector2i(2, 2))
	var defender := _unit(state, 1, UnitTypes.HEAVY, Vector2i(3, 2))
	_set_cover(state, defender.position)
	var before: int = Combat.damage(state, attacker, defender)
	GameStateFactory.grant_tech(state, 1, Techs.PENETRATION)
	assert_int(Combat.damage(state, attacker, defender)).is_equal(before)


func test_volley_adds_one_attack_range() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var before: int = Unit.effective_attack_range(state, unit)
	GameStateFactory.grant_tech(state, 0, Techs.VOLLEY)
	assert_int(Unit.effective_attack_range(state, unit)).is_equal(before + 1)


func test_volley_lets_combat_target_one_tile_further() -> void:
	# Measured where it matters — Combat's own targeting, not just the stat.
	var state := _state()
	var attacker := _unit(state, 0, UnitTypes.SCOUT, Vector2i(2, 2))  # range 1
	_unit(state, 1, UnitTypes.SCOUT, Vector2i(4, 2))                   # 2 tiles away
	assert_array(Combat.legal_targets(state, attacker)).is_empty()
	GameStateFactory.grant_tech(state, 0, Techs.VOLLEY)
	assert_int(Combat.legal_targets(state, attacker).size()).is_equal(1)


func test_volley_does_not_arm_the_builder() -> void:
	var state := _state()
	var builder := _unit(state, 0, UnitTypes.BUILDER, Vector2i(2, 2))
	GameStateFactory.grant_tech(state, 0, Techs.VOLLEY)
	assert_int(Unit.effective_attack_range(state, builder)).is_equal(0)


# --- Defence branch ----------------------------------------------------------------

func test_plating_stacks_on_defense_tech() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var base: int = Unit.effective_defense(state, unit)
	GameStateFactory.grant_tech(state, 0, Techs.DEFENSE_I)
	GameStateFactory.grant_tech(state, 0, Techs.PLATING)
	assert_int(Unit.effective_defense(state, unit)).is_equal(base + 2)


func test_field_repair_heals_an_idle_damaged_unit() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	unit.current_hp = 2
	state.start_turn(0)
	assert_int(unit.current_hp).override_failure_message("Healed without Field Repair.").is_equal(2)
	GameStateFactory.grant_tech(state, 0, Techs.FIELD_REPAIR)
	var events: Array = state.start_turn(0)
	assert_int(unit.current_hp).is_equal(3)
	assert_bool(events.any(func(e: Variant) -> bool: return e is UnitHealedEvent)).is_true()


func test_field_repair_skips_a_unit_that_moved_or_attacked() -> void:
	var state := _state()
	GameStateFactory.grant_tech(state, 0, Techs.FIELD_REPAIR)
	var mover := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var shooter := _unit(state, 0, UnitTypes.TROOPER, Vector2i(4, 2))
	mover.current_hp = 2
	shooter.current_hp = 2
	mover.tiles_moved_this_turn = 1
	shooter.has_attacked = true
	state.start_turn(0)
	assert_int(mover.current_hp).is_equal(2)
	assert_int(shooter.current_hp).is_equal(2)


func test_field_repair_never_exceeds_max_hp() -> void:
	var state := _state()
	GameStateFactory.grant_tech(state, 0, Techs.FIELD_REPAIR)
	var unit := _unit(state, 0, UnitTypes.TROOPER, Vector2i(2, 2))
	var events: Array = state.start_turn(0)
	assert_int(unit.current_hp).is_equal(UnitTypes.TROOPER.hp)
	assert_bool(events.any(func(e: Variant) -> bool: return e is UnitHealedEvent)).is_false()


func test_field_repair_heals_only_its_owners_units() -> void:
	var state := _state()
	GameStateFactory.grant_tech(state, 0, Techs.FIELD_REPAIR)
	var theirs := _unit(state, 1, UnitTypes.TROOPER, Vector2i(2, 2))
	theirs.current_hp = 2
	state.start_turn(0)
	state.start_turn(1)
	assert_int(theirs.current_hp).is_equal(2)


# --- Economy branch ----------------------------------------------------------------

func test_logistics_takes_one_ap_off_produce_and_build() -> void:
	var state := _state()
	var produce_before: int = BaseProduction.effective_produce_ap_cost(state, 0)
	var build_before: int = BaseProduction.effective_build_ap_cost(state, 0)
	GameStateFactory.grant_tech(state, 0, Techs.LOGISTICS)
	assert_int(BaseProduction.effective_produce_ap_cost(state, 0)).is_equal(maxi(0, produce_before - 1))
	assert_int(BaseProduction.effective_build_ap_cost(state, 0)).is_equal(maxi(0, build_before - 1))


func test_logistics_discount_is_what_produce_actually_charges() -> void:
	# The discount must reach apply_produce, not just the quoted price.
	var state := _state()
	var hq := StructureState.new()
	hq.entity_id = state.next_entity_id
	hq.owner = 0
	hq.position = Vector2i(4, 4)
	hq.type = StructureTypes.HQ
	hq.current_hp = hq.type.hp
	hq.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[hq.entity_id] = hq
	state.grid.place(hq.entity_id, 4, 4)
	state.next_entity_id += 1
	GameStateFactory.grant_tech(state, 0, Techs.LOGISTICS)
	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = hq.entity_id
	a.unit_type = UnitTypes.BUILDER
	a.tile = Vector2i(5, 4)
	var ap_before: int = state.per_player[0].current_ap
	assert_bool(state.apply_action(a).ok).is_true()
	assert_int(ap_before - state.per_player[0].current_ap).is_equal(
		BaseProduction.effective_produce_ap_cost(state, 0))


func test_foundry_takes_a_quarter_off_unit_prices() -> void:
	var state := _state()
	var before: int = Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)
	GameStateFactory.grant_tech(state, 0, Techs.FOUNDRY)
	assert_int(Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)).is_equal(before * 75 / 100)


# --- Folds read the tech's value, not a hardcoded +1 ---------------------------------

func test_folds_sum_the_granted_magnitudes() -> void:
	var state := _state()
	var unit := _unit(state, 0, UnitTypes.SCOUT, Vector2i(2, 2))
	var atk: int = Unit.effective_attack(state, unit)
	var def: int = Unit.effective_defense(state, unit)
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(3, 2))
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(4, 0))
	assert_int(Unit.effective_attack(state, unit)).is_equal(atk + 7)
	assert_int(Unit.effective_defense(state, unit)).is_equal(def + 2)
