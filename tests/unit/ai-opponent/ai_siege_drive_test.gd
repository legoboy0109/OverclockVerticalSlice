# The AI's siege drive — a positional pull toward the ENEMY HQ (2026-08-21).
#
# ★ Why it exists. An AI-vs-AI simulation over 20 matches recorded ZERO HQ damage across
# 4,182 turn-rows. The AI values the HQ as a TARGET generously (hq_siege_value 12, with a
# regression guard against that weight being zero) but had no term pulling it TOWARD one.
# Its only positional objective was "close on the nearest enemy", and since both sides
# keep producing, the nearest enemy is always a unit — so the armies stalled mid-map and
# no match could ever end. See
# production/playtests/swing-back-simulation-appendix-2026-08-21.md.
#
# ⚠ These tests prove the TERM works. They do NOT prove the AI besieges in a real match:
# it does not, because economy and production consume the AP budget first. That is a
# separate, deeper problem measured in the appendix and left open. Do not read a green
# suite here as "the AI attacks HQs now".
#
# No RNG, no time-dependent asserts, no file I/O.
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 12


func _make_grid(size: int = GRID_SIZE) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


# Credits default to 0 so economy candidates are unaffordable and the positional
# scoring under test is what actually decides. With Credits funded the AI builds and
# produces first — which is the real-match behaviour, and exactly why the siege term
# does not surface there.
func _make_state(current_ap: int = 20, current_credits: int = 0) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.per_player[0].faction = Factions.RUSH
	state.per_player[1].faction = Factions.BOOM
	for p: int in 2:
		state.per_player[p].current_ap = current_ap
		state.per_player[p].current_credits = current_credits
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = entity_id
	unit.owner = owner
	unit.position = pos
	unit.type = type
	unit.current_hp = type.hp
	return unit


func _make_hq(entity_id: int, owner: int, pos: Vector2i) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = StructureTypes.HQ
	s.current_hp = StructureTypes.HQ.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	return s


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


# --- The objective is findable ------------------------------------------------

func test_enemy_hq_is_found_and_own_hq_is_not() -> void:
	var state := _make_state()
	_place(state, _make_hq(1, 0, Vector2i(2, 5)))
	_place(state, _make_hq(2, 1, Vector2i(9, 5)))
	var target: StructureState = AI._enemy_hq(state, 0)
	assert_object(target).is_not_null()
	assert_int(target.owner).is_equal(1)
	assert_vector(target.position).is_equal(Vector2i(9, 5))


func test_no_enemy_hq_is_a_safe_null_not_a_crash() -> void:
	# Reachable in a real match: the HQ is destroyed on the killing blow.
	var state := _make_state()
	_place(state, _make_hq(1, 0, Vector2i(2, 5)))
	assert_object(AI._enemy_hq(state, 0)).is_null()


# --- ★ The behaviour the term exists to produce -------------------------------

func test_a_unit_with_no_nearer_enemy_advances_on_the_enemy_hq() -> void:
	# The exact stalled position from the simulation, minus the enemy army: before this
	# term the unit had no reason to go anywhere and simply sat.
	var state := _make_state()
	_place(state, _make_hq(1, 0, Vector2i(2, 5)))
	_place(state, _make_hq(2, 1, Vector2i(9, 5)))
	var unit := _make_unit(100, 0, UnitTypes.TROOPER, Vector2i(5, 5))
	_place(state, unit)
	var before: int = state.grid.manhattan_distance(unit.position, Vector2i(9, 5))

	var action: Action = AI.choose_action(state, 0)

	assert_object(action).is_not_null()
	assert_bool(action is MoveAction).is_true()
	var dest: Vector2i = (action as MoveAction).to
	assert_int(state.grid.manhattan_distance(dest, Vector2i(9, 5))).is_less(before)


func test_the_siege_advance_strictly_closes_never_drifts_sideways() -> void:
	# Anti-oscillation, the same rule the ordinary advance uses: a tile that does not
	# strictly close would let the AI ping-pong until its AP drained.
	var state := _make_state()
	_place(state, _make_hq(1, 0, Vector2i(2, 5)))
	_place(state, _make_hq(2, 1, Vector2i(9, 5)))
	var unit := _make_unit(100, 0, UnitTypes.SCOUT, Vector2i(5, 5))
	_place(state, unit)
	var before: int = state.grid.manhattan_distance(unit.position, Vector2i(9, 5))
	for _step: int in 3:
		var action: Action = AI.choose_action(state, 0)
		if action == null or not (action is MoveAction):
			break
		state.apply_action(action)
		var now: int = state.grid.manhattan_distance(unit.position, Vector2i(9, 5))
		assert_int(now).is_less(before)
		before = now


# --- It must not out-compete actually fighting --------------------------------

func test_an_available_attack_still_beats_a_siege_advance() -> void:
	# The combo/attack loop scores far above any bare advance, and must keep doing so —
	# a siege drive that walked past a killable enemy would be strictly worse than the
	# stall it replaced.
	var state := _make_state()
	_place(state, _make_hq(1, 0, Vector2i(2, 5)))
	_place(state, _make_hq(2, 1, Vector2i(9, 5)))
	_place(state, _make_unit(100, 0, UnitTypes.TROOPER, Vector2i(5, 5)))
	_place(state, _make_unit(200, 1, UnitTypes.SCOUT, Vector2i(6, 5))) # adjacent, killable

	var action: Action = AI.choose_action(state, 0)

	assert_object(action).is_not_null()
	assert_bool(action is AttackAction).is_true()


func test_the_siege_weight_stays_above_the_pass_threshold() -> void:
	# ★ Guards the one way to silently disable this: pass_threshold gates every
	# candidate, so a siege weight at or below it means the AI declines to siege at all
	# and the stall returns with no test failing.
	assert_float(AIBalance.ai.siege_value_per_tile_closed) \
		.is_greater(AIBalance.ai.pass_threshold)


func test_the_siege_weight_is_at_least_the_ordinary_advance_rate() -> void:
	# Below the ordinary advance the AI keeps preferring to shuffle toward whichever
	# enemy is nearest, which is precisely the stall this term exists to break.
	assert_float(AIBalance.ai.siege_value_per_tile_closed) \
		.is_greater_equal(AIBalance.ai.positional_value_per_tile_closed)
