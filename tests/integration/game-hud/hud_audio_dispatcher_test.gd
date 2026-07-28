# Story 008: HudAudioDispatcher — single-owner play() + total priority order + ducking.
#
# Covers production/epics/game-hud/story-008-hud-audio-dispatcher.md
# (TR-hud-021, ADR-0016 §7):
#
#   AC-20: a committed action sounds the AP-tick exactly once (single chokepoint —
#          the widgets stay audio-silent); a start-of-turn income fill sounds the
#          fill exactly once.
#   AC-23: 2+ completion cues in one frame dedupe to a single played completion.
#   priority: collisions resolve GameOver > stinger > completion > AP-fill.
#   duck:     a lower-priority cue is ducked (attenuated, still audible) except
#             GameOver, which hard-cuts — asserted via two AudioStreamPlayers at
#             different volume levels.
#   commit-binding: audio reacts ONLY to action_applied, never a value-change.
#
# Two kinds of check:
#   * resolve_plan(...) — the pure priority/dedup/cut heart, asserted directly
#     (no node needed);
#   * the live dispatcher — a Node that add_child()s (so _ready() subscribes to
#     action_applied via the reader broker and builds its two channels), driven
#     by emitting action_applied like the ApCounterWidget suite.
# Deterministic: no RNG, no wall-clock — the duck-restore timer is never awaited;
# volumes/counts are asserted immediately after the triggering commit.
extends GdUnitTestSuite

const Cue = HudAudioDispatcher.Cue


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_dispatcher(reader: GameStateReader, config: HUDConfig = null) -> HudAudioDispatcher:
	var d: HudAudioDispatcher = auto_free(HudAudioDispatcher.new())
	d.bind(reader)
	d.configure(config if config != null else HUDConfig.new())
	add_child(d) # _ready(): subscribe + build the two channels.
	return d


func _commit(state: GameState, events: Array = []) -> void:
	# Emit a successful commit exactly as GameState.apply_action does (line 578).
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))


# ==============================================================================
# resolve_plan — the pure priority / dedup / cut heart (no node required).
# ==============================================================================

func test_resolve_plan_orders_by_priority_and_ducks_the_rest() -> void:
	# Requested out of order; the highest priority is primary, the rest duck in
	# priority order, nothing is suppressed (no GameOver).
	var plan := HudAudioDispatcher.resolve_plan([Cue.AP_FILL, Cue.TURN_STINGER, Cue.COMPLETION])

	assert_int(plan["primary"]).is_equal(Cue.TURN_STINGER)
	assert_array(plan["ducked"]).is_equal([Cue.COMPLETION, Cue.AP_FILL])
	assert_array(plan["suppressed"]).is_empty()


func test_resolve_plan_gameover_hard_cuts_every_other_cue() -> void:
	var plan := HudAudioDispatcher.resolve_plan([Cue.AP_TICK, Cue.TURN_STINGER, Cue.GAME_OVER, Cue.COMPLETION])

	assert_int(plan["primary"]).is_equal(Cue.GAME_OVER)
	assert_array(plan["ducked"]).is_empty() # GameOver ducks nothing — it cuts.
	assert_array(plan["suppressed"]).is_equal([Cue.TURN_STINGER, Cue.COMPLETION, Cue.AP_TICK])


func test_resolve_plan_dedupes_duplicate_completions() -> void:
	# AC-23 at the resolution layer: many COMPLETION requests collapse to one.
	var plan := HudAudioDispatcher.resolve_plan([Cue.COMPLETION, Cue.COMPLETION, Cue.COMPLETION, Cue.AP_TICK])

	assert_int(plan["primary"]).is_equal(Cue.COMPLETION)
	assert_array(plan["ducked"]).is_equal([Cue.AP_TICK]) # one COMPLETION only.


func test_resolve_plan_empty_request_plays_nothing() -> void:
	var plan := HudAudioDispatcher.resolve_plan([])

	assert_int(plan["primary"]).is_equal(-1)
	assert_array(plan["ducked"]).is_empty()
	assert_array(plan["suppressed"]).is_empty()


# ==============================================================================
# AC-20: an ordinary commit sounds the AP-tick exactly once (single chokepoint).
# ==============================================================================

func test_ordinary_commit_sounds_ap_tick_exactly_once() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	_commit(state) # a same-turn commit — no transition, no events.
	await get_tree().process_frame

	assert_int(d.play_count(Cue.AP_TICK)).is_equal(1)
	# Nothing else sounds on a plain spend.
	assert_int(d.play_count(Cue.TURN_STINGER)).is_equal(0)
	assert_int(d.play_count(Cue.AP_FILL)).is_equal(0)
	assert_int(d.play_count(Cue.COMPLETION)).is_equal(0)
	assert_int(d.play_count(Cue.GAME_OVER)).is_equal(0)


# ==============================================================================
# AC-20: a start-of-turn transition sounds the fill AND stinger exactly once
# (and the ordinary AP-tick does NOT fire on a turn boundary).
# ==============================================================================

func test_turn_transition_sounds_fill_and_stinger_once_not_tick() -> void:
	var state := _make_state(0) # baseline: player 0 active.
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	state.active_player = 1 # a real turn boundary (start_turn folded in).
	_commit(state)
	await get_tree().process_frame

	assert_int(d.play_count(Cue.TURN_STINGER)).is_equal(1)
	assert_int(d.play_count(Cue.AP_FILL)).is_equal(1)
	assert_int(d.play_count(Cue.AP_TICK)).is_equal(0) # no per-commit tick on a boundary.


# ==============================================================================
# AC-23: 2+ completion cues in one commit dedupe to a single played completion.
# ==============================================================================

func test_simultaneous_completions_dedupe_to_one_played_cue() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	# Two completions ride the same commit (a structure and a research finish).
	var events: Array = [StructureCompletedEvent.new(), TechCompletedEvent.new()]
	_commit(state, events) # same-turn: COMPLETION is the primary, plays once.
	await get_tree().process_frame

	assert_int(d.play_count(Cue.COMPLETION)).is_equal(1) # 2 events → 1 cue → 1 play.


# ==============================================================================
# Priority — GameOver hard-preempts a coinciding turn stinger (cut, not ducked).
# ==============================================================================

func test_gameover_hard_preempts_coinciding_stinger() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	# A game-ending transition: the match ends AND a turn boundary is crossed.
	state.match_status = GameState.MatchStatus.GAME_OVER
	state.active_player = 1
	_commit(state, [GameOverEvent.new()])
	await get_tree().process_frame

	assert_int(d.play_count(Cue.GAME_OVER)).is_equal(1)
	assert_int(d.play_count(Cue.TURN_STINGER)).is_equal(0) # cut, not ducked.
	assert_int(d.play_count(Cue.AP_FILL)).is_equal(0)
	# The low channel carries no lingering cue under the fanfare.
	assert_int(d.last_plan()["primary"]).is_equal(Cue.GAME_OVER)
	assert_array(d.last_plan()["suppressed"]).contains([Cue.TURN_STINGER])


# ==============================================================================
# Duck — a lower cue is attenuated (not cut): two channels, different volumes.
# ==============================================================================

func test_stinger_full_fill_ducked_across_two_channels() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	state.active_player = 1 # transition → stinger (high) + fill (low, ducked).
	_commit(state)
	await get_tree().process_frame

	# ≥2 AudioStreamPlayers, both present, at DIFFERENT volumes simultaneously.
	assert_object(d.channel_high()).is_not_null()
	assert_object(d.channel_low()).is_not_null()
	assert_float(d.channel_high().volume_db).is_equal(0.0)                      # primary at full.
	assert_float(d.channel_low().volume_db).is_equal(HudAudioDispatcher.DUCK_VOLUME_DB) # ducked.
	assert_bool(d.channel_high().volume_db != d.channel_low().volume_db).is_true()
	# Both cues sounded (the fill is ducked, not cut).
	assert_int(d.play_count(Cue.TURN_STINGER)).is_equal(1)
	assert_int(d.play_count(Cue.AP_FILL)).is_equal(1)


# ==============================================================================
# Two-channel model — a turn boundary that ALSO completes a structure subsumes
# the AP-fill under the completion on the shared LOW channel (documented, §7).
# ==============================================================================

func test_turn_boundary_with_completion_subsumes_fill_on_low_channel() -> void:
	# ADR-0016 §7's two-channel model: a start-of-turn commit that also completes
	# a structure raises stinger (HIGH) + fill + completion (both LOW). The LOW
	# channel sounds only its highest-priority cue — COMPLETION (rank 2) over
	# AP_FILL (rank 3) — so the fill arpeggio is intentionally SUBSUMED that frame,
	# never double-played on one physical channel. Locked here so the silent fill
	# is never mistaken for a regression (independent review, 2026-07-28).
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	state.active_player = 1                          # turn boundary ...
	_commit(state, [StructureCompletedEvent.new()])  # ... with a same-commit completion.
	await get_tree().process_frame

	assert_int(d.play_count(Cue.TURN_STINGER)).is_equal(1) # HIGH channel, full.
	assert_int(d.play_count(Cue.COMPLETION)).is_equal(1)   # LOW channel, ducked.
	assert_int(d.play_count(Cue.AP_FILL)).is_equal(0)      # subsumed by COMPLETION on LOW.
	# resolve_plan still lists AP_FILL as ducked — subsumption is a render-time
	# two-channel consequence, not a change to the resolution order.
	assert_array(d.last_plan()["ducked"]).contains([Cue.COMPLETION, Cue.AP_FILL])


# ==============================================================================
# Duck is temporary — the ducked channel restores to full after the duck window.
# ==============================================================================

func test_ducked_channel_restores_to_full_after_duck_window() -> void:
	# After HUDConfig.hud_audio_duck_ms the ducked LOW channel returns to full
	# volume. Driven with a tiny window for a bounded, deterministic await
	# (mirrors commit_dispatch_lock_test.gd's small-timer pattern) — the assertion
	# is on the RESTORED value, not on any wall-clock duration.
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var cfg := HUDConfig.new()
	cfg.hud_audio_duck_ms = 20 # tiny, for a fast bounded wait.
	var d := _make_dispatcher(reader, cfg)

	state.active_player = 1 # transition → fill ducked on the LOW channel.
	_commit(state)
	await get_tree().process_frame
	assert_float(d.channel_low().volume_db).is_equal(HudAudioDispatcher.DUCK_VOLUME_DB)

	# Wait past the duck window; the LOW channel restores itself to full.
	await get_tree().create_timer(cfg.hud_audio_duck_ms / 1000.0 + 0.05).timeout
	assert_float(d.channel_low().volume_db).is_equal(0.0)


# ==============================================================================
# Commit-binding — audio reacts ONLY to action_applied, never a value-change.
# ==============================================================================

func test_audio_binds_to_commit_signal_not_a_value_change() -> void:
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var d := _make_dispatcher(reader)

	# A bare AP value-change with NO commit emitted must not sound anything —
	# audio is bound to the commit signal, not ap_changed (ADR-0016 §7).
	state.per_player[0].current_ap = 3
	await get_tree().process_frame
	assert_int(d.play_count(Cue.AP_TICK)).is_equal(0)

	# The commit itself is what sounds the tick.
	_commit(state)
	await get_tree().process_frame
	assert_int(d.play_count(Cue.AP_TICK)).is_equal(1)


# ==============================================================================
# Single chokepoint (structural) — the dispatcher is the SOLE HUD play() owner.
# ==============================================================================

func test_dispatcher_is_the_sole_hud_play_owner() -> void:
	# ADR-0016 §7 / control-manifest Forbidden rule: no HUD widget plays its own
	# sound — HudAudioDispatcher is the single play() chokepoint (AC-20's "exactly
	# once across the HUD"). Scan every HUD script EXCEPT the dispatcher and assert
	# none owns an AudioStreamPlayer or calls .play(). Full-comment lines are
	# stripped first so a doc mention could never trip the check (the CAI
	# audio-ownership lint precedent, commit_dispatch_lock_test.gd).
	#
	# Trade-off (accepted, intentional strictness): the ".play(" check is a broad
	# substring — a future widget calling a *visual* AnimationPlayer/Tween .play()
	# would also fail this. That is by design: any .play() surfacing in a HUD
	# widget is worth a human look to confirm it is not audio. If a legitimate
	# non-audio .play() lands, allowlist that file here; narrow the check to
	# AudioStreamPlayer ownership only if the breadth ever becomes noisy.
	var dir := "res://src/ui/game_hud/"
	var files := DirAccess.get_files_at(dir)
	assert_int(files.size()).is_greater(0) # guard: the scan actually found scripts.
	var scanned := 0
	for file: String in files:
		if not file.ends_with(".gd") or file == "hud_audio_dispatcher.gd":
			continue
		scanned += 1
		var source := FileAccess.get_file_as_string(dir + file)
		var code := ""
		for line: String in source.split("\n"):
			if not line.strip_edges().begins_with("#"):
				code += line + "\n"
		assert_bool(code.contains("AudioStreamPlayer")).override_failure_message(
			"%s must own no AudioStreamPlayer — HudAudioDispatcher is the sole HUD audio owner (ADR-0016 §7)" % file).is_false()
		assert_bool(code.contains(".play(")).override_failure_message(
			"%s must call no .play() — exactly one HUD system (HudAudioDispatcher) plays (AC-20)" % file).is_false()
	assert_int(scanned).is_greater(0) # at least the sibling widgets were checked.
