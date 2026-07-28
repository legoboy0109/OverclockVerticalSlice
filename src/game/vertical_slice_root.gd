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
## [br]• [b]Click-to-select[/b] (mouse): picking a unit BY CLICK needs the
##   occupant-pick-region authoring seam (an unassigned build task) — deferred.
##   Keyboard selection is wired around it: the arrow-key grid cursor
##   ([member _cursor]) resolves the entity from its own tile (peek →
##   [method select_at_cursor]), so only mouse-click selection + click-driven
##   board overlays remain on that blocked seam.
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
# Camera framing. The board is fit into the viewport minus these HUD-reserved
# bands (so the top/bottom HUD chrome sits over empty space, not the board), then
# freely zoomable (wheel) between the fit zoom and CAMERA_ZOOM_MAX, and pannable
# (middle-drag / cursor edge-follow).
const CAMERA_HUD_TOP_MARGIN_PX: float = 104.0
const CAMERA_HUD_BOTTOM_MARGIN_PX: float = 128.0
const CAMERA_SIDE_MARGIN_PX: float = 24.0
const CAMERA_FIT_MARGIN: float = 0.95
const CAMERA_ZOOM_MAX: float = 3.0
const CAMERA_ZOOM_STEP: float = 1.12

var _state: GameState = null
var _reader: GameStateReader = null
var _board: BoardRenderer = null
var _camera: Camera2D = null
## The whole-board fit zoom (lower bound for wheel zoom-out); set by _fit_camera_to_board.
var _camera_fit_zoom: float = 1.0
var _cmd: CommandInterface = null
var _hud: GameHud = null
## Slice-owned screen-space status/legend overlay (a CanvasLayer + Label). Surfaces
## the currently-selected Build type (+cost/affordability) and the keyboard controls
## legend — info the committed HUD widgets don't show (HudControlsWidget renders only
## "Build"/"End Turn"). Provisional scene glue; a proper HUD control is a /ux-design
## follow-up. Reads public queries only, never mutates state.
var _status_layer: CanvasLayer = null
var _status_label: Label = null
var _ai_driver: AITurnDriver = null

## True while an AI turn is playing out. Guards against overlapping drives (a
## paced [method AITurnDriver.run_ai_turn] spans multiple frames), and lets a test
## await the paced turn to completion.
var _ai_running: bool = false

## Grid-space keyboard/gamepad navigation cursor (ADR-0014, cai-005 [BoardCursor]).
## Moved with the arrow keys; the entity under it is peeked into the detail panel,
## and an own unit under it can be selected. This is the keyboard [b]work-around
## for the blocked click-pick seam[/b] — it resolves the entity from the cursor's
## OWN tile via [method GameState.entity_at], never the board's
## [method BoardRenderer.pick_at].
var _cursor: BoardCursor = null

## The player's buildable structure roster (also handed to the HUD so its Build
## affordability set matches). KEY_B places [member _selected_buildable] at the
## cursor tile; KEY_C cycles which type is selected. (Produce has the symmetric
## [member _selected_produce_type] / KEY_V pair.)
var _buildables: Array[StructureTypeDef] = []
var _selected_buildable: int = 0
## The unit type KEY_P will produce; cycled by KEY_V. Tracked by reference (not an
## index) so it survives roster changes when a Production Outpost is built. Lazily
## resolved by [method selected_produce_type].
var _selected_produce_type: UnitTypeDef = null


func _ready() -> void:
	_build_match()
	_build_board_and_camera()
	_build_command_interface()
	_build_hud()
	_build_cursor()
	_build_status_overlay()
	_ai_driver = AITurnDriver.new()
	add_child(_ai_driver)
	# Repaint the placeholder markers on every commit (an AI turn drives many).
	_reader.subscribe_action_applied(_on_action_applied)
	# If the match ever opens on the AI's side, hand off immediately.
	_drive_ai_turns()
	queue_redraw()
	_refresh_status()


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
	add_child(_camera)
	_camera.make_current()
	_fit_camera_to_board()
	# Refit when the window is resized so the board stays framed at any size.
	get_viewport().size_changed.connect(_fit_camera_to_board)


## Frames the whole board in the viewport MINUS the HUD-reserved top/bottom bands
## (so the top chrome and the bottom status/controls sit over empty space, not the
## board) and records the resulting fit zoom as the zoom-out floor. Idempotent —
## also runs on window resize.
func _fit_camera_to_board() -> void:
	if _board == null or _camera == null:
		return
	var corners: Array[Vector2] = [
		_board.grid_to_screen(Vector2i(0, 0)),
		_board.grid_to_screen(Vector2i(MAP_WIDTH - 1, 0)),
		_board.grid_to_screen(Vector2i(0, MAP_HEIGHT - 1)),
		_board.grid_to_screen(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1)),
	]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for p: Vector2 in corners:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	# Pad by half a tile so the edge diamonds are not clipped.
	var pad := Vector2(BoardRenderer.TILE_WIDTH_PX, BoardRenderer.TILE_HEIGHT_PX) * 0.5
	min_p -= pad
	max_p += pad
	var board_size: Vector2 = max_p - min_p
	var board_center: Vector2 = (min_p + max_p) * 0.5

	var vp: Vector2 = get_viewport_rect().size
	var safe_w: float = maxf(1.0, vp.x - 2.0 * CAMERA_SIDE_MARGIN_PX)
	var safe_h: float = maxf(1.0, vp.y - CAMERA_HUD_TOP_MARGIN_PX - CAMERA_HUD_BOTTOM_MARGIN_PX)
	var fit: float = minf(safe_w / board_size.x, safe_h / board_size.y) * CAMERA_FIT_MARGIN
	_camera_fit_zoom = fit
	_camera.zoom = Vector2(fit, fit)
	# Offset so the board centers within the safe band (top/bottom margins differ).
	var safe_offset := Vector2(0.0, (CAMERA_HUD_TOP_MARGIN_PX - CAMERA_HUD_BOTTOM_MARGIN_PX) * 0.5)
	_camera.position = board_center - safe_offset / fit


## Multiplies the camera zoom by [param factor], clamped between the whole-board fit
## zoom (can't zoom out into the void) and [constant CAMERA_ZOOM_MAX].
func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var z: float = clampf(_camera.zoom.x * factor, _camera_fit_zoom, CAMERA_ZOOM_MAX)
	_camera.zoom = Vector2(z, z)


## Pans the camera just enough to keep the board cursor inside the central ~70% of
## the view — so arrow-key navigation never loses the cursor when zoomed in. A no-op
## when the whole board fits (fit zoom), since the cursor is always already visible.
func _keep_cursor_in_view() -> void:
	if _board == null or _camera == null or _cursor == null:
		return
	var cursor_world: Vector2 = _board.grid_to_screen(_cursor.grid_pos)
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / _camera.zoom
	var margin: Vector2 = half_view * 0.15
	var lo: Vector2 = _camera.position - half_view + margin
	var hi: Vector2 = _camera.position + half_view - margin
	var pos: Vector2 = _camera.position
	if cursor_world.x < lo.x:
		pos.x += cursor_world.x - lo.x
	elif cursor_world.x > hi.x:
		pos.x += cursor_world.x - hi.x
	if cursor_world.y < lo.y:
		pos.y += cursor_world.y - lo.y
	elif cursor_world.y > hi.y:
		pos.y += cursor_world.y - hi.y
	_camera.position = pos


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
	_buildables = _buildable_roster()
	_hud = GameHud.new()
	# Hand the roster to the HUD so its Build affordability set matches what KEY_B
	# actually places (the widget would otherwise fall back to the same default).
	_hud.assemble(_reader, HudBalance.hud, _cmd, _board, LOCAL_PLAYER, _buildables)
	add_child(_hud)


## The non-HQ structures the player can build (mirrors HudControlsWidget's own
## default roster so the HUD affordability + the KEY_B build stay in lockstep).
func _buildable_roster() -> Array[StructureTypeDef]:
	return [
		StructureTypes.ECONOMY_OUTPOST, StructureTypes.PRODUCTION_OUTPOST,
		StructureTypes.DEFENSIVE_STRUCTURE, StructureTypes.RESEARCH_LAB,
	]


# --- Status / legend overlay (screen space; provisional scene glue) ----------

## Builds the screen-space status overlay: a [CanvasLayer] (so it renders in screen
## space over the world-space board, unaffected by the camera) holding one [Label].
## Text is composed by [method _refresh_status]; the outline keeps it legible over
## the placeholder markers.
func _build_status_overlay() -> void:
	_status_layer = CanvasLayer.new()
	add_child(_status_layer)
	_status_label = Label.new()
	# Bottom-centre, in the camera's reserved bottom band — clear of the board and of
	# the corner widgets (action log bottom-left, controls bottom-right), and off the
	# crowded top edge the player flagged as blocking the board.
	_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position = Vector2(0, -8)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_status_label.add_theme_constant_override("outline_size", 4)
	_status_layer.add_child(_status_label)


## Recomposes the overlay text from public queries: turn indicator, the current
## Build type (name + effective cost + affordability) with its cycle key, the
## produce type, and the controls legend. A no-op before the overlay is built.
func _refresh_status() -> void:
	if _status_label == null:
		return
	var lines := PackedStringArray()
	lines.append("● AI thinking…" if _ai_running else "● Your turn")

	var build_type: StructureTypeDef = selected_buildable()
	if build_type != null:
		var cost: int = BaseProduction.effective_build_cost(_state, build_type, LOCAL_PLAYER)
		var afford: String = "affordable" if _reader.can_afford_build(LOCAL_PLAYER, build_type) else "too expensive"
		lines.append("Build [B]: %s — %d AP (%s)    [C] cycle" % [build_type.display_name, cost, afford])

	var produce_type: UnitTypeDef = selected_produce_type()
	if produce_type != null:
		var pcost: int = Unit.effective_produce_cost(_state, produce_type, LOCAL_PLAYER)
		var pafford: String = "affordable" if _reader.can_afford_produce(LOCAL_PLAYER, produce_type) else "too expensive"
		lines.append("Produce [P]: %s — %d AP (%s)    [V] cycle" % [produce_type.display_name, pcost, pafford])

	lines.append("[Arrows] cursor  [Enter] select  [M] move/attack  [B]/[C] build/cycle  [P]/[V] produce/cycle  [Tab] end turn")
	_status_label.text = "\n".join(lines)


## The producible unit-type roster: the union (deduped, stable order) of every own
## producer's [code]producible_types[/code]. Computed on demand so it grows the turn
## a Production Outpost is built. Empty if the player owns no producer.
func _produce_roster() -> Array[UnitTypeDef]:
	var roster: Array[UnitTypeDef] = []
	if _reader == null:
		return roster
	for e: EntityState in _reader.entities():
		if e is StructureState and e.owner == LOCAL_PLAYER:
			for ut: UnitTypeDef in (e as StructureState).type.producible_types:
				if not roster.has(ut):
					roster.append(ut)
	return roster


## The unit type [method request_produce_at_cursor] will deploy. Lazily initialised
## to the roster's first entry; re-clamped to it if the previously-selected type
## leaves the roster (never stale). Null when no producer is owned.
func selected_produce_type() -> UnitTypeDef:
	var roster: Array[UnitTypeDef] = _produce_roster()
	if roster.is_empty():
		return null
	if _selected_produce_type == null or not roster.has(_selected_produce_type):
		_selected_produce_type = roster[0]
	return _selected_produce_type


## Cycles which unit type [method request_produce_at_cursor] will deploy (the [V]
## key), mirroring [method cycle_buildable]. A no-op when no producer is owned.
func cycle_produce_type() -> void:
	var roster: Array[UnitTypeDef] = _produce_roster()
	if roster.is_empty():
		return
	var current: UnitTypeDef = selected_produce_type() # ensures a valid selection first.
	_selected_produce_type = roster[(roster.find(current) + 1) % roster.size()]
	_refresh_status() # reflect the newly-selected produce type on the overlay.


## The status overlay's current text (test-only read).
func status_text() -> String:
	return _status_label.text if _status_label != null else ""


func _build_cursor() -> void:
	_cursor = BoardCursor.new()
	_cursor.grid_pos = HQ_A # start on the local player's HQ ...
	_cmd.inspect(_state, _cursor.grid_pos) # ... and peek it into the detail panel.


# --- Turn loop ---------------------------------------------------------------

## Every commit repaints the placeholder entity markers. It deliberately does
## NOT drive the AI — that is owned by the End-Turn path ([method try_end_human_turn]),
## so each [method AITurnDriver.run_ai_turn] runs on a clean call stack rather
## than re-entrantly inside [method GameState.apply_action]'s own signal emission.
func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()
	_refresh_status() # AP/affordability/selection may have changed.


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
	_refresh_status() # flip the indicator to "AI thinking…"
	while _state.match_status == GameState.MatchStatus.IN_PROGRESS \
			and _state.per_player[_state.active_player].is_ai_controlled:
		await _ai_driver.run_ai_turn(_state)
	_ai_running = false
	_refresh_status() # back to "Your turn"


## Keyboard board control (ADR-0014). Arrow keys move the grid cursor (peeking the
## entity under it into the detail panel); [code]ui_accept[/code] (Enter/Space)
## selects an own unit at the cursor; M moves/attacks the selected unit onto the
## cursor tile; B builds the selected structure and C cycles the buildable type; P
## produces the selected unit type at the cursor and V cycles that type; Tab ends
## the human's turn. Mouse wheel zooms and middle-drag pans the camera. The cursor
## keys reuse the built-in [code]ui_*[/code] actions; the letter/Tab keys are read
## by keycode. Dedicated, rebindable InputMap actions for all of these are a
## follow-up (the cai-005 InputMap-wiring tech-debt).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_up"):
		move_cursor(Vector2i.UP)
	elif event.is_action_pressed(&"ui_down"):
		move_cursor(Vector2i.DOWN)
	elif event.is_action_pressed(&"ui_left"):
		move_cursor(Vector2i.LEFT)
	elif event.is_action_pressed(&"ui_right"):
		move_cursor(Vector2i.RIGHT)
	elif event.is_action_pressed(&"ui_accept"):
		select_at_cursor()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				act_at_cursor()
			KEY_B:
				request_build_at_cursor()
			KEY_C:
				cycle_buildable()
			KEY_P:
				request_produce_at_cursor()
			KEY_V:
				cycle_produce_type()
			KEY_TAB:
				try_end_human_turn()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(CAMERA_ZOOM_STEP)      # wheel up: zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / CAMERA_ZOOM_STEP) # wheel down: zoom out (to the fit floor)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_camera.position -= event.relative / _camera.zoom # middle-drag: free pan


# --- Keyboard board control (works around the blocked click-pick seam) -------

## Moves the grid cursor one tile along [param direction] (a grid-axis [Vector2i])
## and peeks the entity now under it into the detail panel (unpinned). A no-op at
## a board edge ([method BoardCursor.step] returns false). Returns whether the
## cursor moved.
func move_cursor(direction: Vector2i) -> bool:
	if _cursor == null or _state.grid == null:
		return false
	if not _cursor.step(direction, _state.grid):
		return false
	_cmd.inspect(_state, _cursor.grid_pos) # peek → detail panel (unpinned).
	_keep_cursor_in_view() # pan the camera if the cursor nears the view edge (zoomed in).
	queue_redraw() # repaint the cursor highlight.
	return true


## Selects the own unit at the cursor tile — a pinned selection that drives the
## detail panel and the [CommandInterface] FSM into ENTITY_SELECTED. A no-op
## returning false when the tile is empty, holds a structure, or holds an
## opponent's unit. Resolves the occupant from the cursor's OWN tile
## ([method GameState.entity_at]), never the board's [method BoardRenderer.pick_at]
## — the keyboard path around the blocked pick-region seam.
func select_at_cursor() -> bool:
	if _cursor == null:
		return false
	var entity: EntityState = _state.entity_at(_cursor.grid_pos)
	if entity is UnitState and entity.owner == LOCAL_PLAYER:
		return _cmd.try_select(_state, entity as UnitState)
	return false


## The cursor's current grid tile (for the test + the [method _draw] highlight).
func cursor_tile() -> Vector2i:
	return _cursor.grid_pos if _cursor != null else Vector2i.ZERO


## Builds [method selected_buildable] at the cursor tile, routing a [BuildAction]
## through the [CommandInterface]. A no-op returning false unless it is the human's
## live turn (HUD gate), the cursor tile is a legal build tile for that type, and
## the player can afford it — the same conditions [method BaseProduction.validate_build]
## enforces, pre-checked so this only ever dispatches a build that will commit.
func request_build_at_cursor() -> bool:
	if _cursor == null or _buildables.is_empty() or not _cmd.is_input_live(_state):
		return false # live-gated (same is_input_live check as produce/act).
	var type: StructureTypeDef = _buildables[_selected_buildable]
	var tile: Vector2i = _cursor.grid_pos
	if not _reader.legal_build_tiles(LOCAL_PLAYER, type).has(tile):
		return false
	if not _reader.can_afford_build(LOCAL_PLAYER, type):
		return false
	var action := BuildAction.new()
	action.structure_type = type
	action.tile = tile # action.player is set by CommandInterface.commit.
	return _cmd.dispatch_commit(action, _state)


## Cycles which buildable type [method request_build_at_cursor] will place.
func cycle_buildable() -> void:
	if _buildables.is_empty():
		return
	_selected_buildable = (_selected_buildable + 1) % _buildables.size()
	_refresh_status() # reflect the newly-selected Build type on the overlay.


## The structure type a build would currently place, or [code]null[/code] if the
## roster is empty.
func selected_buildable() -> StructureTypeDef:
	return _buildables[_selected_buildable] if not _buildables.is_empty() else null


## Produces the currently-SELECTED unit type ([method selected_produce_type],
## cycled by KEY_V) onto the cursor tile, from the first own producer that both
## offers that type AND can actually deploy there this turn. Iterates ALL own
## producers (not just the HQ), so a built Production Outpost is reachable and an
## at-cap HQ is skipped. A no-op returning false unless it is the human's live turn
## and some own producer offering the selected type has remaining capacity, a legal
## deploy tile at the cursor, and can afford it — the full set of conditions
## [method BaseProduction.validate_produce] enforces, pre-checked (incl. the per-turn
## cap) so a true return means a real commit.
func request_produce_at_cursor() -> bool:
	if _cursor == null or not _cmd.is_input_live(_state):
		return false
	var utype: UnitTypeDef = selected_produce_type()
	if utype == null:
		return false
	var tile: Vector2i = _cursor.grid_pos
	for e: EntityState in _reader.entities():
		if not (e is StructureState) or e.owner != LOCAL_PLAYER:
			continue
		var producer: StructureState = e as StructureState
		if not producer.type.producible_types.has(utype):
			continue # this producer cannot make the selected type.
		# Remaining cap this turn (validate_produce's first gate — legal_deploy_tiles
		# does not encode it, so pre-check it here to keep the return truthful).
		if int(_reader.structure_info(producer.entity_id).get("remaining_production_cap", 0)) <= 0:
			continue
		if not _reader.legal_deploy_tiles(producer.entity_id, utype).has(tile):
			continue
		if not _reader.can_afford_produce(LOCAL_PLAYER, utype):
			continue
		var action := ProduceAction.new()
		action.producer_id = producer.entity_id
		action.unit_type = utype
		action.tile = tile # action.player set by CommandInterface.commit.
		return _cmd.dispatch_commit(action, _state)
	return false


## Moves or attacks with the currently-SELECTED own unit onto the cursor tile: an
## [AttackAction] when the cursor holds a legal target, otherwise a [MoveAction]
## when the cursor is a reachable tile. A no-op returning false when nothing is
## selected, the selection is not an own unit, it is not the human's live turn, or
## the cursor is neither a legal target nor reachable. Uses the [Movement]/[Combat]
## legality queries directly (the same the validators enforce), pre-checked so it
## only dispatches an action that will commit.
func act_at_cursor() -> bool:
	if _cursor == null or not _cmd.is_input_live(_state):
		return false
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is UnitState) or entity.owner != LOCAL_PLAYER:
		return false
	var unit: UnitState = entity as UnitState
	var tile: Vector2i = _cursor.grid_pos

	# Attack takes priority when the cursor holds a legal target.
	for target: Combat.TargetResult in Combat.legal_targets(_state, unit):
		if target.tile == tile:
			var atk := AttackAction.new()
			atk.attacker_tile = unit.position
			atk.target_tile = tile
			return _cmd.dispatch_commit(atk, _state)

	# Otherwise move when the cursor is a reachable tile.
	for reach: Movement.ReachableTile in Movement.reachable(_state, unit):
		if reach.tile == tile:
			var mv := MoveAction.new()
			mv.from = unit.position
			mv.to = tile
			mv.tiles_entered = reach.min_cost
			return _cmd.dispatch_commit(mv, _state)

	return false


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

	# The keyboard cursor — a hollow diamond outline at the cursor tile.
	if _cursor != null:
		var c: Vector2 = _board.grid_to_screen(_cursor.grid_pos)
		var cr: float = 14.0
		draw_polyline(PackedVector2Array([
			c + Vector2(0, -cr), c + Vector2(cr, 0), c + Vector2(0, cr),
			c + Vector2(-cr, 0), c + Vector2(0, -cr),
		]), Color(1.0, 1.0, 0.4), 2.0)


# --- Accessors (for the boot/integration test) -------------------------------

## The live match state (test-only read; production code reads via the facade).
func state() -> GameState:
	return _state

## The board renderer.
func board() -> BoardRenderer:
	return _board

## The framing camera (test-only read).
func camera() -> Camera2D:
	return _camera

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
