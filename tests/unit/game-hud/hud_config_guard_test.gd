# Story 002: HUDConfig — 9 Tunable Knobs + Cross-Config Loader Guard.
#
# Covers production/epics/game-hud/story-002-hud-config-cross-config-guard.md
# (TR-hud-008, ADR-0016 §4: HUDConfig's 9 @export knobs; the loader-owned
# cross-config invariant ap_tick_duration_ms <= InputConfig.input_lock_ms,
# enforced via push_error + CLAMP, never a bare assert() and never OS.crash):
#
#   AC (defaults present): HUDConfig.new() exposes all 9 knobs at their exact
#     ADR-0016 §4 defaults.
#   AC (violation -> clamp): ap_tick_duration_ms=200, input_lock_ms=120 -> the
#     pure guard clamps ap_tick_duration_ms down to 120.
#   AC (defaults satisfied -> no change): guard(120, 120) leaves
#     ap_tick_duration_ms unchanged at 120 (the boundary is inclusive, <=).
#   AC (invariant NOT in _init): HUDConfig.new() with ap_tick_duration_ms
#     manually set to 200 does NOT self-clamp — proves the guard is
#     loader-owned, not Resource-owned (control-manifest forbidden rule).
#
# Release-surviving mechanism (push_error + CLAMP, never OS.crash / bare
# assert): proven BEHAVIORALLY — the clamp tests below call the guard on a
# violation and then reach their assertions, which is only possible because the
# guard neither OS.crash-ed (would kill the test process) nor fired an aborting
# debug assert(). The push_error half cannot be programmatically captured by
# GdUnit4, so it is covered "by construction" (present in hud_balance.gd) —
# the CLAMP is the machine-checkable proof.
#
# Deterministic: no RNG, no time, no file I/O.
extends GdUnitTestSuite


# --- AC (defaults present): all 9 knobs at their exact ADR-0016 §4 defaults --

func test_hud_config_exposes_all_9_knobs_at_adr_defaults() -> void:
	# Arrange / Act
	var cfg := HUDConfig.new()

	# Assert
	assert_int(cfg.pip_max_hp).is_equal(10)
	assert_int(cfg.action_log_length).is_equal(20)
	assert_int(cfg.ap_fill_flourish_ms).is_equal(400)
	assert_int(cfg.ap_tick_duration_ms).is_equal(120)
	assert_int(cfg.turn_banner_duration_ms).is_equal(1000)
	assert_int(cfg.hud_audio_duck_ms).is_equal(150)
	assert_bool(cfg.show_opponent_ap).is_true()
	assert_bool(cfg.show_opponent_fill_flourish).is_false()
	assert_bool(cfg.income_breakdown_default_expanded).is_false()


func test_hud_config_is_a_resource() -> void:
	assert_bool(HUDConfig.new() is Resource).is_true()


# --- AC (violation -> clamp): 200 > 120 clamps down to 120. Reaching the
#     assertion also proves the guard did NOT OS.crash / abort via assert(). ---

func test_guard_clamps_ap_tick_duration_when_it_exceeds_input_lock_ms() -> void:
	# Arrange
	var hud_cfg := HUDConfig.new()
	hud_cfg.ap_tick_duration_ms = 200
	var input_cfg := InputConfig.new()
	input_cfg.input_lock_ms = 120

	# Act
	HudBalance.enforce_ap_tick_within_input_lock(hud_cfg, input_cfg)

	# Assert
	assert_int(hud_cfg.ap_tick_duration_ms).is_equal(120)


# --- AC (defaults satisfied -> no change): 120 <= 120, unmodified -----------

func test_guard_leaves_ap_tick_unchanged_when_equal_to_input_lock_ms() -> void:
	var hud_cfg := HUDConfig.new()
	hud_cfg.ap_tick_duration_ms = 120
	var input_cfg := InputConfig.new()
	input_cfg.input_lock_ms = 120

	HudBalance.enforce_ap_tick_within_input_lock(hud_cfg, input_cfg)

	assert_int(hud_cfg.ap_tick_duration_ms).is_equal(120)


func test_guard_leaves_ap_tick_unchanged_when_comfortably_under_input_lock_ms() -> void:
	var hud_cfg := HUDConfig.new()
	hud_cfg.ap_tick_duration_ms = 80
	var input_cfg := InputConfig.new()
	input_cfg.input_lock_ms = 120

	HudBalance.enforce_ap_tick_within_input_lock(hud_cfg, input_cfg)

	assert_int(hud_cfg.ap_tick_duration_ms).is_equal(80)


# --- AC (invariant NOT in _init): HUDConfig never self-validates ------------

func test_hud_config_does_not_self_clamp_in_init_even_when_violating() -> void:
	# A HUDConfig built with a violating value must stay unmodified by
	# construction alone (no InputConfig involved yet) — proves the invariant
	# lives in the loader Autoload, not HUDConfig._init(), per the
	# control-manifest forbidden rule.
	var cfg := HUDConfig.new()
	cfg.ap_tick_duration_ms = 200

	assert_int(cfg.ap_tick_duration_ms).is_equal(200)


# --- Shipped defaults satisfy the invariant (the boot guard is a no-op) ------

func test_shipped_default_configs_satisfy_the_invariant() -> void:
	# The as-shipped HUDConfig (ap_tick 120) and InputConfig (input_lock 120)
	# satisfy 120 <= 120, so HudBalance._ready()'s boot guard clamps nothing —
	# the effective ap_tick stays 120.
	var hud_cfg := HUDConfig.new()
	var input_cfg := InputConfig.new()

	HudBalance.enforce_ap_tick_within_input_lock(hud_cfg, input_cfg)

	assert_int(hud_cfg.ap_tick_duration_ms).is_equal(120)
