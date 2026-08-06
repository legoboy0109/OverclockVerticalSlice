extends Control
## ADR-0014 pre-Accepted engine spike: input-consumption-order vs. Control focus.
##
## Confirms LIVE (windowed, real keypresses — cannot be verified headlessly)
## whether a focused Control's focus_neighbor traversal consumes ui_up/down/
## left/right before _unhandled_input ever sees them, per ADR-0014 §2's
## "zero arbitration code" claim, and the two 4.6 dual-focus asymmetric cases
## the ADR flags as genuinely unverified (keyboard-focus-only Control vs.
## mouse-hover-only Control).
##
## See README.md for the interactive run protocol (exact keypress sequences
## and PASS/FAIL readouts for all 4 checks).

@onready var last_handler_label: Label = %LastHandlerLabel
@onready var unhandled_count_label: Label = %UnhandledCountLabel
@onready var focus_owner_label: Label = %FocusOwnerLabel
@onready var hovered_control_label: Label = %HoveredControlLabel
@onready var board_cursor_label: Label = %BoardCursorLabel
@onready var button_a: Button = %ButtonA
@onready var button_b: Button = %ButtonB
@onready var button_click_only: Button = %ButtonClickOnly
@onready var release_focus_button: Button = %ReleaseFocusButton
@onready var board_grid: GridContainer = %BoardGrid

const GRID_SIZE := 5

var board_cursor: BoardCursor = BoardCursor.new()
var grid_stub: GridStub = GridStub.new(GRID_SIZE, GRID_SIZE)
var unhandled_directional_count: int = 0
var tile_rects: Array[ColorRect] = []


func _ready() -> void:
	board_cursor.grid_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	_build_board_grid()
	_wire_focus_neighbors()
	_connect_focus_signals()
	release_focus_button.pressed.connect(_on_release_focus_pressed)
	_refresh_board_grid()
	_refresh_live_readouts()


func _process(_delta: float) -> void:
	# Cheap per-frame poll of engine-owned focus/hover state — this is NOT
	# gameplay logic (a real system would use signals only); it exists purely
	# so the tester has a continuously-live readout to correlate against
	# keypresses. Fine for a throwaway spike (see prototype-code rule).
	_refresh_live_readouts()


func _unhandled_input(event: InputEvent) -> void:
	var direction := Vector2i.ZERO
	var direction_name := ""
	if event.is_action_pressed(&"ui_up"):
		direction = BoardCursor.NORTH
		direction_name = "ui_up"
	elif event.is_action_pressed(&"ui_down"):
		direction = BoardCursor.SOUTH
		direction_name = "ui_down"
	elif event.is_action_pressed(&"ui_left"):
		direction = BoardCursor.WEST
		direction_name = "ui_left"
	elif event.is_action_pressed(&"ui_right"):
		direction = BoardCursor.EAST
		direction_name = "ui_right"
	elif event.is_action_pressed(&"board_cursor_cycle"):
		_cycle_board_cursor()
		return
	else:
		return

	unhandled_directional_count += 1
	board_cursor.step(direction, grid_stub)
	_refresh_board_grid()
	_set_last_handler(
		"_unhandled_input -> BoardCursor moved to %s (via %s)" % [board_cursor.grid_pos, direction_name],
		Color.LIME_GREEN
	)


func _cycle_board_cursor() -> void:
	# Fixed 4-tile candidate set for a visible, deterministic cycle demo.
	var candidates: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(GRID_SIZE - 1, 0),
		Vector2i(0, GRID_SIZE - 1), Vector2i(GRID_SIZE - 1, GRID_SIZE - 1),
	]
	unhandled_directional_count += 1
	board_cursor.jump_to_next(candidates, grid_stub)
	_refresh_board_grid()
	_set_last_handler(
		"_unhandled_input -> BoardCursor jumped to %s (via board_cursor_cycle)" % [board_cursor.grid_pos],
		Color.LIME_GREEN
	)


func _wire_focus_neighbors() -> void:
	# Vertical focus_neighbor chain across A/B so ui_up/ui_down drive real
	# focus traversal (not Tab/ui_focus_next) — this is the exact mechanism
	# ADR-0014 §2 claims arbitrates "for free" against BoardCursor.
	button_a.focus_neighbor_bottom = button_a.get_path_to(button_b)
	button_b.focus_neighbor_top = button_b.get_path_to(button_a)
	button_a.focus_neighbor_top = button_a.get_path_to(button_a)
	button_b.focus_neighbor_bottom = button_b.get_path_to(button_b)

	# ButtonClickOnly sits in the SAME chain (B -> ClickOnly -> wraps to A) so
	# we can observe whether FOCUS_CLICK actually suppresses arrow-key
	# traversal INTO it, per the ADR's flagged FOCUS_CLICK claim.
	button_b.focus_neighbor_bottom = button_b.get_path_to(button_click_only)
	button_click_only.focus_neighbor_top = button_click_only.get_path_to(button_b)
	button_click_only.focus_neighbor_bottom = button_click_only.get_path_to(button_click_only)
	button_click_only.focus_mode = Control.FOCUS_CLICK


func _connect_focus_signals() -> void:
	for b: Button in [button_a, button_b, button_click_only]:
		b.focus_entered.connect(_on_button_focus_entered.bind(b))
		b.gui_input.connect(_on_button_gui_input.bind(b))


func _on_button_focus_entered(button: Button) -> void:
	_set_last_handler(
		"GUI focus_neighbor traversal -> %s gained keyboard focus" % [button.name],
		Color.ORANGE
	)


func _on_button_gui_input(event: InputEvent, button: Button) -> void:
	# Fires only when this Button's GUI pass actually receives the event —
	# proves the event reached the Control layer (whether or not focus
	# changed as a result, e.g. a hover-only Button seeing a click).
	if event is InputEventKey and event.pressed and not event.echo:
		_set_last_handler(
			"GUI _gui_input -> %s received key (keycode=%s)" % [button.name, event.keycode],
			Color.ORANGE
		)


func _on_release_focus_pressed() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner:
		owner.release_focus()
	_set_last_handler("Manual: released all Control focus (no Control focused now)", Color.GRAY)


func _set_last_handler(text: String, color: Color) -> void:
	last_handler_label.text = text
	last_handler_label.add_theme_color_override(&"font_color", color)


func _refresh_live_readouts() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var hovered := get_viewport().gui_get_hovered_control()
	focus_owner_label.text = "Keyboard focus owner: %s" % [owner.name if owner else "(none)"]
	hovered_control_label.text = "Mouse-hovered control: %s" % [hovered.name if hovered else "(none)"]
	unhandled_count_label.text = "_unhandled_input directional count: %d" % [unhandled_directional_count]
	board_cursor_label.text = "BoardCursor.grid_pos: %s" % [board_cursor.grid_pos]


func _build_board_grid() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var rect := ColorRect.new()
			rect.custom_minimum_size = Vector2(48, 48)
			rect.color = Color.DIM_GRAY
			board_grid.add_child(rect)
			tile_rects.append(rect)


func _refresh_board_grid() -> void:
	for i in tile_rects.size():
		var x := i % GRID_SIZE
		var y := i / GRID_SIZE
		var is_cursor: bool = Vector2i(x, y) == board_cursor.grid_pos
		tile_rects[i].color = Color.LIME_GREEN if is_cursor else Color.DIM_GRAY
