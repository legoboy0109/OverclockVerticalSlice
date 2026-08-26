## DiagnoseAI — instrumentation for "why did the AI pass with 44 of 45 AP unspent?"
##
## Built 2026-08-24 after the S6-06 regression batch FAILED: 0/21 games resolved, zero HQ
## damage across 1,260 turn-rows, and the AI leaving ~98% of its AP budget unspent every
## turn. The PIVOT note's diagnosis (unbounded Credits -> economy outscores manoeuvre ->
## AP never reaches movement) predicted its own falsifier and hit it: the economy is now
## bounded and nothing changed.
##
## ★ This tool exists so the NEXT step is a measurement rather than a third hypothesis.
##
## It replays a real AI-vs-AI match and, at each of the acting player's turns, reports:
## [br]• how many candidates each verb produced,
## [br]• the best score each verb reached, against `pass_threshold`,
## [br]• what `choose_action` actually returned, and how much AP was left when it stopped.
##
## The question it answers: does the AI see NO candidate worth taking (a scoring/threshold
## problem), or does it see them and aim them at the wrong thing (an objective problem)?
##
## Usage: `./redot --headless tools/DiagnoseAI.tscn`
extends Node

const TURNS_TO_TRACE: int = 24
# Mirror SimulateMatches exactly -- diagnosing a different board would diagnose a
# different problem.
const MAP_W: int = 12
const MAP_H: int = 10
const HQ_A := Vector2i(1, 5)
const HQ_B := Vector2i(10, 5)


func _ready() -> void:
	var state: GameState = _build_match()
	print("DIAG,turn,player,ap_before,chosen_verb,chosen_score,ap_after,actions_committed,best_move,best_attack,best_produce,best_build,pass_threshold")
	_trace(state)
	print("DIAG_DONE")
	get_tree().quit()


func _build_match() -> GameState:
	# ★ S7-11: shared with the slice via VSMap — see its header on why this is not
	# hand-built here any more.
	var map: MapDefinition = VSMap.build()

	var state: GameState = GameState.start_match(map, 0)
	state.max_rounds = VerticalSliceRoot.VS_MAX_ROUNDS
	state.per_player[0].faction = Factions.RUSH
	state.per_player[1].faction = Factions.BOOM
	state.per_player[0].is_ai_controlled = true
	state.per_player[1].is_ai_controlled = true

	# start_match leaves the HQs as bare stubs; promote them exactly as the slice and
	# the simulator do, or the AI has no producer and no objective.
	for player: int in map.hq_tiles.size():
		var s := StructureState.new()
		s.entity_id = player
		s.owner = player
		s.position = map.hq_tiles[player]
		s.type = StructureTypes.HQ
		s.current_hp = StructureTypes.HQ.hp
		s.build_status = StructureState.BuildStatus.COMPLETED
		state.entities_by_id[s.entity_id] = s
	return state


## Scores each verb family in isolation so we can see WHICH one is starving.
## Mirrors choose_action's own loop, one verb at a time.
func _verb_bests(state: GameState, player: int) -> Dictionary:
	var lookahead: GameState = state.clone()
	var out := {"move": -1.0, "attack": -1.0, "produce": -1.0, "build": -1.0}
	for entity: EntityState in AI._entities_in_enumeration_order(lookahead):
		if entity.owner != player:
			continue
		var m := AI._score_move_and_attack_candidates(lookahead, entity, 0, AI._Candidate.new())
		if m.action != null:
			var key: String = "attack" if m.action is AttackAction else "move"
			out[key] = maxf(out[key], m.score)
		var p := AI._score_production_candidates(lookahead, entity, 0, AI._Candidate.new())
		if p.action != null:
			out["produce"] = maxf(out["produce"], p.score)
		var b := AI._score_build_and_economy_candidates(lookahead, entity, 0, AI._Candidate.new())
		if b.action != null:
			out["build"] = maxf(out["build"], b.score)
	return out


func _trace(state: GameState) -> void:
	var traced: int = 0
	while traced < TURNS_TO_TRACE and state.match_status == GameState.MatchStatus.IN_PROGRESS:
		var player: int = state.active_player
		var ap_before: int = AP.current_ap(state, player)
		var bests: Dictionary = _verb_bests(state, player)

		# Drive the turn exactly as the real driver does: commit until choose_action
		# returns null, then end the turn.
		var committed: int = 0
		var first_verb: String = "-"
		var first_score: float = 0.0
		# ⛔ FIXED 2026-08-26 (S8-26). This passed `committed` — the count of ALL actions
		# taken this turn — into a parameter that means `economy_investments_committed`.
		# The two are wildly different: `committed` climbs on every move and attack, so
		# after a couple of ordinary actions the AI believed it had blown its economy
		# CADENCE CAP (ADR-0011 §1/§6) and stopped producing.
		# ⇒ This tool reported "REJECTED:PRODUCE, no move/attack/build candidates" —
		#   a deadlock THAT IT WAS CAUSING ITSELF. It is the instrument for diagnosing
		#   "why did the AI pass with its budget unspent", and it manufactured exactly
		#   that symptom.
		# ★ simulate_matches.gd and diagnose_cliff.gd both pass a real economy counter;
		#   only this file was wrong, which is why the batch numbers were trustworthy and
		#   the trace was not. Kept in lockstep with the driver, same as the simulator.
		var economy_investments: int = 0
		var rejects: int = 0
		var seq: Array[String] = []
		while true:
			var action: Action = AI.choose_action(state, economy_investments)
			if action == null:
				break
			if committed == 0:
				first_verb = _verb_name(action)
			var result: ActionResult = state.apply_action(action)
			if not result.ok:
				# ⚠ Mirror the simulator: a rejection is not automatically the end of a
				# turn — the driver retries other candidates. Bailing on the first one
				# made an ordinary rejected candidate look like a terminal stall.
				rejects += 1
				first_verb = "REJECTED:%s:%s" % [_verb_name(action), Action.Reason.keys()[result.reason]]
				if rejects >= 8:
					break
				continue
			rejects = 0
			var tag: String = _verb_name(action)
			if action is AttackAction:
				var atk = state.entities_by_id.get((action as AttackAction).attacker_id)
				var tgt = state.entities_by_id.get((action as AttackAction).target_id)
				var an: String = (atk.type.display_name if atk != null and atk.type != null else "?")
				var tn: String = (tgt.type.display_name if tgt != null and tgt.type != null else "?")
				tag = "ATTACK(%s->%s)" % [an, tn]
			elif action is ProduceAction:
				tag = "PRODUCE(%s)" % (action as ProduceAction).unit_type.display_name
			seq.append(tag)
			if action.verb == Action.Verb.RESEARCH:
				economy_investments += 1
			committed += 1
			if committed > 40:
				first_verb = "RUNAWAY"
				break

		var ap_after: int = AP.current_ap(state, player)
		print("DIAG,%d,%d,%d,%s,%.3f,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f" % [
			state.round_number, player, ap_before, first_verb, first_score, ap_after, committed,
			bests["move"], bests["attack"], bests["produce"], bests["build"],
			AIBalance.ai.pass_threshold,
		])
		print("      seq=%s" % str(seq))

		var end_turn := EndTurnAction.new()
		end_turn.player = player
		state.apply_action(end_turn)
		traced += 1


func _verb_name(action: Action) -> String:
	if action is MoveAction: return "MOVE"
	if action is AttackAction: return "ATTACK"
	if action is ProduceAction: return "PRODUCE"
	if action is BuildAction: return "BUILD"
	return "OTHER"
