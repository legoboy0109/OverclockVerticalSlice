## MenuStyle — the shared look and accessibility floors for every menu button.
##
## Extracted 2026-08-24 when the pause menu was built. `pause.md` asks for the
## "same stack idiom as the main menu (consistency)", and the reliable way to get
## that is one implementation rather than two that happen to match today. A second
## copy of these StyleBoxes would drift the first time either screen was tuned.
##
## It also puts the [b]numeric accessibility floors in one place[/b]. Both specs
## state the same Standard-tier requirements — text ≥ 20px, hit target ≥ 44×44 at
## 1080p, keyboard focus styled distinctly from mouse hover — and a floor that
## lives in two files is a floor that gets raised in one of them.
class_name MenuStyle
extends RefCounted

## The spec's "≥ 20px critical" floor for menu text.
const ENTRY_FONT_SIZE: int = 22
## The spec's hit-target floor at 1080p. Entries exceed it; this is the bound.
const MIN_HIT_TARGET: float = 44.0
## Sized for the localization pass's ~40% expansion, not the English width — a
## button fitted to "NEW SKIRMISH" clips on a longer translation.
const ENTRY_WIDTH: float = 340.0
const ENTRY_HEIGHT: float = 56.0
const ENTRY_GAP: int = 14

# Palette — art bible §4.2 anchors, so a menu belongs to the same world as the
# board rather than looking like OS chrome.
const VOID: Color = Color(0.039, 0.055, 0.090)
const ACCENT: Color = Color(1.0, 0.353, 0.180)
const TEXT: Color = Color(0.92, 0.95, 1.0)
const TEXT_INERT: Color = Color(0.50, 0.54, 0.60)
const FOOTER_TEXT: Color = Color(0.42, 0.47, 0.55)
## Deep enough that whatever sits behind reads as context, not as competing text.
const SCRIM: Color = Color(0.0, 0.0, 0.0, 0.90)
## The pause scrim is lighter than a modal's: `pause.md` wants the board "dimmed
## but still visible", because the frozen board IS the context the player is
## holding while they decide.
const PAUSE_SCRIM: Color = Color(0.0, 0.0, 0.0, 0.66)


## Builds a menu entry with the shared look and floors applied.
##
## [param interactive] false yields the Standard Button pattern's INERT state:
## full visibility, no focus, no input — never hidden, because the pattern is
## explicit that inert controls still render.
static func make_entry(text: String, interactive: bool = true,
		width: float = ENTRY_WIDTH) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, maxf(ENTRY_HEIGHT, MIN_HIT_TARGET))
	b.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	b.add_theme_color_override("font_color", TEXT if interactive else TEXT_INERT)
	b.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	b.disabled = not interactive
	apply(b)
	return b


## Applies the five-state StyleBox set (Standard Button: default / hover /
## keyboard-focus / pressed / inert).
##
## ★ Hover and focus differ in BOTH colour and border weight, deliberately. The
## Three-State Focus Indicator convention requires them distinguishable, and a
## difference in hue alone would fail the same specs' "no information by colour
## alone" rule — so the focus ring is also visibly thicker.
static func apply(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.075, 0.095, 0.130, 0.95)
	normal.border_color = Color(0.30, 0.36, 0.44)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.120, 0.150, 0.195, 0.98)
	hover.border_color = Color(0.48, 0.56, 0.66)

	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.150, 0.105, 0.080, 0.98)
	focus.border_color = ACCENT
	focus.set_border_width_all(3)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.190, 0.130, 0.095, 1.0)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.055, 0.070, 0.095, 0.95)
	disabled.border_color = Color(0.20, 0.24, 0.30)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)


## A bordered plate for a panel or a modal prompt, in the shared palette.
static func make_plate() -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.095, 0.130, 1.0)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_content_margin_all(32)
	plate.add_theme_stylebox_override("panel", style)
	return plate
