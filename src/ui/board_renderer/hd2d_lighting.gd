## Hd2dLighting — the screen-level half of the HD-2D lighting pass (2026-09-30).
##
## The art direction is "HD-2D": pixel-art sprites plus modern lighting (art bible, top
## amendment). The lighting is three pieces (ADR-0020):
## [br]• [b]Bloom[/b] — a halo baked into each glow mask ([method EntityGlow.halo_texture]).
##   Deliberately NOT engine glow: that needs rendering/viewport/hdr_2d, and HDR 2D's
##   linear blending turned the translucent move overlay near-solid in a real render.
## [br]• [b]Floor light pools[/b] — [EntityLightPools].
## [br]• [b]Edge blur[/b] — THIS node: a tilt-shift band ([code]edge_blur.gdshader[/code])
##   on its own [CanvasLayer] between the board and the HUD ([constant BLUR_CANVAS_LAYER]
##   < [constant HUD_CANVAS_LAYER]).
##
## [b]Every number here is a tuning knob[/b] and lives in this file only, the same way
## [EntityGlow] owns the glow curve.
##
## Usage (VerticalSliceRoot):
## [codeblock]
## var lighting := Hd2dLighting.new()
## add_child(lighting)
## lighting.set_bands(CAMERA_HUD_TOP_MARGIN_PX, CAMERA_HUD_BOTTOM_MARGIN_PX)
## [/codeblock]
class_name Hd2dLighting
extends Node

## The canvas layer the board (world) draws on — Godot's default, 0.
const WORLD_CANVAS_LAYER: int = 0
## The edge-blur overlay: above the board so it can re-sample it, below the HUD.
const BLUR_CANVAS_LAYER: int = 1
## The layer every screen-space HUD/status overlay must use so it draws ABOVE the blur.
## (The pause menu stays at its own 100.)
const HUD_CANVAS_LAYER: int = 2

const EDGE_BLUR_SHADER_PATH: String = "res://src/ui/board_renderer/edge_blur.gdshader"

# --- Edge-blur tuning --------------------------------------------------------------
## Mip level at the very screen edge.
const EDGE_BLUR_MAX_LOD: float = 2.5

## Emitted when [member GameSettings.glow_effects] changes, so the owner can re-apply the
## per-actor effects (halo, pools) that this node does not own.
signal glow_toggled(on: bool)

var _blur_layer: CanvasLayer = null
var _blur_material: ShaderMaterial = null
## The last applied settings, so the poll only acts on a change.
var _blur_on: bool = true
var _glow_on: bool = true


func _ready() -> void:
	# ALWAYS, not the default: Settings is opened from the pause menu, where the tree is
	# paused and the slice's own _process is frozen — this is what makes the toggle apply
	# live behind the menu instead of on resume.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blur_layer = CanvasLayer.new()
	_blur_layer.name = "Hd2dEdgeBlur"
	_blur_layer.layer = BLUR_CANVAS_LAYER
	add_child(_blur_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Pure visual: it must never swallow a click meant for the board under it.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = load(EDGE_BLUR_SHADER_PATH)
	_blur_material.set_shader_parameter(&"max_lod", EDGE_BLUR_MAX_LOD)
	rect.material = _blur_material
	_blur_layer.add_child(rect)


func _process(_delta: float) -> void:
	apply_setting()


## Reads [member GameSettings.edge_blur] / [member GameSettings.glow_effects] and applies
## whichever changed: the blur here, the glow via [signal glow_toggled]. Polled every
## frame; call it once after connecting the signal so a saved "off" applies before the
## first frame.
func apply_setting() -> void:
	var blur: bool = Settings.settings == null or Settings.settings.edge_blur
	var glow: bool = Settings.settings == null or Settings.settings.glow_effects
	if blur != _blur_on:
		_blur_on = blur
		set_blur_enabled(blur)
	if glow != _glow_on:
		_glow_on = glow
		glow_toggled.emit(glow)


## Sets the blur bands to the HUD's reserved top/bottom screen margins, in pixels.
func set_bands(top_px: float, bottom_px: float) -> void:
	if _blur_material == null:
		return
	_blur_material.set_shader_parameter(&"top_band_px", top_px)
	_blur_material.set_shader_parameter(&"bottom_band_px", bottom_px)


## Shows or hides the edge blur ([member GameSettings.edge_blur] drives it).
func set_blur_enabled(enabled: bool) -> void:
	if _blur_layer != null:
		_blur_layer.visible = enabled
