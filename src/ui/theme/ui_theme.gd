## UiTheme — the shared "holo glass" look (UI direction B, user decision 2026-10-01).
##
## One place for the UI's font, colours and glass panels, so the HUD, action menu and every
## menu screen read as one family. [method install] makes Exo 2 the engine fallback font, so
## hand-drawn widgets and plain Controls all pick it up; [method font] gives other weights.
##
## ★ Colour rule (art bible §4.6, unchanged by the glass decision): no new hues. Panel chrome is
## a desaturated blue-grey; the only saturated colours are the players' own (orange / cyan),
## used for ownership accents (your card's edge, your AP), never decoration.
class_name UiTheme
extends RefCounted

const FONT_PATH: String = "res://assets/fonts/exo2/exo2_variable.ttf"
const GLASS_SHADER_PATH: String = "res://src/ui/theme/glass_panel.gdshader"

# --- Palette --------------------------------------------------------------------------------
const TEXT: Color = Color(0.92, 0.96, 1.0)
const TEXT_MUTED: Color = Color(0.62, 0.77, 0.88)
const TEXT_INERT: Color = Color(0.40, 0.47, 0.56)
const TINT: Color = Color(0.07, 0.12, 0.19, 0.62)
## Opaque-ish tint for the no-blur path (effects off) — keeps text contrast without the blur.
const TINT_FLAT: Color = Color(0.06, 0.09, 0.14, 0.90)
const EDGE: Color = Color(0.47, 0.78, 1.0, 0.30)
const CUT_PX: float = 12.0

# --- Type scale (px at ui_scale 1.0; the window content scale handles the rest) ------------
const SIZE_HERO: int = 44      # AP — the biggest number on screen (art bible §7.2)
const SIZE_TITLE: int = 22
const SIZE_BODY: int = 16
const SIZE_SMALL: int = 13
const SIZE_LABEL: int = 11     # uppercase, letter-spaced labels

static var _fonts: Dictionary = {}
static var _glass_material: ShaderMaterial = null


## Exo 2 at [param weight] (100..900), cached. Falls back to the engine font if the file is
## missing so a broken import never leaves the UI blank.
static func font(weight: int = 500) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	if base == null:
		push_error("UiTheme: %s missing — using the engine fallback font" % FONT_PATH)
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = v
	return v


## Makes Exo 2 the engine's fallback font, which is what every hand-drawn HUD widget
## ([code]ThemeDB.fallback_font[/code]) and every Control without its own font uses — so the whole
## UI switches typeface with no per-widget edits. Called once at boot (HudBalance autoload).
static func install() -> void:
	ThemeDB.fallback_font = font(500)
	# Controls read the engine's DEFAULT theme first, which ships its own font — so the
	# fallback alone only reaches hand-drawn widgets. Point the default theme at Exo 2 too.
	var t: Theme = ThemeDB.get_default_theme()
	if t != null:
		t.default_font = font(500)


## Shared glass material (one shader for every panel; per-panel values are instance uniforms).
static func glass_material() -> ShaderMaterial:
	if _glass_material == null:
		_glass_material = ShaderMaterial.new()
		_glass_material.shader = load(GLASS_SHADER_PATH)
	return _glass_material


## Whether glass panels blur what is behind them. Off with the player's lighting effects
## (Settings: Edge Blur) — the Steam Deck can drop it for battery and GPU.
static func blur_enabled() -> bool:
	var s: Variant = Engine.get_main_loop().root.get_node_or_null("/root/Settings") if Engine.get_main_loop() is SceneTree else null
	if s != null and s.get("settings") != null:
		return bool(s.settings.edge_blur)
	return true


static var _boxes: Dictionary = {}
static var _label_font: Font = null


## Player [param player]'s ownership hue — the same orange/cyan the board uses (seat 0 is the
## rush hue, seat 1 the boom hue, matching the sprite feed's faction order).
static func player_hue(player: int) -> Color:
	return EntityGlow.RUSH_HUE if player == 0 else EntityGlow.BOOM_HUE


## Exo 2 SemiBold with extra letter spacing — for the small uppercase panel labels.
static func label_font() -> Font:
	if _label_font == null:
		var v := FontVariation.new()
		v.base_font = font(600)
		v.spacing_glyph = 2
		_label_font = v
	return _label_font


## Draws [param text] with a soft glow of [param color] behind it (outline passes), for the
## few numerals licensed to glow (AP). Pure drawing helper for hand-drawn widgets.
static func draw_glow_text(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	for pass_i: int in 3:
		var w: int = 10 - pass_i * 3
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, w, Color(color, 0.10 + pass_i * 0.08))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A cut-corner glass StyleBox for Buttons and other Controls that draw their own text, where the
## blurring [GlassBackdrop] can't be used (its shader would also process the glyphs). Same shape
## and edge as the backdrop, flat translucent fill, no blur. 9-sliced, so any size works.
static func glass_box(fill: Color, edge: Color, edge_px: int = 1, cut: int = int(CUT_PX)) -> StyleBoxTexture:
	var key: String = "%s|%s|%d|%d" % [fill.to_html(), edge.to_html(), edge_px, cut]
	if _boxes.has(key):
		return _boxes[key]
	var n: int = cut * 2 + 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			# Distance inside the cut-corner shape (top-left and bottom-right chamfers).
			var d: float = minf(minf(x + 0.5, n - x - 0.5), minf(y + 0.5, n - y - 0.5))
			d = minf(d, ((x + 0.5) + (y + 0.5) - cut) * 0.7071)
			d = minf(d, ((n - x - 0.5) + (n - y - 0.5) - cut) * 0.7071)
			if d <= 0.0:
				continue
			var c: Color = edge if d <= edge_px else fill
			c.a *= clampf(d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	for side: int in 4:
		box.set_texture_margin(side, cut + 2)
		box.set_content_margin(side, 10)
	box.content_margin_left = 14
	box.content_margin_right = 14
	# Recorded so tests can check a state's treatment (e.g. focus vs hover must differ by more
	# than hue — the edge WIDTH) without decoding the texture.
	box.set_meta(&"fill", fill)
	box.set_meta(&"edge", edge)
	box.set_meta(&"edge_px", edge_px)
	_boxes[key] = box
	return box


## Turns [param c]'s own panel draw into holo glass: for a Control whose canvas item draws ONLY
## a background (a PanelContainer's stylebox — its rows are separate child nodes), the glass
## shader goes straight on it, blur included. Never use on a Button/Label (it would shade text).
static func make_glass(c: Control, edge: Color = EDGE, glow_px: float = 0.0) -> void:
	c.material = glass_material()
	var apply := func() -> void:
		var blur: bool = blur_enabled()
		c.set_instance_shader_parameter(&"rect_size", c.size)
		c.set_instance_shader_parameter(&"edge_color", edge)
		c.set_instance_shader_parameter(&"tint", TINT if blur else TINT_FLAT)
		c.set_instance_shader_parameter(&"cut_px", CUT_PX)
		c.set_instance_shader_parameter(&"glow_px", glow_px)
		glass_material().set_shader_parameter(&"blur_lod", 2.2 if blur else 0.0)
	c.resized.connect(apply)
	if c.is_inside_tree():
		apply.call()
	else:
		c.ready.connect(apply, CONNECT_ONE_SHOT)


## The focused/hovered row of a glass menu: the player's hue fading out to the right, with a
## bright 3 px bar on the left — mock-up B's highlight.
static func highlight_box(hue: Color) -> StyleBoxTexture:
	var key: String = "hl|" + hue.to_html()
	if _boxes.has(key):
		return _boxes[key]
	var w: int = 64
	var img := Image.create(w, 4, false, Image.FORMAT_RGBA8)
	for x: int in w:
		var c: Color = Color(1, 1, 1, 1) if x < 3 else Color(hue, 0.38 * (1.0 - float(x) / w))
		for y: int in 4:
			img.set_pixel(x, y, c)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.texture_margin_left = 3
	box.content_margin_left = 10
	box.content_margin_right = 8
	_boxes[key] = box
	return box

