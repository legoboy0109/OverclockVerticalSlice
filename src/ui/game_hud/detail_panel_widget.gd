## DetailPanelWidget — the HUD-owned detail panel whose CONTENT follows CAI's
## selection/inspection (ADR-0016 §6, TR-hud-013). Its chrome is HUD-owned; its
## content is a live verbatim read of whatever entity CAI's
## [signal CommandInterface.selection_changed] currently points at.
##
## [b]Outward-in, one-way[/b] (the leaf-claim guardrail, TR-hud-013/020): this
## panel SUBSCRIBES to [signal CommandInterface.selection_changed] — CAI never
## calls into this (or any) HUD node. The panel holds a [CommandInterface]
## reference solely to connect to its signal; it never drives CAI.
##
## Pinned vs peek ([SelectionTarget.pinned]): a persistent selection renders a
## solid accent edge; a transient inspection (peek) renders a dashed/dimmed edge
## — distinguishable by MORE than content/hue alone (CR-6, Accessibility E). The
## exact treatment is a [code]/ux-design[/code] concern; this widget carries the
## boolean state and the testable getters.
##
## Clears when nothing is selected ([code]entity_id == -1[/code]) or when the
## shown entity is destroyed (AC-13) — the upstream selection clears via
## selection_changed, and this widget also defensively clears on any
## [signal GameState.action_applied] where the shown entity no longer resolves.
##
## Usage:
## [codeblock]
## var panel := DetailPanelWidget.new()
## panel.bind(reader)                 # HudReactiveControl DI (read facade)
## panel.attach_interface(command_interface)   # outward-in selection seam
## hud_layer.add_child(panel)
## [/codeblock]
class_name DetailPanelWidget
extends HudReactiveControl

## The Command & Action Interface whose selection_changed this panel follows.
## Held ONLY to connect to the signal — never called into (leaf claim).
var _cmd: CommandInterface = null

## The entity currently shown, or -1 for "nothing selected/inspected".
var _target_id: int = -1

## True for a persistent selection, false for a transient inspection (peek).
var _pinned: bool = false


## Subscribes outward-in to [param cmd]'s [signal CommandInterface.selection_changed].
## Idempotent. This is the ONLY coupling to CAI — a one-way listen (ADR-0016 §6).
func attach_interface(cmd: CommandInterface) -> void:
	_cmd = cmd
	if not cmd.selection_changed.is_connected(_on_selection_changed):
		cmd.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(target: SelectionTarget) -> void:
	_target_id = target.entity_id
	_pinned = target.pinned
	queue_redraw()


## Overrides [method HudReactiveControl._on_action_applied]: on any board change,
## defensively clear if the shown entity no longer resolves (AC-13 destroyed-
## while-shown) — belt-and-suspenders with the upstream selection clear.
func _on_action_applied(_result: ActionResult) -> void:
	if _target_id != -1 and not _entity_exists(_target_id):
		_target_id = -1
		_pinned = false
	queue_redraw()


## Disconnects both the selection seam (here) and the base action_applied
## subscription (via [code]super()[/code]) on tree exit — no accumulation across
## a match restart within one process.
func _exit_tree() -> void:
	if _cmd != null and _cmd.selection_changed.is_connected(_on_selection_changed):
		_cmd.selection_changed.disconnect(_on_selection_changed)
	super()


func _entity_exists(entity_id: int) -> bool:
	if _reader == null:
		return false
	return not _reader.unit_info(entity_id).is_empty() or not _reader.structure_info(entity_id).is_empty()


# --- Display model (Integration-testable) ------------------------------------

## The entity currently shown, or -1 if the panel is empty.
func shown_entity_id() -> int:
	return _target_id

## True iff the panel is showing an entity (not empty).
func is_showing() -> bool:
	return _target_id != -1

## True for a pinned selection (solid edge), false for a peek (dashed/dimmed edge).
func is_pinned() -> bool:
	return _pinned

## The shown entity's read-only info snapshot ([method GameStateReader.unit_info]
## or [method GameStateReader.structure_info]), or [code]{}[/code] when empty.
func panel_info() -> Dictionary:
	if _reader == null or _target_id == -1:
		return {}
	var u: Dictionary = _reader.unit_info(_target_id)
	if not u.is_empty():
		return u
	return _reader.structure_info(_target_id)


func _draw() -> void:
	if _reader == null or _target_id == -1:
		return
	var info: Dictionary = panel_info()
	if info.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	# Edge: pinned = solid 2px accent; peek = thin dimmed (shape/weight channel,
	# not hue alone). Advisory treatment — the STATE (is_pinned) is what's tested.
	var edge: Color = Color.WHITE if _pinned else Color(0.55, 0.55, 0.6)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), edge, false, 2.0 if _pinned else 1.0)
	if font != null:
		draw_string(font, Vector2(6, 18), "hp %d/%d" % [info.get("current_hp", 0), info.get("hp", 0)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
