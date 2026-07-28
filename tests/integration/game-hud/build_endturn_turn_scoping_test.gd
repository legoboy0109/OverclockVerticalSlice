# Story 007 (Integration slice): Build/End-Turn controls + turn-scoped inertness.
#
# Covers production/epics/game-hud/story-007-action-log-income-build-controls.md
# (TR-hud-015/017, ADR-0016 §8 + ADR-0014):
#
#   AC-16: Build enabled (>=1 affordable) vs dimmed-but-present (0 affordable);
#     activating it opens structure selection in EITHER state.
#   AC-18/27: on the opponent's turn / the EndTurn(P) transient / GameOver, Build
#     and End Turn are inert — FOCUS_NONE, and activation is a hard no-op (no
#     apply_action, no state change). Readouts stay live regardless.
#   Build pressed cue reflects CAI's PREVIEW_BUILD state (outward-in read).
#
# Integration-type: Control nodes are add_child()'d. Deterministic — no waits.
extends GdUnitTestSuite


## Duck-typed CAI stub exposing fsm_state() (the only method HudControlsWidget
## reads for the pressed cue) — CAI has no public path to drive _fsm_state to
## PREVIEW_BUILD, so a stub is the clean seam (mirrors the widget's own doc).
class _CmdStub extends RefCounted:
	var state: int = CommandFSM.State.IDLE
	func fsm_state() -> int:
		return state


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_controls(reader: GameStateReader, local_player: int) -> HudControlsWidget:
	var controls: HudControlsWidget = auto_free(HudControlsWidget.new())
	controls.bind(reader)
	controls.configure(HUDConfig.new(), local_player)
	add_child(controls)
	return controls


# ==============================================================================
# AC-16: Build affordability; activation opens selection in either state.
# ==============================================================================

func test_build_enabled_when_affordable_dimmed_when_not_but_always_opens() -> void:
	var state := _make_state(0) # local player 0 active.
	state.per_player[0].current_ap = 100 # affords something.
	var reader := GameStateReader.new(state)
	var controls := _make_controls(reader, 0)

	assert_bool(controls.controls_live()).is_true()
	assert_bool(controls.build_affordable()).is_true()
	assert_bool(controls.request_build()).is_true() # opens structure selection.

	state.per_player[0].current_ap = 0 # affords nothing.
	assert_bool(controls.build_affordable()).is_false() # dimmed ...
	assert_bool(controls.request_build()).is_true() # ... but STILL opens selection (AC-16).


# ==============================================================================
# AC-18/27: inert on opponent turn / GameOver — FOCUS_NONE + no-op activation.
# ==============================================================================

func test_controls_inert_on_opponent_turn() -> void:
	var state := _make_state(1) # opponent (1) active; local 0.
	state.per_player[0].current_ap = 100
	var reader := GameStateReader.new(state)
	var controls := _make_controls(reader, 0)

	assert_bool(controls.controls_live()).is_false()
	assert_int(controls.controls_focus_mode()).is_equal(Control.FOCUS_NONE)
	assert_bool(controls.request_build()).is_false() # hard no-op.
	assert_bool(controls.request_end_turn()).is_false()


func test_controls_inert_on_game_over() -> void:
	var state := _make_state(0) # local active ...
	state.match_status = GameState.MatchStatus.GAME_OVER # ... but the match is over.
	var reader := GameStateReader.new(state)
	var controls := _make_controls(reader, 0)

	assert_bool(controls.controls_live()).is_false()
	assert_int(controls.controls_focus_mode()).is_equal(Control.FOCUS_NONE)
	assert_bool(controls.request_end_turn()).is_false()
	assert_bool(controls.request_build()).is_false()


func test_controls_live_and_focusable_on_local_turn() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var controls := _make_controls(reader, 0)

	assert_bool(controls.controls_live()).is_true()
	assert_int(controls.controls_focus_mode()).is_equal(Control.FOCUS_ALL)


# ==============================================================================
# Build pressed cue mirrors CAI's PREVIEW_BUILD (outward-in read).
# ==============================================================================

func test_build_pressed_cue_reflects_preview_build_state() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var controls := _make_controls(reader, 0)
	var cmd := _CmdStub.new()
	controls.attach_interface(cmd)

	cmd.state = CommandFSM.State.IDLE
	assert_bool(controls.build_pressed_cue()).is_false()

	cmd.state = CommandFSM.State.PREVIEW_BUILD
	assert_bool(controls.build_pressed_cue()).is_true()

	cmd.state = CommandFSM.State.ENTITY_SELECTED
	assert_bool(controls.build_pressed_cue()).is_false()
