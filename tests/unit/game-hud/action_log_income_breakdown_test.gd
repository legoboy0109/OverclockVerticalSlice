# Story 007 (Logic slice): action-log ring buffer + income breakdown.
#
# Covers production/epics/game-hud/story-007-action-log-income-build-controls.md
# (TR-hud-014/019, ADR-0016 §5/§8 + ADR-0006):
#
#   AC-14: exactly one log entry per result.events element, newest-on-top, in the
#     events' fixed append order (a multi-event commit logs each in order).
#   AC-15: only the newest ACTION_LOG_LENGTH entries are retained; oldest dropped.
#   AC-8:  the income breakdown shows income_breakdown(player)'s base/outpost/
#     econ_tech VERBATIM — the 0-outpost case is a literal 0, never a phantom.
#
# Deterministic: no RNG, no time, no rendering (the ring buffer + breakdown data
# model are asserted directly).
extends GdUnitTestSuite


func _make_state() -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _config(log_length: int = 20) -> HUDConfig:
	var c := HUDConfig.new()
	c.action_log_length = log_length
	return c


func _make_log(state: GameState, log_length: int = 20) -> ActionLogWidget:
	var log: ActionLogWidget = auto_free(ActionLogWidget.new())
	log.bind(GameStateReader.new(state))
	log.configure(_config(log_length))
	add_child(log)
	return log


func _commit(state: GameState, events: Array) -> void:
	state.action_applied.emit(ActionResult.new(true, Action.Reason.OK, events))


# ==============================================================================
# AC-14: one entry per event, append order, newest-on-top display.
# ==============================================================================

func test_multi_event_commit_logs_each_in_append_order() -> void:
	var state := _make_state()
	var log := _make_log(state)
	var kill := Event.new()
	var hq_destroy := Event.new()

	_commit(state, [kill, hq_destroy]) # one commit resolving two events.

	assert_int(log.entry_count()).is_equal(2)
	# append order (oldest → newest): [kill, hq_destroy]
	assert_array(log.entries()).is_equal([kill, hq_destroy])
	# display order (newest → oldest): [hq_destroy, kill]
	assert_array(log.entries_newest_first()).is_equal([hq_destroy, kill])


func test_each_commit_appends_newest_last() -> void:
	var state := _make_state()
	var log := _make_log(state)
	var a := Event.new()
	var b := Event.new()

	_commit(state, [a])
	_commit(state, [b])

	assert_array(log.entries()).is_equal([a, b]) # b is newest.
	assert_object(log.entries_newest_first()[0]).is_same(b)


# ==============================================================================
# AC-15: ring buffer drops the oldest at capacity.
# ==============================================================================

func test_ring_buffer_drops_oldest_at_capacity() -> void:
	var state := _make_state()
	var log := _make_log(state, 3) # capacity 3.
	var e1 := Event.new()
	var e2 := Event.new()
	var e3 := Event.new()
	var e4 := Event.new()
	var e5 := Event.new()

	_commit(state, [e1, e2, e3, e4, e5]) # 5 events, cap 3.

	assert_int(log.entry_count()).is_equal(3)
	assert_array(log.entries()).is_equal([e3, e4, e5]) # oldest e1/e2 dropped.


# ==============================================================================
# AC-8: income breakdown fields verbatim (no phantom non-zero).
# ==============================================================================

func test_income_breakdown_renders_fields_verbatim() -> void:
	var state := _make_state()
	var reader := GameStateReader.new(state)
	var income: IncomeBreakdownWidget = auto_free(IncomeBreakdownWidget.new())
	income.bind(reader)
	income.configure(HUDConfig.new(), 0)
	add_child(income)

	var expected: Dictionary = Credits.credit_income_breakdown(state, 0)
	assert_int(income.base_value()).is_equal(expected["base"])
	assert_int(income.tiers_value()).is_equal(expected["tiers"])
	# ★ S6-01: at tier 0 the tier term is a literal 0, never a phantom bonus.
	# The `outpost` and `econ_tech` terms are GONE, not zeroed -- the widget must
	# not render a line for a mechanic that no longer exists.
	assert_int(income.tiers_value()).is_equal(0)


func test_income_breakdown_default_expanded_follows_config() -> void:
	var state := _make_state()
	var reader := GameStateReader.new(state)
	var collapsed_cfg := HUDConfig.new() # default income_breakdown_default_expanded = false.
	var income: IncomeBreakdownWidget = auto_free(IncomeBreakdownWidget.new())
	income.bind(reader)
	income.configure(collapsed_cfg, 0)
	assert_bool(income.is_expanded()).is_false()
	income.toggle()
	assert_bool(income.is_expanded()).is_true()
