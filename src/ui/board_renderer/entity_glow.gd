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

## The AP-spent clamp (§8.9): visibly present but clearly inert. Not zero — a fully
## dark unit reads as destroyed, which is a different state entirely.
const SPENT_CLAMP: float = 0.08

## Attack-flare peak (§8.9/§2.2). The only spike in the vocabulary.
const FLARE_PEAK: float = 1.0

## Exponential decay constant for the flare, in seconds. [b]Unpinned feel value[/b]
## — S5-06 owns the body lunge this flare syncs to, so expect to tune them together.
const FLARE_DECAY_SEC: float = 0.45

## A destroyed actor emits nothing (§8.5: pulse -> 0 over the 2-4 frame beat).
const DESTROYED_PULSE: float = 0.0

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
		var archetype: String = EntitySpriteCatalog.type_token(unit_type.display_name)
		return "%sunit_%s_%s_idle_01%s.png" % [
			EntitySpriteCatalog.UNITS_DIR, archetype, facing, MASK_SUFFIX
		]
	if entity is StructureState:
		var struct_type: StructureTypeDef = (entity as StructureState).type
		if struct_type == null:
			return ""
		var struct_name: String = EntitySpriteCatalog.type_token(struct_type.display_name)
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
