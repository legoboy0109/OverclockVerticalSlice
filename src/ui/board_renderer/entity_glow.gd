## EntityGlow — the glow curve, hue anchors and mask paths for the §8.9 emission
## pass, Presentation layer (Story 007 / sprint task S5-02).
##
## [b]The single source of truth for the glow numbers.[/b] `glow.gdshader` owns the
## SHAPE of the curve (breathe is a sine, flare is an exponential decay); every
## VALUE it uses is pushed in from the constants here when the material is built,
## so retuning the glow means editing this file only. [method pulse_for] mirrors
## the shader's arithmetic for tests and tools — keep the two in step if the shape
## ever changes.
##
## Every method is [code]static[/code] except by way of the material factory; this
## class is never instantiated.
##
## Usage:
## [codeblock]
## var material := EntityGlow.make_material()
## sprite.material = material                      # shared by every actor
## sprite.set_instance_shader_parameter(&"faction_hue", EntityGlow.hue_for(faction))
## [/codeblock]
class_name EntityGlow
extends RefCounted

## The emission shader. One [Shader] resource, one [ShaderMaterial] built from it,
## shared across every actor on the board (§8.7 rule 2 — batch-safe).
const SHADER_PATH: String = "res://src/ui/board_renderer/glow.gdshader"

## [b]Locked faction anchors[/b] (art-bible §4.1, re-confirmed by the S4-01 palette
## lock). These are not free tuning values — S5-08's colourblind work is bounded by
## them, and the measured Rush/Boom grayscale separation of 34/255 is a consequence
## of this exact pair. Changing either breaks that analysis.
const RUSH_HUE: Color = Color("FF5A2E")

## See [constant RUSH_HUE].
const BOOM_HUE: Color = Color("22C7F0")

## See [constant RUSH_HUE]. Also the menu/showroom hue.
const NEUTRAL_HUE: Color = Color("C6CED8")

## Glow modes, written to the shader's [code]glow_mode[/code] instance uniform as a
## float. Kept as ints here so call sites read as names rather than magic numbers.
enum Mode {
	STATIC, ## Hold [code]pulse_base[/code] — the AP-spent clamp, or a destroyed actor's 0.
	BREATHE, ## Slow sine between [constant BREATHE_MIN] and [constant BREATHE_MAX].
	FLARE, ## Peak at [constant FLARE_PEAK], decay back onto [code]pulse_base[/code].
}

## Breathe floor — the dimmest point of an AP-available actor's cycle (§8.9).
const BREATHE_MIN: float = 0.25

## Breathe ceiling (§8.9).
const BREATHE_MAX: float = 0.85

## Seconds for one full breathe cycle. [b]Unpinned feel value[/b] — §2 requires the
## rest glow read as STEADY, so this is deliberately slow; a fast pulse reads as
## false urgency. Retune from the S5-03 legibility session, not from taste.
const BREATHE_PERIOD_SEC: float = 3.0

## Full brightness — an actor with AP available is drawn as authored.
## See [constant SPENT_BODY_TINT] for why this constant exists at all.
const LIVE_BODY_TINT: float = 1.0

## [b]The body multiply for an AP-spent actor[/b] — the other half of the state read,
## added 2026-08-21 after the S5-07 windowed pass measured the glow-only version at
## 12.5/255 on the trim at its BEST moment and 3.3/255 at its worst, across 0.67% of
## the frame. See `production/qa/evidence/s5-07-windowed/README.md`.
##
## [b]Why the glow alone could never carry this.[/b] The emission shader only ever
## ADDS light on top of already-bright accent art. Ceasing to emit cannot make an
## actor look spent while its base sprite stays fully saturated, so the whole
## available signal was the emission range — small, and confined to a thin rim.
## Multiplying the body down instead moves the signal onto 100% of the silhouette.
## The win is mostly AREA, not contrast.
##
## [b]0.72 is a floor, not a taste value.[/b] Art bible §3.5/P3 makes units
## deliberately LIGHTER than the stage — armour `#6E7C99` (luma 123) against a
## max-elevation tile `#33405A` (luma 63). Darkening past ~0.72 collapses that
## margin below ~25 and the unit starts sinking into the terrain, which is precisely
## the "units vanish into the board" defect the S4-02 art pass already had to fix
## once. Do not lower this without re-checking against the max-elevation tile, and
## do not assume the terrain palette is fixed — if the stage ever brightens, this
## floor rises with it.
const SPENT_BODY_TINT: float = 0.72

## The body multiply reached at the end of §8.5's destroyed beat. Free to go darker
## than [constant SPENT_BODY_TINT] because a destroyed actor is leaving the board —
## nothing downstream needs to identify its silhouette against the terrain.
const DESTROYED_BODY_TINT: float = 0.50

## The AP-spent clamp (§8.9): visibly present but clearly inert. Not zero — a fully
## dark unit reads as destroyed, which is a different state entirely.
##
## [b]Retained, and still doing work.[/b] The body multiply above carries the state
## read now, but the glow clamp is what keeps the two states distinguishable at the
## TRIM: a spent actor's rim goes quiet while a live one breathes.
const SPENT_CLAMP: float = 0.08

## Attack-flare peak (§8.9/§2.2). The only spike in the vocabulary.
const FLARE_PEAK: float = 1.0

## Exponential decay constant for the flare, in seconds. [b]Unpinned feel value[/b]
## — S5-06 owns the body lunge this flare syncs to, so expect to tune them together.
const FLARE_DECAY_SEC: float = 0.45

## A destroyed actor emits nothing (§8.5: pulse -> 0 over the 2-4 frame beat).
const DESTROYED_PULSE: float = 0.0

## HD-2D bloom (2026-09-30) — a soft HALO baked into each glow mask at load time, so the
## neon trim bleeds light onto the dark stage. It rides the same shader as the rim, so it
## breathes, dims when AP is spent, and spikes with the attack flare for free.
##
## ★ Why not engine bloom: a WorldEnvironment glow needs rendering/viewport/hdr_2d to tell
## the neon (≈0.54 luminance) from slate armour (≈0.48), and HDR 2D blends translucency
## in LINEAR space — measured, it turned the move-range overlay's tan near-solid, undoing
## its legibility tuning (ADR-0020). The baked halo changes nothing but the glow.
##
## Padding added round the mask, in TEXTURE px (art ships at 2x, so 16 = 8 screen px).
const HALO_PAD_PX: int = 16
## The blur is a downscale-then-upscale by this divisor (soft, cheap, no kernel code).
const HALO_BLUR_DIVISOR: int = 8
## Halo brightness relative to the rim. The blurred mask is thin (a 2-px rim spread over
## ~16 px), so it is lifted by HALO_GAIN before this cap; the rim itself stays on top.
const HALO_STRENGTH: float = 0.45
const HALO_GAIN: float = 4.0

static var _halo_cache: Dictionary = {}

## Glow-mask suffix. Masks carry [b]no faction token[/b] — they are greyscale
## "which pixels are trim" and one mask serves all three hues, which is the whole
## reason hue is a per-instance uniform (assets/art/README.md).
const MASK_SUFFIX: String = "_glow"


## Builds the one shared [ShaderMaterial], pushing every tunable constant above
## into the shader as a uniform. Call once per board; assign the result to every
## actor's glow sprite.
static func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter(&"state_timer", 0.0)
	material.set_shader_parameter(&"breathe_min", BREATHE_MIN)
	material.set_shader_parameter(&"breathe_max", BREATHE_MAX)
	material.set_shader_parameter(&"breathe_period", BREATHE_PERIOD_SEC)
	material.set_shader_parameter(&"flare_peak", FLARE_PEAK)
	material.set_shader_parameter(&"flare_decay", FLARE_DECAY_SEC)
	return material


## The glow texture for mask [param mask_path]: the mask, padded by [constant
## HALO_PAD_PX] on every side, with a blurred copy added round it as the bloom halo.
## Built once per mask and cached. Draw it at the body's offset MINUS the padding
## ([method halo_offset]) and the rim still lands pixel-for-pixel on the armour.
static func halo_texture(mask_path: String) -> Texture2D:
	if _halo_cache.has(mask_path):
		return _halo_cache[mask_path]
	var mask: Image = (load(mask_path) as Texture2D).get_image()
	mask.convert(Image.FORMAT_L8)
	var w: int = mask.get_width() + HALO_PAD_PX * 2
	var h: int = mask.get_height() + HALO_PAD_PX * 2
	var padded := Image.create(w, h, false, Image.FORMAT_L8)
	padded.blit_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), Vector2i(HALO_PAD_PX, HALO_PAD_PX))
	var blurred: Image = padded.duplicate()
	blurred.resize(maxi(1, w / HALO_BLUR_DIVISOR), maxi(1, h / HALO_BLUR_DIVISOR), Image.INTERPOLATE_BILINEAR)
	blurred.resize(w, h, Image.INTERPOLATE_CUBIC)
	var rim: PackedByteArray = padded.get_data()
	var soft: PackedByteArray = blurred.get_data()
	var out := PackedByteArray()
	out.resize(rim.size())
	for i: int in rim.size():
		var halo: float = minf(float(soft[i]) * HALO_GAIN, 255.0) * HALO_STRENGTH
		out[i] = maxi(rim[i], int(halo))
	var texture := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, out))
	_halo_cache[mask_path] = texture
	return texture


## Where a halo texture must be drawn relative to its body: the body's own offset,
## shifted up-left by the padding, which [method halo_texture] added on every side.
static func halo_offset(body_offset: Vector2) -> Vector2:
	return body_offset - Vector2(HALO_PAD_PX, HALO_PAD_PX)


## The locked emission hue for [param faction]. Compared by reference against the
## [Factions] registry for the same reason [method EntitySpriteCatalog.faction_token]
## is — [FactionDef] is ADR-0012's stub and carries no id. Unknown/null resolves to
## [constant NEUTRAL_HUE].
static func hue_for(faction: FactionDef) -> Color:
	if faction == Factions.RUSH:
		return RUSH_HUE
	if faction == Factions.BOOM:
		return BOOM_HUE
	return NEUTRAL_HUE


## The glow-mask path for [param entity] at [param facing] — the §8.2 sprite name
## with the faction token dropped and [constant MASK_SUFFIX] appended:
## [codeblock]
## unit_scout_rush_e_idle_01.png  ->  unit_scout_e_idle_01_glow.png
## struct_hq_boom_idle.png        ->  struct_hq_idle_glow.png
## [/codeblock]
## Only [code]idle[/code] masks are authored; a destroyed actor emits nothing, so it
## never needs one. Returns an empty [String] for an entity kind or type def this
## catalog cannot name.
static func mask_path(entity: EntityState, facing: String) -> String:
	if EntitySpriteCatalog.state_token(entity) == EntitySpriteCatalog.STATE_DESTROYED:
		# No destroyed mask is authored, and none is owed: a dead actor emits nothing.
		# Returning the idle mask here would also leave an idle-shaped rim sitting on
		# a differently-shaped destroyed body.
		return ""
	if entity is UnitState:
		var unit_type: UnitTypeDef = (entity as UnitState).type
		if unit_type == null:
			return ""
		var archetype: String = EntitySpriteCatalog.type_token_for(unit_type)
		return "%sunit_%s_%s_idle_01%s.png" % [
			EntitySpriteCatalog.UNITS_DIR, archetype, facing, MASK_SUFFIX
		]
	if entity is StructureState:
		var struct_type: StructureTypeDef = (entity as StructureState).type
		if struct_type == null:
			return ""
		var struct_name: String = EntitySpriteCatalog.structure_token(entity as StructureState)
		return "%sstruct_%s_idle%s.png" % [
			EntitySpriteCatalog.STRUCTURES_DIR, struct_name, MASK_SUFFIX
		]
	return ""


## The resting pulse level for an actor: [constant DESTROYED_PULSE] when it is dead,
## otherwise the [constant SPENT_CLAMP]. Never the breathe range — breathing is a
## MODE (time-driven, computed in the shader), not a level.
static func resting_pulse(is_destroyed: bool) -> float:
	return DESTROYED_PULSE if is_destroyed else SPENT_CLAMP


## The [enum Mode] an actor should be in given whether it is destroyed and whether
## its owner can still act. A destroyed actor is always [constant Mode.STATIC] at
## zero — death outranks every other state.
static func mode_for(is_destroyed: bool, is_actionable: bool) -> Mode:
	if is_destroyed:
		return Mode.STATIC
	return Mode.BREATHE if is_actionable else Mode.STATIC


## The body multiply an actor should be drawn at, given whether it is destroyed and
## whether it can still act. The body counterpart to [method mode_for].
##
## Death outranks everything, exactly as in [method mode_for] — a destroyed actor
## takes [constant DESTROYED_BODY_TINT] whether or not its owner still had AP.
static func body_tint_for(is_destroyed: bool, is_actionable: bool) -> float:
	if is_destroyed:
		return DESTROYED_BODY_TINT
	return LIVE_BODY_TINT if is_actionable else SPENT_BODY_TINT


## [b]Reference implementation of the shader's curve[/b] — mirrors `glow.gdshader`'s
## [code]fragment()[/code] arithmetic exactly, using the same constants. Exists so
## the envelope is unit-testable headlessly (the dummy rasteriser cannot render, so
## the shader itself can never be asserted in CI) and so tools can predict a value.
##
## [b]If the curve SHAPE changes, change both.[/b] The values cannot drift — they
## come from the constants above in either path — but the shape can.
static func pulse_for(mode: Mode, pulse_base: float, state_timer: float, flare_start: float) -> float:
	match mode:
		Mode.FLARE:
			var elapsed: float = maxf(state_timer - flare_start, 0.0)
			return maxf(pulse_base, FLARE_PEAK * exp(-elapsed / FLARE_DECAY_SEC))
		Mode.BREATHE:
			var phase: float = sin(state_timer * TAU / BREATHE_PERIOD_SEC) * 0.5 + 0.5
			return lerpf(BREATHE_MIN, BREATHE_MAX, phase)
		_:
			return pulse_base
