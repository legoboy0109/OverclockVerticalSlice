# S6-08: victory/defeat presentation — BOTH of CR-9's clauses.
#
# Covers design/gdd/game-hud.md CR-9 / AC-17 / AC-22 against GameOverOverlay, and
# the GameState.WinReason plumbing that AC-22 needs.
#
# WHY this story sat unimplemented since Sprint 5: it was invisible. Matches never
# ended (see production/vertical-slice/PIVOT-NOTE.md -- an HQ never took a single
# point of damage across 4,182 turn-rows), so a win screen had nothing to present
# and a one-line status string was an honest stopgap. S6-06 flipped that: 18 of 21
# matches now end by HQ destruction and 3 on the round cap, so both paths are
# player-facing.
#
# ★ AC-22 was explicitly deferred as "not testable in VS scope -- activate when
# MAX_ROUNDS ships". It shipped in S6-03 (max_rounds = 30). The deferral is spent
# and the round-limit clause is tested here for the first time.
#
# Deterministic: no RNG, no time, no rendering asserted (the display model is).
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
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _add_hq(state: GameState, player: int, pos: Vector2i, hp: int = -1) -> StructureState:
	var st := StructureState.new()
	st.entity_id = state.next_entity_id
	st.owner = player
	st.position = pos
	st.type = StructureTypes.HQ
	st.current_hp = StructureTypes.HQ.hp if hp < 0 else hp
	st.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[st.entity_id] = st
	state.grid.place(st.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return st


func _add_unit(state: GameState, player: int, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = player
	u.position = pos
	u.type = UnitTypes.TROOPER
	u.current_hp = UnitTypes.TROOPER.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, pos.x, pos.y)
	state.next_entity_id += 1
	return u


func _overlay(state: GameState, local_player: int = 0) -> GameOverOverlay:
	var o: GameOverOverlay = auto_free(GameOverOverlay.new())
	o.bind(GameStateReader.new(state))
	o.configure(local_player)
	add_child(o)
	return o


## Destroys [param loser]'s HQ through run_win_check, exactly as a killing commit
## does — never by setting winner/win_reason by hand, so the test exercises the
## real terminal path.
func _destroy_hq(state: GameState, loser: int) -> Array:
	var evt := StructureDestroyedEvent.new()
	evt.owner = loser
	evt.is_hq = true
	var events: Array = [evt]
	state.run_win_check(events)
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))
	return events


## Drives the round cap, again through run_win_check.
func _reach_round_limit(state: GameState) -> Array:
	state.max_rounds = 1
	state.round_number = 2 # all max_rounds rounds completed.
	var events: Array = []
	state.run_win_check(events)
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))
	return events


# ==============================================================================
# Ongoing match: the overlay is absent and says nothing.
# ==============================================================================

func test_an_ongoing_match_shows_nothing() -> void:
	var state := _state()
	var o := _overlay(state)
	assert_bool(o.is_showing()).is_false()
	assert_str(o.result_text()).is_empty()
	assert_str(o.reason_text()).is_empty()
	assert_str(o.detail_text()).is_empty()
	assert_int(o.winning_player()).is_equal(-1)


# ==============================================================================
# AC-17: HQ destruction — victory and defeat, from the local seat.
# ==============================================================================

func test_destroying_the_enemy_hq_shows_victory_naming_the_cause() -> void:
	var state := _state()
	_add_hq(state, 0, Vector2i(2, 2))
	_add_hq(state, 1, Vector2i(12, 12))
	var o := _overlay(state, 0)

	_destroy_hq(state, 1)

	assert_bool(o.is_showing()).is_true()
	assert_bool(o.is_local_victory()).is_true()
	assert_str(o.result_text()).is_equal("VICTORY")
	assert_int(o.winning_player()).is_equal(0)
	assert_str(o.reason_text()).is_equal("Enemy HQ destroyed")


func test_losing_your_hq_shows_defeat_from_the_same_state() -> void:
	# Same terminal state, other seat -- the overlay is oriented by local_player,
	# so one game produces both screens depending on who is looking.
	var state := _state()
	_add_hq(state, 0, Vector2i(2, 2))
	_add_hq(state, 1, Vector2i(12, 12))
	var o := _overlay(state, 1)

	_destroy_hq(state, 1)

	assert_bool(o.is_showing()).is_true()
	assert_bool(o.is_local_victory()).is_false()
	assert_str(o.result_text()).is_equal("DEFEAT")
	assert_str(o.reason_text()).is_equal("Your HQ was destroyed")


func test_an_hq_victory_shows_no_tiebreak_figures() -> void:
	# Something visibly died; the player watched it happen. Metric scores would be
	# noise on a screen whose job is to name one outcome.
	var state := _state()
	_add_hq(state, 0, Vector2i(2, 2))
	_add_hq(state, 1, Vector2i(12, 12))
	var o := _overlay(state, 0)
	_destroy_hq(state, 1)
	assert_bool(o.is_round_limit_result()).is_false()
	assert_str(o.detail_text()).is_empty()


func test_the_win_reason_is_recorded_on_state_and_on_the_event() -> void:
	var state := _state()
	_add_hq(state, 0, Vector2i(2, 2))
	_add_hq(state, 1, Vector2i(12, 12))
	var events: Array = _destroy_hq(state, 1)

	assert_int(state.win_reason).is_equal(GameState.WinReason.HQ_DESTROYED)
	var game_over: GameOverEvent = null
	for e: Event in events:
		if e is GameOverEvent:
			game_over = e
	assert_object(game_over).is_not_null()
	assert_int(game_over.reason).is_equal(GameState.WinReason.HQ_DESTROYED)
	assert_int(game_over.winner).is_equal(0)


# ==============================================================================
# AC-22: the round-limit tiebreak — live for the first time (max_rounds shipped).
# ==============================================================================

func test_the_round_limit_result_names_the_metric_that_decided_it() -> void:
	var state := _state()
	state.tiebreak_metric = GameState.TiebreakMetric.TOTAL_HQ_HP
	_add_hq(state, 0, Vector2i(2, 2), 40)  # healthier -- P0 should win.
	_add_hq(state, 1, Vector2i(12, 12), 12)
	var o := _overlay(state, 0)

	_reach_round_limit(state)

	assert_bool(o.is_showing()).is_true()
	assert_bool(o.is_round_limit_result()).is_true()
	assert_str(o.result_text()).is_equal("VICTORY")
	assert_str(o.reason_text()).contains("Round limit reached")
	assert_str(o.reason_text()).contains("total HQ health")


func test_the_round_limit_result_shows_both_scores_local_player_first() -> void:
	# ★ The reason this clause needed its own presentation: nothing died. A player
	# told "DEFEAT" on a board that still looks playable has no way to see why
	# unless the deciding figures are on screen.
	var state := _state()
	state.tiebreak_metric = GameState.TiebreakMetric.TOTAL_HQ_HP
	_add_hq(state, 0, Vector2i(2, 2), 11)
	_add_hq(state, 1, Vector2i(12, 12), 33)
	var o := _overlay(state, 0) # the LOSING seat.

	_reach_round_limit(state)

	assert_str(o.result_text()).is_equal("DEFEAT")
	var detail: String = o.detail_text()
	assert_str(detail).contains("you 11")
	assert_str(detail).contains("opponent 33")


func test_the_unit_count_metric_is_named_in_its_own_words() -> void:
	var state := _state()
	state.tiebreak_metric = GameState.TiebreakMetric.UNIT_COUNT
	_add_hq(state, 0, Vector2i(2, 2))
	_add_hq(state, 1, Vector2i(12, 12))
	_add_unit(state, 0, Vector2i(4, 4))
	_add_unit(state, 0, Vector2i(5, 4))
	_add_unit(state, 1, Vector2i(9, 9))
	var o := _overlay(state, 0)

	_reach_round_limit(state)

	assert_str(o.reason_text()).contains("surviving units")
	assert_str(o.detail_text()).contains("you 2")
	assert_str(o.detail_text()).contains("opponent 1")


func test_the_round_limit_event_carries_the_metric_and_both_scores() -> void:
	var state := _state()
	state.tiebreak_metric = GameState.TiebreakMetric.TOTAL_HQ_HP
	_add_hq(state, 0, Vector2i(2, 2), 30)
	_add_hq(state, 1, Vector2i(12, 12), 10)
	var events: Array = _reach_round_limit(state)

	assert_int(state.win_reason).is_equal(GameState.WinReason.ROUND_LIMIT)
	var game_over: GameOverEvent = null
	for e: Event in events:
		if e is GameOverEvent:
			game_over = e
	assert_object(game_over).is_not_null()
	assert_int(game_over.reason).is_equal(GameState.WinReason.ROUND_LIMIT)
	assert_int(game_over.metric).is_equal(GameState.TiebreakMetric.TOTAL_HQ_HP)
	assert_array(game_over.metric_by_player).is_equal([30, 10])


func test_an_hq_destruction_on_the_final_round_still_reports_hq_destroyed() -> void:
	# ★ run_win_check checks HQ destruction FIRST and returns, so a decisive win on
	# the very last round must not be presented as a tiebreak. The reason field has
	# to follow that precedence or the screen contradicts the rule that produced it.
	var state := _state()
	state.tiebreak_metric = GameState.TiebreakMetric.TOTAL_HQ_HP
	_add_hq(state, 0, Vector2i(2, 2), 5)   # would LOSE the tiebreak...
	_add_hq(state, 1, Vector2i(12, 12), 40)
	state.max_rounds = 1
	state.round_number = 2 # ...and the cap is reached on this very commit.
	var o := _overlay(state, 0)

	_destroy_hq(state, 1) # but P1's HQ dies first.

	assert_int(state.win_reason).is_equal(GameState.WinReason.HQ_DESTROYED)
	assert_bool(o.is_round_limit_result()).is_false()
	assert_str(o.result_text()).is_equal("VICTORY")
	assert_str(o.reason_text()).is_equal("Enemy HQ destroyed")
	assert_str(o.detail_text()).is_empty()
