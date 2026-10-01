# AI Rush (2026-10-01): the AI rushes construction and vehicle production when one turn sooner
# is worth the AP, more eagerly with enemies near, and never where the rules forbid it.
extends GdUnitTestSuite

const SIZE: int = 14


func before_test() -> void:
	Balance.reset()


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	var grid := GridState.new()
	grid.width = SIZE
	grid.height = SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(SIZE * SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(SIZE * SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	state.grid = grid
	state.active_player = 0
	for p: PlayerState in state.per_player:
		p.faction = Factions.NEUTRAL
		p.current_ap = 20
	return state


func _factory(state: GameState, producing: UnitTypeDef, turns: int) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = 0
	st.position = Vector2i(3, 3)
	st.type = StructureTypes.FACTORY
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	st.producing_type = producing
	st.production_turns_remaining = turns
	st.production_tile = Vector2i(4, 3)
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, 3, 3)
	state.next_entity_id += 1
	return st


func _enemy(state: GameState, pos: Vector2i) -> void:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = 1
	u.position = pos
	u.type = UnitTypes.TROOPER
	u.current_hp = u.type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1


func test_ai_rush_a_tank_clears_the_pass_threshold() -> void:
	var state := _state()
	var f := _factory(state, UnitTypes.TANK, 2)
	var best := AI._score_rush_candidates(state, f, AI._Candidate.new())
	assert_bool(best.action is RushAction).is_true()
	assert_float(best.score).is_greater(AIBalance.ai.pass_threshold)


func test_ai_rush_is_worth_more_with_enemies_near() -> void:
	var calm := _state()
	var f1 := _factory(calm, UnitTypes.TANK, 2)
	var near := _state()
	var f2 := _factory(near, UnitTypes.TANK, 2)
	_enemy(near, Vector2i(6, 3))
	var s1: float = AI._score_rush_candidates(calm, f1, AI._Candidate.new()).score
	var s2: float = AI._score_rush_candidates(near, f2, AI._Candidate.new()).score
	assert_float(s2).is_greater(s1)


func test_ai_never_rushes_infantry_or_past_the_floor() -> void:
	var state := _state()
	var inf := _factory(state, UnitTypes.TROOPER, 2)
	assert_object(AI._score_rush_candidates(state, inf, AI._Candidate.new()).action).is_null()
	var state2 := _state()
	var floor_f := _factory(state2, UnitTypes.TANK, 1)
	assert_object(AI._score_rush_candidates(state2, floor_f, AI._Candidate.new()).action).is_null()


func test_ai_rush_never_beats_a_better_candidate() -> void:
	var state := _state()
	var f := _factory(state, UnitTypes.TANK, 2)
	var strong := AI._Candidate.new()
	strong.score = 5.0
	assert_object(AI._score_rush_candidates(state, f, strong)).is_same(strong)
