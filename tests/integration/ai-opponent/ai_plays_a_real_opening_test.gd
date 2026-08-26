# The AI actually plays — a multi-turn behavioural gate, not a per-verb one.
#
# WHY THIS SUITE EXISTS: every other AI test scores ONE candidate or drives ONE
# turn, and the whole suite stayed green while the AI did literally nothing for an
# entire match. On the real opening board it produced a Builder, spent it on a
# Barracks, CANCELLED the Barracks for the refund, and repeated that forever —
# ending every match with an empty board and a bank full of Credits.
#
# Two defects had to combine, and each was invisible to a unit test:
#
#   1. The cancel-build anti-oscillation gate keyed on `economy_investments`, the
#      economy-CADENCE counter. S6-09 correctly made builds stop counting toward
#      that cadence — which silently disabled the gate, because two different
#      questions were sharing one variable.
#   2. `_cancel_build_value` returned RAW CREDITS while every competing verb is
#      scored in AP-equivalent. `ai-opponent.md` AC-22 specifies the
#      CREDIT_TO_AP_RATE conversion; the code omitted it and the unit tests
#      asserted the code. Test and implementation agreed with each other while
#      both contradicted the spec.
#
# And a third thing the scorer could not express: the GDD says Cancel Build
# "rarely clears PASS_THRESHOLD against a concrete positive play", which quietly
# assumes a positive play exists. On a turn with none — HQ on cooldown, no units,
# no Builder — cancel wins by default. It is deficit-gated now, as the safety
# valve the design calls it.
#
# So this suite asserts OUTCOMES over several turns rather than scores. It drives
# the same decision loop AITurnDriver runs, minus the wall-clock commit pacing, so
# it stays deterministic and fast.
extends GdUnitTestSuite

## How many AI turns to play. Enough for: produce a Builder, build a Barracks,
## let it finish (build_time 2), and field something out of it.
const TURNS: int = 6
## Mirrors AITurnDriver.MAX_CONSECUTIVE_REJECTS — a turn must not spin forever.
const MAX_REJECTS: int = 8


## Plays one AI turn exactly as [AITurnDriver] does, without the pacing await.
## Returns the number of commits that landed.
func _play_one_ai_turn(state: GameState) -> int:
	var economy_investments: int = 0
	var builds_committed: int = 0
	var rejects: int = 0
	var commits: int = 0
	for _step: int in range(60):
		var action: Action = AI.choose_action(state, economy_investments, builds_committed)
		if action == null:
			break
		var result: ActionResult = state.apply_action(action)
		if not result.ok:
			rejects += 1
			if rejects >= MAX_REJECTS:
				break
			continue
		rejects = 0
		commits += 1
		if action.verb == Action.Verb.BUILD:
			builds_committed += 1
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			break
	var end_turn := EndTurnAction.new()
	end_turn.player = state.active_player
	state.apply_action(end_turn)
	return commits


func _ai_holdings(state: GameState, player: int) -> Dictionary:
	var units: int = 0
	var completed: int = 0
	var building: int = 0
	for e: EntityState in state.entities():
		if e.owner != player:
			continue
		if e is UnitState:
			units += 1
		else:
			var s: StructureState = e
			if s.build_status == StructureState.BuildStatus.COMPLETED:
				completed += 1
			else:
				building += 1
	return {"units": units, "completed": completed, "building": building}


## Boots the real slice and plays [param turns] AI turns on the real map.
func _play(turns: int) -> Dictionary:
	var root: VerticalSliceRoot = auto_free(
		load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	var state: GameState = root.state()
	var ai: int = 1
	var peak: Dictionary = {"units": 0, "completed": 0, "building": 0}
	var total_commits: int = 0
	for _turn: int in range(turns):
		# hand the turn to the AI, play it, hand it back
		state.active_player = ai
		state.start_turn(ai)
		total_commits += _play_one_ai_turn(state)
		var now: Dictionary = _ai_holdings(state, ai)
		for k: String in now:
			peak[k] = maxi(int(peak[k]), int(now[k]))
	var final: Dictionary = _ai_holdings(state, ai)
	final["peak_units"] = peak["units"]
	final["commits"] = total_commits
	final["credits"] = state.per_player[ai].current_credits
	return final


# ==============================================================================
# The AI does something at all.
# ==============================================================================

func test_the_ai_commits_actions_instead_of_passing_every_turn() -> void:
	var out: Dictionary = await _play(TURNS)
	assert_int(int(out["commits"])).override_failure_message(
		"the AI passed every turn — it committed %d actions in %d turns" % [
			int(out["commits"]), TURNS]
	).is_greater(TURNS)


func test_the_ai_still_owns_a_structure_it_built() -> void:
	# ★ THE REGRESSION. The AI built a Barracks every turn and cancelled it the
	# next, so it never owned one at the END of a turn. Asserting on the final
	# board, not on a peak, is what makes build-then-cancel fail here.
	var out: Dictionary = await _play(TURNS)
	assert_int(int(out["completed"]) + int(out["building"])).override_failure_message(
		"after %d turns the AI owns no structure beyond its HQ — it is building " % TURNS +
		"and then cancelling, which leaves the player facing an empty board"
	).is_greater(1)  # > 1 because the HQ itself is always there


func test_the_ai_fields_an_army() -> void:
	# The end of the chain the Builder rework created: HQ makes a Builder, the
	# Builder becomes a Barracks, the Barracks makes fighting units. If any link
	# breaks the AI is harmless, and every link is silent when it fails.
	var out: Dictionary = await _play(TURNS)
	assert_int(int(out["peak_units"])).override_failure_message(
		"the AI never fielded a single unit in %d turns. The opening chain is " % TURNS +
		"HQ -> Builder -> Barracks -> army; one broken link leaves a harmless opponent"
	).is_greater(0)


func test_the_ai_spends_rather_than_hoarding() -> void:
	# A bank that only grows is the signature of an AI with nothing it can do.
	# It banked over 6,000 Credits while owning nothing but its HQ.
	var out: Dictionary = await _play(TURNS)
	assert_int(int(out["credits"])).override_failure_message(
		"the AI hoarded %d Credits over %d turns — it is not converting income " % [
			int(out["credits"]), TURNS] + "into anything on the board"
	).is_less(6000)
