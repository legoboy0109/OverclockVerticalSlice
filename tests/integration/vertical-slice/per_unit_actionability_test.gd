# Per-unit actionability (user decision 2026-08-21) — the Pillar-1 "can this actor
# still act?" predicate that drives both the glow state and Story 010's body tint.
#
# Replaces the army-wide "does this player have any AP" read that art bible §8.5/§2.6
# specified literally, which dimmed a whole army in one step. The change only became
# consequential once Story 010 made the state read actually visible (12.5/255 -> 24.4).
#
# ★ Why the predicate is AFFORDABILITY and not "has this unit acted": the obvious
# XCOM-style read has no equivalent in this game. Attacking sets has_attacked, but the
# move cap is SOFT — a unit that has moved or attacked can always move again at a
# surcharge — so there is no point at which a unit is finished. "Can still act" has to
# mean "the owner can still pay for its cheapest remaining option", which IS per-unit
# because move_cost varies across the roster (Scout 1, Trooper/Sniper 2, Heavy 3).
#
# Covers:
#   * the roster genuinely splits at low AP — the whole point of the change
#   * an empty pool dims everything, whatever it is
#   * has_attacked narrows a unit's options but does NOT finish it (soft cap)
#   * a unit that has attacked AND cannot afford to move is finally dark
#   * structures that cannot shoot never dim; ones that can follow their own attack
#
# Integration-type: exercises VerticalSliceRoot's real wiring, not a stub.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const LOCAL: int = 0


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(VerticalSliceRoot.new())
	add_child(root) # _ready() builds the whole slice.
	return root


func _unit(owner: int, type: UnitTypeDef, attacked: bool = false) -> UnitState:
	var u := UnitState.new()
	u.entity_id = 900
	u.owner = owner
	u.position = Vector2i(1, 1)
	u.type = type
	u.current_hp = type.hp
	u.has_attacked = attacked
	return u


# Drives the real predicate the slice installed on the feed.
func _actionable(root: VerticalSliceRoot, state: GameState, ap: int, entity: EntityState) -> bool:
	state.per_player[entity.owner].current_ap = ap
	return root._is_entity_actionable(entity)


# --- ★ The whole point: the roster splits at low AP --------------------------

func test_low_ap_dims_expensive_units_while_cheap_ones_stay_lit() -> void:
	# This is the read the change exists to produce: at 2 AP a player can still MOVE
	# a Scout, Trooper or Sniper but not a Heavy (move_cost 3), and the board says so.
	#
	# ★ Note these units have already attacked. That is not incidental — see
	# test_fresh_units_do_not_split_until_1_ap for why move_cost differentiation only
	# appears once the attack option is off the table.
	var root := _make_root()
	var state: GameState = root.state()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.SCOUT, true))).is_true()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.TROOPER, true))).is_true()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.SNIPER, true))).is_true()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.HEAVY, true))).is_false()


func test_fresh_units_do_not_split_until_1_ap() -> void:
	# ★ A real characteristic of this predicate, asserted so it is a known property
	# rather than a surprise. attack_cost is a flat 2 for every unit, so for a unit
	# that has NOT attacked the cheapest option is min(move_cost, 2) — which is 2 or
	# less for the entire roster. At 2 AP every fresh unit can therefore still do
	# SOMETHING (the Heavy cannot move, but it can shoot) and the board correctly
	# shows them all lit. Differentiation by move_cost only appears once a unit has
	# spent its attack, or once the pool drops to 1.
	var root := _make_root()
	var state: GameState = root.state()
	for type: UnitTypeDef in [UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.SNIPER, UnitTypes.HEAVY]:
		assert_bool(_actionable(root, state, 2, _unit(LOCAL, type))).is_true()


func test_one_ap_leaves_only_the_cheapest_unit_lit() -> void:
	var root := _make_root()
	var state: GameState = root.state()
	assert_bool(_actionable(root, state, 1, _unit(LOCAL, UnitTypes.SCOUT))).is_true()
	for type: UnitTypeDef in [UnitTypes.TROOPER, UnitTypes.SNIPER, UnitTypes.HEAVY]:
		assert_bool(_actionable(root, state, 1, _unit(LOCAL, type))).is_false()


func test_an_empty_pool_dims_everything() -> void:
	var root := _make_root()
	var state: GameState = root.state()
	for type: UnitTypeDef in [UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.HEAVY, UnitTypes.SNIPER]:
		assert_bool(_actionable(root, state, 0, _unit(LOCAL, type))).is_false()


# --- has_attacked narrows options but does not finish a unit -----------------

func test_a_unit_that_attacked_is_still_lit_while_it_can_afford_to_move() -> void:
	# The soft cap is why: attacking does not end a unit's turn, so it must not go
	# dark while it can still legally move. Scout move_cost 1 against 1 AP.
	var root := _make_root()
	var state: GameState = root.state()
	assert_bool(_actionable(root, state, 1, _unit(LOCAL, UnitTypes.SCOUT, true))).is_true()


func test_a_unit_that_attacked_and_cannot_afford_to_move_is_dark() -> void:
	# Heavy: attack is off the table (already used), move costs 3, pool has 2.
	var root := _make_root()
	var state: GameState = root.state()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.HEAVY, true))).is_false()


func test_attacking_only_matters_when_the_attack_was_the_cheaper_option() -> void:
	# Heavy at 2 AP: cannot move (3) but could attack (2) — so it is lit until it
	# has attacked, then dark. This is the case where has_attacked changes the answer.
	var root := _make_root()
	var state: GameState = root.state()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.HEAVY, false))).is_true()
	assert_bool(_actionable(root, state, 2, _unit(LOCAL, UnitTypes.HEAVY, true))).is_false()


# --- Structures ---------------------------------------------------------------

func test_a_structure_that_cannot_shoot_never_dims() -> void:
	# A fixture, not an actor with a turn allowance — dimming it would say nothing,
	# and it is what made the old army-wide read darken the whole board.
	var root := _make_root()
	var state: GameState = root.state()
	var hq := StructureState.new()
	hq.entity_id = 901
	hq.owner = LOCAL
	hq.position = Vector2i(0, 0)
	hq.type = StructureTypes.HQ
	hq.current_hp = StructureTypes.HQ.hp
	assert_int(hq.type.attack).is_equal(0) # guards the premise of this test
	assert_bool(_actionable(root, state, 0, hq)).is_true()


func test_a_shooting_structure_dims_once_it_has_fired() -> void:
	var root := _make_root()
	var state: GameState = root.state()
	var turret := StructureState.new()
	turret.entity_id = 902
	turret.owner = LOCAL
	turret.position = Vector2i(0, 0)
	turret.type = StructureTypeDef.new()
	turret.type.hp = 10
	turret.type.attack = 4
	turret.type.attack_range = 2
	turret.current_hp = 10
	assert_bool(_actionable(root, state, 5, turret)).is_true()
	turret.has_attacked = true
	assert_bool(_actionable(root, state, 5, turret)).is_false()
