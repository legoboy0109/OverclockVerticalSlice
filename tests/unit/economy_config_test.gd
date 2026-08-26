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
	# ★ S6-01 (2026-08-24): the five outpost-curve constants were DELETED with the
	# Economy Outpost. Income is now base + a finite research-tier bonus, and all
	# Credit quantities are ×100. See design/gdd/ap-economy.md.
	var cfg: EconomyConfig = Balance.economy
	assert_int(cfg.base_income).is_equal(1000)
	assert_int(cfg.econ_tier_bonus).is_equal(500)
	assert_int(cfg.max_economy_tier).is_equal(3)
	assert_int(cfg.econ_tier_costs.size()).is_equal(cfg.max_economy_tier)
	assert_int(cfg.econ_tier_costs[0]).is_equal(1000)

	# ★ The regression that matters: the income ceiling is HARD and finite.
	# An unbounded economy is what the PIVOT verdict diagnosed.
	assert_int(cfg.base_income + cfg.econ_tier_bonus * cfg.max_economy_tier).is_equal(2500)


# --- AP tactical budget knobs (pivot: flat per-turn + capped carryover) ------

func test_config_ap_tactical_budget_knobs_at_pivot_defaults() -> void:
	# Act
	var cfg: EconomyConfig = Balance.economy
	# Assert -- the tactical budget (ap-economy.md Rule 1/2). Max start-of-turn AP
	# is flat_ap_per_turn + ap_carryover_cap = 30 at these values.
	# ⚠ flat_ap_per_turn was 30 until 2026-08-26; set to 20 by user decision (S8-23) as
	# an experiment in tempo pressure. A LITERAL is right here because this suite's whole
	# job is to pin the shipped tuning values -- it is the one place the number is the
	# subject of the assertion rather than an input to it.
	# ⚠ Carryover 15 -> 10 on 2026-08-26 (S8-25). At 15 against the new 20 it was 75% of a
	# turn's budget; 10/20 restores the 50% the 15/30 pairing always had. A correction back
	# to the intended RATIO, not a new lever.
	assert_int(cfg.flat_ap_per_turn).is_equal(20)
	assert_int(cfg.ap_carryover_cap).is_equal(10)


# --- AP logistics surcharges (pivot: the tempo half of the dual-cost gate) ---

func test_config_ap_logistics_surcharge_knobs_at_pivot_defaults() -> void:
	# Act
	var cfg: EconomyConfig = Balance.economy
	# Assert -- the economy-owned AP surcharges read cross-system by B&P/Research
	# (ap-economy.md Rule 3). research_ap_cost is the per-tech override base.
	assert_int(cfg.produce_ap_cost).is_equal(1)
	assert_int(cfg.build_ap_cost).is_equal(2)
	assert_int(cfg.research_ap_cost).is_equal(1)
