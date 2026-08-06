## ADR-0013 pre-Accepted engine spike — interactive scene.
## THROWAWAY. Validates live in the Redot 26.2 editor what the ADR currently only
## asserts from documentation/precedent:
##   1. TileSet.TILE_SHAPE_ISOMETRIC cell placement renders correct 2:1 dimetric diamonds.
##   2. Node2D.y_sort_enabled produces correct front-to-back draw order for occupants
##      (a movable unit) + a tall prop.
## Also re-demonstrates (live, not just headlessly) grid_to_screen()/screen_to_grid()
## exact-inverse round-trip via click-to-highlight, and a simplified pick_at()-style
## occupant-priority-then-diamond-fallback per ADR-0013 §4.
##
## Structure (per ADR §diagram):
##   IsoSpike (Node2D)
##    ├─ FloorTileMapLayer      (TILE_SHAPE_ISOMETRIC; z_index 0)
##    ├─ OverlayTileMapLayer    (shares floor's TileSet config; z_index 1)
##    ├─ OccupantLayer (y_sort_enabled = true; z_index 2)
##    │   ├─ TallProp (Sprite2D)     — fixed at one tile, visually taller than the diamond
##    │   └─ Unit (Sprite2D)         — arrow-key movable, one tile per press
##    └─ HighlightMarker (Sprite2D) — outlines the tile under the mouse on click
extends Node2D

const GRID_WIDTH := 14
const GRID_HEIGHT := 16

const PROP_TILE := Vector2i(6, 7)
const UNIT_START_TILE := Vector2i(6, 6)   # directly "north" (lower-right-ish) of the prop;
                                            # move the unit through/around it to test Y-sort.

@onready var floor_layer: TileMapLayer = $FloorTileMapLayer
@onready var overlay_layer: TileMapLayer = $OverlayTileMapLayer
@onready var occupant_layer: Node2D = $OccupantLayer
@onready var tall_prop: Sprite2D = $OccupantLayer/TallProp
@onready var unit: Sprite2D = $OccupantLayer/Unit
@onready var highlight: Sprite2D = $HighlightMarker
@onready var info_label: Label = $UILayer/InfoLabel

var iso_transform: BoardTransform = BoardTransform.new()
var unit_tile: Vector2i = UNIT_START_TILE
var overlay_tile: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	_build_and_apply_shared_tileset()
	_paint_floor_checkerboard()
	_place_prop()
	_place_unit()
	_setup_highlight()
	_update_info_label()

# ---------------------------------------------------------------------------
# TileSet + floor painting
# ---------------------------------------------------------------------------

func _build_and_apply_shared_tileset() -> void:
	var built := IsoTileSetBuilder.build_shared_tileset()
	var tile_set: TileSet = built["tileset"]
	# ADR §3: overlay shares the floor's exact TileSet resource/config — same object,
	# not a re-authored copy, so alignment is a structural guarantee.
	floor_layer.tile_set = tile_set
	overlay_layer.tile_set = tile_set

func _paint_floor_checkerboard() -> void:
	var source_id := 0
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var atlas_coords := IsoTileSetBuilder.ATLAS_FLOOR_A if (x + y) % 2 == 0 else IsoTileSetBuilder.ATLAS_FLOOR_B
			floor_layer.set_cell(Vector2i(x, y), source_id, atlas_coords)

# ---------------------------------------------------------------------------
# Occupants: tall prop (fixed) + unit (movable) — the y_sort_enabled live check
# ---------------------------------------------------------------------------

func _place_prop() -> void:
	# Deliberately taller than one tile's diamond height, with its pivot (texture bottom
	# edge) at the ground-contact point, per ADR §1's "grid_to_screen is also the sprite
	# placement anchor" convention — sprite.position = grid_to_screen(tile), no fudge offset.
	var prop_w := 96
	var prop_h := 176   # taller than TILE_HEIGHT_PX (64) by design — must visibly overhang
	var texture := IsoTileSetBuilder.build_placeholder_sprite_texture(
		prop_w, prop_h, Color(0.55, 0.35, 0.15), Color(0.25, 0.15, 0.05)
	)
	tall_prop.texture = texture
	tall_prop.offset = Vector2(-prop_w / 2.0, -prop_h)  # bottom-center pivot
	tall_prop.position = iso_transform.grid_to_screen(PROP_TILE)
	tall_prop.z_index = 0  # coarse band only; y_sort_enabled on the parent does the real work

func _place_unit() -> void:
	var unit_w := 56
	var unit_h := 88
	var texture := IsoTileSetBuilder.build_placeholder_sprite_texture(
		unit_w, unit_h, Color(0.2, 0.4, 0.85), Color(0.05, 0.1, 0.3)
	)
	unit.texture = texture
	unit.offset = Vector2(-unit_w / 2.0, -unit_h)  # bottom-center pivot, same convention
	unit.position = iso_transform.grid_to_screen(unit_tile)
	unit.z_index = 0

func _move_unit(delta_tile: Vector2i) -> void:
	var next := unit_tile + delta_tile
	next.x = clampi(next.x, 0, GRID_WIDTH - 1)
	next.y = clampi(next.y, 0, GRID_HEIGHT - 1)
	unit_tile = next
	unit.position = iso_transform.grid_to_screen(unit_tile)
	_update_info_label()

# ---------------------------------------------------------------------------
# Click-to-highlight: live screen_to_grid() + simplified pick_at()
# ---------------------------------------------------------------------------

func _setup_highlight() -> void:
	var texture := IsoTileSetBuilder.build_placeholder_sprite_texture(
		int(BoardTransform.TILE_WIDTH_PX), int(BoardTransform.TILE_HEIGHT_PX),
		Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 0.1, 0.1, 0.9)
	)
	highlight.texture = texture
	highlight.offset = Vector2(-BoardTransform.TILE_WIDTH_PX / 2.0, -BoardTransform.TILE_HEIGHT_PX / 2.0)
	highlight.visible = false
	highlight.z_index = 3

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())
	elif event.is_action_pressed("ui_up"):
		_move_unit(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		_move_unit(Vector2i(0, 1))
	elif event.is_action_pressed("ui_left"):
		_move_unit(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_move_unit(Vector2i(1, 0))

## Simplified stand-in for ADR §4's pick_at(): occupant-priority (test the unit's and
## prop's own visual Rect2 first, front-to-back / closest-drawn-first), then fall through
## to plain screen_to_grid() diamond geometry. There is no GameState in this spike, so
## "occupant_entity_id" is replaced with a plain node reference for the info label.
func _handle_click(screen_pos: Vector2) -> void:
	var hit_node: Node2D = null
	# Front-to-back = reverse of paint order; y_sort_enabled paints lower global-Y first,
	# so the node with the greater global Y (visually "in front") should be tested first.
	var candidates: Array[Sprite2D] = [unit, tall_prop]
	candidates.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.y > b.position.y)
	for sprite in candidates:
		var rect := Rect2(sprite.position + sprite.offset, sprite.texture.get_size())
		if rect.has_point(screen_pos):
			hit_node = sprite
			break

	var resolved_tile: Vector2i
	if hit_node == unit:
		resolved_tile = unit_tile
	elif hit_node == tall_prop:
		resolved_tile = PROP_TILE
	else:
		resolved_tile = iso_transform.screen_to_grid(screen_pos)
		# Empty-tile click: paint/move the overlay diamond there, re-confirming overlay/
		# floor alignment (ADR Validation Criteria) interactively.
		if resolved_tile.x >= 0 and resolved_tile.x < GRID_WIDTH and resolved_tile.y >= 0 and resolved_tile.y < GRID_HEIGHT:
			_set_overlay_tile(resolved_tile)

	highlight.position = iso_transform.grid_to_screen(resolved_tile)
	highlight.visible = true
	_update_info_label(hit_node, resolved_tile)

func _set_overlay_tile(tile: Vector2i) -> void:
	if overlay_tile.x >= 0:
		overlay_layer.erase_cell(overlay_tile)
	overlay_tile = tile
	overlay_layer.set_cell(overlay_tile, 0, IsoTileSetBuilder.ATLAS_OVERLAY)

func _update_info_label(hit_node: Node2D = null, resolved_tile: Vector2i = Vector2i(-999, -999)) -> void:
	var hit_desc := "none (empty diamond)"
	if hit_node == unit:
		hit_desc = "UNIT"
	elif hit_node == tall_prop:
		hit_desc = "TALL PROP"
	var last_click_line := ""
	if resolved_tile.x != -999:
		last_click_line = "\nLast click resolved to tile %s -- hit: %s" % [resolved_tile, hit_desc]
	info_label.text = (
		"ADR-0013 iso spike -- arrow keys move the blue unit, click to test picking.\n"
		+ "Unit tile: %s   Prop tile (fixed): %s\n"
		+ "Walk the unit through/behind the brown prop and watch draw order (y_sort_enabled).\n"
		+ "Click an empty diamond to drop the yellow overlay tile there (floor/overlay alignment check)."
		+ last_click_line
	) % [unit_tile, PROP_TILE]
