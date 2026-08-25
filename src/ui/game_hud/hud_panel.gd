## HudPanel — a titled backing plate that groups related HUD readouts.
##
## [b]Why this exists.[/b] Before 2026-08-24 the HUD was four unlabelled fragments
## in four screen corners: a bare number ("30") top-left with no unit, a Credits
## figure beneath it, a population readout floating alone below that, the
## opponent's state dimmed in the opposite corner, and the action legend adrift
## along the bottom. Every one drew straight onto the board, so text competed with
## terrain and sprites for the same pixels, and nothing indicated which readouts
## belonged together.
##
## This is deliberately NOT a rewrite of the widgets. Each one keeps its own
## display model, its own reactive binding and its own tests; the panel only
## supplies a ground to sit on, a title that says whose numbers these are, and a
## frame that groups them. Composition changed, behaviour did not.
##
## [b]Pillar 3 (Readable Board).[/b] The backing is opaque enough that text never
## fights the board underneath it, and the panel is sized to its content rather
## than to the screen, so it covers as little of the playfield as it can. The
## border is the only bright element — a thin rule reads as "this is a panel" at a
## glance without drawing the eye away from the board, which is where the game is.
##
## Usage:
## [codeblock]
## var panel := HudPanel.new()
## panel.configure("YOU", Vector2(220, 96))
## panel.position = Vector2(16, 12)
## hud_layer.add_child(panel)
## panel.add_content(ap_counter, Vector2(0, 0))
## [/codeblock]
class_name HudPanel
extends Control

## Panel ground. Near-black with a cool bias, matching the art bible's void anchor
## family so a panel reads as part of the game's world rather than as OS chrome.
const BACKING: Color = Color(0.055, 0.075, 0.105, 0.88)
## The frame. Low-saturation steel — present enough to bound the group, quiet
## enough that it never competes with a neon actor on the board.
const BORDER: Color = Color(0.38, 0.45, 0.55, 0.75)
## Title text. Dimmer than the values it introduces: a label is context, and the
## numbers are what the player is actually reading.
const TITLE: Color = Color(0.62, 0.70, 0.78, 1.0)

const BORDER_WIDTH: float = 1.0
const TITLE_FONT_SIZE: int = 11
## Space above the first child, leaving room for the title.
const CONTENT_TOP: float = 26.0
const PAD_X: float = 12.0

var _title: String = ""


## Sets the panel's heading and its fixed size. Size is explicit rather than
## derived: these panels anchor to screen corners, and a box that resized itself
## as values changed would make the whole HUD twitch every time a number ticked.
func configure(title: String, panel_size: Vector2) -> void:
	_title = title
	custom_minimum_size = panel_size
	size = panel_size
	queue_redraw()


## Adds a widget inside the panel at [param offset] from the content origin (just
## below the title). The child keeps its own drawing entirely.
func add_content(node: Control, offset: Vector2) -> void:
	node.position = Vector2(PAD_X, CONTENT_TOP) + offset
	add_child(node)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BACKING, true)
	draw_rect(r, BORDER, false, BORDER_WIDTH)
	if _title == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(PAD_X, 17), _title, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TITLE_FONT_SIZE, TITLE)
