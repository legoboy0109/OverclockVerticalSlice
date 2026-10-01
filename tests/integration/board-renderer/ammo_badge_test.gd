# Out-of-ammo mark on the board (2026-10-01): shown beside a vehicle/aircraft with no ammo left,
# never on a unit with ammo or on infantry, gone once resupplied or dead.
extends GdUnitTestSuite

const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _setup() -> Array:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	return [renderer, feed]


func _unit(id: int, type: UnitTypeDef, spent: int) -> UnitState:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = 0
	u.position = Vector2i(2, 2)
	u.type = type
	u.current_hp = type.hp
	u.ammo_spent = spent
	return u


func test_ammo_badge_shows_on_an_empty_vehicle_on_the_unit_layer() -> void:
	var pair := _setup()
	var renderer: BoardRenderer = pair[0]
	var feed: EntitySpriteFeed = pair[1]
	feed.sync([_unit(1, UnitTypes.TANK, Ammo.max_ammo(UnitTypes.TANK))] as Array[EntityState])
	var badge: Sprite2D = feed.ammo_badge(1)
	assert_object(badge).is_not_null()
	assert_object(badge.texture).is_same(AmmoBadge.texture())
	assert_object(badge.get_parent()).is_same(renderer.occupant_layer)


func test_ammo_badge_absent_with_ammo_left_and_on_infantry() -> void:
	var pair := _setup()
	var feed: EntitySpriteFeed = pair[1]
	feed.sync([_unit(1, UnitTypes.TANK, 1), _unit(2, UnitTypes.TROOPER, 99)] as Array[EntityState])
	assert_object(feed.ammo_badge(1)).is_null()
	assert_object(feed.ammo_badge(2)).is_null()


func test_ammo_badge_leaves_on_resupply_and_on_death() -> void:
	var pair := _setup()
	var feed: EntitySpriteFeed = pair[1]
	var u := _unit(1, UnitTypes.TANK, Ammo.max_ammo(UnitTypes.TANK))
	feed.sync([u] as Array[EntityState])
	u.ammo_spent = 0
	feed.sync([u] as Array[EntityState])
	assert_object(feed.ammo_badge(1)).is_null()
	u.ammo_spent = Ammo.max_ammo(UnitTypes.TANK)
	feed.sync([u] as Array[EntityState])
	feed.sync([] as Array[EntityState])
	assert_object(feed.ammo_badge(1)).is_null()
