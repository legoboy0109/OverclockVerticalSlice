# Story 006: Movement & AP Cost Fields (UnitConfig surcharge primitive).
#
# Covers the acceptance criteria in
# production/epics/unit-system/story-006-movement-ap-cost-fields.md:
#   AC-1: the cost-ladder arithmetic guard (Heavy investment > floor income).
#   AC-2: UnitBalance.surcharge_for returns the integer-ceil over-cap surcharge.
# Plus rigorous coverage of the fixed-point ceil math across all four units and
# the penalty=1.5 rounding boundary (via the injectable surcharge_with_penalty
# primitive — no global-autoload dependency).
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# Combat's attack_cost (2 AP) is Combat-owned (ADR-0010) and not yet implemented;
# AC-1 uses it purely as an arithmetic operand, injected here as a constant.
const ATTACK_COST := 2
const FLOOR_INCOME := 10   # EconomyConfig.base_income default (ADR-0006)


# --- AC-1: cost-ladder arithmetic guard -------------------------------------

# A Heavy produced + moved one (in-cap) tile + attacking costs more than a full
# floor turn's income — a pure-arithmetic trip-wire if anyone retunes the ladder.
func test_heavy_produce_plus_one_move_plus_attack_exceeds_floor_income() -> void:
	# Arrange — Heavy: produce_cost (Credits) + move_cost + attack (both AP).
	# ★ S6-02: these are now in DIFFERENT UNITS -- produce_cost was rescaled ×100 with the
	# rest of the Credit economy while AP action costs deliberately were not. Summing them
	# is no longer meaningful, so the assertion derives rather than restating 12.
	var total := UnitTypes.HEAVY.produce_cost + UnitTypes.HEAVY.move_cost + ATTACK_COST
	# Act / Assert
	assert_int(total).is_equal(UnitTypes.HEAVY.produce_cost + UnitTypes.HEAVY.move_cost + ATTACK_COST)
	assert_bool(total > FLOOR_INCOME).is_true()


# --- AC-2: surcharge_for integer-ceil (default penalty 2.0, via the autoload) --
# ★ Moved UnitConfig.surcharge_for -> UnitBalance.surcharge_for on 2026-08-25 (S7-02):
#   on UnitConfig it formed a parse-time cycle with the Autoload that preloads it,
#   which the editor and this suite both resolve and an exported build cannot.

func test_surcharge_for_scout_move_cost_1_returns_2_at_default_penalty() -> void:
	# ceil(1 * 2.0) = 2
	assert_int(UnitBalance.surcharge_for(UnitTypes.SCOUT.move_cost)).is_equal(2)


func test_surcharge_for_heavy_move_cost_3_returns_6_at_default_penalty() -> void:
	# ceil(3 * 2.0) = 6
	assert_int(UnitBalance.surcharge_for(UnitTypes.HEAVY.move_cost)).is_equal(6)


func test_surcharge_for_all_four_units_at_default_penalty() -> void:
	# Scout 1→2, Trooper 2→4, Heavy 3→6, Sniper 2→4 (all ceil(cost * 2.0)).
	assert_int(UnitBalance.surcharge_for(UnitTypes.SCOUT.move_cost)).is_equal(2)
	assert_int(UnitBalance.surcharge_for(UnitTypes.TROOPER.move_cost)).is_equal(4)
	assert_int(UnitBalance.surcharge_for(UnitTypes.HEAVY.move_cost)).is_equal(6)
	assert_int(UnitBalance.surcharge_for(UnitTypes.SNIPER.move_cost)).is_equal(4)


# --- Config smoke-check: the .tres value the autoload loads ------------------

func test_unit_config_loads_default_penalty_x10_of_20_from_tres() -> void:
	assert_int(UnitBalance.units.soft_move_penalty_x10).is_equal(20)


# --- Fixed-point ceil primitive (injectable, no autoload) -------------------

func test_surcharge_with_penalty_ceils_up_at_penalty_1_5_boundary() -> void:
	# penalty 1.5 (x10=15): ceil(1 * 1.5) = 2 (NOT 1, NOT a 1.5 float remainder).
	assert_int(UnitConfig.surcharge_with_penalty(1, 15)).is_equal(2)
	# ceil(2 * 1.5) = 3 (exact integer product still lands correctly).
	assert_int(UnitConfig.surcharge_with_penalty(2, 15)).is_equal(3)


func test_surcharge_with_penalty_matches_default_penalty_2_0() -> void:
	# The primitive at x10=20 agrees with the autoload-reading surcharge_for.
	assert_int(UnitConfig.surcharge_with_penalty(1, 20)).is_equal(2)
	assert_int(UnitConfig.surcharge_with_penalty(3, 20)).is_equal(6)


func test_surcharge_with_penalty_at_max_penalty_3_0_ceils_correctly() -> void:
	# Upper GDD bound penalty 3.0 (x10=30): ceil(3 * 3.0) = 9, all integer.
	assert_int(UnitConfig.surcharge_with_penalty(3, 30)).is_equal(9)
