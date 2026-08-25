## InputGlyphs — Autoload. Names a bound action the way the device the player is CURRENTLY using
## names it.
##
## [b]Why this exists (S8-06).[/b] Every binding in the game has had a gamepad event since
## S6-17/S6-20, but nothing displayed them: the slice's status legend was a hardcoded string of
## keyboard keys, and [method ActionMenu._shortcut_for] matched [InputEventKey] only and returned
## an empty hint on a pad. **A player on a controller was told to press keys they do not have.**
##
## ⚠ [b]This is a Steam Deck Verified criterion[/b], not a nicety — the Deck is the project's
## hardware floor (S7-08), and Verified requires controller glyphs while a controller is in use.
##
## [b]How the active device is decided.[/b] The most recent real input event wins: a joypad button
## or a past-deadzone stick movement switches to [constant Device.GAMEPAD]; a key, mouse button or
## mouse movement switches back to [constant Device.KEYBOARD].
##
## ★ Mouse input counting as KEYBOARD is deliberate and matters on the floor target: the Deck's
## trackpads present as a mouse, so a player using them is genuinely in pointer mode and should be
## shown pointer/key labels rather than pad glyphs.
##
## Usage:
## [codeblock]
## var hint: String = InputGlyphs.label_for(&"board_build")   # "[B]" or "[LB]"
## InputGlyphs.device_changed.connect(_refresh_my_labels)
## [/codeblock]
extends Node

enum Device {
	KEYBOARD, ## Keyboard and/or mouse — including the Deck's trackpads, which present as a mouse.
	GAMEPAD,
}

## Emitted when, and only when, the active device actually changes — never once per event.
## Subscribers re-render their labels; a widget that never changes device never redraws.
signal device_changed(device: Device)

## Stick movement below this is drift, not a deliberate input, and must not flip the glyphs while
## a player is typing next to a resting controller.
const _STICK_DEADZONE: float = 0.5

var _device: Device = Device.KEYBOARD

## ★ Godot's [enum JoyButton] values in the layout the shipped bindings use (see `[input]` in
## project.godot). Names follow the Xbox/Deck face labels, which is what the Deck prints on its own
## hardware and what Verified expects a player to be able to match.
##
## ⚠ Not localised and deliberately so — these are printed glyphs on a physical device, not words.
const _PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}


func _ready() -> void:
	# ★ PROCESS_MODE_ALWAYS: the pause overlay runs while the tree is paused (S6-23), and its
	# labels must still follow the device the player switches to while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Watches every input for a device switch. [method Node._input] rather than
## [method Node._unhandled_input] on purpose — a press consumed by a focused Control still tells
## us which device the player is holding, and consumed presses are exactly what menu navigation
## produces.
func _input(event: InputEvent) -> void:
	var next: Device = _device
	if event is InputEventJoypadButton:
		next = Device.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= _STICK_DEADZONE:
			next = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		next = Device.KEYBOARD
	if next != _device:
		_device = next
		device_changed.emit(_device)


## The device the player is currently using.
func active_device() -> Device:
	return _device


## Forces the active device. [b]Tests and tools only[/b] — production code learns the device from
## real input. Emits [signal device_changed] if it changed, exactly as a real switch would.
func set_device_for_test(device: Device) -> void:
	if device != _device:
		_device = device
		device_changed.emit(_device)


## A bracketed, player-facing label for [param action] on the active device — `"[B]"` on a
## keyboard, `"[LB]"` on a pad. Empty when the action does not exist or has no event this device
## can produce.
##
## ★ Falls back to the other device's binding rather than returning nothing. A label naming the
## wrong device is a smaller failure than a control the player cannot discover at all — and the
## fallback is visible in play, whereas an empty string looks like an action with no shortcut.
func label_for(action: StringName) -> String:
	var name: String = _raw_label(action, _device)
	if name == "":
		name = _raw_label(action, Device.GAMEPAD if _device == Device.KEYBOARD else Device.KEYBOARD)
	return "[%s]" % name if name != "" else ""


## The unbracketed label, for callers composing their own formatting.
func name_for(action: StringName, device: int = -1) -> String:
	return _raw_label(action, _device if device < 0 else device as Device)


func _raw_label(action: StringName, device: Device) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if device == Device.GAMEPAD and event is InputEventJoypadButton:
			var btn: InputEventJoypadButton = event
			if _PAD_BUTTON_NAMES.has(btn.button_index):
				return _PAD_BUTTON_NAMES[btn.button_index]
		elif device == Device.KEYBOARD and event is InputEventKey:
			var key: InputEventKey = event
			# physical_keycode first: the bindings are authored physically so the layout matches
			# the key's POSITION, which is what a player looks at.
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			var text: String = OS.get_keycode_string(code)
			if text != "":
				return text
	return ""
