# Story 007: Faction Identity Read-Sites -- effective_produce_cost /
# effective_move_cost.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-007-faction-read-sites.md
# (TR-unit-011 -- Faction hooks: effective_produce_cost/effective_move_cost
# fold deltas, floored MIN_MOVE_COST; combat stats faction-locked; no-op
# under Neutral):
#
#   AC-1 (Neutral no-op): under Factions.NEUTRAL, effective_produce_cost/
#     effective_move_cost equal base exactly for all 4 VS unit types --
#     parametrized across the roster, both domains (8 assertions total).
#   AC-2 (delta fold + floor): a test-only FactionDef with a FactionUnitDelta
#     folds into both domains -- base+delta when positive (no ceiling),
#     max(1, ...)/max(MIN_MOVE_COST, ...) when a large negative delta would
#     otherwise drive the value at/below 0.
#   AC-3 (combat stats locked): effective_attack/effective_defense/
#     attack_range are unaffected by a faction that carries unit_deltas --
#     guards that no refactor routes combat stats through this story's
#     cost/mobility functions.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- AC-1: Neutral no-op, parametrized across the full roster ---------------

func test_effective_produce_cost_under_neutral_equals_base_for_all_types() -> void:
	# Arrange -- a genuine registry read: GameStateFactory-built state whose
	# acting player's faction is Factions.NEUTRAL (not a fresh FactionDef.new()).
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].faction = Factions.NEUTRAL

	var types: Array[UnitTypeDef] = [
		UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.HEAVY, UnitTypes.SNIPER,
	]

	# Act / Assert
	for t: UnitTypeDef in types:
		assert_int(Unit.effective_produce_cost(state, t, 0)).override_failure_message(
			"effective_produce_cost for '%s' under Neutral must equal base produce_cost exactly (ADR-0012 §5 no-op)." % t.display_name
		).is_equal(t.produce_cost)


func test_effective_move_cost_under_neutral_equals_base_for_all_types() -> void:
	# Arrange
	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].faction = Factions.NEUTRAL

	var types: Array[UnitTypeDef] = [
		UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.HEAVY, UnitTypes.SNIPER,
	]

	# Act / Assert
	for t: UnitTypeDef in types:
		assert_int(Unit.effective_move_cost(state, t, 0)).override_failure_message(
			"effective_move_cost for '%s' under Neutral must equal base move_cost exactly (ADR-0012 §5 no-op)." % t.display_name
		).is_equal(t.move_cost)


# --- AC-2: delta fold + floor, both domains, both directions ----------------

# Builds a test-only FactionDef carrying a single FactionUnitDelta for
# UnitTypes.TROOPER with the given cost/move deltas, and a 1-player GameState
# whose player 0 is assigned that faction.
func _make_state_with_delta(cost_delta: int, move_cost_delta: int) -> GameState:
	var delta := FactionUnitDelta.new()
	delta.type = UnitTypes.TROOPER
	delta.cost_delta = cost_delta
	delta.move_cost_delta = move_cost_delta

	var faction := FactionDef.new()
	faction.unit_deltas = [delta]

	var state := GameStateFactory.make_state(1, 0)
	state.per_player[0].faction = faction
	return state


func test_effective_produce_cost_folds_positive_delta() -> void:
	# Arrange -- +3 cost_delta, no ceiling.
	var state := _make_state_with_delta(3, 0)

	# Act
	var result := Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)

	# Assert
	assert_int(result).is_equal(UnitTypes.TROOPER.produce_cost + 3)


func test_effective_produce_cost_floors_at_one_with_large_negative_delta() -> void:
	# Arrange -- a -10 cost_delta on Trooper (base produce_cost well below 10)
	# must never drive effective_produce_cost to <=0.
	var state := _make_state_with_delta(-10, 0)

	# Act
	var result := Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)

	# Assert
	assert_int(result).override_failure_message(
		"effective_produce_cost must floor at 1, never <=0, even with a large negative delta."
	).is_equal(maxi(1, UnitTypes.TROOPER.produce_cost - 10))
	assert_int(result).is_equal(1)


func test_effective_move_cost_folds_positive_delta() -> void:
	# Arrange -- +3 move_cost_delta, no ceiling.
	var state := _make_state_with_delta(0, 3)

	# Act
	var result := Unit.effective_move_cost(state, UnitTypes.TROOPER, 0)

	# Assert
	assert_int(result).is_equal(UnitTypes.TROOPER.move_cost + 3)


func test_effective_move_cost_floors_at_min_move_cost_with_large_negative_delta() -> void:
	# Arrange -- a -10 move_cost_delta must never drive effective_move_cost
	# below Unit.MIN_MOVE_COST.
	var state := _make_state_with_delta(0, -10)

	# Act
	var result := Unit.effective_move_cost(state, UnitTypes.TROOPER, 0)

	# Assert
	assert_int(result).override_failure_message(
		"effective_move_cost must floor at Unit.MIN_MOVE_COST, never below it, even with a large negative delta."
	).is_equal(maxi(Unit.MIN_MOVE_COST, UnitTypes.TROOPER.move_cost - 10))
	assert_int(result).is_equal(Unit.MIN_MOVE_COST)


# --- AC-2 robustness: per-player isolation + non-matching-type miss path -----

func test_effective_produce_cost_reads_only_the_named_players_faction() -> void:
	# Arrange -- a 2-player state: player 0 carries a +3 cost delta on TROOPER,
	# player 1 stays Neutral. This is exactly the off-by-one / shared-reference
	# bug the explicit `player` argument exists to prevent (control-manifest:
	# "every effective_X takes player as an explicit argument").
	var delta := FactionUnitDelta.new()
	delta.type = UnitTypes.TROOPER
	delta.cost_delta = 3

	var faction := FactionDef.new()
	faction.unit_deltas = [delta]

	var state := GameStateFactory.make_state(2, 0)
	state.per_player[0].faction = faction
	state.per_player[1].faction = Factions.NEUTRAL

	# Act / Assert -- player 0 sees the delta; player 1 (Neutral) must NOT.
	assert_int(Unit.effective_produce_cost(state, UnitTypes.TROOPER, 0)).override_failure_message(
		"player 0's faction delta must apply to player 0's read."
	).is_equal(UnitTypes.TROOPER.produce_cost + 3)
	assert_int(Unit.effective_produce_cost(state, UnitTypes.TROOPER, 1)).override_failure_message(
		"player 0's faction delta must NOT leak into player 1's read (per-player isolation)."
	).is_equal(UnitTypes.TROOPER.produce_cost)


func test_effective_produce_cost_ignores_delta_for_non_matching_type() -> void:
	# Arrange -- a NON-EMPTY unit_deltas array carrying a delta for TROOPER only.
	# Querying a DIFFERENT type (SCOUT) must take Faction.unit_delta's loop-miss
	# branch and return base exactly. Neutral's AC-1 test only covers the
	# empty-array path; this covers the "present but no match" path -- a
	# regression degrading `d.type == type` to always-true would be caught here.
	var state := _make_state_with_delta(3, 3)  # delta targets TROOPER

	# Act -- query SCOUT, which has no entry in the array.
	var result := Unit.effective_produce_cost(state, UnitTypes.SCOUT, 0)

	# Assert -- miss path -> base, unmodified.
	assert_int(result).override_failure_message(
		"a delta targeting TROOPER must not fold into a SCOUT read (non-matching-type miss path)."
	).is_equal(UnitTypes.SCOUT.produce_cost)


# --- AC-3: combat stats remain faction-identity-locked -----------------------

func test_effective_attack_unaffected_by_faction_unit_deltas() -> void:
	# Arrange -- a faction with a cost/move delta present for the same unit
	# type combat is about to be read for. effective_attack must not route
	# through unit_deltas at all.
	var state := _make_state_with_delta(3, 3)
	var unit := UnitState.new()
	unit.owner = 0
	unit.type = UnitTypes.TROOPER
	unit.current_hp = UnitTypes.TROOPER.hp

	# Act
	var result := Unit.effective_attack(state, unit)

	# Assert -- unaffected: identical to the no-tech, no-faction base value.
	assert_int(result).is_equal(UnitTypes.TROOPER.attack)


func test_effective_defense_unaffected_by_faction_unit_deltas() -> void:
	# Arrange
	var state := _make_state_with_delta(3, 3)
	var unit := UnitState.new()
	unit.owner = 0
	unit.type = UnitTypes.TROOPER
	unit.current_hp = UnitTypes.TROOPER.hp

	# Act
	var result := Unit.effective_defense(state, unit)

	# Assert
	assert_int(result).is_equal(UnitTypes.TROOPER.defense)


func test_attack_range_has_no_faction_read_site_by_design() -> void:
	# Documentation-as-code, NOT a behavioral regression guard: unlike produce/
	# move cost, attack_range has no effective_X fold site (ADR-0012 CR-6 locks
	# combat identity; this story's FactionUnitDelta subset carries no combat
	# field). The real AC-3 weight is on the effective_attack/effective_defense
	# tests above, which DO call Unit.* through a delta-bearing faction and prove
	# no leak. This test pins the current design: attack_range is read straight
	# off the UnitTypeDef template, and FactionUnitDelta structurally cannot
	# carry a value that would perturb it (its only numeric fields are
	# cost_delta/move_cost_delta). If the Faction epic later adds combat_delta,
	# this becomes a real read-site and this note should graduate to a guard.
	var delta := FactionUnitDelta.new()
	delta.type = UnitTypes.TROOPER
	delta.cost_delta = 3
	delta.move_cost_delta = 3

	# The delta the faction carries for TROOPER exposes no attack_range lever --
	# the base template's attack_range is the only source of truth for it.
	assert_int(UnitTypes.TROOPER.attack_range).override_failure_message(
		"attack_range must be sourced only from the UnitTypeDef template; no faction fold site exists for it in this story's schema."
	).is_greater_equal(1)
