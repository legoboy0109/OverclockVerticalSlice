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

## ★ S8-07 — the UI scale applied on a floor-resolution screen when the player has not chosen one.
##
## The HUD was laid out against a 1600×900 design viewport and `window/stretch/mode` is unset, so
## at 1280×800 — the Steam Deck floor (S7-08) — every element keeps its pixel size and simply has
## less room. Nothing clips or overlaps; what a physically smaller *panel* needs is larger text.
##
## [b]Layout is not the constraint.[/b] Probing the real slice at 1280×800 and counting HUD-plate
## intersections found **zero overlaps at every scale from 1.00 to 1.50** — the settings maximum.
## The plates are edge-anchored and the status strip is centred, so they stay clear even at a
## logical 853×533.
##
## ⚠ [b]An earlier draft of this constant claimed 1.10 was a measured ceiling, with 1.15 colliding.
## That was wrong.[/b] The probe behind it filtered candidate Controls against the *physical*
## viewport width rather than the *logical* one, so full-screen scrims and overlays — which are
## supposed to cover everything — were counted as collisions. The number was real and the
## conclusion was nonsense. ★ Recorded because the threshold nearly shipped with that reasoning
## attached to it, and the reasoning is what a future reader would have trusted.
##
## [b]So the value is chosen for legibility, and it is PROVISIONAL.[/b] 1.15 lifts the menu's 22 px
## body text to ~25 px against the Standard tier's 20 px floor, on a panel with roughly twice a
## desktop monitor's pixel density. It is deliberately modest rather than maximal:
## ⛔ **no Steam Deck has run this build**, so the physical result is reasoned, not observed.
## Layout tolerates far more, so this can be raised on evidence without touching anything else.
const UI_SCALE_SMALL_SCREEN: float = 1.15

## At or below this width a display is treated as floor-class. The Deck is 1280 wide; 1366 is the
## next common small-laptop step and behaves the same way, so the band covers both without
## catching a 1440p window that has merely been made narrow.
const SMALL_SCREEN_MAX_WIDTH: int = 1366

## Minimum width for a viewport to be considered a real display at all. Headless runs and test
## harnesses report a few dozen pixels, and they must not be handed a small-screen default —
## that would silently change what every other suite renders.
const _MIN_REAL_WIDTH: int = 640

## The actions a player may rebind, in the order the settings screen lists them.
## `ui_*` actions are deliberately absent: they carry engine defaults for menu
## traversal as well as board movement, and letting a player unbind "confirm" from
## a menu is how someone locks themselves out of the settings screen that would
## fix it.
const REBINDABLE: Array[StringName] = [
	&"board_act", &"board_attack", &"board_build",
	&"board_produce",
	&"board_end_turn", &"board_pause", &"board_menu_focus",
	&"board_cursor_cycle",
]

## Human-readable names for the rebindable actions.
## ★ 2026-08-24 (action menu). Three changes, all consequences of the contextual
## action menu replacing per-command keys (`design/ux/action-menu.md`, decisions
## 2 and 3):
## [br]• [code]board_act[/code] is relabelled Move — it no longer means
##   "move or attack, whichever fits".
## [br]• [code]board_attack[/code] is new, the other half of that split.
## [br]• The two type-cycle bindings are GONE. They mutated a hidden selection
##   that the menu's submenu now shows outright, so the table would have listed
##   two rebindable keys for a command the player can no longer issue.
##
## A saved override for a removed action stays harmlessly in the settings file and
## is skipped on load ([method _capture_defaults] and [method apply_all] both gate
## on [method InputMap.has_action]) — it is neither applied nor an error.
const ACTION_LABELS: Dictionary = {
	&"board_act": "Move",
	&"board_attack": "Attack",
	&"board_build": "Build",
	&"board_produce": "Produce",
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


## True iff [param action]/[param device] carries a player override, i.e. it
## differs from what the project shipped. Drives both the per-binding reset
## affordance and the "which of these have I changed?" read the settings table
## otherwise has no way to give.
func is_overridden(action: StringName, device: int) -> bool:
	return _overrides.has(action) and _overrides[action].has(device)


## Clears the override on ONE binding, restoring just that one to its shipped
## default and leaving every other customisation alone.
##
## ★ Added 2026-08-24. [method reset_to_defaults] was the only revert, which meant
## a player who mis-bound a single control had to discard every other change they
## had made to fix it — an all-or-nothing undo for a per-row mistake. The settings
## spec flagged it as an open question; this closes it.
##
## A no-op when the binding is not overridden, so the caller need not check first.
func clear_binding(action: StringName, device: int) -> void:
	if not _overrides.has(action):
		return
	_overrides[action].erase(device)
	# Drop the action entirely once its last override goes, so `has_overrides()`
	# and the saved file both stop mentioning a binding that is back to default.
	if _overrides[action].is_empty():
		_overrides.erase(action)


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


## The UI scale to apply on a display of [param viewport], for a player who has not chosen one.
##
## Pure and static so the band can be tested without a window. Returns [constant UI_SCALE_DEFAULT]
## for anything that is not a real, floor-class display.
static func recommended_ui_scale(viewport: Vector2i) -> float:
	if viewport.x < _MIN_REAL_WIDTH:
		return UI_SCALE_DEFAULT # headless / test harness — never auto-scale these
	if viewport.x <= SMALL_SCREEN_MAX_WIDTH:
		return UI_SCALE_SMALL_SCREEN
	return UI_SCALE_DEFAULT


## Applies display preferences to the engine.
##
## ★ S8-07: when the player has NOT chosen a scale, a floor-class display gets
## [constant UI_SCALE_SMALL_SCREEN] instead of 1.0 — the Deck's 1280×800 sits on a 7″ panel and
## the HUD was laid out for 1600×900.
##
## ⚠ This does NOT write an override. `GameSettings` stores overrides only (S6-24), precisely so a
## player inherits future default changes; auto-scaling by *writing* 1.10 would pin them to today's
## answer forever. An explicit choice still wins — including an explicit 1.0.
func apply_display() -> void:
	var win: Window = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if win == null:
		return
	var effective: float = ui_scale
	if is_equal_approx(ui_scale, UI_SCALE_DEFAULT):
		effective = recommended_ui_scale(win.size)
	win.content_scale_factor = effective


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
