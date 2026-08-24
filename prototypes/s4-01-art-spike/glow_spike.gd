extends Node2D
## S4-01 one-unit glow spike — windowed validation for art-bible §8.9 + §4.2.
##
## Run this scene (F6) in the live Redot 26.2 editor. Confirm:
##   1. The `instance uniform` shader COMPILES in the real rasterizer (no shader error on run).
##   2. The additive glow blooms past each token's core on the dark stage (emission reads).
##   3. All 15 tokens share ONE ShaderMaterial yet glow different hues — batch-safe (§8.7 rule 2).
##   4. Boom (cyan) stays legible on EVERY stage tile incl. max-elevation (§4.2 side-by-side).
##
## SPACE cycles the glow behavior: BREATHE (§2.1 has-AP) -> FLARE (§2.2 spend) -> CLAMP (§2.6 0-AP).

const STAGE := {
	"Void bg":          "0A0E17",
	"Terrain base":     "232A38",
	"Terrain elevated": "33405A",
	"Terrain recessed": "171C27",
	"Structure plate":  "1B2130",
}
const FACTIONS := {
	"Boom":    "22C7F0",
	"Rush":    "FF5A2E",
	"Neutral": "C6CED8",
}

const COL_W: float = 190.0
const ROW_H: float = 150.0
const X0: float = 140.0
const Y0: float = 120.0

var _shared_mat: ShaderMaterial
var _tokens: Array[Sprite2D] = []
var _state_timer: float = 0.0
var _mode: int = 0
var _mode_names: Array[String] = [
	"BREATHE (§2.1 has-AP)", "FLARE (§2.2 spend)", "CLAMP (§2.6 0-AP)",
]
var _mode_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("05070C"))
	var shader: Shader = load("res://glow.gdshader")
	_shared_mat = ShaderMaterial.new()
	_shared_mat.shader = shader
	var tok: ImageTexture = _make_token_texture(112)

	# Stage-tile background columns + labels.
	var col: int = 0
	for stage_name in STAGE:
		var bg := ColorRect.new()
		bg.color = Color(STAGE[stage_name])
		bg.position = Vector2(X0 + col * COL_W - 80, Y0 - 60)
		bg.size = Vector2(COL_W - 12, ROW_H * FACTIONS.size() + 60)
		add_child(bg)
		_add_label(stage_name, Vector2(X0 + col * COL_W - 76, Y0 - 88), Color("8896B4"))
		col += 1

	# Faction rows: one token per stage tile, all sharing _shared_mat.
	var row: int = 0
	for faction_name in FACTIONS:
		var hue := Color(FACTIONS[faction_name])
		_add_label(faction_name, Vector2(24, Y0 + row * ROW_H + 44), hue)
		col = 0
		for stage_name in STAGE:
			var s := Sprite2D.new()
			s.texture = tok
			s.material = _shared_mat
			s.position = Vector2(X0 + col * COL_W, Y0 + row * ROW_H + 48)
			add_child(s)
			s.set_instance_shader_parameter("faction_hue", hue)
			s.set_instance_shader_parameter("pulse_intensity", 0.2)
			_tokens.append(s)
			col += 1
		row += 1

	_mode_label = _add_label("", Vector2(24, 28), Color.WHITE)
	_update_mode_label()

func _process(delta: float) -> void:
	_state_timer += delta
	var pulse: float = 0.0
	match _mode:
		0: pulse = 0.18 + 0.16 * (0.5 + 0.5 * sin(_state_timer * 2.0))     # slow breathe
		1: pulse = 0.95 * maxf(0.0, 1.0 - fmod(_state_timer, 1.2) / 1.2)   # decaying flare
		2: pulse = 0.0                                                     # clamp (0 AP)
	for s in _tokens:
		s.set_instance_shader_parameter("pulse_intensity", pulse)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_mode = (_mode + 1) % 3
		_state_timer = 0.0
		_update_mode_label()

func _update_mode_label() -> void:
	_mode_label.text = "S4-01 GLOW SPIKE — SPACE cycles mode  |  now: %s" % _mode_names[_mode]

func _add_label(text: String, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _make_token_texture(size: int) -> ImageTexture:
	# White token: solid diamond core + soft radial halo in alpha, so the additive glow
	# blooms past the core on the dark stage. White so the shader tints it by faction hue.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size / 2.0
	for y in size:
		for x in size:
			var dx: float = absf(x - c) / c
			var dy: float = absf(y - c) / c
			var diamond: float = dx + dy        # 0 at center -> ~1 at the diamond edge
			var a: float
			if diamond < 0.60:
				a = 1.0
			else:
				a = clampf(1.0 - (diamond - 0.60) / 0.55, 0.0, 1.0)   # soft halo
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
