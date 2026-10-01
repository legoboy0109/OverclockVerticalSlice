## capture_rush.gd — screenshots the Rush row (2026-09-30) at the Steam Deck floor.
## Usage: `./redot tools/CaptureRush.tscn` (needs a display)
##
## Stages a Factory building a 3-turn vehicle, then presses Rush twice: enabled with its
## price and effect, the post-rush flash, and the floor ("ready next turn").
extends Node

const OUT: String = "res://production/qa/evidence/rush"
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
	var vehicle: UnitTypeDef = null
	for t: UnitTypeDef in UnitTypes.ALL:
		if t.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE and not t.can_build:
			vehicle = t
			break
	var factory := StructureState.new()
	factory.entity_id = 96
	factory.owner = 0
	factory.position = hq.position + Vector2i(0, 2)
	factory.type = StructureTypes.FACTORY
	factory.current_hp = factory.type.hp
	factory.build_status = StructureState.BuildStatus.COMPLETED
	factory.producing_type = vehicle
	factory.production_turns_remaining = 3
	factory.production_tile = factory.position + Vector2i(1, 0)
	state.entities_by_id[96] = factory
	state.grid.place(96, factory.position.x, factory.position.y)

	_select(root, factory.position)
	await _settle()
	_shot("01-factory-menu")
	_press(root, "Rush")
	await _settle()
	_shot("02-after-one-rush")
	_press(root, "Rush")
	await _settle()
	_shot("03-at-floor")
	print("rush: turns=%d ap=%d" % [factory.production_turns_remaining, state.per_player[0].current_ap])
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
