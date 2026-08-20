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
		sprite.scale = Vector2.ONE / TEXTURE_SCALE
		# NO z_index is ever set here — see the class doc comment.
		_nodes[id] = sprite
		_board.occupant_layer.add_child(sprite)
	var texture: Texture2D = _texture_for(entity, facing)
	sprite.texture = texture
	var size: Vector2 = texture.get_size()
	sprite.offset = Vector2(-size.x * 0.5, -size.y)
	sprite.position = _board.grid_to_screen(entity.position)


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


## Builds (once) and returns the shared missing-art placeholder — a flat magenta
## block at [constant MISSING_TEXTURE_SIZE]. See [method _texture_for].
func _placeholder_texture() -> ImageTexture:
	if _placeholder == null:
		var image := Image.create(MISSING_TEXTURE_SIZE.x, MISSING_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(MISSING_TEXTURE_TINT)
		_placeholder = ImageTexture.create_from_image(image)
	return _placeholder
