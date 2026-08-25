# The AI's destination tie-break must be MIRROR-INVARIANT (S7-13).
#
# ★★ WHY THIS SUITE EXISTS. `Movement.reachable()` expands neighbours in a fixed
# N->E->S->W order — deliberately, for determinism, and its own doc says so. The AI's folds
# use `_is_better`, which requires STRICTLY better to replace, so among candidates tying on
# every scored criterion the FIRST ENUMERATED one won. "First enumerated" silently meant
# "furthest East".
#
# That is not symmetric between the seats. For a player based on the WEST side the easterly
# tile is toward the enemy; for the player based on the EAST side the identical preference
# points back toward their own base. One side was pulled into the open while the other
# consolidated, and in a deterministic game with no hidden information whoever commits first
# loses the exchange.
#
# Measured before the fix, on the +1 handicap cell (n=14): the east seat won 14 of 14 games
# regardless of which side held the extra unit, and material advantage converted only 7/14.
# After: 9/5 and 12/14.
#
# ⇒ The property below is the one that was violated. It is worth far more than any single
#   expected-value assertion, because it is the thing that silently decided matches.
extends GdUnitTestSuite

const _WEST_HQ := Vector2i(2, 5)
const _EAST_HQ := Vector2i(9, 5)


func _state() -> GameState:
	return GameState.start_match(VSMap.build(), 0)


## Mirrors a tile across the board's vertical centre line — the transform that maps the west
## seat's situation onto the east seat's.
func _mirror(tile: Vector2i) -> Vector2i:
	return Vector2i(VSMap.WIDTH - 1 - tile.x, tile.y)


## ⚠ [method GameState.start_match] leaves the HQs as bare stubs — it does not give them a
## [StructureTypeDef], so `is_hq()` is false until something promotes them. Both the slice and
## the match simulator do that promotion themselves. Rather than depend on that setup, these
## tests build the HQ they need directly: `_tile_wins_tie` reads nothing but `position`.
func _hq(tile: Vector2i, owner: int) -> StructureState:
	var s := StructureState.new()
	s.entity_id = 1000 + owner
	s.owner = owner
	s.position = tile
	s.type = StructureTypes.HQ
	s.current_hp = StructureTypes.HQ.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	return s


## A state whose HQs have been promoted, for the tests that need real lookups.
func _state_with_hqs() -> GameState:
	var state: GameState = _state()
	for owner: int in 2:
		var s: StructureState = _hq(VSMap.HQ_A if owner == 0 else VSMap.HQ_B, owner)
		s.entity_id = owner
		state.entities_by_id[s.entity_id] = s
	return state


func test_the_tiebreak_is_invariant_under_mirroring() -> void:
	# ★ THE LOAD-BEARING TEST. Whatever a west-based unit prefers, an east-based unit must
	# prefer the mirror image of it. Before S7-13 this failed for every east-west pair,
	# because the answer came from BFS enumeration order rather than from the position.
	var state: GameState = _state()
	var west_enemy: StructureState = _hq(_EAST_HQ, 1) # a west-based unit attacks east
	var east_enemy: StructureState = _hq(_WEST_HQ, 0) # an east-based unit attacks west

	var pairs: Array = [
		[Vector2i(4, 4), Vector2i(4, 6)],
		[Vector2i(5, 3), Vector2i(5, 7)],
		[Vector2i(6, 5), Vector2i(6, 2)],
		[Vector2i(3, 5), Vector2i(4, 5)],
		[Vector2i(7, 6), Vector2i(5, 4)],
	]
	for pair: Array in pairs:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var west_prefers_a: bool = AI._tile_wins_tie(state, a, b, west_enemy, true)
		var east_prefers_mirror_a: bool = AI._tile_wins_tie(
			state, _mirror(a), _mirror(b), east_enemy, true)
		assert_bool(east_prefers_mirror_a).override_failure_message(
			("Mirror asymmetry: a west-based unit choosing between %s and %s decides %s, " % [a, b, west_prefers_a]) +
			("but an east-based unit choosing between the mirrored %s and %s decides %s. " % [_mirror(a), _mirror(b), east_prefers_mirror_a]) +
			"The two seats must make the same decision in their own frames — this is the " +
			"exact defect that handed the east seat 14 of 14 close games."
		).is_equal(west_prefers_a)


func test_closer_to_the_enemy_hq_wins_first() -> void:
	var state: GameState = _state()
	var enemy: StructureState = _hq(_EAST_HQ, 1)
	# (7,5) is nearer the east HQ than (4,5); both sit on the HQ rank.
	assert_bool(AI._tile_wins_tie(state, Vector2i(7, 5), Vector2i(4, 5), enemy, true)).is_true()
	assert_bool(AI._tile_wins_tie(state, Vector2i(4, 5), Vector2i(7, 5), enemy, true)).is_false()


func test_among_equally_distant_tiles_the_lane_beats_a_flank() -> void:
	var state: GameState = _state()
	var enemy: StructureState = _hq(_EAST_HQ, 1)
	# Both are 4 from (9,5): (5,5) sits on the HQ rank, (7,3) is two ranks off it.
	assert_int(state.grid.manhattan_distance(Vector2i(5, 5), _EAST_HQ)).is_equal(
		state.grid.manhattan_distance(Vector2i(7, 3), _EAST_HQ))
	assert_bool(AI._tile_wins_tie(state, Vector2i(5, 5), Vector2i(7, 3), enemy, true)).is_true()


func test_an_exact_tie_keeps_the_incumbent() -> void:
	# Reflexive comparison must be false, or the fold would churn between identical options.
	var state: GameState = _state()
	var enemy: StructureState = _hq(_EAST_HQ, 1)
	assert_bool(AI._tile_wins_tie(state, Vector2i(5, 5), Vector2i(5, 5), enemy, true)).is_false()


func test_the_final_key_uses_the_axis_perpendicular_to_the_hq_line() -> void:
	# ★ A total order needs SOME coordinate key. Taking it on the axis perpendicular to the
	# HQ-to-HQ line means both seats express the identical preference — the bias becomes
	# shared rather than sided, and shared is fair. On this east-west map that axis is y.
	var state: GameState = _state()
	var enemy: StructureState = _hq(_EAST_HQ, 1)
	# (4,4) and (4,6): same distance to the enemy HQ, same lateral offset from its rank.
	assert_int(state.grid.manhattan_distance(Vector2i(4, 4), _EAST_HQ)).is_equal(
		state.grid.manhattan_distance(Vector2i(4, 6), _EAST_HQ))
	assert_bool(AI._tile_wins_tie(state, Vector2i(4, 4), Vector2i(4, 6), enemy, true)).is_true()
	assert_bool(AI._tile_wins_tie(state, Vector2i(4, 6), Vector2i(4, 4), enemy, true)).is_false()


func test_axis_detection_follows_the_hq_layout() -> void:
	var west: StructureState = _hq(_WEST_HQ, 0)
	var east: StructureState = _hq(_EAST_HQ, 1)
	# The shipping map is laid out east-west.
	assert_bool(AI._axis_is_horizontal(west, east)).is_true()
	assert_bool(AI._axis_is_horizontal(east, west)).is_true()
	# ⚠ Missing HQs must not crash the comparator — it runs inside the AI's hot fold.
	assert_bool(AI._axis_is_horizontal(null, east)).is_true()
	assert_bool(AI._axis_is_horizontal(west, null)).is_true()


func test_own_hq_finds_the_callers_own_headquarters() -> void:
	var state: GameState = _state_with_hqs()
	var own: StructureState = AI._own_hq(state, 0)
	var enemy: StructureState = AI._enemy_hq(state, 0)
	assert_object(own).is_not_null()
	assert_object(enemy).is_not_null()
	assert_int(own.owner).is_equal(0)
	assert_int(enemy.owner).is_not_equal(0)
	# And they are the two distinct HQs, not the same one returned twice.
	assert_vector(own.position).is_not_equal(enemy.position)
