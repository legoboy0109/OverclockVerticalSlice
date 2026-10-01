## capture_research.gd — screenshots the HQ research menu (CR-14) at the Steam Deck floor.
## Usage: `./redot tools/CaptureResearch.tscn` (needs a display)
##
## Stages a mid-game tree so every row state is on screen at once: startable, needs a
## parent, locked by a sibling, researched.
extends Node

const OUT: String = "res://production/qa/evidence/research-menu"
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
	state.per_player[0].current_credits = 4200
	var ps: PlayerState = state.per_player[0]
	for t: TechDef in [Techs.ATTACK_I, Techs.DEFENSE_I, Techs.PLATING]:   # Heavy Ordnance, Hardened Armor, Plating
		ps.completed_techs.append(t)
	var hq: StructureState = Research.researcher(state, 0)
	var lab := StructureState.new()
	lab.entity_id = 95
	lab.owner = 0
	lab.position = hq.position + Vector2i(0, 2)
	lab.type = StructureTypes.RESEARCH_LAB
	lab.current_hp = lab.type.hp
	lab.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[95] = lab
	state.grid.place(95, lab.position.x, lab.position.y)

	_select(root, hq.position)
	await _settle()
	_shot("01-hq-menu")
	_press(root, "Research")
	await _settle()
	_shot("02-research-picker")
	# ★ 2026-10-01 (branching trees): the tree list above, then one tree's view.
	_press(root, "Defense")
	await _settle()
	_shot("02b-research-tree")

	# Research in progress: the HQ menu names it, and Cancel Research quotes the refund.
	hq.research_target = Techs.PENETRATION
	hq.research_turns_remaining = 2
	root.select_at_cursor()
	await _settle()
	_select(root, hq.position)
	await _settle()
	_shot("03-hq-researching")
	print("done")
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
