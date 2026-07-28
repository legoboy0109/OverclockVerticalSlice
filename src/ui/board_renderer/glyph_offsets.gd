## GlyphOffsets — the on-board glyph pixel-offset table (ADR-0013 §5, Story 005).
##
## A dedicated [Resource] (`.tres`), mirroring [CombatConfig]/[AIConfig]'s
## config-as-Resource pattern (ADR-0006/0009/0010/0011): flat `@export var`
## fields, never GDScript `const`s, never hardcoded literals inline in
## [code]board_renderer.gd[/code] — a designer/artist retunes an offset by
## editing [code]data/ui/glyph_offsets.tres[/code], no code change required
## (AC-2).
##
## [b]Anchor convention this table feeds (ADR-0013 §5):[/b] every on-board
## glyph anchors at [code]grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class][/code].
## This Resource [i]is[/i] [code]GLYPH_OFFSETS[/code] — [method offset_for]
## indexes it by [enum BoardRenderer.GlyphClass] (an [code]int[/code] at the
## call boundary, since exported enum values are plain ints; this Resource
## does not need to own the enum to be indexed by it — see
## [code]board_renderer.gd[/code]'s [enum BoardRenderer.GlyphClass] doc
## comment for why the enum itself lives there instead).
##
## [b]hp-pip-never-occluded (game-hud.md CR-5 / TR-hud-011) is an authoring
## guarantee, not runtime arbitration:[/b] this Resource intentionally has no
## overlap-detection or z-ordering logic of its own. The guarantee is upheld
## purely by how the offsets below are [i]authored[/i] — [member hp_pip]
## claims the tightest, first-priority non-overlapping band closest to the
## glyph anchor's origin ([method BoardRenderer.grid_to_screen]'s own return
## point, i.e. [code]Vector2.ZERO[/code] offset — hp pips sit right at the
## tile's ground-contact anchor), and every other glyph class's offset is
## authored to sit clear of that claimed band. Whoever retunes these values
## (art/UX) must preserve that ordering discipline; this story does not, and
## per ADR-0013 §5 must not, build any code-level collision check to enforce
## it.
##
## Usage:
## [codeblock]
## var offsets: GlyphOffsets = load("res://data/ui/glyph_offsets.tres")
## var anchor := grid_to_screen(tile) + offsets.offset_for(BoardRenderer.GlyphClass.HP_PIP)
## [/codeblock]
class_name GlyphOffsets
extends Resource

## Pixel offset for the hp-pip glyph class. Authored first — see the class
## doc comment's hp-pip-priority note. Defaults to [constant Vector2.ZERO]
## (sits directly at the glyph anchor's origin, i.e.
## [method BoardRenderer.grid_to_screen]'s own return point) so it always
## keeps first claim on that space regardless of how other offsets are
## retuned.
@export var hp_pip: Vector2 = Vector2.ZERO

## Pixel offset for the has-acted marker glyph class.
@export var has_acted: Vector2 = Vector2(24.0, -56.0)

## Pixel offset for the tech marker glyph class.
@export var tech_marker: Vector2 = Vector2(-24.0, -56.0)

## Pixel offset for the structure-hp glyph class (structures use a distinct
## offset from unit hp pips — different silhouette/footprint, per
## command-action-interface.md/game-hud.md's separate structure-hp glyph).
@export var structure_hp: Vector2 = Vector2(0.0, -72.0)

## Pixel offset for the build-timer badge glyph class.
@export var build_timer_badge: Vector2 = Vector2(0.0, -88.0)

## Pixel offset for the research marker glyph class.
@export var research_marker: Vector2 = Vector2(32.0, -72.0)

## Pixel offset for the AP-cost badge glyph class.
@export var ap_cost_badge: Vector2 = Vector2(-32.0, -20.0)

## Pixel offset for the floating damage-number glyph class.
@export var damage_number: Vector2 = Vector2(0.0, -100.0)

## Pixel offset for the cover glyph class.
@export var cover_glyph: Vector2 = Vector2(-32.0, -8.0)

## Pixel offset for the turns-remaining numeral glyph class.
@export var turns_numeral: Vector2 = Vector2(32.0, -8.0)

## Pixel offset for the target-bracket glyph class.
@export var target_bracket: Vector2 = Vector2(0.0, -32.0)

## Pixel offset for the D-3 after-move echo glyph class (TR-cmdui-017 —
## shares this same anchor mechanism with the six Game HUD glyph classes;
## see command-action-interface.md §B.7 / ADR-0013 §5).
@export var d3_echo: Vector2 = Vector2(0.0, -16.0)


## Returns the authored pixel offset for [param glyph_class]
## ([enum BoardRenderer.GlyphClass], passed as a plain [code]int[/code] since
## exported enum values are ints and this Resource does not own that enum —
## see the class doc comment). This is the [i]only[/i] lookup path
## [method BoardRenderer.glyph_anchor] uses; no other code should read the
## [code]@export[/code] fields above by name. Falls back to
## [constant Vector2.ZERO] for an unrecognized value rather than erroring, so
## a future new glyph class added to the enum without a matching field yet
## degrades to "anchor with no offset" instead of a hard failure.
func offset_for(glyph_class: int) -> Vector2:
	match glyph_class:
		BoardRenderer.GlyphClass.HP_PIP:
			return hp_pip
		BoardRenderer.GlyphClass.HAS_ACTED:
			return has_acted
		BoardRenderer.GlyphClass.TECH_MARKER:
			return tech_marker
		BoardRenderer.GlyphClass.STRUCTURE_HP:
			return structure_hp
		BoardRenderer.GlyphClass.BUILD_TIMER_BADGE:
			return build_timer_badge
		BoardRenderer.GlyphClass.RESEARCH_MARKER:
			return research_marker
		BoardRenderer.GlyphClass.AP_COST_BADGE:
			return ap_cost_badge
		BoardRenderer.GlyphClass.DAMAGE_NUMBER:
			return damage_number
		BoardRenderer.GlyphClass.COVER_GLYPH:
			return cover_glyph
		BoardRenderer.GlyphClass.TURNS_NUMERAL:
			return turns_numeral
		BoardRenderer.GlyphClass.TARGET_BRACKET:
			return target_bracket
		BoardRenderer.GlyphClass.D3_ECHO:
			return d3_echo
		_:
			return Vector2.ZERO
