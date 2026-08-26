# S8-28: the production QUEUE — produce starts a build, the unit arrives X turns later.
#
# ★★ WHY IT REPLACED THE COOLDOWN (user decision 2026-08-26). S6-07 added a flat
# per-STRUCTURE cooldown to break a perpetual-attrition equilibrium: units died exactly as
# fast as they were replaced, so a loss had to cost TIME rather than a turn's Credits.
# That reasoning still holds and this preserves it — but the wait is now a property of
# WHAT you are building rather than of the building making it, which is what makes
# "more powerful units take longer" expressible at all.
#
# Shipped: Builder 1 · Scout 1 · Trooper 1 · Sniper 2 · Heavy 2 owner-turns.
#
# ⚠ REWRITTEN, NOT DELETED. Every scenario the cooldown suite covered has a queue
# equivalent — armed on produce, ticks once per OWNER turn, per-producer not per-player,
# an opponent's production does not arm yours — because those properties are what the
# S6-07 lever actually needed and they are just as load-bearing now. What changed is the
# mechanism; what it must guarantee did not.
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
	a.unit_type = UnitTypes.BUILDER
	a.tile = tile
	return state.apply_action(a)


# --- The shipped configuration -------------------------------------------------

func test_every_unit_takes_at_least_one_turn_to_produce() -> void:
	# ★ A 0 here would restore instant production and re-open the S6-07 attrition
	# equilibrium that the cooldown — and now the queue — exists to prevent.
	for type: UnitTypeDef in UnitTypes.ALL:
		assert_int(type.production_turns).override_failure_message(
			"%s produces in %d turns; instant production re-opens the S6-07 stalemate." % [
				type.display_name, type.production_turns]
		).is_greater_equal(1)


func test_the_powerful_units_take_longer_than_the_cheap_ones() -> void:
	# The user's stated shape: default 1, more powerful units more. Pinned as LITERALS
	# because these values ARE the design decision, not an input to something else.
	assert_int(UnitTypes.BUILDER.production_turns).is_equal(1)
	assert_int(UnitTypes.SCOUT.production_turns).is_equal(1)
	assert_int(UnitTypes.TROOPER.production_turns).is_equal(1)
	assert_int(UnitTypes.SNIPER.production_turns).is_equal(2)
	assert_int(UnitTypes.HEAVY.production_turns).is_equal(2)


# --- Starting a build ----------------------------------------------------------

func test_producing_does_not_place_a_unit_immediately() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	var before: int = _unit_count(state, 0)

	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()

	# ★ THE HEADLINE CHANGE. Before S8-28 this call placed a unit in the same frame.
	assert_int(_unit_count(state, 0)).is_equal(before)
	assert_object(hq.producing_type).is_equal(UnitTypes.BUILDER)
	assert_int(hq.production_turns_remaining).is_equal(UnitTypes.BUILDER.production_turns)


func test_producing_spends_the_cost_up_front() -> void:
	# ⚠ Paid at COMMIT, not on delivery — which is what makes PC-3 ("units under
	# production count against the cap") a real rule instead of a loophole.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	var credits_before: int = state.per_player[0].current_credits

	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()

	assert_int(state.per_player[0].current_credits).is_less(credits_before)


func test_a_unit_under_production_counts_against_the_population_cap() -> void:
	# population-cap.md PC-3, implemented at S8-28. Its stated rationale: otherwise a
	# player queues past the cap and the check does nothing.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	var pop_before: int = Population.current_population(state, 0)

	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()

	assert_int(Population.current_population(state, 0)).is_equal(pop_before + 1)


# --- Delivery ------------------------------------------------------------------

func test_the_unit_arrives_after_its_production_turns() -> void:
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()
	var before: int = _unit_count(state, 0)

	BaseProduction.advance_build_timers(state, 0)

	assert_int(_unit_count(state, 0)).is_equal(before + 1)
	assert_object(hq.producing_type).is_null()
	assert_int(state.grid.occupant_at(5, 4)).is_not_equal(GridState.EMPTY_OCCUPANT)


func test_a_two_turn_unit_does_not_arrive_early() -> void:
	# ⚠ A Barracks, not the HQ: since S8-13 the HQ produces ONLY Builders, so a Sniper
	# has to come from the building that actually makes fighters.
	var state := _state()
	var hq := _barracks(state, 0, Vector2i(4, 4))
	_produce_type(state, hq, Vector2i(5, 4), UnitTypes.SNIPER)
	var before: int = _unit_count(state, 0)

	BaseProduction.advance_build_timers(state, 0)
	assert_int(_unit_count(state, 0)).override_failure_message(
		"A 2-turn unit arrived after 1 turn.").is_equal(before)
	assert_int(hq.production_turns_remaining).is_equal(1)

	BaseProduction.advance_build_timers(state, 0)
	assert_int(_unit_count(state, 0)).is_equal(before + 1)


func test_only_the_owners_turn_advances_their_queue() -> void:
	# Carried over from the cooldown suite unchanged in intent: the timer is in OWNER
	# turns, so an opponent taking their turn must not advance it.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()
	var armed: int = hq.production_turns_remaining

	BaseProduction.advance_build_timers(state, 1)

	assert_int(hq.production_turns_remaining).is_equal(armed)


# --- Busy while building -------------------------------------------------------

func test_a_producer_with_a_build_in_flight_is_rejected() -> void:
	# One at a time (user decision). Being busy IS the cooldown now.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()

	var second: ActionResult = _produce(state, hq, Vector2i(3, 4))

	assert_bool(second.ok).is_false()
	assert_int(second.reason).is_equal(Action.Reason.PRODUCER_ON_COOLDOWN)


func test_the_queue_is_per_producer_not_per_player() -> void:
	var state := _state()
	var first := _hq(state, 0, Vector2i(4, 4))
	var second := _hq(state, 0, Vector2i(10, 10))
	assert_bool(_produce(state, first, Vector2i(5, 4)).ok).is_true()

	assert_object(second.producing_type).is_null()
	assert_bool(_produce(state, second, Vector2i(11, 10)).ok).is_true()


func test_an_opponents_production_does_not_occupy_your_producer() -> void:
	var state := _state()
	var mine := _hq(state, 0, Vector2i(4, 4))
	var theirs := _hq(state, 1, Vector2i(10, 10))
	state.per_player[1].current_ap = 999
	state.per_player[1].current_credits = 999999
	state.active_player = 1

	assert_bool(_produce(state, theirs, Vector2i(11, 10)).ok).is_true()

	assert_object(mine.producing_type).is_null()


# --- Destruction ---------------------------------------------------------------

func test_destroying_a_producer_destroys_the_unit_inside_it() -> void:
	# ★ User decision 2026-08-26: the unit is lost and the Credits are NOT refunded.
	# It is the reason attacking a production building mid-build is worth doing.
	var state := _state()
	var hq := _hq(state, 0, Vector2i(4, 4))
	assert_bool(_produce(state, hq, Vector2i(5, 4)).ok).is_true()
	var credits_after_commit: int = state.per_player[0].current_credits

	state.destroy_entity(hq.entity_id)

	assert_int(Population.current_population(state, 0)).is_equal(0)
	assert_int(state.per_player[0].current_credits).override_failure_message(
		"Destroying a producer refunded the build; it must not.").is_equal(credits_after_commit)


# --- Helpers -------------------------------------------------------------------

func _barracks(state: GameState, player: int, pos: Vector2i) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = StructureTypes.BARRACKS
	st.current_hp = st.type.hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _unit_count(state: GameState, player: int) -> int:
	var n: int = 0
	for e: EntityState in state.entities():
		if e.owner == player and e is UnitState:
			n += 1
	return n


func _produce_type(state: GameState, producer: StructureState, tile: Vector2i, \
		type: UnitTypeDef) -> void:
	var a := ProduceAction.new()
	a.player = producer.owner
	a.producer_id = producer.entity_id
	a.unit_type = type
	a.tile = tile
	assert_bool(state.apply_action(a).ok).override_failure_message(
		"produce(%s) was rejected in setup." % type.display_name).is_true()
