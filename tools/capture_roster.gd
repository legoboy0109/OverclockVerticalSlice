## capture_roster.gd — screenshot chosen unit types standing on the REAL board.
##
## Art review at true game scale: loads `scenes/vertical_slice.tscn`, stands a row of
## the requested unit types for player 0 (orange) and a row for player 1 (cyan) on
## open tiles, and screenshots it — once at the boot camera and once zoomed on the
## lineup. This is the check the HD-2D pivot needs: a sprite sheet on a flat colour
## flatters art that the real board (terrain, overlays, neighbours) does not.
##
## Usage: `./redot tools/CaptureRoster.tscn -- --units levy,knight --out order-infantry`
##        (needs a display; ids are vault note ids, i.e. the .tres basenames)
## Structure ids (e.g. empire_factory) work too — they are placed completed, or as construction
## sites with `--site`.
extends Node

const OUT: String = "res://production/qa/evidence/roster"
const VIEW: Vector2i = Vector2i(1600, 900)


func _arg(flag: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return fallback


func _ready() -> void:
	get_window().size = VIEW
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run()


func _type_by_id(id: String) -> UnitTypeDef:
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.resource_path.get_file().get_basename() == id:
			return t
	return null


func _struct_by_id(id: String) -> StructureTypeDef:
	for t: StructureTypeDef in StructureTypes.ALL:
		if t.resource_path.get_file().get_basename() == id:
			return t
	return null


func _run() -> void:
	var slice: Node = (load("res://scenes/vertical_slice.tscn") as PackedScene).instantiate()
	add_child(slice)
	for i: int in 8:
		await get_tree().process_frame
	# --flat renders with the HD-2D lighting off, through the SAME path the Settings toggle
	# uses (GameSettings.edge_blur + glow_effects, not saved), for before/after comparisons.
	if OS.get_cmdline_user_args().has("--flat") and slice.get("_lighting") != null:
		Settings.settings.edge_blur = false
		Settings.settings.glow_effects = false
		slice._lighting.apply_setting()
	var st: GameState = slice.state()
	var ids: PackedStringArray = _arg("--units", "trooper").split(",")
	var name: String = _arg("--out", "roster")

	# Find two rows of open, passable tiles near the middle of the map.
	var w: int = st.grid.width
	var h: int = st.grid.height
	var placed: Array[Vector2i] = []
	for row: int in 2:
		var y0: int = h / 2 - 1 + row * 2
		var x: int = maxi(0, w / 2 - ids.size())
		for id: String in ids:
			var type: UnitTypeDef = _type_by_id(id)
			var stype: StructureTypeDef = _struct_by_id(id) if type == null else null
			if type == null and stype == null:
				push_error("capture_roster: unknown unit/structure id '%s'" % id)
				continue
			var y: int = y0
			while x < w and (not st.grid.is_passable(x, y) or st.entity_at(Vector2i(x, y)) != null):
				x += 1
			if x >= w:
				break
			if stype != null:
				var b := StructureState.new()
				b.entity_id = st.next_entity_id
				st.next_entity_id += 1
				b.owner = row
				b.type = stype
				b.current_hp = stype.hp
				b.build_status = StructureState.BuildStatus.UNDER_CONSTRUCTION \
					if OS.get_cmdline_user_args().has("--site") else StructureState.BuildStatus.COMPLETED
				b.build_turns_remaining = 2
				b.position = Vector2i(x, y)
				st.entities_by_id[b.entity_id] = b
				st.grid.place(b.entity_id, x, y)
				placed.append(b.position)
				x += 2
				continue
			var u := UnitState.new()
			u.entity_id = st.next_entity_id
			st.next_entity_id += 1
			u.owner = row
			u.type = type
			u.current_hp = type.hp
			# `--dry` places every unit out of ammo, to check the board's out-of-ammo mark.
			if OS.get_cmdline_user_args().has("--dry"):
				u.ammo_spent = Ammo.max_ammo(type)
			# `--damage` halves every other unit's hp, to check the damaged-only hp bar.
			if OS.get_cmdline_user_args().has("--damage") and placed.size() % 2 == 0:
				u.current_hp = maxi(1, type.hp / 2)
			u.position = Vector2i(x, y)
			st.entities_by_id[u.entity_id] = u
			st.grid.place(u.entity_id, x, y)
			placed.append(u.position)
			x += 2
	slice._refresh_occupant_pick_regions()
	# `--no-hud` hides every screen-space layer at the HUD's level, for clean board backdrops
	# (UI mockups, 2026-10-01). The HD-2D edge blur (layer 1) stays — it is part of the board look.
	if OS.get_cmdline_user_args().has("--no-hud"):
		for n: Node in slice.find_children("*", "CanvasLayer", true, false):
			if (n as CanvasLayer).layer >= Hd2dLighting.HUD_CANVAS_LAYER:
				(n as CanvasLayer).visible = false
	# `--cursor-first` puts the board cursor on the first placed unit (hp-number check).
	if OS.get_cmdline_user_args().has("--cursor-first") and not placed.is_empty():
		slice._cursor.grid_pos = placed[0]
		slice._sync_cursor_highlight()
	# `--income` opens the Credits breakdown card.
	if OS.get_cmdline_user_args().has("--income"):
		slice._hud.income_breakdown().toggle()
	# `--game-over=<winner>` ends the match (HQ destroyed) to capture the game-over screen.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--game-over="):
			st.match_status = GameState.MatchStatus.GAME_OVER
			st.winner = int(a.split("=")[1])
			st.win_reason = GameState.WinReason.HQ_DESTROYED
			var ov: GameOverOverlay = slice._hud.game_over_overlay()
			ov._sync_plate()
			ov.queue_redraw()
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot(name + "-board")
	# --perf: average GPU frame time over 120 frames at the boot camera (render cost of
	# the HD-2D lighting, measured against a --flat run).
	if OS.get_cmdline_user_args().has("--perf"):
		var vp_rid: RID = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		for i: int in 30:
			await get_tree().process_frame
		var total: float = 0.0
		for i: int in 120:
			await get_tree().process_frame
			total += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		print("capture_roster: gpu_ms=%.3f" % (total / 120.0))

	# Zoom onto the lineup so each sprite is judged at close range too.
	if not placed.is_empty():
		var cam: Camera2D = slice.camera()
		var sum := Vector2.ZERO
		for p: Vector2i in placed:
			sum += slice._board.grid_to_screen(p) if slice._board.has_method("grid_to_screen") else Vector2.ZERO
		cam.position = sum / placed.size()
		cam.zoom = Vector2(2, 2)
		for i: int in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot(name + "-zoom")
	get_tree().quit()


func _shot(label: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUT, label]
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture_roster: wrote ", path)

