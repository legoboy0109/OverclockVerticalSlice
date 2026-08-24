# Story S6-07: the production cooldown — "slower reinforcement" (user decision 2026-08-24).
#
# ★★ WHY: the S6-06 gate showed 0/21 games resolving with zero HQ damage, and late-game
# armies pinned at ~2.5 units on BOTH sides. Units died exactly as fast as they were
# replaced -- two symmetric AIs reinforcing instantly from HQs at opposite ends of a small
# map, trading one-for-one forever. PERPETUAL ATTRITION WAS THE EQUILIBRIUM.
#
# Three earlier causal chains (unbounded economy, AI paralysis, population cap) were each a
# real defect and each was fixed; none was the cause. This is the first change aimed at the
# equilibrium itself: make a loss cost TIME rather than a turn's Credits, so one side can
# achieve the local superiority the stalemate denies both.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 16


func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	state.active_player = 0
	state.per_player[0].current_ap = 999
	state.per_player[0].current_credits = 999999
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _hq(state: GameState, player: int, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = StructureTypes.HQ
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _produce(state: GameState, producer: StructureState, tile: Vector2i) -> ActionResult:
	var a := ProduceAction.new()
	a.player = producer.owner
	a.producer_id = producer.entity_id
	a.unit_type = UnitTypes.SCOUT
	a.tile = tile
	return state.apply_action(a)


# --- The shipped configuration -------------------------------------------------

func test_producers_ship_with_a_nonzero_cooldown() -> void:
	# ★ If this is 0 the whole lever is inert and the stalemate returns.
	assert_int(StructureTypes.HQ.production_cooldown_turns).is_greater(0)
	assert_int(StructureTypes.BARRACKS.production_cooldown_turns).is_greater(0)


func test_a_zero_cooldown_type_is_unrestricted() -> void:
	# The backwards-compatible default: adding the field changed nothing until a type
	# opted in, which is why the whole suite stayed green across this change.
	var t := StructureTypeDef.new()
	assert_int(t.production_cooldown_turns).is_equal(0)


# --- The mechanic --------------------------------------------------------------

func test_producing_arms_the_cooldown() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	assert_int(hq.production_cooldown_remaining).is_equal(0)
	assert_bool(_produce(state, hq, Vector2i(5, 6)).ok).is_true()
	assert_int(hq.production_cooldown_remaining).is_equal(StructureTypes.HQ.production_cooldown_turns)


func test_a_producer_on_cooldown_is_rejected_naming_the_cooldown() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	_produce(state, hq, Vector2i(5, 6))
	hq.units_produced_this_turn = 0  # isolate from the per-turn throughput cap

	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = hq.entity_id
	a.unit_type = UnitTypes.SCOUT
	a.tile = Vector2i(5, 4)
	assert_int(BaseProduction.validate_produce(state, a)).is_equal(Action.Reason.PRODUCER_ON_COOLDOWN)


func test_the_cooldown_ticks_down_once_per_owner_turn() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	_produce(state, hq, Vector2i(5, 6))
	var armed: int = hq.production_cooldown_remaining
	BaseProduction.advance_build_timers(state, 0)
	assert_int(hq.production_cooldown_remaining).is_equal(armed - 1)


func test_the_cooldown_expires_and_production_resumes() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	_produce(state, hq, Vector2i(5, 6))
	for i: int in range(StructureTypes.HQ.production_cooldown_turns):
		BaseProduction.advance_build_timers(state, 0)
	hq.units_produced_this_turn = 0
	assert_int(hq.production_cooldown_remaining).is_equal(0)

	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = hq.entity_id
	a.unit_type = UnitTypes.SCOUT
	a.tile = Vector2i(5, 4)
	assert_int(BaseProduction.validate_produce(state, a)).is_equal(Action.Reason.OK)


func test_the_cooldown_never_ticks_below_zero() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	for i: int in range(6):
		BaseProduction.advance_build_timers(state, 0)
	assert_int(hq.production_cooldown_remaining).is_equal(0)


func test_the_cooldown_is_per_producer_not_per_player() -> void:
	# ★ Load-bearing: if it were per-player, building more Barracks would not raise the
	# reinforcement rate at all, and the capacity investment would be pointless.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	var second := _hq(state, 0, Vector2i(9, 9))  # a second producer, same owner
	_produce(state, hq, Vector2i(5, 6))
	assert_int(hq.production_cooldown_remaining).is_greater(0)
	assert_int(second.production_cooldown_remaining).is_equal(0)


func test_an_opponents_production_does_not_arm_your_cooldown() -> void:
	var state := _state()
	var mine := _hq(state, 0, Vector2i(5, 5))
	var theirs := _hq(state, 1, Vector2i(12, 12))
	_produce(state, mine, Vector2i(5, 6))
	assert_int(theirs.production_cooldown_remaining).is_equal(0)


func test_only_the_owners_turn_ticks_their_cooldown() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(5, 5))
	_produce(state, hq, Vector2i(5, 6))
	var armed: int = hq.production_cooldown_remaining
	BaseProduction.advance_build_timers(state, 1)  # the opponent's turn
	assert_int(hq.production_cooldown_remaining).is_equal(armed)
