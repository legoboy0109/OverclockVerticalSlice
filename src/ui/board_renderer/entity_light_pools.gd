## EntityLightPools — the per-actor half of the HD-2D lighting pass (2026-09-30).
##
## Every live unit and structure casts a faint pool of its owner's colour onto the floor
## around it: a [PointLight2D] child of the actor's body sprite. [Hd2dLighting] owns the
## screen-level effects; this owns the pools. Pure helpers, like [EntityGlow] — the
## sprite feed calls [method ensure] and [method fade_out].
##
## [b]Only the floor is lit.[/b] Each pool's [member Light2D.range_item_cull_mask] is
## [constant FLOOR_LIGHT_MASK], and only the floor [TileMapLayer] and the cover props carry
## that bit in their [member CanvasItem.light_mask]. Units and structures keep the default
## mask (bit 1), so no sprite is ever tinted by a neighbour's light — a unit's own hue is
## the ownership signal (art bible §4.2) and must never pick up the enemy's.
##
## [b]Every number here is a tuning knob[/b] and lives in this file only.
class_name EntityLightPools
extends RefCounted

## Canvas light-mask bit that marks "receives HD-2D floor light". Bit 2 (value 2); bit 1
## is Godot's default, which every sprite keeps.
const FLOOR_LIGHT_MASK: int = 2
## Child node name, so the feed can find a sprite's pool.
const NODE_NAME: String = "LightPool"
## Pool brightness. 2D lights multiply the lit surface's own colour, so the value only
## makes sense against the near-black floor, and it depends on the blend space: tuned at
## 2.5 under HDR 2D, the same pools washed the floor and cover blocks bright blue once HDR
## was dropped (ADR-0020). In SDR, 0.6 is a subtle wash and 1.0 slightly stronger; 0.8
## keeps §1 P3's dark stage while the pools still read (real renders, 2026-09-30).
const POOL_ENERGY: float = 0.8
## Pool size on screen, in pixels, across its long (horizontal) axis. ~1.5 tiles
## (a tile is 128 px wide on screen) so neighbouring pools overlap into a soft wash.
const POOL_WIDTH_PX: float = 190.0
## Texture resolution; the pool is a 2:1 ellipse to lie flat on the iso floor.
const TEXTURE_SIZE: Vector2i = Vector2i(256, 128)

static var _texture: GradientTexture2D = null


## The shared 2:1 radial falloff texture — built once for every pool.
static func pool_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		# Ease the falloff so the edge is invisible, not a ring.
		gradient.add_point(0.45, Color(1, 1, 1, 0.45))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE.x
		_texture.height = TEXTURE_SIZE.y
	return _texture


## Gives [param sprite] its light pool in [param hue] (creating it once), sized in SCREEN
## pixels regardless of the sprite's own scale — structures are fitted to one tile and
## units drawn at 0.5, and a pool inheriting those would differ per actor.
static func ensure(sprite: Sprite2D, hue: Color) -> PointLight2D:
	var light := sprite.get_node_or_null(NODE_NAME) as PointLight2D
	if light == null:
		light = PointLight2D.new()
		light.name = NODE_NAME
		light.texture = pool_texture()
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.range_item_cull_mask = FLOOR_LIGHT_MASK
		light.energy = POOL_ENERGY
		sprite.add_child(light)
	light.color = hue
	var parent_scale: float = maxf(absf(sprite.scale.x), 0.0001)
	var s: float = POOL_WIDTH_PX / float(TEXTURE_SIZE.x) / parent_scale
	light.scale = Vector2(s, s)
	# The sprite's origin is its ground-contact point (bottom-centre pivot), so the pool
	# sits at local zero — under the feet, or under an aircraft's shadow.
	light.position = Vector2.ZERO
	return light


## Tweens [param sprite]'s pool out over [param duration] on [param tween] (the death
## echo), so the light goes with the body instead of lingering on the floor.
static func fade_out(sprite: Sprite2D, tween: Tween, duration: float) -> void:
	var light := sprite.get_node_or_null(NODE_NAME) as PointLight2D
	if light != null:
		tween.tween_property(light, ^"energy", 0.0, duration)
