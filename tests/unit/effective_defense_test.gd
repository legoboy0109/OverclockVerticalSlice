# Story 005: effective_defense + Two-Bonus Independence Proof.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-005-effective-defense-flag-independence.md:
#   AC-1: base_defense is 0 (the un-researched branch input) for all VS types.
#   AC-2: un-researched -> base(0); researched -> base + Research-config bonus.
#   AC-3: INDEPENDENCE, both directions — an Attack-bonus tech never bonuses
#         defense and a Defense-bonus tech never bonuses attack (the core
#         regression guard).
#   AC-4: both an attack tech and a defense tech granted -> both bonuses apply,
#         neither suppresses the other.
#   AC-5: live fold — granting a defense tech after an existing instance
#         exists changes a later effective_defense() call.
#
# Bonus magnitudes are read live from Research.attack_bonus/defense_bonus
# (CR-14, 2026-09-28: summed TechDef.attack_bonus/defense_bonus fields over
# the owner's completed_techs); tests inject distinct values via
# GameStateFactory.grant_tech(state, player, GameStateFactory.make_tech(atk, def))
# and never assert a hardcoded +1.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# Builds a 2-player state and a player-0-owned unit of the given type. If
# either bonus is nonzero, grants the owner a throwaway tech carrying those
# magnitudes (GameStateFactory.make_tech) — the CR-14 replacement for the old
# has_attack_tech/has_defense_tech flags.
func _make_state_and_unit(type: UnitTypeDef, attack_bonus: int = 0, defense_bonus: int = 0) -> Array:
	var state := GameStateFactory.make_state(2, 0)
	if attack_bonus != 0 or defense_bonus != 0:
		GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(attack_bonus, defense_bonus))
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.position = Vector2i(0, 0)
	unit.type = type
	unit.current_hp = type.hp
	return [state, unit]


# --- AC-1: base_defense is 0 for the whole VS roster ------------------------

func test_base_defense_is_zero_for_all_four_types() -> void:
	assert_int(UnitTypes.SCOUT.defense).is_equal(0)
	assert_int(UnitTypes.TROOPER.defense).is_equal(0)
	assert_int(UnitTypes.HEAVY.defense).is_equal(0)
	assert_int(UnitTypes.SNIPER.defense).is_equal(0)


# --- AC-2: un-researched -> 0; researched -> base + granted bonus -----------

func test_unresearched_owner_effective_defense_is_zero() -> void:
	# Arrange/Act/Assert — no tech granted; base 0, no bonus.
	var pair := _make_state_and_unit(UnitTypes.HEAVY)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(0)


func test_researched_owner_effective_defense_is_base_plus_granted_bonus() -> void:
	# Arrange
	var pair := _make_state_and_unit(UnitTypes.HEAVY, 0, 2)
	# Act / Assert — base 0 + granted 2 = 2.
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(2)


func test_researched_effective_defense_tracks_granted_bonus_not_hardcoded() -> void:
	# Arrange — a different magnitude proves the value is read, not hardcoded.
	var pair := _make_state_and_unit(UnitTypes.SCOUT, 0, 3)
	# Act / Assert — base 0 + granted 3 = 3 (would be 1 if +1 were hardcoded).
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(3)


# --- AC-3: independence (both directions) — the core regression guard -------

# An attack-only tech bonuses attack, defense stays base — proves
# Research.defense_bonus reads TechDef.defense_bonus, not attack_bonus.
func test_attack_only_tech_bonuses_attack_not_defense() -> void:
	# Arrange — attack_bonus=2, defense_bonus=0 on the one granted tech.
	var pair := _make_state_and_unit(UnitTypes.TROOPER, 2, 0)
	# Act / Assert — attack 3 + 2 = 5; defense 0 (NOT 2).
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(5)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(0)


# A defense-only tech (reversed): defense is bonused, attack stays base —
# proves Research.attack_bonus reads TechDef.attack_bonus, not defense_bonus.
func test_defense_only_tech_bonuses_defense_not_attack() -> void:
	# Arrange — attack_bonus=0, defense_bonus=3 on the one granted tech.
	var pair := _make_state_and_unit(UnitTypes.TROOPER, 0, 3)
	# Act / Assert — attack 3 (NOT 6); defense 0 + 3 = 3.
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(3)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(3)


# --- AC-4: two independent techs -> both bonuses apply simultaneously -------

func test_two_granted_techs_apply_both_bonuses_neither_suppresses_the_other() -> void:
	# Arrange — two SEPARATE techs, one per axis, proving Research.attack_bonus/
	# defense_bonus correctly SUM over completed_techs rather than reading a
	# single slot.
	var state := GameStateFactory.make_state(2, 0)
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(2, 0))
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(0, 3))
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.position = Vector2i(0, 0)
	unit.type = UnitTypes.TROOPER
	unit.current_hp = UnitTypes.TROOPER.hp
	# Act / Assert — attack 3 + 2 = 5; defense 0 + 3 = 3.
	assert_int(Unit.effective_attack(state, unit)).is_equal(5)
	assert_int(Unit.effective_defense(state, unit)).is_equal(3)


# --- AC-5: live fold — a defense tech granted after an existing instance ----

func test_defense_tech_granted_after_unit_built_changes_later_effective_defense_live() -> void:
	# Arrange — a Heavy built while its owner has completed no tech.
	var pair := _make_state_and_unit(UnitTypes.HEAVY)
	var state: GameState = pair[0]
	var unit: UnitState = pair[1]
	# Act 1 — base while un-researched.
	assert_int(Unit.effective_defense(state, unit)).is_equal(0)

	# The owner completes a Defense tech mid-match (same instance, no rebuild).
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(0, 2))

	# Act 2 — the SAME instance now reflects the fold live (0 + 2 = 2).
	assert_int(Unit.effective_defense(state, unit)).is_equal(2)
