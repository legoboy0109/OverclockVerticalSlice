# AI cover awareness (S7-11).
#
# ★ Context worth carrying: before S7-11 the AI had NO terrain awareness at all — `ai.gd`
# never called `is_cover`, and no map placed a cover tile anyway, so the game's whole
# positional dimension was built and switched off.
#
# Two halves, and only one of them needed new code:
#   - ATTACK scoring already accounted for cover, and always had, because `_consider_attack`
#     values a target through `Combat.preview_damage`, which applies `cover_dr`. A defender
#     in cover has always scored lower as a target.
#   - MOVE scoring did not. That is what `cover_value` adds.
extends GdUnitTestSuite


func test_positional_value_adds_the_cover_bonus_for_a_cover_destination() -> void:
	# Arrange — one tile closed, no setup bonus, so the only difference is the terrain.
	var open_tile: float = AI._positional_value(4, 3, false, false)
	# Act
	var cover_tile: float = AI._positional_value(4, 3, false, true)
	# Assert
	assert_float(cover_tile - open_tile).is_equal_approx(AIBalance.ai.cover_value, 1e-6)


func test_positional_value_is_unchanged_when_the_destination_is_open() -> void:
	# The pre-S7-11 contract (AC-20's worked example) must still hold exactly — the cover
	# term is additive and must not perturb the open-ground arithmetic.
	assert_float(AI._positional_value(4, 3, false, false)).is_equal_approx(
		AIBalance.ai.positional_value_per_tile_closed, 1e-6)


func test_cover_and_setup_bonuses_both_apply_and_do_not_replace_each_other() -> void:
	var both: float = AI._positional_value(4, 3, true, true)
	var expected: float = AIBalance.ai.positional_value_per_tile_closed \
		+ AIBalance.ai.setup_advance_bonus + AIBalance.ai.cover_value
	assert_float(both).is_equal_approx(expected, 1e-6)


func test_retreat_value_prefers_breaking_contact_into_cover() -> void:
	# ★ This is where cover matters most for a losing player: a wounded unit fleeing should
	# rather end up behind something than in the open at the same distance.
	var into_open: float = AI._retreat_value(1, 3, false)
	var into_cover: float = AI._retreat_value(1, 3, true)
	assert_float(into_cover).is_greater(into_open)
	assert_float(into_cover - into_open).is_equal_approx(AIBalance.ai.cover_value, 1e-6)


func test_retreat_value_is_unchanged_on_open_ground() -> void:
	assert_float(AI._retreat_value(1, 3, false)).is_equal_approx(
		AIBalance.ai.retreat_value_per_tile_fled * 2.0, 1e-6)


func test_cover_value_is_sized_between_a_tile_of_progress_and_a_setup() -> void:
	# ★ Not arbitrary. cover_dr is a flat -1 damage, which against the roster's commonest
	# attack (Trooper, 3) turns a 2-hit kill into a 3-hit kill — worth more than closing one
	# tile and less than enabling a next-turn attack. Pinned so a retune has to be deliberate.
	assert_float(AIBalance.ai.cover_value).is_greater(AIBalance.ai.positional_value_per_tile_closed)
	assert_float(AIBalance.ai.cover_value).is_less(AIBalance.ai.setup_advance_bonus)


func test_cover_value_stays_under_the_lethal_floor() -> void:
	# ★ ADR-0011's standing invariant: no positional term may rival a lethal action, or the
	# AI stops finishing units off. Every other positional bonus is checked against this.
	assert_float(AIBalance.ai.cover_value).is_less(AIBalance.ai.lethal_floor_bonus)


func test_cover_tile_discount_is_zero_and_that_is_deliberate() -> void:
	# ★ MEASURED, not assumed. Letting a unit give up one tile of progress to reach cover
	# made cover usage WORSE (4.7 % of units in cover, versus 5.5 % for a cover-blind AI and
	# 6.1 % with the score term alone): a unit that steps back into cover is further away, so
	# next turn it advances and immediately leaves. Cover rewards a defender who stays put,
	# and this AI never stays put.
	# The knob is kept because it becomes correct the moment a hold-position behaviour exists.
	assert_int(AIBalance.ai.cover_tile_discount).override_failure_message(
		"cover_tile_discount is non-zero. That was measured as counterproductive in S7-11 — " +
		"re-read ai_config.gd's note before changing it, and re-measure cover occupancy."
	).is_equal(0)


func test_a_defender_in_cover_is_a_less_attractive_target() -> void:
	# The half that needed no new code. Proven here so nobody later "adds cover to the attack
	# scorer" and double-counts it.
	var state: GameState = GameState.start_match(VSMap.build(), 0)
	var cover_tile: Vector2i = VSMap.COVER_TILES[0]
	var open_tile := Vector2i(cover_tile.x, cover_tile.y + 1)
	# Guard the fixture's own assumption rather than trusting it.
	assert_bool(state.grid.is_cover(cover_tile.x, cover_tile.y)).is_true()
	assert_bool(state.grid.is_cover(open_tile.x, open_tile.y)).is_false()

	var attacker := UnitState.new()
	attacker.entity_id = 900
	attacker.owner = 0
	attacker.type = UnitTypes.TROOPER
	attacker.current_hp = UnitTypes.TROOPER.hp
	attacker.position = Vector2i(cover_tile.x, cover_tile.y - 1)

	var in_cover := UnitState.new()
	in_cover.entity_id = 901
	in_cover.owner = 1
	in_cover.type = UnitTypes.TROOPER
	in_cover.current_hp = UnitTypes.TROOPER.hp
	in_cover.position = cover_tile

	var in_open := UnitState.new()
	in_open.entity_id = 902
	in_open.owner = 1
	in_open.type = UnitTypes.TROOPER
	in_open.current_hp = UnitTypes.TROOPER.hp
	in_open.position = open_tile

	var dmg_cover: int = Combat.preview_damage(state, attacker, in_cover)
	var dmg_open: int = Combat.preview_damage(state, attacker, in_open)
	assert_int(dmg_cover).override_failure_message(
		"A unit standing in cover took as much damage as one in the open — cover_dr is not " +
		"reaching the damage formula, which would make the whole S7-11 change cosmetic."
	).is_less(dmg_open)
	assert_int(dmg_open - dmg_cover).is_equal(CombatBalance.combat.cover_dr)
