# Story 001: Damage Formula, Structure Cover-Immunity & Damage Preview.
#
# Covers every acceptance criterion in
# production/epics/combat-resolution/story-001-damage-formula-cover-immunity.md:
#   AC-1: base formula, no mitigation.
#   AC-2: min-damage floor (mitigation >= attack clamps to MIN_DAMAGE, never <=0).
#   AC-3: cover reduces unit damage (Cover vs Plain).
#   AC-4: cover + defense stack additively for a unit defender.
#   AC-5: live research fold — injected effective_attack fixture, not base.
#   AC-6: structure cover-immunity — identical result on Cover vs Plain.
#   AC-7: attacker's own Cover tile has no effect on damage it deals.
#   AC-8: preview_damage() is a pure pass-through, exactly == damage().
#
# Fixtures use UnitTypes.HEAVY/SCOUT/TROOPER/SNIPER (real roster stats) for the
# base-formula ACs, and in-memory UnitTypeDef.new() instances (mirroring
# move_action_test.gd's _make_type pattern) wherever a specific defense value
# not present on the VS roster is needed (e.g. a defense-2 unit defender).
# effective_attack fixtures are injected via Research.set_attack_tech_bonus()
# (tests/helpers/stubs/research_stub.gd), never re-derived from base + bonus.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


func before_test() -> void:
	Research.reset() # clears any injected tech bonus (isolation rule)


# --- Fixture builders --------------------------------------------------------

# Blank all-Plain grid, with an optional list of Cover tiles painted in.
func _make_grid(cover_tiles: Array[Vector2i] = []) -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	for tile: Vector2i in cover_tiles:
		grid.terrain[grid.index(tile.x, tile.y)] = GridState.Terrain.COVER
	return grid


func _make_state(cover_tiles: Array[Vector2i] = []) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid(cover_tiles)
	return state


# In-memory UnitTypeDef with an explicit attack/defense, for fixtures the VS
# roster doesn't cover (e.g. a defense-2 unit defender).
func _make_unit_type(attack: int, defense: int) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = "TestType"
	type.hp = 10
	type.attack = attack
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 1
	type.produce_cost = 1
	type.defense = defense
	return type


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


# A defense-2 HQ-style structure defender, per the story's stub extension.
func _make_structure(entity_id: int, owner: int, defense: int, pos: Vector2i) -> StructureState:
	var structure := StructureState.new()
	structure.entity_id = entity_id
	structure.owner = owner
	structure.position = pos
	structure.type.defense = defense
	return structure


# --- AC-1: base formula, no mitigation ---------------------------------------

func test_heavy_vs_defense_zero_sniper_on_plain_deals_full_attack() -> void:
	# Arrange
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var sniper := _make_unit(2, 1, UnitTypes.SNIPER, Vector2i(1, 0))
	# Act / Assert
	assert_int(Combat.damage(state, heavy, sniper)).is_equal(5)


func test_scout_vs_trooper_no_cover_no_defense_deals_full_attack() -> void:
	# Arrange
	var state := _make_state()
	var scout := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	var trooper := _make_unit(2, 1, UnitTypes.TROOPER, Vector2i(1, 0))
	# Act / Assert
	assert_int(Combat.damage(state, scout, trooper)).is_equal(2)


# --- AC-2: min-damage floor ---------------------------------------------------

func test_mitigation_exceeding_attack_clamps_to_min_damage_floor() -> void:
	# Arrange — Scout atk 2 vs a defense-2 unit defender on Cover (cover_dr 1):
	# 2 - 1 - 2 = -1 before the floor -> clamps to 1.
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])
	var scout := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 2)
	var defender := _make_unit(2, 1, defender_type, cover_tile)
	# Act / Assert
	assert_int(Combat.damage(state, scout, defender)).is_equal(1)


func test_mitigation_exactly_equal_to_attack_clamps_to_min_damage_floor() -> void:
	# Arrange — atk 3 vs a defense-3 unit defender, no cover: 3 - 0 - 3 = 0 -> clamps to 1.
	var state := _make_state()
	var attacker_type := _make_unit_type(3, 0)
	var attacker := _make_unit(1, 0, attacker_type, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 3)
	var defender := _make_unit(2, 1, defender_type, Vector2i(1, 0))
	# Act / Assert
	assert_int(Combat.damage(state, attacker, defender)).is_equal(1)


func test_mitigation_far_exceeding_attack_still_clamps_to_min_damage_floor() -> void:
	# Arrange — atk 2 vs a defense-20 unit defender on Cover: deeply negative -> clamps to 1.
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])
	var scout := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 20)
	var defender := _make_unit(2, 1, defender_type, cover_tile)
	# Act / Assert
	assert_int(Combat.damage(state, scout, defender)).is_equal(1)


# --- AC-3: cover reduces unit damage (Cover vs Plain) ------------------------

func test_trooper_vs_defense_zero_unit_on_cover_deals_reduced_damage() -> void:
	# Arrange
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 0)
	var defender := _make_unit(2, 1, defender_type, cover_tile)
	# Act / Assert
	assert_int(Combat.damage(state, trooper, defender)).is_equal(2)


func test_trooper_vs_defense_zero_unit_on_plain_deals_full_damage() -> void:
	# Arrange
	var plain_tile := Vector2i(1, 0)
	var state := _make_state() # no cover tiles
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 0)
	var defender := _make_unit(2, 1, defender_type, plain_tile)
	# Act / Assert
	assert_int(Combat.damage(state, trooper, defender)).is_equal(3)


# --- AC-4: cover + defense stack additively for a unit defender --------------

func test_defense_alone_reduces_unit_damage_additively() -> void:
	# Arrange — atk 5 vs a defense-2 unit defender, no cover: 5 - 0 - 2 = 3.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 2)
	var defender := _make_unit(2, 1, defender_type, Vector2i(1, 0))
	# Act / Assert
	assert_int(Combat.damage(state, heavy, defender)).is_equal(3)


func test_cover_and_defense_stack_additively_not_max_or_min() -> void:
	# Arrange — Sniper atk 6 vs a defense-2 unit defender on Cover: 6 - 1 - 2 = 3
	# (proves additive stacking, not max/min of the two terms).
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 2)
	var defender := _make_unit(2, 1, defender_type, cover_tile)
	# Act / Assert
	assert_int(Combat.damage(state, sniper, defender)).is_equal(3)


# --- AC-5: live research fold — injected effective_attack, not base ---------

func test_researched_trooper_effective_attack_fixture_used_not_base() -> void:
	# Arrange — a researched Trooper's effective_attack fixture is injected as
	# 4 (not the base 3) via Research.set_attack_tech_bonus(); damage must
	# reflect 4.
	Research.set_attack_tech_bonus(1)
	var state := _make_state()
	var trooper := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(0, 0))
	state.per_player[0].has_attack_tech = true
	var defender_type := _make_unit_type(0, 0)
	var defender := _make_unit(2, 1, defender_type, Vector2i(1, 0))
	# Act / Assert — effective_attack = base 3 + injected 1 = 4, never
	# re-derived in this test.
	assert_int(Unit.effective_attack(state, trooper)).is_equal(4)
	assert_int(Combat.damage(state, trooper, defender)).is_equal(4)


# --- AC-6: structure cover-immunity -------------------------------------------

func test_defense_two_structure_on_cover_identical_to_plain() -> void:
	# Arrange — a defense-2 structure (HQ fixture) attacked by atk 5:
	# max(1, 5-0-2) = 3, identical whether the structure sits on Cover or
	# Plain (cover contributes 0 for a structure defender).
	var cover_tile := Vector2i(1, 0)
	var state_cover := _make_state([cover_tile])
	var heavy_cover := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var hq_on_cover := _make_structure(2, 1, 2, cover_tile)

	var plain_tile := Vector2i(1, 0)
	var state_plain := _make_state()
	var heavy_plain := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var hq_on_plain := _make_structure(2, 1, 2, plain_tile)

	# Act / Assert
	assert_int(Combat.damage(state_cover, heavy_cover, hq_on_cover)).is_equal(3)
	assert_int(Combat.damage(state_plain, heavy_plain, hq_on_plain)).is_equal(3)


func test_defense_two_structure_cover_immunity_floor_and_mid_attack_cases() -> void:
	# Arrange
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])

	# Low-attack case: atk 2 -> max(1, 2-0-2) = 1 (floor).
	var low_attacker_off_cover := _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(0, 0))
	var hq_low := _make_structure(2, 1, 2, cover_tile)

	# Distinguishing mid-attack case: atk 4 -> max(1, 4-0-2) = 2 on Cover,
	# never max(1, 4-1-2) = 1 -- proves the structure never reaches 3 mitigation.
	var mid_attacker_type := _make_unit_type(4, 0)
	var mid_attacker := _make_unit(3, 0, mid_attacker_type, Vector2i(0, 0))
	var hq_mid := _make_structure(4, 1, 2, cover_tile)

	# Same mid-attack case on Plain must be identical.
	var state_plain := _make_state()
	var hq_mid_plain := _make_structure(5, 1, 2, Vector2i(1, 0))

	# Act / Assert
	assert_int(Combat.damage(state, low_attacker_off_cover, hq_low)).is_equal(1)
	assert_int(Combat.damage(state, mid_attacker, hq_mid)).is_equal(2)
	assert_int(Combat.damage(state_plain, mid_attacker, hq_mid_plain)).is_equal(2)


# --- AC-7: attacker's own Cover tile has no effect on damage it deals --------

func test_attacker_standing_on_cover_deals_same_damage_as_off_cover() -> void:
	# Arrange
	var attacker_cover_tile := Vector2i(0, 0)
	var state := _make_state([attacker_cover_tile])
	var defender_type := _make_unit_type(0, 0)

	var attacker_on_cover := _make_unit(1, 0, UnitTypes.TROOPER, attacker_cover_tile)
	var defender_on_plain := _make_unit(2, 1, defender_type, Vector2i(3, 3))

	var state_plain := _make_state()
	var attacker_off_cover := _make_unit(1, 0, UnitTypes.TROOPER, Vector2i(5, 5))
	var defender_on_plain_2 := _make_unit(2, 1, defender_type, Vector2i(3, 3))

	# Act
	var damage_with_attacker_on_cover := Combat.damage(state, attacker_on_cover, defender_on_plain)
	var damage_plain_vs_plain := Combat.damage(state_plain, attacker_off_cover, defender_on_plain_2)

	# Assert
	assert_int(damage_with_attacker_on_cover).is_equal(damage_plain_vs_plain)
	assert_int(damage_with_attacker_on_cover).is_equal(3) # Trooper atk 3, no mitigation


# --- AC-8: preview_damage() is a pure pass-through, exactly == damage() -----

func test_preview_damage_equals_committed_damage_for_unit_and_structure_defenders() -> void:
	# Arrange
	var cover_tile := Vector2i(1, 0)
	var state := _make_state([cover_tile])
	var sniper := _make_unit(1, 0, UnitTypes.SNIPER, Vector2i(0, 0))
	var defender_type := _make_unit_type(0, 2)
	var unit_defender := _make_unit(2, 1, defender_type, cover_tile)
	var hq := _make_structure(3, 1, 2, cover_tile)
	var heavy := _make_unit(4, 0, UnitTypes.HEAVY, Vector2i(0, 0))

	# Act / Assert
	assert_int(Combat.preview_damage(state, sniper, unit_defender)).is_equal(
		Combat.damage(state, sniper, unit_defender)
	)
	assert_int(Combat.preview_damage(state, heavy, hq)).is_equal(
		Combat.damage(state, heavy, hq)
	)


func test_preview_damage_is_pure_repeated_calls_return_identical_result() -> void:
	# Arrange
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(0, 0))
	var sniper := _make_unit(2, 1, UnitTypes.SNIPER, Vector2i(1, 0))
	# Act
	var first_call := Combat.preview_damage(state, heavy, sniper)
	var second_call := Combat.preview_damage(state, heavy, sniper)
	# Assert
	assert_int(first_call).is_equal(second_call)
	assert_int(first_call).is_equal(5)
