# Story S6-01: Economy re-base — research-tiered Credit income.
#
# Replaces the outpost-curve suite this file used to hold. The Economy Outpost was
# DELETED and Credit income is now driven entirely by completed economy research
# tiers (design/gdd/ap-economy.md + research-tech.md, revised 2026-08-24).
#
# WHY the old suite is gone rather than migrated: it asserted a formula
# (base + tier1*min(n,T) + tier2*max(0,n-T) + capped econ-tech term) whose every
# term after `base` no longer exists. There is no `n`. Its worked examples
# (n=2 -> 14, n=6 w/tech -> 26, the double-cap regression at n=6 vs n=7) tested a
# curve that has no subject. Preserved in git history at the previous commit.
#
# WHY the economy moved: production/vertical-slice/REPORT.md returned PIVOT --
# Credits were unbounded (peak 5,724, still climbing linearly at turn 200), so
# building always outscored fighting and no match ever resolved. A finite
# three-tier research tree is a HARD ceiling where the old tiering outpost curve
# was only a soft brake that flattened but never stopped.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _state_with_tier(tier: int) -> GameState:
	var state: GameState = GameStateFactory.make_state(2, 0)
	state.per_player[0].economy_tier = tier
	return state


# --- The curve itself: 1000 / 1500 / 2000 / 2500 ---

func test_credit_income_tier0_returns_base_income_only() -> void:
	assert_int(Credits.credit_income(_state_with_tier(0), 0)).is_equal(1000)


func test_credit_income_tier1_returns_1500() -> void:
	assert_int(Credits.credit_income(_state_with_tier(1), 0)).is_equal(1500)


func test_credit_income_tier2_returns_2000() -> void:
	assert_int(Credits.credit_income(_state_with_tier(2), 0)).is_equal(2000)


func test_credit_income_tier3_returns_2500_the_hard_ceiling() -> void:
	assert_int(Credits.credit_income(_state_with_tier(3), 0)).is_equal(2500)


# --- The ceiling is HARD. This is the PIVOT fix's rate-bound half. ---

func test_credit_income_above_max_tier_still_returns_the_ceiling() -> void:
	# A tier value beyond max_economy_tier must not keep paying. The whole point of
	# re-basing onto research is that the economy STOPS growing.
	assert_int(Credits.credit_income(_state_with_tier(4), 0)).is_equal(2500)
	assert_int(Credits.credit_income(_state_with_tier(99), 0)).is_equal(2500)


func test_credit_income_negative_tier_clamps_to_base() -> void:
	assert_int(Credits.credit_income(_state_with_tier(-1), 0)).is_equal(1000)


# --- Breakdown integrity (the HUD reads this, it must never drift from the total) ---

func test_credit_income_breakdown_sums_to_income_exactly_at_every_tier() -> void:
	for tier: int in [0, 1, 2, 3]:
		var state: GameState = _state_with_tier(tier)
		var b: Dictionary = Credits.credit_income_breakdown(state, 0)
		assert_int(int(b["base"]) + int(b["tiers"])) \
			.is_equal(Credits.credit_income(state, 0))


func test_credit_income_breakdown_has_exactly_two_terms() -> void:
	# base + tiers. The `outpost` and `econ_tech` terms are GONE, not zeroed --
	# a phantom key would let the HUD render a line for a mechanic that no longer exists.
	var b: Dictionary = Credits.credit_income_breakdown(_state_with_tier(2), 0)
	assert_int(b.size()).is_equal(2)
	assert_bool(b.has("base")).is_true()
	assert_bool(b.has("tiers")).is_true()
	assert_bool(b.has("outpost")).is_false()
	assert_bool(b.has("econ_tech")).is_false()


func test_credit_income_breakdown_tier0_reports_zero_tiers_not_a_missing_key() -> void:
	var b: Dictionary = Credits.credit_income_breakdown(_state_with_tier(0), 0)
	assert_int(int(b["tiers"])).is_equal(0)


# --- Per-player isolation ---

func test_credit_income_reads_each_player_tier_independently() -> void:
	var state: GameState = GameStateFactory.make_state(2, 0)
	state.per_player[0].economy_tier = 3
	state.per_player[1].economy_tier = 0
	assert_int(Credits.credit_income(state, 0)).is_equal(2500)
	assert_int(Credits.credit_income(state, 1)).is_equal(1000)


# --- Income no longer depends on the board at all ---

func test_credit_income_is_independent_of_owned_structures() -> void:
	# The defining property of the re-base: building things does NOT raise income.
	# This is the regression that proves the outpost curve is really gone -- if any
	# structure-count term survived anywhere, this test fails.
	var bare: GameState = _state_with_tier(1)
	var built: GameState = _state_with_tier(1)
	for i: int in range(8):
		var st: StructureState = StructureState.new()
		st.entity_id = 900 + i
		st.owner = 0
		st.position = Vector2i(i, 0)
		st.type = StructureTypes.RESEARCH_LAB
		st.build_status = StructureState.BuildStatus.COMPLETED
		built.entities_by_id[st.entity_id] = st
	assert_int(Credits.credit_income(built, 0)).is_equal(Credits.credit_income(bare, 0))


# --- Banking still works on the new curve ---

func test_add_income_banks_the_tiered_amount() -> void:
	var state: GameState = _state_with_tier(2)
	state.per_player[0].current_credits = 0
	Credits.add_income(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(2000)
	Credits.add_income(state, 0)
	assert_int(state.per_player[0].current_credits).is_equal(4000)
