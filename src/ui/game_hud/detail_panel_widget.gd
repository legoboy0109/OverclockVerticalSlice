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


## ★ 2026-10-01 (holo glass): the selected-entity CARD — sprite, name, class, a segmented hp
## bar, ammo and the numbers a player weighs (was a bare "hp 40/40"). Drawn inside the
## bottom-left glass plate game_hud gives it; [member CARD_SIZE] is that plate's content area.
const CARD_SIZE: Vector2 = Vector2(300, 96)
const SPRITE_BOX: float = 84.0


func _class_label(info: Dictionary) -> String:
	var t: Variant = info.get("type")
	if t is UnitTypeDef:
		match (t as UnitTypeDef).unit_class:
			UnitTypeDef.UnitClass.GROUND_VEHICLE:
				return "GROUND VEHICLE"
			UnitTypeDef.UnitClass.AIR:
				return "AIRCRAFT"
		return "INFANTRY"
	if info.get("build_status", StructureState.BuildStatus.COMPLETED) == StructureState.BuildStatus.UNDER_CONSTRUCTION:
		return "UNDER CONSTRUCTION"
	return "STRUCTURE"


func _sprite_for(entity_id: int) -> Texture2D:
	for e: EntityState in _reader.entities():
		if e.entity_id == entity_id:
			var seat_faction: FactionDef = Factions.RUSH if e.owner == 0 else Factions.BOOM
			var path: String = EntitySpriteCatalog.texture_path(e, seat_faction, "e")
			return load(path) if path != "" and ResourceLoader.exists(path) else null
	return null


func _draw() -> void:
	if _reader == null or _target_id == -1:
		return
	var info: Dictionary = panel_info()
	if info.is_empty():
		return
	var owner: int = int(info.get("owner", 0))
	var hue: Color = UiTheme.player_hue(owner)
	# Sprite, fitted into the left box, bottom-aligned like it stands on the card.
	var tex: Texture2D = _sprite_for(_target_id)
	if tex != null:
		var sz: Vector2 = tex.get_size()
		var k: float = minf(SPRITE_BOX / sz.x, SPRITE_BOX / sz.y)
		var dst := Rect2(Vector2((SPRITE_BOX - sz.x * k) / 2.0, SPRITE_BOX - sz.y * k), sz * k)
		draw_texture_rect(tex, dst, false)
	var x: float = SPRITE_BOX + 14.0
	var t: Variant = info.get("type")
	var name_text: String = (t.display_name if t != null else "?").to_upper()
	draw_string(UiTheme.label_font(), Vector2(x, 10), _class_label(info) + ("" if owner == 0 else "  ·  ENEMY"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_LABEL, hue if owner != 0 else UiTheme.TEXT_MUTED)
	draw_string(UiTheme.font(700), Vector2(x, 34), name_text, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - x, 20, UiTheme.TEXT)
	# Segmented hp bar: one segment per 2 hp up to 14 segments, so small and large pools both read.
	var cur: int = int(info.get("current_hp", 0))
	var mx: int = maxi(1, int(info.get("hp", 1)))
	var segs: int = clampi(int(ceil(mx / 2.0)), 4, 14)
	var bar_w: float = CARD_SIZE.x - x
	var seg_w: float = (bar_w - (segs - 1) * 2.0) / segs
	var lit: int = int(ceil(float(cur) / mx * segs))
	for i: int in segs:
		var c: Color = Color(hue, 0.95) if i < lit else Color(1, 1, 1, 0.12)
		draw_rect(Rect2(Vector2(x + i * (seg_w + 2.0), 44), Vector2(seg_w, 7)), c)
	var line: String = "HP %d / %d" % [cur, mx]
	var max_ammo: int = int(info.get("max_ammo", 0))
	if max_ammo > 0:
		var ammo: int = int(info.get("ammo", 0))
		line += "    AMMO %d / %d" % [ammo, max_ammo] if ammo > 0 else "    OUT OF AMMO"
	draw_string(UiTheme.font(600), Vector2(x, 68), line, HORIZONTAL_ALIGNMENT_LEFT, bar_w, 13, UiTheme.TEXT)
	if info.has("effective_attack"):
		var stats: String = "ATK %d   RNG %d   DEF %d   MOVE %d AP" % [int(info["effective_attack"]),
			int(info.get("attack_range", 0)), int(info.get("defense", 0)), int(info.get("move_cost", 0))]
		draw_string(UiTheme.font(500), Vector2(x, 88), stats, HORIZONTAL_ALIGNMENT_LEFT, bar_w, 12, UiTheme.TEXT_MUTED)
	elif int(info.get("build_status", 1)) == StructureState.BuildStatus.UNDER_CONSTRUCTION:
		draw_string(UiTheme.font(500), Vector2(x, 88), "READY IN %d TURN(S)" % int(info.get("build_turns_remaining", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, bar_w, 12, UiTheme.TEXT_MUTED)
