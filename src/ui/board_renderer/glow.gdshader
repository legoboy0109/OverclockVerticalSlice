shader_type canvas_item;
render_mode blend_add;

// Entity glow — art-bible §8.9's emission pass (Story 007 / sprint task S5-02).
//
// Drawn as an additive overlay child of each entity sprite, sampling that entity's
// hue-agnostic glow MASK (greyscale, "which pixels are trim") and emitting
// mask x faction_hue x pulse. One ShaderMaterial is shared by every actor; the
// per-actor difference lives entirely in `instance uniform`s, which is the
// batch-safe §8.7-rule-2 pattern the S4-01 spike confirmed on Redot 26.2.
//
// TIME IS NEVER USED. `state_timer` is written from GDScript so the glow freezes
// and scrubs with the turn-based pause state (§8.9, Story 007 AC-5). Reaching for
// the TIME built-in here would silently break that.
//
// Every tunable below is a uniform rather than a literal so EntityGlow's GDScript
// constants stay the single source of truth for the curve — the shader owns the
// SHAPE, never the numbers.

// --- Shared uniforms (written once at build; state_timer once per frame) ------
uniform float state_timer = 0.0;
uniform float breathe_min = 0.25;
uniform float breathe_max = 0.85;
uniform float breathe_period = 3.0;
uniform float flare_peak = 1.0;
uniform float flare_decay = 0.45;

// --- Per-instance uniforms (written only on a state change) -------------------
instance uniform vec4 faction_hue : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// The resting level: the AP-spent clamp, or 0.0 for a destroyed actor.
instance uniform float pulse_base = 0.0;
// 0 = static (use pulse_base) · 1 = breathe · 2 = flare-then-settle.
instance uniform float glow_mode = 0.0;
// The state_timer value at which a flare began; only read when glow_mode == 2.
instance uniform float flare_start = 0.0;

void fragment() {
	float pulse = pulse_base;
	if (glow_mode > 1.5) {
		// Attack flare: peaks immediately, decays exponentially, settles back onto
		// whatever this actor's resting level is rather than snapping to zero.
		float elapsed = max(state_timer - flare_start, 0.0);
		pulse = max(pulse_base, flare_peak * exp(-elapsed / flare_decay));
	} else if (glow_mode > 0.5) {
		// Slow breathe. §2 wants a STEADY glow at rest — this is deliberately gentle,
		// because a fast pulse reads as false urgency.
		float phase = sin(state_timer * TAU / breathe_period) * 0.5 + 0.5;
		pulse = mix(breathe_min, breathe_max, phase);
	}
	// The mask is 8-bit greyscale with no alpha — sample a single channel (§8.9).
	float emission = texture(TEXTURE, UV).r * pulse;
	// ALPHA MUST STAY 1.0. Godot's additive canvas blend is dst + src.rgb * src.a, so
	// putting the emission in alpha as well would SQUARE it — measured as a barely
	// visible glow contributing ~54 changed pixels across the whole frame. The mask
	// already zeroes rgb everywhere it is not trim, so a full-alpha quad adds nothing
	// outside the rim.
	COLOR = vec4(faction_hue.rgb * emission, 1.0);
}
