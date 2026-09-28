# Veteran rank on the board (promotion-veterancy.md PVOQ-3): 1–3 gold chevrons beside a promoted
# unit, nothing for a recruit, and the mark follows the unit and leaves with it.
extends GdUnitTestSuite

const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _setup() -> Array:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	return [renderer, feed]


func _unit(id: int, rank: int, tile: Vector2i = Vector2i(2, 2)) -> UnitState:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = 0
	u.position = tile
	u.type = UnitTypes.TROOPER
	u.current_hp = UnitTypes.TROOPER.hp
	u.rank = rank
	return u


func test_a_recruit_carries_no_badge() -> void:
	var pair := _setup()
	var feed: EntitySpriteFeed = pair[1]
	feed.sync([_unit(1, 0)] as Array[EntityState])
	assert_object(feed.rank_badge(1)).is_null()


func test_each_rank_draws_that_many_chevrons() -> void:
	# Taller per rank: the badge height grows by one chevron (+ gap) per rank.
	var h1: int = RankBadge.texture_for(1).get_height()
	var h2: int = RankBadge.texture_for(2).get_height()
	var h3: int = RankBadge.texture_for(3).get_height()
	assert_int(h2 - h1).is_equal(RankBadge.CHEVRON_H + RankBadge.GAP)
	assert_int(h3 - h2).is_equal(RankBadge.CHEVRON_H + RankBadge.GAP)
	assert_object(RankBadge.texture_for(0)).is_null()


func test_a_veteran_shows_a_badge_beside_its_sprite() -> void:
	var pair := _setup()
	var renderer: BoardRenderer = pair[0]
	var feed: EntitySpriteFeed = pair[1]
	var u := _unit(2, 2)
	feed.sync([u] as Array[EntityState])
	var badge: Sprite2D = feed.rank_badge(2)
	assert_object(badge).is_not_null()
	assert_object(badge.texture).is_same(RankBadge.texture_for(2))
	assert_object(badge.get_parent()).override_failure_message(
		"The badge must Y-sort with units, not sit under them.").is_same(renderer.occupant_layer)


func test_the_badge_updates_on_promotion_and_follows_a_move() -> void:
	var pair := _setup()
	var feed: EntitySpriteFeed = pair[1]
	var u := _unit(3, 1)
	feed.sync([u] as Array[EntityState])
	var before: Vector2 = feed.rank_badge(3).position
	u.rank = 3
	u.position = Vector2i(5, 5)
	feed.sync([u] as Array[EntityState])
	assert_object(feed.rank_badge(3).texture).is_same(RankBadge.texture_for(3))
	assert_bool(feed.rank_badge(3).position != before).is_true()


func test_losing_rank_or_dying_removes_the_badge() -> void:
	var pair := _setup()
	var feed: EntitySpriteFeed = pair[1]
	var u := _unit(4, 2)
	feed.sync([u] as Array[EntityState])
	u.rank = 0   # PV-7: rank lost without the Cathedral
	feed.sync([u] as Array[EntityState])
	assert_object(feed.rank_badge(4)).is_null()
	u.rank = 1
	feed.sync([u] as Array[EntityState])
	feed.sync([] as Array[EntityState])
	assert_object(feed.rank_badge(4)).is_null()
