## EntitySpriteFeed — the live [method GameState.entities] -> [code]OccupantLayer[/code]
## sprite feed, Presentation layer (Story 006 / sprint task S5-01).
##
## Owns one [Sprite2D] per live entity under [member BoardRenderer.occupant_layer]
## and reconciles that set against a feed snapshot on every [method sync]: new
## entities gain a node, departed entities have theirs freed, survivors are
## repositioned and re-textured in place. Replaces both Story 002's
## [code]_build_placeholder_occupants[/code] fixtures and the vertical slice's
## [code]_draw[/code] marker diamonds.
##
## [b]Deliberately a [RefCounted], not a [Node].[/b] It manipulates a node tree it
## does not itself belong to, which keeps it constructible in a test with nothing
## but a [BoardRenderer] — no scene, no autoload, no [code].tscn[/code] (coding
## standards: dependency injection over singletons).
##
## [b]Three load-contract rules from [code]assets/art/README.md[/code][/b] are
## enforced here and will silently corrupt the board if changed without reading it:
## [br]1. [b]2x textures[/b] — every sprite is drawn at [constant TEXTURE_SCALE],
##    because art ships at twice its on-screen size so one asset serves 1080p and
##    1440p (art-bible §8.3). Never blit 1:1.
## [br]2. [b]Bottom-centre pivot[/b] — sprites are trimmed to their opaque bounds
##    and authored so bottom-centre IS the ground-contact point, which is also the
##    Y-sort key (§8.4/§8.8). Anchored per-texture via
##    [member Sprite2D.offset]; sizes differ per asset, so a shared frame must
##    never be assumed. This is what lets
##    [code]position = grid_to_screen(tile)[/code] work with no extra offset.
## [br]3. [b]Facing[/b] — only [code]e[/code] and [code]w[/code] are authored; see
##    [method EntitySpriteCatalog.facing_for_delta].
##
## [b]No child ever sets [code]z_index[/code][/b] (ADR-0013 §2, Control Manifest):
## depth among occupants is native [member Node2D.y_sort_enabled] on the parent
## layer, and a child z_index would fight it.
##
## Usage:
## [codeblock]
## var feed := EntitySpriteFeed.new(board, [Factions.RUSH, Factions.BOOM])
## feed.sync(reader.entities())   # call after every applied action
## [/codeblock]
class_name EntitySpriteFeed
extends RefCounted

## Divisor applied to every sprite so 2x art draws at its on-screen size
## (assets/art/README.md; art-bible §8.3). Paired with
## [constant BoardRenderer.TEXTURE_SCALE] — the floor layer solves the same 2x
## problem with a layer scale instead, and the two must stay in step.
const TEXTURE_SCALE: float = 2.0

## Tint for the missing-texture placeholder ([method _placeholder_texture]).
## Deliberately an alarming out-of-palette magenta: the art bible's board palette
## is entirely cool blues, so this can never be mistaken for real art.
const MISSING_TEXTURE_TINT: Color = Color(1.0, 0.0, 1.0, 0.9)

## Size in pixels of the missing-texture placeholder, in TEXTURE-space (i.e.
## pre-[constant TEXTURE_SCALE]), so it draws at roughly one on-screen tile.
const MISSING_TEXTURE_SIZE: Vector2i = Vector2i(128, 128)

## Target on-screen WIDTH for a structure sprite, in pixels.
##
## [b]Why structures are not simply drawn at [constant TEXTURE_SCALE] like units.[/b]
## The asset spec authored HQ and Production Outpost to a "multi-tile footprint"
## (`vs-entities-assets.md` ASSET-001/ASSET-003), but the simulation gives every
## structure exactly ONE tile — [member StructureState.position] is a single
## [Vector2i] and `base-production.md` says it occupies "the tile", singular. Drawn
## at the unit scale, the HQ's 512px art lands at 256px: two tiles wide and nearly
## four tall, standing on one 128x64 tile.
##
## That is not just ugly — a silhouette covering tiles it does not occupy misleads
## about what is blocked and what is in range. Structures are therefore fitted to
## their real footprint: uniform scale, driven by width, so a one-tile object looks
## like a one-tile object. Height is left to follow, which keeps the HQ around two
## tiles tall and still reading as a landmark (vertical overhang is expected in this
## projection — ADR-0013 §2/art-bible §8.8 — horizontal overhang is what misleads).
##
## [b]Decision: user, 2026-08-19[/b], after seeing it in the S5-04 session. The
## alternative — giving structures a genuine multi-tile footprint in [GridState] —
## was considered and rejected as an ADR-0005-scale change mid-sprint.
const STRUCTURE_TARGET_WIDTH_PX: float = BoardRenderer.TILE_WIDTH_PX

## The board whose [member BoardRenderer.occupant_layer] this feed populates, and
## whose [method BoardRenderer.grid_to_screen] is the one placement anchor.
var _board: BoardRenderer

## Faction per player index, injected rather than read off [GameState] — the feed
## needs only this one fact about the match, and taking it as plain data keeps the
## class testable without building a [GameState] (coding standards: DI).
var _factions: Array[FactionDef]

## Live [code]entity_id -> Sprite2D[/code] map. The reconciliation key: an id
## present here but absent from a [method sync] snapshot is a departed entity and
## its node is freed.
var _nodes: Dictionary = {}

## Live [code]entity_id -> facing token[/code] map. Facing is PRESENTATION state
## with no home in [EntityState] (the data model has no facing field), so it is
## derived from observed travel and remembered here. Seeded to
## [constant EntitySpriteCatalog.DEFAULT_FACING] on first sight.
var _facings: Dictionary = {}

## Live [code]entity_id -> last seen grid position[/code] map, the travel-delta
## source for [method EntitySpriteCatalog.facing_for_delta].
var _positions: Dictionary = {}

## Lazily-built shared placeholder texture for the missing-art case. Built once and
## reused so a board full of unshipped types cannot bake one image per entity.
var _placeholder: ImageTexture = null

## The ONE [ShaderMaterial] every actor's glow overlay shares (Story 007, §8.7
## rule 2). Per-actor variation lives entirely in instance uniforms, never in a
## second material — a material per actor would break batching.
var _glow_material: ShaderMaterial = null

## Live [code]entity_id -> glow overlay Sprite2D[/code] map. Each overlay is a CHILD
## of that entity's base sprite, so it inherits position and draws immediately after
## its parent (i.e. on top) with no depth bookkeeping of its own.
var _glow_nodes: Dictionary = {}

## Live [code]entity_id -> last written glow state[/code], as
## [code][mode, pulse_base][/code]. The gate that makes glow EVENT-DRIVEN (AC-6):
## instance uniforms are rewritten only when an actor's state actually changes, not
## every frame. The time-varying part (breathe, flare decay) is the shader's job,
## fed by the single shared [member _state_timer] write.
var _glow_states: Dictionary = {}

## Live [code]entity_id -> has_attacked as last seen[/code]. The edge detector that
## fires the attack flare — see [method _refresh_glow] for why the flare is derived
## from state rather than from an event.
var _attacked: Dictionary = {}

## The presentation clock driving breathe and flare decay, advanced by
## [method advance_glow]. [b]Never the shader TIME built-in[/b] — glow must freeze
## with the turn-based pause (§8.9, AC-5).
var _state_timer: float = 0.0

## When true, [method advance_glow] ignores its delta and the glow holds its current
## frame. Set from whatever owns pause; the feed itself has no opinion on when the
## game is paused.
var glow_paused: bool = false

## Optional predicate [code]func(entity: EntityState) -> bool[/code] answering "can
## this actor still act?", which selects breathe vs the AP-spent clamp. Injected
## rather than read off [GameState] so the feed stays testable with plain data.
##
## [b]Default (null) breathes everything[/b] — an un-wired board glows rather than
## sitting inert, which fails visibly instead of looking like a dead shader.
##
## ★ [b]Design read, flagged for S5-03:[/b] the vertical slice wires this to the
## OWNING PLAYER's AP pool, which is art-bible §8.5/§2.6 read literally ("AP
## available" / "0 AP") and dims a player's whole army at once. The alternative —
## per-unit actionability, so a unit that has already moved and attacked clamps
## while its idle squadmates keep breathing — carries strictly more tactical
## information and is a one-line change here. Which one reads better is a legibility
## call for the S5-03 session, not an implementation detail.
var actionable_predicate: Callable = Callable()

## Live [code]entity_id -> Vector2[/code] transform offset in board pixels, the
## displacement half of §8.5's motion states (Story 008 / S5-06).
##
## [b]Why an offset instead of tweening [member Node2D.position] directly.[/b]
## [method _refresh_entity] rewrites every tracked sprite's position on every
## [method sync], and a sync fires after every applied action — including actions
## that land mid-tween (the AI commits on a pacing timer). A tween writing
## position directly would be silently stomped, or would stomp the board, half the
## time. Composing [code]grid_to_screen(tile) + offset[/code] instead makes the two
## writers independent: sync owns the tile, the tween owns the offset, and neither
## can clobber the other.
var _offsets: Dictionary = {}

## Live [code]entity_id -> Tween[/code] for the in-flight motion tween, at most one
## per entity. A new motion kills the previous one so a rapid move-then-attack
## cannot leave two tweens fighting over the same offset. Created off the SPRITE
## node ([method Node.create_tween]), so freeing the sprite kills its tween.
var _tweens: Dictionary = {}

## Ids currently playing §8.5's destroyed beat: gone from the simulation, still on
## screen. [b]The death echo[/b] — see [method power_down] for the whole mechanism
## and why it exists.
var _dying: Dictionary = {}

## Live [code]entity_id -> ownership marker Sprite2D[/code] under
## [member BoardRenderer.marker_layer] (Story 009 / S5-08).
##
## [b]A sibling in another layer, not a child of the body sprite.[/b] A child would
## inherit the §8.5 motion transforms — the decal would lean with a moving unit and
## lunge with an attacking one, when it must stay flat on the tile it marks. It also
## has to draw UNDER its entity, which a child cannot do without a z_index that
## ADR-0013 §2 forbids.
var _marker_nodes: Dictionary = {}

## Which entities get an ownership decal (Story 009 / S5-08).
enum MarkerPolicy {
	ALL, ## Every entity. Delivers the non-hue channel board-wide, at more board clutter.
	STRUCTURES_ONLY, ## [b]The default.[/b] Structures only — the entities the S5-08 measurement found weak.
	NONE, ## Hue-only ownership, the pre-S5-08 behaviour.
}

## How widely ownership decals are drawn. Changing it takes effect on the next
## [method sync].
##
## [b]Defaults to [constant MarkerPolicy.STRUCTURES_ONLY] — user decision,
## 2026-08-21[/b], made off the Story 009 render sheet
## (`production/qa/evidence/s5-08-marker-render/`).
##
## The reasoning, recorded so it is not re-litigated: the decal is aimed at a
## measured problem, and that problem is entirely structural. Units already carry
## ownership strongly on their own — 26–82% faction-accent coverage, ΔE 60–76 under
## deuteranopia — while structures sit at 5–22%, with the Defensive Structure at
## ΔE 2.3 across its whole silhouette even in normal colour vision
## (`s5-08-colourblind-ownership-brief.md`). Putting a decal under every unit as
## well spends board clutter where nothing was broken, and art-bible §3.5 is
## explicit that nothing may compete with the actors for the eye.
##
## ★ [b]Known consequence, deliberately accepted.[/b] Under this policy units carry
## ownership by hue ALONE, so a unit-only read does not survive full desaturation —
## §1 P2's non-hue channel exists on the board, but not under every actor on it.
## Structures, the Neutral-vs-Neutral mirror's own anchors, and the weak-ownership
## case are all covered. Switching to [constant MarkerPolicy.ALL] restores the
## board-wide channel if a monochromacy claim is ever made in earnest.
var marker_policy: MarkerPolicy = MarkerPolicy.STRUCTURES_ONLY

## Live [code]entity_id -> the EntityState last seen for it[/code]. Retained solely
## so [method power_down] can still resolve a destroyed actor's texture and faction
## AFTER [method GameState.destroy_entity] has erased it from
## [code]entities_by_id[/code] — by then there is nothing left to ask.
var _last_entity: Dictionary = {}


## Binds this feed to [param board]'s occupant layer, with [param factions] indexed
## by player. Adds nothing to the tree until the first [method sync].
func _init(board: BoardRenderer, factions: Array[FactionDef]) -> void:
	_board = board
	_factions = factions


## Reconciles the sprite set under [member BoardRenderer.occupant_layer] against
## [param entities] — the one entry point, called after every applied action.
##
## Three passes, in order: refresh/create a node per fed entity, then free every
## node whose entity is no longer fed, then re-derive facing. Freeing uses
## [method Node.queue_free] after an immediate [method Node.remove_child] so a
## departed entity leaves the tree in the same frame it leaves the feed rather
## than lingering for a frame (Story 006 AC-1: no orphans).
##
## O(entities + tracked nodes).
func sync(entities: Array[EntityState]) -> void:
	if _board == null or _board.occupant_layer == null:
		return
	var seen: Dictionary = {}
	for entity: EntityState in entities:
		seen[entity.entity_id] = true
		_refresh_entity(entity)
	_free_departed(seen)


## Creates or updates the [Sprite2D] for [param entity]: resolves facing from
## observed travel, resolves and applies the texture, re-anchors the
## bottom-centre pivot for THIS texture's size, and places it at
## [method BoardRenderer.grid_to_screen] with no extra offset.
func _refresh_entity(entity: EntityState) -> void:
	var id: int = entity.entity_id
	# A live entity arriving on an id that is mid-death-echo means the simulation
	# has recycled the id inside the beat. Vanishingly unlikely at 0.35s, but the
	# failure mode if it ever happened would be a new unit wearing a corpse's
	# fade-out, so end the echo now and rebuild clean.
	if _dying.has(id):
		_finish_death(id)
	var facing: String = _update_facing(entity)
	var sprite: Sprite2D = _nodes.get(id)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Entity%d" % id
		# centered=false + an explicit offset is what puts the pivot at
		# bottom-centre; Sprite2D's default centring anchors the bbox CENTRE,
		# which art-bible §8.4 forbids as a Y-sort key.
		sprite.centered = false
		# NO z_index is ever set here — see the class doc comment.
		_nodes[id] = sprite
		_board.occupant_layer.add_child(sprite)
	var texture: Texture2D = _texture_for(entity, facing)
	sprite.texture = texture
	var size: Vector2 = texture.get_size()
	# Scale is re-derived per texture, not set once at creation: sprites are trimmed
	# to their opaque bounds so every asset differs, and a structure is fitted to its
	# one-tile footprint rather than to the flat 2x art scale.
	sprite.scale = _scale_for(entity, size)
	sprite.offset = Vector2(-size.x * 0.5, -size.y)
	# Composed, not assigned: an in-flight §8.5 motion tween owns the offset term
	# and this sync owns the tile term. See [member _offsets].
	sprite.position = _board.grid_to_screen(entity.position) + _offset_for(id)
	_last_entity[id] = entity
	_refresh_marker(entity)
	# Applied HERE and not inside _refresh_glow: that method early-returns for any
	# actor with no authored emission mask, and the body read must not depend on
	# whether a mask happens to exist. It is also gated behind an unchanged-state
	# check in there, which would skip it.
	_refresh_body_tint(entity, sprite)
	_refresh_glow(entity, sprite, facing)


## Derives, stores and returns [param entity]'s current facing. An entity seen for
## the first time takes [constant EntitySpriteCatalog.DEFAULT_FACING] (there is no
## travel to read a sign from); a moved entity takes the sign of its screen-x
## travel; a stationary entity keeps what it had.
func _update_facing(entity: EntityState) -> String:
	var id: int = entity.entity_id
	var previous: String = _facings.get(id, EntitySpriteCatalog.DEFAULT_FACING)
	if _positions.has(id):
		var delta: Vector2i = entity.position - (_positions[id] as Vector2i)
		previous = EntitySpriteCatalog.facing_for_delta(delta, previous)
	_facings[id] = previous
	_positions[id] = entity.position
	return previous


## Loads the texture for [param entity] at [param facing], or returns the loud
## magenta placeholder if the art is missing.
##
## [b]A missing texture is an explicit, logged failure, never a blank sprite[/b]
## (Story 006 QA). Only 5 of the 9 entity types have shipped art as of 2026-08-19 —
## Scout, Trooper, Heavy, HQ and Production Outpost. Sniper, Defensive Structure,
## Economy Outpost and Research Lab have none, so any of those reaching the board
## lands here. A silent blank would look exactly like a rendering bug; the
## placeholder plus [method @GlobalScope.push_error] makes it obvious on screen AND
## in the log.
func _texture_for(entity: EntityState, facing: String) -> Texture2D:
	var path: String = EntitySpriteCatalog.texture_path(entity, _faction_for(entity.owner), facing)
	if path.is_empty():
		push_error("EntitySpriteFeed: no texture path for entity %d (unknown kind or null type def)" % entity.entity_id)
		return _placeholder_texture()
	if not ResourceLoader.exists(path):
		push_error("EntitySpriteFeed: missing texture '%s' for entity %d" % [path, entity.entity_id])
		return _placeholder_texture()
	var texture: Texture2D = load(path)
	if texture == null:
		push_error("EntitySpriteFeed: texture '%s' failed to load for entity %d" % [path, entity.entity_id])
		return _placeholder_texture()
	return texture


## The [FactionDef] for player [param owner], or [code]null[/code] when the index
## is out of range — which [method EntitySpriteCatalog.faction_token] resolves to
## neutral art rather than failing.
func _faction_for(owner: int) -> FactionDef:
	if owner < 0 or owner >= _factions.size():
		return null
	return _factions[owner]


## Frees every tracked node whose entity id is absent from [param seen], clearing
## its facing/position tracking with it so a later id reuse cannot inherit stale
## presentation state. (Ids are never reused within one match — this is belt and
## braces against a future save/load or replay path.)
func _free_departed(seen: Dictionary) -> void:
	var departed: Array = []
	for id: int in _nodes:
		if not seen.has(id):
			departed.append(id)
	for id: int in departed:
		# The death echo's whole job: an id playing §8.5's destroyed beat is absent
		# from the feed BY DEFINITION (destroy_entity erased it), so without this
		# guard it would be freed here on the very sync that reveals its death and
		# the beat could never play. [method _finish_death] frees it when the beat
		# ends instead.
		if _dying.has(id):
			continue
		_forget(id)


## Authors [BoardRenderer.OccupantPickRegion]s from the ACTUAL drawn sprite bounds
## of every tracked entity, back-to-front in Y-sort order (ascending screen y,
## entity id breaking exact-y ties so the order is deterministic).
##
## [b]This closes ADR-0013's occupant-clickable-region authoring gap[/b]
## (vertical-slice build-seam S3-05, `scope.md` §8(b)) — the array
## [member BoardRenderer.occupant_pick_regions] consumes was previously authored
## as a bare tile diamond per entity, which matched the placeholder markers but not
## a real sprite. A tall sprite's clickable region legitimately overlaps the
## diamond of the tile behind it, which is exactly the case ADR-0013 §4 says
## [method BoardRenderer.pick_at] must handle and [method BoardRenderer.screen_to_grid]
## cannot.
##
## The rect is the sprite's post-scale extent in board space
## ([code]position + offset * scale[/code] sized [code]texture_size * scale[/code])
## [b]merged with the occupied tile's own diamond bounds[/b]. Both halves are
## needed:
## [br]• Sprite bounds alone would make the tile itself unclickable. A sprite is
##   anchored at its ground-contact point, so its rect sits entirely ABOVE that
##   point — and [Rect2.has_point] excludes the bottom edge, so even the anchor
##   pixel would miss. Clicking the tile a unit is standing on must select it.
## [br]• Tile bounds alone were the placeholder-era behaviour and miss the body of
##   any sprite taller than one cell — which is every structure.
##
## Cover props are deliberately excluded — they are terrain, not clickable
## occupants.
##
## O(n log n) in tracked entities.
func pick_regions() -> Array[BoardRenderer.OccupantPickRegion]:
	var ids: Array = _nodes.keys()
	ids.sort_custom(_paint_order)
	var regions: Array[BoardRenderer.OccupantPickRegion] = []
	for id: int in ids:
		var sprite: Sprite2D = _nodes[id]
		if not is_instance_valid(sprite) or sprite.texture == null:
			continue
		# A destroyed actor mid-echo is a visual afterimage, not an occupant: it
		# holds no tile and cannot be selected or targeted. Leaving it clickable
		# would let a player pick an entity the simulation has already erased.
		if _dying.has(id):
			continue
		var region := BoardRenderer.OccupantPickRegion.new()
		var sprite_rect := Rect2(
			sprite.position + sprite.offset * sprite.scale,
			sprite.texture.get_size() * sprite.scale
		)
		var tile_rect := Rect2(
			sprite.position - Vector2(BoardRenderer.TILE_WIDTH_PX, BoardRenderer.TILE_HEIGHT_PX) * 0.5,
			Vector2(BoardRenderer.TILE_WIDTH_PX, BoardRenderer.TILE_HEIGHT_PX)
		)
		region.rect = sprite_rect.merge(tile_rect)
		region.entity_id = id
		region.tile = _positions.get(id, Vector2i.ZERO)
		regions.append(region)
	return regions


## Back-to-front ordering for [method pick_regions]: ascending drawn screen y (the
## Y-sort order), entity id breaking exact ties.
func _paint_order(a: int, b: int) -> bool:
	var sprite_a: Sprite2D = _nodes[a]
	var sprite_b: Sprite2D = _nodes[b]
	if sprite_a.position.y == sprite_b.position.y:
		return a < b
	return sprite_a.position.y < sprite_b.position.y


## Advances the glow clock by [param delta] seconds, driving breathe and flare
## decay. Call once per frame from whatever owns the board.
##
## [b]This is the ONLY per-frame glow work[/b] — one shared-uniform write for the
## whole board. Per-actor uniforms are touched only when an actor's state changes
## ([method _refresh_glow]), which is what AC-6's "event-driven, not polled" means.
##
## A no-op while [member glow_paused], so the glow freezes with the turn-based pause
## rather than drifting on underneath it (AC-5).
func advance_glow(delta: float) -> void:
	if glow_paused or _glow_material == null:
		return
	_state_timer += delta
	_glow_material.set_shader_parameter(&"state_timer", _state_timer)


## The current glow clock, in seconds. Exposed for tests and for anything that needs
## to stamp a flare start.
func state_timer() -> float:
	return _state_timer


## Triggers the attack flare on [param entity_id] — peak emission decaying back onto
## the actor's resting level (§2.2). A no-op for an entity with no glow overlay.
##
## S5-06 owns the body lunge this is meant to sync with; this story owns only the
## light.
func flare(entity_id: int) -> void:
	var glow: Sprite2D = _glow_nodes.get(entity_id)
	if glow == null or not is_instance_valid(glow):
		return
	glow.set_instance_shader_parameter(&"glow_mode", float(EntityGlow.Mode.FLARE))
	glow.set_instance_shader_parameter(&"flare_start", _state_timer)
	# Record the flare so the next ordinary state refresh does not treat the actor as
	# unchanged and leave it stuck flaring.
	_glow_states[entity_id] = [EntityGlow.Mode.FLARE, _resting_pulse_for(entity_id)]


# --- Body state tint (Story 010 / S5-07 finding) -----------------------------

## Sets [param sprite]'s body multiply for [param entity]'s current state — full
## brightness while it can act, [constant EntityGlow.SPENT_BODY_TINT] once it cannot.
##
## [b]This is the state read.[/b] The S5-07 windowed pass measured the glow-only
## version at 12.5/255 on the trim at its best moment, 3.3/255 at its worst, over
## 0.67% of the frame — because the emission shader only ADDS light and cannot dim a
## sprite that is already brightly painted. Multiplying the body moves the same
## signal onto the whole silhouette; the win is area far more than contrast.
##
## A no-op for an actor mid-death-echo: [method power_down] owns the tint from that
## point on and is tweening it, so an ordinary sync must not stamp over it.
func _refresh_body_tint(entity: EntityState, sprite: Sprite2D) -> void:
	if _dying.has(entity.entity_id):
		return
	var destroyed: bool = EntitySpriteCatalog.state_token(entity) == EntitySpriteCatalog.STATE_DESTROYED
	_set_body_tint(sprite, EntityGlow.body_tint_for(destroyed, _is_actionable(entity)))


## Writes a grey multiply into [param sprite]'s [member CanvasItem.self_modulate]
## while [b]preserving its alpha[/b].
##
## Two independent things share this property and must not clobber each other: RGB
## carries the state tint (here), alpha carries the death-echo cross-fade
## ([method power_down]). Assigning a whole Color would reset whichever one the
## caller was not thinking about.
##
## [b]self_modulate, never modulate[/b]: modulate is inherited by children, so it
## would drag the glow overlay and the wreck down with the body. The glow already
## carries its own state via `pulse_base`, and dimming it twice would double-count.
static func _set_body_tint(sprite: Sprite2D, tint: float) -> void:
	sprite.self_modulate = Color(tint, tint, tint, sprite.self_modulate.a)


## The tween target for [method power_down]'s body darkening. Offset-first argument
## order, matching [method _set_offset] — [method Tween.tween_method] passes the
## interpolated value first and the bound id after it.
func _set_body_tint_for(tint: float, entity_id: int) -> void:
	var sprite: Sprite2D = _nodes.get(entity_id)
	if sprite != null and is_instance_valid(sprite):
		_set_body_tint(sprite, tint)


# --- Ownership markers (Story 009 / S5-08) -----------------------------------

## Creates or repositions [param entity]'s faction ownership decal on
## [member BoardRenderer.marker_layer].
##
## The decal is a flat tile-sized band whose SHAPE differs per faction, so ownership
## survives with hue removed — the non-hue backup art-bible §1 P2 requires and §5.2
## never shipped. Because it is the same size for every entity, a structure that
## carries faction colour on 5% of its own body still gets a full-strength ownership
## tell; see [OwnershipMarker] for why that was the problem worth solving.
##
## Positioned at the tile centre with no motion offset applied: the marker belongs to
## the TILE, and an actor leaning or lunging must slide against its own decal rather
## than drag it along.
func _refresh_marker(entity: EntityState) -> void:
	var id: int = entity.entity_id
	if not _wants_marker(entity) or _board == null or _board.marker_layer == null:
		_remove_marker(id)
		return
	var marker: Sprite2D = _marker_nodes.get(id)
	if marker == null:
		marker = Sprite2D.new()
		marker.name = "Marker%d" % id
		marker.centered = false
		# NO z_index (ADR-0013 §2) — the whole LAYER carries the band, and a child
		# setting its own would be the exact escape the ADR's guardrail forbids.
		_marker_nodes[id] = marker
		_board.marker_layer.add_child(marker)
	var texture: ImageTexture = OwnershipMarker.texture_for(_faction_for(entity.owner))
	marker.texture = texture
	var size: Vector2 = texture.get_size()
	marker.scale = Vector2.ONE / OwnershipMarker.TEXTURE_SCALE
	# Centred on the tile, unlike the body sprites' bottom-centre pivot: a decal has
	# no ground-contact point, it IS the ground.
	marker.offset = -size * 0.5
	marker.position = _board.grid_to_screen(entity.position)


## Whether [param entity] gets a decal under the current [member marker_policy].
func _wants_marker(entity: EntityState) -> bool:
	match marker_policy:
		MarkerPolicy.ALL:
			return true
		MarkerPolicy.STRUCTURES_ONLY:
			return entity is StructureState
		_:
			return false


## Drops [param entity_id]'s ownership decal, if it has one.
func _remove_marker(entity_id: int) -> void:
	var marker: Sprite2D = _marker_nodes.get(entity_id)
	_marker_nodes.erase(entity_id)
	if marker != null and is_instance_valid(marker):
		if marker.get_parent() != null:
			marker.get_parent().remove_child(marker)
		marker.queue_free()


# --- §8.5 state transforms (Story 008 / S5-06) -------------------------------

## Tips [param entity_id] into a move, per §8.5's directional lean.
## [param screen_delta] is the travel in board pixels; a move with no horizontal
## component leans nowhere (see [method EntityTransforms.lean_angle]).
##
## Rotation, not displacement — the sprite is anchored at its ground-contact
## point, so this pivots at the feet and the actor genuinely tips. A no-op for an
## untracked or dying entity.
func lean(entity_id: int, screen_delta: Vector2) -> void:
	var sprite: Sprite2D = _live_sprite(entity_id)
	if sprite == null:
		return
	var angle: float = EntityTransforms.lean_angle(screen_delta)
	if is_zero_approx(angle):
		return
	var tween: Tween = _begin_tween(entity_id, sprite)
	tween.tween_property(sprite, ^"rotation", angle, EntityTransforms.LEAN_OUT_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, ^"rotation", 0.0, EntityTransforms.LEAN_SETTLE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Shoves [param attacker_id] toward [param target_id] and back — §8.5's attack,
## "snappy, synced to the §2.2 flare spike". The caller fires [method flare] on
## the same frame so the body and the light spike together.
##
## A no-op for an untracked or dying attacker, or when the two occupy the same
## point (which the simulation never produces).
func lunge(attacker_id: int, target_id: int) -> void:
	var sprite: Sprite2D = _live_sprite(attacker_id)
	if sprite == null:
		return
	var shove: Vector2 = EntityTransforms.nudge(
		_base_position(attacker_id), _base_position(target_id),
		EntityTransforms.LUNGE_DISTANCE_PX
	)
	if shove.is_zero_approx():
		return
	_offset_tween(
		attacker_id, sprite, shove,
		EntityTransforms.LUNGE_OUT_SEC, EntityTransforms.LUNGE_BACK_SEC
	)


## Rocks [param target_id] away from [param attacker_id] and back — §8.5's brief
## "plating absorbs impact" recoil. Deliberately a smaller, faster-out,
## slower-back motion than [method lunge]; see [constant
## EntityTransforms.RECOIL_DISTANCE_PX].
##
## [b]Fires on every hit that lands, including a lethal one.[/b] A lethal hit's
## recoil is immediately overridden by [method power_down] (which kills the
## in-flight tween), so a killing blow reads as a power-down rather than a rock
## back — which is the §8.5 intent, and is why the caller dispatches deaths
## before damage.
func recoil(target_id: int, attacker_id: int) -> void:
	var sprite: Sprite2D = _live_sprite(target_id)
	if sprite == null:
		return
	# Arguments reversed against [method lunge]: away from the attacker, not toward.
	var rock: Vector2 = EntityTransforms.nudge(
		_base_position(attacker_id), _base_position(target_id),
		EntityTransforms.RECOIL_DISTANCE_PX
	)
	if rock.is_zero_approx():
		return
	_offset_tween(
		target_id, sprite, rock,
		EntityTransforms.RECOIL_OUT_SEC, EntityTransforms.RECOIL_BACK_SEC
	)


## Starts §8.5's destroyed beat on [param entity_id] — [b]the death echo[/b].
##
## [b]Why an echo is needed at all.[/b] [method GameState.destroy_entity] erases
## an entity from [code]entities_by_id[/code] in the same frame its hp hits zero,
## so a destroyed actor never appears in a [method sync] snapshot — it simply
## vanishes mid-board. §8.5 locks a 2-4 frame power-down that there is, by
## construction, nothing left on screen to play it on. This method is the fix
## flagged as owed by Story 006 (see [constant
## EntitySpriteCatalog.STATE_DESTROYED], "nothing puts it on screen until S5-06"):
## the id is marked dying, which exempts its node from [method _free_departed],
## and the node is freed by [method _finish_death] once the beat has run.
##
## [b]Call this BEFORE the [method sync] that reveals the death[/b], from the
## events of the action that caused it. Called after, the node is already gone.
##
## The beat itself: the destroyed art cross-fades in over the idle art while the
## glow falls to zero, light first and body after ([constant
## EntityTransforms.DEATH_GLOW_FRACTION]) — a shutdown, not an explosion. An
## actor with no destroyed art authored simply fades out, which still reads as a
## power-down and never leaves a live-looking sprite behind.
func power_down(entity_id: int) -> void:
	var sprite: Sprite2D = _nodes.get(entity_id)
	if sprite == null or not is_instance_valid(sprite) or _dying.has(entity_id):
		return
	_dying[entity_id] = true
	_kill_tween(entity_id)   # a lethal hit's recoil loses to its own power-down.
	var tween: Tween = sprite.create_tween()
	_tweens[entity_id] = tween
	tween.set_parallel(true)

	# The light dies first and faster than the body (§8.5 pulse_intensity -> 0).
	var glow: Sprite2D = _glow_nodes.get(entity_id)
	if glow != null and is_instance_valid(glow):
		glow.set_instance_shader_parameter(&"glow_mode", float(EntityGlow.Mode.STATIC))
		tween.tween_method(
			_set_glow_pulse.bind(entity_id), _resting_pulse_for(entity_id), 0.0,
			EntityTransforms.DEATH_ECHO_SEC * EntityTransforms.DEATH_GLOW_FRACTION
		)

	# The body DARKENS as it dies, not just fades. Fading alone left a destroyed
	# actor measurably as bright as a live one (8.9/255, 3.5% — S5-07 finding 2):
	# ceasing to emit cannot power an actor down while its base art stays fully
	# painted. Tweened rather than snapped, because this one IS the beat.
	tween.tween_method(
		_set_body_tint_for.bind(entity_id),
		sprite.self_modulate.r, EntityGlow.DESTROYED_BODY_TINT,
		EntityTransforms.DEATH_ECHO_SEC
	)

	# self_modulate, never modulate: modulate would drag the glow child down with
	# the body on the same curve, and the light is supposed to lead.
	var wreck: Sprite2D = _build_wreck(entity_id, sprite)
	if wreck != null:
		tween.tween_property(wreck, ^"self_modulate:a", 1.0, EntityTransforms.DEATH_ECHO_SEC)
		tween.tween_property(sprite, ^"self_modulate:a", 0.0, EntityTransforms.DEATH_ECHO_SEC)
	else:
		# No destroyed art for this type — fade the body out rather than cutting it,
		# so the loss still reads as a shutdown.
		tween.tween_property(sprite, ^"self_modulate:a", 0.0, EntityTransforms.DEATH_ECHO_SEC)
	# The ownership decal goes with the body — a dead entity owns no tile, and a
	# marker left at full strength under a fading corpse would read as "something is
	# still standing here".
	var marker: Sprite2D = _marker_nodes.get(entity_id)
	if marker != null and is_instance_valid(marker):
		tween.tween_property(marker, ^"modulate:a", 0.0, EntityTransforms.DEATH_ECHO_SEC)
	tween.chain().tween_callback(_finish_death.bind(entity_id))


## Whether [param entity_id] is mid-death-echo — on screen but erased from the
## simulation. Exposed for tests and for anything that must not treat an
## afterimage as a live occupant.
func is_dying(entity_id: int) -> bool:
	return _dying.has(entity_id)


## Builds the destroyed-art overlay for [param entity_id] as a transparent child of
## [param sprite], or returns [code]null[/code] if no destroyed texture is
## authored for it.
##
## A CHILD rather than a texture swap because the two stills must be on screen
## together to cross-fade. It copies the parent's local frame exactly — the two
## states are authored to the same trimmed bounds and pivot, so the wreck stands
## where the body stood.
func _build_wreck(entity_id: int, sprite: Sprite2D) -> Sprite2D:
	var entity: EntityState = _last_entity.get(entity_id)
	if entity == null:
		return null
	var facing: String = _facings.get(entity_id, EntitySpriteCatalog.DEFAULT_FACING)
	var path: String = EntitySpriteCatalog.texture_path(
		entity, _faction_for(entity.owner), facing
	)
	# state_token() reads current_hp off the retained state, which destroy_entity
	# left at or below zero — so this path resolves to the destroyed art without
	# needing to be told the entity died.
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var wreck := Sprite2D.new()
	wreck.name = "Destroyed"
	wreck.centered = false
	wreck.texture = load(path)
	var size: Vector2 = wreck.texture.get_size()
	wreck.offset = Vector2(-size.x * 0.5, -size.y)
	# Starts transparent (so it can fade IN over the body) and already DARK — the
	# wreck is the dead thing, and it should never appear at live brightness even
	# for a frame. Alpha is animated; the rgb multiply is not.
	wreck.self_modulate = Color(
		EntityGlow.DESTROYED_BODY_TINT, EntityGlow.DESTROYED_BODY_TINT,
		EntityGlow.DESTROYED_BODY_TINT, 0.0
	)
	# NO z_index here either (ADR-0013 section 2) — it draws after its parent by
	# virtue of being a child, which is exactly the "on top" this needs.
	sprite.add_child(wreck)
	return wreck


## Ends [param entity_id]'s death echo: drops the dying mark and frees the node
## and every map entry, the deletion [method _free_departed] deferred.
func _finish_death(entity_id: int) -> void:
	_dying.erase(entity_id)
	_forget(entity_id)


## Frees [param entity_id]'s sprite (its glow and wreck children with it) and
## drops every map entry keyed on it. The single teardown path, shared by an
## ordinary departure and the end of a death echo, so no map can be left holding
## a freed node.
func _forget(entity_id: int) -> void:
	_kill_tween(entity_id)
	var sprite: Sprite2D = _nodes.get(entity_id)
	_nodes.erase(entity_id)
	_facings.erase(entity_id)
	_positions.erase(entity_id)
	_glow_nodes.erase(entity_id)   # freed with its parent sprite below
	_glow_states.erase(entity_id)
	_attacked.erase(entity_id)
	_offsets.erase(entity_id)
	_dying.erase(entity_id)
	_last_entity.erase(entity_id)
	_remove_marker(entity_id)
	if sprite != null and is_instance_valid(sprite):
		if sprite.get_parent() != null:
			sprite.get_parent().remove_child(sprite)
		sprite.queue_free()


## The out-and-back offset tween shared by [method lunge] and [method recoil]:
## [param sprite] displaces by [param peak] over [param out_sec], then returns to
## rest over [param back_sec].
func _offset_tween(
	entity_id: int, sprite: Sprite2D, peak: Vector2,
	out_sec: float, back_sec: float
) -> void:
	var tween: Tween = _begin_tween(entity_id, sprite)
	tween.tween_method(
		_set_offset.bind(entity_id), _offset_for(entity_id), peak, out_sec
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_offset.bind(entity_id), peak, Vector2.ZERO, back_sec
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Starts a fresh tween for [param entity_id] on [param sprite], killing whatever
## it was already playing. One motion at a time per actor: a move-then-attack in
## quick succession must not leave two tweens writing the same offset.
func _begin_tween(entity_id: int, sprite: Sprite2D) -> Tween:
	_kill_tween(entity_id)
	var tween: Tween = sprite.create_tween()
	_tweens[entity_id] = tween
	return tween


## Stops and drops [param entity_id]'s in-flight tween, if any.
func _kill_tween(entity_id: int) -> void:
	var tween: Tween = _tweens.get(entity_id)
	_tweens.erase(entity_id)
	if tween != null and is_instance_valid(tween) and tween.is_valid():
		tween.kill()


## Writes [param entity_id]'s transform offset and re-composes its position from
## it. The tween target for [method lunge] and [method recoil] — see
## [member _offsets] for why the displacement is a separate term.
##
## Argument order is offset-first because [method Tween.tween_method] passes the
## interpolated value as the first argument and the bound id follows it.
func _set_offset(offset: Vector2, entity_id: int) -> void:
	_offsets[entity_id] = offset
	var sprite: Sprite2D = _nodes.get(entity_id)
	if sprite != null and is_instance_valid(sprite):
		sprite.position = _base_position(entity_id) + offset


## Writes [param entity_id]'s glow resting level. The tween target for [method
## power_down]'s light fade; same offset-first argument order as
## [method _set_offset].
func _set_glow_pulse(pulse: float, entity_id: int) -> void:
	var glow: Sprite2D = _glow_nodes.get(entity_id)
	if glow != null and is_instance_valid(glow):
		glow.set_instance_shader_parameter(&"pulse_base", pulse)


## [param entity_id]'s sprite if it is tracked, still valid and NOT mid-death-echo,
## else [code]null[/code].
##
## The dying check is what stops a corpse being animated: [method lean],
## [method lunge] and [method recoil] all gate on this, so an actor that died to
## the same action keeps its power-down instead of leaning or rocking through it.
func _live_sprite(entity_id: int) -> Sprite2D:
	if _dying.has(entity_id):
		return null
	var sprite: Sprite2D = _nodes.get(entity_id)
	if sprite == null or not is_instance_valid(sprite):
		return null
	return sprite


## [param entity_id]'s current transform offset, or zero if it has none.
func _offset_for(entity_id: int) -> Vector2:
	return _offsets.get(entity_id, Vector2.ZERO)


## [param entity_id]'s untransformed board position — the screen point of the tile
## it stands on, with no motion offset applied.
func _base_position(entity_id: int) -> Vector2:
	if _board == null or not _positions.has(entity_id):
		return Vector2.ZERO
	return _board.grid_to_screen(_positions[entity_id])


## Creates or updates [param entity]'s additive glow overlay as a child of
## [param sprite].
##
## The overlay is a separate [Sprite2D] rather than a second texture on the base
## sprite because a shared [ShaderMaterial] cannot carry a per-actor mask — Godot's
## instance uniforms are scalars and vectors, never samplers. Making the mask the
## overlay's own [code]TEXTURE[/code] keeps one material for the whole board, which
## is the batch-safe requirement, and uses only the shader surface the S4-01 spike
## already confirmed on this engine.
##
## Uniforms are written only when the actor's [enum EntityGlow.Mode] or resting level
## actually changes (AC-6).
func _refresh_glow(entity: EntityState, sprite: Sprite2D, facing: String) -> void:
	var id: int = entity.entity_id
	var path: String = EntityGlow.mask_path(entity, facing)
	if path.is_empty() or not ResourceLoader.exists(path):
		# No mask authored for this actor (every unshipped type, and every destroyed
		# state — a dead actor emits nothing, so it is never owed one). Not an error.
		_remove_glow(id)
		return
	if _glow_material == null:
		_glow_material = EntityGlow.make_material()
		_glow_material.set_shader_parameter(&"state_timer", _state_timer)

	var glow: Sprite2D = _glow_nodes.get(id)
	if glow == null:
		glow = Sprite2D.new()
		glow.name = "Glow"
		glow.centered = false
		glow.material = _glow_material
		_glow_nodes[id] = glow
		sprite.add_child(glow)
		# Hue never changes for a live entity, so it is written once here rather than
		# on every refresh.
		glow.set_instance_shader_parameter(
			&"faction_hue", EntityGlow.hue_for(_faction_for(entity.owner))
		)
	# The mask matches its sprite pixel-for-pixel, so it shares the parent's local
	# frame exactly — same offset, no scale of its own (the parent already carries
	# the 2x-art scale).
	glow.texture = load(path)
	glow.offset = sprite.offset

	var destroyed: bool = EntitySpriteCatalog.state_token(entity) == EntitySpriteCatalog.STATE_DESTROYED
	var pulse_base: float = EntityGlow.resting_pulse(destroyed)
	glow.set_instance_shader_parameter(&"pulse_base", pulse_base)

	# An attack is detected here from STATE — watching has_attacked flip
	# false->true, which catches the AI's attacks as well as the player's. Story 008
	# has since added [DamageEvent], and the slice now ALSO calls [method flare]
	# from it; the two agree on every ordinary attack and the call is idempotent
	# within a frame. Both are kept because they cover different gaps: the event
	# path is the only one that catches a COUNTERATTACK (a counter is free and
	# never sets has_attacked, so this detector is blind to it), and this path is
	# the only one that survives a board rebuilt from state with no event to
	# replay. The start-of-turn reset flips has_attacked true->false and correctly
	# does not flare.
	var attacked: bool = _has_attacked(entity)
	var attacked_before: bool = _attacked.get(id, false)
	_attacked[id] = attacked
	if attacked and not attacked_before and not destroyed:
		glow.set_instance_shader_parameter(&"glow_mode", float(EntityGlow.Mode.FLARE))
		glow.set_instance_shader_parameter(&"flare_start", _state_timer)
		_glow_states[id] = [EntityGlow.Mode.FLARE, pulse_base]
		return

	var mode: EntityGlow.Mode = EntityGlow.mode_for(destroyed, _is_actionable(entity))
	var previous: Array = _glow_states.get(id, [])
	if previous.size() == 2 and previous[0] == mode and is_equal_approx(previous[1], pulse_base):
		return   # unchanged — do not touch the uniforms (AC-6)
	glow.set_instance_shader_parameter(&"glow_mode", float(mode))
	_glow_states[id] = [mode, pulse_base]


## The draw scale for [param entity] whose texture measures [param texture_size].
##
## Units draw at the flat art scale — textures ship at [constant TEXTURE_SCALE] their
## on-screen size (art-bible §8.3). Structures are instead fitted to
## [constant STRUCTURE_TARGET_WIDTH_PX], their real one-tile footprint; see that
## constant for why the two differ.
static func _scale_for(entity: EntityState, texture_size: Vector2) -> Vector2:
	if entity is StructureState and texture_size.x > 0.0:
		return Vector2.ONE * (STRUCTURE_TARGET_WIDTH_PX / texture_size.x)
	return Vector2.ONE / TEXTURE_SCALE


## Whether [param entity] has attacked this turn. Both [UnitState] and
## [StructureState] carry the flag; a bare [EntityState] never attacks.
static func _has_attacked(entity: EntityState) -> bool:
	if entity is UnitState:
		return (entity as UnitState).has_attacked
	if entity is StructureState:
		return (entity as StructureState).has_attacked
	return false


## Whether [param entity] can still act, per [member actionable_predicate]. An
## unwired predicate breathes (see that member's doc comment).
func _is_actionable(entity: EntityState) -> bool:
	if not actionable_predicate.is_valid():
		return true
	return bool(actionable_predicate.call(entity))


## The resting level currently recorded for [param entity_id], or the live default.
func _resting_pulse_for(entity_id: int) -> float:
	var previous: Array = _glow_states.get(entity_id, [])
	return previous[1] if previous.size() == 2 else EntityGlow.SPENT_CLAMP


## Drops [param entity_id]'s glow overlay, for an actor that has no authored mask.
func _remove_glow(entity_id: int) -> void:
	var glow: Sprite2D = _glow_nodes.get(entity_id)
	_glow_nodes.erase(entity_id)
	_glow_states.erase(entity_id)
	if glow != null and is_instance_valid(glow):
		if glow.get_parent() != null:
			glow.get_parent().remove_child(glow)
		glow.queue_free()


## Builds (once) and returns the shared missing-art placeholder — a flat magenta
## block at [constant MISSING_TEXTURE_SIZE]. See [method _texture_for].
func _placeholder_texture() -> ImageTexture:
	if _placeholder == null:
		var image := Image.create(MISSING_TEXTURE_SIZE.x, MISSING_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(MISSING_TEXTURE_TINT)
		_placeholder = ImageTexture.create_from_image(image)
	return _placeholder
