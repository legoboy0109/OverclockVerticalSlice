## capture_legibility.gd — the S5-03 iso-legibility gate harness (Pillar 3).
##
## [b]Why this is separate from `capture_evidence.gd`.[/b] That harness documents
## individual Visual/Feel ACs on a deliberately sparse board — one unit per fact, well
## spaced, so the fact being evidenced is unambiguous. Pillar 3 asks the opposite
## question: is the board readable when everything is happening at once? A sparse board
## cannot fail that test, so it cannot pass it either.
##
## This harness therefore builds the WORST REALISTIC case rather than a representative
## one: every archetype from both factions, adjacent and depth-overlapping on the
## isometric diagonal, structures behind units, cover under units, at the shipping
## camera. If the board reads here it reads anywhere; if it does not, this is where the
## failure is visible.
##
## It asserts nothing — like its sibling it produces frames. `tools/analyse_legibility.py`
## does the measuring (grayscale silhouette distinctness, ownership separation under
## dichromacy and full desaturation, actor/stage contrast), and a human supplies the
## naive-observer half that no script can.
##
## Usage (needs a display; opens a window then closes itself):
## [codeblock]
## ./redot tools/CaptureLegibility.tscn
## [/codeblock]
## Frames land in `production/qa/evidence/s5-03-legibility/`.
extends Node2D

const OUT_DIR: String = "res://production/qa/evidence/s5-03-legibility"
const VIEW_SIZE: Vector2i = Vector2i(1280, 720)
const ORIGIN: Vector2 = Vector2(640.0, 170.0)

var _root: Node2D
var _board: BoardRenderer
var _feed: EntitySpriteFeed
var _shots: int = 0


func _ready() -> void:
	get_window().size = VIEW_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run()


func _run() -> void:
	# --- 1. The dense board, everything actionable (the common case) -----------
	_build(_dense_entities(), func(_e: EntityState) -> bool: return true)
	await _capture("01-dense-all-actionable",
		"Worst realistic case: 8 units + 4 structures, both factions, adjacent and depth-overlapping. All actionable.")

	# --- 2. Same board, mixed act-state (the real mid-turn picture) -----------
	# Odd entity ids spent, even ids available -- so spent and available units sit
	# adjacent and overlapping, which is the arrangement that actually tests whether
	# the act-state read survives a crowd.
	_build(_dense_entities(), func(e: EntityState) -> bool: return e.entity_id % 2 == 0)
	await _capture("02-dense-mixed-act-state",
		"Same board, alternating act-state. Tests the Pillar-1 read under crowding, not in isolation.")

	# --- 3. All spent (the dimmest the board ever gets) -----------------------
	_build(_dense_entities(), func(_e: EntityState) -> bool: return false)
	await _capture("03-dense-all-spent",
		"Every actor spent -- the dimmest state. If silhouettes fail anywhere they fail here.")

	# --- 4. The stack: same-tile-diagonal overlap, both factions --------------
	# ADR-0013's iso projection puts these in a descending diagonal where each sprite
	# partially occludes the one behind. This is the arrangement the art bible's
	# Principle 3 is written about.
	_build(_stack_entities(), func(_e: EntityState) -> bool: return true)
	await _capture("04-diagonal-stack",
		"Six units on one iso diagonal, alternating faction -- maximum depth occlusion.")

	# --- 5. A mirror pair: identical archetypes, opposing factions, adjacent ---
	_build(_mirror_entities(), func(_e: EntityState) -> bool: return true)
	await _capture("05-mirror-pairs",
		"Each archetype beside its enemy twin. Ownership is the ONLY difference -- isolates the hue read.")

	print("\nS5-03 capture complete: %d frames in %s" % [_shots, OUT_DIR])
	get_tree().quit()


func _build(entities: Array[EntityState], actionable: Callable) -> void:
	if _root != null:
		_root.queue_free()
	_root = Node2D.new()
	_root.position = ORIGIN
	add_child(_root)
	_board = BoardRenderer.new()
	_root.add_child(_board)

	var grid := GridState.new()
	grid.width = 8
	grid.height = 8
	grid.terrain = PackedByteArray()
	grid.terrain.resize(64)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(64)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	# Cover UNDER occupied tiles, not beside them: a terrain feature nobody stands on
	# does not test whether terrain competes with an actor for the same pixels.
	grid.terrain[grid.index(3, 3)] = GridState.Terrain.COVER
	grid.terrain[grid.index(4, 4)] = GridState.Terrain.COVER
	grid.terrain[grid.index(2, 5)] = GridState.Terrain.COVER
	_board.paint_terrain(grid)

	_feed = EntitySpriteFeed.new(_board, [Factions.RUSH, Factions.BOOM] as Array[FactionDef])
	_feed.actionable_predicate = actionable
	_feed.sync(entities)


## The dense board: every archetype, both factions, structures behind the line.
func _dense_entities() -> Array[EntityState]:
	return [
		_structure(1, 0, Vector2i(0, 0), StructureTypes.HQ),
		_structure(2, 1, Vector2i(7, 7), StructureTypes.HQ),
		_structure(3, 0, Vector2i(1, 6), StructureTypes.BARRACKS),
		_structure(4, 1, Vector2i(6, 1), StructureTypes.DEFENSIVE_STRUCTURE),
		_unit(11, 0, Vector2i(2, 3), UnitTypes.TROOPER),
		_unit(12, 0, Vector2i(3, 3), UnitTypes.SCOUT),
		_unit(13, 0, Vector2i(2, 4), UnitTypes.HEAVY),
		_unit(14, 0, Vector2i(2, 5), UnitTypes.SNIPER),
		_unit(21, 1, Vector2i(4, 4), UnitTypes.TROOPER),
		_unit(22, 1, Vector2i(4, 3), UnitTypes.SCOUT),
		_unit(23, 1, Vector2i(5, 4), UnitTypes.HEAVY),
		_unit(24, 1, Vector2i(3, 4), UnitTypes.SNIPER),
	] as Array[EntityState]


## Six units down one iso diagonal, alternating faction — maximum occlusion.
func _stack_entities() -> Array[EntityState]:
	return [
		_unit(11, 0, Vector2i(1, 1), UnitTypes.HEAVY),
		_unit(21, 1, Vector2i(2, 2), UnitTypes.TROOPER),
		_unit(12, 0, Vector2i(3, 3), UnitTypes.SNIPER),
		_unit(22, 1, Vector2i(4, 4), UnitTypes.HEAVY),
		_unit(13, 0, Vector2i(5, 5), UnitTypes.SCOUT),
		_unit(23, 1, Vector2i(6, 6), UnitTypes.TROOPER),
	] as Array[EntityState]


## Archetype beside its enemy twin — ownership is the only variable.
func _mirror_entities() -> Array[EntityState]:
	return [
		_unit(11, 0, Vector2i(1, 2), UnitTypes.TROOPER),
		_unit(21, 1, Vector2i(2, 2), UnitTypes.TROOPER),
		_unit(12, 0, Vector2i(1, 4), UnitTypes.HEAVY),
		_unit(22, 1, Vector2i(2, 4), UnitTypes.HEAVY),
		_unit(13, 0, Vector2i(4, 2), UnitTypes.SCOUT),
		_unit(23, 1, Vector2i(5, 2), UnitTypes.SCOUT),
		_unit(14, 0, Vector2i(4, 4), UnitTypes.SNIPER),
		_unit(24, 1, Vector2i(5, 4), UnitTypes.SNIPER),
	] as Array[EntityState]


func _unit(id: int, owner: int, tile: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	return u


func _structure(id: int, owner: int, tile: Vector2i, type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = id
	s.owner = owner
	s.position = tile
	s.type = type
	s.current_hp = type.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	return s


func _capture(name: String, caption: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, name]))
	_shots += 1
	print("  [%02d] %s — %s" % [_shots, name, caption])
