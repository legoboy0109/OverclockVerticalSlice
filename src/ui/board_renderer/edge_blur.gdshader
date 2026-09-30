shader_type canvas_item;

// HD-2D tilt-shift edge blur (lighting pass, 2026-09-30).
//
// Drawn on a full-screen ColorRect in a CanvasLayer that sits ABOVE the board and BELOW
// the HUD, so the HUD text is never blurred. It re-samples the already-drawn screen at
// a higher mip level the closer a pixel is to the top or bottom edge. The ramp lives
// entirely inside the HUD's reserved top/bottom bands (VerticalSliceRoot's
// CAMERA_HUD_*_MARGIN_PX), so at the fit zoom — where those bands hold empty void —
// nothing on the board is blurred; it only reads once the player zooms in and the
// board passes under the HUD. Legibility of the playable area is never traded for it.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Band heights in screen pixels (set from GDScript, scaled with the window).
uniform float top_band_px = 104.0;
uniform float bottom_band_px = 128.0;
// Mip level at the very edge. ~2.5 = soft, still recognisable shapes.
uniform float max_lod = 2.5;

void fragment() {
	float h = 1.0 / SCREEN_PIXEL_SIZE.y;
	float y = SCREEN_UV.y * h;
	float top = clamp(1.0 - y / max(top_band_px, 1.0), 0.0, 1.0);
	float bottom = clamp(1.0 - (h - y) / max(bottom_band_px, 1.0), 0.0, 1.0);
	float amount = smoothstep(0.0, 1.0, max(top, bottom));
	if (amount <= 0.001) {
		discard;
	}
	COLOR = vec4(textureLod(screen_tex, SCREEN_UV, amount * max_lod).rgb, 1.0);
}
