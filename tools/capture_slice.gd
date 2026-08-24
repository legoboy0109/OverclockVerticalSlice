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
	print("done")
	get_tree().quit()


func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("  wrote ", name)
