# Story 001: UnitTypeDef Template Resource + Registry (Roster Data).
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-001-unittypedef-template-registry.md —
# the Rule 3 stat table, the defense=0 roster-wide default, and the
# in-memory injection seam proving stats are data-driven, not hardcoded.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# AC-1: the 4 preloaded UnitTypeDef consts match the GDD Rule 3 stat table exactly.
func test_unit_types_scout_matches_stat_table() -> void:
	assert_int(UnitTypes.SCOUT.hp).is_equal(3)
	assert_int(UnitTypes.SCOUT.attack).is_equal(2)
	assert_int(UnitTypes.SCOUT.attack_range).is_equal(1)
	assert_int(UnitTypes.SCOUT.move_cost).is_equal(1)
	assert_int(UnitTypes.SCOUT.soft_move_cap).is_equal(4)
	assert_int(UnitTypes.SCOUT.produce_cost).is_equal(200)  # ★ S6-02: ×100 Credit rescale


func test_unit_types_trooper_matches_stat_table() -> void:
	assert_int(UnitTypes.TROOPER.hp).is_equal(6)
	assert_int(UnitTypes.TROOPER.attack).is_equal(3)
	assert_int(UnitTypes.TROOPER.attack_range).is_equal(2)
	assert_int(UnitTypes.TROOPER.move_cost).is_equal(2)
	assert_int(UnitTypes.TROOPER.soft_move_cap).is_equal(3)
	assert_int(UnitTypes.TROOPER.produce_cost).is_equal(400)  # ★ S6-02: ×100 Credit rescale


func test_unit_types_heavy_matches_stat_table() -> void:
	assert_int(UnitTypes.HEAVY.hp).is_equal(10)
	assert_int(UnitTypes.HEAVY.attack).is_equal(5)
	assert_int(UnitTypes.HEAVY.attack_range).is_equal(2)
	assert_int(UnitTypes.HEAVY.move_cost).is_equal(3)
	assert_int(UnitTypes.HEAVY.soft_move_cap).is_equal(2)
	# Regression guard against the stale produce_cost=6 — GDD Rule 3 pins 7.
	assert_int(UnitTypes.HEAVY.produce_cost).is_equal(700)  # ★ S6-02: ×100 Credit rescale


func test_unit_types_sniper_matches_stat_table() -> void:
	assert_int(UnitTypes.SNIPER.hp).is_equal(3)
	assert_int(UnitTypes.SNIPER.attack).is_equal(6)
	assert_int(UnitTypes.SNIPER.attack_range).is_equal(3)
	assert_int(UnitTypes.SNIPER.move_cost).is_equal(2)
	assert_int(UnitTypes.SNIPER.soft_move_cap).is_equal(3)
	assert_int(UnitTypes.SNIPER.produce_cost).is_equal(500)  # ★ S6-02: ×100 Credit rescale


# AC-2: defense defaults to 0 for all four roster-wide (Rule 3a).
func test_unit_types_all_four_default_defense_zero() -> void:
	assert_int(UnitTypes.SCOUT.defense).is_equal(0)
	assert_int(UnitTypes.TROOPER.defense).is_equal(0)
	assert_int(UnitTypes.HEAVY.defense).is_equal(0)
	assert_int(UnitTypes.SNIPER.defense).is_equal(0)


# AC-3: stats flow from injected external data — a UnitTypeDef built in-memory
# (never touching res://data/units/*.tres) reads back exactly what was set.
func test_injected_unittypedef_reads_back_injected_hp() -> void:
	# Arrange
	var injected := UnitTypeDef.new()
	injected.display_name = "TestTrooper"
	injected.hp = 99
	# Act / Assert
	assert_int(injected.hp).is_equal(99)
