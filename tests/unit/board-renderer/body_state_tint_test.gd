# Story 010 / S5-07 finding: EntityGlow.body_tint_for — the body multiply that
# carries the actor-state read.
#
# The glow alone could not carry it. The S5-07 windowed pass measured AP-available
# against AP-spent at 12.5/255 on the neon trim at the BEST moment in the breathe
# cycle and 3.3/255 at the worst, across 0.67% of the frame — because the emission
# shader only ever ADDS light, and ceasing to emit cannot dim a sprite whose base art
# is already brightly painted. See production/qa/evidence/s5-07-windowed/README.md.
#
# The assertions that matter here are the PALETTE FLOOR ones. It is easy to "improve"
# the state read by darkening further, and doing so re-creates the exact defect the
# S4-02 art pass already had to fix once: units sinking into the terrain and failing
# art bible §1's identifiable-by-outline-alone test.
#
# No RNG, no time-dependent asserts, no file I/O.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

# Art-bible §4 locked values, restated so this suite fails loudly if the palette moves
# under it rather than silently validating against a stale floor.
const UNIT_ARMOUR: Color = Color("6E7C99")
const TERRAIN_BASE: Color = Color("232A38")
const MAX_ELEVATION_TILE: Color = Color("33405A")   # the worst case: brightest stage tile

# The margin below which a unit stops reading as a distinct shape against the stage.
const MIN_SILHOUETTE_MARGIN: float = 20.0


func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


# --- The three states are distinct -------------------------------------------

func test_the_three_states_map_to_three_different_tints() -> void:
	var live: float = EntityGlow.body_tint_for(false, true)
	var spent: float = EntityGlow.body_tint_for(false, false)
	var destroyed: float = EntityGlow.body_tint_for(true, false)
	assert_float(live).is_greater(spent)
	assert_float(spent).is_greater(destroyed)


func test_a_live_actor_is_drawn_as_authored() -> void:
	# Anything less would dim the whole board permanently.
	assert_float(EntityGlow.body_tint_for(false, true)).is_equal(1.0)
	assert_float(EntityGlow.LIVE_BODY_TINT).is_equal(1.0)


func test_death_outranks_actionability() -> void:
	# Mirrors mode_for's precedence: a destroyed actor whose owner still had AP is
	# still destroyed.
	assert_float(EntityGlow.body_tint_for(true, true)) \
		.is_equal(EntityGlow.DESTROYED_BODY_TINT)
	assert_float(EntityGlow.body_tint_for(true, false)) \
		.is_equal(EntityGlow.DESTROYED_BODY_TINT)


# --- ★ The palette floor — the constraint that bounds the fix ----------------

func test_a_spent_unit_still_reads_against_the_brightest_stage_tile() -> void:
	# §3.5/P3: units are deliberately LIGHTER than the stage. Darkening past the
	# floor collapses that margin and the unit sinks into the terrain — the exact
	# "units vanish into the board" defect S4-02 had to fix. This is the assertion
	# that stops a future retune from re-introducing it.
	var dimmed: float = _luma(UNIT_ARMOUR) * EntityGlow.SPENT_BODY_TINT
	var margin: float = dimmed - _luma(MAX_ELEVATION_TILE)
	assert_float(margin).is_greater(MIN_SILHOUETTE_MARGIN)


func test_a_spent_unit_stays_well_clear_of_the_terrain_base() -> void:
	var dimmed: float = _luma(UNIT_ARMOUR) * EntityGlow.SPENT_BODY_TINT
	assert_float(dimmed - _luma(TERRAIN_BASE)).is_greater(30.0)


func test_the_spent_tint_is_a_real_change_not_a_token_one() -> void:
	# The whole point of the story: the state must be visible. A tint above ~0.9
	# would reproduce the 12.5/255 problem the windowed pass measured.
	var delta: float = _luma(UNIT_ARMOUR) * (1.0 - EntityGlow.SPENT_BODY_TINT)
	assert_float(delta).is_greater(25.0)


func test_destroyed_may_go_darker_than_spent() -> void:
	# A destroyed actor is leaving the board, so nothing downstream needs to pick its
	# silhouette out of the terrain — it is not bound by the floor above.
	assert_float(EntityGlow.DESTROYED_BODY_TINT).is_less(EntityGlow.SPENT_BODY_TINT)
	assert_float(EntityGlow.DESTROYED_BODY_TINT).is_greater(0.0)


func test_no_tint_is_ever_zero() -> void:
	# Zero would be a black silhouette, which reads as a hole in the board rather
	# than as an actor in any state.
	for t: float in [EntityGlow.LIVE_BODY_TINT, EntityGlow.SPENT_BODY_TINT,
			EntityGlow.DESTROYED_BODY_TINT]:
		assert_float(t).is_greater(0.0)
		assert_float(t).is_less_equal(1.0)
