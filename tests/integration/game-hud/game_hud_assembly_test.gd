# Game HUD scene assembly — GameHud wires every widget to the live game.
#
# Covers src/ui/game_hud/game_hud.gd — the integration glue the per-widget
# stories (001–008) deferred. This suite proves the ASSEMBLY (every widget is
# instantiated, bound, configured, and correctly parented) and that a
# representative reaction propagates through the assembled whole (a commit ticks
# the AP counter + grows the log + sounds the tick; a turn boundary raises the
# banner + stinger; game-over shows the overlay + fanfare). Per-widget behaviour
# is each widget's own suite's job — this checks the wiring, not the internals.
#
# Integration-type: every test add_child()s the GameHud (a CanvasLayer) so its
# widgets enter the tree, run _ready(), and subscribe to action_applied.
# Deterministic: no RNG, no wall-clock; reactions are asserted immediately after
# the triggering commit. Gridless GameState (GameStateFactory) — the assembly and
# the reader/turn/game-over/audio seams need no entities.
extends GdUnitTestSuite

const Cue = HudAudioDispatcher.Cue


func _make_state(active_player: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, active_player)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_cmd(state: GameState, local_player: int = 0) -> CommandInterface:
	var cmd: CommandInterface = auto_free(CommandInterface.new())
	add_child(cmd)
	cmd.configure_dependencies() # real query Callables (defaults).
	cmd.set_local_player(local_player)
	cmd.attach_to_state(state)
	return cmd


func _make_board() -> BoardRenderer:
	var board: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(board)
	return board


func _make_hud(reader: GameStateReader, cmd: CommandInterface, board: BoardRenderer, \
		local_player: int = 0, config: HUDConfig = null) -> GameHud:
	var hud: GameHud = auto_free(GameHud.new())
	hud.assemble(reader, config if config != null else HUDConfig.new(), cmd, board, local_player, [])
	add_child(hud) # CanvasLayer enters the tree → widgets _ready() + subscribe.
	return hud


func _commit(state: GameState, events: Array = []) -> void:
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))


# ==============================================================================
# Assembly — every widget is instantiated, present, and correctly parented.
# ==============================================================================

func test_assembles_all_widgets_and_wires_their_parents() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var cmd := _make_cmd(state)
	var board := _make_board()
	var hud := _make_hud(reader, cmd, board)

	# Every element assembled.
	assert_object(hud.ap_counter()).is_not_null()
	assert_object(hud.opponent_ap_counter()).is_not_null() # show_opponent_ap default true.
	assert_object(hud.turn_banner()).is_not_null()
	assert_object(hud.income_breakdown()).is_not_null()
	assert_object(hud.action_log()).is_not_null()
	assert_object(hud.controls()).is_not_null()
	assert_object(hud.detail_panel()).is_not_null()
	assert_object(hud.game_over_overlay()).is_not_null()
	assert_object(hud.glyph_layer()).is_not_null()
	assert_object(hud.audio()).is_not_null()

	# Screen-space Controls + audio are children of the CanvasLayer; the
	# world-space glyph layer is parented onto the board.
	assert_object(hud.ap_counter().get_parent()).is_equal(hud)
	assert_object(hud.game_over_overlay().get_parent()).is_equal(hud)
	assert_object(hud.audio().get_parent()).is_equal(hud)
	assert_object(hud.glyph_layer().get_parent()).is_equal(board)

	# The dispatcher built its two channels.
	assert_object(hud.audio().channel_high()).is_not_null()
	assert_object(hud.audio().channel_low()).is_not_null()

	# The detail panel starts empty (wired, nothing selected yet).
	assert_int(hud.detail_panel().shown_entity_id()).is_equal(-1)


# ==============================================================================
# A plain commit ticks the local AP counter and sounds the AP-tick once.
# ==============================================================================

func test_plain_commit_ticks_ap_counter_and_audio() -> void:
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var hud := _make_hud(reader, _make_cmd(state), _make_board())
	assert_int(hud.ap_counter().committed_value()).is_equal(9) # baseline from the facade.

	state.per_player[0].current_ap = 6 # a spend ...
	_commit(state)                     # ... committed.
	await get_tree().process_frame

	assert_int(hud.ap_counter().committed_value()).is_equal(6) # live read propagated.
	assert_int(hud.audio().play_count(Cue.AP_TICK)).is_equal(1) # single-owner tick.


# ==============================================================================
# A commit carrying an event grows the action log by one entry.
# ==============================================================================

func test_commit_with_event_grows_action_log() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var hud := _make_hud(reader, _make_cmd(state), _make_board())
	assert_int(hud.action_log().entry_count()).is_equal(0)

	_commit(state, [StructureCompletedEvent.new()])
	await get_tree().process_frame

	assert_int(hud.action_log().entry_count()).is_equal(1)


# ==============================================================================
# A turn boundary raises the banner and sounds the turn-change stinger.
# ==============================================================================

func test_turn_transition_raises_banner_and_stinger() -> void:
	var state := _make_state(0) # local player 0 active (baseline).
	var reader := GameStateReader.new(state)
	var hud := _make_hud(reader, _make_cmd(state), _make_board())

	state.active_player = 1 # a real turn boundary.
	_commit(state)
	await get_tree().process_frame

	assert_bool(hud.turn_banner().banner_active()).is_true()
	assert_int(hud.audio().play_count(Cue.TURN_STINGER)).is_equal(1)


# ==============================================================================
# Game over shows the victory/defeat overlay and sounds the GameOver fanfare.
# ==============================================================================

func test_game_over_shows_overlay_and_plays_fanfare() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var hud := _make_hud(reader, _make_cmd(state), _make_board(), 0)

	state.match_status = GameState.MatchStatus.GAME_OVER
	state.winner = 0 # the local player wins.
	_commit(state, [GameOverEvent.new()])
	await get_tree().process_frame

	assert_bool(hud.game_over_overlay().is_showing()).is_true()
	assert_bool(hud.game_over_overlay().is_local_victory()).is_true() # winner 0 == local 0.
	assert_int(hud.audio().play_count(Cue.GAME_OVER)).is_equal(1)


# ==============================================================================
# assemble() is idempotent — a second call is a no-op, not a rebuild.
# ==============================================================================

func test_second_assemble_is_a_noop() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var cmd := _make_cmd(state)
	var board := _make_board()
	var hud: GameHud = auto_free(GameHud.new())
	hud.assemble(reader, HUDConfig.new(), cmd, board, 0, [])
	var first_counter := hud.ap_counter()
	var child_count := hud.get_child_count()

	hud.assemble(reader, HUDConfig.new(), cmd, board, 1, []) # second call.

	assert_bool(hud.ap_counter() == first_counter).is_true() # same instance, not rebuilt.
	assert_int(hud.get_child_count()).is_equal(child_count)  # no duplicate widgets.


# ==============================================================================
# Boardless assembly (e.g. a menu) skips the on-board glyph layer cleanly.
# ==============================================================================

func test_boardless_assembly_skips_glyph_layer() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var hud: GameHud = auto_free(GameHud.new())
	hud.assemble(reader, HUDConfig.new(), _make_cmd(state), null, 0, [])
	add_child(hud)

	assert_object(hud.glyph_layer()).is_null()    # skipped — no board.
	assert_object(hud.ap_counter()).is_not_null()  # the rest still assembled.
	assert_object(hud.audio()).is_not_null()


# ==============================================================================
# The AP preview-echo scene-glue passthrough forwards to the AP counter.
# ==============================================================================

func test_open_and_close_ap_preview_forward_to_the_counter() -> void:
	# GameHud cannot auto-connect the echo (CommandInterface exposes no preview
	# signal), so it forwards open/close to the counter for the scene glue —
	# verify the passthrough hits the right widget instance.
	var state := _make_state(0)
	state.per_player[0].current_ap = 9
	var reader := GameStateReader.new(state)
	var hud := _make_hud(reader, _make_cmd(state), _make_board())

	hud.open_ap_preview(3, true)
	assert_bool(hud.ap_counter().showing_echo()).is_true()
	assert_int(hud.ap_counter().projected_value()).is_equal(3)

	hud.close_ap_preview()
	assert_bool(hud.ap_counter().showing_echo()).is_false()


# ==============================================================================
# The opponent AP counter is omitted when show_opponent_ap is off.
# ==============================================================================

func test_opponent_ap_counter_omitted_when_show_opponent_ap_false() -> void:
	var state := _make_state(0)
	var reader := GameStateReader.new(state)
	var cfg := HUDConfig.new()
	cfg.show_opponent_ap = false
	var hud := _make_hud(reader, _make_cmd(state), _make_board(), 0, cfg)

	assert_object(hud.opponent_ap_counter()).is_null()  # omitted.
	assert_object(hud.ap_counter()).is_not_null()        # local counter still present.
