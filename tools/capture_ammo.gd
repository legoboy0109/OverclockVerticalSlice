## capture_ammo.gd — screenshots the ammo readout and the out-of-ammo Attack row (2026-10-01).
## Usage: `./redot tools/CaptureAmmo.tscn` (needs a display)
##
## Stages a Factory building a 3-turn vehicle, then presses Rush twice: enabled with its
## price and effect, the post-rush flash, and the floor ("ready next turn").
extends Node

const OUT: String = "res://production/qa/evidence/ammo"
const VIEW: Vector2i = Vector2i(1280, 800)


func _ready() -> void:
	get_window().size = VIEW
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run()


func _run() -> void:
	var root: VerticalSliceRoot = load("res://scenes/vertical_slice.tscn").instantiate()
	add_child(root)
	for i: int in 10:
		await get_tree().process_frame
	var state: GameState = root.state()
	state.per_player[0].current_ap = 20
	var hq: StructureState = Research.researcher(state, 0)
	var tank := UnitState.new()
	tank.entity_id = 97
	tank.owner = 0
	tank.type = UnitTypes.TANK
	tank.current_hp = tank.type.hp
	tank.position = hq.position + Vector2i(0, 3)
	if tank.type.requires_pilot:
		var pilot := UnitState.new()
		pilot.entity_id = 98
		pilot.owner = 0
		pilot.type = UnitTypes.TROOPER
		pilot.current_hp = pilot.type.hp
		tank.pilot = pilot
	tank.ammo_spent = 2
	state.entities_by_id[97] = tank
	state.grid.place(97, tank.position.x, tank.position.y)
	_select(root, tank.position)
	await _settle()
	_shot("01-tank-ammo-2-of-4")
	root.select_at_cursor()
	await _settle()
	tank.ammo_spent = Ammo.max_ammo(tank.type)
	_select(root, tank.position)
	await _settle()
	_shot("02-tank-out-of-ammo")
	print("ammo capture done")
	get_tree().quit()


func _select(root: VerticalSliceRoot, tile: Vector2i) -> void:
	while root.cursor_tile() != tile:
		var d: Vector2i = tile - root.cursor_tile()
		root.move_cursor(Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y)))
	root.select_at_cursor()


func _press(root: Node, prefix: String) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).visible and not (n as Button).disabled \
				and (n as Button).text.begins_with(prefix):
			(n as Button).emit_signal("pressed")
			return
		for c: Node in n.get_children():
			stack.append(c)


func _settle() -> void:
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("  wrote ", name)
