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


func _ready() -> void:
	get_window().size = VIEW
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
			for i: int in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_shot("03-unit-selected-move-range")
	# --- Focus the menu, as a gamepad would with Back/Select -------------------
	if slice.has_method("toggle_menu_focus"):
		slice.toggle_menu_focus()
		for i: int in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("04-menu-focused")
	print("done")
	get_tree().quit()


func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("  wrote ", name)
