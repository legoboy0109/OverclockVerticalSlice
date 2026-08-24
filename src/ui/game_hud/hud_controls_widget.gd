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


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var live: bool = controls_live()
	# Build: dimmed when unaffordable, pressed cue while PREVIEW_BUILD; both
	# controls dimmed further when inert (advisory treatment).
	var build_col: Color = Color.WHITE if build_affordable() else Color(0.5, 0.5, 0.5)
	if not live:
		build_col = build_col.darkened(0.4)
	if build_pressed_cue():
		draw_rect(Rect2(Vector2(2, 2), Vector2(60, 20)), Color(0.2, 0.5, 1.0, 0.4))
	draw_string(font, Vector2(6, 18), "Build", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, build_col)
	var end_col: Color = Color.WHITE if live else Color(0.4, 0.4, 0.4)
	draw_string(font, Vector2(70, 18), "End Turn", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, end_col)
