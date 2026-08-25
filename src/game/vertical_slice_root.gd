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
##    ([method GameState.start_match]); pins the two sides to the RUSH and BOOM
##    factions (ownership-by-hue; both empty-delta, so VS parity holds) and marks
##    player 1 AI-controlled.
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
## [br]• [b]Unit/HQ sprites[/b]: ✅ BUILT (Story 006 / S5-01, scope §8 build-seam c
##   closed). [EntitySpriteFeed] renders one real [Sprite2D] per live entity into
##   the board's Y-sorted occupant layer, and [method BoardRenderer.paint_terrain]
##   paints the floor + Cover props. This scene no longer draws entities itself.
## [br]• [b]Click-to-select[/b] (mouse): WIRED (scope §8 seam b closed). Left-click
##   routes through [method select_at_mouse] → [method CommandInterface.route_click]
##   → [method BoardRenderer.pick_at] against the occupant pick-regions this scene
##   authors from the live entities ([method _refresh_occupant_pick_regions]) — the
##   ADR-0013 §4 CAI boundary (never [code]screen_to_grid[/code] for routing). The
##   regions are authored from the ACTUAL drawn sprite bounds by
##   [method EntitySpriteFeed.pick_regions] (Story 006 closed the S3-05 seam).
##   Click-to-MOVE (an action from a click into an open preview) stays Story 007
##   scope — this closes selection only. The keyboard cursor path
##   ([method select_at_cursor]) remains as the gamepad/keyboard equivalent.
## [br]• [b]Art[/b]: real sprites + terrain as of 2026-08-19. Still owed: the glow
##   shader (S5-02), move/attack/hit transforms and the destroyed beat (S5-06).
## [br]• Camera framing/zoom is provisional (final feel = `/ux-design`).
class_name VerticalSliceRoot
extends Node2D

## Board dimensions and HQ placement for the slice's authored map. Within
## [MapDefinition]'s [code][MIN_DIM, MAX_DIM][/code] range; HQs mutually reachable
## across an all-Plain board.
# ★ S7-11: aliases onto [VSMap], which is the single authored definition. Kept as names
# here because ~a dozen call sites read them; redefining the VALUES here is what would let
# the slice and the match simulator drift apart.
const MAP_WIDTH: int = VSMap.WIDTH
const MAP_HEIGHT: int = VSMap.HEIGHT
const HQ_A: Vector2i = VSMap.HQ_A
const HQ_B: Vector2i = VSMap.HQ_B

## The human player is 0; the AI is player 1 (VS 1v1, ADR-0011).
const LOCAL_PLAYER: int = 0

## Where "Quit to Main Menu" goes (`design/ux/pause.md` exit table).
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const AI_PLAYER: int = 1

## Round cap for the vertical slice, arming [member GameState.max_rounds] (user
## decision, 2026-08-21).
##
## [b]Why the slice needs one at all.[/b] An AI-vs-AI simulation over 20 matches found
## the slice had NO terminating condition: the AI never attacks an HQ (zero HQ damage in
## 4,182 turn-rows) and `max_rounds` defaulted to 0, so every game ran forever — even
## with one side starting three Troopers up. See
## `production/playtests/swing-back-simulation-appendix-2026-08-21.md`.
##
## [b]Why 30.[/b] The simulation showed unit counts stabilising by round 20-30 and the
## economy well developed by 25, so 30 rounds leaves room for a full arc without the
## indefinite drag. It is a starting value for the S5-04 session to judge, not a locked
## one — change this single constant.
##
## ★ [b]Note what the tiebreak rewards.[/b] [constant GameState.TiebreakMetric.UNIT_COUNT]
## is the only implemented metric, so a capped game is won on unit COUNT. Combined with
## the unbounded Credit accumulation the same simulation found, the theoretically optimal
## line in a capped game is "bank, mass-produce cheap units, avoid fighting" — flagged
## for the playtest to watch for, not fixed here.
const VS_MAX_ROUNDS: int = 30

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

## Horizontal screen margin the status plate must leave free on EACH side, in
## pixels — the columns the bottom corner HUD panels own.
##
## Sized off [GameHud]'s own bottom-corner geometry: LOG is 210 wide at x+16 from
## the left edge, ACTIONS is 200 wide at x-216 from the right, so 240 clears the
## wider of the two with room to spare at either edge. Kept here rather than
## imported from [GameHud] because the plate is the slice's own scene glue, not a
## HUD widget — if the two ever need to agree formally, that is the HUD chrome
## sign-off's call, not this file's.
const STATUS_SIDE_RESERVE_PX: float = 240.0

## Floor for the status plate's clamped width, so a very narrow window degrades to
## a small overlapping plate rather than a one-word-per-line column.
const STATUS_MIN_WIDTH_PX: float = 280.0

var _state: GameState = null
var _reader: GameStateReader = null
var _board: BoardRenderer = null

## The live [method GameState.entities] -> sprite feed (Story 006 / S5-01). Owns
## every entity [Sprite2D] under the board's occupant layer, and is also the source
## of the board's occupant pick-regions (see [method _refresh_occupant_pick_regions]).
var _feed: EntitySpriteFeed = null
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

## ★ 2026-08-24 — the contextual action menu (`design/ux/action-menu.md`).
##
## The verb surface CR-1's loop always specified and the slice never had: before
## this, every verb was a separate keyboard key, which cannot express CR-4's
## "shown disabled with its reason, not hidden" because a key that does nothing
## looks exactly like a key that does not exist. Lives in [member _status_layer]
## rather than under [member _hud] so it draws ABOVE the HUD panels (it is
## transient and must never be hidden behind a corner plate) but BELOW nothing
## else — the pause and game-over overlays own their own layers above it.
var _action_menu: ActionMenu = null

## The unit type chosen in the Produce submenu, held while
## [constant CommandFSM.State.PREVIEW_PRODUCE] is open so the commit at the cursor
## knows what to deploy. Cleared on every preview exit — a stale type here would
## deploy something the player did not just pick.
var _pending_produce: UnitTypeDef = null

## The structure type the Build flow will place, held for the same reason and for
## the same lifetime as [member _pending_produce].
var _pending_build: StructureTypeDef = null

## The legal tiles of the open Produce/Build preview, painted as the
## [constant BoardRenderer.OverlayClass.BUILD_DEPLOY_GO_TILE] overlay.
##
## [b]Slice-owned, not [CommandInterface]-owned, and deliberately so.[/b] That
## class's Tier-1/2 recompute covers PREVIEW_MOVE and PREVIEW_ATTACK only —
## ADR-0015 §3 scopes the tiers to `reachable()`/`legal_targets()` and explicitly
## leaves Base & Production's own preview queries out. Adding a fourth tier family
## to a heavily-specified class in order to light up deploy tiles would be a much
## larger change than the feature needs; the slice paints these itself through the
## sanctioned [method BoardRenderer.set_overlays] path.
var _preview_tiles: Array[Vector2i] = []

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

## The in-match pause overlay (`design/ux/pause.md`). Built here rather than inside
## [GameHud] because the destructive paths it offers — restart, quit to menu — are
## match-lifecycle concerns this node owns, and the HUD owns none of them.
var _pause: PauseMenu = null

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
## Transient one-line feedback shown on the overlay when an action does nothing
## (e.g. "not enough AP"), so a no-op isn't silent. Set on a failed act/build/
## produce; cleared on the next cursor move or successful commit.
var _flash: String = ""


func _ready() -> void:
	_build_match()
	_build_board_and_camera()
	_build_command_interface()
	_build_hud()
	_build_cursor()
	_build_status_overlay()
	_ai_driver = AITurnDriver.new()
	add_child(_ai_driver)
	# Re-sync sprites + pick regions on every commit (an AI turn drives many).
	_reader.subscribe_action_applied(_on_action_applied)
	# If the match ever opens on the AI's side, hand off immediately.
	_drive_ai_turns()
	_refresh_occupant_pick_regions() # author the initial click targets from the starting entities.
	_refresh_status()


# --- Build steps -------------------------------------------------------------

func _build_match() -> void:
	# ★ S7-11: the map is authored ONCE in VSMap and shared by the slice, the match
	# simulator and both diagnostic tools. It used to be hand-built in all four, which
	# agreed only for as long as every tile was Plain — see VSMap's header.
	var map: MapDefinition = VSMap.build()

	_state = GameState.start_match(map, LOCAL_PLAYER)
	# Faction / AI assignment is a direct Setup-phase field write (no
	# faction-assignment verb exists yet; the "lock" is a future-verb convention,
	# ADR-0012). The two sides are pinned to RUSH/BOOM so ownership reads by hue
	# (art-bible §4.2 / S4-02); both carry empty unit_deltas, so this is exact VS
	# parity — mechanically identical to Neutral, distinct only in identity/hue.
	# Arm the round cap so a match can actually end (see VS_MAX_ROUNDS). The tiebreak
	# machinery already existed and is tested; the slice simply never set this.
	_state.max_rounds = VS_MAX_ROUNDS
	_state.per_player[LOCAL_PLAYER].faction = Factions.RUSH
	_state.per_player[AI_PLAYER].faction = Factions.BOOM
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
	# Static board first (floor cells + Y-sorted Cover props), then the live entity
	# feed into the same occupant layer. Story 002's placeholder fixtures and this
	# scene's own _draw marker diamonds are both gone — this is the real art.
	_board.paint_terrain(_state.grid)
	_feed = EntitySpriteFeed.new(_board, [
		_state.per_player[LOCAL_PLAYER].faction,
		_state.per_player[AI_PLAYER].faction,
	])
	# ★ PER-UNIT actionability (user decision, 2026-08-21), replacing the army-wide
	# "does this player have any AP" read that art bible §8.5/§2.6 specified
	# literally. An actor is lit while its owner can still afford SOMETHING for it,
	# and dims when it cannot.
	#
	# [b]Why affordability and not "has this unit acted".[/b] The obvious XCOM-style
	# read — a unit greys out once used — has no equivalent state here. Attacking
	# sets has_attacked, but the move cap is SOFT: a unit that has moved, or
	# attacked, can always keep moving, it just pays a surcharge. There is no point
	# at which a unit is finished. So "can still act" has to mean "the owner can
	# still pay for its cheapest remaining option", which IS per-unit because
	# move_cost varies across the roster (Scout 1, Trooper/Sniper 2, Heavy 3).
	#
	# The practical read this gives: at 2 AP the Scout, Trooper and Sniper stay lit
	# while the Heavy goes dark; at 1 AP only the Scout is left. That answers the
	# question a player actually has at end of turn — "what can I still do?" —
	# rather than the blunter "am I out of AP", which the AP counter already says.
	#
	# Structures are handled separately: see the closure.
	_feed.actionable_predicate = _is_entity_actionable

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
	# Accept the real default query Callables, then inject the board as the click
	# renderer (scope §8 seam b closed): route_click consumes _board.pick_at as the
	# ONE click-routing entry point (ADR-0013 §4), never screen_to_grid directly.
	# _board is built first in _ready, so it exists here.
	_cmd.configure_dependencies()
	_cmd.set_renderer(_board)
	_cmd.set_local_player(LOCAL_PLAYER)
	_cmd.set_input_config(InputConfig.new())
	_cmd.attach_to_state(_state)
	# ★ 2026-08-24 (/ux-review advisory 8). GameState.action_applied fires on
	# SUCCESS only, and dispatch_commit returns "a commit was dispatched", not "it
	# worked" — so a refused commit used to reach nothing here and the player was
	# told nothing at all. They would read that as the input not registering and
	# press again. Now every rejection says why, in the same voice the greyed-out
	# menu rows use.
	_cmd.commit_rejected.connect(_on_commit_rejected)


func _build_hud() -> void:
	_buildables = _buildable_roster()
	_hud = GameHud.new()
	# Hand the roster to the HUD so its Build affordability set matches what KEY_B
	# actually places (the widget would otherwise fall back to the same default).
	_hud.assemble(_reader, HudBalance.hud, _cmd, _board, LOCAL_PLAYER, _buildables)
	add_child(_hud)
	_wire_hud_controls() # after assemble — the widgets do not exist until then.
	_build_pause_menu()


## Routes the HUD's action buttons into the SAME methods the keyboard uses, rather
## than giving clicks and pad presses their own path.
##
## ★ Until 2026-08-24 the "Build" and "End Turn" controls were `draw_string` calls:
## the words were painted and nothing could activate them by any input method.
## `HudControlsWidget.request_build()` had no caller outside the test suite. They
## are real [Button]s now, and these two connections are what make them do
## something — deliberately landing on `request_build_at_cursor()` and
## `try_end_human_turn()`, the exact entry points [B] and [Tab] already use, so a
## click, a key and a pad press cannot drift apart in behaviour.
func _wire_hud_controls() -> void:
	var controls: HudControlsWidget = _hud.controls()
	if controls == null:
		return
	# ★ 2026-08-24: Build now opens a TYPE PICKER rather than immediately placing
	# whatever type happened to be cycled. The [C] cycle key it used to depend on is
	# gone (action-menu.md decision 2), and "place the hidden current selection" was
	# never a thing the button could explain anyway.
	controls.build_requested.connect(open_build_picker)
	controls.end_turn_requested.connect(func() -> void: try_end_human_turn())


## The non-HQ structures the player can build (mirrors HudControlsWidget's own
## default roster so the HUD affordability + the KEY_B build stay in lockstep).
func _buildable_roster() -> Array[StructureTypeDef]:
	# ★ The FACTORY is deliberately absent (S6-09, 2026-08-24). Its design role is to
	# produce GROUND_VEHICLE units, and those are wave 2 -- `unit-classes.md` is not
	# implemented. Today the Factory produces nothing (`producible_types = []`), grants
	# no income (that moved to research in S6-01), and costs 1,000 Credits plus 200
	# upkeep every turn. Offering it is offering the player a button that can only make
	# their position worse, and the corrected stats make the trap more expensive, not
	# less. Restore this entry in the same change that gives the Factory something to
	# build. The AI already skips it on its own -- its value gate scores an
	# unproductive structure 0 -- so this only ever affected the human.
	return [
		StructureTypes.BARRACKS,
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
	_status_label.position = Vector2(0, -26)
	# ★ 2026-08-24 (user-reported: "the central info panel is covering two of the text
	# boxes"). This label sizes itself to its own longest line, and the control legend
	# is ~1280px wide at 1600px — so the plate reached under the LOG panel on the left
	# and the ACTIONS panel on the right, hiding the Build button. Wrapping is what
	# makes the width a CHOICE rather than whatever the text happens to be; the width
	# itself is clamped in [method _layout_status] to the band the corner panels leave.
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	# ★ 2026-08-24: a real backing plate, not just an outline. This block carries the
	# selected build/produce type, its live cost and the whole control legend — the
	# text a player reads most while learning the game — and it was drawing straight
	# onto the board, so it competed with terrain and sprites for the same pixels.
	# The 4px outline was a workaround for having no ground; a panel is the fix.
	# Matches HudPanel's palette so the two read as one HUD rather than two.
	var backing := StyleBoxFlat.new()
	backing.bg_color = HudPanel.BACKING
	backing.border_color = HudPanel.BORDER
	backing.set_border_width_all(1)
	backing.set_content_margin_all(10)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	_status_label.add_theme_stylebox_override("normal", backing)
	_status_layer.add_child(_status_label)
	# Re-clamp on resize: the reserve is measured from the screen EDGES (both corner
	# panels are edge-anchored), so the usable band changes with the window.
	_status_label.get_viewport().size_changed.connect(_layout_status)
	_layout_status()
	_build_action_menu()


## Builds the contextual action menu and wires its four outcomes to the same entry
## points the keyboard accelerators use, so a menu pick and a keypress can never
## drift apart in behaviour (the discipline [method _wire_hud_controls] already
## established for the HUD's buttons).
func _build_action_menu() -> void:
	_action_menu = ActionMenu.new()
	_action_menu.configure(Settings.settings != null and Settings.settings.reduced_motion)
	_status_layer.add_child(_action_menu)
	_action_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_action_menu.verb_chosen.connect(_on_menu_verb_chosen)
	_action_menu.produce_type_chosen.connect(_on_menu_produce_chosen)
	_action_menu.dismissed.connect(deselect)
	# ★ 2026-08-25 — OQ-1 answered. Wait is no longer a deselect: it commits a
	# WaitAction that marks the entity stood down for the turn, and dismissal still
	# just closes the menu. The two signals were kept separate specifically so this
	# day's change would be a one-line rewire rather than an untangling.
	_action_menu.waited.connect(_on_menu_waited)


## Clamps the status plate to the horizontal band the bottom corner panels leave
## free, so it can never draw over them at any window size.
##
## [b]Why a computed clamp and not a hand-set width.[/b] The two panels it must
## avoid are anchored to the screen edges and keep a constant inset from them
## ([code]GameHud[/code]: LOG bottom-left, ACTIONS bottom-right), so the free band
## is [code]viewport.x - 2 * STATUS_SIDE_RESERVE_PX[/code] at every resolution —
## one expression that stays true instead of a magic number that is right at 1600
## and wrong at 1920.
##
## The clamp is a MINIMUM size, not a size: with [constant Control.GROW_DIRECTION_BOTH]
## on a centre anchor, Godot grows the control symmetrically about that anchor, so
## the plate still hugs short text (a one-line "Your turn" stays a small centred
## box) and only widens to the band when the text needs it — at which point
## [member Label.autowrap_mode] wraps rather than letting it spill into the corners.
## Content margins are subtracted because the plate's border sits outside the text.
func _layout_status() -> void:
	if _status_label == null:
		return
	var band: float = _status_label.get_viewport_rect().size.x - 2.0 * STATUS_SIDE_RESERVE_PX
	var margins: float = 0.0
	var backing: StyleBox = _status_label.get_theme_stylebox("normal")
	if backing != null:
		margins = backing.get_margin(SIDE_LEFT) + backing.get_margin(SIDE_RIGHT)
	_status_label.custom_minimum_size.x = maxf(
		STATUS_MIN_WIDTH_PX, minf(_widest_status_line(), band - margins)
	)


## Pixel width of the widest line currently in the status text, measured with the
## label's own font and size — the width the plate WOULD take with no clamp.
## Measured rather than assumed because the legend's length changes with the
## selected build/produce type and with any transient flash message.
func _widest_status_line() -> float:
	var font: Font = _status_label.get_theme_font("font")
	if font == null:
		return 0.0
	var font_size: int = _status_label.get_theme_font_size("font_size")
	var widest: float = 0.0
	for line: String in _status_label.text.split("\n"):
		widest = maxf(widest, font.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x)
	return widest


## Recomposes the overlay text from public queries: turn indicator, the current
## Build type (name + effective cost + affordability) with its cycle key, the
## produce type, and the controls legend. A no-op before the overlay is built.
func _refresh_status() -> void:
	if _status_label == null:
		return
	var lines := PackedStringArray()
	# ASCII only — the engine fallback font has no glyph for many symbols
	# (bullet/hourglass/warning/arrow), which render as "tofu" boxes.
	# Match end takes over the whole status line. ★ This is NOT game-hud.md CR-9's
	# victory/defeat screen — that remains unimplemented for EVERY win path, including
	# HQ destruction (AC-17/AC-22). It is a stopgap so that arming the round cap does not
	# produce a build where the match silently stops responding with no explanation,
	# which is what a playtester would otherwise experience.
	if _state != null and _state.match_status == GameState.MatchStatus.GAME_OVER:
		var who: String = "You win" if _state.winner == LOCAL_PLAYER else "You lose"
		var how: String = "opponent HQ destroyed" if _hq_destroyed() \
			else "round limit reached (%d) - decided on unit count" % VS_MAX_ROUNDS
		_status_label.text = ">> MATCH OVER - %s (%s)" % [who, how]
		_layout_status()
		return
	lines.append(">> AI thinking..." if _ai_running else ">> Your turn")

	if _flash != "":
		lines.append("(!) " + _flash) # what the last action did, or why it did nothing.

	# ★ 2026-08-24 — the legend used to name ELEVEN bindings across two lines, plus
	# a "Build [B]: <type> - <cost> ... [C] cycle" line and a Produce twin, because
	# every verb was its own key and every type choice was a hidden cycled value the
	# player could only read here. The action menu shows the verbs, their shortcuts
	# and their costs in place, and the type pickers show the types — so all of that
	# moved to where the decision is actually made, and what is left is the handful
	# of controls that belong to no selection.
	lines.append("[Arrows] cursor   [Enter] confirm   [Esc] back   " +
		"[B] build   [Tab] end turn   [[ ] jump cursor")
	_status_label.text = "\n".join(lines)
	_layout_status() # the widest line just changed; re-clamp before it is drawn.


## Renders a refused commit as the status line's transient reason.
##
## Wording comes from [method ActionMenu.commit_rejection_text] rather than from a
## local table, so the sentence a player reads after a refusal matches the one on
## the greyed-out row that would have predicted it.
func _on_commit_rejected(reason: int) -> void:
	_flash_msg("Refused: %s" % ActionMenu.commit_rejection_text(reason))
	# The board did not change, but the menu's affordability may have been what was
	# wrong — reopen it so the player can see the verb greyed out with its reason
	# rather than only reading the transient line.
	_open_action_menu()


## Sets the transient feedback line and repaints the overlay.
func _flash_msg(text: String) -> void:
	_flash = text
	_refresh_status()


## The reason [method act_at_cursor] found nothing to do with [param unit] at the
## cursor — AP exhaustion (the common case: producing spent the shared budget) vs a
## non-actionable target tile.
func _act_hint(unit: UnitState) -> String:
	var ap: int = _state.per_player[LOCAL_PLAYER].current_ap
	var can_move: bool = not Movement.reachable(_state, unit).is_empty()
	var can_attack: bool = not Combat.legal_targets(_state, unit).is_empty()
	if not can_move and not can_attack:
		return "%s can't act — only %d AP left this turn (End Turn to refresh)." % [unit.type.display_name, ap]
	return "%s: aim at a highlighted tile — blue = move, red outline = attack." % unit.type.display_name


## The producible unit-type roster: the union (deduped, stable order) of every own
## [b]COMPLETED[/b] producer's [code]producible_types[/code] — only types the player
## can produce RIGHT NOW. An under-construction producer contributes nothing (its
## units unlock when it finishes), so the player never cycles to a type they cannot
## yet make. Computed on demand so it grows the turn a Production Outpost completes.
## Empty if the player owns no completed producer.
func _produce_roster() -> Array[UnitTypeDef]:
	var roster: Array[UnitTypeDef] = []
	if _reader == null:
		return roster
	for e: EntityState in _reader.entities():
		if e is StructureState and e.owner == LOCAL_PLAYER:
			var s: StructureState = e as StructureState
			if s.build_status != StructureState.BuildStatus.COMPLETED:
				continue # can't produce from an unfinished structure yet.
			for ut: UnitTypeDef in s.type.producible_types:
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
	_sync_cursor_highlight() # ... and paint it, so the board shows a cursor on turn 1.


# --- Turn loop ---------------------------------------------------------------

## Every commit repaints the board and plays §8.5's state transforms. It
## deliberately does NOT drive the AI — that is owned by the End-Turn path
## ([method try_end_human_turn]), so each [method AITurnDriver.run_ai_turn] runs on
## a clean call stack rather than re-entrantly inside
## [method GameState.apply_action]'s own signal emission.
##
## [b]The three steps are strictly ordered[/b] (Story 008 / S5-06):
## [br]1. [b]Deaths first, BEFORE the sync.[/b] A destroyed entity is already gone
##    from [method GameStateReader.entities], so the sync in step 2 would free its
##    sprite — [method EntitySpriteFeed.power_down] must claim the node first or
##    §8.5's destroyed beat has nothing to play on.
## [br]2. [b]Sync.[/b] Sprites move onto their new tiles and click targets are
##    re-authored.
## [br]3. [b]Motion last, AFTER the sync[/b], so a lean or a lunge is measured from
##    where the actors now are rather than where they were.
func _on_action_applied(result: ActionResult) -> void:
	_dispatch_deaths(result)
	_refresh_open_preview() # the board changed under any open range overlay.
	_refresh_occupant_pick_regions() # entities moved/spawned/died — re-author the click targets.
	_dispatch_motion(result)
	# ★ 2026-08-24 — CR-4's "the menu re-filters for the same entity" (AC-25/AC-12).
	# CommandInterface._reselect_after_commit has already decided whether the actor
	# survives with a legal action left (ENTITY_SELECTED) or the selection collapses
	# (IDLE); this re-reads that decision and re-opens or closes accordingly, so a
	# move->attack chain is one sequence and a unit that dies to a counterattack
	# leaves no menu hanging over an empty tile.
	_clear_placement_preview()
	_close_cost_preview() # the projection just became the real number.
	_open_action_menu()
	_refresh_status() # AP/affordability/selection may have changed.


## Step 1 of [method _on_action_applied]: starts the destroyed beat for everything
## [param result] killed, unit or structure alike (§8.5, art-bible "no gibs").
##
## Must run before the feed syncs — see [method EntitySpriteFeed.power_down].
func _dispatch_deaths(result: ActionResult) -> void:
	if _feed == null:
		return
	for event: Event in result.events:
		if event is UnitDestroyedEvent:
			_feed.power_down((event as UnitDestroyedEvent).entity_id)
		elif event is StructureDestroyedEvent:
			_feed.power_down((event as StructureDestroyedEvent).entity_id)


## Step 3 of [method _on_action_applied]: plays §8.5's move lean and attack/hit
## pair from [param result]'s events.
##
## Narrowing is [code]if e is XEvent[/code] per ADR-0004 — never a match on
## runtime type, and never an hp diff.
##
## A [DamageEvent] drives three things at once on the same frame: the attacker's
## body lunge, its §2.2 glow flare (so light and body spike together, §8.5
## "snappy, synced to the flare"), and the target's recoil. A counterattack
## arrives as its own [DamageEvent] with the roles swapped, so it animates
## correctly with no special case here. Anything killed by the blow was marked
## dying in step 1 and is silently skipped by the feed, so a killing hit reads as
## a power-down rather than a recoil.
func _dispatch_motion(result: ActionResult) -> void:
	if _feed == null or _board == null:
		return
	for event: Event in result.events:
		if event is UnitMovedEvent:
			var moved := event as UnitMovedEvent
			_feed.lean(
				moved.entity_id,
				_board.grid_to_screen(moved.to) - _board.grid_to_screen(moved.from)
			)
		elif event is DamageEvent:
			var hit := event as DamageEvent
			_feed.lunge(hit.attacker_id, hit.target_id)
			_feed.flare(hit.attacker_id)
			_feed.recoil(hit.target_id, hit.attacker_id)


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
## the human's turn. Left-click selects the own unit under the pointer (routed
## through the board's pick-regions, [method select_at_mouse]); mouse wheel zooms
## and middle-drag pans the camera. The cursor
## keys reuse the built-in [code]ui_*[/code] actions; the letter/Tab keys are read
## by keycode. Dedicated, rebindable InputMap actions for all of these are a
## follow-up (the cai-005 InputMap-wiring tech-debt).
## Advances the board glow clock (§8.9). One shared-uniform write per frame for the
## whole board — the per-actor uniforms are event-driven and untouched here.
##
## The glow deliberately keeps breathing during the AI's paced turn: it signals
## "this actor still has AP", which stays true and legible while the opponent moves.
## [member EntitySpriteFeed.glow_paused] is the hook if a real pause screen ever
## needs it frozen.
func _process(delta: float) -> void:
	if _feed == null:
		return
	# ★ Reduced motion is not a stored-but-inert preference: the resting glow's
	# breathe cycle is the slice's one continuous ambient animation, and
	# `EntitySpriteFeed.glow_paused` freezes it at a steady value. Snap-Never-Tween
	# means the glow is reinforcement riding on an instant snap, so freezing it
	# loses no information — which is exactly why
	# `accessibility-requirements.md` calls this row "cheap by design".
	_feed.glow_paused = Settings.settings != null and Settings.settings.reduced_motion
	_feed.advance_glow(delta)


## ★ 2026-08-24 — restructured around the action menu.
##
## Two things changed in kind, not just in detail:
## [br]1. [b]Back-out is checked before pause[/b], and the SAME key does both. See
##    [method back_out] for why that is the resolution to the GDD/pause-spec
##    collision over Esc rather than a hack.
## [br]2. [b]Confirm is context-sensitive[/b] ([method commit_at_cursor]) instead of
##    every verb owning a key. The per-verb actions that remain are accelerators
##    into a preview, not commits.
##
## Direction keys are NOT handled here while the menu holds focus — a focused
## Control consumes them first (ADR-0014 §2), which is exactly what keeps menu
## traversal and board-cursor movement from colliding.
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
		commit_at_cursor()
	elif event.is_action_pressed(&"board_pause"):
		# Back-out FIRST. Esc means "cancel what I am in" whenever there is something
		# to cancel, and "pause" only when there is not (action-menu.md decision 1).
		# Ordering it the other way round would make it impossible to leave a preview
		# from the keyboard without opening the pause overlay on the way.
		if not back_out():
			open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"board_act"):
		open_verb_preview(CommandFSM.Verb.MOVE)
	elif event.is_action_pressed(&"board_attack"):
		open_verb_preview(CommandFSM.Verb.ATTACK)
	elif event.is_action_pressed(&"board_produce"):
		open_produce_picker()
	elif event.is_action_pressed(&"board_build"):
		open_build_picker()
	elif event.is_action_pressed(&"board_end_turn"):
		try_end_human_turn()
	elif event.is_action_pressed(&"board_menu_focus"):
		toggle_menu_focus()
	elif event.is_action_pressed(&"board_cursor_cycle"):
		jump_cursor()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(CAMERA_ZOOM_STEP)      # wheel up: zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / CAMERA_ZOOM_STEP) # wheel down: zoom out (to the fit floor)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			back_out() # the mouse half of CR-1's "right-click or ESC" cancel.
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_camera.position -= event.relative / _camera.zoom # middle-drag: free pan


## Left-click: inside an open preview a click on a highlighted tile COMMITS
## (CR-6's single-click commit); otherwise it selects what was clicked.
##
## The board cursor is moved to the clicked tile first so both paths act on the
## same tile — which is also what keeps the mouse and keyboard from ever
## disagreeing about where "here" is.
func _on_left_click() -> void:
	if _board == null:
		return
	if _in_preview():
		var tile: Vector2i = _board.screen_to_grid(_board.get_local_mouse_position())
		if _state.grid != null and _state.grid.in_bounds(tile.x, tile.y) and _cursor != null:
			_cursor.grid_pos = tile
			_sync_cursor_highlight()
			commit_at_cursor()
		return
	select_at_mouse()


## Whether a preview of any kind is open — the Command & Action Interface's own
## Move/Attack previews or the slice-owned Build/Produce placement previews.
func _in_preview() -> bool:
	if not _preview_tiles.is_empty():
		return true
	match _cmd.fsm_state():
		CommandFSM.State.PREVIEW_MOVE, CommandFSM.State.PREVIEW_ATTACK, \
		CommandFSM.State.PREVIEW_PRODUCE, CommandFSM.State.PREVIEW_BUILD:
			return true
		_:
			return false


## Accelerator: jumps the current selection straight into [param verb]'s preview,
## skipping the menu.
##
## [b]Routes through the same handler the menu row does[/b] — never a second
## implementation — but gated on the verb actually being ENABLED for this entity.
## That gate is what keeps an accelerator honest: a hotkey that could enter a
## preview the menu greys out would be a way to reach an illegal action the UI says
## is unavailable. When the verb is unavailable the menu opens instead, so the
## player is shown WHY rather than being ignored.
func open_verb_preview(verb: int) -> bool:
	if _cmd == null or not _cmd.is_input_live(_state):
		return false
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity == null:
		# Nothing selected: try to select what the cursor is on, then retry once.
		if not select_at_cursor():
			return false
		entity = _state.entities_by_id.get(_cmd.selected_id())
		if entity == null:
			return false
	for entry: CommandFSM.VerbEntry in CommandFSM.menu_model(_state, entity):
		if entry.verb == verb:
			if not entry.enabled:
				_flash_msg("%s unavailable: %s" % [
					ActionMenu.VERB_LABELS.get(verb, "?"), ActionMenu.reason_text(entry.reason)
				])
				_open_action_menu()
				return false
			_action_menu.close()
			_on_menu_verb_chosen(verb)
			return true
	return false


## Accelerator: opens the Produce type submenu for the current selection. Same
## enabled-gate discipline as [method open_verb_preview].
func open_produce_picker() -> bool:
	if _cmd == null or not _cmd.is_input_live(_state):
		return false
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity == null and not select_at_cursor():
		return false
	entity = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is StructureState):
		_flash_msg("Select a producer first — Produce belongs to a structure.")
		return false
	_open_action_menu()
	_action_menu.open_produce_submenu(CommandFSM.produce_options(_state, entity))
	return true


# --- Keyboard board control (works around the blocked click-pick seam) -------# --- Keyboard board control (works around the blocked click-pick seam) -------

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
	if _flash != "":
		_flash = "" # a new cursor move supersedes the last no-op's message.
		_refresh_status()
	_keep_cursor_in_view() # pan the camera if the cursor nears the view edge (zoomed in).
	_sync_cursor_highlight()
	_refresh_cost_preview() # a move's price is per-tile — the echo follows the cursor.
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
	# ★ 2026-08-24 — two changes, both from the action menu.
	#
	# 1. STRUCTURES select too. This used to gate on `entity is UnitState`, so a
	#    Barracks could never be selected and its Produce verb was reachable only
	#    through a global [P] hotkey that guessed which producer the player meant.
	#    CR-3 says you select an entity you own; a producer is one.
	# 2. Selection opens the MENU, not a move preview. Auto-entering PREVIEW_MOVE
	#    was the right stand-in while there was no menu — it put SOMETHING on screen
	#    on select — but it also decided the verb for the player, and it is the
	#    reason Attack needed its own hotkey to be reachable at all. CR-1's loop is
	#    select -> menu -> verb -> preview, and this is the "-> menu" step.
	var entity: EntityState = _state.entity_at(_cursor.grid_pos)
	if entity != null and entity.owner == LOCAL_PLAYER:
		var ok: bool = _cmd.try_select(_state, entity)
		if ok:
			_open_action_menu()
		return ok
	return false


# --- Contextual action menu (design/ux/action-menu.md) -----------------------

## Opens (or re-opens) the action menu on whatever is currently selected.
##
## Called on every selection AND after every commit — CR-4's menu "re-filters for
## the same entity" so a move->attack chain is one sequence rather than a
## re-selection (AC-25/AC-12). Rebuilding is what re-filters it: the rows come
## straight from [method CommandFSM.menu_model] against the now-current AP,
## `has_attacked` and board.
##
## Closes instead of opening when there is nothing to command — no selection, the
## selection is not ours, or it is not our live turn.
func _open_action_menu() -> void:
	if _action_menu == null or _cmd == null or _state == null:
		return
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity == null or entity.owner != LOCAL_PLAYER or not _cmd.is_input_live(_state):
		_action_menu.close()
		return
	_action_menu.open(
		_state, entity, _entity_screen_anchor(entity.position), _screen_tile_width()
	)


## The screen-space point a menu anchors to for an entity standing on [param tile]
## — the tile's own ground anchor, run through the board's canvas transform so the
## camera's pan and zoom are folded in.
##
## [b]The same anchor the sprite uses[/b] ([method BoardRenderer.grid_to_screen]),
## deliberately: a menu that anchored to anything else would drift away from its
## entity the moment the board and the HUD disagreed about where that entity is.
func _entity_screen_anchor(tile: Vector2i) -> Vector2:
	if _board == null:
		return Vector2.ZERO
	return _board.get_global_transform_with_canvas() * _board.grid_to_screen(tile)


## One board tile's CURRENT on-screen width in pixels — the board's constant tile
## width scaled by the live camera zoom. The menu's one-tile clearance is a
## SCREEN-space distance, so it has to follow the zoom; a constant 128 would leave
## the plate overlapping the entity when zoomed out and adrift when zoomed in.
func _screen_tile_width() -> float:
	if _board == null:
		return BoardRenderer.TILE_WIDTH_PX
	var scale_x: float = absf(_board.get_global_transform_with_canvas().get_scale().x)
	return BoardRenderer.TILE_WIDTH_PX * scale_x


## Routes a chosen verb into its preview. Move and Attack use the
## [CommandInterface]'s own preview states; Cancel Build commits directly (see
## below). Produce never arrives here — it opens the submenu instead, and the
## submenu's chosen TYPE is what routes ([method _on_menu_produce_chosen]).
func _on_menu_verb_chosen(verb: int) -> void:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity == null:
		return
	match verb:
		CommandFSM.Verb.MOVE:
			_pending_produce = null
			_pending_build = null
			_cmd.enter_preview(_state, entity, CommandFSM.State.PREVIEW_MOVE)
			_refresh_cost_preview()
			_flash_msg("Move: pick a highlighted tile. Esc to go back.")
		CommandFSM.Verb.ATTACK:
			_pending_produce = null
			_pending_build = null
			_cmd.enter_preview(_state, entity, CommandFSM.State.PREVIEW_ATTACK)
			_refresh_cost_preview()
			_flash_msg("Attack: pick a highlighted target. Esc to go back.")
		CommandFSM.Verb.DISBAND:
			# Reached only on the SECOND press — ActionMenu holds the arm-then-confirm
			# gate for every destructive verb, so by the time this fires the player
			# has activated a row that read "Confirm disband".
			var disband := DisbandAction.new()
			disband.entity_id = entity.entity_id # action.player set by commit.
			_cmd.dispatch_commit(disband, _state)
		CommandFSM.Verb.CANCEL_BUILD:
			# ★ Committed directly rather than through Story 004's timed hold.
			# That hold exists to stop a BARE KEYPRESS destroying a structure by
			# accident. Reaching this row already costs a deliberate two-step —
			# select the structure, then activate a row that says "Cancel Build" —
			# so the accident the hold guards against cannot happen here. The hold
			# gesture stays intact for any direct-input path that wants it.
			var cancel := CancelBuildAction.new()
			cancel.structure_tile = entity.position
			_cmd.dispatch_commit(cancel, _state)


## Routes a chosen produce TYPE into the deploy-tile preview. The type is held in
## [member _pending_produce] until the player picks a tile, because a
## [ProduceAction] needs both and they are chosen in two separate steps.
func _on_menu_produce_chosen(unit_type: UnitTypeDef) -> void:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is StructureState):
		return
	_pending_build = null
	_pending_produce = unit_type
	_cmd.enter_preview(_state, entity, CommandFSM.State.PREVIEW_PRODUCE)
	_preview_tiles = _reader.legal_deploy_tiles(entity.entity_id, unit_type)
	_paint_preview_tiles()
	_snap_cursor_to_preview()
	_refresh_cost_preview()
	_flash_msg("Deploy %s: pick a highlighted tile. Esc to go back." % unit_type.display_name)


## Opens the player-level Build type picker — the HUD Build control's entry point
## (CR-5). Lists every buildable with its live dual cost and disables the ones the
## player cannot place right now, naming which pool or condition fell short.
##
## Anchored to the HUD's Build control rather than to the board: Build has no
## selected entity to float beside, so it opens where the player clicked.
func open_build_picker() -> void:
	if _action_menu == null or not _cmd.is_input_live(_state) or _buildables.is_empty():
		return
	_action_menu.open_build_options(
		CommandFSM.build_options(_state, LOCAL_PLAYER, _buildables),
		_build_control_anchor(),
		_screen_tile_width()
	)


## Screen-space anchor for the Build picker: the TOP-RIGHT corner of the HUD's
## ACTIONS panel. [method ActionMenu._reposition_picker] grows the list up and to
## the left out of that point, so it rises out of the Build button it belongs to
## instead of spilling off the bottom edge or over the status legend.
##
## Derived from [GameHud]'s own bottom-right panel geometry (200 wide at x-216,
## 66 tall at y-82), one corner of which is exactly what this needs.
func _build_control_anchor() -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(view.x - 16.0, view.y - 90.0)


## Enters the player-level Build placement preview for [param type] (CR-5 — Build
## belongs to the player, not to a selected entity, so it is reached from the HUD's
## persistent control rather than from a menu row).
func begin_build_preview(type: StructureTypeDef) -> void:
	if type == null or not _cmd.is_input_live(_state):
		return
	_pending_produce = null
	_pending_build = type
	_preview_tiles = _reader.legal_build_tiles(LOCAL_PLAYER, type)
	_action_menu.close()
	# ★ Drive the FSM before painting. Without this the interface stayed in IDLE for
	# the whole build flow, so commit_at_cursor's match fell through to "select what
	# is under the cursor" and a click on a highlighted build tile did nothing but
	# re-select. enter_build_preview clears the overlay, so the go-tiles are painted
	# after it, never before.
	_cmd.enter_build_preview(_state)
	_paint_preview_tiles()
	_snap_cursor_to_preview()
	_refresh_cost_preview()
	var cost: int = BaseProduction.effective_build_cost(_state, type, LOCAL_PLAYER)
	_flash_msg("Build %s (%d CR + %d AP): pick a highlighted tile. Esc to go back." % [
		type.display_name, cost, Balance.economy.build_ap_cost
	])


## Paints [member _preview_tiles] as the shared build/deploy "go-tile" overlay.
## Routed through [method BoardRenderer.set_overlays] — the sanctioned write path —
## never by touching the overlay layer directly (ADR-0013 §3).
func _paint_preview_tiles() -> void:
	if _board == null:
		return
	_board.set_overlays({BoardRenderer.OverlayClass.BUILD_DEPLOY_GO_TILE: _preview_tiles})


## Moves the cursor onto the nearest legal tile of the open placement preview.
##
## Without this, opening a Build or Produce preview leaves the cursor wherever it
## happened to be — usually not a legal tile — so the very next confirm press does
## nothing and the player has to hunt for a highlighted tile by hand. Snapping is
## the placement equivalent of what cursor-jump does for move and attack.
func _snap_cursor_to_preview() -> void:
	if _cursor == null or _preview_tiles.is_empty():
		return
	if _preview_tiles.has(_cursor.grid_pos):
		return # already somewhere legal — leave the player's own aim alone.
	var from: Vector2i = _cursor.grid_pos
	var best: Vector2i = _preview_tiles[0]
	var best_d: int = absi(best.x - from.x) + absi(best.y - from.y)
	for tile: Vector2i in _preview_tiles:
		var d: int = absi(tile.x - from.x) + absi(tile.y - from.y)
		if d < best_d:
			best = tile
			best_d = d
	_cursor.grid_pos = best
	_cmd.inspect(_state, best)
	_keep_cursor_in_view()
	_sync_cursor_highlight()


## Drives the HUD counters' `current -> projected` echoes off whatever preview is
## open and wherever the cursor is (`command-action-interface.md` D-1/D-1b, the
## GDD's "renders on the HUD's AP counter as inline current -> projected, updating
## live on hover").
##
## [b]One function rather than open/close calls scattered through every verb
## path.[/b] The echo has to be correct after a verb is picked, after every cursor
## step inside a preview, after a commit, after a back-out and after a deselect —
## six callers, and any one of them forgetting to close would leave a stale
## projection sitting on the counter claiming AP the player still has. Recomputing
## from current state at each of those points cannot go stale.
##
## [b]Both pools, together, for economic verbs[/b] (D-1b): Build and Produce spend
## Credits AND AP, and showing one without the other cannot tell the player which
## pool a purchase will exhaust. Move and Attack are AP-only, so the Credit echo is
## closed for them rather than shown at an unchanged value — an echo that says
## "1000 -> 1000" is noise pretending to be information.
func _refresh_cost_preview() -> void:
	if _hud == null or _cmd == null or _state == null:
		return
	if not _cmd.is_input_live(_state):
		_close_cost_preview()
		return
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	match _cmd.fsm_state():
		CommandFSM.State.PREVIEW_MOVE:
			# Per-TILE, not per-verb: a move's price is whatever the cursor is
			# currently resting on, which is exactly the number the player is
			# deciding against. Off the reachable set there is no move to price.
			var reach: Movement.ReachableTile = _cmd.get_reachable_tile(_cursor.grid_pos) \
				if _cursor != null else null
			if reach == null:
				_close_cost_preview()
				return
			_show_ap_preview(reach.min_cost)
			_hud.close_credits_preview()
		CommandFSM.State.PREVIEW_ATTACK:
			if entity == null or _cursor == null or _cmd.get_target(_cursor.grid_pos) == null:
				_close_cost_preview()
				return
			_show_ap_preview(Combat.attack_cost_for(entity))
			_hud.close_credits_preview()
		CommandFSM.State.PREVIEW_PRODUCE:
			if _pending_produce == null:
				_close_cost_preview()
				return
			_show_dual_preview(
				Balance.economy.produce_ap_cost,
				Unit.effective_produce_cost(_state, _pending_produce, LOCAL_PLAYER)
			)
		CommandFSM.State.PREVIEW_BUILD:
			if _pending_build == null:
				_close_cost_preview()
				return
			_show_dual_preview(
				Balance.economy.build_ap_cost,
				BaseProduction.effective_build_cost(_state, _pending_build, LOCAL_PLAYER)
			)
		_:
			_close_cost_preview()


## Opens the AP echo for [param ap_cost]. The projection itself comes from
## [method CommandFSM.projected_remaining_ap] — never a local subtraction, so the
## number on the counter and the number the FSM would report cannot diverge.
func _show_ap_preview(ap_cost: int) -> void:
	_hud.open_ap_preview(
		CommandFSM.projected_remaining_ap(_state, LOCAL_PLAYER, ap_cost),
		AP.can_afford(_state, LOCAL_PLAYER, ap_cost)
	)


## Opens BOTH echoes for a dual-cost economic action (ADR-0006). Each pool reports
## its OWN affordability, so a purchase blocked on Credits shows an unaffordable
## Credit echo next to an affordable AP one — which is precisely CR-8's
## "name the binding pool" rendered on the counters instead of in words.
func _show_dual_preview(ap_cost: int, credit_cost: int) -> void:
	_show_ap_preview(ap_cost)
	_hud.open_credits_preview(
		Credits.current_credits(_state, LOCAL_PLAYER) - credit_cost,
		Credits.can_afford(_state, LOCAL_PLAYER, credit_cost)
	)


## Closes both echoes. Idempotent.
func _close_cost_preview() -> void:
	if _hud == null:
		return
	_hud.close_ap_preview()
	_hud.close_credits_preview()


## Clears any open placement preview's held type and painted tiles. Leaves the
## [CommandInterface]'s own Move/Attack overlays alone — those are its to clear.
func _clear_placement_preview() -> void:
	_pending_produce = null
	_pending_build = null
	if not _preview_tiles.is_empty():
		_preview_tiles = []
		if _board != null:
			_board.clear_overlay()


## Clears the selection and everything hanging off it: the menu, any placement
## preview, and the interface's own preview overlays. The single deselect path —
## Wait, dismissal, clicking empty ground and backing out of the menu all land here
## so none of them can leave a fragment of the previous selection on screen.
func deselect() -> void:
	_close_cost_preview()
	_clear_placement_preview()
	if _action_menu != null:
		_action_menu.close()
	if _cmd != null:
		_cmd.deselect(_state)
	_refresh_status()


## Stands the selected entity down for the turn, then deselects.
##
## The mark is ADVISORY (user decision, 2026-08-25): it changes what the interface
## offers, never what the rules allow. See [member UnitState.stood_down].
func _on_menu_waited() -> void:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity != null and entity.owner == LOCAL_PLAYER and _cmd.is_input_live(_state):
		var action := WaitAction.new()
		action.entity_id = entity.entity_id # action.player set by CommandInterface.commit.
		_cmd.dispatch_commit(action, _state)
	deselect()


## Every tile holding one of the local player's entities that still has something
## to do — the cycle set for [method jump_cursor] when no preview is open.
##
## Sorted by entity id so repeated presses walk a stable ring rather than
## reshuffling as the board changes.
func _idle_entity_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if _reader == null:
		return tiles
	var ids: Array[int] = []
	for entity: EntityState in _reader.entities():
		if entity.owner != LOCAL_PLAYER or _reader.is_stood_down(entity):
			continue
		if _is_entity_actionable(entity):
			ids.append(entity.entity_id)
	ids.sort()
	for id: int in ids:
		var e: EntityState = _state.entities_by_id.get(id)
		if e != null:
			tiles.append(e.position)
	return tiles


## Steps back one level: submenu -> menu -> selection -> nothing. Returns whether
## anything was backed out of.
##
## [b]This return value is what lets Esc mean two things without ambiguity[/b]
## (`design/ux/action-menu.md`, decision 1). The GDD binds back-out to Esc; the
## pause spec binds pause to Esc; both are right about their own surface. Esc
## consults this first, and only opens pause when it returns false — i.e. when
## there was genuinely nothing to cancel. A player mid-preview can never
## accidentally pause, and a player doing nothing can always pause.
func back_out() -> bool:
	if _action_menu != null and _action_menu.is_submenu_open():
		return _action_menu.back_out()
	# A placement preview and a Move/Attack preview both back out to the menu.
	var had_placement: bool = not _preview_tiles.is_empty()
	_clear_placement_preview()
	if _cmd != null and _cmd.back_out_preview(_state):
		_close_cost_preview() # nothing is being priced any more.
		_open_action_menu()
		_flash = ""
		_refresh_status()
		return true
	if had_placement:
		_close_cost_preview()
		_open_action_menu()
		_flash = ""
		_refresh_status()
		return true
	if _action_menu != null and _action_menu.is_open():
		return _action_menu.back_out() # emits dismissed -> deselect()
	if _cmd != null and _cmd.deselect(_state):
		_refresh_status()
		return true
	return false


## Commits whatever the OPEN PREVIEW means at the cursor tile.
##
## ★ 2026-08-24 — replaces [method act_at_cursor]'s guess. That method inspected
## the cursor tile and chose Attack if a target was there, else Move: one input
## meaning two verbs, with the interface deciding which. It worked, but it could
## never explain itself, and it made "attack the thing you are standing next to"
## and "move onto that tile" the same gesture. With the menu, the player has
## already said which verb they are in, so this only has to honour it.
##
## Returns whether an action was dispatched.
func commit_at_cursor() -> bool:
	if _cursor == null or _cmd == null or not _cmd.is_input_live(_state):
		return false
	_flash = ""
	var tile: Vector2i = _cursor.grid_pos
	match _cmd.fsm_state():
		CommandFSM.State.PREVIEW_MOVE:
			return _commit_move(tile)
		CommandFSM.State.PREVIEW_ATTACK:
			return _commit_attack(tile)
		CommandFSM.State.PREVIEW_PRODUCE:
			return _commit_produce(tile)
		CommandFSM.State.PREVIEW_BUILD:
			return _commit_build(tile)
		_:
			# No preview open: confirm means "select what is under the cursor".
			return select_at_cursor()


## Commits a [MoveAction] onto [param tile] when it is in the open move preview.
func _commit_move(tile: Vector2i) -> bool:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is UnitState):
		return false
	var unit: UnitState = entity as UnitState
	var reach: Movement.ReachableTile = _cmd.get_reachable_tile(tile)
	if reach == null:
		_flash_msg("Not a reachable tile — pick a highlighted one, or Esc to go back.")
		return false
	var mv := MoveAction.new()
	mv.from = unit.position
	mv.to = tile
	# tiles_entered is the TILE COUNT (input to move_path_cost), NOT the AP cost —
	# reach.min_cost is the AP cost. They coincide only for move_cost-1 units; for
	# the rest the raw min_cost overstates the count and validate_move rejects it.
	mv.tiles_entered = _tiles_for_cost(unit, reach.min_cost)
	return _cmd.dispatch_commit(mv, _state)


## Commits an [AttackAction] onto [param tile] when it holds a legal target.
func _commit_attack(tile: Vector2i) -> bool:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity == null:
		return false
	if _cmd.get_target(tile) == null:
		_flash_msg("Not a legal target — pick a highlighted one, or Esc to go back.")
		return false
	var atk := AttackAction.new()
	atk.attacker_tile = entity.position
	atk.target_tile = tile
	return _cmd.dispatch_commit(atk, _state)


## Commits a [ProduceAction] of [member _pending_produce] onto [param tile].
func _commit_produce(tile: Vector2i) -> bool:
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is StructureState) or _pending_produce == null:
		return false
	if not _preview_tiles.has(tile):
		_flash_msg("Not a legal deploy tile — pick a highlighted one, or Esc to go back.")
		return false
	var action := ProduceAction.new()
	action.producer_id = entity.entity_id
	action.unit_type = _pending_produce
	action.tile = tile # action.player is set by CommandInterface.commit.
	return _cmd.dispatch_commit(action, _state)


## Commits a [BuildAction] of [member _pending_build] onto [param tile].
func _commit_build(tile: Vector2i) -> bool:
	if _pending_build == null:
		return false
	if not _preview_tiles.has(tile):
		_flash_msg("Not a legal build tile — pick a highlighted one, or Esc to go back.")
		return false
	var action := BuildAction.new()
	action.structure_type = _pending_build
	action.tile = tile # action.player is set by CommandInterface.commit.
	return _cmd.dispatch_commit(action, _state)


## Mouse click-select (scope §8 seam b): resolves the click through the Command &
## Action Interface's ONE routing entry point — [method CommandInterface.route_click]
## → [method BoardRenderer.pick_at] against the authored occupant pick-regions, NEVER
## [method BoardRenderer.screen_to_grid] directly (the ADR-0013 §4 CAI boundary).
## Clicking an own unit pins it (detail panel + move/attack range), exactly like the
## keyboard [method select_at_cursor]. The board-cursor is synced to the picked tile
## (when in bounds) so keyboard control continues from where the mouse last acted and
## the two input paths never disagree on "where we are". Click-to-MOVE (a committed
## action from a click) stays Story 007 scope — this closes selection only. Returns
## whether the click left an own unit selected.
##
## The board is a child Node2D under the framing camera, and pick_at works in the
## board's local space (the space grid_to_screen and the pick-regions live in), so
## [method Node2D.get_local_mouse_position] folds in the camera zoom/pan for free.
## The actual routing lives in [method select_at_board_point] (a testable seam that
## takes an explicit board-space point, since the live mouse position is not settable
## headlessly).
func select_at_mouse() -> bool:
	if _board == null:
		return false
	return select_at_board_point(_board.get_local_mouse_position())


## Click-select at an explicit board-local point (the injectable core of
## [method select_at_mouse]). See that method for the full contract.
func select_at_board_point(board_pos: Vector2) -> bool:
	if _board == null or _cmd == null or _state == null:
		return false
	var pick: Object = _cmd.route_click(board_pos, _state)
	if pick == null:
		return false
	# route_click returns the raw pick whether or not it selected; reflect it in the
	# keyboard cursor + detail panel so the two input paths stay in lockstep.
	if _cursor != null and _state.grid != null \
			and _state.grid.in_bounds(pick.tile.x, pick.tile.y):
		_cursor.grid_pos = pick.tile
		_cmd.inspect(_state, pick.tile) # peek the picked tile into the detail panel.
		if _flash != "":
			_flash = ""
			_refresh_status()
		_keep_cursor_in_view()
	# Mouse select opens the same action menu the keyboard path does, so the two
	# input routes never disagree about what is on screen after a selection.
	var picked: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if picked != null and picked.owner == LOCAL_PLAYER:
		_open_action_menu()
	else:
		# Clicking empty terrain or something not yours clears the selection (CR-3).
		deselect()
	return pick.occupant_entity_id != -1 and _cmd.selected_id() == pick.occupant_entity_id


## Whether the match ended by HQ destruction rather than by the round cap — used only
## to word the end-of-match status line. True when either HQ is missing from the live
## entity set, which is what [method GameState.destroy_entity] leaves behind.
func _hq_destroyed() -> bool:
	if _state == null:
		return false
	for player: int in 2:
		var hq: EntityState = _state.entities_by_id.get(player)
		if hq == null:
			return true
	return false


## Whether [param entity] can still be used this turn — the Pillar-1 "can this
## actor act?" read feeding [member EntitySpriteFeed.actionable_predicate], which
## drives both the glow state and (since Story 010) the body tint.
##
## A [UnitState] is actionable while its owner can afford the cheapest option still
## open to it: moving (always available — the cap is soft, so a moved unit can move
## again at a surcharge) or attacking, if it has not already attacked this turn.
## Because [member UnitTypeDef.move_cost] varies across the roster this genuinely
## discriminates between units rather than dimming a whole army at once.
##
## A [StructureState] that can shoot follows the same rule against its own
## once-per-turn attack; one that cannot shoot never dims, because it is a fixture
## rather than an actor with a turn allowance and dimming it would say nothing.
##
## [b]Not a legality check.[/b] It deliberately does not ask whether any legal move
## target or attack target exists — that is O(reachable) per actor per refresh, and
## a unit boxed in by its own squad is still "yours to use", not spent. Affordability
## is the honest cheap approximation; a fully accurate version would be a legality
## query and is not worth the cost on a per-frame-adjacent path.
func _is_entity_actionable(entity: EntityState) -> bool:
	if _reader == null:
		return true # unwired: breathe rather than sit inert (feed's own default).
	# ★ 2026-08-25 — a stood-down entity stops breathing whatever it could still
	# legally do. This is the mark's most visible payoff: at a glance the board
	# shows what the player has dealt with and what is still waiting on them, which
	# is the read the glow existed to give and could not while "actionable" meant
	# only "has AP and a legal target".
	if _reader.is_stood_down(entity):
		return false
	# ★ Structures are resolved BEFORE the empty-pool check, deliberately. A
	# non-combat structure is a fixture with no turn allowance, so it must stay lit
	# even at 0 AP — dimming it says nothing true, and both HQs are a large share of
	# the board's visual mass, so darkening them at every end of turn would
	# re-create most of the whole-board flattening this predicate replaced.
	if entity is StructureState:
		var structure := entity as StructureState
		if structure.type == null or structure.type.attack <= 0:
			return true
		# One that CAN shoot does have a once-per-turn allowance, and follows it.
		return not structure.has_attacked \
			and _reader.current_ap(entity.owner) >= Combat.attack_cost_for(structure)
	if entity is UnitState:
		var unit := entity as UnitState
		if unit.type == null:
			return true
		var ap: int = _reader.current_ap(entity.owner)
		if ap <= 0:
			return false
		var cheapest: int = unit.type.move_cost
		if not unit.has_attacked:
			cheapest = mini(cheapest, Combat.attack_cost_for(unit))
		return ap >= cheapest
	return true


## Rebuilds the board's occupant pick-regions from the live entities## Rebuilds the board's occupant pick-regions from the live entities so a left-click
## resolves to the occupant on that tile (scope §8 seam b, consumed by
## [method BoardRenderer.pick_at]). Each region is the occupant tile's screen-space
## AABB, authored back-to-front (ascending screen Y — the Y-sort paint order) so
## pick_at's front-most-wins overlap rule (it tests regions in reverse) resolves a
## tie to the occupant nearest the camera. Placeholder-era sizing: the tile diamond's
## box, matching the markers [method _draw] paints; the real entity renderer (S4-03)
## re-authors these from actual sprite bounds. Refreshed on every commit
## ([method _on_action_applied]) since entities move, spawn, and die.
func _refresh_occupant_pick_regions() -> void:
	if _board == null or _reader == null or _feed == null:
		return
	# Sync the sprites FIRST, then author the click targets from their actual drawn
	# bounds — the regions must describe what is on screen right now, and a sprite
	# is wider/taller than the tile diamond the placeholder markers used.
	_feed.sync(_reader.entities())
	_board.occupant_pick_regions = _feed.pick_regions()


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
	_flash = ""
	var type: StructureTypeDef = _buildables[_selected_buildable]
	var tile: Vector2i = _cursor.grid_pos
	if not _reader.legal_build_tiles(LOCAL_PLAYER, type).has(tile):
		_flash_msg("Can't build %s here — move the cursor onto an empty tile next to something you own." % type.display_name)
		return false
	if not _reader.can_afford_build(LOCAL_PLAYER, type):
		_flash_msg("Can't afford %s (%d AP) — End Turn to refresh AP." % [type.display_name, BaseProduction.effective_build_cost(_state, type, LOCAL_PLAYER)])
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
	_flash = ""
	var utype: UnitTypeDef = selected_produce_type()
	if utype == null:
		_flash_msg("No completed producer yet — build a Production Outpost and wait for it to finish.")
		return false
	var tile: Vector2i = _cursor.grid_pos
	for e: EntityState in _reader.entities():
		if not (e is StructureState) or e.owner != LOCAL_PLAYER:
			continue
		var producer: StructureState = e as StructureState
		if producer.build_status != StructureState.BuildStatus.COMPLETED:
			continue # unfinished structure can't produce (validate_produce's
			         # NOT_COMPLETED gate) — skip so it never blocks a ready producer.
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
	# No completed producer could deploy the selected type at the cursor.
	var afford: bool = _reader.can_afford_produce(LOCAL_PLAYER, utype)
	if not afford:
		_flash_msg("Can't afford %s (%d AP) — End Turn to refresh AP." % [utype.display_name, Unit.effective_produce_cost(_state, utype, LOCAL_PLAYER)])
	else:
		_flash_msg("Put the cursor on an empty tile next to a completed producer that makes %s." % utype.display_name)
	return false


## Move-or-attack at the cursor in ONE call: enters whichever preview the cursor
## tile supports and commits there, Attack taking priority when the tile holds a
## legal target.
##
## ★ 2026-08-24 — this used to be a keyboard verb ([M]) and its own commit path.
## The action menu retired it as a verb: "move or attack, whichever fits" is a
## guess the interface makes on the player's behalf and cannot explain, which is
## exactly what CR-4's separate Move and Attack rows exist to replace. It survives
## as a THIN WRAPPER over [method open_verb_preview] + [method commit_at_cursor],
## with no legality logic of its own, because the whole-turn tests and the capture
## harness drive a move or an attack in one step and rewriting them to open a
## preview by hand would test the harness rather than the game.
##
## Returns whether an action was dispatched.
func act_at_cursor() -> bool:
	if _cursor == null or _cmd == null or not _cmd.is_input_live(_state):
		return false
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if not (entity is UnitState) or entity.owner != LOCAL_PLAYER:
		_flash_msg("Select your unit first, then pick Move or Attack.")
		return false
	var unit: UnitState = entity as UnitState
	var tile: Vector2i = _cursor.grid_pos
	var verb: int = CommandFSM.Verb.MOVE
	for target: Combat.TargetResult in Combat.legal_targets(_state, unit):
		if target.tile == tile:
			verb = CommandFSM.Verb.ATTACK
			break
	if not open_verb_preview(verb):
		return false
	return commit_at_cursor()


## Recovers the tile count whose [method Movement.move_path_cost] equals
## [param ap_cost] (a [member Movement.ReachableTile.min_cost]) — the inverse the
## [MoveAction] needs for its [member MoveAction.tiles_entered]. Linear search over
## the monotonic cost function, mirroring the AI's own conversion. Falls back to 1.
func _tiles_for_cost(unit: UnitState, ap_cost: int) -> int:
	var tiles: int = 1
	while tiles <= unit.type.soft_move_cap + unit.tiles_moved_this_turn + 64:
		var c: int = Movement.move_path_cost(unit, tiles)
		if c == ap_cost:
			return tiles
		if c > ap_cost:
			break
		tiles += 1
	return 1


# --- Board-space affordance drawing — REMOVED 2026-08-24 ---------------------
#
# ★ This node used to draw the selected unit's move range, its attack targets and
# a ring on the unit itself in `_draw()`. None of it was ever visible.
#
# `_board` is a CHILD of this node, and a CanvasItem paints ITSELF BEFORE its
# children — so everything drawn here rendered underneath all four of the board's
# TileMapLayers. The same defect hid the board cursor (fixed the same day). It is
# an easy one to keep making: the code looks correct, runs every frame, and
# produces pixels that are simply covered.
#
# Range preview now goes through the path that already owns it:
# `CommandInterface.enter_preview()` -> `_render_overlays()` ->
# `BoardRenderer.set_overlays()`, painting on the board's own overlay layer.
# That is strictly better than what was here, and not only because it is visible:
#
#   - it separates IN-CAP from OVER-CAP move tiles, so the player can see where
#     the AP surcharge starts. The old flat fill drew both the same colour and
#     hid the single most Pillar-1-relevant thing about a move.
#   - it adds the after-move-attack echo, showing which tiles let the unit still
#     shoot after moving.
#   - it re-issues automatically on `action_applied` (ADR-0015 §3), so the
#     overlay tracks a changing board instead of going stale until reselect.
#
# The cursor moved to `BoardRenderer.set_cursor()` on its own layer for the same
# reason. Nothing should be drawn in this node's `_draw()` again — if it must
# appear over the board, it belongs on a layer inside the board.


## Moves keyboard/gamepad focus between the board and the HUD's action controls,
## and returns whether focus now sits on the menu.
##
## ★ This is what makes the menu reachable on a pad at all. ADR-0014 §2 arbitrates
## board-cursor vs menu traversal structurally: a focused [Control] consumes a
## direction press before [method _unhandled_input] sees it, so the two can never
## collide — but the flip side is that with NOTHING focused every direction goes to
## the board, and a controller has no way to reach a button. A mouse can just click
## one; a pad needs this.
##
## Deliberately a TOGGLE rather than a one-way grab: a player who focuses the menu
## must be able to get back to the board with the same button they arrived on.
## Being stuck in a two-button panel with no way out is the worst version of this
## feature, and it is the easy one to ship.
func toggle_menu_focus() -> bool:
	if _hud == null or _hud.controls() == null:
		return false
	var controls: HudControlsWidget = _hud.controls()
	if controls.has_menu_focus():
		controls.release_menu_focus()
		_sync_cursor_highlight() # the board is driving again — show it.
		return false
	return controls.focus_first()


## Opens the pause overlay and freezes the match beneath it.
##
## ★ Freeze is [b]engine pause[/b] (`get_tree().paused`), not a hand-rolled input
## flag, which answers `pause.md`'s open questions 2 and 3 in one move: input stops
## reaching this node, tweens and timers stop, and no wall-clock state can desync
## across the pause. The overlay itself runs with
## [constant Node.PROCESS_MODE_WHEN_PAUSED] so it stays interactive.
##
## The AI's commit pacing needed a matching fix — [SceneTree] timers default to
## `process_always = true`, so with the default the opponent went on taking its
## turn behind the overlay. See [method AITurnDriver.run_ai_turn].
func open_pause() -> void:
	if _pause == null or _pause.is_open():
		return
	_pause.open()
	get_tree().paused = true


## Un-freezes and returns to the exact prior match state. No state was written
## while paused, so there is nothing to reconcile — resuming is only un-pausing.
func resume_from_pause() -> void:
	get_tree().paused = false


## Discards the match and reloads the slice from turn 1 (pause.md "Restart
## Skirmish"). Un-pauses FIRST: a reloaded scene inherits a paused tree, and the
## fresh match would open frozen with no overlay to un-freeze it.
func restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Abandons the match and returns to the main menu (pause.md "Quit to Main Menu").
## Un-pauses for the same reason as [method restart_match].
func quit_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Builds the pause overlay on its own [CanvasLayer], above the HUD's, so nothing
## in the HUD can ever draw over the thing that is meant to be modal.
func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(layer)
	_pause = PauseMenu.new()
	layer.add_child(_pause)
	_pause.resume_requested.connect(resume_from_pause)
	_pause.restart_requested.connect(restart_match)
	_pause.quit_to_menu_requested.connect(quit_to_main_menu)


## Jumps the board cursor to the next highlighted tile, wrapping at the end.
##
## ★ [method BoardCursor.jump_to_next] has existed, implemented and unit-tested,
## since ADR-0014 — and NOTHING CALLED IT. The action was declared in
## `project.godot` and handled nowhere, so the feature was present in every layer
## except the one that runs. That is the second hook found dead this way (the first
## was `CommandInterface.notify_action_applied`); both were invisible because a
## unit test proves a function works, not that anything invokes it.
##
## It matters most on a gamepad: stepping a cursor one tile at a time across a
## 12x10 board to reach the far edge of a move range is the slowest thing a pad
## player does, and this is the shortcut. The candidate set comes from
## [method CommandInterface.salient_tiles], so a jump can only ever land on a tile
## that is already highlighted.
##
## A no-op outside a preview (nothing is highlighted, so there is nothing to jump
## between) and a no-op when the cursor is the only candidate.
func jump_cursor() -> bool:
	if _cursor == null or _cmd == null or _state.grid == null:
		return false
	var candidates: Array[Vector2i] = _cmd.salient_tiles()
	if candidates.is_empty():
		# ★ 2026-08-25. Outside a preview the salient set is empty, so this key did
		# nothing at all — it only ever worked mid-Move or mid-Attack. It now walks
		# the player's own entities that still have something to do, which is the
		# question a player actually asks between commands ("what have I not moved
		# yet?"). Entities stood down with Wait are skipped: that is the mark's
		# whole purpose, and without a skip the ring would keep offering back the
		# very units the player just said they were finished with.
		candidates = _idle_entity_tiles()
	if candidates.is_empty():
		return false
	var before: Vector2i = _cursor.grid_pos
	_cursor.jump_to_next(candidates, _state.grid)
	if _cursor.grid_pos == before:
		return false
	_cmd.inspect(_state, _cursor.grid_pos) # peek the new tile, as a step would
	_keep_cursor_in_view()
	_sync_cursor_highlight()
	return true


## Paints the board cursor at its current tile.
##
## The single call site for cursor rendering — every path that moves the cursor
## ends here, so the highlight cannot drift from [member BoardCursor.grid_pos].
## Delegates to [method BoardRenderer.set_cursor], which owns its own TileMapLayer
## precisely so an open move/attack preview cannot clear it.
func _sync_cursor_highlight() -> void:
	if _board == null or _cursor == null:
		return
	_board.set_cursor(_cursor.grid_pos)


## Re-issues the open range overlay after a commit, so it reflects the board that
## now exists rather than the one that did when the unit was selected.
##
## ★ [method CommandInterface.notify_action_applied] is the hook ADR-0015 §3
## specifies for exactly this ("the reachable overlay reflects the new board
## state... no reselect trick") and it had NO CALLER anywhere in the project — it
## was documented, implemented, tested, and never wired. That was harmless only
## while nothing held a preview open; now that selecting a unit opens its move
## preview, an unrefreshed overlay would show a moved unit's PRE-move reach until
## the player reselected it.
##
## A no-op when nothing is selected, when the selection is not an own unit, or
## when the selected unit is what just died.
func _refresh_open_preview() -> void:
	if _cmd == null or _state == null:
		return
	var entity: EntityState = _state.entities_by_id.get(_cmd.selected_id())
	if entity is UnitState and entity.owner == LOCAL_PLAYER:
		_cmd.notify_action_applied(_state, entity as UnitState)


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
