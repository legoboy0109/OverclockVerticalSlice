## VerticalSliceRoot — the bootable main scene that assembles the whole vertical
## slice end-to-end: a live match, the isometric board, the camera, the reactive
## HUD, and the human-vs-AI turn loop, all wired in code.
##
## This is the first runnable scene in the project (everything before it was
## script-only + headless-tested). It is the integration harness the remaining
## Production art/interaction work plugs into — it proves the full stack boots and
## the turn loop runs at runtime, not just under GdUnit.
##
## [b]What it does[/b]:
## [br]1. Builds an authored all-Plain map + two HQs and starts a real match
##    ([method GameState.start_match]); pins both players to the NEUTRAL faction
##    and marks player 1 AI-controlled.
## [br]2. Adds a [BoardRenderer] (placeholder iso floor tiles + the overlay layer)
##    and a [Camera2D] framing the board.
## [br]3. Wires a [CommandInterface] to the board + state (input + overlays).
## [br]4. Assembles the [GameHud] over it via [method GameHud.assemble].
## [br]5. Runs the turn loop: on the human's turn it waits for an End-Turn
##    ([code]ui_accept[/code] / Enter); on the AI's turn it drives [AITurnDriver],
##    which paces its commits ([member AIConfig.commit_pacing_sec]) so the AI turn
##    plays out visibly — the loop therefore [b]awaits[/b] each turn to completion.
##
## [b]Known stubs (flagged, not hidden)[/b] — these are unbuilt/blocked seams, not
## part of this harness:
## [br]• [b]Unit/HQ sprites[/b]: [BoardRenderer] renders only the floor + overlay
##   TileMapLayers — there is no live-entity sprite renderer yet (the
##   [code]GameState.entities()[/code] → board feed is unowned). Entities are drawn
##   here as minimal owner-coloured placeholder markers ([method _draw]) purely so
##   the board is not empty; replace with the real entity renderer when it lands.
## [br]• [b]Click-to-select[/b]: picking a unit needs the occupant-pick-region
##   authoring seam (an unassigned build task) — until it exists, the only human
##   interaction wired here is End-Turn. Board overlays/selection via click are
##   deferred to that seam.
## [br]• [b]Art[/b]: placeholder tinted diamonds until the art/TileSet pass.
## [br]• Camera framing/zoom is provisional (final feel = `/ux-design`).
class_name VerticalSliceRoot
extends Node2D

## Board dimensions and HQ placement for the slice's authored map. Within
## [MapDefinition]'s [code][MIN_DIM, MAX_DIM][/code] range; HQs mutually reachable
## across an all-Plain board.
const MAP_WIDTH: int = 12
const MAP_HEIGHT: int = 10
const HQ_A: Vector2i = Vector2i(2, 5)
const HQ_B: Vector2i = Vector2i(9, 5)

## The human player is 0; the AI is player 1 (VS 1v1, ADR-0011).
const LOCAL_PLAYER: int = 0
const AI_PLAYER: int = 1

## Provisional camera zoom over the placeholder board (final feel = `/ux-design`).
const CAMERA_ZOOM: Vector2 = Vector2(2.0, 2.0)

var _state: GameState = null
var _reader: GameStateReader = null
var _board: BoardRenderer = null
var _camera: Camera2D = null
var _cmd: CommandInterface = null
var _hud: GameHud = null
var _ai_driver: AITurnDriver = null

## True while an AI turn is playing out. Guards against overlapping drives (a
## paced [method AITurnDriver.run_ai_turn] spans multiple frames), and lets a test
## await the paced turn to completion.
var _ai_running: bool = false


func _ready() -> void:
	_build_match()
	_build_board_and_camera()
	_build_command_interface()
	_build_hud()
	_ai_driver = AITurnDriver.new()
	add_child(_ai_driver)
	# Repaint the placeholder markers on every commit (an AI turn drives many).
	_reader.subscribe_action_applied(_on_action_applied)
	# If the match ever opens on the AI's side, hand off immediately.
	_drive_ai_turns()
	queue_redraw()


# --- Build steps -------------------------------------------------------------

func _build_match() -> void:
	var map := MapDefinition.new()
	map.width = MAP_WIDTH
	map.height = MAP_HEIGHT
	map.mode = MapDefinition.Mode.AUTHORED
	var terrain := PackedByteArray()
	terrain.resize(MAP_WIDTH * MAP_HEIGHT)
	terrain.fill(GridState.Terrain.PLAIN)
	map.authored_terrain = terrain
	map.hq_tiles = [HQ_A, HQ_B]
	map.deploy_tiles = []

	_state = GameState.start_match(map, LOCAL_PLAYER)
	# Faction / AI assignment is a direct Setup-phase field write (no
	# faction-assignment verb exists yet; the "lock" is a future-verb convention,
	# ADR-0012 — the widget/integration tests set these the same way).
	_state.per_player[LOCAL_PLAYER].faction = Factions.NEUTRAL
	_state.per_player[AI_PLAYER].faction = Factions.NEUTRAL
	_state.per_player[AI_PLAYER].is_ai_controlled = true

	# start_match places HQs as bare EntityState stubs (its own doc flags that
	# real entity typing is a "later story"). Finish the setup here: promote each
	# to a completed StructureState carrying the real StructureTypes.HQ identity,
	# so the AI scoring, glyph layer, and combat all see a proper HQ (is_hq(),
	# type, hp). Same entity_id/owner/position, so grid occupancy is untouched.
	for player: int in map.hq_tiles.size():
		var hq := StructureState.new()
		hq.entity_id = player # start_match allocates HQ ids 0/1 = player index.
		hq.owner = player
		hq.position = map.hq_tiles[player]
		hq.type = StructureTypes.HQ
		hq.current_hp = StructureTypes.HQ.hp
		hq.build_status = StructureState.BuildStatus.COMPLETED
		_state.entities_by_id[hq.entity_id] = hq

	_reader = GameStateReader.new(_state)


func _build_board_and_camera() -> void:
	_board = BoardRenderer.new()
	add_child(_board)

	_camera = Camera2D.new()
	_camera.position = _board.grid_to_screen(Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2))
	_camera.zoom = CAMERA_ZOOM
	add_child(_camera)
	_camera.make_current()


func _build_command_interface() -> void:
	_cmd = CommandInterface.new()
	add_child(_cmd)
	# Accept the real default query Callables. The overlay renderer is NOT injected
	# yet: overlays only render during selection/preview, which rides the blocked
	# click-pick seam — inject the board as renderer (a small CommandInterface
	# set_renderer passthrough is owed) when board selection is wired.
	_cmd.configure_dependencies()
	_cmd.set_local_player(LOCAL_PLAYER)
	_cmd.set_input_config(InputConfig.new())
	_cmd.attach_to_state(_state)


func _build_hud() -> void:
	_hud = GameHud.new()
	# Buildable roster is left empty for the boot skeleton — the Build control's
	# tile-placement UX rides the (blocked) pick-region seam; the AI still drives
	# economy/production so the loop shows activity. Populate when Build is wired.
	_hud.assemble(_reader, HudBalance.hud, _cmd, _board, LOCAL_PLAYER, [])
	add_child(_hud)


# --- Turn loop ---------------------------------------------------------------

## Every commit repaints the placeholder entity markers. It deliberately does
## NOT drive the AI — that is owned by the End-Turn path ([method try_end_human_turn]),
## so each [method AITurnDriver.run_ai_turn] runs on a clean call stack rather
## than re-entrantly inside [method GameState.apply_action]'s own signal emission.
func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


## Runs AI turns to completion until it is a human's turn again (or the match
## ends). [b][method AITurnDriver.run_ai_turn] is a COROUTINE[/b]: it paces its
## commits with [code]await ...create_timer(commit_pacing_sec).timeout[/code], so
## it is [b]awaited[/b] here — each call must fully finish (its trailing
## [EndTurnAction] included) before the loop condition is re-checked. Awaiting is
## load-bearing: calling it un-awaited would resume the loop at the first pacing
## suspension, spinning up overlapping AI turns racing the same [GameState].
## Termination is guaranteed by that contract (run_ai_turn always self-ends with
## an [EndTurnAction], ADR-0011 §3), which advances the active player away from
## the AI so the condition eventually goes false. The [member _ai_running] guard
## makes a second invocation while one is in flight a no-op. Fire-and-forget from
## the End-Turn path: the AI turn plays out over several frames (paced, visible),
## never blocking input.
func _drive_ai_turns() -> void:
	if _ai_running:
		return
	_ai_running = true
	while _state.match_status == GameState.MatchStatus.IN_PROGRESS \
			and _state.per_player[_state.active_player].is_ai_controlled:
		await _ai_driver.run_ai_turn(_state)
	_ai_running = false


## Human End-Turn on [code]ui_accept[/code] (Enter/Space). Delegates to
## [method try_end_human_turn], which gates on the human's live turn and hands off
## to the AI.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		try_end_human_turn()


# --- Placeholder entity rendering (STUB — see class doc) ---------------------

## Draws a minimal owner-coloured marker at each live entity's tile — a stand-in
## for the not-yet-built entity-sprite renderer, so the board is not blank. This
## is deliberately crude (a filled diamond per entity); delete it when the real
## renderer lands.
func _draw() -> void:
	if _board == null or _reader == null:
		return
	for entity: EntityState in _reader.entities():
		var center: Vector2 = _board.grid_to_screen(entity.position)
		var col: Color = Color(0.2, 0.7, 1.0) if entity.owner == LOCAL_PLAYER else Color(1.0, 0.4, 0.3)
		var r: float = 10.0
		var diamond := PackedVector2Array([
			center + Vector2(0, -r), center + Vector2(r, 0),
			center + Vector2(0, r), center + Vector2(-r, 0),
		])
		draw_colored_polygon(diamond, col)


# --- Accessors (for the boot/integration test) -------------------------------

## The live match state (test-only read; production code reads via the facade).
func state() -> GameState:
	return _state

## The board renderer.
func board() -> BoardRenderer:
	return _board

## The assembled HUD.
func hud() -> GameHud:
	return _hud

## The command interface.
func command_interface() -> CommandInterface:
	return _cmd

## Ends the human's turn (if legal) and hands off to the AI, which self-returns
## control. The single End-Turn path — [method _unhandled_input] delegates here.
## Gated by the HUD's own live check (never acts on the AI's turn / after game
## over). Stays synchronous and returns true iff an End-Turn was routed: it routes
## the commit (AFTER which [method CommandInterface.dispatch_commit] has fully
## returned, so the drive never runs re-entrantly inside the commit's signal) and
## then FIRE-AND-FORGETS [method _drive_ai_turns], so the paced AI turn plays out
## over the following frames without blocking input. A test awaits completion via
## [method is_ai_turn_running].
func try_end_human_turn() -> bool:
	if _state.match_status != GameState.MatchStatus.IN_PROGRESS:
		return false
	if _state.per_player[_state.active_player].is_ai_controlled:
		return false
	if not _hud.controls().request_end_turn(): # live-gated (FOCUS_NONE when inert).
		return false
	_cmd.dispatch_commit(EndTurnAction.new(), _state)
	_drive_ai_turns() # fire-and-forget; the AI turn plays out paced, then returns control.
	return true


## True while an AI turn is playing out (paced across frames). Exposed so a test
## can await the hand-off to completion after an End-Turn.
func is_ai_turn_running() -> bool:
	return _ai_running
