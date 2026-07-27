# Framework smoke test — proves the GdUnit4 harness is installed and runs green.
#
# Intentionally implementation-free: no src/ system exists yet (all 18 ADRs are
# still Proposed). This validates the test pipeline itself and demonstrates the
# project's arrange/act/assert + determinism conventions for future suites.
# Replace/expand once the first real system lands.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# A tiny pure, deterministic helper standing in for the integer-only formula style
# ADR-0003 mandates (state math is integer; no floats in state, no unseeded RNG).
static func _clamped_damage(attack: int, defense: int) -> int:
	return maxi(0, attack - defense)


func test_framework_core_assertions_are_wired() -> void:
	# Arrange / Act / Assert — confirms GdUnit4 core assertions resolve at all.
	assert_int(2 + 2).is_equal(4)
	assert_bool(true).is_true()
	assert_str("OVERCLOCK").is_equal("OVERCLOCK")


func test_clamped_damage_positive_difference_returns_difference() -> void:
	# Arrange
	var attack := 7
	var defense := 3
	# Act
	var dealt := _clamped_damage(attack, defense)
	# Assert
	assert_int(dealt).is_equal(4)


func test_clamped_damage_defense_exceeds_attack_floors_at_zero() -> void:
	# Arrange
	var attack := 2
	var defense := 5
	# Act
	var dealt := _clamped_damage(attack, defense)
	# Assert — never negative (integer floor); deterministic across runs.
	assert_int(dealt).is_equal(0)
