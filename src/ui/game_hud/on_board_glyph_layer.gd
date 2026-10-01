## OnBoardGlyphLayer — the on-board glyph render layer (ADR-0013 §5 anchoring +
## ADR-0016 hp pip/numeric branch; TR-hud-010/011/012).
##
## A [Node2D] (board screen-space, like [BoardRenderer]) that draws per-entity
## glyphs — hp (a bar when damaged, the number under the cursor), the has-acted marker, the build-timer badge —
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

## ★ hp bar geometry (2026-10-01). Neutral, never a faction hue: hp is state, not ownership
## (art bible §4.3); a dark plate keeps it legible over either player's colours.
const HP_BAR_SIZE: Vector2 = Vector2(34, 5)
const HP_BAR_FILL: Color = Color(0.94, 0.95, 0.98)
const HP_BAR_BACK: Color = Color(0.05, 0.06, 0.09, 0.9)
const HP_NUMBER_SIZE: int = 13

## The board cursor's tile ([method set_cursor_tile]) and the mouse-hover tile
## ([method set_hover_tile]); the exact hp number shows only on these two.
var _cursor_tile: Vector2i = Vector2i(-1, -1)
var _hover_tile: Vector2i = Vector2i(-1, -1)

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
	# ★ 2026-10-01: draw above every board layer (props, cover blocks, sprites) — a damaged
	# unit's bar was hidden behind a cover block beside it.
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	if _reader != null:
		_reader.subscribe_action_applied(_on_action_applied)


func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


func _exit_tree() -> void:
	if _reader != null:
		_reader.unsubscribe_action_applied(_on_action_applied)


## PURE: the hp bar shows only for a damaged entity — a full-health board stays clean.
static func hp_bar_visible(current_hp: int, max_hp: int) -> bool:
	return max_hp > 0 and current_hp < max_hp


## PURE: the exact hp number shows only for the entity under the board cursor.
static func hp_number_visible(tile: Vector2i, cursor_tile: Vector2i) -> bool:
	return tile == cursor_tile


## Moves the "exact hp" readout to [param tile] (the board cursor; mouse and pad alike).
func set_cursor_tile(tile: Vector2i) -> void:
	if tile == _cursor_tile:
		return
	_cursor_tile = tile
	queue_redraw()


## The tile under the mouse pointer (the mouse never moves the board cursor by itself).
func set_hover_tile(tile: Vector2i) -> void:
	if tile == _hover_tile:
		return
	_hover_tile = tile
	queue_redraw()


func _draw_hp_bar(anchor: Vector2, cur: int, mx: int) -> void:
	var r := Rect2(anchor, HP_BAR_SIZE)
	draw_rect(r.grow(1.0), HP_BAR_BACK)
	var frac: float = clampf(float(cur) / float(mx), 0.0, 1.0)
	draw_rect(Rect2(anchor, Vector2(maxf(1.0, HP_BAR_SIZE.x * frac), HP_BAR_SIZE.y)), HP_BAR_FILL)


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
	# ★ 2026-10-01 (user decision): ONE generic bar for every unit and structure, shown only
	# when damaged; the exact number only under the board cursor. Replaces the pip/numeric
	# split (ADR-0016), which drew "40/40" over every full-health entity on the board.
	var hp_anchor: Vector2 = _anchor_source.glyph_anchor(tile, hp_class)
	if hp_bar_visible(cur, mx):
		_draw_hp_bar(hp_anchor, cur, mx)
	if (hp_number_visible(tile, _cursor_tile) or hp_number_visible(tile, _hover_tile)) and font != null:
		var text: String = "%d/%d" % [cur, mx]
		var pos: Vector2 = hp_anchor + Vector2(0, -4)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, HP_NUMBER_SIZE, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, HP_NUMBER_SIZE, Color.WHITE)

	# Markers — each at its own authored GLYPH_OFFSETS sub-position; distinct
	# SHAPES (non-hue-redundant): has-acted a circle, build badge a number.
	# Reuse the u/s already fetched above (no re-query on the redraw path).
	for m: int in _markers_from(u, s):
		var anchor: Vector2 = _anchor_source.glyph_anchor(tile, m)
		if m == BoardRenderer.GlyphClass.HAS_ACTED:
			draw_circle(anchor, 3.0, Color(0.85, 0.85, 0.85))
		elif m == BoardRenderer.GlyphClass.BUILD_TIMER_BADGE and font != null:
			draw_string(font, anchor, "%d" % s["build_turns_remaining"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
