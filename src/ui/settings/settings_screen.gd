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
## "action.device" -> the small per-binding reset button beside it.
var _reset_buttons: Dictionary = {}
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

	# States the reset affordance permanently, because a keyboard path nobody is
	# told about is a keyboard path nobody uses.
	var hint := _cell("Changed bindings are highlighted. Press \u21ba, or Delete on a "
		+ "focused binding, to reset just that one.", 0.0, MenuStyle.FOOTER_TEXT)
	hint.add_theme_font_size_override("font_size", 14)
	column.add_child(hint)

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
		row.add_child(_reset_button(action, device))
	return row


## The per-binding reset affordance: restores ONE binding to its shipped default.
##
## ★ Two input paths, because one is not enough here. `technical-preferences.md`
## requires every action be reachable by CLICK, and the Standard accessibility tier
## requires keyboard/gamepad reach — a Delete-key-only clear fails the first, and a
## mouse-only button fails the second.
##
## ★ It is deliberately [constant Control.FOCUS_NONE]: the keyboard/gamepad path is
## the Delete key on the focused binding (see [method _input]), which is fewer
## presses than tabbing past 9 extra stops. Making these focusable would grow the
## table from 18 tab stops to 27 and slow down the input method that can least
## afford it.
##
## Inert when the binding is not overridden — the Standard Button pattern's inert
## state, present but non-interactive, never hidden. That is a feature rather than
## clutter: the column doubles as the "which of these have I changed?" readout the
## table otherwise has no way to give.
func _reset_button(action: StringName, device: int) -> Button:
	var r := Button.new()
	r.text = "\u21ba" # ↺
	r.tooltip_text = "Reset this binding to its default"
	r.custom_minimum_size = Vector2(34, MenuStyle.MIN_HIT_TARGET)
	r.focus_mode = Control.FOCUS_NONE
	r.add_theme_font_size_override("font_size", 16)
	MenuStyle.apply(r)
	r.pressed.connect(func() -> void: clear_binding(action, device))
	_reset_buttons["%s.%d" % [action, device]] = r
	return r


## Restores one binding to its shipped default, leaving every other customisation
## alone. The single entry point for both the ↺ button and the Delete key.
func clear_binding(action: StringName, device: int) -> bool:
	if not _settings.is_overridden(action, device):
		return false
	_settings.clear_binding(action, device)
	_settings.apply_bindings()
	var saved: bool = _save_and_report()
	_refresh_all()
	if saved:
		_warning_label.text = "%s (%s) reset to default." % [
			GameSettings.ACTION_LABELS.get(action, String(action)),
			"keyboard" if device == GameSettings.Device.KEYBOARD else "gamepad"]
	return true


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
	if not visible:
		return
	# Delete / gamepad X clears the FOCUSED binding — the keyboard and gamepad half
	# of the per-binding reset. Only when not mid-rebind, or Delete would be
	# swallowed instead of being bindable.
	if _listening.is_empty() and event.is_pressed() and not event.is_echo():
		var is_clear: bool = (event is InputEventKey
				and (event as InputEventKey).keycode == KEY_DELETE)
		if is_clear:
			var focused: Dictionary = _focused_binding()
			if not focused.is_empty():
				clear_binding(focused["action"], focused["device"])
				get_viewport().set_input_as_handled()
			return
	if _listening.is_empty():
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
	var saved: bool = _save_and_report()
	_listening.clear()
	_refresh_all()
	if not clashes.is_empty():
		# Reported, not refused — see the class doc for why a swap needs this.
		var names: Array[String] = []
		for c: StringName in clashes:
			names.append(String(GameSettings.ACTION_LABELS.get(c, String(c))))
		_warning_label.text = "⚠ Also bound to: %s" % ", ".join(names)
	elif not saved:
		pass # _save_and_report already put the failure on the line
	get_viewport().set_input_as_handled()


## Which binding cell currently holds focus, or [code]{}[/code] if none does.
func _focused_binding() -> Dictionary:
	for key: String in _bind_buttons:
		var b: Button = _bind_buttons[key]
		if b.has_focus():
			var parts: PackedStringArray = key.rsplit(".", true, 1)
			return {"action": StringName(parts[0]), "device": int(parts[1])}
	return {}


# --- Display ------------------------------------------------------------------

func _on_scale_changed(value: float) -> void:
	_settings.ui_scale = value
	_settings.apply_display()
	_save_and_report()
	_refresh_display_labels()


func _on_motion_toggled(pressed: bool) -> void:
	_settings.reduced_motion = pressed
	_save_and_report()


func _on_reset() -> void:
	_settings.reset_to_defaults()
	_settings.apply_all()
	var saved: bool = _save_and_report()
	_refresh_all()
	if saved:
		_warning_label.text = "Defaults restored."


## Saves, and puts a failure on the hint line rather than swallowing it.
##
## ★ Added 2026-08-24 after `/ux-review` raised it as blocking. Every call site
## discarded [method GameSettings.save]'s [enum Error], so a read-only or full
## `user://` lost the player's settings SILENTLY — they would rebind a control,
## see the table update, and find it reverted on next launch with nothing having
## said why. The screen's whole purpose is persistence; failing at it quietly is
## the worst way for it to fail.
##
## Routed through one funnel so a future call site cannot forget the failure path,
## which is how the original four came to drop it.
func _save_and_report() -> bool:
	var err: Error = _settings.save()
	if err == OK:
		return true
	# Names the file, because "could not save" with no location is unactionable.
	_warning_label.text = "⚠ Could not save settings to %s (error %d). Changes apply now but will be lost on exit." % [
		GameSettings.PATH, err]
	push_error("SettingsScreen: save failed (%d) writing %s" % [err, GameSettings.PATH])
	return false


func close() -> void:
	visible = false
	closed.emit()


# --- Refresh ------------------------------------------------------------------

func _refresh_all() -> void:
	for action: StringName in GameSettings.REBINDABLE:
		for device: int in [GameSettings.Device.KEYBOARD, GameSettings.Device.GAMEPAD]:
			var key: String = "%s.%d" % [action, device]
			var b: Button = _bind_buttons[key]
			b.text = binding_label(action, device)
			var changed: bool = _settings.is_overridden(action, device)
			# Overridden cells carry the accent, so "what have I changed?" is
			# answerable at a glance rather than only by pressing Reset and seeing
			# what moves. Not colour-alone: the ↺ beside it is live only here too.
			b.add_theme_color_override("font_color",
				MenuStyle.ACCENT if changed else MenuStyle.TEXT)
			var r: Button = _reset_buttons[key]
			r.disabled = not changed
			r.modulate = Color.WHITE if changed else Color(0.45, 0.48, 0.54)
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

## Whether [param action]/[param device] currently differs from the shipped default.
func is_overridden(action: StringName, device: int) -> bool:
	return _settings.is_overridden(action, device)

## Whether the per-binding reset affordance is live for this cell.
func reset_available(action: StringName, device: int) -> bool:
	var r: Button = _reset_buttons.get("%s.%d" % [action, device])
	return r != null and not r.disabled

## Whether a row is waiting for an input.
func is_listening() -> bool:
	return not _listening.is_empty()

func ui_scale() -> float:
	return _settings.ui_scale

func reduced_motion() -> bool:
	return _settings.reduced_motion
