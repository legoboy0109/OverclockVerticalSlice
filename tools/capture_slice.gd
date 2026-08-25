## capture_slice.gd — screenshot the REAL vertical slice, HUD and all.
##
## The other capture harnesses build a board in isolation to evidence one thing.
## This one loads `scenes/vertical_slice.tscn` itself, so what lands on disk is
## what a player actually sees: board, entities, HUD widgets, controls, the lot.
##
## Usage: `./redot tools/CaptureSlice.tscn` (needs a display)
extends Node

const OUT: String = "res://production/qa/evidence/slice-ui"
const VIEW: Vector2i = Vector2i(1600, 900)

## Override the capture resolution with `--view WxH` so the same script can
## evidence the two resolutions technical-preferences.md names ("keep the board
## readable at 1080p and 1440p") and .claude/rules/ui-code.md requires testing at.
## Shots are suffixed with the size when it is not the default.
func _view_size() -> Vector2i:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--view" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split("x")
			if parts.size() == 2:
				return Vector2i(int(parts[0]), int(parts[1]))
	return VIEW


func _suffix() -> String:
	var v: Vector2i = _view_size()
	return "" if v == VIEW else "-%dx%d" % [v.x, v.y]


func _ready() -> void:
	get_window().size = _view_size()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/vertical_slice.tscn")
	var slice: Node = packed.instantiate()
	add_child(slice)
	# Let the scene build, lay out and render before sampling.
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot("01-slice-boot")

	# Move the cursor a few tiles so any cursor treatment would be visible on a
	# tile that is NOT the default corner.
	if slice.has_method("move_cursor"):
		for i: int in 3:
			slice.move_cursor(Vector2i(1, 0))
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("02-cursor-moved")
	# --- Produce a unit and SELECT it, so the move-range overlay is on screen ---
	# This is the case the old immediate-mode `_draw()` was meant to serve and never
	# could, so it is the frame worth capturing.
	if slice.has_method("request_produce_at_cursor"):
		# Walk back toward the HQ first: shot 02 moved the cursor 3 tiles away, which
		# is outside the producer's deploy radius, so producing there silently fails.
		for i: int in 3:
			slice.move_cursor(Vector2i(-1, 0))
			await get_tree().process_frame
		slice.move_cursor(Vector2i(1, 0)) # one tile off the HQ = a legal deploy tile
		await get_tree().process_frame
		slice.request_produce_at_cursor()
		for i: int in 4:
			await get_tree().process_frame
		var st: GameState = slice.state()
		var target := Vector2i(-1, -1)
		for e: EntityState in st.entities():
			if e is UnitState and e.owner == 0:
				target = e.position
				break
		if target.x >= 0:
			# Walk the cursor onto the produced unit, then select it.
			for i: int in 40:
				var c: Vector2i = slice.cursor_tile()
				if c == target:
					break
				var step := Vector2i(
					signi(target.x - c.x) if c.x != target.x else 0,
					signi(target.y - c.y) if c.x == target.x else 0)
				if step == Vector2i.ZERO:
					break
				slice.move_cursor(step)
				await get_tree().process_frame
			slice.select_at_cursor()
			for i: int in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_shot("03-unit-selected-action-menu")

			# --- The verb's PREVIEW, which is what a menu pick opens ------------
			# The menu hides itself here on purpose: the overlay it just opened is
			# what the player now has to read, and a plate over it would compete.
			slice.open_verb_preview(CommandFSM.Verb.MOVE)
			for i: int in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_shot("03b-move-preview")

			# --- Back out: preview -> menu, spending nothing --------------------
			slice.back_out()
			for i: int in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_shot("03c-backed-out-to-menu")

	# --- A PRODUCER's menu + its per-type submenu -----------------------------
	# The case the old one-key-per-command scheme could not show at all: which
	# types this producer can make, what each costs, and which are out of reach.
	var hq := Vector2i(-1, -1)
	for e: EntityState in slice.state().entities():
		if e is StructureState and e.owner == 0:
			hq = e.position
			break
	if hq.x >= 0:
		for i: int in 60:
			var c: Vector2i = slice.cursor_tile()
			if c == hq:
				break
			var step := Vector2i(
				signi(hq.x - c.x) if c.x != hq.x else 0,
				signi(hq.y - c.y) if c.x == hq.x else 0)
			if step == Vector2i.ZERO:
				break
			slice.move_cursor(step)
			await get_tree().process_frame
		slice.select_at_cursor()
		for i: int in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03d-structure-selected-menu")

		slice.open_produce_picker()
		for i: int in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03e-produce-submenu")
		slice.back_out()
		slice.back_out()
		await get_tree().process_frame

	# --- Cancel Build's arm-then-confirm gate, and the cost echo ---------------
	# Both are /ux-review blocking fixes: the gate the Hold-to-Confirm Refund pattern
	# requires, and the projected-cost echo the GDD promised and nothing ever drove.
	if slice.has_method("begin_build_preview"):
		slice.begin_build_preview(slice.selected_buildable())
		for i: int in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03g-build-preview-cost-echo")
		slice.back_out()
		await get_tree().process_frame

	# --- The player-level Build picker (CR-5: it belongs to no entity) ---------
	if slice.has_method("open_build_picker"):
		slice.open_build_picker()
		for i: int in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03f-build-picker")
		slice.back_out()
		await get_tree().process_frame

	# --- Attack LIVE, so its priced row is on screen ---------------------------
	# The match never opens with an enemy in range, so the one shot that shows an
	# ENABLED Attack row has to stage its target. Everything else about the board is
	# the real match.
	if slice.has_method("select_at_cursor"):
		var st0: GameState = slice.state()
		var mine := Vector2i(-1, -1)
		for e: EntityState in st0.entities():
			if e is UnitState and e.owner == 0:
				mine = e.position
				break
		if mine.x >= 0:
			var foe := Vector2i(mine.x + 1, mine.y)
			if st0.entity_at(foe) == null:
				var enemy := UnitState.new()
				enemy.entity_id = 901
				enemy.owner = 1
				enemy.position = foe
				enemy.type = UnitTypes.SCOUT
				enemy.current_hp = enemy.type.hp
				st0.entities_by_id[901] = enemy
				st0.grid.occupancy[st0.grid.index(foe.x, foe.y)] = 901
				for i: int in 60:
					var c: Vector2i = slice.cursor_tile()
					if c == mine:
						break
					var step := Vector2i(signi(mine.x - c.x), 0) if c.x != mine.x \
						else Vector2i(0, signi(mine.y - c.y))
					if step == Vector2i.ZERO:
						break
					slice.move_cursor(step)
					await get_tree().process_frame
				slice.select_at_cursor()
				for i: int in 22:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				# Solvent player: the Attack row is priced and there is NO Disband row.
				_shot("03j-attack-priced")

				# --- Disband, offered only when it would unblock something ----------
				# Two triggers: a Credit deficit or being at/over population cap. This
				# forces the deficit one — reaching either for real takes several turns
				# of over-extension, and the shot is about the ROW, not about how a
				# player gets there. The cap trigger is covered at the model level
				# (command_fsm_test.gd) and renders the identical row.
				st0.per_player[0].in_deficit = true
				slice.back_out()
				slice.select_at_cursor()
				for i: int in 22:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				_shot("03k-disband-offered")

				# ...and its ARMED state. Disband destroys a unit outright, so the
				# two-press gate is the safety property most worth a picture.
				var armed: Button = _find_verb_row(slice, CommandFSM.Verb.DISBAND)
				if armed != null:
					armed.emit_signal("pressed")
					for i: int in 12:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					_shot("03l-disband-armed")
				slice.back_out() # disarms; nothing is destroyed
				st0.per_player[0].in_deficit = false
				slice.back_out()
				await get_tree().process_frame

	# --- A spent unit's menu: the OQ-5 wording, on screen ----------------------
	# Runs after every board/menu shot because it zeroes the player's AP, which
	# would poison those — but BEFORE the pause sequence, whose full-screen dim
	# would otherwise sit over this shot and the stand-down one after it. Pins the fix visually: a unit in open ground with nothing left to spend
	# is told it "needs AP", not that it has "no route" — the two point at opposite
	# fixes (end the turn vs. clear a path).
	if slice.has_method("select_at_cursor"):
		var st: GameState = slice.state()
		var spent := UnitState.new()
		spent.entity_id = 900
		spent.owner = 0
		spent.position = Vector2i(6, 5)
		spent.type = UnitTypes.TROOPER
		spent.current_hp = spent.type.hp
		st.entities_by_id[900] = spent
		st.grid.occupancy[st.grid.index(6, 5)] = 900
		st.per_player[0].current_ap = 0
		for i: int in 60:
			var c: Vector2i = slice.cursor_tile()
			if c == Vector2i(6, 5):
				break
			var step := Vector2i(signi(6 - c.x), 0) if c.x != 6 else Vector2i(0, signi(5 - c.y))
			if step == Vector2i.ZERO:
				break
			slice.move_cursor(step)
			await get_tree().process_frame
		slice.select_at_cursor()
		for i: int in 22:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03h-spent-unit-needs-ap")

	# --- Wait's stand-down mark: dim actor, idle notice, "stood down" row -------
	if slice.has_method("_on_menu_waited"):
		# Re-select the spent unit from the shot above and stand it down.
		slice.select_at_cursor()
		for i: int in 6:
			await get_tree().process_frame
		slice._on_menu_waited()
		for i: int in 10:
			await get_tree().process_frame
		# Re-open its menu so the Wait row's "stood down" state is on screen.
		slice.select_at_cursor()
		for i: int in 22:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("03i-stood-down")

	# --- Focus the menu, as a gamepad would with Back/Select -------------------
	if slice.has_method("toggle_menu_focus"):
		slice.toggle_menu_focus()
		for i: int in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("04-menu-focused")
	# --- Pause over the live board --------------------------------------------
	if slice.has_method("open_pause"):
		slice.open_pause()
		for i: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("05-paused")
		# ...and the destructive confirm, which is the gate that matters.
		slice._pause._open_confirm(PauseMenu.Confirm.QUIT)
		for i: int in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("06-pause-quit-confirm")
		get_tree().paused = false
	print("done")
	get_tree().quit()


## The action menu's row for [param verb], found by the meta tag ActionMenu puts on
## each one — never by label, since an ARMED row deliberately stops reading as its
## own verb name.
func _find_verb_row(slice: Node, verb: int) -> Button:
	var menu: Node = slice._action_menu
	if menu == null:
		return null
	var plate: Node = menu.get_node_or_null(^"MenuPlate")
	if plate == null or plate.get_child_count() == 0:
		return null
	for child: Node in plate.get_child(0).get_children():
		if child is Button and (child as Button).get_meta(&"verb", -1) == verb:
			return child
	return null


func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var full: String = name + _suffix()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, full]))
	print("  wrote ", full)
