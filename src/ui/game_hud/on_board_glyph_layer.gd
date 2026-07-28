## OnBoardGlyphLayer — the on-board glyph render layer (ADR-0013 §5 anchoring +
## ADR-0016 hp pip/numeric branch; TR-hud-010/011/012).
##
## A [Node2D] (board screen-space, like [BoardRenderer]) that draws per-entity
## glyphs — hp (pips or numeric), the has-acted marker, the build-timer badge —
## each anchored at exactly [code]grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class][/code]
## via the injected anchor source's [method BoardRenderer.glyph_anchor]. This
## layer NEVER writes HUD-local pixel-offset math (ADR-0013 forbidden pattern):
## every anchor goes through [method BoardRenderer.glyph_anchor], so the whole
## layer reprojects correctly under the iso transform. hp-pip-never-occluded
## (TR-hud-011) is guaranteed upstream by the [GlyphOffsets] authoring discipline
## (Board Renderer Story 005), not by any runtime z-arbitration here.
##
## Every displayed value is a live verbatim read through the injected
## [GameStateReader] (Pass-Through, ADR-0016) — hp/has-acted from
## [method GameStateReader.unit_info], build-timer from
## [method GameStateReader.structure_info].
##
## [b]Testable model[/b] (the blocking Logic sub-slice, AC-10): the pure
## [method hp_render_mode] branch + [method hp_mode_for]/[method active_markers_for]
## are asserted headlessly; [method _draw] is the Visual/Feel rendering of that
## model (its legibility/shape-distinctness at 1080p/1440p is the advisory
## evidence, AC-11/26 — see production/qa/evidence/on-board-glyph-layer-evidence.md).
##
## [b]STUBBED[/b] (data not yet available): the TECH_MARKER (owner-has-researched)
## needs a player tech-flag read the facade does not yet expose, and the
## RESEARCH_MARKER (per-Research-Lab in-progress) needs the Research/Tech epic
## (not implemented — the same stub the AI epic carries). Neither ever renders
## until that data exists; [method active_markers_for] documents this.
##
## Usage:
## [codeblock]
## var glyphs := OnBoardGlyphLayer.new()
## glyphs.bind(reader, board_renderer, HudBalance.hud)
## board_root.add_child(glyphs)   # sibling of the BoardRenderer, same space
## [/codeblock]
class_name OnBoardGlyphLayer
extends Node2D

## hp display mode (AC-10). Discrete drain-on-damage pips below
## [member HUDConfig.pip_max_hp]; numeric current/max at or above it.
enum HpMode { PIPS, NUMERIC }

## Default pip threshold if no [HUDConfig] was injected (matches the resource default).
const _DEFAULT_PIP_MAX_HP: int = 10

var _reader: GameStateReader = null

## Duck-typed anchor source exposing [code]glyph_anchor(tile, glyph_class) -> Vector2[/code]
## (production: a [BoardRenderer]). Held so every glyph position is
## [code]grid_to_screen(tile) + GLYPH_OFFSETS[class][/code], never HUD-local math.
var _anchor_source: Object = null

var _config: HUDConfig = null


## Injects the read facade, the glyph-anchor source, and the config (DI seam).
## Safe before or after tree entry (mirrors [HudReactiveControl]); subscribes to
## [signal GameState.action_applied] so the layer repaints on any board change.
func bind(reader: GameStateReader, anchor_source: Object, config: HUDConfig) -> void:
	_reader = reader
	_anchor_source = anchor_source
	_config = config
	if is_inside_tree():
		_reader.subscribe_action_applied(_on_action_applied)


func _ready() -> void:
	if _reader != null:
		_reader.subscribe_action_applied(_on_action_applied)


func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


func _exit_tree() -> void:
	if _reader != null:
		_reader.unsubscribe_action_applied(_on_action_applied)


## PURE (AC-10): hp renders as discrete pips below [param pip_max_hp] and numeric
## at/above it — the `>=` boundary is load-bearing (a max_hp exactly at the
## threshold flips to numeric, e.g. a hp-14 structure at pip_max_hp 10 → NUMERIC).
static func hp_render_mode(max_hp: int, pip_max_hp: int) -> HpMode:
	return HpMode.NUMERIC if max_hp >= pip_max_hp else HpMode.PIPS


## The [enum HpMode] for [param entity_id], branching the entity's max hp against
## [member HUDConfig.pip_max_hp]. NUMERIC for an unknown id (harmless default).
func hp_mode_for(entity_id: int) -> HpMode:
	var pip_max: int = _config.pip_max_hp if _config != null else _DEFAULT_PIP_MAX_HP
	var u: Dictionary = _reader.unit_info(entity_id)
	if not u.is_empty():
		return hp_render_mode(u["hp"], pip_max)
	var s: Dictionary = _reader.structure_info(entity_id)
	if not s.is_empty():
		return hp_render_mode(s["hp"], pip_max)
	return HpMode.NUMERIC


## The marker [enum BoardRenderer.GlyphClass] values [param entity_id] should show
## (besides hp), each a live verbatim read: HAS_ACTED for a unit that has attacked;
## BUILD_TIMER_BADGE for an under-construction structure. TECH_MARKER and
## RESEARCH_MARKER are deliberately NEVER added here — the owner-tech read and the
## Research system do not exist yet (owed to the Research/Tech epic); this method
## is the single place they attach once that data lands.
func active_markers_for(entity_id: int) -> Array[int]:
	return _markers_from(_reader.unit_info(entity_id), _reader.structure_info(entity_id))


## Pure marker derivation from already-fetched read snapshots — so the redraw
## path (which already holds [param u]/[param s]) and the public accessor share
## one [GameStateReader] read instead of re-querying. [param u] non-empty → a
## unit (HAS_ACTED iff it has attacked); else [param s] non-empty → a structure
## (BUILD_TIMER_BADGE iff under construction). TECH_MARKER/RESEARCH_MARKER stay
## stubbed (see [method active_markers_for]'s doc).
func _markers_from(u: Dictionary, s: Dictionary) -> Array[int]:
	var markers: Array[int] = []
	if not u.is_empty():
		if u["has_attacked"]:
			markers.append(BoardRenderer.GlyphClass.HAS_ACTED)
		return markers
	if not s.is_empty():
		if s["build_status"] == StructureState.BuildStatus.UNDER_CONSTRUCTION:
			markers.append(BoardRenderer.GlyphClass.BUILD_TIMER_BADGE)
	return markers


func _draw() -> void:
	if _reader == null or _anchor_source == null:
		return
	var font: Font = ThemeDB.fallback_font
	for entity: EntityState in _reader.entities():
		_draw_entity(entity, font)


func _draw_entity(entity: EntityState, font: Font) -> void:
	var tile: Vector2i = entity.position
	var u: Dictionary = _reader.unit_info(entity.entity_id)
	var s: Dictionary = _reader.structure_info(entity.entity_id)
	var cur: int
	var mx: int
	var hp_class: int
	if not u.is_empty():
		cur = u["current_hp"]
		mx = u["hp"]
		hp_class = BoardRenderer.GlyphClass.HP_PIP
	elif not s.is_empty():
		cur = s["current_hp"]
		mx = s["hp"]
		hp_class = BoardRenderer.GlyphClass.STRUCTURE_HP
	else:
		return

	# hp — anchored via glyph_anchor (never HUD-local math).
	var pip_max: int = _config.pip_max_hp if _config != null else _DEFAULT_PIP_MAX_HP
	var hp_anchor: Vector2 = _anchor_source.glyph_anchor(tile, hp_class)
	if hp_render_mode(mx, pip_max) == HpMode.NUMERIC:
		if font != null:
			draw_string(font, hp_anchor, "%d/%d" % [cur, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		# Discrete pips: chunky neutral squares (hp is state, never a faction hue),
		# one per current hp, drained one at a time — no smooth bar.
		for i: int in cur:
			draw_rect(Rect2(hp_anchor + Vector2(i * 6, 0), Vector2(4, 4)), Color.WHITE)

	# Markers — each at its own authored GLYPH_OFFSETS sub-position; distinct
	# SHAPES (non-hue-redundant): has-acted a circle, build badge a number.
	# Reuse the u/s already fetched above (no re-query on the redraw path).
	for m: int in _markers_from(u, s):
		var anchor: Vector2 = _anchor_source.glyph_anchor(tile, m)
		if m == BoardRenderer.GlyphClass.HAS_ACTED:
			draw_circle(anchor, 3.0, Color(0.85, 0.85, 0.85))
		elif m == BoardRenderer.GlyphClass.BUILD_TIMER_BADGE and font != null:
			draw_string(font, anchor, "%d" % s["build_turns_remaining"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
