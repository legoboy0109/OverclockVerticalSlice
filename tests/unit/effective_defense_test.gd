# Story 005: effective_defense + Two-Flag Independence Proof.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-005-effective-defense-flag-independence.md:
#   AC-1: base_defense is 0 (the un-researched branch input) for all VS types.
#   AC-2: un-researched -> base(0); researched -> base + Research-config bonus.
#   AC-3: flag INDEPENDENCE, both directions — Attack Tech never bonuses defense
#         and Defense Tech never bonuses attack (the core regression guard).
#   AC-4: both flags true -> both bonuses apply, neither suppresses the other.
#   AC-5: live fold — flipping the Defense-Tech flag on an existing instance
#         changes a later effective_defense() call.
#
# Bonus magnitudes are read live from the forward-declared Research stub
# (Research.attack_tech_bonus()/defense_tech_bonus()); tests inject distinct
# values and never assert a hardcoded +1.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	Research.reset() # clears both injected tech bonuses (isolation rule)


func _make_state_and_unit(type: UnitTypeDef, has_attack_tech: bool, has_defense_tech: bool) -> Array:
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].has_attack_tech = has_attack_tech
	state.per_player[0].has_defense_tech = has_defense_tech
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


# --- AC-2: un-researched -> 0; researched -> base + injected bonus -----------

func test_unresearched_owner_effective_defense_is_zero() -> void:
	# Arrange — inject a nonzero bonus to prove it is NOT added when the flag is false.
	Research.set_defense_tech_bonus(4)
	var pair := _make_state_and_unit(UnitTypes.HEAVY, false, false)
	# Act / Assert — base 0, no bonus.
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(0)


func test_researched_owner_effective_defense_is_base_plus_injected_bonus() -> void:
	# Arrange
	Research.set_defense_tech_bonus(2)
	var pair := _make_state_and_unit(UnitTypes.HEAVY, false, true)
	# Act / Assert — base 0 + injected 2 = 2.
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(2)


func test_researched_effective_defense_tracks_injected_bonus_not_hardcoded() -> void:
	# Arrange — a different magnitude proves the value is read, not hardcoded.
	Research.set_defense_tech_bonus(3)
	var pair := _make_state_and_unit(UnitTypes.SCOUT, false, true)
	# Act / Assert — base 0 + injected 3 = 3 (would be 1 if +1 were hardcoded).
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(3)


# --- AC-3: flag independence (both directions) — the core regression guard ---

# Attack Tech ONLY: attack is bonused, defense stays base — Attack Tech must not
# leak into the defense fold.
func test_attack_tech_only_bonuses_attack_not_defense() -> void:
	# Arrange — distinct magnitudes so any cross-contamination is unambiguous.
	Research.set_attack_tech_bonus(2)
	Research.set_defense_tech_bonus(3)
	var pair := _make_state_and_unit(UnitTypes.TROOPER, true, false)
	# Act / Assert — attack 3 + 2 = 5; defense 0 (NOT 3).
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(5)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(0)


# Defense Tech ONLY (reversed): defense is bonused, attack stays base — Defense
# Tech must not leak into the attack fold.
func test_defense_tech_only_bonuses_defense_not_attack() -> void:
	# Arrange
	Research.set_attack_tech_bonus(2)
	Research.set_defense_tech_bonus(3)
	var pair := _make_state_and_unit(UnitTypes.TROOPER, false, true)
	# Act / Assert — attack 3 (NOT 5); defense 0 + 3 = 3.
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(3)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(3)


# --- AC-4: both flags true -> both bonuses apply simultaneously --------------

func test_both_flags_true_apply_both_bonuses_neither_suppresses_the_other() -> void:
	# Arrange
	Research.set_attack_tech_bonus(2)
	Research.set_defense_tech_bonus(3)
	var pair := _make_state_and_unit(UnitTypes.TROOPER, true, true)
	# Act / Assert — attack 3 + 2 = 5; defense 0 + 3 = 3.
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(5)
	assert_int(Unit.effective_defense(pair[0], pair[1])).is_equal(3)


# --- AC-5: live fold — Defense-Tech flag flip on an existing instance --------

func test_defense_flag_flip_on_existing_unit_changes_later_effective_defense_live() -> void:
	# Arrange — a Heavy built while its owner has no Defense Tech.
	Research.set_defense_tech_bonus(2)
	var pair := _make_state_and_unit(UnitTypes.HEAVY, false, false)
	var state: GameState = pair[0]
	var unit: UnitState = pair[1]
	# Act 1 — base while un-researched.
	assert_int(Unit.effective_defense(state, unit)).is_equal(0)

	# The owner researches Defense Tech mid-match (same instance, no rebuild).
	# (No revert test: Research tech-unlock flags are permanent — ADR-0018.)
	state.per_player[0].has_defense_tech = true

	# Act 2 — the SAME instance now reflects the fold live (0 + 2 = 2).
	assert_int(Unit.effective_defense(state, unit)).is_equal(2)
