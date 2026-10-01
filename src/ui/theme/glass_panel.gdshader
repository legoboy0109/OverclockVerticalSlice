shader_type canvas_item;

// Holo-glass panel (UI direction B, user decision 2026-10-01).
//
// Drawn as one rect per panel: a frosted, blurred copy of whatever is behind it (the board),
// tinted dark blue, with two cut corners (top-left, bottom-right) and a soft glowing edge.
// Everything is in panel PIXELS (rect_size), so cuts and edges stay the same size on every
// panel. blur_lod 0 = no blur (the "effects off" path and the Deck fallback): the tint alone
// is then raised in opacity by GDScript so text keeps its contrast.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform vec2 rect_size = vec2(100.0, 40.0);
instance uniform vec4 edge_color : source_color = vec4(0.47, 0.78, 1.0, 0.30);
instance uniform vec4 tint : source_color = vec4(0.07, 0.12, 0.19, 0.62);
instance uniform float cut_px = 12.0;
instance uniform float glow_px = 0.0;
uniform float blur_lod = 2.2;

// Panel-local position in px. ★ Taken from VERTEX, not UV: an untextured draw_rect carries no
// meaningful UVs, so UV * rect_size put every pixel in the top-left cut and discarded the plate.
varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

// Signed distance to the cut-corner rectangle (negative inside).
float sdf(vec2 p, vec2 size, float cut) {
	vec2 d = min(p, size - p);
	float box = -min(d.x, d.y);
	// Top-left cut: x + y >= cut. Bottom-right cut: (w - x) + (h - y) >= cut.
	float tl = (cut - (p.x + p.y)) * 0.70710678;
	float br = (cut - ((size.x - p.x) + (size.y - p.y))) * 0.70710678;
	return max(box, max(tl, br));
}

void fragment() {
	vec2 p = local_px;
	float d = sdf(p, rect_size, cut_px);
	if (d > 0.5) {
		discard;
	}
	vec3 behind = blur_lod > 0.01 ? textureLod(screen_tex, SCREEN_UV, blur_lod).rgb : vec3(0.0);
	float a = tint.a;
	vec3 col = mix(behind, tint.rgb, blur_lod > 0.01 ? a : 1.0);
	float alpha = blur_lod > 0.01 ? 1.0 : a;
	// 1 px hard edge + optional inner glow band.
	float edge = 1.0 - smoothstep(0.0, 1.25, abs(d + 0.6));
	float inner = glow_px > 0.0 ? (1.0 - smoothstep(0.0, glow_px, -d)) * 0.35 : 0.0;
	col = mix(col, edge_color.rgb, clamp(edge * edge_color.a * 2.2 + inner * edge_color.a, 0.0, 1.0));
	alpha = max(alpha, edge * edge_color.a);
	// Anti-aliased outer boundary.
	alpha *= 1.0 - smoothstep(-0.5, 0.5, d);
	COLOR = vec4(col, alpha);
}
