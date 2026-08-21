# Story 008 / sprint task S5-06: EntityTransforms — the §8.5 motion helpers.
#
# EntityTransforms is pure: constants plus two static functions with no engine or
# scene-tree dependency, so this is a unit suite. The tweens that consume it are
# covered by tests/integration/board-renderer/entity_death_echo_test.gd, and the
# way the motion actually LOOKS is Visual/Feel evidence (S5-07), not assertable
# headless.
#
# Covers:
#   * lean_angle: leans into travel, sign follows screen-x, and a move with no
#     horizontal component leans nowhere (the flicker guard).
#   * nudge: direction, magnitude, reversibility (the same call serves lunge and
#     recoil with the arguments swapped), and the coincident-points zero case.
#   * the value relationships §8.5 depends on: the recoil is smaller than the
#     lunge that caused it, and the lean stays small enough to survive repetition.
#
# No RNG, no time-dependent asserts, no file I/O.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


# --- lean_angle --------------------------------------------------------------

func test_rightward_travel_leans_right_and_leftward_leans_left() -> void:
	# Positive rotation tips a sprite's top to the right in Godot's 2D frame.
	var right: float = EntityTransforms.lean_angle(Vector2(64.0, 32.0))
	var left: float = EntityTransforms.lean_angle(Vector2(-64.0, 32.0))
	assert_float(right).is_greater(0.0)
	assert_float(left).is_less(0.0)
	assert_float(right).is_equal_approx(-left, 0.0001)


func test_lean_angle_matches_the_configured_degrees() -> void:
	assert_float(EntityTransforms.lean_angle(Vector2(1.0, 0.0))) \
		.is_equal_approx(deg_to_rad(EntityTransforms.LEAN_ANGLE_DEG), 0.0001)


func test_purely_vertical_travel_does_not_lean() -> void:
	# A straight up-screen move has no side to lean toward; leaning by tie-break
	# would flicker between frames.
	assert_float(EntityTransforms.lean_angle(Vector2(0.0, -48.0))).is_equal(0.0)
	assert_float(EntityTransforms.lean_angle(Vector2.ZERO)).is_equal(0.0)


func test_lean_stays_small_enough_to_survive_repetition() -> void:
	# §8.5: Move is "the most-seen animation, must survive repetition". A lean
	# past ~10 degrees reads as a stumble by the fiftieth move. Guards a retune
	# from quietly crossing that line.
	assert_float(EntityTransforms.LEAN_ANGLE_DEG).is_less(10.0)
	assert_float(EntityTransforms.LEAN_ANGLE_DEG).is_greater(0.0)


# --- nudge -------------------------------------------------------------------

func test_nudge_points_from_the_first_point_toward_the_second() -> void:
	var shove: Vector2 = EntityTransforms.nudge(Vector2(100.0, 100.0), Vector2(200.0, 100.0), 10.0)
	assert_float(shove.x).is_equal_approx(10.0, 0.0001)
	assert_float(shove.y).is_equal_approx(0.0, 0.0001)


func test_nudge_magnitude_is_the_requested_distance_regardless_of_separation() -> void:
	# Actors two tiles apart and twenty tiles apart nudge exactly as far — the
	# motion is a tell, not a travel distance.
	var near: Vector2 = EntityTransforms.nudge(Vector2.ZERO, Vector2(3.0, 4.0), 12.0)
	var far: Vector2 = EntityTransforms.nudge(Vector2.ZERO, Vector2(300.0, 400.0), 12.0)
	assert_float(near.length()).is_equal_approx(12.0, 0.0001)
	assert_float(far.length()).is_equal_approx(12.0, 0.0001)
	assert_vector(near).is_equal_approx(far, Vector2(0.0001, 0.0001))


func test_swapping_the_arguments_reverses_the_nudge() -> void:
	# This is exactly how one helper serves both a lunge (toward) and a recoil
	# (away) — EntitySpriteFeed.recoil passes the same pair in the same order and
	# gets the opposite vector because it starts from the attacker.
	var a := Vector2(40.0, 80.0)
	var b := Vector2(140.0, 20.0)
	assert_vector(EntityTransforms.nudge(a, b, 9.0)) \
		.is_equal_approx(-EntityTransforms.nudge(b, a, 9.0), Vector2(0.0001, 0.0001))


func test_coincident_points_nudge_nowhere() -> void:
	# No meaningful direction — better skipped than guessed.
	assert_vector(EntityTransforms.nudge(Vector2(7.0, 7.0), Vector2(7.0, 7.0), 10.0)) \
		.is_equal(Vector2.ZERO)


# --- §8.5 value relationships ------------------------------------------------

func test_recoil_never_out_travels_the_lunge_that_caused_it() -> void:
	# §8.5 wants "plating absorbs impact". A recoil larger than the blow reads as
	# knockback, a mechanic this game does not have.
	assert_float(EntityTransforms.RECOIL_DISTANCE_PX) \
		.is_less(EntityTransforms.LUNGE_DISTANCE_PX)


func test_strike_is_faster_than_its_return() -> void:
	# Both the lunge and the recoil snap out and ease back; the asymmetry is what
	# makes them read as impacts rather than wobbles.
	assert_float(EntityTransforms.LUNGE_OUT_SEC).is_less(EntityTransforms.LUNGE_BACK_SEC)
	assert_float(EntityTransforms.RECOIL_OUT_SEC).is_less(EntityTransforms.RECOIL_BACK_SEC)


func test_death_beat_falls_inside_the_locked_two_to_four_frame_window() -> void:
	# §8.5 LOCKS destroyed at 2-4 animation frames at the bible's ~10fps
	# functional rate, i.e. 0.2s-0.4s. Guards a retune from breaking a locked value.
	assert_float(EntityTransforms.DEATH_ECHO_SEC).is_greater_equal(0.2)
	assert_float(EntityTransforms.DEATH_ECHO_SEC).is_less_equal(0.4)


func test_the_light_dies_before_the_body() -> void:
	# A shutdown, not an explosion: the glow fade occupies only part of the beat.
	assert_float(EntityTransforms.DEATH_GLOW_FRACTION).is_greater(0.0)
	assert_float(EntityTransforms.DEATH_GLOW_FRACTION).is_less(1.0)
