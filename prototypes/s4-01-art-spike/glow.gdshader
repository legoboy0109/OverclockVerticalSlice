shader_type canvas_item;

// S4-01 glow spike — the exact art-bible §8.9 pattern under test.
//
// faction_hue + pulse_intensity are PER-INSTANCE uniforms so every token can share ONE
// ShaderMaterial resource yet glow a different hue/intensity — the batch-safe rule from
// §8.7 rule 2. Set from GDScript via Node2D.set_instance_shader_parameter(...).
//
// Note (§8.9): glow is driven by pulse_intensity written from GDScript per state change,
// NOT the shader TIME built-in — so it can freeze/scrub with the turn-based pause state.
instance uniform vec4 faction_hue : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float pulse_intensity = 0.0;

// How strongly the token body shows its faction hue at rest (shared, not per-instance).
uniform float body_tint : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);                // white token: alpha = core + soft halo
	vec3 body = faction_hue.rgb * body_tint;        // faction identity (ownership hue)
	vec3 glow = faction_hue.rgb * pulse_intensity;  // additive emission: breathe / flare / clamp
	COLOR = vec4(body + glow, tex.a);
}
