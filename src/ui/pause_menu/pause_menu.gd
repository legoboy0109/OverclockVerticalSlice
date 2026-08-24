## PauseMenu — the in-match pause overlay.
##
## Implements `design/ux/pause.md` (Approved, `/ux-review` 2026-07-27). A modal
## overlay over a frozen, dimmed board: the board stays visible because it is the
## context the player is holding while they decide.
##
## [b]It owns no game state.[/b] Resume, Restart and Quit are emitted as signals;
## the owning scene performs the freeze, the reload and the teardown. That keeps
## the destructive paths (`pause.md` flags them for the architecture team as
## state-teardown) in the node that actually owns the match.
##
## [b]Esc is symmetric[/b] (spec, Interaction Map): it opens pause from the match
## and resumes from the default pause view. From a confirm prompt it backs out to
## the pause menu instead, so a player can always retreat one step rather than
## being dropped straight back into the match from a half-made decision.
##
## [b]Both destructive actions are confirm-gated.[/b] The spec calls this an
## accessibility/error-prevention safeguard rather than a nicety: the vertical
## slice has no save, so a mis-click on Restart or Quit destroys the match with no
## recovery.
##
## [b]Testable model[/b]: [method entry_labels] / [method focused_entry] /
## [method is_open] / [method open_confirm_kind] are the integration surface.
class_name PauseMenu
extends Control

signal resume_requested
signal restart_requested
signal quit_to_menu_requested

## Entry ids in the spec's stated focus order.
enum Entry { RESUME, RESTART, SETTINGS, QUIT_TO_MENU }
## Which confirm prompt is showing, if any.
enum Confirm { NONE, RESTART, QUIT }

## ⚠ Same call as the main menu's: the Settings screen has no spec and no
## implementation (`pause.md` OQ-4, `main-menu.md` OQ-3). Present and inert beats
## omitting a specified component or opening a screen that does not exist.
const SETTINGS_AVAILABLE: bool = false

const ENTRY_WIDTH: float = 300.0

var _buttons: Array[Button] = []
var _panel: Control = null
var _confirm_layer: Control = null
var _confirm_label: Label = null
var _confirm_yes: Button = null
var _confirm_kind: int = Confirm.NONE


func _ready() -> void:
	# ★ A Control parented to a CanvasLayer has NO parent rect to anchor against, so
	# `PRESET_FULL_RECT` alone leaves it at zero size. That is not a cosmetic
	# problem: at zero size the scrim covers nothing (the board never dims) and the
	# CenterContainer centres the panel on the origin (it renders in the top-left
	# corner). Both symptoms, one cause. Size is taken from the viewport and kept in
	# sync on resize.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	# ★ Runs WHILE THE TREE IS PAUSED. Without this the overlay freezes with
	# everything else and the player cannot press any of its buttons — the pause
	# menu would be the one thing pause breaks.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build()


## Matches the overlay to the viewport. See [method _ready] for why this cannot be
## left to anchors.
func _fit_to_viewport() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	position = Vector2.ZERO
	size = rect.size


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = MenuStyle.PAUSE_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = MenuStyle.make_plate()
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MenuStyle.ENTRY_GAP)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(column)

	var label := Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", MenuStyle.TEXT)
	column.add_child(label)

	_buttons = [
		MenuStyle.make_entry("RESUME", true, ENTRY_WIDTH),
		MenuStyle.make_entry("RESTART SKIRMISH", true, ENTRY_WIDTH),
		MenuStyle.make_entry("SETTINGS", SETTINGS_AVAILABLE, ENTRY_WIDTH),
		MenuStyle.make_entry("QUIT TO MAIN MENU", true, ENTRY_WIDTH),
	]
	for b: Button in _buttons:
		column.add_child(b)
	if not SETTINGS_AVAILABLE:
		_buttons[Entry.SETTINGS].tooltip_text = "Settings are not implemented yet."

	_buttons[Entry.RESUME].pressed.connect(request_resume)
	_buttons[Entry.RESTART].pressed.connect(func() -> void: _open_confirm(Confirm.RESTART))
	_buttons[Entry.QUIT_TO_MENU].pressed.connect(func() -> void: _open_confirm(Confirm.QUIT))

	_build_confirm()


func _build_confirm() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.visible = false
	add_child(_confirm_layer)

	var scrim := ColorRect.new()
	scrim.color = MenuStyle.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(centre)

	var plate: PanelContainer = MenuStyle.make_plate()
	centre.add_child(plate)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(column)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_font_size_override("font_size", 24)
	_confirm_label.add_theme_color_override("font_color", MenuStyle.TEXT)
	column.add_child(_confirm_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	_confirm_yes = MenuStyle.make_entry("CONFIRM", true, 160.0)
	var cancel: Button = MenuStyle.make_entry("CANCEL", true, 160.0)
	row.add_child(_confirm_yes)
	row.add_child(cancel)
	_confirm_yes.pressed.connect(_on_confirmed)
	cancel.pressed.connect(close_confirm)


# --- Open / close -------------------------------------------------------------

## Shows the overlay with Resume focused (spec: "Resume focused on open").
func open() -> void:
	if visible:
		return
	visible = true
	_confirm_kind = Confirm.NONE
	_confirm_layer.visible = false
	_buttons[Entry.RESUME].grab_focus()


## Hides the overlay and emits [signal resume_requested]. The owning scene decides
## what resuming means; this node only reports the intent.
func request_resume() -> void:
	if not visible:
		return
	visible = false
	_confirm_kind = Confirm.NONE
	_confirm_layer.visible = false
	resume_requested.emit()


func _open_confirm(kind: int) -> void:
	_confirm_kind = kind
	_confirm_label.text = "Restart this skirmish?" if kind == Confirm.RESTART \
		else "Leave the match? Progress is lost."
	_confirm_layer.visible = true
	_confirm_yes.grab_focus() # a pad must land inside the modal


## Backs out of a confirm prompt to the pause menu, restoring focus to the entry
## that opened it rather than to the top of the list.
func close_confirm() -> void:
	if not _confirm_layer.visible:
		return
	var came_from: int = Entry.RESTART if _confirm_kind == Confirm.RESTART else Entry.QUIT_TO_MENU
	_confirm_layer.visible = false
	_confirm_kind = Confirm.NONE
	_buttons[came_from].grab_focus()


func _on_confirmed() -> void:
	var kind: int = _confirm_kind
	_confirm_layer.visible = false
	_confirm_kind = Confirm.NONE
	visible = false
	if kind == Confirm.RESTART:
		restart_requested.emit()
	elif kind == Confirm.QUIT:
		quit_to_menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	# ★ Esc backs out ONE step: from a confirm prompt to the pause menu, and from
	# the pause menu to the match. Dropping straight into the match from a
	# half-made destructive decision would be the wrong kind of shortcut.
	if _confirm_layer.visible:
		close_confirm()
	else:
		request_resume()
	get_viewport().set_input_as_handled()


# --- Testable model -----------------------------------------------------------

## Entry labels, in focus order.
func entry_labels() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _buttons:
		out.append(b.text)
	return out

## Which entry holds keyboard/gamepad focus, or -1.
func focused_entry() -> int:
	for i: int in _buttons.size():
		if _buttons[i].has_focus():
			return i
	return -1

## Whether an entry accepts input (Standard Button "inert" state when false).
func entry_interactive(entry: int) -> bool:
	return entry >= 0 and entry < _buttons.size() and not _buttons[entry].disabled

## Whether the overlay is showing.
func is_open() -> bool:
	return visible

## Which confirm prompt is showing (see [enum Confirm]).
func open_confirm_kind() -> int:
	return _confirm_kind if _confirm_layer != null and _confirm_layer.visible else Confirm.NONE

## The confirm prompt's current wording.
func confirm_text() -> String:
	return _confirm_label.text if _confirm_label != null else ""

## Activates the focused confirm button — the test seam for "confirming fires".
func confirm_now() -> void:
	_on_confirmed()
