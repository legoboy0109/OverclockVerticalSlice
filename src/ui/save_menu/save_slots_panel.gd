## SaveSlotsPanel — the Save and Load screens (user decision 2026-09-29: autosave + manual slots).
##
## One panel, two modes. [enum Mode] LOAD lists the autosave and the manual slots; empty ones are
## shown but inert. SAVE lists only the manual slots (the autosave is written by the game itself).
## Every row is a button, so it works the same by mouse, keyboard or pad; saving over a used slot
## asks for a second press on the same row rather than opening a dialog.
##
## [b]It owns no game state.[/b] It emits [signal slot_chosen] with the slot id and the owner
## saves or loads; [signal closed] when the player backs out.
class_name SaveSlotsPanel
extends Control

signal slot_chosen(slot: String)
signal closed

enum Mode { SAVE, LOAD }

const ROW_WIDTH: float = 720.0

var mode: int = Mode.LOAD
var _rows: Array[Button] = []
var _slots: Array[String] = []
var _armed_overwrite: String = ""


## Creates a panel in [param panel_mode]; add it to the tree to show it.
static func create(panel_mode: int) -> SaveSlotsPanel:
	var p := SaveSlotsPanel.new()
	p.mode = panel_mode
	return p


func _ready() -> void:
	MenuStyle.fill_viewport(self)
	_build()
	var first: Button = null
	for b: Button in _rows:
		if not b.disabled:
			first = b
			break
	if first != null:
		first.grab_focus()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = MenuStyle.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var centred := CenterContainer.new()
	centred.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centred)
	var plate: PanelContainer = MenuStyle.make_plate()
	centred.add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MenuStyle.ENTRY_GAP)
	plate.add_child(column)

	var title := Label.new()
	title.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", MenuStyle.ACCENT)
	MenuStyle.glow_label(title, MenuStyle.ACCENT)   # ★ 2026-10-01: holo-glass neon title
	column.add_child(title)

	_slots.clear()
	if mode == Mode.LOAD:
		_slots.append(SaveGame.AUTOSAVE)
	_slots.append_array(SaveGame.MANUAL_SLOTS)
	for slot: String in _slots:
		var info: SaveGame.SlotInfo = SaveGame.info(slot)
		var interactive: bool = info.exists or mode == Mode.SAVE
		var row: Button = MenuStyle.make_entry(row_text(info), interactive, ROW_WIDTH)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 18)
		row.pressed.connect(_on_row.bind(slot))
		column.add_child(row)
		_rows.append(row)

	var back: Button = MenuStyle.make_entry("BACK", true, ROW_WIDTH)
	back.pressed.connect(_close)
	column.add_child(back)


## What a slot's row says: its name, then the saved match and when — or "Empty".
static func row_text(info: SaveGame.SlotInfo) -> String:
	var name: String = "Autosave" if info.slot == SaveGame.AUTOSAVE \
		else "Slot %d" % (SaveGame.MANUAL_SLOTS.find(info.slot) + 1)
	if not info.exists:
		return "%s  —  Empty" % name
	var when: String = Time.get_datetime_string_from_unix_time(info.saved_at + _utc_offset_sec(), true)
	return "%s  —  %s  —  %s" % [name, info.label, when]


static func _utc_offset_sec() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _on_row(slot: String) -> void:
	if mode == Mode.SAVE and SaveGame.exists(slot) and _armed_overwrite != slot:
		# First press on a used slot: ask for a second one, on the same row.
		_armed_overwrite = slot
		_rows[_slots.find(slot)].text = "Press again to overwrite  —  " + SaveGame.info(slot).label
		return
	_armed_overwrite = ""
	slot_chosen.emit(slot)


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


## Row captions, in order — for tests.
func row_labels() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _rows:
		out.append(b.text)
	return out


## Whether each row can be chosen — for tests.
func row_enabled() -> Array[bool]:
	var out: Array[bool] = []
	for b: Button in _rows:
		out.append(not b.disabled)
	return out


## Presses the row for [param slot] as a player would — for tests.
func press(slot: String) -> void:
	_on_row(slot)
