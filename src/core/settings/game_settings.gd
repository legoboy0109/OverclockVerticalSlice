## GameSettings — the player's own preferences, persisted across sessions.
##
## The project had NO settings store before 2026-08-24: `user://` was unused
## everywhere, so nothing a player chose survived closing the game. This is that
## store, and it is deliberately the only thing that touches the settings file —
## every screen reads and writes through here rather than reaching for
## `ConfigFile` itself.
##
## [b]What it holds[/b], and why each one is here rather than invented:
## [br]• [b]Input bindings[/b] — `accessibility-requirements.md` commits Standard
##   tier to "every bound input... rebindable independently across keyboard, mouse
##   and gamepad, with conflict warnings". Only OVERRIDES are stored, so a player
##   who never rebinds anything gets whatever `project.godot` ships, including
##   future changes to it.
## [br]• [b]UI scale[/b] — the same document commits to "Range 75%–150%, default
##   100%".
## [br]• [b]Reduced motion[/b] — committed at Standard tier, and cheap here because
##   `interaction-patterns.md`'s Snap-Never-Tween rule means every flourish rides
##   on top of an instant snap. Stripping them loses no information by design.
##
## [b]Applying is separate from storing.[/b] [method apply_all] pushes the values
## into the engine; the setters only record them. That keeps a screen able to
## preview a change before committing it, and keeps this class testable without a
## window.
class_name GameSettings
extends RefCounted

const PATH: String = "user://settings.cfg"

const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.50
const UI_SCALE_DEFAULT: float = 1.0

## The actions a player may rebind, in the order the settings screen lists them.
## `ui_*` actions are deliberately absent: they carry engine defaults for menu
## traversal as well as board movement, and letting a player unbind "confirm" from
## a menu is how someone locks themselves out of the settings screen that would
## fix it.
const REBINDABLE: Array[StringName] = [
	&"board_act", &"board_build", &"board_build_cycle",
	&"board_produce", &"board_produce_cycle",
	&"board_end_turn", &"board_pause", &"board_menu_focus",
	&"board_cursor_cycle",
]

## Human-readable names for the rebindable actions.
const ACTION_LABELS: Dictionary = {
	&"board_act": "Move / Attack",
	&"board_build": "Build",
	&"board_build_cycle": "Cycle Build Type",
	&"board_produce": "Produce",
	&"board_produce_cycle": "Cycle Unit Type",
	&"board_end_turn": "End Turn",
	&"board_pause": "Pause",
	&"board_menu_focus": "Focus Action Panel",
	&"board_cursor_cycle": "Jump Cursor",
}

## Which input family a binding belongs to. Kept separate so a player can rebind
## their pad without disturbing the keyboard and vice versa — the commitment says
## "independently across keyboard, mouse and gamepad".
enum Device { KEYBOARD, GAMEPAD }

var ui_scale: float = UI_SCALE_DEFAULT
var reduced_motion: bool = false

## Only the bindings the player actually changed: {action: {device: code}}.
## Absent entries fall through to whatever project.godot ships.
var _overrides: Dictionary = {}

## The bindings as shipped, captured before any override is applied, so
## [method reset_to_defaults] can restore them without reloading the project.
var _defaults: Dictionary = {}


func _init() -> void:
	_capture_defaults()


## Records the project's own bindings once, at startup, before anything overrides
## them. Without this "reset to defaults" would have nothing to reset TO — the
## InputMap is mutated in place by rebinding.
func _capture_defaults() -> void:
	for action: StringName in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		var per_device: Dictionary = {}
		for e: InputEvent in InputMap.action_get_events(action):
			var d: int = _device_of(e)
			if d >= 0 and not per_device.has(d):
				per_device[d] = _code_of(e)
		_defaults[action] = per_device


static func _device_of(e: InputEvent) -> int:
	if e is InputEventKey:
		return Device.KEYBOARD
	if e is InputEventJoypadButton:
		return Device.GAMEPAD
	return -1


static func _code_of(e: InputEvent) -> int:
	if e is InputEventKey:
		return (e as InputEventKey).physical_keycode
	if e is InputEventJoypadButton:
		return (e as InputEventJoypadButton).button_index
	return -1


## Builds the engine event for [param device]/[param code].
static func make_event(device: int, code: int) -> InputEvent:
	if device == Device.KEYBOARD:
		var k := InputEventKey.new()
		k.physical_keycode = code
		return k
	var j := InputEventJoypadButton.new()
	j.button_index = code
	return j


## The code currently bound to [param action] on [param device] — the override if
## one exists, otherwise the shipped default. -1 when nothing is bound.
func binding(action: StringName, device: int) -> int:
	if _overrides.has(action) and _overrides[action].has(device):
		return _overrides[action][device]
	if _defaults.has(action) and _defaults[action].has(device):
		return _defaults[action][device]
	return -1


## Every action already bound to [param code] on [param device], excluding
## [param except]. The conflict-warning query the accessibility commitment names.
func conflicts(code: int, device: int, except: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for action: StringName in REBINDABLE:
		if action == except:
			continue
		if binding(action, device) == code:
			out.append(action)
	return out


## Rebinds [param action] on [param device] to [param code].
##
## Conflicts are REPORTED, not refused: the caller decides. Refusing outright
## would leave a player unable to swap two bindings, since any swap passes through
## a moment where both actions want the same key.
func set_binding(action: StringName, device: int, code: int) -> void:
	if not _overrides.has(action):
		_overrides[action] = {}
	_overrides[action][device] = code


## Pushes every binding into the live [InputMap]. Rebuilds each action from
## scratch rather than appending, so a rebind replaces rather than accumulates.
func apply_bindings() -> void:
	for action: StringName in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for device: int in [Device.KEYBOARD, Device.GAMEPAD]:
			var code: int = binding(action, device)
			if code >= 0:
				InputMap.action_add_event(action, make_event(device, code))


## Applies display preferences to the engine.
func apply_display() -> void:
	var win: Window = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if win != null:
		win.content_scale_factor = ui_scale


func apply_all() -> void:
	apply_bindings()
	apply_display()


## Clears every override, returning to the shipped bindings and default display
## values. Does not save — the caller decides whether a reset is committed.
func reset_to_defaults() -> void:
	_overrides.clear()
	ui_scale = UI_SCALE_DEFAULT
	reduced_motion = false


## True iff the player has changed anything from the shipped defaults.
func has_overrides() -> bool:
	return not _overrides.is_empty() or ui_scale != UI_SCALE_DEFAULT or reduced_motion


# --- Persistence --------------------------------------------------------------

func save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "reduced_motion", reduced_motion)
	for action: StringName in _overrides:
		for device: int in _overrides[action]:
			cfg.set_value("bindings", "%s.%d" % [action, device], _overrides[action][device])
	return cfg.save(PATH)


## Loads saved preferences. A missing file is not an error — it is a first run.
func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", UI_SCALE_DEFAULT)),
		UI_SCALE_MIN, UI_SCALE_MAX)
	reduced_motion = bool(cfg.get_value("display", "reduced_motion", false))
	_overrides.clear()
	if not cfg.has_section("bindings"):
		return
	for key: String in cfg.get_section_keys("bindings"):
		var parts: PackedStringArray = key.rsplit(".", true, 1)
		if parts.size() != 2:
			continue
		var action := StringName(parts[0])
		# ★ Drop a saved binding for an action that no longer exists. A settings
		# file outlives the build that wrote it, and a renamed or removed action
		# would otherwise resurrect as a dead entry the player cannot clear.
		if not InputMap.has_action(action):
			continue
		var device: int = int(parts[1])
		if not _overrides.has(action):
			_overrides[action] = {}
		_overrides[action][device] = int(cfg.get_value("bindings", key, -1))
