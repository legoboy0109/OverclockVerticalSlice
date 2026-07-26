# Story 001: AP Income Formula, EconomyConfig & Balance Autoload.
#
# Covers the acceptance criteria in
# production/epics/ap-economy/story-001-ap-income-econconfig-balance.md against
# AP.income()/AP.ap_income_breakdown(), using GameStateFactory for state setup
# and the BaseProduction/Research test stubs for the two forward-declared
# cross-system calls (ADR-0006). No RNG, no time-dependent asserts, no file I/O;
# each test resets both stubs for isolation.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	BaseProduction.reset()
	Research.reset()


# --- No Economy Tech: worked examples from the GDD Formulas section --------

func test_income_no_tech_n0_returns_10_base_floor() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 0)
	# Act
	var result := AP.income(state, 0)
	# Assert
	assert_int(result).is_equal(10)


func test_income_no_tech_n2_returns_14() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 2)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(14)


func test_income_no_tech_n4_returns_18_at_tier_threshold() -> void:
	# Arrange — n == TIER_THRESHOLD (4), boundary value.
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 4)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(18)


func test_income_no_tech_n5_returns_19_fifth_outpost_adds_tier2_rate() -> void:
	# Arrange — one past TIER_THRESHOLD: the 5th outpost adds +1 (tier2), not +2.
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 5)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(19)


func test_income_no_tech_n8_returns_22() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 8)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(22)


func test_income_no_tech_n12_returns_26() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 12)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(26)


# --- Economy Tech held: worked examples, tech term added verbatim ----------

func test_income_econ_tech_held_n2_returns_16() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 2)
	Research.set_economy_tech_income_bonus(0, 2)  # already-capped: 1 * min(2,6)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(16)


func test_income_econ_tech_held_n4_returns_22() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 4)
	Research.set_economy_tech_income_bonus(0, 4)  # 1 * min(4,6)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(22)


func test_income_econ_tech_held_n6_returns_26_at_econ_tech_tier_threshold() -> void:
	# Arrange — n == ECONOMY_TECH_TIER_THRESHOLD (6), boundary value.
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 6)
	Research.set_economy_tech_income_bonus(0, 6)  # 1 * min(6,6)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(26)


# Regression guard for the 2026-07-24 /architecture-review C3 bug: the tech
# term must stay capped at the ECONOMY_TECH_TIER_THRESHOLD value (6) past the
# threshold, proving AP adds it verbatim and never re-applies min(n, threshold)
# a second time (which would square the tier factor: 36 instead of 6 at n=6).
func test_income_econ_tech_held_n6_vs_n7_cap_reengages_diminishing_returns() -> void:
	# Arrange — n=6 (at cap) vs n=7 (one past cap): both stub the SAME
	# already-capped econ_tech term (6), per Research stub's design contract.
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true

	BaseProduction.set_completed_outpost_count(0, 6)
	Research.set_economy_tech_income_bonus(0, 6)
	var income_at_6 := AP.income(state, 0)

	BaseProduction.set_completed_outpost_count(0, 7)
	Research.set_economy_tech_income_bonus(0, 6)  # still capped at 6, not 7
	var income_at_7 := AP.income(state, 0)

	# Assert — 26 vs 27 (not 36 vs 6, the double-cap regression shape).
	assert_int(income_at_6).is_equal(26)
	assert_int(income_at_7).is_equal(27)


func test_income_econ_tech_held_n8_returns_28() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 8)
	Research.set_economy_tech_income_bonus(0, 6)  # capped at threshold
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(28)


func test_income_econ_tech_held_n12_returns_32() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 12)
	Research.set_economy_tech_income_bonus(0, 6)  # capped at threshold
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(32)


# --- AP is flag-agnostic: it adds the Research term verbatim, no own gating --

func test_income_flag_true_but_research_term_zero_adds_no_fabricated_bonus() -> void:
	# AP.income() never reads has_economy_tech itself — per ADR-0006 the flag
	# gating lives entirely inside Research.economy_tech_income_bonus(). This
	# pins AP's flag-agnostic, purely-additive behavior: even with the flag set
	# TRUE, if Research returns a 0 term (e.g. just-researched, no outposts yet),
	# AP adds exactly 0 and never fabricates a tech bonus of its own. (The real
	# AC-5 "flag must not default true" regression is a Research-layer concern —
	# see story-001 Completion Notes.)
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 8)
	Research.set_economy_tech_income_bonus(0, 0)  # flag TRUE, but term is 0
	# Act / Assert — base 10 + outpost 12 + econ_tech 0 = 22, no fabricated bonus.
	assert_int(AP.income(state, 0)).is_equal(22)


# --- Negative-count defense -------------------------------------------------

func test_income_negative_outpost_count_clamps_to_zero_returns_base_income() -> void:
	# Arrange — completed_outpost_count returning a negative value simulates a
	# caller bug; AP.income() must clamp n to 0 via max(0, n), never go below
	# base_income.
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, -3)
	# Act / Assert
	assert_int(AP.income(state, 0)).is_equal(10)


# --- Per-player indexing ----------------------------------------------------

func test_income_reads_correct_player_index_for_two_players_independently() -> void:
	# Guards against a parameter-threading / hardcoded-index bug: income(state,
	# player) must resolve the passed player's own outpost count, not player 0's.
	# Two players with different counts must yield independent incomes.
	var state := GameStateFactory.make_state(2, 0)
	BaseProduction.set_completed_outpost_count(0, 2)  # player 0 -> 14
	BaseProduction.set_completed_outpost_count(1, 8)  # player 1 -> 22
	# Act / Assert — each player's income reflects only their own count.
	assert_int(AP.income(state, 0)).is_equal(14)
	assert_int(AP.income(state, 1)).is_equal(22)


# --- Breakdown/total consistency -------------------------------------------

func test_ap_income_breakdown_sums_to_income_exactly() -> void:
	# Arrange
	var state := GameStateFactory.make_state()
	state.per_player[0].has_economy_tech = true
	BaseProduction.set_completed_outpost_count(0, 5)
	Research.set_economy_tech_income_bonus(0, 5)
	# Act
	var breakdown := AP.ap_income_breakdown(state, 0)
	var total := AP.income(state, 0)
	# Assert — the breakdown decomposes the exact same total, term-for-term.
	assert_int(breakdown["base"]).is_equal(10)
	assert_int(breakdown["outpost"]).is_equal(9)  # tier1(2*4) + tier2(1*1)
	assert_int(breakdown["econ_tech"]).is_equal(5)
	assert_int(breakdown["base"] + breakdown["outpost"] + breakdown["econ_tech"]).is_equal(total)
	assert_int(total).is_equal(24)


# --- VS Neutral default: exactly three terms, no fourth (decision A) -------

# BASE_INCOME_FLOOR / faction delta fold: ADR-0006 Risks explicitly defers this
# to the Alpha faction-asymmetry prototype (ADR-0012) — not implemented in
# this story. See story-001's Completion Notes.
func test_income_has_exactly_three_terms_no_fourth_term_under_neutral_default() -> void:
	# Arrange — VS Neutral default: no faction assigned (per_player[0].faction
	# stays null, the Neutral-equivalent no-op state), no fold code exists in
	# AP at all under decision A. The breakdown must contain exactly the three
	# ADR-0006 terms — no fourth key, no hidden fold contribution.
	var state := GameStateFactory.make_state()
	BaseProduction.set_completed_outpost_count(0, 4)
	# Act
	var breakdown := AP.ap_income_breakdown(state, 0)
	# Assert — exactly 3 keys, and the shipped numbers are unchanged (18 total).
	assert_int(breakdown.size()).is_equal(3)
	assert_bool(breakdown.has("base")).is_true()
	assert_bool(breakdown.has("outpost")).is_true()
	assert_bool(breakdown.has("econ_tech")).is_true()
	assert_int(breakdown["base"] + breakdown["outpost"] + breakdown["econ_tech"]).is_equal(18)
	assert_int(AP.income(state, 0)).is_equal(18)
