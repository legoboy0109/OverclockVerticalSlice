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

## ★ 24px, not 22. The UX specs (`main-menu.md`, `pause.md`) say "≥ 20px critical",
## but `accessibility-requirements.md` — the authority on the committed Standard
## tier — is stricter for menus specifically: "Minimum text size — menu UI ... 24px
## minimum at 1080p". Two documents, two numbers; the tier commitment wins, and the
## looser figure in the UX specs is the older one. Entries are already sized for
## ~40% localization expansion, so raising this clips nothing.
const ENTRY_FONT_SIZE: int = 24
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
	# ★ 2026-10-01 (holo glass, UI direction B): cut-corner glass entries. Focus is the loud
	# state — accent edge and a warm fill — because on a pad it is the only cursor there is.
	var glass_fill := Color(0.07, 0.12, 0.19, 0.82)
	b.add_theme_stylebox_override("normal", UiTheme.glass_box(glass_fill, Color(0.47, 0.78, 1.0, 0.45)))
	b.add_theme_stylebox_override("hover", UiTheme.glass_box(Color(0.10, 0.17, 0.26, 0.90), Color(0.60, 0.85, 1.0, 0.85)))
	b.add_theme_stylebox_override("focus", UiTheme.glass_box(Color(ACCENT, 0.16), ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UiTheme.glass_box(Color(ACCENT, 0.30), ACCENT, 2))
	b.add_theme_stylebox_override("disabled", UiTheme.glass_box(Color(0.05, 0.08, 0.12, 0.70), Color(0.47, 0.78, 1.0, 0.18)))
	b.add_theme_font_override("font", UiTheme.label_font())


## Gives [param label] the soft neon glow the holo-glass titles use (outline passes, no shader).
static func glow_label(label: Label, color: Color, size_px: int = 14) -> void:
	# A faint wide outline reads as a halo; a strong one read as a brown stroke (2026-10-01).
	label.add_theme_color_override("font_outline_color", Color(color, 0.12))
	label.add_theme_constant_override("outline_size", size_px)
	label.add_theme_font_override("font", UiTheme.font(700))


static func fill_viewport(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport: Viewport = c.get_viewport()
	if viewport == null:
		return
	c.position = Vector2.ZERO
	c.size = viewport.get_visible_rect().size
	# ★ The validity guard is load-bearing. A lambda's lifetime is not tied to the
	# Control it closes over, so `size_changed` keeps invoking it after that Control
	# is freed — and a screen opened and closed once then leaves a callable writing
	# `position` to a freed object on the next window resize. It surfaced as an
	# unrelated test failing on a null assignment, which is the least helpful place
	# for it to show up.
	viewport.size_changed.connect(func() -> void:
		if not is_instance_valid(c):
			return
		c.position = Vector2.ZERO
		c.size = c.get_viewport().get_visible_rect().size)


## A bordered plate for a panel or a modal prompt, in the shared palette.
static func make_plate() -> PanelContainer:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE   # replaced by the glass shader; only the margins matter
	style.set_content_margin_all(32)
	plate.add_theme_stylebox_override("panel", style)
	# ★ 2026-10-01 (holo glass): frosted plate with an accent edge and soft glow.
	UiTheme.make_glass(plate, Color(ACCENT, 0.7), 14.0)
	return plate
