# Phase 3 (AP<->Credits economy pivot): EconomyConfig extended 5 -> 10 fields.
#
# Config smoke + knob-lock test for ADR-0006's EconomyConfig, loaded via the
# Balance autoload (res://data/balance/economy_config.tres). Verifies the
# resource loads without error and every field resolves to its ADR-0006 default
# -- the five original Credit-income-curve knobs and the five pivot knobs (AP
# tactical budget + logistics surcharges). Locks the playtest-sensitive pivot
# values so a silent default change is caught (they are called out in the GDD as
# the most tuning-sensitive numbers in the pivot). No RNG, no I/O beyond the boot
# preload; reads the shared read-only Balance.economy.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Config loads via the Balance autoload (ADR-0006 config-load criterion) --

func test_config_balance_economy_loads_as_economy_config() -> void:
	# Act -- the autoload preloads res://data/balance/economy_config.tres at boot.
	var cfg: EconomyConfig = Balance.economy
	# Assert -- loaded, non-null, and the right resource type.
	assert_object(cfg).is_not_null()
	assert_bool(cfg is EconomyConfig).is_true()


# --- Credit-income curve knobs (the original five; re-denominated to Credits) -

func test_config_credit_income_curve_knobs_at_adr0006_defaults() -> void:
	# Act
	var cfg: EconomyConfig = Balance.economy
	# Assert -- the five income-curve constants (ap-economy.md Formulas table).
	assert_int(cfg.base_income).is_equal(10)
	assert_int(cfg.outpost_bonus_tier1).is_equal(2)
	assert_int(cfg.outpost_bonus_tier2).is_equal(1)
	assert_int(cfg.tier_threshold).is_equal(4)
	assert_int(cfg.economy_tech_tier_threshold).is_equal(6)


# --- AP tactical budget knobs (pivot: flat per-turn + capped carryover) ------

func test_config_ap_tactical_budget_knobs_at_pivot_defaults() -> void:
	# Act
	var cfg: EconomyConfig = Balance.economy
	# Assert -- the tactical budget (ap-economy.md Rule 1/2). Max start-of-turn AP
	# is flat_ap_per_turn + ap_carryover_cap = 15 at these defaults.
	assert_int(cfg.flat_ap_per_turn).is_equal(10)
	assert_int(cfg.ap_carryover_cap).is_equal(5)


# --- AP logistics surcharges (pivot: the tempo half of the dual-cost gate) ---

func test_config_ap_logistics_surcharge_knobs_at_pivot_defaults() -> void:
	# Act
	var cfg: EconomyConfig = Balance.economy
	# Assert -- the economy-owned AP surcharges read cross-system by B&P/Research
	# (ap-economy.md Rule 3). research_ap_cost is the per-tech override base.
	assert_int(cfg.produce_ap_cost).is_equal(1)
	assert_int(cfg.build_ap_cost).is_equal(2)
	assert_int(cfg.research_ap_cost).is_equal(1)
