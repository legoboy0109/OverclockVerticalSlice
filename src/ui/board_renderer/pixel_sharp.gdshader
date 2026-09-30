shader_type canvas_item;

// Sharp pixel-art sampling for actor bodies (HD-2D pivot, 2026-09-30).
//
// The camera zooms continuously (fit zoom → CAMERA_ZOOM_MAX), so one art pixel lands on
// 2 × zoom screen pixels — rarely a whole number. Plain LINEAR filtering then smears
// every pixel edge across ~1.5 screen px at close zoom; plain NEAREST keeps edges hard
// but makes neighbouring art pixels alternate 1- and 2-px wide, which shimmers as the
// camera or a unit moves. This does neither: inside a texel it samples the flat
// centre, and only across the edge between two texels does it blend — over exactly
// ONE screen pixel (fwidth = texels per screen pixel). Crisp at every zoom, no shimmer,
// and the zoom behaviour stays exactly as designed.
//
// Technique: "smooth pixel filtering" (box-filter the texel edge at screen resolution).
// Requires the sprite's texture filter to be LINEAR — the smoothstep offset lands
// between texel centres and the bilinear fetch does the one-pixel blend.
//
// ★ In fragment(), COLOR arrives ALREADY multiplied by texture(TEXTURE, UV). Multiplying
// the resample by COLOR squared the texture — measured in a real render as the rush
// orange going deep red and slate going dark (2026-09-30). So the node's
// (self_)modulate is captured in vertex(), where COLOR is modulate only, and the body
// tint, AP-spent dim and death-echo fades keep working through that.
// Minification (zoomed out, <1 screen px per texel) clamps box_size to 1 and degrades
// to ordinary bilinear, which is the right answer when a texel is smaller than a pixel.

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 pix = UV * size;
	vec2 box_size = clamp(fwidth(pix), vec2(1e-5), vec2(1.0));
	vec2 tx = pix - 0.5 * box_size;
	vec2 tx_offset = smoothstep(vec2(1.0) - box_size, vec2(1.0), fract(tx));
	vec2 uv = (floor(tx) + 0.5 + tx_offset) / size;
	// textureGrad with the ORIGINAL derivatives: the reshaped uv has step-shaped
	// derivatives, which would otherwise pick a wrong (blurry) mip at texel edges.
	COLOR = textureGrad(TEXTURE, uv, dFdx(UV), dFdy(UV)) * node_modulate;
}
