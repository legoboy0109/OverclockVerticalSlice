## HudControlsWidget — the HUD-hosted Build + End-Turn controls with turn-scoped
## inertness (ADR-0016 §8 + ADR-0014, TR-hud-015/017). The controls' PLACEMENT is
## HUD-owned; their interaction routes to CAI / the turn manager.
##
## [b]Build button[/b] (TR-hud-015): reads [method GameStateReader.can_afford_build]
## across the buildable structure types and is DIMMED (never hidden) when none are
## affordable; activating it opens structure selection in EITHER state (AC-16). It
## holds a pressed/active cue while CAI's [constant CommandFSM.State.PREVIEW_BUILD]
## is live (subscribed outward-in via [method attach_interface] — CAI never calls
## in). Reads affordability verbatim, never re-derives a cost (Pass-Through).
##
## [b]Turn-scoped inertness[/b] (TR-hud-017): Build + End Turn are interactive only
## during the LOCAL player's Action phase. Outside it (opponent turn, the EndTurn(P)
## transient — captured as [code]active_player[/code] flipping away — or GameOver)
## they render but are inert: [method controls_focus_mode] returns
## [constant Control.FOCUS_NONE] (ADR-0014 — not a hand-rolled per-frame focus-ring
## suppression), and [method request_build]/[method request_end_turn] are hard
## no-ops (no [code]apply_action[/code], no state change, AC-18/27). Readouts stay
## live regardless.
##
## [b]Testable model[/b]: [method controls_live]/[method build_affordable]/
## [method build_pressed_cue]/[method controls_focus_mode] + the gated
## [method request_build]/[method request_end_turn] are the blocking Integration
## surface; the button chrome / dual-focus StyleBoxes are advisory UI.
##
## Usage:
## [codeblock]
## var controls := HudControlsWidget.new()
## controls.bind(reader)
## controls.configure(HudBalance.hud, local_player)
## controls.attach_interface(command_interface)   # PREVIEW_BUILD cue (outward-in)
## hud_layer.add_child(controls)
## [/codeblock]
class_name HudControlsWidget
extends HudReactiveControl

## Emitted when the player activates Build — by click, keyboard or gamepad. The
## widget never acts on it; the owning scene routes it, exactly as it already
## routes the keyboard path.
signal build_requested
## Emitted when the player activates End Turn, from any input method.
signal end_turn_requested

## ★ Real [Button] children since 2026-08-24. These were `draw_string` calls: the
## HUD rendered the words "Build" and "End Turn" and NOTHING could activate them —
## not a mouse click, not a key, not a pad. `request_build()` had no caller outside
## the test suite. ADR-0014 §6 makes interactive Controls the project convention
## precisely because a real Control brings click focus, keyboard focus, focus
## traversal and the theme's own focus/hover StyleBoxes with it, none of which can
## be retrofitted onto drawn text.
var _build_button: Button = null
var _end_turn_button: Button = null

## The non-blocking "you still have things to do" notice above End Turn
## (`design/ux/action-menu.md`; the GDD's long-planned unspent-AP reminder, made
## workable for ENTITIES by the Wait verb's stand-down mark).
##
## [b]A notice, never a gate.[/b] It never disables End Turn and never opens a
## dialog — a player who wants to end a turn with idle units may always do so, and
## in a tactics game that is often correct play (holding position, baiting). It
## exists because forgetting a unit is a different thing from choosing to hold it,
## and before the stand-down mark the interface could not tell them apart either.
var _idle_notice: Label = null

## Width the idle notice is right-aligned within — the ACTIONS panel's content
## width ([constant HudPanel.PAD_X] either side of its 200px plate).
const IDLE_NOTICE_WIDTH_PX: float = 200.0 - HudPanel.PAD_X * 2.0

## How many of the local player's entities still have something to do, as of the
## last refresh. Recomputed on every [signal GameState.action_applied]; -1 before
## the first bind.
var _idle_count: int = -1

var _config: HUDConfig = null
var _local_player: int = 0

## The build-preview state source, held ONLY to read [method CommandInterface.fsm_state]
## for the Build pressed cue (outward-in — never called into). Duck-typed to
## [code]fsm_state() -> int[/code] (production value: a [CommandInterface]) so a
## lightweight stub works in tests without depending on CAI's internals.
var _cmd: Object = null

## The structure types the Build button offers (affordability is checked across
## them). Defaults to the non-HQ buildables; injectable for tests/tuning.
var _buildable_types: Array[StructureTypeDef] = []


func configure(config: HUDConfig, local_player: int, buildable_types: Array[StructureTypeDef] = []) -> void:
	_config = config
	_local_player = local_player
	_buildable_types = buildable_types if not buildable_types.is_empty() else _default_buildable_types()
	_ensure_buttons()


## Creates the two interactive controls, once. Focus traversal is wired between
## them (ADR-0014 §6: `focus_neighbor_*`, not hand-rolled arbitration), so a pad or
## keyboard moves between them with the same directions that drive the board — the
## engine's own input-consumption order decides which of the two is listening, and
## no "who owns this keypress" flag is needed anywhere.
func _ensure_buttons() -> void:
	if _build_button != null:
		return
	_build_button = _make_button("Build", "BuildButton", Vector2(0, 0))
	_end_turn_button = _make_button("End Turn", "EndTurnButton", Vector2(76, 0))
	_build_button.pressed.connect(func() -> void:
		if request_build():
			build_requested.emit())
	_end_turn_button.pressed.connect(func() -> void:
		if request_end_turn():
			end_turn_requested.emit())
	# Linear order in both axes: the two sit side by side, and a player pushing
	# up/down on a pad expects to stay put rather than fall out of the group.
	#
	# ★ RELATIVE sibling paths, not `get_path()`. `configure()` (which calls this)
	# can run BEFORE the widget enters the scene tree, and `get_path()` on a node
	# outside the tree does not yield a path that resolves later — the neighbours
	# silently pointed at nothing and traversal did not work at all. A relative path
	# is resolved when focus actually moves, so it does not care when it was set.
	_build_button.focus_neighbor_right = NodePath("../EndTurnButton")
	_end_turn_button.focus_neighbor_left = NodePath("../BuildButton")
	_build_button.focus_next = NodePath("../EndTurnButton")
	_end_turn_button.focus_previous = NodePath("../BuildButton")

	# The idle notice sits ABOVE the two buttons, inside the same panel. Not
	# focusable and not clickable: it is information about the turn, not a control,
	# and putting it in the traversal order would make a gamepad player tab through
	# a label to reach End Turn.
	_idle_notice = Label.new()
	_idle_notice.name = "IdleNotice"
	# Sits on the panel's TITLE line, right-aligned — "ACTIONS" on the left, the
	# count opposite it. Placed there rather than above the buttons because that
	# space belongs to HudPanel's title (CONTENT_TOP = 26) and the two overlapped:
	# the notice printed straight through the word ACTIONS. Right-aligning costs the
	# panel no extra height, which matters because it is corner-anchored and growing
	# it would push it into the board.
	_idle_notice.position = Vector2(0, -19)
	_idle_notice.size = Vector2(IDLE_NOTICE_WIDTH_PX, 14)
	_idle_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_idle_notice.add_theme_font_size_override("font_size", 11)
	_idle_notice.add_theme_color_override("font_color", Color(0.72, 0.68, 0.52))
	_idle_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_notice.focus_mode = Control.FOCUS_NONE
	add_child(_idle_notice)


func _make_button(text: String, node_name: String, at: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.position = at
	b.custom_minimum_size = Vector2(72, 26)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 12)
	add_child(b)
	return b


## Moves keyboard/gamepad focus onto the first control in the group. The entry
## point a pad uses to reach the menu at all — with no Control focused every
## direction press goes to the board cursor (ADR-0014 §2), which is correct and
## also means something has to hand focus over deliberately.
func focus_first() -> bool:
	if _build_button == null or not controls_live():
		return false
	_build_button.grab_focus()
	return true


## True while either control holds keyboard/gamepad focus — the owning scene reads
## this to know whether the board or the menu is currently being driven.
func has_menu_focus() -> bool:
	if _build_button == null:
		return false
	return _build_button.has_focus() or _end_turn_button.has_focus()


## Releases menu focus, handing every direction press back to the board cursor.
## Named `release_menu_focus` rather than `release_focus` — the latter is a native
## Control method, and shadowing it is a parse error under this project's
## warnings-as-errors setting.
func release_menu_focus() -> void:
	if _build_button != null and _build_button.has_focus():
		_build_button.release_focus()
	if _end_turn_button != null and _end_turn_button.has_focus():
		_end_turn_button.release_focus()


## Reads CAI's [constant CommandFSM.State.PREVIEW_BUILD] for the Build pressed
## cue — outward-in, one-way (CAI never depends on this widget). [param cmd] is
## duck-typed to [code]fsm_state() -> int[/code] (production: a [CommandInterface]).
func attach_interface(cmd: Object) -> void:
	_cmd = cmd


func _default_buildable_types() -> Array[StructureTypeDef]:
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


func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


# --- Display / interaction model (Integration-testable) ----------------------

## True iff the controls are interactive right now — the local player's Action
## phase (their turn AND the match is not over). Any other state is inert.
func controls_live() -> bool:
	if _reader == null or _reader.match_status() == GameState.MatchStatus.GAME_OVER:
		return false
	return _reader.active_player() == _local_player

## True iff at least one buildable structure type is currently affordable — the
## Build button is enabled iff this, dimmed-but-present otherwise (AC-16).
func build_affordable() -> bool:
	if _reader == null:
		return false
	for t: StructureTypeDef in _buildable_types:
		if _reader.can_afford_build(_local_player, t):
			return true
	return false

## True while CAI's build-preview is live (the Build button's pressed/active cue).
func build_pressed_cue() -> bool:
	return _cmd != null and _cmd.fsm_state() == CommandFSM.State.PREVIEW_BUILD

## The focus_mode the interactive controls carry: [constant Control.FOCUS_ALL]
## when live, [constant Control.FOCUS_NONE] when inert (ADR-0014 dual-focus).
func controls_focus_mode() -> int:
	return Control.FOCUS_ALL if controls_live() else Control.FOCUS_NONE


## Build activation. Returns true (opens structure selection — in EITHER
## affordable/dimmed state, AC-16) iff the controls are live; a hard no-op
## returning false when inert (AC-18/27) — no apply_action, no state change here.
func request_build() -> bool:
	return controls_live()

## End-Turn activation. Returns true (the caller routes the EndTurn commit to the
## turn manager) iff live; a hard no-op returning false when inert (AC-18/27).
func request_end_turn() -> bool:
	return controls_live()


## Pushes the live/inert and affordability state onto the real controls.
##
## ★ [method controls_focus_mode] already computed FOCUS_ALL vs FOCUS_NONE and
## NOTHING APPLIED IT — the value was returned to tests and dropped on the floor.
## ADR-0014 §6 requires present-but-inert controls to set `focus_mode = FOCUS_NONE`
## rather than suppressing a focus ring per frame; that is what this does. Without
## it a pad could focus End Turn during the opponent's turn and press it.
func _sync_button_state() -> void:
	if _build_button == null:
		return
	var live: bool = controls_live()
	var mode: int = controls_focus_mode()
	_build_button.focus_mode = mode
	_end_turn_button.focus_mode = mode
	_build_button.disabled = not live
	_end_turn_button.disabled = not live
	if not live:
		release_menu_focus() # never leave focus parked on an inert control
	# Affordability is advisory, not a lock: AC-16 keeps Build openable while
	# unaffordable so the player can still see WHAT they cannot afford.
	_build_button.modulate = Color.WHITE if build_affordable() else Color(0.62, 0.62, 0.66)
	_build_button.button_pressed = build_pressed_cue()


func _draw() -> void:
	# Nothing is drawn here any more — the two controls are real Buttons, so the
	# theme renders them along with their hover and focus StyleBoxes (ADR-0014 §6:
	# "distinct StyleBoxes on the default Theme — no custom focus-ring wiring").
	_sync_button_state()
	_sync_idle_notice()


## Recomputes and renders the idle notice.
##
## Counts through [method GameStateReader.idle_entity_count] rather than walking
## entities here: which entities "still have something to do" is a rules question
## (does this thing have a legal, affordable verb left, and has the player said
## they are finished with it?), and a HUD widget that answered it itself would be
## a second, drifting definition of idleness alongside the menu's own.
func _sync_idle_notice() -> void:
	if _idle_notice == null or _reader == null:
		return
	_idle_count = _reader.idle_entity_count(_local_player) if controls_live() else 0
	if _idle_count <= 0:
		_idle_notice.text = ""
		return
	_idle_notice.text = "%d idle" % _idle_count if _idle_count > 1 else "1 idle"


## How many of the local player's entities the notice currently reports, or -1
## before the first refresh. Exposed for the assembly test.
func idle_count() -> int:
	return _idle_count
