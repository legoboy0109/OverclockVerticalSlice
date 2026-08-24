# Story 001: AIConfig — 15 Tunable Knobs + Cross-Knob Invariant Enforcement.
#
# Covers production/epics/ai-opponent/story-001-ai-config-knobs-invariant.md
# (TR-ai-007: 15 externally-tunable knobs; TR-ai-008: lethal_floor_bonus >
# economy_ceiling_score enforced at load with a release-surviving guard):
#
#   AC (defaults pass): default AIConfig clears the invariant silently.
#   AC-8 (violation fails): economy_horizon=10, economy_decay=0.95,
#     lethal_floor_bonus=3.5 -> ceiling ~3.81 > 3.5, invariant does NOT hold.
#   AC (release-surviving): the production guard is push_error + OS.crash,
#     never a bare assert() (code-level check on ai_balance.gd's source).
#   Edge: economy_horizon=4, economy_decay=0.7 (floor of the safe range) ->
#     invariant holds trivially.
#   15-field presence + GDD default spot-checks (pass_threshold=0.15,
#     lethal_floor_bonus=3.5, economy_horizon=6, economy_decay=0.85,
#     score_tie_epsilon=1e-6, commit_pacing_sec=0.35).
#
# Deterministic: no RNG, no time, no file I/O beyond the one static source
# read for the release-surviving mechanism check.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- Test fixture helpers ----------------------------------------------------

# ★ S6-01 (2026-08-24): re-pointed off the deleted per-outpost income curve onto the
# research-tier model. The ratio is UNCHANGED and so is every expected value below --
# econ_tier_bonus/first_tier_cost = 500/1000 = 0.5, exactly as the old
# outpost_bonus_tier1/build_cost = 2/4 did. The invariant's meaning is identical
# (the AI's lethal floor must exceed the best economic score available); only its
# subject moved from "the first outpost" to "the first economy tier".
func _default_economy() -> EconomyConfig:
	var cfg := EconomyConfig.new()
	cfg.econ_tier_bonus = 500
	cfg.econ_tier_costs = PackedInt32Array([1000, 2000, 3500])
	return cfg


# --- 15-field presence + GDD default spot-checks (AC-1, AC "defaults") -------

func test_ai_config_exposes_all_15_scoring_knobs_plus_pacing_at_gdd_defaults() -> void:
	var cfg := AIConfig.new()

	assert_float(cfg.hp_per_ap).is_equal_approx(1.5, 0.0001)
	assert_float(cfg.kill_denial_rate).is_equal_approx(0.5, 0.0001)
	assert_int(cfg.economy_horizon).is_equal(6)
	assert_int(cfg.tech_value_horizon).is_equal(10)
	assert_float(cfg.economy_decay).is_equal_approx(0.85, 0.0001)
	assert_int(cfg.max_economy_investments_per_turn).is_equal(2)
	assert_float(cfg.lethal_floor_bonus).is_equal_approx(3.5, 0.0001)
	assert_float(cfg.pass_threshold).is_equal_approx(0.15, 0.0001)
	assert_float(cfg.attacks_landed_per_turn_estimate).is_equal_approx(1.5, 0.0001)
	assert_float(cfg.positional_value_per_tile_closed).is_equal_approx(0.16, 0.0001)
	assert_float(cfg.setup_advance_bonus).is_equal_approx(0.4, 0.0001)
	assert_float(cfg.retreat_hp_fraction).is_equal_approx(0.30, 0.0001)
	assert_float(cfg.retreat_value_per_tile_fled).is_equal_approx(0.20, 0.0001)
	assert_int(cfg.hq_siege_value).is_equal(12)
	assert_float(cfg.score_tie_epsilon).is_equal_approx(1e-6, 1e-9)

	# commit_pacing_sec: not one of the 15 GDD scoring knobs, but lives on
	# AIConfig per ADR-0011 §6 — spot-checked separately.
	assert_float(cfg.commit_pacing_sec).is_equal_approx(0.35, 0.0001)


func test_ai_config_extends_resource() -> void:
	var cfg := AIConfig.new()
	assert_bool(cfg is Resource).is_true()


# --- AC (defaults pass): the invariant holds at shipped defaults -------------

func test_lethal_floor_invariant_holds_at_defaults() -> void:
	var cfg := AIConfig.new()  # economy_horizon=6, economy_decay=0.85, lethal_floor_bonus=3.5
	var ceiling: float = AIBalance.economy_ceiling_score(cfg, _default_economy())

	# GDD worked example: ceiling ~= 1.77 at defaults.
	assert_float(ceiling).is_equal_approx(1.7647, 0.001)
	assert_bool(cfg.lethal_floor_bonus > ceiling).is_true()


# --- AC-8 (violation fails loudly): the documented ~3.81 > 3.5 case ----------

func test_lethal_floor_invariant_violation_at_safe_range_maxima() -> void:
	var cfg := AIConfig.new()
	cfg.economy_horizon = 10
	cfg.economy_decay = 0.95
	cfg.lethal_floor_bonus = 3.5
	var ceiling: float = AIBalance.economy_ceiling_score(cfg, _default_economy())

	# GDD worked example: ceiling ~= 3.81 at safe-range maxima.
	assert_float(ceiling).is_equal_approx(3.81, 0.02)
	# The documented violation: the default 3.5 floor no longer clears it.
	assert_bool(cfg.lethal_floor_bonus > ceiling).is_false()


# --- AC (release-surviving): the production guard is not a bare assert() ----

func test_lethal_floor_guard_mechanism_is_push_error_and_os_crash_not_bare_assert() -> void:
	# Code-level/static check on the actual guard mechanism (not a runtime
	# crash, which would kill the test process) — confirms AIBalance's
	# invariant check uses push_error + OS.crash and never a bare assert(),
	# per ADR-0011 §6 Risks ("a bare assert() no-ops in a shipped build,
	# silently defeating TR-ai-008"). Deliberate, narrow exception to "tests
	# must not depend on the filesystem" (test-standards.md): this is a
	# static-analysis assertion on source *form*, not a runtime dependency on
	# external mutable state, mirroring the GDD's own routing of CR-4's
	# no-privileged-reads claim to code-review/lint rather than a black-box
	# test. Only code lines are scanned (doc-comment lines starting with `#`
	# are stripped first) so prose that merely *discusses* `assert()` — as
	# this very file's own doc comments do — cannot produce a false failure.
	var source := FileAccess.get_file_as_string("res://src/gameplay/ai/ai_balance.gd")
	var code_only := ""
	for line in source.split("\n"):
		var stripped: String = (line as String).strip_edges()
		if not stripped.begins_with("#"):
			code_only += line + "\n"

	assert_str(code_only).contains("push_error")
	assert_str(code_only).contains("OS.crash")

	# No bare `assert(` call in any executable line of the guard's source —
	# a release build must not be able to silently no-op this check.
	assert_bool(code_only.contains("assert(")).override_failure_message(
		"AIBalance must not use a bare assert() for the TR-ai-008 invariant guard — it compiles out in release exports."
	).is_false()


# --- Edge: safe-range floor (economy_horizon=4, economy_decay=0.7) ----------

func test_lethal_floor_invariant_holds_trivially_at_safe_range_floor() -> void:
	var cfg := AIConfig.new()
	cfg.economy_horizon = 4
	cfg.economy_decay = 0.7
	# lethal_floor_bonus left at its default 3.5.
	var ceiling: float = AIBalance.economy_ceiling_score(cfg, _default_economy())

	assert_bool(cfg.lethal_floor_bonus > ceiling).is_true()
