## SettingsScreen — the screen both menus have linked to since 2026-07-27.
##
## `main-menu.md` OQ-3 and `pause.md` OQ-4 each deferred this to "a separate spec"
## that was never authored, so its contents come from the project's standing
## commitments rather than from a UX document:
## [br]• `accessibility-requirements.md` — Standard tier owes **full input
##   remapping** ("every bound input... rebindable independently across keyboard,
##   mouse and gamepad, **with conflict warnings**"), **UI scaling 75–150%**, and a
##   **motion-reduction mode**.
## [br]• `production/post-gate-backlog.md` item 6 — the control-binding UI was
##   parked here explicitly.
##
## [b]Returns where it came from.[/b] Both specs require "back returns to the
## screen you opened it from" — the pause overlay, or the main menu. The caller
## supplies that destination via [method open_from]; this screen does not guess.
##
## [b]Rebinding reports conflicts, it does not refuse them.[/b] Refusing a
## duplicate outright would make swapping two bindings impossible, since every swap
## passes through a state where both actions want the same input. The warning names
## what else uses it and lets the player decide.
##
## [b]Testable model[/b]: [method binding_label] / [method conflict_warning] /
## [method is_listening] / [method ui_scale] / [method reduced_motion] are the
## integration surface, so the behaviour is assertable without a display.
class_name SettingsScreen
extends Control

## Emitted when the player leaves. The host swaps back to wherever it came from.
signal closed

const ROW_LABEL_WIDTH: float = 260.0
const BIND_BUTTON_WIDTH: float = 150.0

var _settings: GameSettings = null

## The row currently waiting for a key/button press, or [code]{}[/code] when not
## listening. Shape: {action: StringName, device: int}.
var _listening: Dictionary = {}

var _bind_buttons: Dictionary = {}   ## "action.device" -> Button
var _warning_label: Label = null
var _scale_label: Label = null
var _scale_slider: HSlider = null
var _motion_button: CheckButton = null
var _back_button: Button = null


func _ready() -> void:
	# Built with .new(), so it carries none of a .tscn root's anchor properties and
	# would sit at zero size — see MenuStyle.fill_viewport for why that shows up as
	# "the screen simply does not appear" rather than as a sizing fault.
	MenuStyle.fill_viewport(self)
	_settings = Settings.settings
	_build()
	_refresh_all()
	if _back_button != null:
		_back_button.grab_focus()


## Shows the screen. [param on_closed] is invoked when the player backs out, so the
## caller decides where "back" goes rather than this screen assuming.
func open_from(on_closed: Callable) -> void:
	if on_closed.is_valid():
		closed.connect(on_closed, CONNECT_ONE_SHOT)
	visible = true


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = MenuStyle.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_top", 40)
	add_child(scroll)

	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	column.add_child(_heading("SETTINGS", 34))
	column.add_child(_heading("CONTROLS", 20))

	# A column header, so the two binding columns are labelled rather than left for
	# the player to infer from the glyphs in them.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(_cell("", ROW_LABEL_WIDTH, MenuStyle.FOOTER_TEXT))
	header.add_child(_cell("KEYBOARD", BIND_BUTTON_WIDTH, MenuStyle.FOOTER_TEXT))
	header.add_child(_cell("GAMEPAD", BIND_BUTTON_WIDTH, MenuStyle.FOOTER_TEXT))
	column.add_child(header)

	for action: StringName in GameSettings.REBINDABLE:
		column.add_child(_binding_row(action))

	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", 16)
	_warning_label.add_theme_color_override("font_color", MenuStyle.ACCENT)
	_warning_label.custom_minimum_size = Vector2(0, 26) # reserve the line so the
	# layout does not jump when a warning appears — a shifting list is its own bug
	column.add_child(_warning_label)

	column.add_child(_heading("DISPLAY", 20))
	column.add_child(_scale_row())
	column.add_child(_motion_row())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset: Button = MenuStyle.make_entry("RESET TO DEFAULTS", true, 260.0)
	_back_button = MenuStyle.make_entry("BACK", true, 180.0)
	reset.pressed.connect(_on_reset)
	_back_button.pressed.connect(close)
	buttons.add_child(reset)
	buttons.add_child(_back_button)
	column.add_child(buttons)


func _heading(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MenuStyle.TEXT)
	return l


func _cell(text: String, width: float, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", colour)
	return l


func _binding_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_cell(GameSettings.ACTION_LABELS.get(action, String(action)),
		ROW_LABEL_WIDTH, MenuStyle.TEXT))
	for device: int in [GameSettings.Device.KEYBOARD, GameSettings.Device.GAMEPAD]:
		var b: Button = MenuStyle.make_entry("", true, BIND_BUTTON_WIDTH)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func() -> void: _begin_listening(action, device))
		_bind_buttons["%s.%d" % [action, device]] = b
		row.add_child(b)
	return row


func _scale_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_cell("UI Scale", ROW_LABEL_WIDTH, MenuStyle.TEXT))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = GameSettings.UI_SCALE_MIN
	_scale_slider.max_value = GameSettings.UI_SCALE_MAX
	_scale_slider.step = 0.05
	_scale_slider.custom_minimum_size = Vector2(220, MenuStyle.MIN_HIT_TARGET)
	_scale_slider.focus_mode = Control.FOCUS_ALL
	_scale_slider.value_changed.connect(_on_scale_changed)
	row.add_child(_scale_slider)
	_scale_label = _cell("", 80.0, MenuStyle.TEXT)
	row.add_child(_scale_label)
	return row


func _motion_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_cell("Reduced Motion", ROW_LABEL_WIDTH, MenuStyle.TEXT))
	_motion_button = CheckButton.new()
	_motion_button.custom_minimum_size = Vector2(0, MenuStyle.MIN_HIT_TARGET)
	_motion_button.focus_mode = Control.FOCUS_ALL
	_motion_button.toggled.connect(_on_motion_toggled)
	row.add_child(_motion_button)
	return row


# --- Rebinding ----------------------------------------------------------------

func _begin_listening(action: StringName, device: int) -> void:
	_listening = {"action": action, "device": device}
	var b: Button = _bind_buttons["%s.%d" % [action, device]]
	b.text = "PRESS..."
	_warning_label.text = "Press a %s input, or Esc to cancel." % (
		"key" if device == GameSettings.Device.KEYBOARD else "gamepad button")


func _input(event: InputEvent) -> void:
	if _listening.is_empty() or not visible:
		return
	if not event.is_pressed() or event.is_echo():
		return

	# Esc cancels rather than binding. Without this the only way out of a listening
	# row is to bind something, which is a trap if the player opened it by mistake.
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_listening.clear()
		_refresh_all()
		get_viewport().set_input_as_handled()
		return

	var device: int = _listening["device"]
	var code: int = -1
	if device == GameSettings.Device.KEYBOARD and event is InputEventKey:
		code = (event as InputEventKey).physical_keycode
	elif device == GameSettings.Device.GAMEPAD and event is InputEventJoypadButton:
		code = (event as InputEventJoypadButton).button_index
	if code < 0:
		return # wrong input family for this column — keep listening

	var action: StringName = _listening["action"]
	var clashes: Array[StringName] = _settings.conflicts(code, device, action)
	_settings.set_binding(action, device, code)
	_settings.apply_bindings()
	_settings.save()
	_listening.clear()
	_refresh_all()
	if not clashes.is_empty():
		# Reported, not refused — see the class doc for why a swap needs this.
		var names: Array[String] = []
		for c: StringName in clashes:
			names.append(String(GameSettings.ACTION_LABELS.get(c, String(c))))
		_warning_label.text = "⚠ Also bound to: %s" % ", ".join(names)
	get_viewport().set_input_as_handled()


# --- Display ------------------------------------------------------------------

func _on_scale_changed(value: float) -> void:
	_settings.ui_scale = value
	_settings.apply_display()
	_settings.save()
	_refresh_display_labels()


func _on_motion_toggled(pressed: bool) -> void:
	_settings.reduced_motion = pressed
	_settings.save()


func _on_reset() -> void:
	_settings.reset_to_defaults()
	_settings.apply_all()
	_settings.save()
	_refresh_all()
	_warning_label.text = "Defaults restored."


func close() -> void:
	visible = false
	closed.emit()


# --- Refresh ------------------------------------------------------------------

func _refresh_all() -> void:
	for action: StringName in GameSettings.REBINDABLE:
		for device: int in [GameSettings.Device.KEYBOARD, GameSettings.Device.GAMEPAD]:
			var b: Button = _bind_buttons["%s.%d" % [action, device]]
			b.text = binding_label(action, device)
	if _warning_label != null and _listening.is_empty():
		_warning_label.text = ""
	_refresh_display_labels()


func _refresh_display_labels() -> void:
	if _scale_slider != null:
		_scale_slider.set_value_no_signal(_settings.ui_scale)
	if _scale_label != null:
		_scale_label.text = "%d%%" % roundi(_settings.ui_scale * 100.0)
	if _motion_button != null:
		_motion_button.set_pressed_no_signal(_settings.reduced_motion)


# --- Testable model -----------------------------------------------------------

## The label shown on a binding button — the input's name, or "—" if unbound.
func binding_label(action: StringName, device: int) -> String:
	var code: int = _settings.binding(action, device)
	if code < 0:
		return "—"
	if device == GameSettings.Device.KEYBOARD:
		return OS.get_keycode_string(code)
	return "Pad %d" % code

## The current warning/hint line ("" when there is nothing to say).
func conflict_warning() -> String:
	return _warning_label.text if _warning_label != null else ""

## Whether a row is waiting for an input.
func is_listening() -> bool:
	return not _listening.is_empty()

func ui_scale() -> float:
	return _settings.ui_scale

func reduced_motion() -> bool:
	return _settings.reduced_motion
