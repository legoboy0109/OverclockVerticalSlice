# Story 004: effective_attack — Live Research-Tech Fold.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-004-effective-attack.md:
#   AC-1: un-researched owner -> base attack (per roster type).
#   AC-2: researched owner -> base + Research-config-sourced bonus (not hardcoded).
#   AC-3: live fold — a tech completing after an already-built instance exists
#         changes a later effective_attack() call (not baked at build).
#
# The Attack-Tech bonus MAGNITUDE is read at call time from
# Research.attack_bonus (CR-14, 2026-09-28: sums TechDef.attack_bonus over the
# owner's completed_techs); tests inject it via
# GameStateFactory.grant_tech(state, player, GameStateFactory.make_tech(bonus))
# and never assert a hardcoded +1.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# Builds a 2-player state and a player-0-owned unit of the given type. If
# [param attack_bonus] is nonzero, grants the owner a throwaway tech carrying
# that attack_bonus (GameStateFactory.make_tech) — the CR-14 replacement for
# the old has_attack_tech flag.
func _make_state_and_unit(type: UnitTypeDef, attack_bonus: int = 0) -> Array:
	var state := GameStateFactory.make_state(2, 0)
	if attack_bonus != 0:
		GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(attack_bonus))
	var unit := UnitState.new()
	unit.entity_id = 1
	unit.owner = 0
	unit.position = Vector2i(0, 0)
	unit.type = type
	unit.current_hp = type.hp
	return [state, unit]


# --- AC-1: un-researched owner -> base attack -------------------------------

func test_unresearched_owner_effective_attack_is_base_for_all_four_types() -> void:
	# Arrange/Act/Assert — no tech granted, so no bonus can apply regardless of
	# type; base attack only.
	for entry: Array in [
		[UnitTypes.SCOUT, 2], [UnitTypes.TROOPER, 3],
		[UnitTypes.HEAVY, 5], [UnitTypes.SNIPER, 6],
	]:
		var pair := _make_state_and_unit(entry[0])
		assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(entry[1])


# --- AC-2: researched owner -> base + config-sourced bonus ------------------

func test_researched_owner_effective_attack_is_base_plus_granted_bonus() -> void:
	# Arrange
	var pair := _make_state_and_unit(UnitTypes.TROOPER, 1)
	# Act / Assert — base 3 + granted 1 = 4.
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(4)


# The bonus must TRACK the granted tech's own value, not a hardcoded +1 — re-run
# with a different magnitude and the output must follow it.
func test_researched_effective_attack_tracks_granted_bonus_not_hardcoded() -> void:
	# Arrange
	var pair := _make_state_and_unit(UnitTypes.SNIPER, 3)
	# Act / Assert — base 6 + granted 3 = 9 (would be 7 if +1 were hardcoded).
	assert_int(Unit.effective_attack(pair[0], pair[1])).is_equal(9)


# --- AC-3: live fold — a tech completing after the unit exists changes the result --

func test_tech_completing_after_unit_built_changes_later_effective_attack_live() -> void:
	# Arrange — a Scout built while the owner has completed no tech.
	var pair := _make_state_and_unit(UnitTypes.SCOUT)
	var state: GameState = pair[0]
	var unit: UnitState = pair[1]
	# Act 1 — recorded at base while un-researched.
	assert_int(Unit.effective_attack(state, unit)).is_equal(2)

	# The owner completes an Attack tech mid-match (same unit instance, no rebuild).
	GameStateFactory.grant_tech(state, 0, GameStateFactory.make_tech(1))

	# Act 2 — the SAME instance now reflects the fold live (2 + 1 = 3).
	assert_int(Unit.effective_attack(state, unit)).is_equal(3)
