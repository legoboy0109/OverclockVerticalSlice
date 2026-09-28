## SkirmishSetup — the screen between NEW SKIRMISH and the match (user decision 2026-09-28).
##
## Chooses each seat's faction and the three match settings the user chose to expose — AP per
## turn, round limit, who moves first — and remembers them ([MatchSettings], user://match.cfg)
## so the next skirmish opens on the last choice.
##
## [b]One control per setting, and every one works the same way:[/b] a button showing the
## current value. Activate it (click, Enter, pad A) to step forward; ←/→ (keys or d-pad) step
## either way; right-click steps back. No drop-downs and no text fields — both are awkward on a
## pad, and a pad is a required input on the Steam Deck floor.
class_name SkirmishSetup
extends Control

signal start_requested
signal closed

const SLICE_SCENE: String = "res://scenes/vertical_slice.tscn"
const ROW_SIZE: Vector2 = Vector2(560.0, 50.0)
const FONT_SIZE: int = 20
const HINT_SIZE: int = 15
const AP_STEP: int = 1
const ROUND_STEP: int = 10

var _settings: MatchSettings = null
var _rows: Array[Button] = []
var _start: Button = null
var _desc: Array[Label] = []
var _on_close: Callable = Callable()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings = MatchSettings.load_saved()
	_build()
	_refresh()
	_rows[0].grab_focus()


## Opens as an overlay over the main menu; [param on_close] runs when the player backs out.
func open_from(on_close: Callable) -> void:
	_on_close = on_close


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = MainMenu.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centred := CenterContainer.new()
	centred.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centred)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	centred.add_child(column)

	var title := Label.new()
	title.text = "NEW SKIRMISH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", MainMenu.TITLE_HUE)
	column.add_child(title)

	for i: int in 6:
		var row := Button.new()
		row.custom_minimum_size = ROW_SIZE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", FONT_SIZE)
		row.add_theme_color_override("font_color", MainMenu.ENTRY_TEXT)
		MenuStyle.apply(row)
		row.pressed.connect(_step.bind(i, 1))
		row.gui_input.connect(_on_row_input.bind(i))
		column.add_child(row)
		_rows.append(row)
		if i < 2:
			# The faction's one-line identity, under its row — choosing blind is not a choice.
			var d := Label.new()
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(ROW_SIZE.x, 0)
			d.add_theme_font_size_override("font_size", HINT_SIZE)
			d.add_theme_color_override("font_color", MainMenu.FOOTER_TEXT)
			column.add_child(d)
			_desc.append(d)

	var hint := Label.new()
	hint.text = "< / > or click to change.  Your colour is orange, the opponent's cyan."
	hint.add_theme_font_size_override("font_size", HINT_SIZE)
	hint.add_theme_color_override("font_color", MainMenu.FOOTER_TEXT)
	column.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_start = _make_button(buttons, "START")
	_start.pressed.connect(_on_start)
	var back: Button = _make_button(buttons, "BACK")
	back.pressed.connect(_on_back)


func _make_button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, MainMenu.MIN_HIT_TARGET)
	b.add_theme_font_size_override("font_size", MainMenu.ENTRY_FONT_SIZE)
	b.add_theme_color_override("font_color", MainMenu.ENTRY_TEXT)
	MenuStyle.apply(b)
	parent.add_child(b)
	return b


func _on_row_input(event: InputEvent, row: int) -> void:
	if event.is_action_pressed(&"ui_left"):
		_step(row, -1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_step(row, 1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_step(row, -1)
		accept_event()


## Steps setting [param row] by [param dir] (wrapping for lists, clamping for numbers).
func _step(row: int, dir: int) -> void:
	var playable: Array[FactionDef] = Factions.playable()
	match row:
		0, 1:
			if not playable.is_empty():
				var at: int = maxi(0, playable.find(_settings.factions[row]))
				_settings.factions[row] = playable[posmod(at + dir, playable.size())]
		2:
			_settings.ap_per_turn = clampi(_settings.ap_per_turn + dir * AP_STEP,
				MatchSettings.AP_MIN, MatchSettings.AP_MAX)
		3:
			_settings.round_limit = clampi(_settings.round_limit + dir * ROUND_STEP,
				MatchSettings.ROUNDS_MIN, MatchSettings.ROUNDS_MAX)
		4:
			_settings.first_mover = posmod(_settings.first_mover + dir, 3)
		5:
			var maps: Array[MapDefinition] = Maps.all()
			var at: int = maxi(0, maps.find(_settings.map))
			_settings.map = maps[posmod(at + dir, maps.size())]
	_refresh()


func _refresh() -> void:
	var movers: Array[String] = ["You", "The opponent", "Random"]
	var texts: Array[String] = [
		"Your faction:    < %s >" % _settings.factions[0].display_name,
		"Opponent:        < %s >" % _settings.factions[1].display_name,
		"AP per turn:     < %d >" % _settings.ap_per_turn,
		"Round limit:     < %d >" % _settings.round_limit,
		"Moves first:     < %s >" % movers[_settings.first_mover],
		"Map:             < %s (%dx%d) >" % [_settings.map.display_name, _settings.map.width, _settings.map.height],
	]
	for i: int in _rows.size():
		_rows[i].text = texts[i]
	for i: int in _desc.size():
		_desc[i].text = _settings.factions[i].description


## The settings as shown — for tests and for the slice.
func settings() -> MatchSettings:
	return _settings


func _on_start() -> void:
	_settings.save()
	MatchSettings.current = _settings
	start_requested.emit()
	get_tree().change_scene_to_file(SLICE_SCENE)


func _on_back() -> void:
	_settings.save()   # remembered even if the player backs out — they chose it
	closed.emit()
	if _on_close.is_valid():
		_on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
