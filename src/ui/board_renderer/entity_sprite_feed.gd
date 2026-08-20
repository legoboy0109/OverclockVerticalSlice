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
	sprite.position = _board.grid_to_screen(entity.position)
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
		var sprite: Sprite2D = _nodes[id]
		_nodes.erase(id)
		_facings.erase(id)
		_positions.erase(id)
		_glow_nodes.erase(id)   # freed with its parent sprite below
		_glow_states.erase(id)
		_attacked.erase(id)
		if is_instance_valid(sprite):
			if sprite.get_parent() != null:
				sprite.get_parent().remove_child(sprite)
			sprite.queue_free()


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

	# An attack is detected from STATE, not from an event: no event carries an
	# attacker id (ADR-0004's schema has no attack event at all), and adding one is a
	# core-layer change well outside this story. Watching has_attacked flip false->true
	# catches the AI's attacks as well as the player's, which a call-site hook in the
	# slice would not. The start-of-turn reset flips it true->false and correctly does
	# not flare.
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
