## MainMenu — the game's boot destination and top-level hub.
##
## Implements `design/ux/main-menu.md` (Approved, `/ux-review` 2026-07-27). Cold
## boot lands here, and it is the return target from an in-match "Quit to Main
## Menu". It owns no game state: New Skirmish hands off to the vertical slice, and
## Settings values belong to a Settings screen this menu only links to.
##
## [b]Three entries, no dead ones.[/b] The spec is explicit that Campaign/Continue
## are OMITTED in the vertical slice rather than greyed out — persistence does not
## exist, and a disabled entry for a feature that was never built reads as a broken
## game rather than a scoped one.
##
## [b]Accessibility — Standard tier[/b] (WCAG 2.1 AA + CVAA), per the spec:
## [br]• Every entry reachable by click AND by keyboard/gamepad focus traversal, in
##   the stated order (New Skirmish → Settings → Quit), with New Skirmish focused
##   on load so a pad has somewhere to start.
## [br]• Keyboard focus is styled DISTINCTLY from mouse hover (the Three-State
##   Focus Indicator convention) — two different StyleBoxes, never one shared
##   highlight, because a player navigating with a pad and a player with a mouse
##   need to see different things.
## [br]• Entry text at [constant ENTRY_FONT_SIZE] (the spec's "≥ 20px critical"),
##   buttons at least [constant MIN_HIT_TARGET] tall.
## [br]• Buttons are sized to the ~40% text expansion the localization pass calls
##   out, not to the English width — so a translated "NEW SKIRMISH" does not clip.
## [br]• Nothing is conveyed by colour alone: every entry is labelled text.
##
## [b]Testable model[/b]: [method entry_labels] / [method focused_entry] /
## [method is_quit_confirm_open] / [method activate_focused] are the integration
## surface, so the menu's behaviour is assertable without a display.
class_name MainMenu
extends Control

## Emitted when the player starts a match. The scene swap itself is done here, but
## the signal exists so a test (or a future flow controller) can observe the intent
## without a scene change actually happening.
signal new_skirmish_requested
## Emitted when the player confirms Quit.
signal quit_confirmed

const SLICE_SCENE: String = "res://scenes/vertical_slice.tscn"

## The spec's "≥ 20px critical" accessibility floor for menu text.
const ENTRY_FONT_SIZE: int = 22
const TITLE_FONT_SIZE: int = 64
const FOOTER_FONT_SIZE: int = 13

## The spec's hit-target floor at 1080p. The entries far exceed it; this is the
## bound, not the target.
const MIN_HIT_TARGET: float = 44.0
## Sized for the localization pass's ~40% expansion of "NEW SKIRMISH", not for the
## English string — a button fitted to English clips in German.
const ENTRY_SIZE: Vector2 = Vector2(340.0, 56.0)
const ENTRY_GAP: float = 14.0

# Palette — art bible §4.2 anchors. The void ground and the Rush hue, so the menu
# belongs to the same world as the board rather than looking like OS chrome.
const VOID: Color = Color(0.039, 0.055, 0.090)
const TITLE_HUE: Color = Color(1.0, 0.353, 0.180)
const ENTRY_TEXT: Color = Color(0.92, 0.95, 1.0)
const ENTRY_TEXT_INERT: Color = Color(0.50, 0.54, 0.60)
const FOOTER_TEXT: Color = Color(0.42, 0.47, 0.55)
## Deep enough that the menu behind reads as context rather than as competing text.
## At 0.72 the entry labels stayed legible and collided with the prompt — a modal
## the player can still read past is not modal.
const SCRIM: Color = Color(0.0, 0.0, 0.0, 0.90)

## Entry ids, in the spec's stated focus order.
enum Entry { NEW_SKIRMISH, SETTINGS, QUIT }

var _buttons: Array[Button] = []
var _quit_confirm: Control = null
var _confirm_yes: Button = null

## ⚠ The Settings screen has no spec and no implementation (main-menu.md Open
## Question 3 defers it, and `post-gate-backlog.md` item 6 parks the control-binding
## UI there). The entry is PRESENT and INERT rather than omitted: it is a specified
## component of this screen, so removing it would silently deviate from an approved
## spec, while wiring it to nothing would open a broken screen. Flip this the moment
## a Settings scene exists.
const SETTINGS_AVAILABLE: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# The spec: New Skirmish focused on load. Without this a gamepad boots into a
	# menu it cannot move within, because focus traversal needs somewhere to start.
	if not _buttons.is_empty():
		_buttons[Entry.NEW_SKIRMISH].grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "OVERCLOCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.position = Vector2(0, 120)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_HUE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# A CenterContainer rather than an anchored VBox with a hand-computed offset:
	# the offset has to be half the container's OWN width, which is not known until
	# the buttons lay out, so the hand-computed version sits off-centre. Letting the
	# container do it also survives a longer translated label without re-tuning.
	var centred := CenterContainer.new()
	centred.set_anchors_preset(Control.PRESET_FULL_RECT)
	centred.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centred)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", int(ENTRY_GAP))
	centred.add_child(stack)

	_buttons = [
		_make_entry(stack, "NEW SKIRMISH", true),
		_make_entry(stack, "SETTINGS", SETTINGS_AVAILABLE),
		_make_entry(stack, "QUIT", true),
	]
	_buttons[Entry.NEW_SKIRMISH].pressed.connect(_on_new_skirmish)
	_buttons[Entry.QUIT].pressed.connect(_open_quit_confirm)

	var footer := Label.new()
	footer.text = _version_stamp()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.position = Vector2(20, -34)
	footer.add_theme_font_size_override("font_size", FOOTER_FONT_SIZE)
	footer.add_theme_color_override("font_color", FOOTER_TEXT)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

	_build_quit_confirm()


## Builds one menu entry. [param interactive] false renders it at full visibility
## but refuses focus and input — the Standard Button pattern's "inert" state, which
## is explicit that inert controls are never hidden.
func _make_entry(parent: Node, text: String, interactive: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(ENTRY_SIZE.x, maxf(ENTRY_SIZE.y, MIN_HIT_TARGET))
	b.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	b.add_theme_color_override("font_color", ENTRY_TEXT if interactive else ENTRY_TEXT_INERT)
	b.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	b.disabled = not interactive
	if not interactive:
		# Says WHY rather than just refusing. A dead-looking entry with no
		# explanation reads as a bug; this reads as a scope boundary.
		b.tooltip_text = "Settings are not implemented yet."
	_apply_focus_and_hover_styles(b)
	parent.add_child(b)
	return b


## Gives the button DISTINCT hover and keyboard-focus treatments.
##
## ★ The Three-State Focus Indicator convention, and the reason it is set
## explicitly rather than left to the default theme: a mouse user and a pad user
## need to see different things, and a single shared highlight would tell a pad
## user nothing about where focus is while the mouse happens to rest elsewhere.
func _apply_focus_and_hover_styles(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.075, 0.095, 0.130, 0.95)
	normal.border_color = Color(0.30, 0.36, 0.44)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.120, 0.150, 0.195, 0.98)
	hover.border_color = Color(0.48, 0.56, 0.66)

	# Focus: the accent hue and a thicker rule — legible at a glance and unlike
	# hover in both colour AND weight, so the two never read as the same state.
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.150, 0.105, 0.080, 0.98)
	focus.border_color = TITLE_HUE
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


func _build_quit_confirm() -> void:
	_quit_confirm = Control.new()
	_quit_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_confirm.visible = false
	add_child(_quit_confirm)

	var scrim := ColorRect.new()
	scrim.color = SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_confirm.add_child(scrim)

	# Prompt and buttons in ONE centred column. Centring them independently put the
	# label on top of the buttons — two things each centred on the same point are
	# not a layout.
	var modal_centre := CenterContainer.new()
	modal_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_confirm.add_child(modal_centre)

	# The prompt sits on its own plate, so it never has to compete with whatever
	# happens to be behind it.
	var plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.075, 0.095, 0.130, 1.0)
	plate_style.border_color = TITLE_HUE
	plate_style.set_border_width_all(2)
	plate_style.set_content_margin_all(32)
	plate.add_theme_stylebox_override("panel", plate_style)
	modal_centre.add_child(plate)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(column)

	var prompt := Label.new()
	prompt.text = "Quit OVERCLOCK?"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 28)
	prompt.add_theme_color_override("font_color", ENTRY_TEXT)
	column.add_child(prompt)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	_confirm_yes = _make_entry(row, "QUIT", true)
	_confirm_yes.custom_minimum_size = Vector2(160, MIN_HIT_TARGET)
	var cancel: Button = _make_entry(row, "CANCEL", true)
	cancel.custom_minimum_size = Vector2(160, MIN_HIT_TARGET)
	_confirm_yes.pressed.connect(_confirm_quit)
	cancel.pressed.connect(close_quit_confirm)


func _on_new_skirmish() -> void:
	new_skirmish_requested.emit()
	get_tree().change_scene_to_file(SLICE_SCENE)


func _open_quit_confirm() -> void:
	_quit_confirm.visible = true
	_confirm_yes.grab_focus() # a pad must land on something inside the modal


## Closes the confirm prompt and returns focus to the Quit entry it came from —
## not to the top of the menu, which would silently move the player.
func close_quit_confirm() -> void:
	if _quit_confirm == null or not _quit_confirm.visible:
		return
	_quit_confirm.visible = false
	_buttons[Entry.QUIT].grab_focus()


func _confirm_quit() -> void:
	quit_confirmed.emit()
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# Esc cancels the prompt (spec's Interaction Map). Only when it is open, so Esc
	# on the menu proper stays free for a future "back" behaviour.
	if _quit_confirm != null and _quit_confirm.visible and event.is_action_pressed(&"ui_cancel"):
		close_quit_confirm()
		get_viewport().set_input_as_handled()


func _version_stamp() -> String:
	var v: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return "vslice-build %s" % v if v != "" else "vslice-build (unversioned)"


# --- Testable model -----------------------------------------------------------

## The entry labels, in focus order.
func entry_labels() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _buttons:
		out.append(b.text)
	return out

## Which entry currently holds keyboard/gamepad focus, or -1 if none does.
func focused_entry() -> int:
	for i: int in _buttons.size():
		if _buttons[i].has_focus():
			return i
	return -1

## Whether an entry accepts input at all (the Standard Button "inert" state).
func entry_interactive(entry: int) -> bool:
	return entry >= 0 and entry < _buttons.size() and not _buttons[entry].disabled

## Whether the quit-confirm prompt is showing.
func is_quit_confirm_open() -> bool:
	return _quit_confirm != null and _quit_confirm.visible

## Opens the quit-confirm prompt (the same path the Quit entry takes).
func open_quit_confirm() -> void:
	_open_quit_confirm()

## The footer's build stamp.
func version_text() -> String:
	return _version_stamp()
