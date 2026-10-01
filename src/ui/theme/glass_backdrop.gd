## GlassBackdrop — the frosted holo-glass plate behind a panel's content (UI direction B).
##
## Add as the FIRST child of any panel (it fills the parent and ignores the mouse). It is its
## own canvas item on purpose: the glass shader must never touch the panel's text, so text lives
## on sibling nodes drawn after it. One shared material for every plate; per-plate values are
## instance uniforms, so dozens of panels stay one batchable shader.
class_name GlassBackdrop
extends Control

## Edge colour — [constant UiTheme.EDGE] for neutral chrome, a player's hue for ownership.
var edge_color: Color = UiTheme.EDGE:
	set(v):
		edge_color = v
		_apply()
## Inner glow band width in px (0 = edge only). Ownership plates glow; neutral ones don't.
var glow_px: float = 0.0:
	set(v):
		glow_px = v
		_apply()
var cut_px: float = UiTheme.CUT_PX:
	set(v):
		cut_px = v
		_apply()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = UiTheme.glass_material()


func _ready() -> void:
	# ★ set_anchors_AND_OFFSETS: anchors alone left a code-built Control at size 0 (the plate
	# never drew). See .agent/notes.md "Controls built with .new() have zero size".
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply)
	_apply()


## Adds a backdrop to [param panel] as its bottom-most child and returns it.
static func attach(panel: Control, edge: Color = UiTheme.EDGE, glow: float = 0.0) -> GlassBackdrop:
	var b := GlassBackdrop.new()
	b.edge_color = edge
	b.glow_px = glow
	panel.add_child(b)
	panel.move_child(b, 0)
	return b


func _apply() -> void:
	if not is_inside_tree():
		return
	var blur: bool = UiTheme.blur_enabled()
	set_instance_shader_parameter(&"rect_size", size)
	set_instance_shader_parameter(&"edge_color", edge_color)
	set_instance_shader_parameter(&"tint", UiTheme.TINT if blur else UiTheme.TINT_FLAT)
	set_instance_shader_parameter(&"cut_px", cut_px)
	set_instance_shader_parameter(&"glow_px", glow_px)
	(material as ShaderMaterial).set_shader_parameter(&"blur_lod", 2.2 if blur else 0.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
