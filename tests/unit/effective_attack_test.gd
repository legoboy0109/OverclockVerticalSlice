# Story 004: effective_attack — Live Research-Tech Fold.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-004-effective-attack.md:
#   AC-1: un-researched owner -> base attack (per roster type).
#   AC-2: researched owner -> base + Research-config-sourced bonus (not hardcoded).
#   AC-3: live fold — flipping the owner's Attack-Tech flag on an already-built
#         instance changes a later effective_attack() call (not baked at build).
#
# The Attack-Tech bonus MAGNITUDE is read at call time from the forward-declared
# Research.attack_tech_bonus() (the test stub — tests/helpers/stubs/research_stub.gd);
# tests inject it via Research.set_attack_tech_bonus() and never assert a hardcoded +1.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func before_test() -> void:
	Research.reset() # clears the injected attack-tech bonus (isolation rule)


# Builds a 2-player state and a player-0-owned unit of the given type, with
# the owner's has_attack_tech flag set as requested.
func _make_state_and_unit(type: UnitTypeDef, has_attack_tech: bool) -> Array:
	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].has_attack_tech = has_attack_tech
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.position = Vector2i(0, 0)
	unit.type = type
	unit.current_hp = type.hp
	return [state, unit]


# --- AC-1: un-researched owner -> base attack -------------------------------

func test_unresearched_owner_effective_attack_is_base_for_all_four_types() -> void:
	# Arrange — inject a nonzero bonus to prove it is NOT added when the flag is false.
	Research.set_attack_tech_bonus(5)
	for entry: Array in [
		[UnitTypes.SCOUT, 2], [UnitTypes.TROOPER, 3],
		[UnitTypes.HEAVY, 5], [UnitTypes.SNIPER, 6],
	]:
		var pair := _make_state_and_unit(entry[0], false)
		# Act / Assert — base only, no bonus (flag false).
		assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(entry[1])


# --- AC-2: researched owner -> base + config-sourced bonus ------------------

func test_researched_owner_effective_attack_is_base_plus_injected_bonus() -> void:
	# Arrange
	Research.set_attack_tech_bonus(1)
	var pair := _make_state_and_unit(UnitTypes.TROOPER, true)
	# Act / Assert — base 3 + injected 1 = 4.
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(4)


# The bonus must TRACK the Research-config value, not a hardcoded +1 — re-run
# with a different injected magnitude and the output must follow it.
func test_researched_effective_attack_tracks_injected_bonus_not_hardcoded() -> void:
	# Arrange
	Research.set_attack_tech_bonus(3)
	var pair := _make_state_and_unit(UnitTypes.SNIPER, true)
	# Act / Assert — base 6 + injected 3 = 9 (would be 7 if +1 were hardcoded).
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(9)


# --- AC-3: live fold — flag flip on an existing instance changes the result --

func test_flag_flip_on_existing_unit_changes_later_effective_attack_live() -> void:
	# Arrange — a Scout built while the owner has no Attack Tech.
	Research.set_attack_tech_bonus(1)
	var pair := _make_state_and_unit(UnitTypes.SCOUT, false)
	var state: GameState = pair[0]
	var unit: UnitState = pair[1]
	# Act 1 — recorded at base while un-researched.
	assert_int(Unit.effective_attack(state, unit)).is_equal(2)

	# The owner researches Attack Tech mid-match (same unit instance, no rebuild).
	# (No revert test exists: Research tech-unlock flags are permanent — ADR-0018.)
	state.per_player[0].has_attack_tech = true

	# Act 2 — the SAME instance now reflects the fold live (2 + 1 = 3).
	assert_int(Unit.effective_attack(state, unit)).is_equal(3)
